import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class AppColors {
  // Brand
  static const brandNavy = Color(0xFF0B1530);
  static const brandNavyDeep = Color(0xFF050A1A);
  static const brandCoral = Color(0xFFFF6E5F);
  static const brandCoralSoft = Color(0xFFFF917A);

  // Neutrals
  static const neutral0 = Color(0xFFFFFFFF);
  static const neutral50 = Color(0xFFF7F8FA);
  static const neutral100 = Color(0xFFEDF0F5);
  static const neutral200 = Color(0xFFDADFE8);
  static const neutral400 = Color(0xFF9AA3B5);
  static const neutral500 = Color(0xFF7B8494);
  static const neutral600 = Color(0xFF5C6475);
  static const neutral800 = Color(0xFF252B36);
  static const neutral900 = Color(0xFF101320);

  // Semantic
  static const success = Color(0xFF1F9E63);
  static const successSoft = Color(0xFFE4F7EE);
  static const warning = Color(0xFFFFB648);
  static const warningSoft = Color(0xFFFFF4DE);
  static const error = Color(0xFFFF4C5A);
  static const errorSoft = Color(0xFFFFE7EA);
  static const info = Color(0xFF3B82F6);
  static const infoSoft = Color(0xFFE0EDFF);
}

class AppGradients {
  /// Primary coral gradient – for main CTAs
  static const primary = LinearGradient(
    colors: [
      AppColors.brandCoral,
      AppColors.brandCoralSoft,
    ],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  /// Navy aurora – for app bars / headers
  static const navyAurora = LinearGradient(
    colors: [
      AppColors.brandNavy,
      Color(0xFF1F2D52),
      AppColors.brandNavy,
    ],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  /// Midnight – subtle dark background
  static const midnight = LinearGradient(
    colors: [
      AppColors.brandNavyDeep,
      AppColors.brandNavy,
    ],
    begin: Alignment.topCenter,
    end: Alignment.bottomCenter,
  );

  /// Coral ↔ Navy hero fusion
  static const fusion = LinearGradient(
    colors: [
      AppColors.brandCoral,
      Color(0xFFEC5A6A),
      AppColors.brandNavy,
    ],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );
}

const double _compactRadius = 12;
const double _compactButtonPaddingV = 12;
const double _compactButtonPaddingH = 16;
const double _compactFontScale = 0.92;

TextStyle? _scaleStyle(TextStyle? style) {
  if (style?.fontSize == null) return style;
  return style!.copyWith(fontSize: style.fontSize! * _compactFontScale);
}

TextTheme _scaledTextTheme(TextTheme base) {
  return base.copyWith(
    displayLarge: _scaleStyle(base.displayLarge),
    displayMedium: _scaleStyle(base.displayMedium),
    displaySmall: _scaleStyle(base.displaySmall),
    headlineLarge: _scaleStyle(base.headlineLarge),
    headlineMedium: _scaleStyle(base.headlineMedium),
    headlineSmall: _scaleStyle(base.headlineSmall),
    titleLarge: _scaleStyle(base.titleLarge),
    titleMedium: _scaleStyle(base.titleMedium),
    titleSmall: _scaleStyle(base.titleSmall),
    labelLarge: _scaleStyle(base.labelLarge),
    labelMedium: _scaleStyle(base.labelMedium),
    labelSmall: _scaleStyle(base.labelSmall),
    bodyLarge: _scaleStyle(base.bodyLarge),
    bodyMedium: _scaleStyle(base.bodyMedium),
    bodySmall: _scaleStyle(base.bodySmall),
  );
}

final ThemeData lightTheme = ThemeData(
  useMaterial3: true,
  brightness: Brightness.light,
  visualDensity: VisualDensity.compact,
  primaryColor: AppColors.brandCoral,
  scaffoldBackgroundColor: AppColors.neutral50,
  colorScheme: const ColorScheme(
    brightness: Brightness.light,
    primary: AppColors.brandCoral,
    onPrimary: Colors.white,
    secondary: AppColors.brandNavy,
    onSecondary: Colors.white,
    error: AppColors.error,
    onError: Colors.white,
    surface: AppColors.neutral0,
    onSurface: AppColors.neutral900,
  ),
  textTheme: GoogleFonts.interTextTheme(
    _scaledTextTheme(ThemeData.light().textTheme),
  ).apply(
    bodyColor: AppColors.neutral900,
    displayColor: AppColors.neutral900,
  ),
  appBarTheme: const AppBarTheme(
    backgroundColor: Colors.transparent,
    foregroundColor: AppColors.neutral0,
    elevation: 0,
    centerTitle: true,
  ),
  cardTheme: CardThemeData(
    color: AppColors.neutral0,
    elevation: 4,
    shadowColor: AppColors.brandNavy.withValues(alpha: 0.08),
    shape: RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(_compactRadius),
    ),
  ),
  elevatedButtonTheme: ElevatedButtonThemeData(
    style: ElevatedButton.styleFrom(
      backgroundColor: AppColors.brandCoral,
      foregroundColor: Colors.white,
      elevation: 0,
      padding: const EdgeInsets.symmetric(
        vertical: _compactButtonPaddingV,
        horizontal: _compactButtonPaddingH,
      ),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(_compactRadius),
      ),
      textStyle: const TextStyle(
        fontSize: 14,
        fontWeight: FontWeight.w600,
      ),
    ),
  ),
  textButtonTheme: TextButtonThemeData(
    style: TextButton.styleFrom(
      foregroundColor: AppColors.brandCoral,
      textStyle: const TextStyle(
        fontSize: 14,
        fontWeight: FontWeight.w500,
      ),
    ),
  ),
  inputDecorationTheme: InputDecorationTheme(
    filled: true,
    fillColor: AppColors.neutral100,
    contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
    border: OutlineInputBorder(
      borderRadius: BorderRadius.circular(_compactRadius),
      borderSide: const BorderSide(color: AppColors.neutral200),
    ),
    enabledBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(_compactRadius),
      borderSide: const BorderSide(color: AppColors.neutral200),
    ),
    focusedBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(_compactRadius),
      borderSide: const BorderSide(color: AppColors.brandCoral, width: 1.1),
    ),
    hintStyle: const TextStyle(
      color: AppColors.neutral400,
      fontSize: 13,
    ),
  ),
  navigationBarTheme: NavigationBarThemeData(
    height: 62,
    indicatorColor: AppColors.brandCoral.withValues(alpha: 0.18),
    iconTheme: const WidgetStatePropertyAll(
      IconThemeData(size: 22),
    ),
    labelTextStyle: const WidgetStatePropertyAll(
      TextStyle(
        fontSize: 11,
        fontWeight: FontWeight.w600,
      ),
    ),
  ),
  bottomNavigationBarTheme: const BottomNavigationBarThemeData(
    backgroundColor: AppColors.neutral0,
    selectedItemColor: AppColors.brandCoral,
    unselectedItemColor: AppColors.neutral400,
    type: BottomNavigationBarType.fixed,
    showUnselectedLabels: true,
  ),
);

final ThemeData darkTheme = ThemeData(
  useMaterial3: true,
  brightness: Brightness.dark,
  visualDensity: VisualDensity.compact,
  primaryColor: AppColors.brandCoral,
  scaffoldBackgroundColor: AppColors.brandNavyDeep,
  colorScheme: const ColorScheme(
    brightness: Brightness.dark,
    primary: AppColors.brandCoral,
    onPrimary: AppColors.brandNavy,
    secondary: AppColors.neutral100,
    onSecondary: AppColors.brandNavyDeep,
    error: AppColors.error,
    onError: Colors.white,
    surface: AppColors.brandNavy,
    onSurface: AppColors.neutral50,
  ),
  textTheme: GoogleFonts.interTextTheme(
    _scaledTextTheme(ThemeData.dark().textTheme),
  ).apply(
    bodyColor: AppColors.neutral50,
    displayColor: AppColors.neutral50,
  ),
  appBarTheme: const AppBarTheme(
    backgroundColor: Colors.transparent,
    foregroundColor: AppColors.neutral50,
    elevation: 0,
    centerTitle: true,
  ),
  cardTheme: CardThemeData(
    color: AppColors.brandNavy,
    elevation: 3,
    shadowColor: Colors.black.withValues(alpha: 0.4),
    shape: RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(_compactRadius),
      side: const BorderSide(color: Color(0xFF252B36)),
    ),
  ),
  elevatedButtonTheme: ElevatedButtonThemeData(
    style: ElevatedButton.styleFrom(
      backgroundColor: AppColors.brandCoral,
      foregroundColor: AppColors.brandNavy,
      elevation: 0,
      padding: const EdgeInsets.symmetric(
        vertical: _compactButtonPaddingV,
        horizontal: _compactButtonPaddingH,
      ),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(_compactRadius),
      ),
      textStyle: const TextStyle(
        fontSize: 14,
        fontWeight: FontWeight.w600,
      ),
    ),
  ),
  textButtonTheme: TextButtonThemeData(
    style: TextButton.styleFrom(
      foregroundColor: AppColors.brandCoralSoft,
      textStyle: const TextStyle(
        fontSize: 14,
        fontWeight: FontWeight.w500,
      ),
    ),
  ),
  inputDecorationTheme: InputDecorationTheme(
    filled: true,
    fillColor: const Color(0xFF111A35),
    contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
    border: OutlineInputBorder(
      borderRadius: BorderRadius.circular(_compactRadius),
      borderSide: const BorderSide(color: Color(0xFF252B36)),
    ),
    enabledBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(_compactRadius),
      borderSide: const BorderSide(color: Color(0xFF252B36)),
    ),
    focusedBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(_compactRadius),
      borderSide: const BorderSide(color: AppColors.brandCoralSoft, width: 1.1),
    ),
    hintStyle: const TextStyle(
      color: AppColors.neutral400,
      fontSize: 13,
    ),
  ),
  navigationBarTheme: NavigationBarThemeData(
    height: 62,
    indicatorColor: AppColors.brandCoral.withValues(alpha: 0.2),
    iconTheme: const WidgetStatePropertyAll(
      IconThemeData(size: 22),
    ),
    labelTextStyle: const WidgetStatePropertyAll(
      TextStyle(
        fontSize: 11,
        fontWeight: FontWeight.w600,
      ),
    ),
  ),
  bottomNavigationBarTheme: const BottomNavigationBarThemeData(
    backgroundColor: AppColors.brandNavyDeep,
    selectedItemColor: AppColors.brandCoral,
    unselectedItemColor: AppColors.neutral400,
    type: BottomNavigationBarType.fixed,
    showUnselectedLabels: true,
  ),
);

class PrimaryGradientButton extends StatelessWidget {
  final String label;
  final VoidCallback? onPressed;

  const PrimaryGradientButton({
    super.key,
    required this.label,
    this.onPressed,
  });

  @override
  Widget build(BuildContext context) {
    final bool isDisabled = onPressed == null;

    return Opacity(
      opacity: isDisabled ? 0.5 : 1,
      child: InkWell(
        borderRadius: BorderRadius.circular(18),
        onTap: onPressed,
        child: Ink(
          decoration: BoxDecoration(
            gradient: AppGradients.primary,
            borderRadius: BorderRadius.circular(18),
            boxShadow: [
              BoxShadow(
                color: AppColors.brandCoral.withValues(alpha: 0.35),
                blurRadius: 18,
                offset: const Offset(0, 8),
              ),
            ],
          ),
          padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 14),
          child: Text(
            label,
            style: Theme.of(context).textTheme.labelLarge?.copyWith(
                  color: Colors.white,
                  fontWeight: FontWeight.w600,
                ),
          ),
        ),
      ),
    );
  }
}
