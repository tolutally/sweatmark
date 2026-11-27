import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../state/auth_notifier.dart';
import '../theme/app_theme.dart';

/// A small, quiet "Delete account" link. Rarely needed, so it stays out of
/// the way; it confirms first and explains any failure.
class DeleteAccountLink extends StatelessWidget {
  const DeleteAccountLink({super.key});

  @override
  Widget build(BuildContext context) => Center(
        child: TextButton(
          onPressed: () => _confirmDelete(context),
          style: TextButton.styleFrom(
              foregroundColor: AppColors.referenceMuted,
              minimumSize: const Size(44, 36),
              textStyle: const TextStyle(fontSize: 12)),
          child: const Text('Delete account'),
        ),
      );

  Future<void> _confirmDelete(BuildContext context) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialog) => AlertDialog(
        title: const Text('Delete your account?'),
        content: const Text(
            'This permanently deletes your account, workouts, routines and settings. It can’t be undone.'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(dialog, false),
              child: const Text('Cancel')),
          TextButton(
              onPressed: () => Navigator.pop(dialog, true),
              style: TextButton.styleFrom(foregroundColor: AppColors.error),
              child: const Text('Delete')),
        ],
      ),
    );
    if (confirmed != true || !context.mounted) return;
    try {
      await context.read<AuthNotifier>().deleteAccount();
      if (context.mounted) Navigator.of(context).popUntil((r) => r.isFirst);
    } on AccountDeletionException catch (error) {
      if (context.mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(error.message)));
      }
    }
  }
}
