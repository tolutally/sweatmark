import 'package:flutter/widgets.dart';

/// Replaces all account-owned providers AND navigation when identity changes.
/// Changes to loading/profile state for the same account preserve the session.
class AccountSession extends StatelessWidget {
  final String? userId;
  final WidgetBuilder builder;

  const AccountSession(
      {super.key, required this.userId, required this.builder});

  @override
  Widget build(BuildContext context) => KeyedSubtree(
        key: ValueKey<String?>(userId),
        child: Builder(builder: builder),
      );
}
