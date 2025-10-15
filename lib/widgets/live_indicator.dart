import 'package:flutter/material.dart';
import '../core/theme/app_colors.dart';

/// Indicador "EN VIVO" que se muestra cuando la radio está reproduciendo
/// Aparece en el AppBar junto al título para indicar transmisión activa
class LiveIndicator extends StatelessWidget {
  const LiveIndicator({super.key});

  @override
  Widget build(BuildContext context) {
    // Obtener información del dispositivo para diseño responsivo
    final screenSize = MediaQuery.of(context).size;
    final isTablet = screenSize.shortestSide >= 600;
    final textScale = MediaQuery.of(context).textScaler.scale(1.0);

    // Calcular tamaños dinámicos según el tipo de dispositivo
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
        // Sombra sutil para destacar el indicador
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
          // Icono de radio transmitiendo
          Icon(
            Icons.radio_button_checked,
            size: iconSize,
            color: AppColors.textPrimary,
          ),
          SizedBox(width: spacing),
          // Texto "EN VIVO"
          Text(
            'EN VIVO',
            style: TextStyle(
              fontSize: fontSize,
              fontWeight: FontWeight.bold,
              color: AppColors.textPrimary,
              letterSpacing: isTablet ? 0.5 : 0.3,
            ),
          ),
        ],
      ),
    );
  }
}
