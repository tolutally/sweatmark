import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../models/health_activity.dart';
import '../services/apple_health_service.dart';
import '../theme/app_theme.dart';

/// Stats section for movement read from Apple Health: runs, walks, rides and
/// steps recorded by other apps or devices. Shown on its own, never added to
/// SweatMark's logged-workout counts, so nothing is counted twice.
class AppleHealthActivity extends StatefulWidget {
  final String? uid;
  final DateTime start;
  final DateTime end;
  final bool miles;

  /// Reads Health; replaceable in tests.
  final Future<HealthSummary?> Function(String?, DateTime, DateTime)? reader;
  final Future<bool> Function(String)? connect;

  const AppleHealthActivity({
    super.key,
    required this.uid,
    required this.start,
    required this.end,
    this.miles = false,
    this.reader,
    this.connect,
  });

  @override
  State<AppleHealthActivity> createState() => _AppleHealthActivityState();
}

class _AppleHealthActivityState extends State<AppleHealthActivity> {
  late Future<HealthSummary?> _future;
  bool _connecting = false;

  @override
  void initState() {
    super.initState();
    _future = _load();
  }

  @override
  void didUpdateWidget(AppleHealthActivity old) {
    super.didUpdateWidget(old);
    if (old.start != widget.start ||
        old.end != widget.end ||
        old.uid != widget.uid) {
      _future = _load();
    }
  }

  Future<HealthSummary?> _load() =>
      (widget.reader ?? AppleHealthService.instance.readActivity)(
          widget.uid, widget.start, widget.end);

  Future<void> _connect() async {
    final uid = widget.uid;
    if (uid == null) return;
    setState(() => _connecting = true);
    final on =
        await (widget.connect ?? AppleHealthService.instance.enable)(uid);
    if (!mounted) return;
    setState(() {
      _connecting = false;
      _future = _load();
    });
    if (!on) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text(
              'Apple Health was not turned on. You can allow it in the Health app under Sharing → Apps.')));
    }
  }

  String _time(int seconds) {
    final minutes = seconds ~/ 60;
    if (minutes < 60) return '$minutes min';
    return '${minutes ~/ 60}h ${minutes % 60}m';
  }

  String _distance(double km) {
    final value = widget.miles ? km / 1.609344 : km;
    return '${value.toStringAsFixed(value >= 100 ? 0 : 1)} ${widget.miles ? 'mi' : 'km'}';
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

    return FutureBuilder<HealthSummary?>(
      future: _future,
      builder: (context, snapshot) {
        final loading = snapshot.connectionState != ConnectionState.done;
        final data = snapshot.data;
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
                'See runs, walks, rides and steps from your iPhone or Apple Watch next to your lifts. They stay on this phone and are not added to your logged workouts.'),
            const SizedBox(height: 14),
            FilledButton(
              onPressed: _connecting || widget.uid == null ? null : _connect,
              style: FilledButton.styleFrom(
                backgroundColor: AppColors.lavender,
                foregroundColor: AppColors.ink,
                minimumSize: const Size.fromHeight(48),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14)),
              ),
              child: Text(_connecting ? 'Connecting…' : 'Connect Apple Health'),
            ),
          ];
        } else if (data.isEmpty) {
          body = [
            const SizedBox(height: 12),
            note(
                'No workouts or steps from Health in this period. Workouts you log in SweatMark are counted above, not here.'),
          ];
        } else {
          Widget metric(String value, String label) => Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                    color: colors.surface,
                    borderRadius: BorderRadius.circular(18)),
                child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(value,
                          style: const TextStyle(
                              fontSize: 20, fontWeight: FontWeight.w500)),
                      const SizedBox(height: 2),
                      note(label),
                    ]),
              );
          final metrics = [
            metric('${data.activities.length}',
                data.activities.length == 1 ? 'workout' : 'workouts'),
            metric(_time(data.totalSeconds), 'active time'),
            if (data.distanceKm > 0)
              metric(_distance(data.distanceKm), 'distance'),
            if (data.steps != null)
              metric(NumberFormat.decimalPattern().format(data.steps), 'steps'),
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
            for (final activity in data.activities.take(4)) ...[
              const SizedBox(height: 8),
              _ActivityRow(
                activity: activity,
                detail: [
                  _time(activity.seconds),
                  if (activity.distanceMeters != null)
                    _distance(activity.distanceMeters! / 1000),
                ].join(' · '),
              ),
            ],
            if (data.activities.length > 4) ...[
              const SizedBox(height: 10),
              note('${data.activities.length - 4} more in Health.'),
            ],
            const SizedBox(height: 12),
            note(
                'Recorded by other apps and devices. Kept separate from your logged workouts so nothing is counted twice.'),
          ];
        }
        return Container(
          width: double.infinity,
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
              color: panel, borderRadius: BorderRadius.circular(28)),
          child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [header, ...body]),
        );
      },
    );
  }
}

class _ActivityRow extends StatelessWidget {
  final HealthActivity activity;
  final String detail;
  const _ActivityRow({required this.activity, required this.detail});

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final date = DateFormat('EEE d MMM').format(activity.start.toLocal());
    return Container(
      padding: const EdgeInsets.fromLTRB(12, 10, 14, 10),
      decoration: BoxDecoration(
          color: colors.surface, borderRadius: BorderRadius.circular(18)),
      child: Row(children: [
        Container(
          width: 36,
          height: 36,
          decoration: const BoxDecoration(
              color: AppColors.paleLavender, shape: BoxShape.circle),
          child: const Icon(Icons.directions_run_rounded,
              size: 18, color: Color(0xFF6741B2)),
        ),
        const SizedBox(width: 12),
        Expanded(
          child:
              Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(activity.label,
                style:
                    const TextStyle(fontSize: 15, fontWeight: FontWeight.w500)),
            Text('$date · ${activity.sourceName}',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(fontSize: 12, color: colors.onSurfaceVariant)),
          ]),
        ),
        const SizedBox(width: 8),
        Text(detail,
            style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w500)),
      ]),
    );
  }
}
