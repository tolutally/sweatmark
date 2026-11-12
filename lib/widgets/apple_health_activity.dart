import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../models/health_activity.dart';
import '../theme/app_theme.dart';

/// Stats card for movement read from Apple Health: steps, walking and running
/// distance and active energy. Shown on its own, never added to SweatMark's
/// logged cardio, so nothing is counted twice.
class AppleHealthActivity extends StatelessWidget {
  /// Null when Health is off or reading was not allowed yet.
  final HealthSummary? summary;
  final bool loading;
  final bool connecting;
  final bool miles;

  /// How many logged workouts in the period use Apple Watch time.
  final int watchTimed;

  /// The span the totals cover, such as "Nov 1–11" or "2026 so far".
  final String? period;

  /// Calendar days in [period] up to now; daily averages divide by the days
  /// that have Health data, or by this when that isn't known.
  final int periodDays;
  final VoidCallback? onConnect;

  const AppleHealthActivity({
    super.key,
    required this.summary,
    this.loading = false,
    this.connecting = false,
    this.miles = false,
    this.watchTimed = 0,
    this.period,
    this.periodDays = 0,
    this.onConnect,
  });

  String _distance(double km) {
    final value = miles ? km / 1.609344 : km;
    return '${value.toStringAsFixed(value >= 100 ? 0 : 1)} ${miles ? 'mi' : 'km'}';
  }

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final dark = Theme.of(context).brightness == Brightness.dark;
    final panel = dark ? colors.surfaceContainer : AppColors.referencePanel;
    final muted = colors.onSurfaceVariant;
    Widget note(String text) =>
        Text(text, style: TextStyle(fontSize: 13, height: 1.45, color: muted));

    final header = Row(children: [
      Container(
        width: 40,
        height: 40,
        decoration:
            const BoxDecoration(color: AppColors.lime, shape: BoxShape.circle),
        child:
            const Icon(Icons.favorite_rounded, size: 20, color: AppColors.ink),
      ),
      const SizedBox(width: 12),
      const Expanded(
        child: Text('Apple Health',
            style: TextStyle(fontSize: 17, fontWeight: FontWeight.w500)),
      ),
      Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
        decoration: BoxDecoration(
            color: colors.surface, borderRadius: BorderRadius.circular(99)),
        child:
            Text('From Health', style: TextStyle(fontSize: 12, color: muted)),
      ),
    ]);

    final data = summary;
    final List<Widget> body;
    if (loading) {
      body = [
        const SizedBox(height: 16),
        const Center(
            child: SizedBox(
                width: 22,
                height: 22,
                child: CircularProgressIndicator(strokeWidth: 2.4))),
      ];
    } else if (data == null) {
      body = [
        const SizedBox(height: 12),
        note(
            'See steps, walking and running distance and active energy from your iPhone or Apple Watch next to your lifts. They stay on this phone.'),
        const SizedBox(height: 14),
        FilledButton(
          onPressed: connecting ? null : onConnect,
          style: FilledButton.styleFrom(
            backgroundColor: AppColors.lavender,
            foregroundColor: AppColors.ink,
            minimumSize: const Size.fromHeight(48),
            shape:
                RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
          ),
          child: Text(connecting ? 'Connecting…' : 'Connect Apple Health'),
        ),
      ];
    } else if (data.isEmpty) {
      body = [
        const SizedBox(height: 12),
        note('No steps, distance or active energy from Health in this period.'),
      ];
    } else {
      final number = NumberFormat.decimalPattern();
      final days = periodDays;
      String? average(num? total, String Function(double) format) {
        if (days <= 1) return null;
        final value = data.perDay(total, days);
        return value == null ? null : 'avg ${format(value)} a day';
      }

      Widget metric(String value, String label, String? perDay) => Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
                color: colors.surface, borderRadius: BorderRadius.circular(18)),
            child:
                Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(value,
                  style: const TextStyle(
                      fontSize: 20, fontWeight: FontWeight.w500)),
              const SizedBox(height: 2),
              note(label),
              if (perDay != null)
                Text(perDay,
                    style: TextStyle(
                        fontSize: 13,
                        height: 1.45,
                        fontWeight: FontWeight.w500,
                        color: colors.onSurface)),
            ]),
          );
      final metrics = [
        if ((data.steps ?? 0) > 0)
          metric(number.format(data.steps), 'steps',
              average(data.steps, (v) => number.format(v.round()))),
        if (data.distanceKm > 0)
          metric(_distance(data.distanceKm), 'walked and run',
              average(data.distanceKm, _distance)),
        if ((data.activeKcal ?? 0) > 0)
          metric(
              '${number.format(data.activeKcal!.round())} kcal',
              'active energy',
              average(
                  data.activeKcal, (v) => '${number.format(v.round())} kcal')),
      ];
      final known = data.daysWithData;
      body = [
        const SizedBox(height: 14),
        LayoutBuilder(builder: (context, box) {
          final single = box.maxWidth < 260 ||
              MediaQuery.textScalerOf(context).scale(1) > 1.3;
          final width = single ? box.maxWidth : (box.maxWidth - 8) / 2;
          return Wrap(spacing: 8, runSpacing: 8, children: [
            for (final m in metrics) SizedBox(width: width, child: m),
          ]);
        }),
        const SizedBox(height: 12),
        if (known != null && days > 1 && known < days) ...[
          note(
              'Health has data on $known of $days days. Averages use those $known days.'),
          const SizedBox(height: 6),
        ],
        note(
            'From your iPhone and Apple Watch. Kept separate from cardio you log, so nothing is counted twice.'),
      ];
    }
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration:
          BoxDecoration(color: panel, borderRadius: BorderRadius.circular(28)),
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        header,
        if (period != null && !loading && data != null) ...[
          const SizedBox(height: 10),
          Text(
              periodDays > 0
                  ? '$period · ${periodDays == 1 ? '1 day' : '$periodDays days'}'
                  : period!,
              style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w500,
                  color: colors.onSurface)),
        ],
        ...body,
        if (!loading && data != null && watchTimed > 0) ...[
          const SizedBox(height: 8),
          note(watchTimed == 1
              ? '1 logged workout uses Apple Watch time from the same day.'
              : '$watchTimed logged workouts use Apple Watch time from the same day.'),
        ],
      ]),
    );
  }
}
