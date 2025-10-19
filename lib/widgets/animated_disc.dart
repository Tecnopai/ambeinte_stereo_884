import 'package:flutter/material.dart';
import '../core/theme/app_colors.dart';
import '../utils/responsive_helper.dart';

/// Widget de disco animado que rota cuando está reproduciendo
/// Simula un disco de vinilo girando con el logo de la emisora
class AnimatedDisc extends StatefulWidget {
  // Indica si el disco debe estar girando
  final bool isPlaying;

  const AnimatedDisc({super.key, required this.isPlaying});

  @override
  State<AnimatedDisc> createState() => _AnimatedDiscState();
}

class _AnimatedDiscState extends State<AnimatedDisc>
    with SingleTickerProviderStateMixin {
  // Controlador para la animación de rotación
  late AnimationController _rotationController;

  @override
  void initState() {
    super.initState();
    // Configurar animación de 10 segundos por rotación completa
    _rotationController = AnimationController(
      duration: const Duration(seconds: 10),
      vsync: this,
    );

    // Si está reproduciendo, iniciar la rotación
    if (widget.isPlaying) {
      _rotationController.repeat();
    }
  }

  @override
  void didUpdateWidget(AnimatedDisc oldWidget) {
    super.didUpdateWidget(oldWidget);
    // Detectar cambios en el estado de reproducción
    if (widget.isPlaying != oldWidget.isPlaying) {
      if (widget.isPlaying) {
        _rotationController.repeat();
      } else {
        _rotationController.stop();
      }
    }
  }

  @override
  void dispose() {
    _rotationController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final responsive = ResponsiveHelper(context);

    // Tamaños responsivos del disco usando ResponsiveHelper
    final discSize = responsive.getValue(
      smallPhone: 120.0,
      phone: 140.0,
      largePhone: 160.0,
      tablet: 180.0,
      largeTablet: 200.0,
      desktop: 220.0,
      automotive: 170.0,
    );

    // Blur y spread de la sombra
    final shadowBlur = responsive.getValue(
      smallPhone: 15.0,
      phone: 20.0,
      largePhone: 22.0,
      tablet: 25.0,
      desktop: 30.0,
      automotive: 22.0,
    );

    final shadowSpread = responsive.getValue(
      smallPhone: 3.0,
      phone: 5.0,
      tablet: 6.0,
      desktop: 8.0,
      automotive: 5.0,
    );

    // Tamaño del icono de error
    final iconSize = responsive.getValue(
      smallPhone: 48.0,
      phone: 56.0,
      largePhone: 64.0,
      tablet: 72.0,
      desktop: 88.0,
      automotive: 68.0,
    );

    // El contenedor interior es 85% del tamaño exterior
    final innerSize = discSize * 0.85;

    return AnimatedBuilder(
      animation: _rotationController,
      builder: (context, child) {
        return Transform.rotate(
          // Calcular ángulo de rotación en radianes
          angle: _rotationController.value * 2 * 3.14159,
          child: Container(
            width: discSize,
            height: discSize,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: AppColors.discGradient,
              boxShadow: [
                BoxShadow(
                  color: const Color.fromARGB(36, 240, 240, 241),
                  blurRadius: shadowBlur,
                  spreadRadius: shadowSpread,
                ),
              ],
            ),
            child: Center(
              // Círculo interior blanco que contiene el logo
              child: Container(
                width: innerSize,
                height: innerSize,
                decoration: const BoxDecoration(
                  shape: BoxShape.circle,
                  color: Color.fromARGB(255, 255, 255, 255),
                ),
                child: ClipOval(
                  child: Image.asset(
                    'assets/images/ambiente_logo.png',
                    width: innerSize * 0.7, // 70% del contenedor interior
                    height: innerSize * 0.7,
                    fit: BoxFit.cover,
                    // Mostrar icono por defecto si la imagen falla
                    errorBuilder: (context, error, stackTrace) {
                      return Icon(
                        Icons.music_note,
                        color: AppColors.primary,
                        size: iconSize * 0.4,
                      );
                    },
                  ),
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}
