import 'package:flutter/foundation.dart';

/// Holds the app-wide bottom navigation index so that screens can
/// programmatically switch tabs (e.g. returning home from profile).
class TabNavigationNotifier extends ChangeNotifier {
  int _currentIndex = 0;

  int get currentIndex => _currentIndex;

  void goTo(int index) {
    if (index == _currentIndex) {
      return;
    }
    _currentIndex = index;
    notifyListeners();
  }

  void goHome() => goTo(0);
}
