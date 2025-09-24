import 'package:flutter/material.dart';
import '../services/audio_player_manager.dart';
import '../core/theme/app_colors.dart';

class VolumeControl extends StatefulWidget {
  final double volume;
  final AudioPlayerManager audioManager;

  const VolumeControl({
    super.key,
    required this.volume,
    required this.audioManager,
  });

  @override
  State<VolumeControl> createState() => _VolumeControlState();
}

class _VolumeControlState extends State<VolumeControl> {
  bool _showVolumeSlider = false;

  IconData _getVolumeIcon() {
    if (widget.volume == 0) return Icons.volume_off;
    if (widget.volume < 0.5) return Icons.volume_down;
    return Icons.volume_up;
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 40),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              GestureDetector(
                onTap: () {
                  setState(() {
                    _showVolumeSlider = !_showVolumeSlider;
                  });
                },
                child: Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: AppColors.surface,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(
                    _getVolumeIcon(),
                    color: AppColors.primary,
                    size: 24,
                  ),
                ),
              ),
              Text(
                '${(widget.volume * 100).round()}%',
                style: const TextStyle(
                  color: AppColors.textMuted,
                  fontSize: 16,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
          if (_showVolumeSlider) ...[
            const SizedBox(height: 16),
            Container(
              decoration: BoxDecoration(
                color: AppColors.surface,
                borderRadius: BorderRadius.circular(12),
              ),
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: SliderTheme(
                data: SliderThemeData(
                  activeTrackColor: AppColors.primary,
                  inactiveTrackColor: const Color(0xFF374151),
                  thumbColor: AppColors.primary,
                  overlayColor: AppColors.primary.withOpacity(0.2),
                  trackHeight: 4,
                ),
                child: Slider(
                  value: widget.volume,
                  onChanged: (value) {
                    widget.audioManager.setVolume(value);
                  },
                  min: 0.0,
                  max: 1.0,
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}
