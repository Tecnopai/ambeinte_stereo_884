import 'package:flutter/material.dart';
import '../core/theme/app_colors.dart';

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
    // Obtener información del dispositivo para diseño responsivo
    final screenSize = MediaQuery.of(context).size;
    final isTablet = screenSize.shortestSide >= 600;
    final isLandscape = screenSize.width > screenSize.height;
    final textScale = MediaQuery.of(context).textScaler.scale(1.0);

    // Variables para tamaños dinámicos
    double discSize;
    double innerSize;
    double shadowBlur;
    double shadowSpread;

    if (isTablet) {
      // Tamaños para tablets
      discSize = isLandscape ? 200 : 180;
      shadowBlur = 25;
      shadowSpread = 6;
    } else {
      // Tamaños para teléfonos - usar porcentaje del ancho de pantalla
      final screenWidth = screenSize.width;
      discSize = screenWidth * 0.4; // 40% del ancho de pantalla

      // Aplicar límites mínimos y máximos
      if (discSize < 120) discSize = 120; // Mínimo para pantallas muy pequeñas
      if (discSize > 160) discSize = 160; // Máximo para pantallas grandes

      shadowBlur = 20;
      shadowSpread = 5;
    }

    // Reducir tamaño si la escala de texto es muy grande
    if (textScale > 1.2) {
      discSize = discSize * 0.9;
    }

    // El contenedor interior es 85% del tamaño exterior
    innerSize = discSize * 0.85;

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
                        size: innerSize * 0.4,
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
