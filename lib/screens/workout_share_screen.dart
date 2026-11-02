import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'package:share_plus/share_plus.dart';

import '../widgets/exercise_media.dart';
import '../models/workout_result.dart';
import '../state/auth_notifier.dart';
import '../theme/app_theme.dart';

Future<void> showWorkoutShare(
    BuildContext context, WorkoutResultData data) async {
  final name = context.read<AuthNotifier>().user?.displayName?.trim();
  await showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    showDragHandle: false,
    backgroundColor: AppColors.ink,
    barrierColor: Colors.black54,
    clipBehavior: Clip.antiAlias,
    shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(28))),
    builder: (_) => FractionallySizedBox(
      heightFactor: .94,
      child: _WorkoutShareSheet(
          data: data,
          displayName: name == null || name.isEmpty ? 'My workout' : name),
    ),
  );
}

class _WorkoutShareSheet extends StatefulWidget {
  final WorkoutResultData data;
  final String displayName;
  const _WorkoutShareSheet({required this.data, required this.displayName});

  @override
  State<_WorkoutShareSheet> createState() => _WorkoutShareSheetState();
}

class _WorkoutShareSheetState extends State<_WorkoutShareSheet> {
  final _cardKey = GlobalKey();
  bool _sharing = false;
  String? _error;

  Future<void> _share(BuildContext buttonContext) async {
    if (_sharing) return;
    final button = buttonContext.findRenderObject() as RenderBox?;
    final origin =
        button == null ? null : button.localToGlobal(Offset.zero) & button.size;
    setState(() {
      _sharing = true;
      _error = null;
    });
    try {
      // Capture only the card, after the current frame has painted. Its eager
      // Column includes every exercise, including rows below the viewport.
      await WidgetsBinding.instance.endOfFrame;
      if (!mounted) return;
      final boundary =
          _cardKey.currentContext?.findRenderObject() as RenderRepaintBoundary?;
      if (boundary == null || !boundary.hasSize) {
        throw StateError('The result card is not ready.');
      }
      final size = boundary.size;
      // Keep long workout images within a reasonable memory/texture budget.
      final ratio = math.min(
          3.0,
          math.min(math.sqrt(12000000 / (size.width * size.height)),
              8192 / math.max(size.width, size.height)));
      final image = await boundary.toImage(pixelRatio: ratio);
      // Release the native image even if PNG encoding fails.
      final bytes = await (() async {
        try {
          final encoded =
              await image.toByteData(format: ui.ImageByteFormat.png);
          if (encoded == null) throw StateError('Could not create the image.');
          return encoded.buffer
              .asUint8List(encoded.offsetInBytes, encoded.lengthInBytes);
        } finally {
          image.dispose();
        }
      })();
      if (!mounted) return;
      await SharePlus.instance.share(ShareParams(
        title: widget.data.workout.workoutName,
        files: [XFile.fromData(bytes, mimeType: 'image/png')],
        fileNameOverrides: ['sweatmark-workout-${widget.data.workout.id}.png'],
        sharePositionOrigin: origin,
      ));
    } catch (_) {
      if (mounted) {
        setState(
            () => _error = 'Could not share this image. Please try again.');
      }
    } finally {
      if (mounted) setState(() => _sharing = false);
    }
  }

  @override
  Widget build(BuildContext context) => PopScope(
        canPop: !_sharing,
        child: Column(children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 14, 16, 8),
            child: Row(children: [
              IconButton(
                tooltip: 'Close share preview',
                onPressed: _sharing ? null : () => Navigator.of(context).pop(),
                style: IconButton.styleFrom(
                    backgroundColor: Colors.white.withValues(alpha: .09),
                    foregroundColor: Colors.white,
                    disabledForegroundColor: Colors.white38,
                    minimumSize: const Size(48, 48)),
                icon: const Icon(Icons.close_rounded, size: 25),
              ),
              const Expanded(
                child: Text('Share result',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                        color: Colors.white,
                        fontSize: 18,
                        fontWeight: FontWeight.w500)),
              ),
              const SizedBox(width: 48),
            ]),
          ),
          Expanded(
            child: LayoutBuilder(builder: (_, constraints) {
              return SingleChildScrollView(
                padding: const EdgeInsets.all(20),
                child: ConstrainedBox(
                  constraints: BoxConstraints(
                      minHeight: math.max(0, constraints.maxHeight - 40)),
                  child: Center(
                    child: ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 440),
                      child: RepaintBoundary(
                        key: _cardKey,
                        child: Theme(
                          // Export stays consistent in light and dark mode.
                          data: lightTheme,
                          child: Material(
                            type: MaterialType.transparency,
                            child: _WorkoutShareCard(
                                data: widget.data,
                                displayName: widget.displayName),
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              );
            }),
          ),
          Container(
            width: double.infinity,
            decoration: BoxDecoration(
                border: Border(
                    top:
                        BorderSide(color: Colors.white.withValues(alpha: .1)))),
            child: SafeArea(
              top: false,
              minimum: const EdgeInsets.fromLTRB(20, 16, 20, 16),
              child: Column(mainAxisSize: MainAxisSize.min, children: [
                if (_error != null)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 12),
                    child: Text(_error!,
                        textAlign: TextAlign.center,
                        style: const TextStyle(color: Colors.white)),
                  ),
                Builder(builder: (buttonContext) {
                  return SizedBox(
                    width: double.infinity,
                    child: FilledButton.icon(
                      onPressed: _sharing ? null : () => _share(buttonContext),
                      style: FilledButton.styleFrom(
                          minimumSize: const Size(0, 52),
                          backgroundColor: AppColors.lavender,
                          foregroundColor: AppColors.ink,
                          disabledBackgroundColor: AppColors.paleLavender,
                          disabledForegroundColor: AppColors.ink),
                      icon: _sharing
                          ? const SizedBox(
                              width: 18,
                              height: 18,
                              child: CircularProgressIndicator(
                                  strokeWidth: 2, color: AppColors.ink))
                          : const Icon(Icons.ios_share_rounded, size: 20),
                      label: Text(_sharing
                          ? 'Preparing image…'
                          : 'Share or save image'),
                    ),
                  );
                }),
                const SizedBox(height: 10),
                const Text(
                    'Choose an app or save from your phone’s share menu.',
                    textAlign: TextAlign.center,
                    style: TextStyle(color: Colors.white70, fontSize: 12)),
              ]),
            ),
          ),
        ]),
      );
}

/// The preview itself is the exported image. Notes and account email are never
/// included. Local placeholders keep missing exercise artwork usable offline.
class _WorkoutShareCard extends StatelessWidget {
  final WorkoutResultData data;
  final String displayName;
  const _WorkoutShareCard({required this.data, required this.displayName});

  static const _interactive = Color(0xFF6741B2);
  static const _muted = Color(0xFF696473);

  Widget _metric(IconData icon, Color color, String value) =>
      Row(mainAxisSize: MainAxisSize.min, children: [
        Icon(icon, size: 21, color: color),
        const SizedBox(width: 7),
        Flexible(
          child: Text(value,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style:
                  const TextStyle(fontSize: 18, fontWeight: FontWeight.w600)),
        ),
      ]);

  /// Numbers stay ink and bold; units and separators recede, as in
  /// "45 lb • 10 reps".
  static Widget _result(String label, {TextAlign align = TextAlign.end}) {
    final text = label.replaceFirstMapped(
        RegExp(r' × (\d+)$'), (match) => ' • ${match[1]} reps');
    final spans = <TextSpan>[];
    text.splitMapJoin(RegExp(r'-?\d[\d,.]*'), onMatch: (match) {
      spans.add(TextSpan(
          text: match[0],
          style: const TextStyle(
              fontWeight: FontWeight.w600, color: AppColors.ink)));
      return '';
    }, onNonMatch: (rest) {
      if (rest.isNotEmpty) spans.add(TextSpan(text: rest));
      return '';
    });
    return Text.rich(TextSpan(children: spans),
        textAlign: align,
        style: const TextStyle(
            fontSize: 15, color: _muted, fontWeight: FontWeight.w400));
  }

  static const _prBadge = DecoratedBox(
    decoration: BoxDecoration(
        color: AppColors.coral,
        borderRadius: BorderRadius.all(Radius.circular(8))),
    child: Padding(
      padding: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      child: Text('PR',
          style: TextStyle(
              fontSize: 12, fontWeight: FontWeight.w600, color: Colors.white)),
    ),
  );

  /// The first exercise with artwork represents the workout; the lavender
  /// dumbbell tile covers workouts without any artwork or offline failures.
  Widget _workoutTile() {
    final image = data.exercises
        .map((exercise) => exercise.imageUrl)
        .whereType<String>()
        .where((url) => url.isNotEmpty)
        .firstOrNull;
    const fallback = DecoratedBox(
      decoration: BoxDecoration(
        gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [Color(0xFFDED0FC), AppColors.lavender]),
      ),
      child: Center(
        child:
            Icon(Icons.fitness_center_rounded, color: AppColors.ink, size: 22),
      ),
    );
    return Container(
      width: 46,
      height: 46,
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border:
            image == null ? null : Border.all(color: const Color(0xFFE6E1ED)),
      ),
      child: image == null
          ? fallback
          : Padding(
              padding: const EdgeInsets.all(3),
              child: ExerciseMedia(
                imageUrl: image,
                fit: BoxFit.contain,
                fadeInDuration: Duration.zero,
                placeholder: (_, __) => fallback,
                errorWidget: (_, __, ___) => fallback,
              ),
            ),
    );
  }

  Widget _exercise(WorkoutResultExercise exercise) {
    final image = exercise.imageUrl;
    const placeholder = Icon(Icons.fitness_center_rounded,
        size: 19, color: AppColors.referenceMuted);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 10),
      child: Row(children: [
        Container(
          width: 40,
          height: 40,
          clipBehavior: Clip.antiAlias,
          padding: const EdgeInsets.all(3),
          decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(11),
              boxShadow: const [
                BoxShadow(
                    color: Color(0x0F1D1C21),
                    blurRadius: 6,
                    offset: Offset(0, 2)),
              ]),
          child: image != null && image.isNotEmpty
              ? ExerciseMedia(
                  imageUrl: image,
                  fit: BoxFit.contain,
                  fadeInDuration: Duration.zero,
                  placeholder: (_, __) => placeholder,
                  errorWidget: (_, __, ___) => placeholder,
                )
              : placeholder,
        ),
        const SizedBox(width: 12),
        Expanded(
          child: LayoutBuilder(builder: (context, constraints) {
            final name = Text(exercise.name,
                style: const TextStyle(
                    fontSize: 15, height: 1.3, fontWeight: FontWeight.w500));
            if (constraints.maxWidth < 250 ||
                MediaQuery.textScalerOf(context).scale(1) > 1.3) {
              return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    name,
                    const SizedBox(height: 4),
                    Wrap(
                        spacing: 8,
                        runSpacing: 4,
                        crossAxisAlignment: WrapCrossAlignment.center,
                        children: [
                          _result(exercise.resultLabel, align: TextAlign.start),
                          if (exercise.isNewRecord) _prBadge,
                        ]),
                  ]);
            }
            return Row(children: [
              Expanded(child: name),
              const SizedBox(width: 10),
              ConstrainedBox(
                  constraints:
                      BoxConstraints(maxWidth: constraints.maxWidth * .45),
                  child: FittedBox(
                      fit: BoxFit.scaleDown,
                      alignment: Alignment.centerRight,
                      child: _result(exercise.resultLabel))),
              if (exercise.isNewRecord) ...[
                const SizedBox(width: 10),
                _prBadge,
              ],
            ]);
          }),
        ),
      ]),
    );
  }

  @override
  Widget build(BuildContext context) {
    // Missing measurements are left out rather than shown as placeholders.
    final metrics = [
      if (data.workout.durationSeconds > 0)
        _metric(Icons.timer_outlined, _interactive, data.durationLabel),
      _metric(Icons.done_all_rounded, AppColors.lavender,
          '${data.completedSets} ${data.completedSets == 1 ? 'set' : 'sets'}'),
      if (data.volumeLabel != '—')
        _metric(
            Icons.fitness_center_rounded, AppColors.coral, data.volumeLabel),
    ];
    return Container(
      width: double.infinity,
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
          color: AppColors.referencePanel,
          borderRadius: BorderRadius.circular(28),
          border: Border.all(color: const Color(0xFFE6E1ED))),
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        Container(
          color: Colors.white,
          padding: const EdgeInsets.fromLTRB(22, 22, 22, 24),
          child:
              Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Row(children: [
              Container(
                width: 46,
                height: 46,
                alignment: Alignment.center,
                decoration: const BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: [AppColors.lavender, _interactive]),
                ),
                child: Text(displayName.characters.first.toUpperCase(),
                    style: const TextStyle(
                        fontSize: 19,
                        fontWeight: FontWeight.w600,
                        color: Colors.white)),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(displayName,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                              fontSize: 16, fontWeight: FontWeight.w500)),
                      const SizedBox(height: 2),
                      Text(
                          DateFormat('MMM d, yyyy')
                              .format(data.workout.timestamp.toLocal()),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                              fontSize: 13, color: Color(0xFF8A72D8))),
                    ]),
              ),
              const SizedBox(width: 8),
              const Text('S W E A T M A R K',
                  style: TextStyle(
                      fontSize: 10,
                      letterSpacing: 1.6,
                      fontWeight: FontWeight.w700,
                      color: AppColors.ink)),
            ]),
            const SizedBox(height: 22),
            Row(children: [
              _workoutTile(),
              const SizedBox(width: 14),
              Expanded(
                child: Text(data.workout.workoutName,
                    style: const TextStyle(
                        fontSize: 27,
                        height: 1.15,
                        fontWeight: FontWeight.w600,
                        letterSpacing: -.4)),
              ),
            ]),
            const SizedBox(height: 22),
            SizedBox(
              width: double.infinity,
              child: Wrap(
                alignment: metrics.length > 1
                    ? WrapAlignment.spaceBetween
                    : WrapAlignment.start,
                spacing: 18,
                runSpacing: 12,
                children: metrics,
              ),
            ),
          ]),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(22, 18, 22, 34),
          child:
              Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            for (final exercise in data.exercises) _exercise(exercise),
          ]),
        ),
      ]),
    );
  }
}
