import 'package:flutter/material.dart';
import '../core/theme/app_colors.dart';

/// Widget que muestra ondas de sonido animadas
/// Las barras se mueven verticalmente simulando un ecualizador
/// Se puede pausar/reanudar la animación según el estado de reproducción
class SoundWaves extends StatefulWidget {
  // Controla si las ondas deben animarse
  final bool isPlaying;

  const SoundWaves({super.key, this.isPlaying = true});

  @override
  State<SoundWaves> createState() => _SoundWavesState();
}

class _SoundWavesState extends State<SoundWaves>
    with SingleTickerProviderStateMixin {
  // Controlador para la animación de las ondas
  late AnimationController _waveController;
  late Animation<double> _waveAnimation;

  @override
  void initState() {
    super.initState();
    // Configurar animación de 1.5 segundos
    _waveController = AnimationController(
      duration: const Duration(milliseconds: 1500),
      vsync: this,
    );

    _waveAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _waveController, curve: Curves.easeInOut),
    );

    // Iniciar animación si está reproduciendo
    if (widget.isPlaying) {
      _waveController.repeat(reverse: true);
    }
  }

  @override
  void didUpdateWidget(SoundWaves oldWidget) {
    super.didUpdateWidget(oldWidget);
    // Detectar cambios en el estado de reproducción
    if (widget.isPlaying != oldWidget.isPlaying) {
      if (widget.isPlaying) {
        _waveController.repeat(reverse: true);
      } else {
        _waveController.stop();
      }
    }
  }

  @override
  void dispose() {
    _waveController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // Obtener información del dispositivo para diseño responsivo
    final screenSize = MediaQuery.of(context).size;
    final isTablet = screenSize.shortestSide >= 600;

    // Calcular tamaños dinámicos según el dispositivo
    final barCount = isTablet ? 7 : 5; // Más barras en tablets
    final barSpacing = isTablet ? 3.0 : 2.0;
    final barWidth = isTablet ? 6.0 : 4.0;
    final borderRadius = isTablet ? 3.0 : 2.0;

    // Calcular alturas base y máxima adaptadas al dispositivo
    double baseHeight;
    double maxHeight;

    if (isTablet) {
      baseHeight = 30;
      maxHeight = 60;
    } else {
      // Para teléfonos, usar porcentaje del alto de pantalla
      final availableHeight = screenSize.height * 0.08; // 8% del alto
      baseHeight = availableHeight * 0.4; // Altura mínima
      maxHeight = availableHeight; // Altura máxima

      // Aplicar límites de seguridad para evitar tamaños extremos
      if (baseHeight < 15) baseHeight = 15;
      if (maxHeight < 30) maxHeight = 30;
      if (baseHeight > 25) baseHeight = 25;
      if (maxHeight > 50) maxHeight = 50;
    }

    return AnimatedBuilder(
      animation: _waveAnimation,
      builder: (context, child) {
        return SizedBox(
          // Altura fija del contenedor para evitar saltos visuales
          height: maxHeight + 10,
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.end, // Alinear desde abajo
            children: List.generate(barCount, (index) {
              // Asignar diferentes patrones de animación a cada barra
              // Esto crea un efecto de ecualizador más realista
              double animationMultiplier;
              switch (index % 4) {
                case 0:
                  animationMultiplier = 1.0;
                  break;
                case 1:
                  animationMultiplier = 0.6;
                  break;
                case 2:
                  animationMultiplier = 0.8;
                  break;
                case 3:
                  animationMultiplier = 0.4;
                  break;
                default:
                  animationMultiplier = 0.7;
              }

              // Calcular altura animada de la barra
              final animatedHeight =
                  baseHeight +
                  ((maxHeight - baseHeight) *
                      _waveAnimation.value *
                      animationMultiplier);

              return Container(
                margin: EdgeInsets.symmetric(horizontal: barSpacing),
                width: barWidth,
                height: animatedHeight,
                decoration: BoxDecoration(
                  // Gradiente de abajo hacia arriba
                  gradient: LinearGradient(
                    begin: Alignment.bottomCenter,
                    end: Alignment.topCenter,
                    colors: [
                      AppColors.primary.withValues(alpha: 0.8),
                      AppColors.primary.withValues(alpha: 0.4),
                    ],
                  ),
                  borderRadius: BorderRadius.circular(borderRadius),
                  // Sombra sutil para dar profundidad
                  boxShadow: [
                    BoxShadow(
                      color: AppColors.primary.withValues(alpha: 0.2),
                      blurRadius: isTablet ? 3 : 2,
                      spreadRadius: 0,
                      offset: const Offset(0, 1),
                    ),
                  ],
                ),
              );
            }),
          ),
        );
      },
    );
  }
}
