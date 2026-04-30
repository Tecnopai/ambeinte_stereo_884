import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'app_colors.dart';

class AppTheme {
  AppTheme._();

  static ThemeData get darkTheme {
    final interTextTheme = GoogleFonts.interTextTheme(
      const TextTheme(
        headlineLarge: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, height: 1.2),
        headlineMedium: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, height: 1.3),
        headlineSmall: TextStyle(color: Colors.white, fontWeight: FontWeight.w600, height: 1.3),
        titleLarge: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, height: 1.3),
        titleMedium: TextStyle(color: Colors.white, fontWeight: FontWeight.w600, height: 1.4),
        titleSmall: TextStyle(color: Colors.white, fontWeight: FontWeight.w600, height: 1.4),
        bodyLarge: TextStyle(color: Colors.white, height: 1.5),
        bodyMedium: TextStyle(color: AppColors.textMuted, height: 1.5),
        bodySmall: TextStyle(color: AppColors.textMuted, height: 1.4),
        labelLarge: TextStyle(color: Colors.white, fontWeight: FontWeight.w600),
        labelMedium: TextStyle(color: AppColors.textSecondary, fontWeight: FontWeight.w500),
        labelSmall: TextStyle(color: AppColors.textSecondary, fontWeight: FontWeight.w500),
      ),
    );

    return ThemeData(
      useMaterial3: true,
      scaffoldBackgroundColor: AppColors.background,
      textTheme: interTextTheme,
      colorScheme: const ColorScheme.dark(
        brightness: Brightness.dark,
        primary: AppColors.primary,
        onPrimary: Colors.white,
        secondary: AppColors.secondary,
        onSecondary: Colors.white,
        surface: AppColors.surface,
        onSurface: AppColors.textPrimary,
        surfaceContainerHighest: AppColors.surfaceVariant,
        onSurfaceVariant: AppColors.textSecondary,
        outline: Color(0xFF1E301E),
        primaryContainer: AppColors.surfaceVariant,
        onPrimaryContainer: AppColors.textPrimary,
        error: AppColors.error,
        onError: Colors.white,
      ),
      appBarTheme: AppBarTheme(
        backgroundColor: AppColors.background,
        foregroundColor: Colors.white,
        elevation: 0,
        scrolledUnderElevation: 0,
        centerTitle: true,
        systemOverlayStyle: SystemUiOverlayStyle.light,
        titleTextStyle: GoogleFonts.inter(
          color: Colors.white,
          fontWeight: FontWeight.w600,
          fontSize: 16,
          letterSpacing: 0.2,
        ),
      ),
      bottomNavigationBarTheme: BottomNavigationBarThemeData(
        backgroundColor: AppColors.surface,
        selectedItemColor: AppColors.primary,
        unselectedItemColor: AppColors.textSecondary,
        type: BottomNavigationBarType.fixed,
        elevation: 0,
        selectedLabelStyle: GoogleFonts.inter(fontWeight: FontWeight.w600, fontSize: 12),
        unselectedLabelStyle: GoogleFonts.inter(fontWeight: FontWeight.normal, fontSize: 11),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ButtonStyle(
          backgroundColor: WidgetStateProperty.all(AppColors.primary),
          foregroundColor: WidgetStateProperty.all(AppColors.background),
          elevation: WidgetStateProperty.all(0),
          shadowColor: WidgetStateProperty.all(Colors.transparent),
          shape: WidgetStateProperty.all(
            RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
          ),
          textStyle: WidgetStateProperty.all(
            GoogleFonts.inter(fontWeight: FontWeight.w600),
          ),
          padding: WidgetStateProperty.all(
            const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
          ),
        ),
      ),
      cardTheme: CardThemeData(
        color: AppColors.surfaceVariant,
        elevation: 0,
        shadowColor: Colors.transparent,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: BorderSide(color: Colors.white.withValues(alpha: 0.08), width: 1),
        ),
        margin: EdgeInsets.zero,
      ),
      sliderTheme: SliderThemeData(
        activeTrackColor: AppColors.primary,
        inactiveTrackColor: AppColors.textSecondary.withValues(alpha: 0.2),
        thumbColor: AppColors.primary,
        overlayColor: Colors.white.withValues(alpha: 0.1),
        valueIndicatorColor: AppColors.surfaceVariant,
        valueIndicatorTextStyle: GoogleFonts.inter(
          color: Colors.white,
          fontWeight: FontWeight.w600,
        ),
      ),
      iconTheme: const IconThemeData(color: Colors.white),
      dividerTheme: DividerThemeData(
        color: Colors.white.withValues(alpha: 0.08),
        thickness: 1,
      ),
      tabBarTheme: TabBarThemeData(
        labelColor: Colors.white,
        unselectedLabelColor: AppColors.textSecondary,
        indicatorColor: Colors.white,
        indicatorSize: TabBarIndicatorSize.label,
        labelStyle: GoogleFonts.inter(fontWeight: FontWeight.w600, fontSize: 13),
        unselectedLabelStyle: GoogleFonts.inter(fontWeight: FontWeight.normal, fontSize: 13),
        dividerColor: Colors.transparent,
      ),
    );
  }

  // ====================================================================
  // MÉTODOS UTILITARIOS RESPONSIVOS
  // ====================================================================

  static double getResponsiveFontSize(
    BuildContext context, {
    required double baseSize,
    double tabletMultiplier = 1.2,
  }) {
    final screenSize = MediaQuery.of(context).size;
    final isTablet = screenSize.shortestSide >= 600;
    final textScale = MediaQuery.of(context).textScaler.scale(1.0);
    return (isTablet ? baseSize * tabletMultiplier : baseSize) * textScale;
  }

  static EdgeInsets getResponsivePadding(
    BuildContext context, {
    required double basePadding,
    double tabletMultiplier = 1.3,
  }) {
    final isTablet = MediaQuery.of(context).size.shortestSide >= 600;
    final padding = isTablet ? basePadding * tabletMultiplier : basePadding;
    return EdgeInsets.all(padding);
  }

  static EdgeInsets getResponsiveSymmetricPadding(
    BuildContext context, {
    required double horizontalBase,
    required double verticalBase,
    double tabletMultiplier = 1.3,
  }) {
    final isTablet = MediaQuery.of(context).size.shortestSide >= 600;
    return EdgeInsets.symmetric(
      horizontal: isTablet ? horizontalBase * tabletMultiplier : horizontalBase,
      vertical: isTablet ? verticalBase * tabletMultiplier : verticalBase,
    );
  }

  static double getResponsiveBorderRadius(
    BuildContext context, {
    required double baseRadius,
    double tabletMultiplier = 1.3,
  }) {
    final isTablet = MediaQuery.of(context).size.shortestSide >= 600;
    return isTablet ? baseRadius * tabletMultiplier : baseRadius;
  }

  static double getResponsiveIconSize(
    BuildContext context, {
    required double baseSize,
    double tabletMultiplier = 1.2,
  }) {
    final isTablet = MediaQuery.of(context).size.shortestSide >= 600;
    final textScale = MediaQuery.of(context).textScaler.scale(1.0);
    return (isTablet ? baseSize * tabletMultiplier : baseSize) * textScale;
  }

  static bool isTablet(BuildContext context) =>
      MediaQuery.of(context).size.shortestSide >= 600;

  static bool isLandscape(BuildContext context) {
    final size = MediaQuery.of(context).size;
    return size.width > size.height;
  }
}
