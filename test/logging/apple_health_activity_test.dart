import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sweatmark/models/health_activity.dart';
import 'package:sweatmark/widgets/apple_health_activity.dart';

void main() {
  final start = DateTime(2026, 11, 1);
  final end = DateTime(2026, 11, 3, 12);

  Future<void> pump(WidgetTester tester,
      Future<HealthSummary?> Function(String?, DateTime, DateTime) reader,
      {Future<bool> Function(String)? connect, bool miles = false}) async {
    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: SingleChildScrollView(
          child: AppleHealthActivity(
            uid: 'u1',
            start: start,
            end: end,
            miles: miles,
            reader: reader,
            connect: connect,
          ),
        ),
      ),
    ));
    await tester.pumpAndSettle();
  }

  test('labels, units and totals', () {
    expect(HealthSummary.labelFor('RUNNING'), 'Run');
    expect(HealthSummary.labelFor('OUTDOOR_SKATING'), 'Outdoor skating');
    expect(HealthSummary.meters(2, 'MILE'), closeTo(3218.688, .001));
    expect(HealthSummary.meters(500, 'METER'), 500);
    expect(HealthSummary.meters(3, 'CALORIE'), isNull);
    expect(HealthSummary.meters(0, 'METER'), isNull);

    final summary = HealthSummary([
      HealthActivity(
          id: 'a',
          label: 'Walk',
          start: DateTime(2026, 11, 1, 8),
          end: DateTime(2026, 11, 1, 8, 30),
          sourceName: 'Apple Watch',
          distanceMeters: 2500),
      HealthActivity(
          id: 'b',
          label: 'Run',
          start: DateTime(2026, 11, 2, 7),
          end: DateTime(2026, 11, 2, 7, 25),
          sourceName: 'Strava'),
    ], steps: 12000);
    expect(summary.activities.first.label, 'Run', reason: 'newest first');
    expect(summary.totalSeconds, 55 * 60);
    expect(summary.distanceKm, 2.5);
    expect(summary.isEmpty, isFalse);
    expect(HealthSummary(const [], steps: 0).isEmpty, isTrue);
  });

  testWidgets('asks to connect when Health is off', (tester) async {
    var connected = false;
    await pump(tester,
        (_, __, ___) async => connected ? HealthSummary(const []) : null,
        connect: (_) async => connected = true);
    expect(find.text('Connect Apple Health'), findsOneWidget);
    await tester.tap(find.text('Connect Apple Health'));
    await tester.pumpAndSettle();
    expect(connected, isTrue);
    expect(find.textContaining('No workouts or steps from Health'),
        findsOneWidget);
  });

  testWidgets('shows Health workouts and steps apart from lifts',
      (tester) async {
    await pump(
        tester,
        (_, __, ___) async => HealthSummary([
              HealthActivity(
                  id: 'a',
                  label: 'Run',
                  start: DateTime(2026, 11, 2, 7),
                  end: DateTime(2026, 11, 2, 7, 30),
                  sourceName: 'Apple Watch',
                  distanceMeters: 5000),
            ], steps: 8421),
        miles: true);
    expect(find.text('Apple Health'), findsOneWidget);
    expect(find.text('1'), findsOneWidget);
    expect(find.text('workout'), findsOneWidget);
    expect(find.text('8,421'), findsOneWidget);
    expect(find.text('3.1 mi'), findsOneWidget);
    expect(find.text('Run'), findsOneWidget);
    expect(find.textContaining('Apple Watch'), findsOneWidget);
    expect(find.text('30 min · 3.1 mi'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
