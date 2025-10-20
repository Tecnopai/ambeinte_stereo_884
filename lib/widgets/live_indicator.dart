import 'package:flutter/material.dart';
import '../core/theme/app_colors.dart';
import '../utils/responsive_helper.dart';

/// Indicador "EN VIVO" que se muestra cuando la radio está reproduciendo
/// Aparece en el AppBar junto al título para indicar transmisión activa
class LiveIndicator extends StatelessWidget {
  const LiveIndicator({super.key});

  @override
  Widget build(BuildContext context) {
    final responsive = ResponsiveHelper(context);

    // Padding horizontal del contenedor
    final horizontalPadding = responsive.getValue(
      smallPhone: 6.0,
      phone: 8.0,
      largePhone: 10.0,
      tablet: 12.0,
      desktop: 14.0,
      automotive: 12.0,
    );

    // Padding vertical del contenedor
    final verticalPadding = responsive.getValue(
      smallPhone: 2.0,
      phone: 2.0,
      largePhone: 3.0,
      tablet: 4.0,
      desktop: 5.0,
      automotive: 4.0,
    );

    // Border radius del contenedor
    final borderRadius = responsive.getValue(
      smallPhone: 10.0,
      phone: 12.0,
      largePhone: 14.0,
      tablet: 16.0,
      desktop: 18.0,
      automotive: 14.0,
    );

    // Tamaño del ícono
    final iconSize = responsive.getValue(
      smallPhone: 11.0,
      phone: 12.0,
      largePhone: 14.0,
      tablet: 16.0,
      desktop: 18.0,
      automotive: 16.0,
    );

    // Espaciado entre ícono y texto
    final spacing = responsive.getValue(
      smallPhone: 3.0,
      phone: 4.0,
      largePhone: 5.0,
      tablet: 6.0,
      desktop: 7.0,
      automotive: 6.0,
    );

    // Tamaño de fuente del texto
    final fontSize = responsive.getValue(
      smallPhone: 8.0,
      phone: 9.0,
      largePhone: 10.0,
      tablet: 11.0,
      desktop: 12.0,
      automotive: 11.0,
    );

    // Margen izquierdo
    final marginLeft = responsive.getValue(
      smallPhone: 6.0,
      phone: 8.0,
      largePhone: 10.0,
      tablet: 12.0,
      desktop: 14.0,
      automotive: 10.0,
    );

    // Blur de la sombra
    final shadowBlur = responsive.getValue(
      smallPhone: 2.5,
      phone: 3.0,
      tablet: 4.0,
      desktop: 5.0,
      automotive: 3.5,
    );

    // Letter spacing
    final letterSpacing = responsive.getValue(
      smallPhone: 0.2,
      phone: 0.3,
      largePhone: 0.4,
      tablet: 0.5,
      desktop: 0.6,
      automotive: 0.4,
    );

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
            blurRadius: shadowBlur,
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
              letterSpacing: letterSpacing,
            ),
          ),
        ],
      ),
    );
  }
}
