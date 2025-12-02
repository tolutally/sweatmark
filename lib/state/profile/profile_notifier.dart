import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import '../../models/profile_model.dart';
import '../../services/firebase_service.dart';

class ProfileNotifier extends ChangeNotifier {
  ProfileNotifier(this._firebaseService);

  final FirebaseService _firebaseService;

  ProfileModel? _profile;
  bool _isLoading = false;
  String? _errorMessage;

  ProfileModel? get profile => _profile;
  bool get isLoading => _isLoading;
  String? get errorMessage => _errorMessage;

  bool get hasProfile => _profile != null;

  Future<void> loadProfile(String userId, {bool forceRefresh = false}) async {
    if (_isLoading) return;
    if (_profile != null && !forceRefresh) return;

    _setLoading(true);
    try {
      final data = await _firebaseService.getUserProfile(userId);
      if (data != null) {
        _profile = ProfileModel.fromFirestore(data);
      } else {
        final defaults = ProfileModel.defaults();
        await _firebaseService.setUserProfile(userId, defaults.toFirestore());
        _profile = defaults;
      }
      _errorMessage = null;
    } catch (error, stack) {
      debugPrint('Profile load failed: $error\n$stack');
      _errorMessage = 'Failed to load profile. Please pull to refresh.';
    } finally {
      _setLoading(false);
    }
  }

  Future<void> updateProfileField(
    String userId,
    Map<String, dynamic> patch,
  ) async {
    if (_profile == null) {
      await loadProfile(userId);
    }

    final sanitizedPatch = <String, dynamic>{};
    final currentData = _profile?.toFirestore() ?? {};

    patch.forEach((key, value) {
      var sanitizedValue = value;
      if (value is String) {
        sanitizedValue = value.trim();
      }

      if (sanitizedValue == null) {
        sanitizedPatch[key] = FieldValue.delete();
        currentData.remove(key);
      } else if (sanitizedValue is String && sanitizedValue.isEmpty) {
        sanitizedPatch[key] = FieldValue.delete();
        currentData.remove(key);
      } else {
        sanitizedPatch[key] = sanitizedValue;
        currentData[key] = sanitizedValue;
      }
    });

    try {
      if (sanitizedPatch.isNotEmpty) {
        await _firebaseService.updateUserProfile(userId, sanitizedPatch);
      }
      _profile = ProfileModel.fromFirestore(currentData);
      _errorMessage = null;
      notifyListeners();
    } catch (error, stack) {
      debugPrint('Profile update failed: $error\n$stack');
      rethrow;
    }
  }

  Future<void> updateDisplayName(String userId, String displayName) {
    return updateProfileField(userId, {
      'username': displayName.trim(),
    });
  }

  Future<void> updateLocation(String userId, String? location) {
    return updateProfileField(userId, {
      'location': location,
    });
  }

  Future<void> updateBio(String userId, String? bio) {
    return updateProfileField(userId, {
      'bio': bio,
    });
  }

  Future<void> updateHandle(String userId, String? handle) {
    return updateProfileField(userId, {
      'handle': _normalizeHandle(handle),
    });
  }

  Future<void> updateNameAndHandle(
    String userId, {
    required String displayName,
    required String handle,
  }) {
    return updateProfileField(userId, {
      'username': displayName.trim(),
      'handle': _normalizeHandle(handle),
    });
  }

  Future<void> updateInstagram(String userId, String? instagramHandle) {
    return updateProfileField(userId, {
      'instagram': instagramHandle,
    });
  }

  void clear() {
    _profile = null;
    _errorMessage = null;
    _isLoading = false;
    notifyListeners();
  }

  void _setLoading(bool value) {
    _isLoading = value;
    notifyListeners();
  }

  String? _normalizeHandle(String? handle) {
    final trimmed = handle?.trim() ?? '';
    if (trimmed.isEmpty) {
      return null;
    }
    return trimmed.startsWith('@') ? trimmed : '@$trimmed';
  }
}
