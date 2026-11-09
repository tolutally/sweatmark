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
  final VoidCallback? onConnect;

  const AppleHealthActivity({
    super.key,
    required this.summary,
    this.loading = false,
    this.connecting = false,
    this.miles = false,
    this.watchTimed = 0,
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
      Widget metric(String value, String label) => Container(
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
            ]),
          );
      final metrics = [
        if ((data.steps ?? 0) > 0)
          metric(NumberFormat.decimalPattern().format(data.steps), 'steps'),
        if (data.distanceKm > 0)
          metric(_distance(data.distanceKm), 'walked and run'),
        if ((data.activeKcal ?? 0) > 0)
          metric(
              '${NumberFormat.decimalPattern().format(data.activeKcal!.round())} kcal',
              'active energy'),
      ];
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
