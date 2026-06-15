import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

/// Palette dell'app: viola come accento primario, teal come accento secondario,
/// superfici scure neutre (no più viola sfumato) per un look moderno.
abstract final class AppColors {
  // Light
  static const lightPrimary = Color(0xFF7C3AED);
  static const lightPrimaryVariant = Color(0xFFA78BFA);
  static const lightSecondary = Color(0xFF0D9488);
  static const lightBackground = Color(0xFFF6F5FB);
  static const lightSurface = Color(0xFFFFFFFF);
  static const lightSurfaceContainer = Color(0xFFF1EFFA);
  static const lightOutline = Color(0xFFE4E1F0);
  static const lightOnPrimary = Color(0xFFFFFFFF);
  static const lightOnBackground = Color(0xFF1C1B1F);
  static const lightOnSurfaceVariant = Color(0xFF6B6878);
  static const lightError = Color(0xFFB00020);
  static const lightSuccess = Color(0xFF2E7D32);

  // Dark
  static const darkPrimary = Color(0xFFA78BFA);
  static const darkPrimaryVariant = Color(0xFF7C3AED);
  static const darkSecondary = Color(0xFF2DD4BF);
  static const darkBackground = Color(0xFF0A0A0B);
  static const darkSurface = Color(0xFF151517);
  static const darkSurfaceContainer = Color(0xFF1E1E22);
  static const darkOutline = Color(0xFF2C2C31);
  static const darkOnPrimary = Color(0xFF150A2E);
  static const darkOnBackground = Color(0xFFF5F3FF);
  static const darkOnSurfaceVariant = Color(0xFF9D9AA8);
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
  static const _radius = 18.0;

  static ThemeData get light => _build(
        brightness: Brightness.light,
        primary: AppColors.lightPrimary,
        primaryVariant: AppColors.lightPrimaryVariant,
        secondary: AppColors.lightSecondary,
        background: AppColors.lightBackground,
        surface: AppColors.lightSurface,
        surfaceContainer: AppColors.lightSurfaceContainer,
        outline: AppColors.lightOutline,
        onPrimary: AppColors.lightOnPrimary,
        onBackground: AppColors.lightOnBackground,
        onSurfaceVariant: AppColors.lightOnSurfaceVariant,
        error: AppColors.lightError,
        success: AppColors.lightSuccess,
      );

  static ThemeData get dark => _build(
        brightness: Brightness.dark,
        primary: AppColors.darkPrimary,
        primaryVariant: AppColors.darkPrimaryVariant,
        secondary: AppColors.darkSecondary,
        background: AppColors.darkBackground,
        surface: AppColors.darkSurface,
        surfaceContainer: AppColors.darkSurfaceContainer,
        outline: AppColors.darkOutline,
        onPrimary: AppColors.darkOnPrimary,
        onBackground: AppColors.darkOnBackground,
        onSurfaceVariant: AppColors.darkOnSurfaceVariant,
        error: AppColors.darkError,
        success: AppColors.darkSuccess,
      );

  static ThemeData _build({
    required Brightness brightness,
    required Color primary,
    required Color primaryVariant,
    required Color secondary,
    required Color background,
    required Color surface,
    required Color surfaceContainer,
    required Color outline,
    required Color onPrimary,
    required Color onBackground,
    required Color onSurfaceVariant,
    required Color error,
    required Color success,
  }) {
    final colorScheme = ColorScheme(
      brightness: brightness,
      primary: primary,
      onPrimary: onPrimary,
      primaryContainer: primaryVariant,
      onPrimaryContainer: onPrimary,
      secondary: secondary,
      onSecondary: onPrimary,
      error: error,
      onError: onPrimary,
      surface: surface,
      onSurface: onBackground,
      onSurfaceVariant: onSurfaceVariant,
      surfaceContainerHighest: surfaceContainer,
      surfaceContainerHigh: surfaceContainer,
      surfaceContainer: surfaceContainer,
      outline: outline,
      outlineVariant: outline,
    );

    final baseTextTheme =
        brightness == Brightness.dark ? ThemeData.dark().textTheme : ThemeData.light().textTheme;
    // Inter per il testo, Space Grotesk per titoli e numeri (look moderno).
    final bodyTextTheme = GoogleFonts.interTextTheme(baseTextTheme);
    final displayTextTheme = GoogleFonts.spaceGroteskTextTheme(baseTextTheme);

    final textTheme = bodyTextTheme.copyWith(
      displayLarge: displayTextTheme.displayLarge?.copyWith(fontWeight: FontWeight.w700),
      displayMedium: displayTextTheme.displayMedium?.copyWith(fontWeight: FontWeight.w700),
      displaySmall: displayTextTheme.displaySmall?.copyWith(fontWeight: FontWeight.w700),
      headlineLarge: displayTextTheme.headlineLarge?.copyWith(fontWeight: FontWeight.w700),
      headlineMedium: displayTextTheme.headlineMedium?.copyWith(fontWeight: FontWeight.w700),
      headlineSmall: displayTextTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w700),
      titleLarge: displayTextTheme.titleLarge?.copyWith(fontWeight: FontWeight.w700),
      titleMedium: displayTextTheme.titleMedium?.copyWith(fontWeight: FontWeight.w600),
    );

    OutlineInputBorder borderWith(Color color, [double width = 1]) => OutlineInputBorder(
          borderRadius: BorderRadius.circular(_radius - 2),
          borderSide: BorderSide(color: color, width: width),
        );

    return ThemeData(
      useMaterial3: true,
      brightness: brightness,
      colorScheme: colorScheme,
      scaffoldBackgroundColor: background,
      textTheme: textTheme,
      appBarTheme: AppBarTheme(
        backgroundColor: background,
        foregroundColor: onBackground,
        elevation: 0,
        scrolledUnderElevation: 0,
        centerTitle: false,
        titleTextStyle: GoogleFonts.spaceGrotesk(
          fontSize: 22,
          fontWeight: FontWeight.w700,
          color: onBackground,
        ),
      ),
      cardTheme: CardThemeData(
        color: surface,
        elevation: 0,
        margin: EdgeInsets.zero,
        clipBehavior: Clip.antiAlias,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(_radius + 4),
          side: BorderSide(color: outline),
        ),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 20),
          textStyle: GoogleFonts.spaceGrotesk(fontSize: 15, fontWeight: FontWeight.w600),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(_radius - 4)),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 18),
          side: BorderSide(color: outline),
          textStyle: GoogleFonts.spaceGrotesk(fontSize: 15, fontWeight: FontWeight.w600),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(_radius - 4)),
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          textStyle: GoogleFonts.spaceGrotesk(fontSize: 14, fontWeight: FontWeight.w600),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: surfaceContainer,
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        border: borderWith(Colors.transparent),
        enabledBorder: borderWith(outline),
        focusedBorder: borderWith(primary, 1.5),
        errorBorder: borderWith(error),
        focusedErrorBorder: borderWith(error, 1.5),
      ),
      dialogTheme: DialogThemeData(
        backgroundColor: surface,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(_radius + 4),
          side: BorderSide(color: outline),
        ),
      ),
      snackBarTheme: SnackBarThemeData(
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(_radius - 4)),
      ),
      segmentedButtonTheme: SegmentedButtonThemeData(
        style: SegmentedButton.styleFrom(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(_radius - 4)),
        ),
      ),
      floatingActionButtonTheme: FloatingActionButtonThemeData(
        backgroundColor: primary,
        foregroundColor: onPrimary,
        elevation: 0,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(_radius)),
      ),
      dividerTheme: DividerThemeData(color: outline, thickness: 1),
      extensions: [
        AppSemanticColors(success: success),
      ],
    );
  }
}
