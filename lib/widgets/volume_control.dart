import 'package:flutter/material.dart';
import 'package:volume_controller/volume_controller.dart';
import '../core/theme/app_colors.dart';
import '../services/audio_player_manager.dart';
import '../utils/responsive_helper.dart';

/// Control de volumen con botón y slider expandible
/// Muestra un botón con el icono de volumen actual y porcentaje
/// Al tocar el botón, expande un slider para ajustar el volumen
class VolumeControl extends StatefulWidget {
  final AudioPlayerManager audioManager;

  const VolumeControl({super.key, required this.audioManager});

  @override
  State<VolumeControl> createState() => _VolumeControlState();
}

class _VolumeControlState extends State<VolumeControl> {
  // Controla la visibilidad del slider de volumen
  bool _showVolumeSlider = false;

  // Volumen local sincronizado con el audio manager
  double _localVolume = 0.7;

  @override
  void initState() {
    super.initState();
    _localVolume = widget.audioManager.volume;

    widget.audioManager.volumeStream.listen((volume) {
      if (mounted) {
        setState(() {
          _localVolume = volume;
        });
      }
    });

    _syncWithSystemVolume();

    // El listener recibe el volumen directamente
    VolumeController.instance.addListener((volume) {
      if (mounted) {
        setState(() => _localVolume = volume);
        widget.audioManager.setVolume(volume);
      }
    });
  }

  Future<void> _syncWithSystemVolume() async {
    final systemVolume = await VolumeController.instance.getVolume();
    setState(() => _localVolume = systemVolume);
    widget.audioManager.setVolume(systemVolume);
  }

  /// Retorna el icono apropiado según el nivel de volumen
  IconData _getVolumeIcon(double volume) {
    if (volume == 0) return Icons.volume_off;
    if (volume < 0.5) return Icons.volume_down;
    return Icons.volume_up;
  }

  /// Alterna la visibilidad del slider de volumen
  void _toggleVolumeSlider() {
    setState(() {
      _showVolumeSlider = !_showVolumeSlider;
    });
  }

  /// Maneja los cambios en el slider y actualiza el volumen
  void _handleVolumeChange(double value) {
    setState(() {
      _localVolume = value;
    });
    widget.audioManager.setVolume(value);
  }

  @override
  Widget build(BuildContext context) {
    final responsive = ResponsiveHelper(context);

    // Padding horizontal del contenedor principal
    final horizontalPadding = responsive.getValue(
      smallPhone: 20.0,
      phone: 24.0,
      largePhone: 32.0,
      tablet: 60.0,
      desktop: 80.0,
      automotive: 40.0,
    );

    // Padding del botón de volumen
    final buttonPadding = responsive.getValue(
      smallPhone: 10.0,
      phone: 12.0,
      largePhone: 14.0,
      tablet: 16.0,
      desktop: 18.0,
      automotive: 14.0,
    );

    // Border radius de los botones
    final buttonRadius = responsive.getValue(
      smallPhone: 10.0,
      phone: 12.0,
      largePhone: 14.0,
      tablet: 16.0,
      desktop: 18.0,
      automotive: 14.0,
    );

    // Tamaño del ícono
    final iconSize = responsive.getValue(
      smallPhone: 22.0,
      phone: 24.0,
      largePhone: 26.0,
      tablet: 28.0,
      desktop: 32.0,
      automotive: 26.0,
    );

    // Tamaño de fuente del porcentaje
    final fontSize = responsive.getValue(
      smallPhone: 14.0,
      phone: 16.0,
      largePhone: 17.0,
      tablet: 18.0,
      desktop: 20.0,
      automotive: 17.0,
    );

    // Padding del contenedor del slider
    final sliderPadding = responsive.getValue(
      smallPhone: 14.0,
      phone: 16.0,
      largePhone: 18.0,
      tablet: 20.0,
      desktop: 24.0,
      automotive: 18.0,
    );

    // Border radius del slider
    final sliderRadius = responsive.getValue(
      smallPhone: 10.0,
      phone: 12.0,
      largePhone: 14.0,
      tablet: 16.0,
      desktop: 18.0,
      automotive: 14.0,
    );

    // Espaciado entre botón y slider
    final spacing = responsive.getValue(
      smallPhone: 14.0,
      phone: 16.0,
      largePhone: 18.0,
      tablet: 20.0,
      desktop: 24.0,
      automotive: 18.0,
    );

    // Altura del track del slider
    final trackHeight = responsive.getValue(
      smallPhone: 3.5,
      phone: 4.0,
      largePhone: 5.0,
      tablet: 6.0,
      desktop: 7.0,
      automotive: 5.0,
    );

    // Radio del thumb del slider
    final thumbRadius = responsive.getValue(
      smallPhone: 10.0,
      phone: 12.0,
      largePhone: 13.0,
      tablet: 14.0,
      desktop: 16.0,
      automotive: 13.0,
    );

    // Blur de sombras
    final shadowBlur1 = responsive.getValue(
      smallPhone: 5.0,
      phone: 6.0,
      tablet: 8.0,
      desktop: 10.0,
      automotive: 7.0,
    );

    final shadowBlur2 = responsive.getValue(
      smallPhone: 6.0,
      phone: 8.0,
      tablet: 12.0,
      desktop: 14.0,
      automotive: 10.0,
    );

    // Tamaño de íconos del slider
    final sliderIconSize = responsive.getValue(
      smallPhone: 13.0,
      phone: 14.0,
      largePhone: 15.0,
      tablet: 16.0,
      desktop: 18.0,
      automotive: 15.0,
    );

    // Padding del indicador de porcentaje
    final percentPaddingH = responsive.getValue(
      smallPhone: 6.0,
      phone: 8.0,
      largePhone: 10.0,
      tablet: 12.0,
      desktop: 14.0,
      automotive: 10.0,
    );

    final percentPaddingV = responsive.getValue(
      smallPhone: 5.0,
      phone: 6.0,
      largePhone: 7.0,
      tablet: 8.0,
      desktop: 9.0,
      automotive: 7.0,
    );

    // Padding vertical del slider
    final sliderVerticalPadding = responsive.getValue(
      smallPhone: 6.0,
      phone: 8.0,
      largePhone: 10.0,
      tablet: 12.0,
      desktop: 14.0,
      automotive: 10.0,
    );

    // Espaciado dentro del slider
    final sliderInnerSpacing = responsive.getValue(
      smallPhone: 3.0,
      phone: 4.0,
      largePhone: 6.0,
      tablet: 8.0,
      desktop: 10.0,
      automotive: 6.0,
    );

    // Número de divisiones del slider
    final divisions = responsive.getValue(
      smallPhone: 10,
      phone: 10,
      largePhone: 15,
      tablet: 20,
      desktop: 20,
      automotive: 15,
    );

    return Container(
      padding: EdgeInsets.symmetric(horizontal: horizontalPadding),
      child: Column(
        children: [
          // Fila con botón de volumen y porcentaje
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              // Botón de volumen con icono
              GestureDetector(
                onTap: _toggleVolumeSlider,
                child: Container(
                  padding: EdgeInsets.all(buttonPadding),
                  decoration: BoxDecoration(
                    color: AppColors.surface,
                    borderRadius: BorderRadius.circular(buttonRadius),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.1),
                        blurRadius: shadowBlur1,
                        spreadRadius: 1,
                        offset: const Offset(0, 2),
                      ),
                    ],
                    // Borde resaltado cuando el slider está visible
                    border: _showVolumeSlider
                        ? Border.all(
                            color: AppColors.primary.withValues(alpha: 0.3),
                            width: 2,
                          )
                        : null,
                  ),
                  child: Icon(
                    _getVolumeIcon(_localVolume),
                    color: _showVolumeSlider
                        ? AppColors.primary
                        : AppColors.primary.withValues(alpha: 0.8),
                    size: iconSize,
                  ),
                ),
              ),

              // Indicador de porcentaje de volumen
              Container(
                padding: EdgeInsets.symmetric(
                  horizontal: percentPaddingH,
                  vertical: percentPaddingV,
                ),
                decoration: BoxDecoration(
                  color: AppColors.surface.withValues(alpha: 0.5),
                  borderRadius: BorderRadius.circular(buttonRadius),
                ),
                child: Text(
                  '${(_localVolume * 100).round()}%',
                  style: TextStyle(
                    color: AppColors.textMuted,
                    fontSize: fontSize,
                    fontWeight: FontWeight.w500,
                    letterSpacing: 0.5,
                  ),
                ),
              ),
            ],
          ),

          // Slider expandible de volumen
          if (_showVolumeSlider) ...[
            SizedBox(height: spacing),
            Container(
              decoration: BoxDecoration(
                color: AppColors.surface,
                borderRadius: BorderRadius.circular(sliderRadius),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.1),
                    blurRadius: shadowBlur2,
                    spreadRadius: 1,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              padding: EdgeInsets.symmetric(
                horizontal: sliderPadding,
                vertical: sliderVerticalPadding,
              ),
              child: Column(
                children: [
                  // Iconos indicadores de volumen bajo y alto
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Icon(
                        Icons.volume_mute,
                        color: AppColors.textSecondary,
                        size: sliderIconSize,
                      ),
                      Icon(
                        Icons.volume_up,
                        color: AppColors.textSecondary,
                        size: sliderIconSize,
                      ),
                    ],
                  ),

                  SizedBox(height: sliderInnerSpacing),

                  // Control deslizante de volumen
                  SliderTheme(
                    data: SliderThemeData(
                      activeTrackColor: AppColors.primary,
                      inactiveTrackColor: const Color(0xFF374151),
                      thumbColor: AppColors.primary,
                      overlayColor: AppColors.primary.withValues(alpha: 0.2),
                      trackHeight: trackHeight,
                      thumbShape: RoundSliderThumbShape(
                        enabledThumbRadius: thumbRadius,
                        elevation: 2,
                      ),
                      overlayShape: RoundSliderOverlayShape(
                        overlayRadius: thumbRadius * 1.5,
                      ),
                    ),
                    child: Slider(
                      value: _localVolume,
                      onChanged: _handleVolumeChange,
                      min: 0.0,
                      max: 1.0,
                      // Divisiones para valores discretos
                      divisions: divisions,
                      label: '${(_localVolume * 100).round()}%',
                    ),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }
}
