import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

/// Shared geometry. Sizes are logical pixels and text remains system-scalable.
abstract final class AppSpace {
  static const double xs = 4, sm = 8, md = 12, lg = 16, xl = 24, xxl = 32;
  static const double cardRadius = 24, sheetRadius = 28, inputRadius = 12;
}

abstract final class AppColors {
  // Sampled from the supplied activity/journal references. Keep the saturated
  // accessible link color separate from decorative lavender fills.
  static const lavender = Color(0xFFA893F0);
  static const paleLavender = Color(0xFFE6DFFB);
  static const lime = Color(0xFFD4F120);
  static const coral = Color(0xFFFF555D);
  static const referencePanel = Color(0xFFF7F6F9);
  static const referenceLavenderPanel = Color(0xFFF8F5FE);
  static const referenceMuted = Color(0xFF7C8196);
  static const ink = Color(0xFF1D1C21);
  static const error = Color(0xFFB3263D), errorSoft = Color(0xFFFFE9EC);
}

/// Extra semantic roles not represented by Material's ColorScheme.
@immutable
class AppDesign extends ThemeExtension<AppDesign> {
  final Color success, successContainer, onSuccessContainer;
  final Color record, recordContainer, onRecordContainer;
  final Color warning, warningContainer;
  final List<Color> chartColors;
  final LinearGradient heroGradient;

  const AppDesign({
    required this.success,
    required this.successContainer,
    required this.onSuccessContainer,
    required this.record,
    required this.recordContainer,
    required this.onRecordContainer,
    required this.warning,
    required this.warningContainer,
    required this.chartColors,
    required this.heroGradient,
  });

  static AppDesign of(BuildContext context) =>
      Theme.of(context).extension<AppDesign>() ??
      (Theme.of(context).brightness == Brightness.dark ? dark : light);

  static const light = AppDesign(
    success: Color(0xFF21754A),
    successContainer: Color(0xFFE3F3E9),
    onSuccessContainer: Color(0xFF185634),
    record: Color(0xFF825710),
    recordContainer: Color(0xFFFFF2D9),
    onRecordContainer: Color(0xFF68430A),
    warning: Color(0xFF8B5900),
    warningContainer: Color(0xFFFFF1D6),
    chartColors: [
      AppColors.lavender,
      Color(0xFF5273AD),
      Color(0xFFA54E72),
      Color(0xFF4E7B58),
      Color(0xFF9B672D),
      Color(0xFF726080)
    ],
    heroGradient: LinearGradient(
      begin: Alignment.topLeft,
      end: Alignment.bottomRight,
      colors: [Color(0xFFDED0FC), Color(0xFFF1EBFC), Color(0xFFFFFFFF)],
    ),
  );
  static const dark = AppDesign(
    success: Color(0xFF82D4A3),
    successContainer: Color(0xFF203C2D),
    onSuccessContainer: Color(0xFFAEEDC8),
    record: Color(0xFFE9C176),
    recordContainer: Color(0xFF43351E),
    onRecordContainer: Color(0xFFF4D99F),
    warning: Color(0xFFF0C27B),
    warningContainer: Color(0xFF40311D),
    chartColors: [
      AppColors.lavender,
      Color(0xFF91AFE8),
      Color(0xFFE8A0BE),
      Color(0xFF9BC9A6),
      Color(0xFFE5B67E),
      Color(0xFFBCA9CD)
    ],
    heroGradient: LinearGradient(
      begin: Alignment.topLeft,
      end: Alignment.bottomRight,
      colors: [Color(0xFF493760), Color(0xFF30263F), Color(0xFF211E29)],
    ),
  );

  @override
  AppDesign copyWith(
          {Color? success,
          Color? successContainer,
          Color? onSuccessContainer,
          Color? record,
          Color? recordContainer,
          Color? onRecordContainer,
          Color? warning,
          Color? warningContainer,
          List<Color>? chartColors,
          LinearGradient? heroGradient}) =>
      AppDesign(
        success: success ?? this.success,
        successContainer: successContainer ?? this.successContainer,
        onSuccessContainer: onSuccessContainer ?? this.onSuccessContainer,
        record: record ?? this.record,
        recordContainer: recordContainer ?? this.recordContainer,
        onRecordContainer: onRecordContainer ?? this.onRecordContainer,
        warning: warning ?? this.warning,
        warningContainer: warningContainer ?? this.warningContainer,
        chartColors: chartColors ?? this.chartColors,
        heroGradient: heroGradient ?? this.heroGradient,
      );

  @override
  AppDesign lerp(covariant AppDesign? other, double t) {
    if (other == null) return this;
    return AppDesign(
      success: Color.lerp(success, other.success, t)!,
      successContainer:
          Color.lerp(successContainer, other.successContainer, t)!,
      onSuccessContainer:
          Color.lerp(onSuccessContainer, other.onSuccessContainer, t)!,
      record: Color.lerp(record, other.record, t)!,
      recordContainer: Color.lerp(recordContainer, other.recordContainer, t)!,
      onRecordContainer:
          Color.lerp(onRecordContainer, other.onRecordContainer, t)!,
      warning: Color.lerp(warning, other.warning, t)!,
      warningContainer:
          Color.lerp(warningContainer, other.warningContainer, t)!,
      chartColors: List.generate(chartColors.length,
          (i) => Color.lerp(chartColors[i], other.chartColors[i], t)!),
      heroGradient: LinearGradient.lerp(heroGradient, other.heroGradient, t)!,
    );
  }
}

const _type = TextTheme(
  displayLarge:
      TextStyle(fontSize: 27, height: 1.2, fontWeight: FontWeight.w600),
  displayMedium:
      TextStyle(fontSize: 27, height: 1.2, fontWeight: FontWeight.w600),
  displaySmall:
      TextStyle(fontSize: 24, height: 1.2, fontWeight: FontWeight.w600),
  headlineLarge:
      TextStyle(fontSize: 27, height: 1.2, fontWeight: FontWeight.w500),
  headlineMedium:
      TextStyle(fontSize: 24, height: 1.2, fontWeight: FontWeight.w500),
  headlineSmall:
      TextStyle(fontSize: 22, height: 1.2, fontWeight: FontWeight.w500),
  titleLarge: TextStyle(fontSize: 17, height: 1.3, fontWeight: FontWeight.w500),
  titleMedium:
      TextStyle(fontSize: 15, height: 1.35, fontWeight: FontWeight.w500),
  titleSmall:
      TextStyle(fontSize: 13, height: 1.35, fontWeight: FontWeight.w500),
  bodyLarge: TextStyle(fontSize: 15, height: 1.45, fontWeight: FontWeight.w400),
  bodyMedium:
      TextStyle(fontSize: 15, height: 1.45, fontWeight: FontWeight.w400),
  bodySmall: TextStyle(fontSize: 13, height: 1.4, fontWeight: FontWeight.w400),
  labelLarge: TextStyle(fontSize: 15, height: 1.3, fontWeight: FontWeight.w600),
  labelMedium:
      TextStyle(fontSize: 13, height: 1.3, fontWeight: FontWeight.w500),
  labelSmall: TextStyle(fontSize: 13, height: 1.3, fontWeight: FontWeight.w500),
);

final ThemeData lightTheme = _buildTheme(false);
final ThemeData darkTheme = _buildTheme(true);

ThemeData _buildTheme(bool dark) {
  final design = dark ? AppDesign.dark : AppDesign.light;
  final surface = dark ? const Color(0xFF211E29) : Colors.white;
  final background = dark ? const Color(0xFF141218) : const Color(0xFFFDFCFD);
  final text = dark ? const Color(0xFFF5F3FA) : AppColors.ink;
  final muted = dark ? const Color(0xFFB5AEC2) : const Color(0xFF696473);
  final border = dark ? const Color(0xFF40394D) : const Color(0xFFE6E1ED);
  final scheme = ColorScheme.fromSeed(
    seedColor: AppColors.lavender,
    brightness: dark ? Brightness.dark : Brightness.light,
  ).copyWith(
    primary: dark ? const Color(0xFFC9B5FF) : const Color(0xFF6741B2),
    onPrimary: dark ? const Color(0xFF25183E) : Colors.white,
    primaryContainer: dark ? const Color(0xFF382D50) : AppColors.paleLavender,
    onPrimaryContainer:
        dark ? const Color(0xFFE9DFFF) : const Color(0xFF3D2468),
    secondary: AppColors.lavender,
    onSecondary: AppColors.ink,
    secondaryContainer: dark ? const Color(0xFF382D50) : AppColors.paleLavender,
    onSecondaryContainer:
        dark ? const Color(0xFFE9DFFF) : const Color(0xFF3D2468),
    surface: surface,
    onSurface: text,
    onSurfaceVariant: muted,
    surfaceContainerLowest: background,
    surfaceContainerLow: background,
    surfaceContainer: dark ? const Color(0xFF292431) : AppColors.referencePanel,
    surfaceContainerHigh:
        dark ? const Color(0xFF332D3D) : const Color(0xFFECE7F2),
    surfaceContainerHighest:
        dark ? const Color(0xFF3B3346) : const Color(0xFFE6E0ED),
    outline: dark ? const Color(0xFF93879F) : const Color(0xFF82768E),
    outlineVariant: border,
    error: dark ? const Color(0xFFFFA9B5) : AppColors.error,
    onError: dark ? const Color(0xFF591323) : Colors.white,
    errorContainer: dark ? const Color(0xFF4E2530) : AppColors.errorSoft,
    onErrorContainer: dark ? const Color(0xFFFFD9DF) : const Color(0xFF8B1930),
    surfaceTint: Colors.transparent,
  );
  final type = _type.apply(
      fontFamily: 'General Sans', bodyColor: text, displayColor: text);
  final action = dark ? AppColors.lavender : AppColors.ink;
  final onAction = dark ? AppColors.ink : Colors.white;
  final buttonStyle = FilledButton.styleFrom(
    backgroundColor: action,
    foregroundColor: onAction,
    disabledBackgroundColor: scheme.surfaceContainerHighest,
    disabledForegroundColor: muted,
    minimumSize: const Size(44, 48),
    padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
    shape: const StadiumBorder(),
    textStyle: type.labelLarge,
  );
  OutlineInputBorder inputBorder(Color color, [double width = 1]) =>
      OutlineInputBorder(
        borderRadius: BorderRadius.circular(AppSpace.inputRadius),
        borderSide: BorderSide(color: color, width: width),
      );
  return ThemeData(
    useMaterial3: true,
    brightness: scheme.brightness,
    fontFamily: 'General Sans',
    colorScheme: scheme,
    textTheme: type,
    extensions: [design],
    scaffoldBackgroundColor: background,
    primaryColor: scheme.primary,
    hintColor: muted,
    disabledColor: muted,
    dividerColor: border,
    visualDensity: VisualDensity.standard,
    materialTapTargetSize: MaterialTapTargetSize.padded,
    iconTheme: IconThemeData(color: muted, size: 22),
    appBarTheme: AppBarTheme(
      backgroundColor: background,
      foregroundColor: text,
      surfaceTintColor: Colors.transparent,
      elevation: 0,
      scrolledUnderElevation: 0,
      centerTitle: true,
      titleTextStyle: type.titleLarge,
      systemOverlayStyle:
          dark ? SystemUiOverlayStyle.light : SystemUiOverlayStyle.dark,
    ),
    cardTheme: CardThemeData(
      color: surface,
      surfaceTintColor: Colors.transparent,
      elevation: dark ? 0 : 1,
      shadowColor: Colors.black.withValues(alpha: .08),
      margin: EdgeInsets.zero,
      shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppSpace.cardRadius)),
    ),
    elevatedButtonTheme: ElevatedButtonThemeData(
        style:
            buttonStyle.copyWith(elevation: const WidgetStatePropertyAll(0))),
    filledButtonTheme: FilledButtonThemeData(style: buttonStyle),
    textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
      foregroundColor: scheme.primary,
      textStyle: type.labelLarge,
      minimumSize: const Size(44, 44),
      shape: const StadiumBorder(),
    )),
    outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
      foregroundColor: text,
      backgroundColor: surface,
      textStyle: type.labelLarge,
      minimumSize: const Size(44, 48),
      side: BorderSide(color: border),
      shape: const StadiumBorder(),
    )),
    iconButtonTheme: IconButtonThemeData(
        style: IconButton.styleFrom(
      foregroundColor: text,
      minimumSize: const Size(44, 44),
    )),
    floatingActionButtonTheme: const FloatingActionButtonThemeData(
      backgroundColor: AppColors.lavender,
      foregroundColor: AppColors.ink,
      elevation: 2,
      shape: CircleBorder(),
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: background,
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      border: inputBorder(border),
      enabledBorder: inputBorder(border),
      focusedBorder: inputBorder(scheme.primary, 1.5),
      errorBorder: inputBorder(scheme.error),
      focusedErrorBorder: inputBorder(scheme.error, 1.5),
      hintStyle: type.bodyMedium?.copyWith(color: muted),
      labelStyle: type.bodyMedium?.copyWith(color: muted),
      floatingLabelStyle: type.bodySmall?.copyWith(color: scheme.primary),
      prefixIconColor: muted,
      suffixIconColor: muted,
    ),
    chipTheme: ChipThemeData(
      backgroundColor: surface,
      selectedColor: scheme.primaryContainer,
      secondarySelectedColor: scheme.primaryContainer,
      labelStyle: type.labelMedium?.copyWith(color: text),
      secondaryLabelStyle:
          type.labelMedium?.copyWith(color: scheme.onPrimaryContainer),
      side: BorderSide(color: border),
      shape: const StadiumBorder(),
      checkmarkColor: scheme.onPrimaryContainer,
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
    ),
    segmentedButtonTheme: SegmentedButtonThemeData(
        style: ButtonStyle(
      textStyle: WidgetStatePropertyAll(type.labelMedium),
      shape: const WidgetStatePropertyAll(StadiumBorder()),
      side: WidgetStatePropertyAll(BorderSide(color: border)),
      backgroundColor: WidgetStateProperty.resolveWith((states) =>
          states.contains(WidgetState.selected)
              ? scheme.primaryContainer
              : surface),
      foregroundColor: WidgetStateProperty.resolveWith((states) =>
          states.contains(WidgetState.selected)
              ? scheme.onPrimaryContainer
              : text),
    )),
    switchTheme: SwitchThemeData(
      thumbColor: WidgetStateProperty.resolveWith((states) =>
          states.contains(WidgetState.selected) ? Colors.white : muted),
      trackColor: WidgetStateProperty.resolveWith((states) =>
          states.contains(WidgetState.selected)
              ? AppColors.lavender
              : scheme.surfaceContainerHighest),
    ),
    checkboxTheme: CheckboxThemeData(
      fillColor: WidgetStateProperty.resolveWith((states) =>
          states.contains(WidgetState.selected)
              ? AppColors.lavender
              : Colors.transparent),
      checkColor: const WidgetStatePropertyAll(AppColors.ink),
      side: BorderSide(color: scheme.outline, width: 1.5),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(5)),
    ),
    dividerTheme: DividerThemeData(color: border, thickness: 1),
    listTileTheme: ListTileThemeData(
      iconColor: muted,
      textColor: text,
      titleTextStyle: type.bodyLarge,
      subtitleTextStyle: type.bodySmall?.copyWith(color: muted),
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
    ),
    bottomSheetTheme: BottomSheetThemeData(
      backgroundColor: background,
      modalBackgroundColor: background,
      surfaceTintColor: Colors.transparent,
      showDragHandle: true,
      dragHandleColor: border,
      clipBehavior: Clip.antiAlias,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(
              top: Radius.circular(AppSpace.sheetRadius))),
    ),
    dialogTheme: DialogThemeData(
      backgroundColor: surface,
      surfaceTintColor: Colors.transparent,
      shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppSpace.sheetRadius)),
      titleTextStyle: type.headlineSmall,
      contentTextStyle: type.bodyMedium,
    ),
    datePickerTheme: DatePickerThemeData(
      backgroundColor: surface,
      surfaceTintColor: Colors.transparent,
      headerBackgroundColor: scheme.surfaceContainer,
      headerForegroundColor: text,
      shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppSpace.sheetRadius)),
      dayForegroundColor: WidgetStateProperty.resolveWith(
          (states) => states.contains(WidgetState.disabled)
              ? muted.withValues(alpha: .45)
              : states.contains(WidgetState.selected)
                  ? AppColors.ink
                  : text),
      dayBackgroundColor: WidgetStateProperty.resolveWith((states) =>
          states.contains(WidgetState.selected)
              ? AppColors.lavender
              : Colors.transparent),
      todayForegroundColor: WidgetStateProperty.resolveWith((states) =>
          states.contains(WidgetState.selected) ? AppColors.ink : text),
      todayBackgroundColor: WidgetStateProperty.resolveWith((states) =>
          states.contains(WidgetState.selected)
              ? AppColors.lavender
              : Colors.transparent),
      todayBorder: const BorderSide(color: AppColors.lavender),
      yearForegroundColor: WidgetStateProperty.resolveWith(
          (states) => states.contains(WidgetState.disabled)
              ? muted.withValues(alpha: .45)
              : states.contains(WidgetState.selected)
                  ? AppColors.ink
                  : text),
      yearBackgroundColor: WidgetStateProperty.resolveWith((states) =>
          states.contains(WidgetState.selected)
              ? AppColors.lavender
              : Colors.transparent),
    ),
    popupMenuTheme: PopupMenuThemeData(
      color: surface,
      surfaceTintColor: Colors.transparent,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
    ),
    snackBarTheme: SnackBarThemeData(
      backgroundColor: scheme.inverseSurface,
      contentTextStyle:
          type.bodyMedium?.copyWith(color: scheme.onInverseSurface),
      behavior: SnackBarBehavior.floating,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
    ),
    navigationBarTheme: NavigationBarThemeData(
      backgroundColor: surface,
      indicatorColor: scheme.primaryContainer,
      height: 64,
      labelTextStyle: WidgetStatePropertyAll(type.labelSmall),
    ),
    tabBarTheme: TabBarThemeData(
      labelColor: scheme.primary,
      unselectedLabelColor: muted,
      indicatorColor: scheme.primary,
      labelStyle: type.titleMedium,
      unselectedLabelStyle: type.titleMedium,
      dividerColor: border,
    ),
    progressIndicatorTheme: ProgressIndicatorThemeData(
        color: AppColors.lavender, linearTrackColor: scheme.primaryContainer),
  );
}
