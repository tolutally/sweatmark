import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';
import 'package:provider/provider.dart';
import '../state/auth_notifier.dart';
import '../state/settings_notifier.dart';
import '../state/profile/profile_notifier.dart';
import '../state/navigation/tab_navigation_notifier.dart';
import '../state/streak_notifier.dart';
import '../services/streak_service.dart';
import '../models/profile_model.dart';
import '../theme/app_theme.dart';
import 'workout_history_screen.dart';
import 'recovery_screen.dart';
import 'pr_history_screen.dart';
import '../widgets/streak_settings_sheet.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _loadProfile();
    });
  }

  void _loadProfile() {
    final authNotifier = context.read<AuthNotifier>();
    final userId = authNotifier.user?.uid;
    if (userId != null) {
      context.read<ProfileNotifier>().loadProfile(userId);
    }
  }

  @override
  Widget build(BuildContext context) {
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: const SystemUiOverlayStyle(
        statusBarColor: Colors.transparent,
        statusBarIconBrightness: Brightness.dark,
        statusBarBrightness: Brightness.light,
      ),
      child: Scaffold(
        backgroundColor: AppColors.neutral50,
        body: Consumer2<AuthNotifier, ProfileNotifier>(
          builder: (context, authNotifier, profileNotifier, child) {
            final userId = authNotifier.user?.uid;
            final profile = profileNotifier.profile ??
                ProfileModel(
                  displayName: 'Loading...',
                  handle: '@loading',
                  createdAt: null,
                  totalWorkouts: 0,
                  totalPersonalRecords: 0,
                );

            return CustomScrollView(
              slivers: [
                // Header with Profile Info
                SliverToBoxAdapter(
                  child: Container(
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: const BorderRadius.vertical(
                      bottom: Radius.circular(24),
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.04),
                        blurRadius: 12,
                        offset: const Offset(0, 6),
                      ),
                    ],
                  ),
                  child: SafeArea(
                    bottom: false,
                    child: Padding(
                      padding: const EdgeInsets.all(20.0),
                      child: Column(
                        children: [
                          // Close button
                          Align(
                            alignment: Alignment.topRight,
                            child: IconButton(
                              icon: const Icon(PhosphorIconsRegular.x,
                                  color: AppColors.neutral500),
                              onPressed: () => _showCloseOptions(context),
                            ),
                          ),

                          // Premium Badge
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 12, vertical: 6),
                            decoration: BoxDecoration(
                              gradient: const LinearGradient(
                                colors: [AppColors.brandTeal, AppColors.info],
                              ),
                              borderRadius: BorderRadius.circular(14),
                            ),
                            child: const Text(
                              'SWEAT ELITE',
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 11,
                                fontWeight: FontWeight.w700,
                                letterSpacing: 1.1,
                              ),
                            ),
                          ),

                          const SizedBox(height: 12),

                          // Avatar with edit capability
                          GestureDetector(
                            onTap: userId == null
                                ? null
                                : () => _showAvatarOptions(context, userId, profile),
                            child: Stack(
                              children: [
                                Container(
                                  width: 76,
                                  height: 76,
                                  decoration: BoxDecoration(
                                    shape: BoxShape.circle,
                                    color: Colors.white,
                                    boxShadow: [
                                      BoxShadow(
                                        color: Colors.black.withValues(alpha: 0.08),
                                        blurRadius: 8,
                                        offset: const Offset(0, 2),
                                      ),
                                    ],
                                    image: profile.avatarUrl != null && profile.avatarUrl!.isNotEmpty
                                        ? DecorationImage(
                                            image: NetworkImage(profile.avatarUrl!),
                                            fit: BoxFit.cover,
                                          )
                                        : null,
                                  ),
                                  child: profile.avatarUrl == null || profile.avatarUrl!.isEmpty
                                      ? Center(
                                          child: profileNotifier.isUploadingImage
                                              ? const SizedBox(
                                                  width: 24,
                                                  height: 24,
                                                  child: CircularProgressIndicator(
                                                    strokeWidth: 2,
                                                    color: AppColors.brandTeal,
                                                  ),
                                                )
                                              : const Icon(
                                                  PhosphorIconsBold.barbell,
                                                  size: 30,
                                                  color: AppColors.brandTeal,
                                                ),
                                        )
                                      : profileNotifier.isUploadingImage
                                          ? Container(
                                              decoration: BoxDecoration(
                                                shape: BoxShape.circle,
                                                color: Colors.black.withValues(alpha: 0.4),
                                              ),
                                              child: const Center(
                                                child: SizedBox(
                                                  width: 24,
                                                  height: 24,
                                                  child: CircularProgressIndicator(
                                                    strokeWidth: 2,
                                                    color: Colors.white,
                                                  ),
                                                ),
                                              ),
                                            )
                                          : null,
                                ),
                                // Edit badge
                                Positioned(
                                  bottom: 0,
                                  right: 0,
                                  child: Container(
                                    width: 24,
                                    height: 24,
                                    decoration: BoxDecoration(
                                      color: AppColors.brandTeal,
                                      shape: BoxShape.circle,
                                      border: Border.all(
                                        color: Colors.white,
                                        width: 2,
                                      ),
                                    ),
                                    child: const Icon(
                                      PhosphorIconsBold.camera,
                                      size: 12,
                                      color: AppColors.brandNavy,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),

                          const SizedBox(height: 12),

                          // Username
                          Column(
                            children: [
                              GestureDetector(
                                behavior: HitTestBehavior.translucent,
                                onTap: userId == null
                                    ? null
                                    : () => _handleNameHandleEdit(
                                          context,
                                          userId,
                                          profile,
                                        ),
                                child: Row(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Flexible(
                                      child: Text(
                                        profile.displayName,
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                        textAlign: TextAlign.center,
                                        style: const TextStyle(
                                          fontSize: 22,
                                          fontWeight: FontWeight.w700,
                                          color: AppColors.neutral900,
                                        ),
                                      ),
                                    ),
                                    const SizedBox(width: 6),
                                    const Icon(
                                      PhosphorIconsRegular.pencilSimple,
                                      size: 18,
                                      color: AppColors.neutral500,
                                    ),
                                  ],
                                ),
                              ),
                              const SizedBox(height: 4),
                              ConstrainedBox(
                                constraints:
                                    const BoxConstraints(maxWidth: 240),
                                child: Text(
                                  profile.handle,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  textAlign: TextAlign.center,
                                  style: const TextStyle(
                                    fontSize: 12,
                                    color: AppColors.neutral500,
                                  ),
                                ),
                              ),
                            ],
                          ),

                          const SizedBox(height: 10),

                          // Stats
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 14, vertical: 8),
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(12),
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.black.withValues(alpha: 0.04),
                                  blurRadius: 4,
                                  offset: const Offset(0, 2),
                                ),
                              ],
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Text(
                                  '${profile.totalWorkouts}',
                                  style: const TextStyle(
                                    fontSize: 15,
                                    fontWeight: FontWeight.w700,
                                    color: AppColors.neutral900,
                                  ),
                                ),
                                const Text(
                                  ' workouts',
                                  style: TextStyle(
                                    fontSize: 13,
                                    color: AppColors.neutral600,
                                  ),
                                ),
                              ],
                            ),
                          ),

                          const SizedBox(height: 18),

                          // Achievements Section
                          Consumer<StreakNotifier?>(
                            builder: (context, streakNotifier, child) {
                              if (streakNotifier == null) return const SizedBox.shrink();

                              return FutureBuilder<List<Map<String, dynamic>>>(
                                future: context.read<StreakService>().getStreakAchievements(userId!),
                                builder: (context, snapshot) {
                                  if (!snapshot.hasData || snapshot.data!.isEmpty) {
                                    return const SizedBox.shrink();
                                  }

                                  final achievements = snapshot.data!;
                                  return Column(
                                    children: [
                                      Row(
                                        mainAxisAlignment: MainAxisAlignment.center,
                                        children: [
                                          const Text(
                                            'Achievements',
                                            style: TextStyle(
                                              fontSize: 14,
                                              fontWeight: FontWeight.w600,
                                              color: AppColors.neutral600,
                                            ),
                                          ),
                                          const SizedBox(width: 8),
                                          GestureDetector(
                                            onTap: () {
                                              showModalBottomSheet(
                                                context: context,
                                                isScrollControlled: true,
                                                backgroundColor: Colors.transparent,
                                                builder: (context) => const StreakSettingsSheet(),
                                              );
                                            },
                                            child: const Icon(
                                              PhosphorIconsRegular.gear,
                                              size: 16,
                                              color: AppColors.neutral500,
                                            ),
                                          ),
                                        ],
                                      ),
                                      const SizedBox(height: 12),
                                      Wrap(
                                        spacing: 12,
                                        runSpacing: 12,
                                        alignment: WrapAlignment.center,
                                        children: achievements.map((achievement) {
                                          return Container(
                                            padding: const EdgeInsets.all(12),
                                            decoration: BoxDecoration(
                                              color: Colors.white,
                                              borderRadius: BorderRadius.circular(12),
                                              boxShadow: [
                                                BoxShadow(
                                                  color: Colors.black.withValues(alpha: 0.04),
                                                  blurRadius: 4,
                                                  offset: const Offset(0, 2),
                                                ),
                                              ],
                                            ),
                                            child: Column(
                                              children: [
                                                Text(
                                                  achievement['badge'],
                                                  style: const TextStyle(fontSize: 32),
                                                ),
                                                const SizedBox(height: 4),
                                                Text(
                                                  '${achievement['milestone']} days',
                                                  style: const TextStyle(
                                                    fontSize: 11,
                                                    fontWeight: FontWeight.w600,
                                                    color: AppColors.neutral600,
                                                  ),
                                                ),
                                              ],
                                            ),
                                          );
                                        }).toList(),
                                      ),
                                      const SizedBox(height: 18),
                                    ],
                                  );
                                },
                              );
                            },
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),

              // Action Buttons
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.all(14.0),
                  child: Column(
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: _ActionButton(
                              icon: PhosphorIconsRegular.barbell,
                              label: 'My Workouts',
                              isPrimary: true,
                              onTap: () {
                                Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder: (_) =>
                                        const WorkoutHistoryScreen(),
                                  ),
                                );
                              },
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: _ActionButton(
                              icon: PhosphorIconsRegular.heartbeat,
                              label: 'Recovery',
                              isPrimary: false,
                              onTap: () {
                                Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder: (_) => const RecoveryScreen(),
                                  ),
                                );
                              },
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      Row(
                        children: [
                          Expanded(
                            child: _ActionButton(
                              icon: PhosphorIconsRegular.trophy,
                              label: 'Personal Records',
                              isPrimary: false,
                              onTap: () {
                                Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder: (_) => const PRHistoryScreen(),
                                  ),
                                );
                              },
                            ),
                          ),
                          const SizedBox(width: 12),
                          Container(
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(14),
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.black.withValues(alpha: 0.04),
                                  blurRadius: 4,
                                  offset: const Offset(0, 2),
                                ),
                              ],
                            ),
                            child: IconButton(
                              icon: const Icon(PhosphorIconsRegular.dotsThree),
                              color: AppColors.neutral800,
                              onPressed: () {
                                _showSettingsDialog(context);
                              },
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),

              // Achievement Display
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Achievement Display',
                        style: TextStyle(
                          fontSize: 11,
                          color: AppColors.neutral500,
                          letterSpacing: 0.5,
                        ),
                      ),
                      const SizedBox(height: 10),
                      const Row(
                        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                        children: [
                          _AchievementSlot(),
                          _AchievementSlot(),
                          _AchievementSlot(),
                          _AchievementSlot(),
                        ],
                      ),
                      const SizedBox(height: 16),
                      Center(
                        child: TextButton.icon(
                          onPressed: () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (_) => const PRHistoryScreen(),
                              ),
                            );
                          },
                          icon: const Icon(
                            PhosphorIconsBold.trophy,
                            size: 16,
                            color: AppColors.warning,
                          ),
                          label: const Text(
                            'View Personal Records',
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w600,
                              color: AppColors.neutral800,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),

              // User Info Section
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.all(14.0),
                  child: Column(
                    children: [
                      const SizedBox(height: 6),
                      _InfoRow(
                        icon: PhosphorIconsRegular.mapPin,
                        text: (profile.location?.trim().isNotEmpty ?? false)
                            ? profile.location!.trim()
                            : 'Add Location...',
                        onTap: () {
                          if (userId == null) return;
                          _handleLocationEdit(
                              context, userId, profile.location);
                        },
                      ),
                      const SizedBox(height: 6),
                      _InfoRow(
                        icon: PhosphorIconsRegular.user,
                        text: (profile.bio?.trim().isNotEmpty ?? false)
                            ? profile.bio!.trim()
                            : 'Add Bio...',
                        onTap: () {
                          if (userId == null) return;
                          _handleBioEdit(context, userId, profile.bio);
                        },
                      ),
                      const SizedBox(height: 6),
                      _InfoRow(
                        icon: PhosphorIconsRegular.instagramLogo,
                        text: (profile.instagramHandle?.trim().isNotEmpty ??
                                false)
                            ? "@${profile.instagramHandle!.replaceFirst(RegExp(r'^@'), '')}"
                            : 'Add Instagram',
                        onTap: () {
                          if (userId == null) return;
                          _handleInstagramEdit(
                              context, userId, profile.instagramHandle);
                        },
                      ),
                    ],
                  ),
                ),
              ),

              // Activity Section
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.all(14.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Activity',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: AppColors.neutral900,
                        ),
                      ),
                      const SizedBox(height: 18),
                      Center(
                        child: Column(
                          children: [
                            const Text(
                              'No Posts',
                              style: TextStyle(
                                fontSize: 14,
                                color: AppColors.neutral400,
                              ),
                            ),
                            const SizedBox(height: 16),
                            Container(
                              decoration: BoxDecoration(
                                color: Colors.white,
                                borderRadius: BorderRadius.circular(16),
                                boxShadow: [
                                  BoxShadow(
                                    color: Colors.black.withValues(alpha: 0.04),
                                    blurRadius: 8,
                                    offset: const Offset(0, 2),
                                  ),
                                ],
                              ),
                              child: Material(
                                color: Colors.transparent,
                                child: InkWell(
                                  onTap: () {},
                                  borderRadius: BorderRadius.circular(16),
                                  child: const Padding(
                                    padding: EdgeInsets.symmetric(
                                      horizontal: 20,
                                      vertical: 12,
                                    ),
                                    child: Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        Icon(
                                          PhosphorIconsRegular.plus,
                                          size: 16,
                                          color: AppColors.neutral600,
                                        ),
                                        SizedBox(width: 8),
                                        Text(
                                          'Post Activity',
                                          style: TextStyle(
                                            color: AppColors.neutral800,
                                            fontWeight: FontWeight.w500,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 40),
                    ],
                  ),
                ),
              ),
            ],
          );
        },
      ),
      ),
    );
  }

  // Avatar editing methods
  Future<void> _showAvatarOptions(
    BuildContext context,
    String userId,
    ProfileModel profile,
  ) async {
    final hasExistingAvatar = profile.avatarUrl != null && profile.avatarUrl!.isNotEmpty;
    
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: AppColors.neutral200,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const SizedBox(height: 16),
              const Text(
                'Profile Photo',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w700,
                  color: AppColors.neutral900,
                ),
              ),
              const SizedBox(height: 16),
              ListTile(
                leading: Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    color: AppColors.brandTeal.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Icon(
                    PhosphorIconsBold.camera,
                    color: AppColors.brandTeal,
                    size: 22,
                  ),
                ),
                title: const Text(
                  'Take Photo',
                  style: TextStyle(
                    fontWeight: FontWeight.w600,
                    color: AppColors.neutral900,
                  ),
                ),
                onTap: () {
                  Navigator.pop(context);
                  _pickAndUploadImage(userId, ImageSource.camera);
                },
              ),
              ListTile(
                leading: Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    color: AppColors.brandTeal.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Icon(
                    PhosphorIconsBold.image,
                    color: AppColors.brandTeal,
                    size: 22,
                  ),
                ),
                title: const Text(
                  'Choose from Library',
                  style: TextStyle(
                    fontWeight: FontWeight.w600,
                    color: AppColors.neutral900,
                  ),
                ),
                onTap: () {
                  Navigator.pop(context);
                  _pickAndUploadImage(userId, ImageSource.gallery);
                },
              ),
              if (hasExistingAvatar) ...[
                const Divider(height: 24),
                ListTile(
                  leading: Container(
                    width: 44,
                    height: 44,
                    decoration: BoxDecoration(
                      color: AppColors.error.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Icon(
                      PhosphorIconsBold.trash,
                      color: AppColors.error,
                      size: 22,
                    ),
                  ),
                  title: const Text(
                    'Remove Photo',
                    style: TextStyle(
                      fontWeight: FontWeight.w600,
                      color: AppColors.error,
                    ),
                  ),
                  onTap: () {
                    Navigator.pop(context);
                    _removeProfileImage(userId);
                  },
                ),
              ],
              const SizedBox(height: 8),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _pickAndUploadImage(String userId, ImageSource source) async {
    try {
      final picker = ImagePicker();
      final profileNotifier = context.read<ProfileNotifier>();
      final pickedFile = await picker.pickImage(
        source: source,
        maxWidth: 512,
        maxHeight: 512,
        imageQuality: 85,
      );

      if (pickedFile == null) return;

      final imageFile = File(pickedFile.path);
      
      final success = await profileNotifier.updateProfileImage(userId, imageFile);

      if (!mounted) return;

      if (success) {
        _showSnack('Profile photo updated');
      } else {
        _showSnack('Failed to update photo', backgroundColor: AppColors.error);
      }
    } catch (e) {
      if (!mounted) return;
      _showSnack('Failed to pick image', backgroundColor: AppColors.error);
    }
  }

  Future<void> _removeProfileImage(String userId) async {
    final profileNotifier = context.read<ProfileNotifier>();
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: Colors.white,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
        ),
        title: const Text(
          'Remove Photo?',
          style: TextStyle(
            fontWeight: FontWeight.w700,
            color: AppColors.neutral900,
          ),
        ),
        content: const Text(
          'Are you sure you want to remove your profile photo?',
          style: TextStyle(color: AppColors.neutral600),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text(
              'Cancel',
              style: TextStyle(
                color: AppColors.neutral600,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.error,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10),
              ),
            ),
            child: const Text(
              'Remove',
              style: TextStyle(fontWeight: FontWeight.w600),
            ),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    if (!mounted) return;

    final success = await profileNotifier.removeProfileImage(userId);

    if (success) {
      _showSnack('Profile photo removed');
    } else {
      _showSnack('Failed to remove photo', backgroundColor: AppColors.error);
    }
  }

  // Handler methods for profile editing
  Future<void> _handleNameHandleEdit(
    BuildContext context,
    String userId,
    ProfileModel profile,
  ) async {
    await _showEditNameHandleDialog(
      context,
      initialName: profile.displayName,
      initialHandle: profile.handle,
      onSave: (name, handle) async {
        try {
          await context.read<ProfileNotifier>().updateNameAndHandle(
                userId,
                displayName: name,
                handle: handle,
              );
          if (mounted) {
            _showSnack('Profile updated');
          }
        } catch (_) {
          if (mounted) {
            _showSnack('Failed to update profile', backgroundColor: Colors.red);
          }
        }
      },
    );
  }

  Future<void> _handleLocationEdit(
    BuildContext context,
    String userId,
    String? currentValue,
  ) async {
    await _showEditLocationDialog(
      context,
      initialValue: currentValue,
      onSave: (value) async {
        final sanitized = value.trim();
        try {
          await context
              .read<ProfileNotifier>()
              .updateLocation(userId, sanitized.isEmpty ? null : sanitized);
          if (mounted) {
            _showSnack(
              sanitized.isEmpty ? 'Location cleared' : 'Location updated',
            );
          }
        } catch (_) {
          if (mounted) {
            _showSnack('Failed to update location',
                backgroundColor: Colors.red);
          }
        }
      },
    );
  }

  Future<void> _handleBioEdit(
    BuildContext context,
    String userId,
    String? currentValue,
  ) async {
    await _showEditBioDialog(
      context,
      initialValue: currentValue,
      onSave: (value) async {
        final sanitized = value.trim();
        try {
          await context
              .read<ProfileNotifier>()
              .updateBio(userId, sanitized.isEmpty ? null : sanitized);
          if (mounted) {
            _showSnack(
              sanitized.isEmpty ? 'Bio cleared' : 'Bio updated',
            );
          }
        } catch (_) {
          if (mounted) {
            _showSnack('Failed to update bio', backgroundColor: Colors.red);
          }
        }
      },
    );
  }

  Future<void> _handleInstagramEdit(
    BuildContext context,
    String userId,
    String? currentValue,
  ) async {
    await _showEditInstagramDialog(
      context,
      initialValue: currentValue?.replaceFirst(RegExp(r'^@'), ''),
      onSave: (value) async {
        final sanitized = value.trim().replaceFirst(RegExp(r'^@'), '');
        try {
          await context
              .read<ProfileNotifier>()
              .updateInstagram(userId, sanitized.isEmpty ? null : sanitized);
          if (mounted) {
            _showSnack(
              sanitized.isEmpty ? 'Instagram cleared' : 'Instagram linked',
            );
          }
        } catch (_) {
          if (mounted) {
            _showSnack('Failed to update Instagram',
                backgroundColor: Colors.red);
          }
        }
      },
    );
  }

  void _showCloseOptions(BuildContext context) {
    final tabController = context.read<TabNavigationNotifier>();
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (sheetContext) => Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              AppColors.brandNavy.withValues(alpha: 0.95),
              AppColors.brandNavyDeep.withValues(alpha: 0.98),
            ],
          ),
          borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
          border: Border.all(
            color: Colors.white.withValues(alpha: 0.1),
          ),
        ),
        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 20),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 36,
                  height: 4,
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.2),
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
                const SizedBox(height: 12),
                const Text(
                  'Leave Profile?',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
                const SizedBox(height: 10),
                Text(
                  'Head back to your home dashboard to keep exploring workouts and stats.',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 13,
                    color: Colors.white.withValues(alpha: 0.6),
                  ),
                ),
                const SizedBox(height: 20),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    onPressed: () {
                      Navigator.pop(sheetContext);
                      tabController.goHome();
                    },
                    icon: const Icon(PhosphorIconsRegular.house),
                    label: const Text('Go Home'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.brandTeal,
                      foregroundColor: Colors.black,
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 10),
                SizedBox(
                  width: double.infinity,
                  child: OutlinedButton(
                    onPressed: () => Navigator.pop(sheetContext),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: Colors.white,
                      side: BorderSide(color: Colors.white.withValues(alpha: 0.3)),
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    child: const Text('Stay on Profile'),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  void _showSnack(String message,
      {Color backgroundColor = AppColors.brandTeal}) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: backgroundColor,
      ),
    );
  }
}

// Widget classes
class _ActionButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final bool isPrimary;
  final VoidCallback onTap;

  const _ActionButton({
    required this.icon,
    required this.label,
    required this.isPrimary,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        gradient: isPrimary ? AppGradients.primary : null,
        color: isPrimary ? null : AppColors.neutral100,
        borderRadius: BorderRadius.circular(14),
        border: isPrimary
            ? null
            : Border.all(
                color: AppColors.neutral200,
              ),
        boxShadow: isPrimary
            ? [
                BoxShadow(
                  color: AppColors.brandTeal.withValues(alpha: 0.35),
                  blurRadius: 12,
                  offset: const Offset(0, 5),
                ),
              ]
            : null,
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(14),
          child: Container(
            padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 10),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  icon,
                  size: 18,
                  color: isPrimary ? Colors.white : AppColors.neutral600,
                ),
                const SizedBox(width: 8),
                Text(
                  label,
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: isPrimary ? Colors.white : AppColors.neutral800,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _AchievementSlot extends StatelessWidget {
  const _AchievementSlot();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 60,
      height: 60,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 3,
            offset: const Offset(0, 1),
          ),
        ],
      ),
      child: const Center(
        child: Icon(
          PhosphorIconsRegular.plus,
          color: AppColors.brandTeal,
          size: 20,
        ),
      ),
    );
  }
}

class _InfoRow extends StatelessWidget {
  final IconData icon;
  final String text;
  final VoidCallback onTap;

  const _InfoRow({
    required this.icon,
    required this.text,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final isPlaceholder = text.contains('Add') || text.contains('...');

    return Container(
      margin: const EdgeInsets.symmetric(vertical: 4),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(14),
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Row(
              children: [
                Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    color: isPlaceholder ? AppColors.neutral200 : null,
                    gradient: isPlaceholder ? null : AppGradients.primary,
                    shape: BoxShape.circle,
                    boxShadow: isPlaceholder
                        ? null
                        : [
                            BoxShadow(
                              color: AppColors.brandTeal.withValues(alpha: 0.3),
                              blurRadius: 8,
                              spreadRadius: 1,
                            ),
                          ],
                  ),
                  child: Icon(
                    icon,
                    size: 20,
                    color: isPlaceholder ? AppColors.neutral400 : Colors.white,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    text,
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight:
                          isPlaceholder ? FontWeight.w400 : FontWeight.w500,
                      color: isPlaceholder
                          ? AppColors.neutral400
                          : AppColors.neutral800,
                    ),
                  ),
                ),
                const Icon(
                  PhosphorIconsRegular.pencilSimple,
                  size: 16,
                  color: AppColors.neutral400,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// Dialog functions
void _showSettingsDialog(BuildContext context) {
  showModalBottomSheet(
    context: context,
    backgroundColor: Colors.transparent,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
    ),
    builder: (context) => Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            AppColors.brandNavy.withValues(alpha: 0.95),
            AppColors.brandNavyDeep.withValues(alpha: 0.98),
          ],
        ),
        borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
        border: Border.all(
          color: Colors.white.withValues(alpha: 0.1),
        ),
      ),
      padding: const EdgeInsets.symmetric(vertical: 16),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Text(
            'Settings',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: Colors.white,
            ),
          ),
          const SizedBox(height: 16),
          ListTile(
            leading: const Icon(PhosphorIconsBold.timer, color: Colors.white),
            title:
                const Text('Rest Timer', style: TextStyle(color: Colors.white)),
            trailing: const Icon(PhosphorIconsRegular.caretRight,
                color: Colors.white54),
            onTap: () {
              Navigator.pop(context);
              _showRestTimerSettings(context);
            },
          ),
          // Anonymous sign-in removed - all users are authenticated
        ],
      ),
    ),
  );
}

Future<void> _showEditNameHandleDialog(
  BuildContext context, {
  String? initialName,
  String? initialHandle,
  required Future<void> Function(String name, String handle) onSave,
}) async {
  final nameController = TextEditingController(text: initialName ?? '');
  final handleController = TextEditingController(text: initialHandle ?? '');

  await showDialog<void>(
    context: context,
    builder: (dialogContext) => AlertDialog(
      backgroundColor: Colors.transparent,
      content: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [
              AppColors.brandNavy.withValues(alpha: 0.9),
              AppColors.brandNavyDeep.withValues(alpha: 0.95),
            ],
          ),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: Colors.white.withValues(alpha: 0.15),
          ),
        ),
        padding: const EdgeInsets.all(20),
        child: SingleChildScrollView(
          padding: EdgeInsets.only(
            bottom: MediaQuery.of(dialogContext).viewInsets.bottom,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Edit Name & Handle',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: nameController,
                style: const TextStyle(color: Colors.white),
                decoration: InputDecoration(
                  labelText: 'Display Name',
                  labelStyle: TextStyle(color: Colors.white.withValues(alpha: 0.7)),
                  hintText: 'Enter your display name',
                  hintStyle: TextStyle(color: Colors.white.withValues(alpha: 0.5)),
                  filled: true,
                  fillColor: Colors.white.withValues(alpha: 0.1),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10),
                    borderSide:
                        BorderSide(color: Colors.white.withValues(alpha: 0.2)),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10),
                    borderSide:
                        BorderSide(color: Colors.white.withValues(alpha: 0.2)),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10),
                    borderSide: const BorderSide(
                        color: AppColors.brandTeal, width: 1.4),
                  ),
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: handleController,
                style: const TextStyle(color: Colors.white),
                decoration: InputDecoration(
                  labelText: 'Handle',
                  labelStyle: TextStyle(color: Colors.white.withValues(alpha: 0.7)),
                  hintText: '@username',
                  hintStyle: TextStyle(color: Colors.white.withValues(alpha: 0.5)),
                  prefixText: '@',
                  prefixStyle: const TextStyle(color: Colors.white),
                  filled: true,
                  fillColor: Colors.white.withValues(alpha: 0.1),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10),
                    borderSide:
                        BorderSide(color: Colors.white.withValues(alpha: 0.2)),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10),
                    borderSide:
                        BorderSide(color: Colors.white.withValues(alpha: 0.2)),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10),
                    borderSide: const BorderSide(
                        color: AppColors.brandTeal, width: 1.4),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  TextButton(
                    onPressed: () => Navigator.pop(dialogContext),
                    style: TextButton.styleFrom(
                      foregroundColor: Colors.white.withValues(alpha: 0.7),
                    ),
                    child: const Text('Cancel'),
                  ),
                  const SizedBox(width: 8),
                  ElevatedButton(
                    onPressed: () async {
                      Navigator.pop(dialogContext);
                      await onSave(nameController.text, handleController.text);
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.brandTeal,
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                    ),
                    child: const Text('Save'),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    ),
  );

  nameController.dispose();
  handleController.dispose();
}

Future<void> _showEditLocationDialog(
  BuildContext context, {
  String? initialValue,
  required Future<void> Function(String value) onSave,
}) async {
  final controller = TextEditingController(text: initialValue ?? '');
  await showDialog<void>(
    context: context,
    builder: (dialogContext) => AlertDialog(
      backgroundColor: Colors.transparent,
      content: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [
              AppColors.brandNavy.withValues(alpha: 0.9),
              AppColors.brandNavyDeep.withValues(alpha: 0.95),
            ],
          ),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: Colors.white.withValues(alpha: 0.15),
          ),
        ),
        padding: const EdgeInsets.all(20),
        child: SingleChildScrollView(
          padding: EdgeInsets.only(
            bottom: MediaQuery.of(dialogContext).viewInsets.bottom,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Edit Location',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: controller,
                style: const TextStyle(color: Colors.white),
                decoration: InputDecoration(
                  hintText: 'Enter your location',
                  hintStyle: TextStyle(color: Colors.white.withValues(alpha: 0.5)),
                  filled: true,
                  fillColor: Colors.white.withValues(alpha: 0.1),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10),
                    borderSide: BorderSide(
                      color: Colors.white.withValues(alpha: 0.2),
                    ),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10),
                    borderSide: BorderSide(
                      color: Colors.white.withValues(alpha: 0.2),
                    ),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10),
                    borderSide: const BorderSide(
                      color: AppColors.brandTeal,
                      width: 1.4,
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  TextButton(
                    onPressed: () => Navigator.pop(dialogContext),
                    style: TextButton.styleFrom(
                      foregroundColor: Colors.white.withValues(alpha: 0.7),
                    ),
                    child: const Text('Cancel'),
                  ),
                  const SizedBox(width: 8),
                  ElevatedButton(
                    onPressed: () async {
                      Navigator.pop(dialogContext);
                      await onSave(controller.text);
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.brandTeal,
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                    ),
                    child: const Text('Save'),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    ),
  );
  controller.dispose();
}

Future<void> _showEditBioDialog(
  BuildContext context, {
  String? initialValue,
  required Future<void> Function(String value) onSave,
}) async {
  final controller = TextEditingController(text: initialValue ?? '');
  await showDialog<void>(
    context: context,
    builder: (dialogContext) => AlertDialog(
      backgroundColor: Colors.transparent,
      content: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [
              AppColors.brandNavy.withValues(alpha: 0.9),
              AppColors.brandNavyDeep.withValues(alpha: 0.95),
            ],
          ),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: Colors.white.withValues(alpha: 0.15),
          ),
        ),
        padding: const EdgeInsets.all(20),
        child: SingleChildScrollView(
          padding: EdgeInsets.only(
            bottom: MediaQuery.of(dialogContext).viewInsets.bottom,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Edit Bio',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: controller,
                maxLines: 3,
                style: const TextStyle(color: Colors.white),
                decoration: InputDecoration(
                  hintText: 'Tell us about yourself...',
                  hintStyle: TextStyle(color: Colors.white.withValues(alpha: 0.5)),
                  filled: true,
                  fillColor: Colors.white.withValues(alpha: 0.1),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10),
                    borderSide: BorderSide(
                      color: Colors.white.withValues(alpha: 0.2),
                    ),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10),
                    borderSide: BorderSide(
                      color: Colors.white.withValues(alpha: 0.2),
                    ),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10),
                    borderSide: const BorderSide(
                      color: AppColors.brandTeal,
                      width: 1.4,
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  TextButton(
                    onPressed: () => Navigator.pop(dialogContext),
                    style: TextButton.styleFrom(
                      foregroundColor: Colors.white.withValues(alpha: 0.7),
                    ),
                    child: const Text('Cancel'),
                  ),
                  const SizedBox(width: 8),
                  ElevatedButton(
                    onPressed: () async {
                      Navigator.pop(dialogContext);
                      await onSave(controller.text);
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.brandTeal,
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                    ),
                    child: const Text('Save'),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    ),
  );
  controller.dispose();
}

Future<void> _showEditInstagramDialog(
  BuildContext context, {
  String? initialValue,
  required Future<void> Function(String value) onSave,
}) async {
  final controller = TextEditingController(text: initialValue ?? '');
  await showDialog<void>(
    context: context,
    builder: (dialogContext) => AlertDialog(
      backgroundColor: Colors.transparent,
      content: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [
              AppColors.brandNavy.withValues(alpha: 0.9),
              AppColors.brandNavyDeep.withValues(alpha: 0.95),
            ],
          ),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: Colors.white.withValues(alpha: 0.15),
          ),
        ),
        padding: const EdgeInsets.all(20),
        child: SingleChildScrollView(
          padding: EdgeInsets.only(
            bottom: MediaQuery.of(dialogContext).viewInsets.bottom,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Add Instagram',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: controller,
                style: const TextStyle(color: Colors.white),
                decoration: InputDecoration(
                  hintText: '@username',
                  hintStyle: TextStyle(color: Colors.white.withValues(alpha: 0.5)),
                  prefixText: '@',
                  prefixStyle: const TextStyle(color: Colors.white),
                  filled: true,
                  fillColor: Colors.white.withValues(alpha: 0.1),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10),
                    borderSide: BorderSide(
                      color: Colors.white.withValues(alpha: 0.2),
                    ),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10),
                    borderSide: BorderSide(
                      color: Colors.white.withValues(alpha: 0.2),
                    ),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10),
                    borderSide: const BorderSide(
                      color: AppColors.brandTeal,
                      width: 1.4,
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  TextButton(
                    onPressed: () => Navigator.pop(dialogContext),
                    style: TextButton.styleFrom(
                      foregroundColor: Colors.white.withValues(alpha: 0.7),
                    ),
                    child: const Text('Cancel'),
                  ),
                  const SizedBox(width: 8),
                  ElevatedButton(
                    onPressed: () async {
                      Navigator.pop(dialogContext);
                      await onSave(controller.text);
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.brandTeal,
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                    ),
                    child: const Text('Save'),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    ),
  );
  controller.dispose();
}

// _showLinkAccountDialog removed - anonymous sign-in is disabled

void _showRestTimerSettings(BuildContext context) {
  showModalBottomSheet(
    context: context,
    backgroundColor: Colors.transparent,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
    ),
    builder: (context) => Consumer<SettingsNotifier>(
      builder: (context, settings, child) => Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              AppColors.brandNavy.withValues(alpha: 0.95),
              AppColors.brandNavyDeep.withValues(alpha: 0.98),
            ],
          ),
          borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
          border: Border.all(
            color: Colors.white.withValues(alpha: 0.1),
          ),
        ),
        padding: const EdgeInsets.all(16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text(
              'Rest Timer Settings',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: Colors.white,
              ),
            ),
            const SizedBox(height: 22),
            // Duration display
            Text(
              _formatDuration(settings.restTimerDuration),
              style: const TextStyle(
                fontSize: 28,
                fontWeight: FontWeight.bold,
                color: AppColors.brandTeal,
              ),
            ),
            const SizedBox(height: 16),
            SliderTheme(
              data: SliderTheme.of(context).copyWith(
                activeTrackColor: AppColors.brandTeal,
                thumbColor: AppColors.brandTeal,
                overlayColor: AppColors.brandTeal.withValues(alpha: 0.2),
                inactiveTrackColor: Colors.white24,
              ),
              child: Slider(
                value: settings.restTimerDuration.toDouble(),
                min: 30,
                max: 300,
                divisions: 18,
                onChanged: (value) {
                  settings.setRestTimerDuration(value.round());
                },
              ),
            ),
            const Padding(
              padding: EdgeInsets.symmetric(horizontal: 16),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text('30s',
                      style: TextStyle(color: Colors.white54, fontSize: 11)),
                  Text('5m',
                      style: TextStyle(color: Colors.white54, fontSize: 11)),
                ],
              ),
            ),
            const SizedBox(height: 20),
            // Haptic Feedback Toggle
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                children: [
                  Icon(
                    PhosphorIconsBold.vibrate,
                    color: settings.hapticFeedbackEnabled 
                        ? AppColors.brandTeal 
                        : Colors.white54,
                    size: 22,
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Haptic Feedback',
                          style: TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w600,
                            color: Colors.white,
                          ),
                        ),
                        Text(
                          'Vibrate on timer start & end',
                          style: TextStyle(
                            fontSize: 12,
                            color: Colors.white.withValues(alpha: 0.6),
                          ),
                        ),
                      ],
                    ),
                  ),
                  Switch(
                    value: settings.hapticFeedbackEnabled,
                    onChanged: (value) {
                      settings.setHapticFeedbackEnabled(value);
                    },
                    activeThumbColor: AppColors.brandTeal,
                    activeTrackColor: AppColors.brandTeal.withValues(alpha: 0.3),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
          ],
        ),
      ),
    ),
  );
}

String _formatDuration(int seconds) {
  if (seconds < 60) {
    return '${seconds}s';
  } else {
    int minutes = seconds ~/ 60;
    int remainingSeconds = seconds % 60;
    if (remainingSeconds == 0) {
      return '${minutes}m';
    } else {
      return '${minutes}m ${remainingSeconds}s';
    }
  }
}
