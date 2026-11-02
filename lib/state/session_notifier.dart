import 'package:flutter/foundation.dart';

/// Account-owned notifiers are discarded on logout. Async completions may
/// finish afterwards, but must never notify a disposed widget tree.
class SessionNotifier extends ChangeNotifier {
  bool _isDisposed = false;
  bool get isDisposed => _isDisposed;

  @override
  void notifyListeners() {
    if (!_isDisposed) super.notifyListeners();
  }

  @override
  void dispose() {
    _isDisposed = true;
    super.dispose();
  }
}
