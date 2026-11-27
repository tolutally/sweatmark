import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../models/workout_result.dart';
import '../state/auth_notifier.dart';
import '../theme/app_theme.dart';
import '../widgets/share_image_sheet.dart';
import 'monthly_wrap_screen.dart';

Future<void> showWorkoutShare(
    BuildContext context, WorkoutResultData data) async {
  final name = context.read<AuthNotifier>().user?.displayName?.trim();
  await showShareImage(
    context,
    title: 'Share result',
    shareTitle: data.workout.workoutName,
    fileName: 'sweatmark-workout-${data.workout.id}.png',
    previewKey: const ValueKey('workout-share-card'),
    canvas: ShareCanvas.reel,
    card: WorkoutShareCard(
        data: data, displayName: name == null || name.isEmpty ? null : name),
  );
}

/// The exported image, 9:16 for stories: streak, totals, top set, muscles
/// worked and the exercises with their sets, on white with the brand
/// purple, lime, lavender and coral. Spare space is shared between the
/// sections so the card is full; exercises that don't fit end in
/// "+N more". Notes and account email are never included; the person's
/// name appears only when they set one.
class WorkoutShareCard extends StatelessWidget {
  final WorkoutResultData data;
  final String? displayName;
  const WorkoutShareCard(
      {super.key, required this.data, required this.displayName});

  /// Layout size; [ShareCanvas.reel] exports it at 1080 × 1920.
  static const size = Size(360, 640);

  static const _purple = MonthlyWrapCard.purple;
  static const _panel = Color(0xFFF6F4FC);
  static const _divider = Color(0xFFE2DCF3);
  static const _line = Color(0xFFECE8F2);
  static const _muted = AppColors.referenceMuted;
  static const _coralWash = Color(0xFFFFECEC);
  static const _coralText = Color(0xFFB3262E);
  static const _outline = Color(0xFFCFC6E8);

  // Heights used to decide how many exercise rows fit. Text is laid out
  // unscaled (see [build]), so these hold on every phone.
  static const _rowHeight = 33.0;
  static const _minGap = 10.0;

  static Widget _dot(Color color, {double size = 6}) => Container(
      width: size,
      height: size,
      decoration: BoxDecoration(color: color, shape: BoxShape.circle));

  static Widget _stat(String value, String label, Color dot) => Expanded(
        child: Column(children: [
          SizedBox(
            height: 18,
            child: FittedBox(
              fit: BoxFit.scaleDown,
              child: Text(value,
                  maxLines: 1,
                  style: const TextStyle(
                      fontSize: 13.5,
                      fontWeight: FontWeight.w600,
                      color: AppColors.ink)),
            ),
          ),
          const SizedBox(height: 2),
          Row(mainAxisAlignment: MainAxisAlignment.center, children: [
            _dot(dot),
            const SizedBox(width: 4),
            Flexible(
              child: Text(label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontSize: 11, color: _muted)),
            ),
          ]),
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

  static Widget _chip(String muscle, {required bool primary}) => Container(
        padding: EdgeInsets.symmetric(
            horizontal: primary ? 9 : 8, vertical: primary ? 3 : 2),
        decoration: BoxDecoration(
            color: primary ? AppColors.lavender : Colors.white,
            borderRadius: BorderRadius.circular(99),
            border: primary ? null : Border.all(color: _outline)),
        child: Text(muscle,
            style: TextStyle(
                fontSize: 11,
                fontWeight: primary ? FontWeight.w600 : FontWeight.w400,
                color: primary ? AppColors.ink : const Color(0xFF4A4553))),
      );

  static const _sectionTitle = TextStyle(
      fontSize: 11.5, fontWeight: FontWeight.w600, color: AppColors.ink);

  /// Lines the muscle chips wrap onto, estimated from their text.
  static int _chipLines(List<String> muscles, double width) {
    var lines = 1;
    var used = 0.0;
    for (final muscle in muscles) {
      final chip = muscle.length * 6.4 + 20;
      if (used > 0 && used + 5 + chip > width) {
        lines++;
        used = chip;
      } else {
        used += (used > 0 ? 5 : 0) + chip;
      }
    }
    return lines;
  }

  /// The result as worth sharing: notes about what an older log didn't
  /// record ("weight unit not recorded") stay on the detail screen.
  static String _shareLabel(String label) => label
      .split(' · ')
      .where((part) => !part.endsWith('not recorded'))
      .join(' · ');

  Widget _exerciseRow(WorkoutResultExercise row, {required bool top}) =>
      SizedBox(
        height: _rowHeight,
        child: Row(children: [
          _dot(top ? AppColors.coral : _purple),
          const SizedBox(width: 8),
          Expanded(
            child: Text(row.name,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(fontSize: 12, color: AppColors.ink)),
          ),
          const SizedBox(width: 6),
          // The name takes the rest, so the set pills line up on the right.
          ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 150),
            child: Text(_shareLabel(row.resultLabel),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                textAlign: TextAlign.end,
                style: const TextStyle(fontSize: 11, color: _muted)),
          ),
          if (row.sets > 0) ...[
            const SizedBox(width: 6),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
              decoration: BoxDecoration(
                  color: Colors.white, borderRadius: BorderRadius.circular(99)),
              child: Text(row.sets == 1 ? '1 set' : '${row.sets} sets',
                  style: const TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                      color: AppColors.ink)),
            ),
          ],
        ]),
      );

  @override
  Widget build(BuildContext context) {
    final date =
        DateFormat('EEE, MMM d, yyyy').format(data.workout.timestamp.toLocal());
    final volume = _volume(data.volumeLabel);
    final exercises = data.exerciseCount;
    final top = data.topSet;
    final streak = data.streakWeeks;
    // Missing measurements are left out rather than shown as placeholders.
    final stats = [
      if (data.workout.durationSeconds > 0)
        _stat(data.durationLabel, 'time', _purple),
      _stat('${data.completedSets}', data.completedSets == 1 ? 'set' : 'sets',
          AppColors.lime),
      _stat('$exercises', exercises == 1 ? 'exercise' : 'exercises',
          AppColors.lavender),
      if (volume != null)
        _stat(volume.$1, '${volume.$2} lifted'.trim(), AppColors.coral),
    ];
    final muscles = [
      for (final m in data.primaryMuscles) (m, true),
      for (final m in data.secondaryMuscles) (m, false),
    ];

    const padding = EdgeInsets.fromLTRB(16, 18, 16, 12);
    final inner = size.width - padding.horizontal;

    // How many exercise rows fit once every other section is placed with
    // its smallest gap; the rest become "+N more".
    var fixed = padding.vertical + 70 + 49; // header, stats
    var sections = 2;
    if (top != null) {
      fixed += 46;
      sections++;
    }
    if (muscles.isNotEmpty) {
      final lines = _chipLines(muscles.map((m) => m.$1).toList(), inner);
      fixed += 20 + lines * 22 + (lines - 1) * 5;
      sections++;
    }
    final rows = data.exercises;
    fixed += 19 + 4 + 25; // list title, list padding, footer
    fixed += sections * _minGap;
    var shown = math.max(0, ((size.height - fixed) / _rowHeight).floor());
    if (shown < rows.length) {
      shown = math.max(0, ((size.height - fixed - 22) / _rowHeight).floor());
    }
    shown = math.min(shown, rows.length);
    final hidden = rows.length - shown;

    final card = Container(
      width: size.width,
      height: size.height,
      padding: padding,
      decoration: BoxDecoration(
          color: Colors.white, borderRadius: BorderRadius.circular(22)),
      child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Row(children: [
                MonthlyWrapCard.logo(20),
                const SizedBox(width: 7),
                const Expanded(
                  child: Text('SweatMark',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                          fontSize: 12.5,
                          fontWeight: FontWeight.w600,
                          color: AppColors.ink)),
                ),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                      color:
                          streak > 0 ? AppColors.lime : AppColors.paleLavender,
                      borderRadius: BorderRadius.circular(99)),
                  child: Row(mainAxisSize: MainAxisSize.min, children: [
                    if (streak > 0) ...[
                      const Icon(Icons.local_fire_department_rounded,
                          size: 12, color: AppColors.ink),
                      const SizedBox(width: 3),
                    ],
                    Text(streak > 0 ? '$streak-week streak' : 'Complete',
                        style: const TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                            color: AppColors.ink)),
                  ]),
                ),
              ]),
              const SizedBox(height: 14),
              Text(data.workout.workoutName,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                      fontSize: 18,
                      height: 1.15,
                      fontWeight: FontWeight.w600,
                      color: AppColors.ink)),
              const SizedBox(height: 2),
              Text(displayName == null ? date : '$displayName · $date',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontSize: 11, color: _muted)),
            ]),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 9),
              decoration: BoxDecoration(
                  color: _panel, borderRadius: BorderRadius.circular(12)),
              child: Row(children: [
                for (var i = 0; i < stats.length; i++) ...[
                  if (i > 0) Container(width: 1, height: 24, color: _divider),
                  stats[i],
                ],
              ]),
            ),
            if (top != null)
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 11, vertical: 9),
                decoration: BoxDecoration(
                    color: _coralWash, borderRadius: BorderRadius.circular(12)),
                child: Row(children: [
                  Container(
                    width: 26,
                    height: 26,
                    decoration: const BoxDecoration(
                        color: AppColors.coral, shape: BoxShape.circle),
                    child: const Icon(Icons.emoji_events_rounded,
                        size: 14, color: Colors.white),
                  ),
                  const SizedBox(width: 9),
                  Expanded(
                    child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text('Top set',
                              style: TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.w600,
                                  color: _coralText)),
                          Text(top.exerciseName,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w600,
                                  color: AppColors.ink)),
                        ]),
                  ),
                  const SizedBox(width: 8),
                  Flexible(
                    child: Row(
                        mainAxisSize: MainAxisSize.min,
                        mainAxisAlignment: MainAxisAlignment.end,
                        children: [
                          Flexible(
                            child: Text(top.label,
                                maxLines: 2,
                                textAlign: TextAlign.end,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(
                                    fontSize: 12.5,
                                    fontWeight: FontWeight.w600,
                                    color: AppColors.ink)),
                          ),
                          if (top.isNewRecord) ...[
                            const SizedBox(width: 5),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 5, vertical: 1),
                              decoration: BoxDecoration(
                                  color: AppColors.lime,
                                  borderRadius: BorderRadius.circular(5)),
                              child: const Text('PR',
                                  style: TextStyle(
                                      fontSize: 11,
                                      fontWeight: FontWeight.w700,
                                      color: AppColors.ink)),
                            ),
                          ],
                        ]),
                  ),
                ]),
              ),
            if (muscles.isNotEmpty)
              Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                const Text('Muscles worked', style: _sectionTitle),
                const SizedBox(height: 6),
                Wrap(spacing: 5, runSpacing: 5, children: [
                  for (final (muscle, primary) in muscles)
                    _chip(muscle, primary: primary),
                ]),
              ]),
            // The exercises, with the footer straight under them.
            Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
              const Text('Exercises', style: _sectionTitle),
              const SizedBox(height: 5),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 11, vertical: 2),
                decoration: BoxDecoration(
                    color: _panel, borderRadius: BorderRadius.circular(12)),
                child: Column(children: [
                  for (var i = 0; i < shown; i++) ...[
                    if (i > 0) Container(height: 1, color: _line),
                    _exerciseRow(rows[i],
                        top: top != null && rows[i].name == top.exerciseName),
                  ],
                  if (hidden > 0) ...[
                    if (shown > 0) Container(height: 1, color: _line),
                    SizedBox(
                      height: 22,
                      child: Center(
                        child: Text(
                            hidden == 1
                                ? '+1 more exercise'
                                : '+$hidden more exercises',
                            style:
                                const TextStyle(fontSize: 11, color: _muted)),
                      ),
                    ),
                  ],
                ]),
              ),
              const SizedBox(height: 10),
              Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                const Text('Tracked with',
                    style: TextStyle(fontSize: 11, color: _muted)),
                const SizedBox(width: 6),
                MonthlyWrapCard.logo(15),
                const SizedBox(width: 4),
                const Text('SweatMark',
                    style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                        color: AppColors.ink)),
              ]),
            ]),
          ]),
    );
    // The image looks the same whatever text size the phone uses.
    return MediaQuery.withNoTextScaling(child: card);
  }
}
