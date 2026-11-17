import 'dart:async';

import 'package:flutter/material.dart';
import 'package:volume_controller/volume_controller.dart';
import '../core/theme/app_colors.dart';
import '../services/audio_player_manager.dart';

/// Control de volumen siempre visible: parlante, barra y porcentaje.
///
/// Mueve el volumen del teléfono (el mismo de los botones físicos) y se
/// actualiza solo si se usan esos botones. Tocar el parlante silencia y
/// vuelve a tocarlo devuelve el volumen anterior.
class VolumeControl extends StatefulWidget {
  /// Se mantiene para avisar el volumen a la app (lo usa el mini reproductor).
  final AudioPlayerManager audioManager;

  const VolumeControl({super.key, required this.audioManager});

  @override
  State<VolumeControl> createState() => _VolumeControlState();
}

class _VolumeControlState extends State<VolumeControl> {
  double _volume = 0.7;

  /// Volumen antes de silenciar, para recuperarlo.
  double? _beforeMute;

  StreamSubscription<double>? _volumeSub;

  @override
  void dispose() {
    _volumeSub?.cancel();
    super.dispose();
  }

  @override
  void initState() {
    super.initState();
    // Al mover la barra no se muestra además la ventana de volumen del
    // sistema (la barra ya dice cuánto es).
    VolumeController.instance.showSystemUI = false;
    _volume = widget.audioManager.volume;
    VolumeController.instance.getVolume().then((v) {
      if (mounted) setState(() => _volume = v);
      widget.audioManager.setVolume(v);
    });
    // Botones físicos del teléfono: el sistema avisa a un solo escuchador (el
    // mini reproductor de otras pantallas también se registra), y ambos pasan
    // el valor a la app. La barra sigue ese aviso central.
    _volumeSub = widget.audioManager.volumeStream.listen((v) {
      if (mounted && v != _volume) setState(() => _volume = v);
    });
    VolumeController.instance.addListener(widget.audioManager.setVolume);
    // En iOS, addListener cambia la sesión a `.mixWithOthers`; se restaura.
    Future.delayed(
      const Duration(milliseconds: 500),
      widget.audioManager.restoreExclusiveAudioSession,
    );
  }

  Future<void> _setVolume(double v) async {
    setState(() => _volume = v);
    widget.audioManager.setVolume(v);
    await VolumeController.instance.setVolume(v);
  }

  void _toggleMute() {
    if (_volume > 0) {
      _beforeMute = _volume;
      _setVolume(0);
    } else {
      _setVolume(_beforeMute ?? 0.5);
      _beforeMute = null;
    }
  }

  IconData get _icon {
    if (_volume == 0) return Icons.volume_off;
    if (_volume < 0.5) return Icons.volume_down;
    return Icons.volume_up;
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: AppColors.surface.withValues(alpha: 0.6),
        borderRadius: BorderRadius.circular(28),
      ),
      child: Row(
        children: [
          IconButton(
            tooltip: _volume == 0 ? 'Quitar silencio' : 'Silenciar',
            onPressed: _toggleMute,
            icon: Icon(_icon, color: AppColors.primary),
          ),
          Expanded(
            child: SliderTheme(
              data: SliderThemeData(
                activeTrackColor: AppColors.primary,
                inactiveTrackColor: AppColors.textSecondary.withValues(
                  alpha: 0.25,
                ),
                thumbColor: AppColors.primary,
                overlayColor: AppColors.primary.withValues(alpha: 0.2),
                trackHeight: 4,
              ),
              child: Slider(
                value: _volume.clamp(0.0, 1.0),
                min: 0,
                max: 1,
                onChanged: _setVolume,
              ),
            ),
          ),
          SizedBox(
            width: 48,
            child: Text(
              '${(_volume * 100).round()}%',
              textAlign: TextAlign.right,
              style: const TextStyle(
                color: AppColors.textMuted,
                fontSize: 14,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
          const SizedBox(width: 8),
        ],
      ),
    );
  }
}
