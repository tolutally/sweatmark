import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import '../state/workout_notifier.dart';
import '../state/settings_notifier.dart';
import '../services/pr_service.dart';
import '../theme/app_theme.dart';
import '../screens/exercise_progress_screen.dart';

class BestRecordBadge extends StatelessWidget {
  final String exerciseId;
  const BestRecordBadge(this.exerciseId, {super.key});
  @override
  Widget build(BuildContext context) {
    final records =
        context.watch<WorkoutNotifier>().bestForExercise(exerciseId);
    final unit = context.watch<SettingsNotifier>().weightSuffix;
    if (records.isEmpty) return const SizedBox.shrink();
    return Text(records.map((r) => '🏆 Best: ${r.label(unit)}').join('\n'),
        style: TextStyle(
            fontSize: 13,
            color: AppDesign.of(context).record,
            fontWeight: FontWeight.w600));
  }
}

class SetRecordBadge extends StatelessWidget {
  final String exerciseId;
  final int setIndex;
  const SetRecordBadge(this.exerciseId, this.setIndex, {super.key});
  @override
  Widget build(BuildContext context) {
    final matches = context.watch<WorkoutNotifier>().activeRecords.where((r) =>
        r.exerciseId == exerciseId && r.setIndex == setIndex && !r.isBaseline);
    if (matches.isEmpty) return const SizedBox.shrink();
    final design = AppDesign.of(context);
    return Padding(
        padding: const EdgeInsets.only(right: 4),
        child: Tooltip(
            message: 'New PR',
            child: Column(mainAxisSize: MainAxisSize.min, children: [
              Icon(Icons.emoji_events_rounded, size: 16, color: design.record),
              Text('New PR',
                  style: TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.w600,
                      color: design.record)),
            ])));
  }
}

class RecordList extends StatelessWidget {
  final List<PersonalRecord> records;
  final String emptyMessage;
  const RecordList(this.records,
      {super.key, this.emptyMessage = 'No personal records yet.'});

  @override
  Widget build(BuildContext context) {
    final unit = context.watch<SettingsNotifier>().weightSuffix;
    final colors = Theme.of(context).colorScheme;
    final text = Theme.of(context).textTheme;
    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      if (records.isEmpty && emptyMessage.isNotEmpty)
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 16),
          child: Text(emptyMessage,
              style: text.bodyLarge?.copyWith(color: colors.onSurfaceVariant)),
        ),
      for (var i = 0; i < records.length; i++) ...[
        if (i > 0) const SizedBox(height: 12),
        _recordCard(context, records[i], unit),
      ],
    ]);
  }

  Widget _recordCard(BuildContext context, PersonalRecord record, String unit) {
    final colors = Theme.of(context).colorScheme;
    final text = Theme.of(context).textTheme;
    final design = AppDesign.of(context);
    return Material(
      color: colors.surface,
      borderRadius: BorderRadius.circular(24),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: () => Navigator.of(context).push(MaterialPageRoute(
            builder: (_) => ExerciseProgressScreen(
                exerciseId: record.exerciseId, name: record.exerciseName))),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child:
              Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Container(
                width: 42,
                height: 42,
                decoration: const BoxDecoration(
                    color: AppColors.lavender, shape: BoxShape.circle),
                child: const Icon(Icons.emoji_events_outlined,
                    color: AppColors.ink, size: 21),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(record.exerciseName, style: text.titleMedium),
                      const SizedBox(height: 4),
                      Text(
                          'Logged ${DateFormat('MMM d, yyyy · h:mm a').format(record.timestamp.toLocal())}',
                          style: text.bodySmall
                              ?.copyWith(color: colors.onSurfaceVariant)),
                    ]),
              ),
              const SizedBox(width: 8),
              Container(
                width: 30,
                height: 34,
                decoration: BoxDecoration(
                    color: colors.surfaceContainer,
                    borderRadius: BorderRadius.circular(12)),
                child: Icon(Icons.chevron_right_rounded,
                    size: 18, color: colors.onSurfaceVariant),
              ),
            ]),
            const SizedBox(height: 14),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                  color: colors.surfaceContainer,
                  borderRadius: BorderRadius.circular(19)),
              child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(record.label(unit), style: text.headlineSmall),
                    const SizedBox(height: 7),
                    Wrap(spacing: 8, runSpacing: 6, children: [
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 9, vertical: 4),
                        decoration: BoxDecoration(
                            color: design.recordContainer,
                            borderRadius: BorderRadius.circular(12)),
                        child: Text(
                            record.isBaseline ? 'First best saved' : 'New PR',
                            style: text.labelSmall
                                ?.copyWith(color: design.onRecordContainer)),
                      ),
                      if (record.previous != null)
                        Padding(
                          padding: const EdgeInsets.symmetric(vertical: 4),
                          child: Text(
                              'Previous: ${record.previous!.label(unit)}',
                              style: text.bodySmall
                                  ?.copyWith(color: colors.onSurfaceVariant)),
                        ),
                    ]),
                  ]),
            ),
          ]),
        ),
      ),
    );
  }
}

/// Small, finite celebration within the snackbar; no full-screen interruption.
class RecordCelebration extends StatelessWidget {
  final String message;
  const RecordCelebration(this.message, {super.key});
  @override
  Widget build(BuildContext context) {
    final reduced = MediaQuery.of(context).disableAnimations;
    final text = Text(message,
        style: TextStyle(color: AppDesign.of(context).onRecordContainer));
    final palette = [
      AppDesign.of(context).record,
      Theme.of(context).colorScheme.secondary,
      AppDesign.of(context).onRecordContainer
    ];
    if (reduced) return text;
    return TweenAnimationBuilder<double>(
        tween: Tween(begin: 0, end: 1),
        duration: const Duration(milliseconds: 1100),
        child: text,
        builder: (_, progress, child) => CustomPaint(
            foregroundPainter: _Confetti(progress, palette),
            child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 8),
                child: child)));
  }
}

class _Confetti extends CustomPainter {
  final double progress;
  final List<Color> palette;
  _Confetti(this.progress, this.palette);
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint();
    for (var i = 0; i < 16; i++) {
      paint.color = palette[i % palette.length].withValues(alpha: 1 - progress);
      final x = size.width * (i + 0.5) / 16;
      final y = size.height * progress + math.sin(i.toDouble()) * 12;
      canvas.drawCircle(Offset(x, y), 2.5, paint);
    }
  }

  @override
  bool shouldRepaint(_Confetti oldDelegate) =>
      oldDelegate.progress != progress || oldDelegate.palette != palette;
}
