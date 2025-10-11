import 'package:flutter/material.dart';
import '../core/theme/app_colors.dart';
import '../services/audio_player_manager.dart';

class VolumeControl extends StatefulWidget {
  final AudioPlayerManager audioManager;

  const VolumeControl({super.key, required this.audioManager});

  @override
  State<VolumeControl> createState() => _VolumeControlState();
}

class _VolumeControlState extends State<VolumeControl>
    with SingleTickerProviderStateMixin {
  bool _showVolumeSlider = false;
  late AnimationController _slideController;
  late Animation<double> _slideAnimation;

  @override
  void initState() {
    super.initState();
    _slideController = AnimationController(
      duration: const Duration(milliseconds: 300),
      vsync: this,
    );
    _slideAnimation = CurvedAnimation(
      parent: _slideController,
      curve: Curves.easeInOut,
    );
  }

  @override
  void dispose() {
    _slideController.dispose();
    super.dispose();
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

    if (_showVolumeSlider) {
      _slideController.forward();
    } else {
      _slideController.reverse();
    }
  }

  @override
  Widget build(BuildContext context) {
    // Obtener información del dispositivo
    final screenSize = MediaQuery.of(context).size;
    final isTablet = screenSize.shortestSide >= 600;
    final screenWidth = screenSize.width;
    final textScale = MediaQuery.of(context).textScaler.scale(1.0);

    // Calcular tamaños dinámicos
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

    // Límites para padding horizontal
    final clampedHorizontalPadding = horizontalPadding.clamp(20.0, 80.0);

    // ✅ StreamBuilder para escuchar cambios de volumen
    return StreamBuilder<double>(
      stream: widget.audioManager.volumeStream,
      initialData: widget.audioManager.volume,
      builder: (context, snapshot) {
        final currentVolume = snapshot.data ?? widget.audioManager.volume;

        return Container(
          padding: EdgeInsets.symmetric(horizontal: clampedHorizontalPadding),
          child: Column(
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  // Botón de volumen con animación
                  AnimatedContainer(
                    duration: const Duration(milliseconds: 200),
                    child: GestureDetector(
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
                                  color: AppColors.primary.withValues(
                                    alpha: 0.3,
                                  ),
                                  width: 2,
                                )
                              : null,
                        ),
                        child: Icon(
                          _getVolumeIcon(currentVolume),
                          color: _showVolumeSlider
                              ? AppColors.primary
                              : AppColors.primary.withValues(alpha: 0.8),
                          size: iconSize,
                        ),
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
                      '${(currentVolume * 100).round()}%',
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
              AnimatedSize(
                duration: const Duration(milliseconds: 300),
                curve: Curves.easeInOut,
                child: _showVolumeSlider
                    ? Column(
                        children: [
                          SizedBox(height: spacing),
                          SlideTransition(
                            position: Tween<Offset>(
                              begin: const Offset(0, -0.5),
                              end: Offset.zero,
                            ).animate(_slideAnimation),
                            child: FadeTransition(
                              opacity: _slideAnimation,
                              child: Container(
                                decoration: BoxDecoration(
                                  color: AppColors.surface,
                                  borderRadius: BorderRadius.circular(
                                    sliderRadius,
                                  ),
                                  boxShadow: [
                                    BoxShadow(
                                      color: Colors.black.withValues(
                                        alpha: 0.1,
                                      ),
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
                                      mainAxisAlignment:
                                          MainAxisAlignment.spaceBetween,
                                      children: [
                                        Icon(
                                          Icons.volume_mute,
                                          color: AppColors.textSecondary,
                                          size: isTablet ? 18 : 16,
                                        ),
                                        Icon(
                                          Icons.volume_up,
                                          color: AppColors.textSecondary,
                                          size: isTablet ? 18 : 16,
                                        ),
                                      ],
                                    ),

                                    SizedBox(height: isTablet ? 8 : 4),

                                    // Slider personalizado
                                    SliderTheme(
                                      data: SliderThemeData(
                                        activeTrackColor: AppColors.primary,
                                        inactiveTrackColor: const Color(
                                          0xFF374151,
                                        ),
                                        thumbColor: AppColors.primary,
                                        overlayColor: AppColors.primary
                                            .withValues(alpha: 0.2),
                                        trackHeight: trackHeight,
                                        thumbShape: RoundSliderThumbShape(
                                          enabledThumbRadius: thumbRadius,
                                          elevation: 2,
                                        ),
                                        overlayShape: RoundSliderOverlayShape(
                                          overlayRadius: thumbRadius * 1.5,
                                        ),
                                        tickMarkShape:
                                            const RoundSliderTickMarkShape(
                                              tickMarkRadius: 2,
                                            ),
                                        activeTickMarkColor: AppColors.primary
                                            .withValues(alpha: 0.7),
                                        inactiveTickMarkColor: const Color(
                                          0xFF374151,
                                        ),
                                      ),
                                      child: Slider(
                                        value: currentVolume,
                                        onChanged: (value) {
                                          widget.audioManager.setVolume(value);
                                        },
                                        min: 0.0,
                                        max: 1.0,
                                        divisions: isTablet ? 20 : 10,
                                        label:
                                            '${(currentVolume * 100).round()}%',
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ),
                        ],
                      )
                    : const SizedBox.shrink(),
              ),
            ],
          ),
        );
      },
    );
  }
}
