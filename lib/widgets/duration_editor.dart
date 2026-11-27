import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';

import '../theme/app_theme.dart';

/// Lets the person correct a workout's time in hours and minutes. Returns
/// the new length in seconds, or null if they cancel.
Future<int?> showDurationEditor(BuildContext context, int seconds,
    {String title = 'Workout time',
    String message =
        'Fix the time if the clock ran on or stopped early. Stats use this time.',
    bool withSeconds = false}) {
  final minimum = withSeconds ? 1 : 60;
  var chosen = Duration(seconds: seconds < minimum ? minimum : seconds);
  return showModalBottomSheet<int>(
    context: context,
    backgroundColor: const Color(0xFFF6F4FC),
    shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(28))),
    builder: (sheet) => SafeArea(
      top: false,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 20, 20, 16),
        child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(title,
                  style: const TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.w600,
                      color: AppColors.ink)),
              const SizedBox(height: 6),
              Text(message,
                  style: const TextStyle(
                      fontSize: 13, color: AppColors.referenceMuted)),
              const SizedBox(height: 8),
              SizedBox(
                height: 180,
                child: CupertinoTheme(
                  data: const CupertinoThemeData(brightness: Brightness.light),
                  child: CupertinoTimerPicker(
                    key: const ValueKey('duration-picker'),
                    mode: withSeconds
                        ? CupertinoTimerPickerMode.hms
                        : CupertinoTimerPickerMode.hm,
                    initialTimerDuration: chosen,
                    onTimerDurationChanged: (value) => chosen = value,
                  ),
                ),
              ),
              const SizedBox(height: 8),
              FilledButton(
                onPressed: () => Navigator.pop(sheet,
                    chosen.inSeconds < minimum ? minimum : chosen.inSeconds),
                style: FilledButton.styleFrom(
                    backgroundColor: AppColors.lavender,
                    foregroundColor: AppColors.ink,
                    minimumSize: const Size.fromHeight(50)),
                child: const Text('Save time'),
              ),
            ]),
      ),
    ),
  );
}
