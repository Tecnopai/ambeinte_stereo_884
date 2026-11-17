import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:radio_player/radio_player.dart';

import 'audio_player_manager.dart';
import 'diagnostics_log.dart';
import 'podcast_player.dart';

/// Apagado programado ("sleep"): apaga la radio o el podcast después de un
/// tiempo. En los últimos [fade] baja el volumen poco a poco para no cortar de
/// golpe a quien se está quedando dormido, y al terminar devuelve el volumen
/// al 100 % para la próxima vez que se dé play.
///
/// Sigue corriendo con la pantalla apagada (la app se mantiene viva mientras
/// suena el audio). Si el usuario pausa todo a mano, se cancela solo.
class SleepTimer {
  SleepTimer._();
  static final SleepTimer instance = SleepTimer._();

  /// Opciones rápidas, en minutos.
  static const List<int> presets = [15, 30, 45, 60, 90];

  /// Límites de "Personalizado", en minutos.
  static const int minMinutes = 5;
  static const int maxMinutes = 240;

  static const Duration fade = Duration(seconds: 30);

  /// Tiempo que falta, o null si no hay apagado programado.
  final ValueNotifier<Duration?> remaining = ValueNotifier(null);

  Timer? _ticker;
  DateTime? _endsAt;
  bool _volumeLowered = false;

  bool get active => remaining.value != null;

  void start(Duration duration) {
    _stopTicker();
    _restoreVolume();
    _endsAt = DateTime.now().add(duration);
    remaining.value = duration;
    _ticker = Timer.periodic(const Duration(seconds: 1), (_) => _tick());
    DiagnosticsLog.instance.add(
      'Apagado programado en ${duration.inMinutes} min',
    );
  }

  void cancel() {
    if (!active) return;
    _stopTicker();
    _restoreVolume();
    remaining.value = null;
    DiagnosticsLog.instance.add('Apagado programado cancelado');
  }

  void _stopTicker() {
    _ticker?.cancel();
    _ticker = null;
  }

  bool get _somethingWanted =>
      AudioPlayerManager().wantsPlayback || PodcastPlayer.instance.playing;

  void _tick() {
    final endsAt = _endsAt;
    if (endsAt == null) return;

    // El usuario pausó todo a mano: ya no hace falta apagar nada.
    if (!_somethingWanted) {
      cancel();
      return;
    }

    final left = endsAt.difference(DateTime.now());
    if (left <= Duration.zero) {
      _finish();
      return;
    }
    remaining.value = left;

    if (left <= fade) {
      final volume = left.inMilliseconds / fade.inMilliseconds;
      _setVolume(volume.clamp(0.0, 1.0));
    }
  }

  Future<void> _finish() async {
    _stopTicker();
    remaining.value = null;
    DiagnosticsLog.instance.add('Apagado programado: se apaga el audio');
    final radio = AudioPlayerManager();
    if (radio.wantsPlayback) await radio.pause();
    if (PodcastPlayer.instance.playing) await PodcastPlayer.instance.pause();
    // Ya en pausa: el volumen vuelve al 100 % para la próxima vez.
    await Future<void>.delayed(const Duration(milliseconds: 600));
    _restoreVolume();
  }

  void _setVolume(double volume) {
    _volumeLowered = true;
    RadioPlayer.setVolume(volume).catchError((_) {});
    PodcastPlayer.instance.setVolume(volume).catchError((_) {});
  }

  void _restoreVolume() {
    if (!_volumeLowered) return;
    _volumeLowered = false;
    RadioPlayer.setVolume(1).catchError((_) {});
    PodcastPlayer.instance.setVolume(1).catchError((_) {});
  }
}
