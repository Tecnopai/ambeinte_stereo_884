import 'package:flutter/material.dart';

class AppColors {
  // Colores principales (tema oscuro)
  static const Color primary = Color(0xFF6366F1);
  static const Color secondary = Color(0xFF8B5CF6);
  static const Color accent = Color(0xFF7B68EE);

  // Colores de fondo
  static const Color background = Color(0xFF0F172A);
  static const Color surface = Color(0xFF1E293B);
  static const Color cardBackground = Color(0xFF1E293B);

  // Colores de texto
  static const Color textPrimary = Colors.white;
  static const Color textSecondary = Color(0xFF64748B);
  static const Color textMuted = Color(0xFFCBD5E1);

  // Colores de estado
  static const Color error = Colors.red;
  static const Color success = Color(0xFF10B981);
  static const Color warning = Color(0xFFF59E0B);
  static const Color liveIndicator = Colors.red;

  // Gradientes
  static const LinearGradient primaryGradient = LinearGradient(
    begin: Alignment.topCenter,
    end: Alignment.bottomCenter,
    colors: [Color(0xFF1E293B), Color(0xFF0F172A)],
  );

  static const LinearGradient buttonGradient = LinearGradient(
    colors: [Color(0xFF6366F1), Color(0xFF8B5CF6)],
  );

  static const RadialGradient discGradient = RadialGradient(
    colors: [Color(0xFF6366F1), Color(0xFF3730A3), Color(0xFF1E1B4B)],
  );
}
