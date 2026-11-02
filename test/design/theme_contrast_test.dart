import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sweatmark/theme/app_theme.dart';

double contrast(Color foreground, Color background) {
  final a = foreground.computeLuminance();
  final b = background.computeLuminance();
  return a > b ? (a + .05) / (b + .05) : (b + .05) / (a + .05);
}

void main() {
  for (final theme in [lightTheme, darkTheme]) {
    test('${theme.brightness.name} text and status contrast', () {
      final c = theme.colorScheme;
      final d = theme.extension<AppDesign>()!;
      final pairs = <String, (Color, Color)>{
        'body': (c.onSurface, c.surface),
        'supporting': (c.onSurfaceVariant, c.surface),
        'supporting on page': (
          c.onSurfaceVariant,
          theme.scaffoldBackgroundColor
        ),
        'link': (c.primary, c.surface),
        'selected': (c.onPrimaryContainer, c.primaryContainer),
        'lavender selection': (AppColors.ink, AppColors.lavender),
        'selected calendar day': (
          theme.datePickerTheme.dayForegroundColor!
              .resolve({WidgetState.selected})!,
          theme.datePickerTheme.dayBackgroundColor!
              .resolve({WidgetState.selected})!
        ),
        'success': (d.onSuccessContainer, d.successContainer),
        'record': (d.record, c.surface),
        'record message': (d.onRecordContainer, d.recordContainer),
        'error': (c.onErrorContainer, c.errorContainer),
        'button': (
          theme.filledButtonTheme.style!.foregroundColor!.resolve({})!,
          theme.filledButtonTheme.style!.backgroundColor!.resolve({})!
        ),
      };
      for (final pair in pairs.entries) {
        expect(
            contrast(pair.value.$1, pair.value.$2), greaterThanOrEqualTo(4.5),
            reason: pair.key);
      }
      expect(
          contrast(c.outline, c.surfaceContainerLow), greaterThanOrEqualTo(3));
      expect(contrast(c.primary, c.primaryContainer), greaterThanOrEqualTo(3));
    });
  }
}
