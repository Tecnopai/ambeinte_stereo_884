import 'package:flutter/material.dart';
import '../core/theme/app_colors.dart';

class LiveIndicator extends StatelessWidget {
  const LiveIndicator({super.key});

  @override
  Widget build(BuildContext context) {
    // Obtener información del dispositivo
    final screenSize = MediaQuery.of(context).size;
    final isTablet = screenSize.shortestSide >= 600;
    final textScale = MediaQuery.of(context).textScaler.scale(1.0);

    // Calcular tamaños dinámicos
    final horizontalPadding = isTablet ? 12.0 : 8.0;
    final verticalPadding = isTablet ? 4.0 : 2.0;
    final borderRadius = isTablet ? 16.0 : 12.0;
    final iconSize = (isTablet ? 16.0 : 12.0) * textScale;
    final spacing = isTablet ? 6.0 : 4.0;
    final fontSize = (isTablet ? 10.0 : 8.0) * textScale;
    final marginLeft = isTablet ? 12.0 : 8.0;

    return Container(
      margin: EdgeInsets.only(left: marginLeft),
      padding: EdgeInsets.symmetric(
        horizontal: horizontalPadding,
        vertical: verticalPadding,
      ),
      decoration: BoxDecoration(
        color: AppColors.primary,
        borderRadius: BorderRadius.circular(borderRadius),
        // Agregar sombra sutil para mejor visibilidad
        boxShadow: [
          BoxShadow(
            color: AppColors.primary.withValues(alpha: 0.3),
            blurRadius: isTablet ? 4 : 3,
            spreadRadius: 1,
            offset: const Offset(0, 1),
          ),
        ],
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            Icons.radio_button_checked, // Ícono más apropiado para "en vivo"
            size: iconSize,
            color: AppColors.textPrimary,
          ),
          SizedBox(width: spacing),
          Text(
            'EN VIVO',
            style: TextStyle(
              fontSize: fontSize,
              fontWeight: FontWeight.bold,
              color: AppColors.textPrimary,
              letterSpacing: isTablet ? 0.5 : 0.3, // Mejor legibilidad
            ),
          ),
        ],
      ),
    );
  }
}
