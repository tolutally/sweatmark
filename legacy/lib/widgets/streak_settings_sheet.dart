import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:phosphor_icons/phosphor_icons.dart';
import '../state/streak_notifier.dart';
import '../models/streak_model.dart';
import '../theme/app_theme.dart';

/// Bottom sheet for configuring streak settings
class StreakSettingsSheet extends StatefulWidget {
  const StreakSettingsSheet({super.key});

  @override
  State<StreakSettingsSheet> createState() => _StreakSettingsSheetState();
}

class _StreakSettingsSheetState extends State<StreakSettingsSheet> {
  late StreakType _selectedType;
  late int _weeklyGoal;
  late Set<int> _selectedDays;
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    final streakNotifier = context.read<StreakNotifier?>();
    final streak = streakNotifier?.streak;

    _selectedType = streak?.type ?? StreakType.daily;
    _weeklyGoal = streak?.weeklyGoal ?? 3;
    _selectedDays = Set<int>.from(streak?.scheduledDays ?? []);
  }

  Future<void> _saveSettings() async {
    setState(() => _isSaving = true);

    try {
      final streakNotifier = context.read<StreakNotifier?>();
      if (streakNotifier == null) return;

      await streakNotifier.updateSettings(
        type: _selectedType,
        weeklyGoal: _weeklyGoal,
        scheduledDays: _selectedDays.toList()..sort(),
      );

      if (mounted) {
        Navigator.of(context).pop();
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Streak settings updated'),
            backgroundColor: AppColors.success,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error: $e'),
            backgroundColor: AppColors.error,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isSaving = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom,
      ),
      child: SafeArea(
        child: SingleChildScrollView(
          child: Padding(
            padding: const EdgeInsets.all(24.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                // Header
                Row(
                  children: [
                    const Icon(
                      PhosphorIconsBold.fire,
                      color: AppColors.warning,
                      size: 28,
                    ),
                    const SizedBox(width: 12),
                    const Expanded(
                      child: Text(
                        'Streak Settings',
                        style: TextStyle(
                          fontSize: 22,
                          fontWeight: FontWeight.bold,
                          color: AppColors.neutral900,
                        ),
                      ),
                    ),
                    IconButton(
                      icon: const Icon(PhosphorIconsRegular.x),
                      onPressed: () => Navigator.of(context).pop(),
                    ),
                  ],
                ),

                const SizedBox(height: 24),

                // Streak Type Selector
                const Text(
                  'Streak Type',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    color: AppColors.neutral900,
                  ),
                ),
                const SizedBox(height: 12),

                // Segmented Control
                Container(
                  decoration: BoxDecoration(
                    color: AppColors.neutral100,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Row(
                    children: [
                      Expanded(
                        child: _SegmentButton(
                          label: 'Daily',
                          isSelected: _selectedType == StreakType.daily,
                          onTap: () => setState(() => _selectedType = StreakType.daily),
                        ),
                      ),
                      Expanded(
                        child: _SegmentButton(
                          label: 'Weekly',
                          isSelected: _selectedType == StreakType.weekly,
                          onTap: () => setState(() => _selectedType = StreakType.weekly),
                        ),
                      ),
                      Expanded(
                        child: _SegmentButton(
                          label: 'Custom',
                          isSelected: _selectedType == StreakType.custom,
                          onTap: () => setState(() => _selectedType = StreakType.custom),
                        ),
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 24),

                // Type-specific settings
                if (_selectedType == StreakType.daily) ...const [
                  _InfoCard(
                    icon: PhosphorIconsRegular.info,
                    text: 'Complete at least 1 workout every day to maintain your streak. You have a 6-hour grace period after midnight.',
                  ),
                ] else if (_selectedType == StreakType.weekly) ...[
                  const Text(
                    'Weekly Goal',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                      color: AppColors.neutral900,
                    ),
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      IconButton(
                        icon: const Icon(PhosphorIconsBold.minus),
                        onPressed: _weeklyGoal > 1
                            ? () => setState(() => _weeklyGoal--)
                            : null,
                        color: AppColors.brandTeal,
                      ),
                      Expanded(
                        child: Container(
                          padding: const EdgeInsets.symmetric(vertical: 16),
                          decoration: BoxDecoration(
                            color: AppColors.neutral100,
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: AppColors.neutral200),
                          ),
                          child: Text(
                            '$_weeklyGoal workouts/week',
                            textAlign: TextAlign.center,
                            style: const TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                              color: AppColors.neutral900,
                            ),
                          ),
                        ),
                      ),
                      IconButton(
                        icon: const Icon(PhosphorIconsBold.plus),
                        onPressed: _weeklyGoal < 7
                            ? () => setState(() => _weeklyGoal++)
                            : null,
                        color: AppColors.brandTeal,
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  const _InfoCard(
                    icon: PhosphorIconsRegular.info,
                    text: 'Complete your weekly goal by Sunday 6 AM. Week starts Monday.',
                  ),
                ] else ...[
                  const Text(
                    'Scheduled Days',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                      color: AppColors.neutral900,
                    ),
                  ),
                  const SizedBox(height: 12),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: List.generate(7, (index) {
                      final day = index + 1; // 1=Mon, 7=Sun
                      final dayNames = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
                      final isSelected = _selectedDays.contains(day);

                      return GestureDetector(
                        onTap: () {
                          setState(() {
                            if (isSelected) {
                              _selectedDays.remove(day);
                            } else {
                              _selectedDays.add(day);
                            }
                          });
                        },
                        child: Container(
                          width: 48,
                          height: 48,
                          decoration: BoxDecoration(
                            color: isSelected ? AppColors.brandTeal : AppColors.neutral100,
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(
                              color: isSelected ? AppColors.brandTeal : AppColors.neutral200,
                            ),
                          ),
                          child: Center(
                            child: Text(
                              dayNames[index],
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                                color: isSelected ? Colors.white : AppColors.neutral600,
                              ),
                            ),
                          ),
                        ),
                      );
                    }),
                  ),
                  const SizedBox(height: 12),
                  const _InfoCard(
                    icon: PhosphorIconsRegular.info,
                    text: 'Complete a workout on each selected day. 6-hour grace period after each day.',
                  ),
                ],

                const SizedBox(height: 32),

                // Save Button
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: _isSaving ? null : _saveSettings,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.brandTeal,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    child: _isSaving
                        ? const SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: Colors.white,
                            ),
                          )
                        : const Text(
                            'Save Settings',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                  ),
                ),

                const SizedBox(height: 12),

                // Warning
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: AppColors.warning.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: AppColors.warning.withValues(alpha: 0.3),
                    ),
                  ),
                  child: const Row(
                    children: [
                      Icon(
                        PhosphorIconsRegular.warning,
                        color: AppColors.warning,
                        size: 20,
                      ),
                      SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          'Changing streak type will reset your current streak.',
                          style: TextStyle(
                            fontSize: 12,
                            color: AppColors.neutral600,
                          ),
                        ),
                      ),
                    ],
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

class _SegmentButton extends StatelessWidget {
  final String label;
  final bool isSelected;
  final VoidCallback onTap;

  const _SegmentButton({
    required this.label,
    required this.isSelected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 12),
        decoration: BoxDecoration(
          color: isSelected ? Colors.white : Colors.transparent,
          borderRadius: BorderRadius.circular(10),
          boxShadow: isSelected
              ? [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.05),
                    blurRadius: 4,
                    offset: const Offset(0, 2),
                  ),
                ]
              : null,
        ),
        child: Text(
          label,
          textAlign: TextAlign.center,
          style: TextStyle(
            fontSize: 14,
            fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
            color: isSelected ? AppColors.brandTeal : AppColors.neutral600,
          ),
        ),
      ),
    );
  }
}

class _InfoCard extends StatelessWidget {
  final IconData icon;
  final String text;

  const _InfoCard({
    required this.icon,
    required this.text,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.brandTeal.withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: AppColors.brandTeal.withValues(alpha: 0.1),
        ),
      ),
      child: Row(
        children: [
          Icon(
            icon,
            color: AppColors.brandTeal,
            size: 20,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              text,
              style: const TextStyle(
                fontSize: 12,
                color: AppColors.neutral600,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
