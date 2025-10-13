import 'package:flutter/material.dart';
import '../core/theme/app_colors.dart';
import '../services/audio_player_manager.dart';

class VolumeControl extends StatefulWidget {
  final AudioPlayerManager audioManager;

  const VolumeControl({super.key, required this.audioManager});

  @override
  State<VolumeControl> createState() => _VolumeControlState();
}

class _VolumeControlState extends State<VolumeControl> {
  bool _showVolumeSlider = false;
  double _localVolume = 0.7;

  @override
  void initState() {
    super.initState();
    // Inicializar con el volumen actual del manager
    _localVolume = widget.audioManager.volume;

    // Escuchar cambios del stream
    widget.audioManager.volumeStream.listen((volume) {
      if (mounted) {
        setState(() {
          _localVolume = volume;
        });
      }
    });
  }

  IconData _getVolumeIcon(double volume) {
    if (volume == 0) return Icons.volume_off;
    if (volume < 0.5) return Icons.volume_down;
    return Icons.volume_up;
  }

  void _toggleVolumeSlider() {
    setState(() {
      _showVolumeSlider = !_showVolumeSlider;
    });
  }

  void _handleVolumeChange(double value) {
    setState(() {
      _localVolume = value;
    });
    widget.audioManager.setVolume(value);
  }

  @override
  Widget build(BuildContext context) {
    final screenSize = MediaQuery.of(context).size;
    final isTablet = screenSize.shortestSide >= 600;
    final screenWidth = screenSize.width;
    final textScale = MediaQuery.of(context).textScaler.scale(1.0);

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

    final clampedHorizontalPadding = horizontalPadding.clamp(20.0, 80.0);

    return Container(
      padding: EdgeInsets.symmetric(horizontal: clampedHorizontalPadding),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              // Botón de volumen
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

              // Porcentaje de volumen
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

          // Slider animado
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
                  // Etiquetas de volumen
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

                  // Slider
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
