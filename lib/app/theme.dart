import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

/// Palette definita in UI_DESIGN.md (light: violetto + bianco, dark: viola + nero).
abstract final class AppColors {
  static const lightPrimary = Color(0xFF7C3AED);
  static const lightPrimaryVariant = Color(0xFFA78BFA);
  static const lightBackground = Color(0xFFFFFFFF);
  static const lightSurface = Color(0xFFF5F3FF);
  static const lightOnPrimary = Color(0xFFFFFFFF);
  static const lightOnBackground = Color(0xFF1C1B1F);
  static const lightError = Color(0xFFB00020);
  static const lightSuccess = Color(0xFF2E7D32);

  static const darkPrimary = Color(0xFFA78BFA);
  static const darkPrimaryVariant = Color(0xFF7C3AED);
  static const darkBackground = Color(0xFF0D0D0D);
  static const darkSurface = Color(0xFF1A0533);
  static const darkOnPrimary = Color(0xFF000000);
  static const darkOnBackground = Color(0xFFF1EDFF);
  static const darkError = Color(0xFFCF6679);
  static const darkSuccess = Color(0xFF81C784);
}

/// Colori semantici non coperti da [ColorScheme] (es. stati di successo).
@immutable
class AppSemanticColors extends ThemeExtension<AppSemanticColors> {
  const AppSemanticColors({required this.success});

  final Color success;

  @override
  AppSemanticColors copyWith({Color? success}) {
    return AppSemanticColors(success: success ?? this.success);
  }

  @override
  AppSemanticColors lerp(ThemeExtension<AppSemanticColors>? other, double t) {
    if (other is! AppSemanticColors) return this;
    return AppSemanticColors(success: Color.lerp(success, other.success, t)!);
  }
}

extension AppThemeContext on BuildContext {
  AppSemanticColors get appColors =>
      Theme.of(this).extension<AppSemanticColors>()!;
}

abstract final class AppTheme {
  static ThemeData get light => _build(
        brightness: Brightness.light,
        primary: AppColors.lightPrimary,
        secondary: AppColors.lightPrimaryVariant,
        background: AppColors.lightBackground,
        surface: AppColors.lightSurface,
        onPrimary: AppColors.lightOnPrimary,
        onBackground: AppColors.lightOnBackground,
        error: AppColors.lightError,
        success: AppColors.lightSuccess,
      );

  static ThemeData get dark => _build(
        brightness: Brightness.dark,
        primary: AppColors.darkPrimary,
        secondary: AppColors.darkPrimaryVariant,
        background: AppColors.darkBackground,
        surface: AppColors.darkSurface,
        onPrimary: AppColors.darkOnPrimary,
        onBackground: AppColors.darkOnBackground,
        error: AppColors.darkError,
        success: AppColors.darkSuccess,
      );

  static ThemeData _build({
    required Brightness brightness,
    required Color primary,
    required Color secondary,
    required Color background,
    required Color surface,
    required Color onPrimary,
    required Color onBackground,
    required Color error,
    required Color success,
  }) {
    final colorScheme = ColorScheme(
      brightness: brightness,
      primary: primary,
      onPrimary: onPrimary,
      secondary: secondary,
      onSecondary: onPrimary,
      error: error,
      onError: onPrimary,
      surface: surface,
      onSurface: onBackground,
    );

    final baseTextTheme =
        brightness == Brightness.dark ? ThemeData.dark().textTheme : ThemeData.light().textTheme;

    return ThemeData(
      useMaterial3: true,
      brightness: brightness,
      colorScheme: colorScheme,
      scaffoldBackgroundColor: background,
      textTheme: GoogleFonts.interTextTheme(baseTextTheme),
      appBarTheme: AppBarTheme(
        backgroundColor: background,
        foregroundColor: onBackground,
        elevation: 0,
      ),
      extensions: [
        AppSemanticColors(success: success),
      ],
    );
  }
}
