import 'package:flutter/material.dart';
import 'package:volume_controller/volume_controller.dart';
import '../core/theme/app_colors.dart';
import '../services/audio_player_manager.dart';
import '../utils/responsive_helper.dart';

/// Control de volumen con botón y slider expandible.
///
/// Muestra un botón con el icono de volumen actual y porcentaje.
/// Al tocar el botón, permite al usuario expandir un slider para ajustar
/// el volumen. Se sincroniza con los botones de hardware del dispositivo.
class VolumeControl extends StatefulWidget {
  /// Instancia del gestor de audio. Necesario para actualizar el volumen interno.
  final AudioPlayerManager audioManager;

  const VolumeControl({super.key, required this.audioManager});

  @override
  State<VolumeControl> createState() => _VolumeControlState();
}

class _VolumeControlState extends State<VolumeControl> {
  /// Controla la visibilidad del slider de volumen expandido.
  bool _showVolumeSlider = false;

  /// Volumen local sincronizado con el audio manager y el sistema.
  double _localVolume = 0.7;

  @override
  void initState() {
    super.initState();
    // 1. Obtener el volumen inicial del manager.
    _localVolume = widget.audioManager.volume;

    // 2. Escuchar cambios de volumen internos del manager (ej. si el manager lo cambia).
    widget.audioManager.volumeStream.listen((volume) {
      if (mounted) {
        setState(() {
          _localVolume = volume;
        });
      }
    });

    // 3. Sincronizar el estado inicial con el volumen del sistema.
    _syncWithSystemVolume();

    // 4. Escuchar los botones de volumen físico del sistema.
    // Esto es crucial para mantener la sincronización bidireccional.
    VolumeController.instance.addListener((volume) {
      if (mounted) {
        setState(() => _localVolume = volume);
        widget.audioManager.setVolume(volume);
      }
    });
  }

  /// Sincroniza el volumen local y el del manager con el volumen actual del sistema.
  Future<void> _syncWithSystemVolume() async {
    final systemVolume = await VolumeController.instance.getVolume();
    setState(() => _localVolume = systemVolume);
    widget.audioManager.setVolume(systemVolume);
  }

  /// Retorna el icono apropiado según el nivel de volumen.
  IconData _getVolumeIcon(double volume) {
    if (volume == 0) return Icons.volume_off;
    if (volume < 0.5) return Icons.volume_down;
    return Icons.volume_up;
  }

  /// Alterna la visibilidad del slider de volumen.
  void _toggleVolumeSlider() {
    setState(() {
      _showVolumeSlider = !_showVolumeSlider;
    });
  }

  /// Maneja los cambios en el slider y actualiza el volumen.
  void _handleVolumeChange(double value) {
    // 1. Actualiza el estado local para el redibujado instantáneo del slider.
    setState(() {
      _localVolume = value;
    });
    // 2. Notifica al AudioPlayerManager del cambio.
    widget.audioManager.setVolume(value);
  }

  @override
  Widget build(BuildContext context) {
    final responsive = ResponsiveHelper(context);

    // Definición de propiedades responsivas
    final horizontalPadding = responsive.getValue(
      smallPhone: 20.0,
      phone: 24.0,
      largePhone: 32.0,
      tablet: 60.0,
      desktop: 80.0,
      automotive: 40.0,
    );
    final buttonPadding = responsive.getValue(
      smallPhone: 10.0,
      phone: 12.0,
      largePhone: 14.0,
      tablet: 16.0,
      desktop: 18.0,
      automotive: 14.0,
    );
    final buttonRadius = responsive.getValue(
      smallPhone: 10.0,
      phone: 12.0,
      largePhone: 14.0,
      tablet: 16.0,
      desktop: 18.0,
      automotive: 14.0,
    );
    final iconSize = responsive.getValue(
      smallPhone: 22.0,
      phone: 24.0,
      largePhone: 26.0,
      tablet: 28.0,
      desktop: 32.0,
      automotive: 26.0,
    );
    final fontSize = responsive.getValue(
      smallPhone: 14.0,
      phone: 16.0,
      largePhone: 17.0,
      tablet: 18.0,
      desktop: 20.0,
      automotive: 17.0,
    );
    final sliderPadding = responsive.getValue(
      smallPhone: 14.0,
      phone: 16.0,
      largePhone: 18.0,
      tablet: 20.0,
      desktop: 24.0,
      automotive: 18.0,
    );
    final sliderRadius = responsive.getValue(
      smallPhone: 10.0,
      phone: 12.0,
      largePhone: 14.0,
      tablet: 16.0,
      desktop: 18.0,
      automotive: 14.0,
    );
    final spacing = responsive.getValue(
      smallPhone: 14.0,
      phone: 16.0,
      largePhone: 18.0,
      tablet: 20.0,
      desktop: 24.0,
      automotive: 18.0,
    );
    final trackHeight = responsive.getValue(
      smallPhone: 3.5,
      phone: 4.0,
      largePhone: 5.0,
      tablet: 6.0,
      desktop: 7.0,
      automotive: 5.0,
    );
    final thumbRadius = responsive.getValue(
      smallPhone: 10.0,
      phone: 12.0,
      largePhone: 13.0,
      tablet: 14.0,
      desktop: 16.0,
      automotive: 13.0,
    );
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
    final sliderIconSize = responsive.getValue(
      smallPhone: 13.0,
      phone: 14.0,
      largePhone: 15.0,
      tablet: 16.0,
      desktop: 18.0,
      automotive: 15.0,
    );
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
    final sliderVerticalPadding = responsive.getValue(
      smallPhone: 6.0,
      phone: 8.0,
      largePhone: 10.0,
      tablet: 12.0,
      desktop: 14.0,
      automotive: 10.0,
    );
    final sliderInnerSpacing = responsive.getValue(
      smallPhone: 3.0,
      phone: 4.0,
      largePhone: 6.0,
      tablet: 8.0,
      desktop: 10.0,
      automotive: 6.0,
    );
    final divisions = responsive.getValue(
      smallPhone: 10,
      phone: 10,
      largePhone: 15,
      tablet: 20,
      desktop: 20,
      automotive: 15,
    );
    // Fin de propiedades responsivas

    return Container(
      padding: EdgeInsets.symmetric(horizontal: horizontalPadding),
      child: Column(
        children: [
          // Fila con botón de volumen y porcentaje
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              // Botón de volumen (alterna _showVolumeSlider)
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
                    // Borde resaltado cuando el slider está visible (indicador visual)
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

              // Indicador de porcentaje de volumen (siempre visible)
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

          // Transición condicional para el Slider expandible
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
                      // Divisiones para valores discretos (ej. 10%, 20%, etc.)
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
