import 'package:flutter/material.dart';

/// Fixed brand colours (Outly redesign v2). These do not change with the
/// theme: the hero card, trip header and share image are always blue.
const brand = Color(0xFF1F5BFF);
const brandDark = Color(0xFF1646CC);
const coral = Color(0xFFFF5C39);
const accentOrange = coral;
const sun = Color(0xFFFFD23F);
const inkColor = Color(0xFF0E1220);

/// Avatar fills, picked by position so neighbours differ.
const avatarColors = [
  Color(0xFFFFD23F),
  Color(0xFFFFB4A2),
  Color(0xFFBFE9DD),
  Color(0xFFD9D2FF),
];

const _radius = 24.0;

/// Theme-aware colours, read from the active [ColorScheme] so every widget
/// follows light and dark mode automatically.
extension ThemeColors on BuildContext {
  ThemeData get _theme => Theme.of(this);
  ColorScheme get _scheme => _theme.colorScheme;
  bool get isDark => _theme.brightness == Brightness.dark;

  /// Main blue (lighter in dark mode so it stays readable).
  Color get brandColor => _scheme.primary;

  /// Text/icons placed on top of [brandColor].
  Color get onBrand => _scheme.onPrimary;

  /// Soft blue tint for selected chips, badges and callouts.
  Color get soft => _scheme.primaryContainer;

  /// Text/icons placed on top of [soft].
  Color get onSoft => _scheme.onPrimaryContainer;

  /// Hairline borders and dividers.
  Color get border => _scheme.outlineVariant;

  /// Secondary text.
  Color get muted => _scheme.onSurfaceVariant;

  /// Card / pill surface.
  Color get surfaceColor => _scheme.surface;

  /// Strongest text colour. Also the fill of a selected filter pill.
  Color get ink => _scheme.onSurface;

  /// Text on top of [ink].
  Color get onInk => isDark ? const Color(0xFF0B0E1A) : Colors.white;

  /// "Local business" mint badge and banner.
  Color get mint => isDark ? const Color(0xFF12372F) : const Color(0xFFDDF5EC);
  Color get onMint =>
      isDark ? const Color(0xFF7EE0C0) : const Color(0xFF0B5E4A);

  /// Date tile for upcoming plans.
  Color get peach => isDark ? const Color(0xFF3A1D16) : const Color(0xFFFFE3DB);
  Color get onPeach =>
      isDark ? const Color(0xFFFF9B82) : const Color(0xFFA8321A);

  /// The floating dark bars (bottom navigation and "Total spent").
  Color get bar => isDark ? const Color(0xFF222A45) : inkColor;
  Color get onBarMuted => const Color(0xFFC9D0E0);
}

ThemeData buildTheme(Brightness brightness) {
  final dark = brightness == Brightness.dark;

  final scheme = ColorScheme.fromSeed(
    seedColor: brand,
    brightness: brightness,
  ).copyWith(
    primary: dark ? const Color(0xFF5B8CFF) : brand,
    onPrimary: dark ? const Color(0xFF0B1020) : Colors.white,
    primaryContainer: dark ? const Color(0xFF1B2A57) : const Color(0xFFE8EEFF),
    onPrimaryContainer:
        dark ? const Color(0xFFC9D8FF) : const Color(0xFF1F4BCC),
    secondary: coral,
    onSecondary: inkColor,
    surface: dark ? const Color(0xFF151A2B) : Colors.white,
    onSurface: dark ? const Color(0xFFE8ECF8) : inkColor,
    onSurfaceVariant: dark ? const Color(0xFFA3ACC2) : const Color(0xFF5B6478),
    outlineVariant: dark ? const Color(0xFF262D45) : const Color(0xFFE3E8F2),
  );

  final background = dark ? const Color(0xFF0B0E1A) : const Color(0xFFF4F6FB);

  // Standard Material text theme using system typography to avoid package conflicts.
  final textTheme = ThemeData(brightness: brightness).textTheme.apply(
        bodyColor: scheme.onSurface,
        displayColor: scheme.onSurface,
      );

  OutlineInputBorder inputBorder(Color color, [double width = 1]) =>
      OutlineInputBorder(
        borderRadius: BorderRadius.circular(16),
        borderSide: BorderSide(color: color, width: width),
      );

  return ThemeData(
    useMaterial3: true,
    brightness: brightness,
    colorScheme: scheme,
    scaffoldBackgroundColor: background,
    textTheme: textTheme,
    splashFactory: InkSparkle.splashFactory,
    appBarTheme: AppBarTheme(
      backgroundColor: background,
      foregroundColor: scheme.onSurface,
      elevation: 0,
      scrolledUnderElevation: 0,
      centerTitle: false,
      titleTextStyle: textTheme.titleLarge!.copyWith(
        color: scheme.onSurface,
        fontSize: 20,
        fontWeight: FontWeight.w800,
      ),
    ),
    cardTheme: CardThemeData(
      color: scheme.surface,
      surfaceTintColor: Colors.transparent,
      elevation: 0,
      margin: EdgeInsets.zero,
      clipBehavior: Clip.antiAlias,
      // The design uses borderless white cards on a tinted page. Dark mode
      // keeps a hairline so cards still separate from the page.
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(_radius),
        side: dark ? BorderSide(color: scheme.outlineVariant) : BorderSide.none,
      ),
    ),
    dialogTheme: DialogThemeData(
      backgroundColor: scheme.surface,
      surfaceTintColor: Colors.transparent,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(28)),
    ),
    snackBarTheme: SnackBarThemeData(
      behavior: SnackBarBehavior.floating,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: scheme.surface,
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
      border: inputBorder(scheme.outlineVariant),
      enabledBorder: inputBorder(scheme.outlineVariant),
      focusedBorder: inputBorder(scheme.primary, 1.6),
    ),
    navigationBarTheme: NavigationBarThemeData(
      backgroundColor: scheme.surface,
      surfaceTintColor: Colors.transparent,
      height: 68,
      indicatorColor: scheme.primaryContainer,
      indicatorShape: const StadiumBorder(),
      labelTextStyle: const WidgetStatePropertyAll(
        TextStyle(fontWeight: FontWeight.w700, fontSize: 12),
      ),
    ),
    chipTheme: ChipThemeData(
      backgroundColor: scheme.surface,
      selectedColor: scheme.primaryContainer,
      side: BorderSide(color: scheme.outlineVariant),
      shape: const StadiumBorder(),
      checkmarkColor: scheme.primary,
      labelStyle: TextStyle(
        color: scheme.onSurface,
        fontWeight: FontWeight.w600,
      ),
    ),
    switchTheme: SwitchThemeData(
      thumbColor: WidgetStateProperty.resolveWith(
        (states) => states.contains(WidgetState.selected)
            ? scheme.onPrimary
            : scheme.outline,
      ),
      trackColor: WidgetStateProperty.resolveWith(
        (states) => states.contains(WidgetState.selected)
            ? scheme.primary
            : scheme.surfaceContainerHighest,
      ),
    ),
    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(
        backgroundColor: scheme.primary,
        foregroundColor: scheme.onPrimary,
        shape: const StadiumBorder(),
        padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 20),
        textStyle: const TextStyle(fontWeight: FontWeight.w800),
      ),
    ),
    outlinedButtonTheme: OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(
        foregroundColor: scheme.onSurface,
        side: BorderSide(color: scheme.outlineVariant, width: 1.4),
        shape: const StadiumBorder(),
        padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 20),
        textStyle: const TextStyle(fontWeight: FontWeight.w800),
      ),
    ),
    textButtonTheme: TextButtonThemeData(
      style: TextButton.styleFrom(
        foregroundColor: scheme.primary,
        textStyle: const TextStyle(fontWeight: FontWeight.w700),
      ),
    ),
    checkboxTheme: CheckboxThemeData(
      fillColor: WidgetStateProperty.resolveWith(
        (states) =>
            states.contains(WidgetState.selected) ? scheme.primary : null,
      ),
      checkColor: WidgetStatePropertyAll(scheme.onPrimary),
    ),
    dividerTheme: DividerThemeData(color: scheme.outlineVariant, space: 1),
  );
}
