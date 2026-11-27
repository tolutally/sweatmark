import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../theme/app_theme.dart';

/// Two intro pages shown once on this device before sign-up. Device-level
/// preference only; no account data is read or written while signed out.
class OnboardingScreen extends StatefulWidget {
  final VoidCallback onDone;

  /// False for previews, so trying the intro never hides it from real use.
  final bool remember;
  const OnboardingScreen(
      {super.key, required this.onDone, this.remember = true});

  static const seenKey = 'onboarding_seen_v1';

  static Future<bool> hasBeenSeen() async {
    try {
      return (await SharedPreferences.getInstance()).getBool(seenKey) ?? false;
    } catch (_) {
      return false;
    }
  }

  static Future<void> markSeen() async {
    try {
      await (await SharedPreferences.getInstance()).setBool(seenKey, true);
    } catch (_) {
      // Showing the intro again next launch is harmless.
    }
  }

  @override
  State<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _Page {
  final String title, subtitle, photo, chip;
  final IconData chipIcon;

  /// Share of the figure that rises above the card (0 keeps it inside).
  final double popOut;

  /// Height divided by width of the cut-out photo.
  final double aspect;
  final Color accent;
  final List<IconData> bubbles;
  const _Page({
    required this.title,
    required this.subtitle,
    required this.photo,
    this.popOut = 0,
    required this.aspect,
    required this.chip,
    required this.chipIcon,
    required this.accent,
    required this.bubbles,
  });
}

const _pages = [
  _Page(
    title: 'Log every set in seconds',
    subtitle:
        'Pick a routine or start empty. Your last numbers fill in, so you just lift.',
    photo: 'assets/onboarding/curl.webp',
    aspect: 900 / 716,
    chip: 'Last time · 12 kg × 10',
    chipIcon: Icons.history_rounded,
    accent: AppColors.coral,
    bubbles: [
      Icons.timer_outlined,
      Icons.verified_rounded,
      Icons.calendar_month_rounded,
    ],
  ),
  _Page(
    title: 'Watch your progress add up',
    subtitle:
        'History, weekly streaks and personal records — saved even when you are offline.',
    photo: 'assets/onboarding/lace.webp',
    popOut: .16,
    aspect: 805 / 720,
    chip: 'New PR',
    chipIcon: Icons.emoji_events_outlined,
    accent: AppColors.lavender,
    bubbles: [
      Icons.local_fire_department_outlined,
      Icons.show_chart_rounded,
      Icons.cloud_off_rounded,
    ],
  ),
];

class _OnboardingScreenState extends State<OnboardingScreen> {
  final _controller = PageController();
  int _index = 0;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _finish() async {
    if (widget.remember) await OnboardingScreen.markSeen();
    widget.onDone();
  }

  void _next() {
    if (_index == _pages.length - 1) {
      _finish();
    } else {
      _controller.nextPage(
          duration: const Duration(milliseconds: 320), curve: Curves.easeOut);
    }
  }

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final dark = Theme.of(context).brightness == Brightness.dark;
    final accent = _pages[_index].accent;
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: dark ? SystemUiOverlayStyle.light : SystemUiOverlayStyle.dark,
      child: Scaffold(
        backgroundColor: colors.surface,
        body: SafeArea(
          child: Column(children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 16, 24, 0),
              // Two intro pages, then sign-up as the third step.
              child: Row(children: [
                for (var i = 0; i < 3; i++) ...[
                  if (i > 0) const SizedBox(width: 10),
                  Expanded(
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 250),
                      height: 6,
                      decoration: BoxDecoration(
                        color: i <= _index
                            ? accent
                            : colors.surfaceContainerHighest,
                        borderRadius: BorderRadius.circular(99),
                      ),
                    ),
                  ),
                ],
              ]),
            ),
            Expanded(
              child: PageView.builder(
                controller: _controller,
                itemCount: _pages.length,
                onPageChanged: (index) => setState(() => _index = index),
                itemBuilder: (_, index) => _OnboardingPage(page: _pages[index]),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 8, 24, 20),
              child: Row(children: [
                FilledButton(
                  onPressed: _finish,
                  style: FilledButton.styleFrom(
                    backgroundColor:
                        dark ? colors.surfaceContainerHighest : AppColors.ink,
                    foregroundColor: Colors.white,
                    minimumSize: const Size(150, 56),
                    shape: const StadiumBorder(),
                    textStyle: const TextStyle(
                        fontSize: 16, fontWeight: FontWeight.w500),
                  ),
                  child: const Text('Skip'),
                ),
                const Spacer(),
                IconButton(
                  tooltip: _index == _pages.length - 1
                      ? 'Continue to sign up'
                      : 'Next',
                  onPressed: _next,
                  style: IconButton.styleFrom(
                    backgroundColor: accent,
                    foregroundColor: accent == AppColors.coral
                        ? Colors.white
                        : AppColors.ink,
                    minimumSize: const Size(60, 60),
                  ),
                  icon: const Icon(Icons.chevron_right_rounded, size: 30),
                ),
              ]),
            ),
          ]),
        ),
      ),
    );
  }
}

class _OnboardingPage extends StatelessWidget {
  final _Page page;
  const _OnboardingPage({required this.page});

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final dark = Theme.of(context).brightness == Brightness.dark;
    final tint = page.accent.withValues(alpha: dark ? .22 : .26);
    final iconColor = page.accent == AppColors.coral
        ? AppColors.coral
        : const Color(0xFF6741B2);
    Widget bubble(IconData icon, double size) => Container(
          width: size,
          height: size,
          decoration: BoxDecoration(
            color: colors.surface.withValues(alpha: .94),
            shape: BoxShape.circle,
            boxShadow: [
              BoxShadow(
                  color: Colors.black.withValues(alpha: .06), blurRadius: 12),
            ],
          ),
          child: Icon(icon, color: iconColor, size: size * .4),
        );
    return LayoutBuilder(builder: (context, box) {
      final textScale = MediaQuery.textScalerOf(context).scale(1);
      // Leave the text room on short screens and with large text.
      final heroHeight = math.max(
          240.0, math.min(box.maxHeight - 170 * textScale, box.maxWidth * 1.3));
      return SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(24, 16, 24, 8),
        child: Column(children: [
          SizedBox(
            height: heroHeight,
            child: LayoutBuilder(builder: (context, hero) {
              final w = hero.maxWidth, h = hero.maxHeight;
              final figureWidth = page.popOut > 0 ? w : w * .92;
              final figureHeight = math.min(h, figureWidth * page.aspect);
              // The card starts below the figure's top by popOut of its height.
              final cardTop = page.popOut == 0
                  ? 0.0
                  : h - figureHeight + figureHeight * page.popOut;
              // Clipping only the bottom corners lets the figure rise out of
              // the top of the card, as in the reference.
              return ClipRRect(
                borderRadius:
                    const BorderRadius.vertical(bottom: Radius.circular(32)),
                child: Stack(children: [
                  Positioned(
                    left: 0,
                    right: 0,
                    top: cardTop,
                    bottom: 0,
                    child: DecoratedBox(
                      decoration: BoxDecoration(
                          color: tint, borderRadius: BorderRadius.circular(32)),
                      child: CustomPaint(
                        painter: _ArcTicks(
                            color: colors.surface.withValues(alpha: .75)),
                      ),
                    ),
                  ),
                  Positioned(
                    left: page.popOut > 0 ? 0 : w * .04,
                    right: page.popOut > 0 ? 0 : w * .04,
                    top: page.popOut > 0 ? h - figureHeight : h * .06,
                    bottom: 0,
                    child: Image.asset(
                      page.photo,
                      fit: BoxFit.contain,
                      alignment: Alignment.bottomCenter,
                      errorBuilder: (_, __, ___) => Icon(
                          Icons.fitness_center_rounded,
                          size: 96,
                          color: iconColor),
                    ),
                  ),
                  Positioned(
                      left: w * .05,
                      top: cardTop + h * .2,
                      child: bubble(page.bubbles[0], 64)),
                  // Off the face when the figure rises out of the card.
                  Positioned(
                      left: page.popOut > 0 ? w - 52 - w * .05 : w * .52,
                      top: cardTop + (page.popOut > 0 ? 16 : h * .04),
                      child: bubble(page.bubbles[1], 52)),
                  Positioned(
                      right: w * .04,
                      top: cardTop + h * .3,
                      child: bubble(page.bubbles[2], 72)),
                  Positioned(
                    left: 16,
                    bottom: 16,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 14, vertical: 10),
                      decoration: BoxDecoration(
                        color: colors.surface,
                        borderRadius: BorderRadius.circular(99),
                      ),
                      child: Row(mainAxisSize: MainAxisSize.min, children: [
                        Icon(page.chipIcon, size: 18, color: iconColor),
                        const SizedBox(width: 6),
                        Text(page.chip,
                            style: const TextStyle(
                                fontSize: 13, fontWeight: FontWeight.w600)),
                      ]),
                    ),
                  ),
                ]),
              );
            }),
          ),
          const SizedBox(height: 28),
          Text(page.title,
              textAlign: TextAlign.center,
              style: TextStyle(
                  fontSize: 27,
                  height: 1.15,
                  fontWeight: FontWeight.w600,
                  letterSpacing: -.4,
                  color: colors.onSurface)),
          const SizedBox(height: 12),
          Text(page.subtitle,
              textAlign: TextAlign.center,
              style: TextStyle(
                  fontSize: 15, height: 1.4, color: colors.onSurfaceVariant)),
        ]),
      );
    });
  }
}

/// The dashed half-ring behind the hero, as in the reference composition.
class _ArcTicks extends CustomPainter {
  final Color color;
  const _ArcTicks({required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height * .5);
    final outer = size.width * .44, inner = outer - 18;
    final paint = Paint()
      ..color = color
      ..strokeWidth = 3
      ..strokeCap = StrokeCap.round;
    const ticks = 34;
    for (var i = 0; i <= ticks; i++) {
      final angle = math.pi + math.pi * i / ticks;
      final direction = Offset(math.cos(angle), math.sin(angle));
      canvas.drawLine(
          center + direction * inner, center + direction * outer, paint);
    }
  }

  @override
  bool shouldRepaint(_ArcTicks old) => old.color != color;
}
