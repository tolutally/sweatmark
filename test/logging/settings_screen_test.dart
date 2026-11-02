import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:sweatmark/models/user_settings.dart';
import 'package:sweatmark/models/weekly_progress.dart';
import 'package:sweatmark/screens/settings_screen.dart';
import 'package:sweatmark/state/settings_notifier.dart';

class Preferences extends ChangeNotifier implements SettingsNotifier {
  UserSettings value = const UserSettings();
  int duration = 60;
  bool haptics = true;
  @override
  bool get userSettingsLoaded => true;
  @override
  UserSettings get userSettings => value;
  @override
  int get restTimerDuration => duration;
  @override
  bool get hapticFeedbackEnabled => haptics;
  @override
  Future<void> setWeightUnit(WeightUnit unit) async {
    value = value.copyWith(weightUnit: unit);
    notifyListeners();
  }

  @override
  Future<void> setDistanceUnit(DistanceUnit unit) async {
    value = value.copyWith(distanceUnit: unit);
    notifyListeners();
  }

  @override
  Future<void> setRestTimerDuration(int seconds) async {
    duration = seconds;
    notifyListeners();
  }

  @override
  Future<void> setHapticFeedbackEnabled(bool enabled) async {
    haptics = enabled;
    notifyListeners();
  }

  @override
  Future<void> setWeeklyGoal(int goal, {DateTime? now}) async {
    final currentWeek = weekStart(now ?? DateTime.now());
    final nextWeek =
        DateTime(currentWeek.year, currentWeek.month, currentWeek.day + 7);
    value = value.copyWith(weeklyGoals: {
      ...value.weeklyGoals,
      weekKey(nextWeek): goal,
    });
    notifyListeners();
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

void main() {
  testWidgets('settings switches and unit segments update preferences',
      (tester) async {
    final settings = Preferences();
    await tester.pumpWidget(ChangeNotifierProvider<SettingsNotifier>.value(
        value: settings, child: const MaterialApp(home: SettingsScreen())));
    expect(find.byType(DropdownButton<int>), findsNothing);
    await tester.scrollUntilVisible(find.byType(CupertinoSwitch).first, 120);
    await tester.tap(find.byType(CupertinoSwitch).first);
    await tester.pumpAndSettle();
    expect(settings.duration, 0);
    await tester.scrollUntilVisible(find.text('kg'), -120);
    await tester.pumpAndSettle();
    await tester.tap(find.text('kg'));
    await tester.pumpAndSettle();
    expect(settings.value.weightUnit, WeightUnit.kg);
    await tester.scrollUntilVisible(find.text('km'), 120);
    await tester.pumpAndSettle();
    await tester.tap(find.text('km'));
    await tester.pumpAndSettle();
    expect(settings.value.distanceUnit, DistanceUnit.kilometers);
    expect(tester.takeException(), isNull);
  });
}
