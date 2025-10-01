import 'package:flutter/material.dart';
import '../core/theme/app_colors.dart';

class SoundWaves extends StatefulWidget {
  final bool isPlaying; // Agregamos control para pausar/reanudar animación

  const SoundWaves({super.key, this.isPlaying = true});

  @override
  State<SoundWaves> createState() => _SoundWavesState();
}

class _SoundWavesState extends State<SoundWaves>
    with SingleTickerProviderStateMixin {
  late AnimationController _waveController;
  late Animation<double> _waveAnimation;

  @override
  void initState() {
    super.initState();
    _waveController = AnimationController(
      duration: const Duration(milliseconds: 1500),
      vsync: this,
    );

    _waveAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _waveController, curve: Curves.easeInOut),
    );

    if (widget.isPlaying) {
      _waveController.repeat(reverse: true);
    }
  }

  @override
  void didUpdateWidget(SoundWaves oldWidget) {
    super.didUpdateWidget(oldWidget);
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
    // Obtener información del dispositivo
    final screenSize = MediaQuery.of(context).size;
    final isTablet = screenSize.shortestSide >= 600;

    // Calcular tamaños dinámicos
    final barCount = isTablet ? 7 : 5; // Más barras en tablets
    final barSpacing = isTablet ? 3.0 : 2.0;
    final barWidth = isTablet ? 6.0 : 4.0;
    final borderRadius = isTablet ? 3.0 : 2.0;

    // Altura base y máxima adaptadas al dispositivo
    double baseHeight;
    double maxHeight;

    if (isTablet) {
      baseHeight = 30;
      maxHeight = 60;
    } else {
      // Para teléfonos, usar un porcentaje del alto de pantalla
      final availableHeight =
          screenSize.height * 0.08; // 8% del alto de pantalla
      baseHeight = availableHeight * 0.4; // Altura mínima
      maxHeight = availableHeight; // Altura máxima

      // Límites de seguridad
      if (baseHeight < 15) baseHeight = 15;
      if (maxHeight < 30) maxHeight = 30;
      if (baseHeight > 25) baseHeight = 25;
      if (maxHeight > 50) maxHeight = 50;
    }

    return AnimatedBuilder(
      animation: _waveAnimation,
      builder: (context, child) {
        return SizedBox(
          height:
              maxHeight + 10, // Altura fija del contenedor para evitar saltos
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment:
                CrossAxisAlignment.end, // Alineación desde abajo
            children: List.generate(barCount, (index) {
              // Diferentes patrones de animación para cada barra
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

              // Calcular altura de la barra con animación
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
                  // Gradiente más dinámico
                  gradient: LinearGradient(
                    begin: Alignment.bottomCenter,
                    end: Alignment.topCenter,
                    colors: [
                      AppColors.primary.withValues(alpha: 0.8),
                      AppColors.primary.withValues(alpha: 0.4),
                    ],
                  ),
                  borderRadius: BorderRadius.circular(borderRadius),
                  // Sombra sutil para profundidad
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
