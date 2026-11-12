import 'package:flutter/material.dart';

import '../theme/app_theme.dart';

/// Adds a slim "Done" bar above the on-screen keyboard while a text field
/// is focused, so number pads (which have no return key on iPhone) can be
/// closed in one tap. Wrap the app's content with it once.
class KeyboardDoneBar extends StatefulWidget {
  final Widget child;
  const KeyboardDoneBar({super.key, required this.child});

  static const barHeight = 44.0;

  @override
  State<KeyboardDoneBar> createState() => _KeyboardDoneBarState();
}

class _KeyboardDoneBarState extends State<KeyboardDoneBar> {
  @override
  void initState() {
    super.initState();
    FocusManager.instance.addListener(_focusChanged);
  }

  @override
  void dispose() {
    FocusManager.instance.removeListener(_focusChanged);
    super.dispose();
  }

  void _focusChanged() {
    if (mounted) setState(() {});
  }

  static bool get _editingText {
    final focused = FocusManager.instance.primaryFocus?.context;
    return focused != null &&
        (focused.widget is EditableText ||
            focused.findAncestorWidgetOfExactType<EditableText>() != null);
  }

  @override
  Widget build(BuildContext context) {
    final keyboard = MediaQuery.viewInsetsOf(context).bottom;
    final show = keyboard > 0 && _editingText;
    return Stack(children: [
      widget.child,
      if (show)
        Positioned(
          left: 0,
          right: 0,
          bottom: keyboard,
          height: KeyboardDoneBar.barHeight,
          child: Material(
            color: Theme.of(context).colorScheme.surfaceContainerHigh,
            child: Row(children: [
              const Spacer(),
              TextButton(
                key: const ValueKey('keyboard-done'),
                onPressed: () => FocusManager.instance.primaryFocus?.unfocus(),
                style: TextButton.styleFrom(
                    foregroundColor:
                        Theme.of(context).brightness == Brightness.dark
                            ? AppColors.lavender
                            : const Color(0xFF6741B2),
                    textStyle: const TextStyle(
                        fontSize: 16, fontWeight: FontWeight.w600)),
                child: const Text('Done'),
              ),
              const SizedBox(width: 8),
            ]),
          ),
        ),
    ]);
  }
}

/// Closes the keyboard, e.g. after a set is completed.
void hideKeyboard() => FocusManager.instance.primaryFocus?.unfocus();
