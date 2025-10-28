import 'package:flutter/material.dart';
import '../core/theme/app_colors.dart';
import '../utils/responsive_helper.dart';

/// Widget que muestra ondas de sonido animadas.
/// Las barras se mueven verticalmente simulando un ecualizador.
/// Se detiene y reanuda la animación según el estado de reproducción.
class SoundWaves extends StatefulWidget {
  /// Controla si las ondas deben animarse.
  final bool isPlaying;

  const SoundWaves({super.key, this.isPlaying = true});

  @override
  State<SoundWaves> createState() => _SoundWavesState();
}

class _SoundWavesState extends State<SoundWaves>
    with SingleTickerProviderStateMixin {
  /// Controlador principal para la animación de las ondas (ciclo).
  late AnimationController _waveController;

  /// Animación que varía de 0.0 a 1.0 (ida y vuelta).
  late Animation<double> _waveAnimation;

  @override
  void initState() {
    super.initState();
    // Configurar animación de 1.5 segundos (una onda completa)
    _waveController = AnimationController(
      duration: const Duration(milliseconds: 1500),
      vsync: this,
    );

    _waveAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _waveController, curve: Curves.easeInOut),
    );

    // Iniciar animación si está reproduciendo.
    if (widget.isPlaying) {
      _waveController.repeat(
        reverse: true,
      ); // Animación cíclica de ida y vuelta
    }
  }

  @override
  void didUpdateWidget(SoundWaves oldWidget) {
    super.didUpdateWidget(oldWidget);
    // Detectar cambios en el estado de reproducción para pausar/reanudar.
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
    final responsive = ResponsiveHelper(context);

    // Número de barras dinámico según el dispositivo (más en desktop).
    final barCount = responsive.getValue(
      smallPhone: 5,
      phone: 5,
      largePhone: 6,
      tablet: 7,
      desktop: 9,
      automotive: 6,
    );

    // Espaciado entre barras (adaptativo).
    final barSpacing = responsive.getValue(
      smallPhone: 1.5,
      phone: 2.0,
      largePhone: 2.5,
      tablet: 3.0,
      desktop: 3.5,
      automotive: 2.5,
    );

    // Ancho de cada barra (adaptativo).
    final barWidth = responsive.getValue(
      smallPhone: 3.5,
      phone: 4.0,
      largePhone: 5.0,
      tablet: 6.0,
      desktop: 7.0,
      automotive: 5.0,
    );

    // Border radius de las barras.
    final borderRadius = responsive.getValue(
      smallPhone: 1.8,
      phone: 2.0,
      largePhone: 2.5,
      tablet: 3.0,
      desktop: 3.5,
      automotive: 2.5,
    );

    // Altura base (mínima) de las barras cuando la animación está cerca de 0.
    final baseHeight = responsive.getValue(
      smallPhone: 15.0,
      phone: 18.0,
      largePhone: 22.0,
      tablet: 30.0,
      desktop: 35.0,
      automotive: 24.0,
    );

    // Altura máxima (tope) de la animación.
    final maxHeight = responsive.getValue(
      smallPhone: 32.0,
      phone: 38.0,
      largePhone: 45.0,
      tablet: 60.0,
      desktop: 70.0,
      automotive: 48.0,
    );

    // Blur de la sombra para el efecto de luz.
    final shadowBlur = responsive.getValue(
      smallPhone: 1.5,
      phone: 2.0,
      tablet: 3.0,
      desktop: 4.0,
      automotive: 2.5,
    );

    // Padding adicional para asegurar que la sombra no sea cortada.
    final containerPadding = responsive.getValue(
      smallPhone: 8.0,
      phone: 10.0,
      tablet: 12.0,
      desktop: 14.0,
      automotive: 10.0,
    );

    return AnimatedBuilder(
      animation: _waveAnimation,
      builder: (context, child) {
        return SizedBox(
          // Altura fija del contenedor basada en el máximo para evitar CLS.
          height: maxHeight + containerPadding,
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment
                .end, // Alinear las barras desde la parte inferior.
            children: List.generate(barCount, (index) {
              // Lógica de "desfase" para simular un ecualizador orgánico,
              // asegurando que no todas las barras se muevan a la misma altura o tiempo.
              double animationMultiplier;
              switch (index % 4) {
                case 0: // La más activa
                  animationMultiplier = 1.0;
                  break;
                case 1:
                  animationMultiplier = 0.6;
                  break;
                case 2:
                  animationMultiplier = 0.8;
                  break;
                case 3: // La menos activa
                  animationMultiplier = 0.4;
                  break;
                default:
                  animationMultiplier = 0.7;
              }

              // 1. Calcula el rango total de altura de animación (maxHeight - baseHeight).
              // 2. Multiplica por el valor actual de la animación (_waveAnimation.value).
              // 3. Aplica el desfase por barra (animationMultiplier).
              // 4. Suma la altura base (mínima).
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
                  // Gradiente de abajo hacia arriba para un efecto de "ecualizador" que se ilumina.
                  gradient: LinearGradient(
                    begin: Alignment.bottomCenter,
                    end: Alignment.topCenter,
                    colors: [
                      AppColors.primary.withValues(alpha: 0.8),
                      AppColors.primary.withValues(alpha: 0.4),
                    ],
                  ),
                  borderRadius: BorderRadius.circular(borderRadius),
                  // Sombra sutil para dar profundidad.
                  boxShadow: [
                    BoxShadow(
                      color: AppColors.primary.withValues(alpha: 0.2),
                      blurRadius: shadowBlur,
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
