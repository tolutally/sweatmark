import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'package:share_plus/share_plus.dart';

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
          data: data, displayName: name == null || name.isEmpty ? null : name),
    ),
  );
}

class _WorkoutShareSheet extends StatefulWidget {
  final WorkoutResultData data;
  final String? displayName;
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
                      child: KeyedSubtree(
                        key: const ValueKey('workout-share-card'),
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

/// The preview itself is the exported image: streak, totals, top set and
/// muscles worked. The exercise list stays on the in-app summary so the image
/// is clean. Notes and account email are never included; the person's name
/// appears only when they set one.
class _WorkoutShareCard extends StatelessWidget {
  final WorkoutResultData data;
  final String? displayName;
  const _WorkoutShareCard({required this.data, required this.displayName});

  static const _muted = Color(0xFF6E6A78);
  static const _line = Color(0xFFECE8F2);
  static const _coralWash = Color(0xFFFFECEC);
  static const _coralText = Color(0xFFB3262E);

  static const _prBadge = DecoratedBox(
    decoration: BoxDecoration(
        color: AppColors.lime,
        borderRadius: BorderRadius.all(Radius.circular(5))),
    child: Padding(
      padding: EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      child: Text('PR',
          style: TextStyle(
              fontSize: 10,
              fontWeight: FontWeight.w700,
              letterSpacing: .3,
              color: AppColors.ink)),
    ),
  );

  Widget _brand({double size = 28, bool light = true}) =>
      Row(mainAxisSize: MainAxisSize.min, children: [
        ClipRRect(
          borderRadius: BorderRadius.circular(size * .28),
          child: Image.asset('assets/icon.png',
              width: size, height: size, fit: BoxFit.cover),
        ),
        SizedBox(width: size * .32),
        Flexible(
          child: Text('SweatMark',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                  fontSize: size * .55,
                  fontWeight: FontWeight.w700,
                  letterSpacing: -.3,
                  color: light ? Colors.white : AppColors.ink)),
        ),
      ]);

  Widget _stat(String value, String label) => Expanded(
        child: Column(children: [
          SizedBox(
            height: 22,
            child: FittedBox(
              fit: BoxFit.scaleDown,
              child: Text(value,
                  maxLines: 1,
                  style: const TextStyle(
                      fontSize: 17,
                      fontWeight: FontWeight.w600,
                      letterSpacing: -.2,
                      color: Colors.white)),
            ),
          ),
          const SizedBox(height: 3),
          Text(label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 11, color: Color(0xFF9C97A8))),
        ]),
      );

  /// "41,444 lb" becomes ("41.4k", "lb") so four totals fit one row.
  static (String, String)? _volume(String label) {
    if (label == '—') return null;
    final space = label.lastIndexOf(' ');
    if (space < 0) return (label, '');
    final unit = label.substring(space + 1);
    final number = num.tryParse(label.substring(0, space).replaceAll(',', ''));
    final value = number == null
        ? label.substring(0, space)
        : number >= 10000
            ? '${(number / 1000).toStringAsFixed(1)}k'
            : NumberFormat('#,##0').format(number);
    return (value, unit);
  }

  Widget _chips(String title, List<String> muscles, {required bool primary}) =>
      Padding(
        padding: const EdgeInsets.fromLTRB(20, 18, 20, 0),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(title,
              style: const TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: AppColors.ink)),
          const SizedBox(height: 9),
          Wrap(spacing: 6, runSpacing: 6, children: [
            for (final muscle in muscles)
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 11, vertical: 5),
                decoration: BoxDecoration(
                    color: primary ? AppColors.lavender : Colors.white,
                    borderRadius: BorderRadius.circular(99),
                    border: primary
                        ? null
                        : Border.all(color: const Color(0xFFCFC6E8))),
                child: Text(muscle,
                    style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w500,
                        color:
                            primary ? AppColors.ink : const Color(0xFF4A4553))),
              ),
          ]),
        ]),
      );

  @override
  Widget build(BuildContext context) {
    final date = DateFormat('EEEE, MMM d, yyyy')
        .format(data.workout.timestamp.toLocal());
    final volume = _volume(data.volumeLabel);
    final exercises = data.exerciseCount;
    // Missing measurements are left out rather than shown as placeholders.
    final stats = [
      if (data.workout.durationSeconds > 0) _stat(data.durationLabel, 'time'),
      _stat('${data.completedSets}', data.completedSets == 1 ? 'set' : 'sets'),
      _stat('$exercises', exercises == 1 ? 'exercise' : 'exercises'),
      if (volume != null) _stat(volume.$1, '${volume.$2} lifted'.trim()),
    ];
    final top = data.topSet;
    final streak = data.streakWeeks;
    return Container(
      width: double.infinity,
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
          color: Colors.white, borderRadius: BorderRadius.circular(26)),
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        Container(
          color: AppColors.ink,
          padding: const EdgeInsets.fromLTRB(20, 18, 20, 20),
          child:
              Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Row(children: [
              Expanded(
                  child:
                      Align(alignment: Alignment.centerLeft, child: _brand())),
              const SizedBox(width: 10),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                decoration: BoxDecoration(
                    color: streak > 0
                        ? AppColors.lime
                        : AppColors.lavender.withValues(alpha: .2),
                    borderRadius: BorderRadius.circular(99)),
                child: Row(mainAxisSize: MainAxisSize.min, children: [
                  if (streak > 0) ...[
                    const Icon(Icons.local_fire_department_rounded,
                        size: 13, color: AppColors.ink),
                    const SizedBox(width: 3),
                  ],
                  Text(streak > 0 ? '$streak-week streak' : 'Complete',
                      style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                          color:
                              streak > 0 ? AppColors.ink : AppColors.lavender)),
                ]),
              ),
            ]),
            const SizedBox(height: 20),
            Text(data.workout.workoutName,
                style: const TextStyle(
                    fontSize: 25,
                    height: 1.12,
                    fontWeight: FontWeight.w600,
                    letterSpacing: -.5,
                    color: Colors.white)),
            const SizedBox(height: 6),
            Text(displayName == null ? date : '$displayName · $date',
                style: const TextStyle(fontSize: 12, color: Color(0xFFB8B3C2))),
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 12),
              decoration: BoxDecoration(
                  color: const Color(0xFF2A2830),
                  borderRadius: BorderRadius.circular(14)),
              child: Row(children: [
                for (var i = 0; i < stats.length; i++) ...[
                  if (i > 0)
                    Container(
                        width: 1, height: 30, color: const Color(0xFF44414D)),
                  stats[i],
                ],
              ]),
            ),
          ]),
        ),
        if (top != null)
          Container(
            margin: const EdgeInsets.fromLTRB(20, 16, 20, 0),
            padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
            decoration: BoxDecoration(
                color: _coralWash, borderRadius: BorderRadius.circular(14)),
            child: Row(children: [
              Container(
                width: 36,
                height: 36,
                decoration: const BoxDecoration(
                    color: AppColors.coral, shape: BoxShape.circle),
                child: const Icon(Icons.emoji_events_rounded,
                    size: 19, color: Colors.white),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('Top set',
                          style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w500,
                              color: _coralText)),
                      const SizedBox(height: 1),
                      Text(top.exerciseName,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                              fontSize: 14,
                              height: 1.25,
                              fontWeight: FontWeight.w600,
                              color: AppColors.ink)),
                    ]),
              ),
              const SizedBox(width: 10),
              Flexible(
                child: Align(
                  alignment: Alignment.centerRight,
                  child: Column(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Text(top.label,
                            textAlign: TextAlign.end,
                            style: const TextStyle(
                                fontSize: 15,
                                fontWeight: FontWeight.w600,
                                color: AppColors.ink)),
                        if (top.isNewRecord) ...[
                          const SizedBox(height: 4),
                          _prBadge,
                        ],
                      ]),
                ),
              ),
            ]),
          ),
        if (data.primaryMuscles.isNotEmpty)
          _chips('Primary muscles worked', data.primaryMuscles, primary: true),
        if (data.secondaryMuscles.isNotEmpty)
          _chips('Secondary muscles worked', data.secondaryMuscles,
              primary: false),
        Container(
          margin: const EdgeInsets.only(top: 20),
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 14),
          decoration: const BoxDecoration(
              border: Border(top: BorderSide(color: _line))),
          child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
            const Text('Tracked with',
                style: TextStyle(fontSize: 11, color: _muted)),
            const SizedBox(width: 7),
            Flexible(child: _brand(size: 18, light: false)),
          ]),
        ),
      ]),
    );
  }
}
