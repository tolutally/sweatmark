import 'package:flutter/material.dart';

class RoundBackButton extends StatelessWidget {
  final bool close;
  const RoundBackButton({super.key, this.close = false});
  @override
  Widget build(BuildContext context) => IconButton(
        tooltip: close ? 'Close' : 'Back',
        onPressed: () => Navigator.maybePop(context),
        style: IconButton.styleFrom(
          backgroundColor:
              Theme.of(context).colorScheme.surface.withValues(alpha: .85),
          foregroundColor: Theme.of(context).colorScheme.onSurface,
          side: BorderSide(color: Theme.of(context).colorScheme.outlineVariant),
          minimumSize: const Size(48, 48),
          shape: const CircleBorder(),
        ),
        icon: Icon(
            close ? Icons.close_rounded : Icons.arrow_back_ios_new_rounded,
            size: close ? 26 : 22),
      );
}
