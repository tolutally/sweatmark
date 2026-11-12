import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../models/workout_result.dart';
import '../state/auth_notifier.dart';
import '../theme/app_theme.dart';
import '../widgets/share_image_sheet.dart';

Future<void> showWorkoutShare(
    BuildContext context, WorkoutResultData data) async {
  final name = context.read<AuthNotifier>().user?.displayName?.trim();
  await showShareImage(
    context,
    title: 'Share result',
    shareTitle: data.workout.workoutName,
    fileName: 'sweatmark-workout-${data.workout.id}.png',
    previewKey: const ValueKey('workout-share-card'),
    card: _WorkoutShareCard(
        data: data, displayName: name == null || name.isEmpty ? null : name),
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
