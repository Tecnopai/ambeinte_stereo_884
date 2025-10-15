import 'package:flutter/material.dart';
import '../core/theme/app_colors.dart';
import '../services/audio_player_manager.dart';

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
    // Inicializar con el volumen actual del manager
    _localVolume = widget.audioManager.volume;

    // Escuchar cambios del stream de volumen
    widget.audioManager.volumeStream.listen((volume) {
      if (mounted) {
        setState(() {
          _localVolume = volume;
        });
      }
    });
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
    // Obtener información del dispositivo para diseño responsivo
    final screenSize = MediaQuery.of(context).size;
    final isTablet = screenSize.shortestSide >= 600;
    final screenWidth = screenSize.width;
    final textScale = MediaQuery.of(context).textScaler.scale(1.0);

    // Calcular tamaños dinámicos según el dispositivo
    final horizontalPadding = isTablet ? 60.0 : (screenWidth * 0.1);
    final buttonPadding = isTablet ? 16.0 : 12.0;
    final buttonRadius = isTablet ? 16.0 : 12.0;
    final iconSize = (isTablet ? 28.0 : 24.0) * textScale;
    final fontSize = (isTablet ? 18.0 : 16.0) * textScale;
    final sliderPadding = isTablet ? 20.0 : 16.0;
    final sliderRadius = isTablet ? 16.0 : 12.0;
    final spacing = isTablet ? 20.0 : 16.0;
    final trackHeight = isTablet ? 6.0 : 4.0;
    final thumbRadius = isTablet ? 14.0 : 12.0;

    // Aplicar límites al padding horizontal
    final clampedHorizontalPadding = horizontalPadding.clamp(20.0, 80.0);

    return Container(
      padding: EdgeInsets.symmetric(horizontal: clampedHorizontalPadding),
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
                        blurRadius: isTablet ? 8 : 6,
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
                  horizontal: isTablet ? 12 : 8,
                  vertical: isTablet ? 8 : 6,
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
                    blurRadius: isTablet ? 12 : 8,
                    spreadRadius: 1,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              padding: EdgeInsets.symmetric(
                horizontal: sliderPadding,
                vertical: isTablet ? 12 : 8,
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
                        size: isTablet ? 16 : 14,
                      ),
                      Icon(
                        Icons.volume_up,
                        color: AppColors.textSecondary,
                        size: isTablet ? 16 : 14,
                      ),
                    ],
                  ),

                  SizedBox(height: isTablet ? 8 : 4),

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
                      divisions: isTablet ? 20 : 10,
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
