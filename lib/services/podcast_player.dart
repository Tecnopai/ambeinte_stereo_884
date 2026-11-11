import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:just_audio/just_audio.dart';
import 'package:path_provider/path_provider.dart';

import '../models/podcast.dart';
import 'audio_player_manager.dart';

/// Progreso guardado de un episodio.
class EpisodeProgress {
  final Duration position;
  final Duration? duration;
  final bool finished;

  const EpisodeProgress({
    required this.position,
    this.duration,
    this.finished = false,
  });

  /// Fracción escuchada (0–1), si se conoce la duración.
  double? get fraction {
    final total = duration?.inMilliseconds ?? 0;
    if (finished) return 1;
    if (total <= 0) return null;
    return (position.inMilliseconds / total).clamp(0.0, 1.0);
  }
}

/// Reproductor de episodios de podcast.
///
/// Es independiente del reproductor de la radio y del audio de los artículos:
/// usa su propia instancia de just_audio. Para que nunca suenen dos audios a
/// la vez:
///   - al reproducir un episodio se pausa la radio;
///   - si la radio empieza a sonar, se pausa el episodio;
///   - el audio de un artículo llama a [pauseIfPlaying].
///
/// El minuto en que va cada episodio se guarda SOLO en el teléfono
/// (archivo `podcast_progreso.json`), nunca se envía a ningún servidor.
class PodcastPlayer {
  PodcastPlayer._();
  static PodcastPlayer? _instance;
  static PodcastPlayer get instance => _instance ??= PodcastPlayer._();

  /// Pausa el episodio si hay uno sonando, sin crear el reproductor.
  static Future<void> pauseIfPlaying() async {
    final player = _instance?._player;
    if (player != null && player.playing) await _instance!.pause();
  }

  static const _finishedMargin = Duration(seconds: 30);
  static const _maxStored = 200;

  AudioPlayer? _player;
  StreamSubscription<bool>? _radioSubscription;
  Timer? _saveTimer;

  /// Episodio cargado en el reproductor (null = ninguno).
  final ValueNotifier<PodcastEpisode?> current = ValueNotifier(null);

  /// Progreso por episodio; se notifica al guardar para refrescar listas.
  final ValueNotifier<Map<String, EpisodeProgress>> progress = ValueNotifier(
    const {},
  );

  /// Último episodio escuchado (para "Continuar escuchando").
  final ValueNotifier<PodcastEpisode?> lastEpisode = ValueNotifier(null);

  bool _loaded = false;
  File? _file;

  AudioPlayer get _p => _player ??= _createPlayer();

  AudioPlayer _createPlayer() {
    final player = AudioPlayer();
    player.playerStateStream.listen((state) {
      if (state.processingState == ProcessingState.completed) {
        _markFinished();
      }
      if (!state.playing) _saveNow();
    });
    _radioSubscription ??= AudioPlayerManager().playingStream.listen((radio) {
      if (radio && (_player?.playing ?? false)) pause();
    });
    return player;
  }

  Stream<PlayerState> get playerStateStream => _p.playerStateStream;
  Stream<Duration> get positionStream => _p.positionStream;
  Stream<Duration?> get durationStream => _p.durationStream;
  Stream<double> get speedStream => _p.speedStream;
  Stream<Duration> get bufferedPositionStream => _p.bufferedPositionStream;
  bool get playing => _player?.playing ?? false;
  Duration get position => _player?.position ?? Duration.zero;
  Duration? get duration => _player?.duration;
  double get speed => _player?.speed ?? 1.0;

  /// Carga el progreso guardado. Se llama al abrir la pestaña de podcasts.
  Future<void> init() async {
    if (_loaded) return;
    _loaded = true;
    try {
      final dir = await getApplicationSupportDirectory();
      _file = File('${dir.path}/podcast_progreso.json');
      if (!await _file!.exists()) return;
      final data = jsonDecode(await _file!.readAsString());
      if (data is! Map) return;
      final episodes = data['episodios'];
      if (episodes is Map) {
        final map = <String, EpisodeProgress>{};
        episodes.forEach((key, value) {
          if (key is String && value is Map) {
            final pos = value['pos'], dur = value['dur'];
            map[key] = EpisodeProgress(
              position: Duration(seconds: pos is int ? pos : 0),
              duration: dur is int ? Duration(seconds: dur) : null,
              finished: value['fin'] == true,
            );
          }
        });
        progress.value = map;
      }
      lastEpisode.value = PodcastEpisode.fromJson(data['ultimo']);
    } catch (_) {
      // Archivo dañado: se empieza de cero.
    }
  }

  /// Reproduce [episode]. Si ya está cargado, solo continúa.
  Future<void> play(PodcastEpisode episode) async {
    await init();
    final radio = AudioPlayerManager();
    if (radio.isPlaying || radio.isLoading) await radio.pause();

    if (current.value?.id == episode.id && _player?.audioSource != null) {
      if (_p.processingState == ProcessingState.completed) {
        await _p.seek(Duration.zero);
      }
      unawaited(_p.play());
      return;
    }

    await _saveNow();
    current.value = episode;
    lastEpisode.value = episode;

    final saved = progress.value[episode.id];
    final start = (saved == null || saved.finished)
        ? Duration.zero
        : saved.position;

    try {
      await _p.setAudioSource(
        AudioSource.uri(Uri.parse(episode.audioUrl)),
        initialPosition: start,
      );
      unawaited(_p.play());
      _startSaveTimer();
    } catch (e) {
      current.value = null;
      rethrow;
    }
  }

  Future<void> pause() async {
    await _player?.pause();
    await _saveNow();
  }

  Future<void> togglePlayPause() async {
    final episode = current.value;
    if (episode == null) return;
    if (playing) {
      await pause();
    } else {
      await play(episode);
    }
  }

  Future<void> seek(Duration position) async => _player?.seek(position);

  Future<void> seekBy(Duration offset) async {
    final player = _player;
    if (player == null) return;
    var target = player.position + offset;
    final total = player.duration;
    if (target < Duration.zero) target = Duration.zero;
    if (total != null && target > total) target = total;
    await player.seek(target);
  }

  Future<void> setSpeed(double speed) async => _player?.setSpeed(speed);

  /// Detiene y descarga el episodio (botón cerrar del mini reproductor).
  Future<void> stop() async {
    await _saveNow();
    _saveTimer?.cancel();
    await _player?.stop();
    current.value = null;
  }

  void _startSaveTimer() {
    _saveTimer?.cancel();
    _saveTimer = Timer.periodic(const Duration(seconds: 15), (_) {
      if (playing) _saveNow();
    });
  }

  void _markFinished() {
    final episode = current.value;
    if (episode == null) return;
    _update(
      episode.id,
      EpisodeProgress(
        position: Duration.zero,
        duration: _player?.duration ?? episode.duration,
        finished: true,
      ),
    );
    _persist();
  }

  Future<void> _saveNow() async {
    final episode = current.value;
    final player = _player;
    if (episode == null || player == null) return;
    final pos = player.position;
    final total = player.duration ?? episode.duration;
    if (pos < const Duration(seconds: 5)) return;
    final finished = total != null && total - pos <= _finishedMargin;
    _update(
      episode.id,
      EpisodeProgress(
        position: finished ? Duration.zero : pos,
        duration: total,
        finished: finished || (progress.value[episode.id]?.finished ?? false),
      ),
    );
    await _persist();
  }

  void _update(String id, EpisodeProgress value) {
    final map = Map<String, EpisodeProgress>.of(progress.value);
    map.remove(id);
    map[id] = value; // al final = más reciente
    while (map.length > _maxStored) {
      map.remove(map.keys.first);
    }
    progress.value = map;
  }

  Future<void> _persist() async {
    final file = _file;
    if (file == null) return;
    try {
      final data = {
        'episodios': progress.value.map(
          (id, p) => MapEntry(id, {
            'pos': p.position.inSeconds,
            if (p.duration != null) 'dur': p.duration!.inSeconds,
            if (p.finished) 'fin': true,
          }),
        ),
        'ultimo': lastEpisode.value?.toJson(),
      };
      await file.writeAsString(jsonEncode(data), flush: true);
    } catch (_) {
      // Si no se puede guardar, solo se pierde el punto de reanudación.
    }
  }
}
