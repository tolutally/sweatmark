import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:phosphor_icons/phosphor_icons.dart';
import '../state/analytics_notifier.dart';
import '../state/streak_notifier.dart';
import '../state/flame_notifier.dart';
import '../models/analytics_model.dart';
import '../widgets/analytics/volume_trend_chart.dart';
import '../widgets/analytics/muscle_distribution_chart.dart';
import '../widgets/analytics/analytics_widgets.dart';
import '../theme/app_theme.dart';


class AnalyticsScreen extends StatelessWidget {
  const AnalyticsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: const SystemUiOverlayStyle(
        statusBarColor: Colors.transparent,
        statusBarIconBrightness: Brightness.dark,
        statusBarBrightness: Brightness.light,
      ),
      child: Scaffold(
        backgroundColor: const Color(0xFFF5F5F5),
        body: SafeArea(
          child: Consumer<AnalyticsNotifier?>(
            builder: (context, notifier, child) {
              if (notifier == null) {
                return const Center(
                  child: Text('Please sign in to view analytics'),
                );
              }

              if (notifier.isLoading) {
                return const Center(
                  child: CircularProgressIndicator(
                    color: AppColors.brandTeal,
                  ),
                );
              }

              if (notifier.error != null) {
                return Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(PhosphorIconsBold.warning,
                          size: 48, color: Colors.orange),
                      const SizedBox(height: 16),
                      const Text('Error loading analytics'),
                      const SizedBox(height: 8),
                      ElevatedButton(
                        onPressed: notifier.refresh,
                        child: const Text('Retry'),
                      ),
                    ],
                  ),
                );
              }

              return RefreshIndicator(
                onRefresh: notifier.refresh,
                color: AppColors.brandTeal,
                child: SingleChildScrollView(
                  physics: const AlwaysScrollableScrollPhysics(),
                  padding: const EdgeInsets.all(20),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Header
                      _buildHeader(context, notifier),
                      const SizedBox(height: 20),

                      // Tier Progress Card
                      _buildTierCard(notifier),
                      const SizedBox(height: 20),

                      // Streak & Flame Row
                      _buildStreakFlameRow(context),
                      const SizedBox(height: 24),

                      // Time Window Selector
                      _buildWindowSelector(notifier),
                      const SizedBox(height: 20),

                      // Section 1: Overview Stats
                      _buildSectionTitle('Overview'),
                      const SizedBox(height: 12),
                      _buildOverviewStats(notifier),
                      const SizedBox(height: 24),

                      // Section 2: Progress
                      _buildSectionTitle('Progress'),
                      const SizedBox(height: 12),
                      _buildProgressSection(notifier),
                      const SizedBox(height: 24),

                      // Section 3: Muscle Balance
                      _buildSectionTitle('Muscle Balance'),
                      const SizedBox(height: 12),
                      _buildMuscleSection(context, notifier),
                      const SizedBox(height: 24),

                      // Section 4: Personal Records
                      _buildSectionTitle('Personal Records'),
                      const SizedBox(height: 12),
                      _buildPRSection(notifier),

                      const SizedBox(height: 40),
                    ],
                  ),
                ),
              );
            },
          ),
        ),
      ),
    );
  }

  Widget _buildHeader(BuildContext context, AnalyticsNotifier notifier) {
    return Row(
      children: [
        const Text(
          'Analytics',
          style: TextStyle(
            fontSize: 28,
            fontWeight: FontWeight.bold,
            color: Colors.black87,
          ),
        ),
        const Spacer(),
        // Tier badge
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          decoration: BoxDecoration(
            color: AppColors.brandTeal.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(20),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                notifier.tier.emoji,
                style: const TextStyle(fontSize: 14),
              ),
              const SizedBox(width: 6),
              Text(
                notifier.tier.label.split(' ').last, // Just "Starter", "Builder", etc
                style: const TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: AppColors.brandTeal,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildTierCard(AnalyticsNotifier notifier) {
    final tierProgress = notifier.getTierProgress();
    final currentTier = tierProgress['currentTier'] as SweatTier;
    final nextTier = tierProgress['nextTier'] as SweatTier?;

    return TierProgressCard(
      currentTier: currentTier.label,
      nextTier: nextTier?.label,
      emoji: currentTier.emoji,
      progress: tierProgress['progress'] as double,
      message: tierProgress['message'] as String,
    );
  }

  Widget _buildStreakFlameRow(BuildContext context) {
    return Row(
      children: [
        // Streak card
        Expanded(
          child: Consumer<StreakNotifier?>(
            builder: (context, streakNotifier, _) {
              final streak = streakNotifier?.streak;
              final isLoading = streakNotifier?.isLoading ?? true;

              return Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: const Color(0xFFFF9500).withValues(alpha: 0.1),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(
                        PhosphorIconsBold.fire,
                        color: Color(0xFFFF9500),
                        size: 20,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          isLoading ? '--' : '${streak?.current ?? 0}',
                          style: const TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                            color: Colors.black87,
                          ),
                        ),
                        const Text(
                          'Day Streak',
                          style: TextStyle(
                            fontSize: 11,
                            color: Colors.black38,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              );
            },
          ),
        ),
        const SizedBox(width: 12),
        // Flame card (compact)
        Expanded(
          child: Consumer<FlameNotifier?>(
            builder: (context, flameNotifier, _) {
              final stats = flameNotifier?.stats;
              final isLoading = flameNotifier?.isLoading ?? true;

              return Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: const Color(0xFFFF5722).withValues(alpha: 0.1),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(
                        PhosphorIconsBold.flame,
                        color: Color(0xFFFF5722),
                        size: 20,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          isLoading
                              ? '--'
                              : FlameNotifier.formatVolume(stats?.peak7d ?? 0),
                          style: const TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                            color: Colors.black87,
                          ),
                        ),
                        Text(
                          isLoading ? 'Peak' : stats?.level.label ?? 'Spark',
                          style: const TextStyle(
                            fontSize: 11,
                            color: Colors.black38,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              );
            },
          ),
        ),
      ],
    );
  }

  Widget _buildWindowSelector(AnalyticsNotifier notifier) {
    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: AnalyticsWindow.values.map((window) {
          final isSelected = notifier.selectedWindow == window;
          return Expanded(
            child: GestureDetector(
              onTap: () => notifier.setWindow(window),
              child: Container(
                padding: const EdgeInsets.symmetric(vertical: 12),
                decoration: BoxDecoration(
                  color: isSelected ? AppColors.brandTeal : Colors.transparent,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Text(
                  window.label,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: isSelected ? Colors.white : Colors.black54,
                  ),
                ),
              ),
            ),
          );
        }).toList(),
      ),
    );
  }

  Widget _buildSectionTitle(String title) {
    return Text(
      title,
      style: const TextStyle(
        fontSize: 18,
        fontWeight: FontWeight.bold,
        color: Colors.black87,
      ),
    );
  }

  Widget _buildOverviewStats(AnalyticsNotifier notifier) {
    final summary = notifier.summary ?? AnalyticsSummary.empty();

    return Column(
      children: [
        Row(
          children: [
            Expanded(
              child: StatCard(
                title: 'Workouts',
                value: '${summary.workouts}',
                icon: PhosphorIconsBold.barbell,
                iconColor: AppColors.brandTeal,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: StatCard(
                title: 'Total Volume',
                value: AnalyticsSummary.formatVolume(summary.totalVolume),
                icon: PhosphorIconsBold.chartLineUp,
                iconColor: const Color(0xFF6C5CE7),
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(
              child: StatCard(
                title: 'Time Trained',
                value: AnalyticsSummary.formatTime(summary.totalTimeMinutes),
                icon: PhosphorIconsBold.clock,
                iconColor: const Color(0xFFFF9500),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: StatCard(
                title: 'Consistency',
                value: '${summary.consistencyPercent.toStringAsFixed(0)}%',
                subtitle: notifier.getConsistencyRating(),
                icon: PhosphorIconsBold.chartPie,
                iconColor: const Color(0xFF9B59B6),
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildProgressSection(AnalyticsNotifier notifier) {
    final summary = notifier.summary ?? AnalyticsSummary.empty();

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Volume Trend Chart
          const Text(
            'Volume Trend',
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w600,
              color: Colors.black54,
            ),
          ),
          const SizedBox(height: 16),
          SizedBox(
            height: 180,
            child: VolumeTrendChart(
              dailyStats: summary.dailyStats,
            ),
          ),
          const SizedBox(height: 24),

          // PR Highlights
          Row(
            children: [
              const Icon(PhosphorIconsBold.trophy,
                  color: Color(0xFFFFD700), size: 20),
              const SizedBox(width: 8),
              Text(
                '${summary.prCountThisMonth} PRs this month',
                style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: Colors.black87,
                ),
              ),
            ],
          ),
          if (summary.recentPRs.isNotEmpty) ...[
            const SizedBox(height: 12),
            ...summary.recentPRs.take(3).map((pr) => Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: Row(
                    children: [
                      if (pr.isNew)
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 6, vertical: 2),
                          margin: const EdgeInsets.only(right: 8),
                          decoration: BoxDecoration(
                            color: AppColors.brandTeal,
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: const Text(
                            'NEW',
                            style: TextStyle(
                              fontSize: 9,
                              fontWeight: FontWeight.bold,
                              color: Colors.white,
                            ),
                          ),
                        ),
                      Expanded(
                        child: Text(
                          pr.exerciseName,
                          style: const TextStyle(
                            fontSize: 13,
                            color: Colors.black87,
                          ),
                        ),
                      ),
                      Text(
                        '${pr.value.toStringAsFixed(0)} ${pr.unit}',
                        style: const TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          color: Colors.black87,
                        ),
                      ),
                    ],
                  ),
                )),
          ],
        ],
      ),
    );
  }

  Widget _buildMuscleSection(BuildContext context, AnalyticsNotifier notifier) {
    final summary = notifier.summary ?? AnalyticsSummary.empty();
    final distribution = summary.muscleDistribution;

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Muscle distribution chart
          SizedBox(
            height: 160,
            child: MuscleDistributionChart(
              distribution: distribution.distribution,
              size: 140,
            ),
          ),
          const SizedBox(height: 20),

          // Most/Least trained
          if (distribution.mostTrained.isNotEmpty) ...[
            Row(
              children: [
                Expanded(
                  child: _buildMuscleHighlight(
                    'Most Trained',
                    distribution.mostTrained,
                    AppColors.brandTeal,
                    PhosphorIconsBold.trendUp,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _buildMuscleHighlight(
                    'Least Trained',
                    distribution.leastTrained,
                    const Color(0xFFFF6B6B),
                    PhosphorIconsBold.trendDown,
                  ),
                ),
              ],
            ),
          ],

          // Recovery tie-in
          const SizedBox(height: 16),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: const Color(0xFFE8F5E9),
              borderRadius: BorderRadius.circular(10),
            ),
            child: const Row(
              children: [
                Icon(PhosphorIconsBold.heartbeat,
                    color: Color(0xFF4CAF50), size: 18),
                SizedBox(width: 10),
                Expanded(
                  child: Text(
                    'Check Recovery tab for muscle availability',
                    style: TextStyle(
                      fontSize: 12,
                      color: Color(0xFF2E7D32),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMuscleHighlight(
    String label,
    String muscle,
    Color color,
    IconData icon,
  ) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, color: color, size: 14),
              const SizedBox(width: 6),
              Text(
                label,
                style: TextStyle(
                  fontSize: 11,
                  color: color,
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            muscle,
            style: const TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w600,
              color: Colors.black87,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPRSection(AnalyticsNotifier notifier) {
    final summary = notifier.summary ?? AnalyticsSummary.empty();
    final prs = summary.recentPRs;

    if (prs.isEmpty) {
      return Container(
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
        ),
        child: const Center(
          child: Column(
            children: [
              Icon(PhosphorIconsBold.trophy,
                  size: 40, color: Color(0xFFE0E0E0)),
              SizedBox(height: 12),
              Text(
                'No personal records yet',
                style: TextStyle(
                  fontSize: 14,
                  color: Colors.black38,
                ),
              ),
              SizedBox(height: 4),
              Text(
                'Keep training to set your first PR!',
                style: TextStyle(
                  fontSize: 12,
                  color: Colors.black26,
                ),
              ),
            ],
          ),
        ),
      );
    }

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        children: prs.map((pr) {
          return Padding(
            padding: const EdgeInsets.symmetric(vertical: 8),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: const Color(0xFFFFD700).withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Icon(
                    PhosphorIconsBold.trophy,
                    color: Color(0xFFFFD700),
                    size: 18,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Flexible(
                            child: Text(
                              pr.exerciseName,
                              style: const TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.w600,
                                color: Colors.black87,
                              ),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          if (pr.isNew) ...[
                            const SizedBox(width: 8),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 6, vertical: 2),
                              decoration: BoxDecoration(
                                color: AppColors.brandTeal,
                                borderRadius: BorderRadius.circular(4),
                              ),
                              child: const Text(
                                'NEW',
                                style: TextStyle(
                                  fontSize: 9,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.white,
                                ),
                              ),
                            ),
                          ],
                        ],
                      ),
                      Text(
                        pr.muscleGroup,
                        style: const TextStyle(
                          fontSize: 11,
                          color: Colors.black38,
                        ),
                      ),
                    ],
                  ),
                ),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(
                      '${pr.value.toStringAsFixed(0)} ${pr.unit}',
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: Colors.black87,
                      ),
                    ),
                    Text(
                      _formatDate(pr.achievedAt),
                      style: const TextStyle(
                        fontSize: 10,
                        color: Colors.black26,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          );
        }).toList(),
      ),
    );
  }

  String _formatDate(DateTime date) {
    final now = DateTime.now();
    final diff = now.difference(date).inDays;

    if (diff == 0) return 'Today';
    if (diff == 1) return 'Yesterday';
    if (diff < 7) return '$diff days ago';
    if (diff < 30) return '${diff ~/ 7} weeks ago';
    return '${date.month}/${date.day}';
  }
}
