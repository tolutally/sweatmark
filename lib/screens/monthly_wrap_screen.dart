import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../models/monthly_wrap.dart';
import '../state/auth_notifier.dart';
import '../theme/app_theme.dart';
import '../widgets/muscle_icon.dart';
import '../widgets/share_image_sheet.dart';

/// Opens the shareable wrap for one month. The image is 1080 × 1920, the
/// size used for reels and stories.
Future<void> showMonthlyWrap(BuildContext context, MonthlyWrap wrap,
    {String weightUnit = 'kg', bool miles = false}) {
  final name = context.read<AuthNotifier?>()?.user?.displayName?.trim();
  final month = DateFormat('MMMM yyyy').format(wrap.month);
  return showShareImage(
    context,
    title: '${DateFormat('MMMM').format(wrap.month)} wrap',
    shareTitle: 'My $month on SweatMark',
    fileName: 'sweatmark-wrap-${DateFormat('yyyy-MM').format(wrap.month)}.png',
    previewKey: const ValueKey('monthly-wrap-card'),
    canvas: ShareCanvas.reel,
    card: MonthlyWrapCard(
        wrap: wrap,
        weightUnit: weightUnit,
        miles: miles,
        displayName: name == null || name.isEmpty ? null : name),
  );
}

/// The exported image, laid out on a 9:16 canvas: a motivating headline,
/// activity rings, the month's numbers and what was trained most. Notes,
/// email and workout names are never included; the person's name appears
/// only when they set one.
class MonthlyWrapCard extends StatelessWidget {
  final MonthlyWrap wrap;
  final String weightUnit;
  final bool miles;
  final String? displayName;
  const MonthlyWrapCard(
      {super.key,
      required this.wrap,
      this.weightUnit = 'kg',
      this.miles = false,
      this.displayName});

  /// Layout size; [ShareCanvas.reel] exports it at 1080 × 1920.
  static const size = Size(360, 640);

  static const _background = Color(0xFFF6F4FC);
  static const _muted = AppColors.referenceMuted;
  static const _chip = Color(0xFFF3F2F6);

  /// The app's deeper purple (its accent color), for the active-days ring.
  static const purple = Color(0xFF6741B2);
  static final _number = NumberFormat.decimalPattern();

  /// "23 min" or "4.2 hrs", split so the unit can be set smaller.
  static (String, String) _time(int seconds) {
    final minutes = (seconds / 60).round();
    if (minutes < 60) return ('$minutes', 'min');
    final hours = minutes / 60;
    return (
      hours.toStringAsFixed(hours >= 10 ? 0 : 1).replaceFirst('.0', ''),
      'hrs'
    );
  }

  String? get _volume {
    final kg = wrap.volumeKg;
    if (kg == null) return null;
    final value = kg * (weightUnit == 'lb' ? 2.2046226218 : 1);
    return value >= 10000
        ? '${(value / 1000).toStringAsFixed(1)}k'
        : _number.format(value.round());
  }

  String _distanceValue(double km) {
    final value = miles ? km / 1.609344 : km;
    return value.toStringAsFixed(value >= 100 ? 0 : 1);
  }

  /// The purple SweatMark mark on its own, without the app icon's dark
  /// square. The artwork has wide padding, so it's drawn larger and centred.
  static Widget _logo(double size) => SizedBox(
        width: size,
        height: size,
        child: OverflowBox(
          maxWidth: size * 2.4,
          maxHeight: size * 2.4,
          child: Image.asset('assets/icon-foreground.png',
              width: size * 2.4, height: size * 2.4, fit: BoxFit.contain),
        ),
      );

  static Widget _circle(Widget icon, Color color, {double size = 36}) =>
      Container(
        width: size,
        height: size,
        alignment: Alignment.center,
        decoration: BoxDecoration(color: color, shape: BoxShape.circle),
        child: icon,
      );

  static Widget _icon(IconData icon, {Color color = AppColors.ink}) =>
      Icon(icon, size: 17, color: color);

  /// A bold number with a smaller muted unit: "6 sets".
  static Widget _value(String value, String unit, {double size = 19}) =>
      Text.rich(
        TextSpan(children: [
          TextSpan(
              text: value,
              style: TextStyle(
                  fontSize: size,
                  fontWeight: FontWeight.w600,
                  letterSpacing: -.4,
                  color: AppColors.ink)),
          if (unit.isNotEmpty)
            TextSpan(
                text: ' $unit',
                style: TextStyle(
                    fontSize: size * .66,
                    fontWeight: FontWeight.w500,
                    color: _muted)),
        ]),
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
      );

  /// A white stat tile: colored icon circle, then the number.
  static Widget _stat(Widget icon, Color circle, String value, String unit) =>
      Container(
        padding: const EdgeInsets.fromLTRB(8, 8, 10, 8),
        decoration: BoxDecoration(
            color: Colors.white, borderRadius: BorderRadius.circular(20)),
        child: Row(children: [
          _circle(icon, circle),
          const SizedBox(width: 9),
          Expanded(
            child: FittedBox(
              fit: BoxFit.scaleDown,
              alignment: Alignment.centerLeft,
              child: _value(value, unit),
            ),
          ),
        ]),
      );

  static Widget _legend(Color color, String value, String label) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 5),
        child: Row(children: [
          Container(
              width: 10,
              height: 10,
              decoration: BoxDecoration(color: color, shape: BoxShape.circle)),
          const SizedBox(width: 8),
          Expanded(
            child:
                Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              FittedBox(
                fit: BoxFit.scaleDown,
                alignment: Alignment.centerLeft,
                child: Text(value,
                    maxLines: 1,
                    style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                        letterSpacing: -.3,
                        color: AppColors.ink)),
              ),
              Text(label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontSize: 11.5, color: _muted)),
            ]),
          ),
        ]),
      );

  @override
  Widget build(BuildContext context) {
    final monthLabel = DateFormat('MMMM yyyy').format(wrap.month);
    final cheer = wrap.cheer;
    final top = wrap.topExercise;
    final steps = wrap.stepsPerDay;
    final cardioMinutes = (wrap.cardioSeconds / 60).round();
    final cardioGoal =
        (MonthlyWrap.weeklyCardioMinutes * wrap.days / 7).round();
    final time = wrap.totalSeconds == null ? null : _time(wrap.totalSeconds!);
    final volume = _volume;
    final moved = wrap.cardioKm ?? wrap.health?.distanceKm;

    final rings = <_Ring>[
      _Ring(wrap.activeShare, purple),
      if (wrap.cardioSessions > 0) _Ring(wrap.cardioShare, AppColors.coral),
      if (steps != null) _Ring(steps / MonthlyWrap.dailySteps, AppColors.lime),
    ];

    final stats = [
      if (wrap.strengthSets > 0)
        _stat(
            _icon(Icons.fitness_center_rounded),
            AppColors.paleLavender,
            _number.format(wrap.strengthSets),
            wrap.strengthSets == 1 ? 'set' : 'sets'),
      if (time != null)
        _stat(_icon(Icons.timer_outlined), AppColors.lime, time.$1, time.$2),
      if (volume != null)
        _stat(_icon(Icons.trending_up_rounded, color: Colors.white),
            AppColors.coral, volume, '$weightUnit lifted'),
      if (wrap.records.isNotEmpty)
        _stat(_icon(Icons.emoji_events_rounded), AppColors.lime,
            '${wrap.records.length}', wrap.records.length == 1 ? 'PR' : 'PRs'),
      if (wrap.longestStreak > 1)
        _stat(_icon(Icons.local_fire_department_rounded, color: Colors.white),
            purple, '${wrap.longestStreak}', 'day streak'),
      if (moved != null && moved > 0)
        _stat(
            const MuscleIcon('cardio', size: 18, color: Colors.white),
            AppColors.coral,
            _distanceValue(moved),
            '${miles ? 'mi' : 'km'} moved'),
    ].take(4).toList();

    final content = Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Motivation first: the month's best result, in a line.
          Text(cheer.title,
              maxLines: 2,
              style: const TextStyle(
                  fontSize: 25,
                  height: 1.1,
                  fontWeight: FontWeight.w600,
                  letterSpacing: -.6,
                  color: AppColors.ink)),
          const SizedBox(height: 6),
          Text(cheer.detail,
              maxLines: 2,
              style:
                  const TextStyle(fontSize: 13.5, height: 1.35, color: _muted)),
          const SizedBox(height: 14),
          Container(
            padding: const EdgeInsets.fromLTRB(12, 12, 14, 12),
            decoration: BoxDecoration(
                color: Colors.white, borderRadius: BorderRadius.circular(24)),
            child: Row(children: [
              SizedBox(
                width: 150,
                height: 150,
                child: CustomPaint(
                  painter: _Rings(rings),
                  child: Center(
                    child: Column(mainAxisSize: MainAxisSize.min, children: [
                      Text('${wrap.workouts}',
                          style: const TextStyle(
                              fontSize: 34,
                              height: 1,
                              fontWeight: FontWeight.w600,
                              letterSpacing: -1.2,
                              color: AppColors.ink)),
                      const SizedBox(height: 2),
                      Text(wrap.workouts == 1 ? 'workout' : 'workouts',
                          style: const TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w500,
                              color: _muted)),
                    ]),
                  ),
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _legend(purple, '${wrap.activeDays} of ${wrap.days}',
                          wrap.activeDays == 1 ? 'day active' : 'days active'),
                      if (wrap.cardioSessions > 0)
                        _legend(AppColors.coral, '$cardioMinutes min',
                            'cardio · goal $cardioGoal'),
                      if (steps != null)
                        _legend(AppColors.lime, _number.format(steps.round()),
                            'steps a day'),
                    ]),
              ),
            ]),
          ),
          if (stats.isNotEmpty) const SizedBox(height: 10),
          for (var i = 0; i < stats.length; i += 2) ...[
            if (i > 0) const SizedBox(height: 8),
            Row(children: [
              Expanded(child: stats[i]),
              const SizedBox(width: 8),
              Expanded(
                  child: i + 1 < stats.length
                      ? stats[i + 1]
                      : const SizedBox.shrink()),
            ]),
          ],
          if (top != null || wrap.topMuscles.isNotEmpty) ...[
            const SizedBox(height: 10),
            Container(
              padding: const EdgeInsets.fromLTRB(14, 14, 14, 14),
              decoration: BoxDecoration(
                  color: Colors.white, borderRadius: BorderRadius.circular(24)),
              child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (top != null) ...[
                      const Text('Most trained',
                          style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w600,
                              color: AppColors.ink)),
                      const SizedBox(height: 10),
                      Row(children: [
                        _circle(
                            MuscleIcon(
                                wrap.topMuscles.isEmpty
                                    ? ''
                                    : wrap.topMuscles.first,
                                size: 19),
                            AppColors.coral),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Text(top.name,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                  fontSize: 14.5,
                                  fontWeight: FontWeight.w500,
                                  color: AppColors.ink)),
                        ),
                        const SizedBox(width: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 10, vertical: 6),
                          decoration: BoxDecoration(
                              color: _chip,
                              borderRadius: BorderRadius.circular(99)),
                          child: _value(
                              '${top.sets}', top.sets == 1 ? 'set' : 'sets',
                              size: 13.5),
                        ),
                      ]),
                    ],
                    if (top != null && wrap.topMuscles.isNotEmpty) ...[
                      const SizedBox(height: 12),
                      const _DashedLine(),
                      const SizedBox(height: 12),
                    ],
                    if (wrap.topMuscles.isNotEmpty)
                      Wrap(spacing: 6, runSpacing: 6, children: [
                        for (final muscle in wrap.topMuscles)
                          Container(
                            padding: const EdgeInsets.fromLTRB(4, 4, 12, 4),
                            decoration: BoxDecoration(
                                color: _chip,
                                borderRadius: BorderRadius.circular(99)),
                            child:
                                Row(mainAxisSize: MainAxisSize.min, children: [
                              _circle(MuscleIcon(muscle, size: 16),
                                  AppColors.paleLavender,
                                  size: 28),
                              const SizedBox(width: 7),
                              Text(muscle,
                                  style: const TextStyle(
                                      fontSize: 13,
                                      fontWeight: FontWeight.w500,
                                      color: AppColors.ink)),
                            ]),
                          ),
                      ]),
                  ]),
            ),
          ],
        ]);

    return Container(
      width: size.width,
      height: size.height,
      padding: const EdgeInsets.fromLTRB(18, 20, 18, 16),
      decoration: BoxDecoration(
          color: _background, borderRadius: BorderRadius.circular(28)),
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        Row(children: [
          _logo(30),
          const SizedBox(width: 9),
          const Expanded(
            child: Text('SweatMark',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                    fontSize: 17,
                    fontWeight: FontWeight.w600,
                    letterSpacing: -.3,
                    color: AppColors.ink)),
          ),
          const SizedBox(width: 8),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
                color: AppColors.paleLavender,
                borderRadius: BorderRadius.circular(99)),
            child: Text(wrap.soFar ? 'Month so far' : 'Monthly wrap',
                style: const TextStyle(
                    fontSize: 12.5,
                    fontWeight: FontWeight.w500,
                    color: AppColors.ink)),
          ),
        ]),
        const SizedBox(height: 8),
        Text(displayName == null ? monthLabel : '$monthLabel · $displayName',
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
                fontSize: 13, fontWeight: FontWeight.w500, color: _muted)),
        const SizedBox(height: 14),
        // Content keeps its natural size and only shrinks if a full month
        // would not fit the 9:16 canvas.
        Expanded(
          child: FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.topCenter,
            child: SizedBox(width: size.width - 36, child: content),
          ),
        ),
        const SizedBox(height: 10),
        Row(mainAxisAlignment: MainAxisAlignment.center, children: [
          const Text('Tracked with',
              style: TextStyle(fontSize: 11.5, color: _muted)),
          const SizedBox(width: 6),
          _logo(16),
          const SizedBox(width: 5),
          const Text('SweatMark',
              style: TextStyle(
                  fontSize: 11.5,
                  fontWeight: FontWeight.w600,
                  color: AppColors.ink)),
        ]),
      ]),
    );
  }
}

class _Ring {
  final double share;
  final Color color;
  const _Ring(this.share, this.color);
}

/// Concentric activity rings, outermost first. Each fills clockwise from
/// the top; any progress at all shows at least a dot.
class _Rings extends CustomPainter {
  final List<_Ring> rings;
  _Rings(this.rings);

  @override
  void paint(Canvas canvas, Size size) {
    const stroke = 13.0;
    const gap = 4.0;
    final center = size.center(Offset.zero);
    var radius = (math.min(size.width, size.height) - stroke) / 2;
    for (final ring in rings) {
      canvas.drawCircle(
          center,
          radius,
          Paint()
            ..style = PaintingStyle.stroke
            ..strokeWidth = stroke
            ..color = ring.color.withValues(alpha: .16));
      final share = ring.share.clamp(0.0, 1.0);
      if (share > 0) {
        canvas.drawArc(
            Rect.fromCircle(center: center, radius: radius),
            -math.pi / 2,
            2 * math.pi * math.max(share, .015),
            false,
            Paint()
              ..style = PaintingStyle.stroke
              ..strokeWidth = stroke
              ..strokeCap = StrokeCap.round
              ..color = ring.color);
      }
      radius -= stroke + gap;
    }
  }

  @override
  bool shouldRepaint(_Rings old) {
    if (old.rings.length != rings.length) return true;
    for (var i = 0; i < rings.length; i++) {
      if (old.rings[i].share != rings[i].share ||
          old.rings[i].color != rings[i].color) {
        return true;
      }
    }
    return false;
  }
}

class _DashedLine extends StatelessWidget {
  const _DashedLine();

  @override
  Widget build(BuildContext context) => SizedBox(
        height: 1,
        width: double.infinity,
        child: CustomPaint(painter: _Dashes()),
      );
}

class _Dashes extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = const Color(0xFFE2E0E8)
      ..strokeWidth = 1;
    for (double x = 0; x < size.width; x += 7) {
      canvas.drawLine(
          Offset(x, 0), Offset(math.min(x + 4, size.width), 0), paint);
    }
  }

  @override
  bool shouldRepaint(_Dashes old) => false;
}
