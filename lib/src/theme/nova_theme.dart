import 'package:flutter/material.dart';

@immutable
class NovaColors extends ThemeExtension<NovaColors> {
  const NovaColors({
    required this.background,
    required this.surface,
    required this.surfaceRaised,
    required this.surfaceMuted,
    required this.avatarBackground,
    required this.progressTrack,
    required this.chipBackground,
    required this.heroGradientStart,
    required this.heroGradientEnd,
  });

  final Color background;
  final Color surface;
  final Color surfaceRaised;
  final Color surfaceMuted;
  final Color avatarBackground;
  final Color progressTrack;
  final Color chipBackground;
  final Color heroGradientStart;
  final Color heroGradientEnd;

  static const dark = NovaColors(
    background: Color(0xFF09101A),
    surface: Color(0xFF121E2D),
    surfaceRaised: Color(0xFF132130),
    surfaceMuted: Color(0xFF0F1723),
    avatarBackground: Color(0xFF183249),
    progressTrack: Color(0xFF203243),
    chipBackground: Color(0xFF132130),
    heroGradientStart: Color(0xFF10273F),
    heroGradientEnd: Color(0xFF0D1824),
  );

  static const light = NovaColors(
    background: Color(0xFFF5F2EC),
    surface: Color(0xFFFFFCF8),
    surfaceRaised: Color(0xFFEEE8DE),
    surfaceMuted: Color(0xFFE6EBF0),
    avatarBackground: Color(0xFFD9E3EA),
    progressTrack: Color(0xFFD6DEE5),
    chipBackground: Color(0xFFE7EDF2),
    heroGradientStart: Color(0xFFF8F1E9),
    heroGradientEnd: Color(0xFFF1E8DE),
  );

  @override
  NovaColors copyWith({
    Color? background,
    Color? surface,
    Color? surfaceRaised,
    Color? surfaceMuted,
    Color? avatarBackground,
    Color? progressTrack,
    Color? chipBackground,
    Color? heroGradientStart,
    Color? heroGradientEnd,
  }) {
    return NovaColors(
      background: background ?? this.background,
      surface: surface ?? this.surface,
      surfaceRaised: surfaceRaised ?? this.surfaceRaised,
      surfaceMuted: surfaceMuted ?? this.surfaceMuted,
      avatarBackground: avatarBackground ?? this.avatarBackground,
      progressTrack: progressTrack ?? this.progressTrack,
      chipBackground: chipBackground ?? this.chipBackground,
      heroGradientStart: heroGradientStart ?? this.heroGradientStart,
      heroGradientEnd: heroGradientEnd ?? this.heroGradientEnd,
    );
  }

  @override
  NovaColors lerp(ThemeExtension<NovaColors>? other, double t) {
    if (other is! NovaColors) {
      return this;
    }

    return NovaColors(
      background: Color.lerp(background, other.background, t) ?? background,
      surface: Color.lerp(surface, other.surface, t) ?? surface,
      surfaceRaised:
          Color.lerp(surfaceRaised, other.surfaceRaised, t) ?? surfaceRaised,
      surfaceMuted:
          Color.lerp(surfaceMuted, other.surfaceMuted, t) ?? surfaceMuted,
      avatarBackground:
          Color.lerp(avatarBackground, other.avatarBackground, t) ??
          avatarBackground,
      progressTrack:
          Color.lerp(progressTrack, other.progressTrack, t) ?? progressTrack,
      chipBackground:
          Color.lerp(chipBackground, other.chipBackground, t) ?? chipBackground,
      heroGradientStart:
          Color.lerp(heroGradientStart, other.heroGradientStart, t) ??
          heroGradientStart,
      heroGradientEnd:
          Color.lerp(heroGradientEnd, other.heroGradientEnd, t) ??
          heroGradientEnd,
    );
  }
}

ThemeData buildNovaTheme(Brightness brightness) {
  final isDark = brightness == Brightness.dark;
  final palette = isDark ? NovaColors.dark : NovaColors.light;
  final seed = isDark ? const Color(0xFF12B4FF) : const Color(0xFF648BA6);
  final actionColor = isDark ? const Color(0xFF12B4FF) : seed;
  final actionOnColor = isDark ? const Color(0xFF04131D) : null;
  final baseScheme = ColorScheme.fromSeed(
    seedColor: seed,
    brightness: brightness,
  );
  final colorScheme = baseScheme.copyWith(
    primary: actionColor,
    secondary: actionColor,
    onPrimary: actionOnColor ?? baseScheme.onPrimary,
    surface: palette.surface,
    surfaceContainerHighest: palette.surfaceRaised,
  );

  return ThemeData(
    useMaterial3: true,
    brightness: brightness,
    colorScheme: colorScheme,
    scaffoldBackgroundColor: palette.background,
    cardColor: palette.surface,
    extensions: <ThemeExtension<dynamic>>[palette],
    appBarTheme: AppBarTheme(
      backgroundColor: Colors.transparent,
      surfaceTintColor: Colors.transparent,
      foregroundColor: colorScheme.onSurface,
      scrolledUnderElevation: 0,
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: palette.surfaceRaised,
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(18),
        borderSide: BorderSide.none,
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(18),
        borderSide: BorderSide.none,
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(18),
        borderSide: BorderSide(
          color: colorScheme.primary.withValues(alpha: 0.28),
        ),
      ),
    ),
    navigationBarTheme: NavigationBarThemeData(
      backgroundColor: palette.surface,
      indicatorColor: colorScheme.primary.withValues(alpha: 0.14),
      surfaceTintColor: Colors.transparent,
    ),
    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(
        backgroundColor: isDark ? actionColor : null,
        foregroundColor: isDark ? actionOnColor : null,
      ),
    ),
    floatingActionButtonTheme: FloatingActionButtonThemeData(
      backgroundColor: isDark ? actionColor : null,
      foregroundColor: isDark ? actionOnColor : null,
    ),
    snackBarTheme: const SnackBarThemeData(behavior: SnackBarBehavior.floating),
    dividerColor: colorScheme.outlineVariant.withValues(alpha: 0.55),
  );
}

extension NovaThemeContext on BuildContext {
  NovaColors get novaColors => Theme.of(this).extension<NovaColors>()!;
}
