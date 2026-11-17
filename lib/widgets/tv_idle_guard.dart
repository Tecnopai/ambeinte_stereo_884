import 'dart:async';
import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../core/theme/app_colors.dart';
import '../services/audio_player_manager.dart';
import '../services/podcast_player.dart';
import '../utils/tv.dart';

/// Televisor: mientras suena la radio o un podcast, el televisor no pone su
/// protector de pantalla ni se apaga (eso cortaba el audio). Para no dejar
/// una imagen fija por horas, si nadie toca el control en [_idleTime] se
/// muestra un modo de reposo propio: fondo oscuro con el logo y lo que suena,
/// moviéndose despacio. Cualquier botón vuelve a la pantalla normal.
///
/// En pausa no se pide nada: el televisor usa su protector y apagado normal.
class TvIdleGuard extends StatefulWidget {
  final Widget child;

  const TvIdleGuard({super.key, required this.child});

  @override
  State<TvIdleGuard> createState() => _TvIdleGuardState();
}

class _TvIdleGuardState extends State<TvIdleGuard> {
  static const Duration _idleTime = Duration(minutes: 2);

  final _audio = AudioPlayerManager();
  StreamSubscription<bool>? _playingSub;
  StreamSubscription<Map<String, String>>? _metadataSub;
  Timer? _ticker;

  DateTime _lastInput = DateTime.now();
  bool _playing = false;
  bool _resting = false;
  Map<String, String> _metadata = const {};

  @override
  void initState() {
    super.initState();
    HardwareKeyboard.instance.addHandler(_onKey);
    _playingSub = _audio.playingStream.listen((_) => _check());
    _metadataSub = _audio.metadataStream.listen((m) {
      if (mounted) setState(() => _metadata = m);
    });
    // Los podcasts no tienen un aviso de "sonando" aquí: se revisa seguido.
    _ticker = Timer.periodic(const Duration(seconds: 5), (_) => _check());
  }

  @override
  void dispose() {
    HardwareKeyboard.instance.removeHandler(_onKey);
    _playingSub?.cancel();
    _metadataSub?.cancel();
    _ticker?.cancel();
    Tv.keepScreenOn(false);
    super.dispose();
  }

  bool get _somethingPlaying =>
      _audio.isPlaying || PodcastPlayer.instance.playing;

  void _check() {
    if (!mounted) return;
    final playing = _somethingPlaying;
    if (playing != _playing) {
      _playing = playing;
      Tv.keepScreenOn(playing);
      // Al empezar a sonar se cuenta el tiempo desde ahí.
      if (playing) _lastInput = DateTime.now();
    }
    final idle = DateTime.now().difference(_lastInput) >= _idleTime;
    final rest = playing && idle;
    if (rest != _resting) setState(() => _resting = rest);
  }

  /// Cualquier botón cuenta como actividad. En reposo, el botón solo
  /// despierta la pantalla (no hace nada más).
  bool _onKey(KeyEvent event) {
    if (event is! KeyDownEvent) return _resting;
    _lastInput = DateTime.now();
    if (_resting) {
      setState(() => _resting = false);
      return true;
    }
    return false;
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        widget.child,
        if (_resting)
          Positioned.fill(
            child: _RestScreen(
              song: _songText(),
              podcast: PodcastPlayer.instance.playing
                  ? PodcastPlayer.instance.current.value?.title
                  : null,
            ),
          ),
      ],
    );
  }

  String _songText() {
    final artist = _metadata['artist'] ?? '';
    final title = _metadata['title'] ?? '';
    if (title.isEmpty) return '';
    return artist.isEmpty || artist == 'Desconocido'
        ? title
        : '$artist — $title';
  }
}

/// Pantalla de reposo: fondo negro y el contenido cambiando de lugar cada
/// cierto tiempo, para no marcar la pantalla del televisor.
class _RestScreen extends StatefulWidget {
  final String song;
  final String? podcast;

  const _RestScreen({required this.song, this.podcast});

  @override
  State<_RestScreen> createState() => _RestScreenState();
}

class _RestScreenState extends State<_RestScreen> {
  final _random = Random();
  Alignment _alignment = Alignment.center;
  Timer? _mover;

  @override
  void initState() {
    super.initState();
    _mover = Timer.periodic(const Duration(seconds: 20), (_) {
      if (!mounted) return;
      setState(() {
        _alignment = Alignment(
          _random.nextDouble() * 1.4 - 0.7,
          _random.nextDouble() * 1.4 - 0.7,
        );
      });
    });
  }

  @override
  void dispose() {
    _mover?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final podcast = widget.podcast;
    final line = podcast != null && podcast.isNotEmpty ? podcast : widget.song;
    // Material: da el estilo de texto de la app (sin él, Flutter subraya el
    // texto en amarillo, porque esta capa está encima del Scaffold).
    return Material(
      color: Colors.black,
      child: AnimatedAlign(
        alignment: _alignment,
        duration: const Duration(seconds: 6),
        curve: Curves.easeInOut,
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Opacity(
                opacity: 0.85,
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(20),
                  child: Image.asset(
                    'assets/images/icon.png',
                    width: 96,
                    height: 96,
                  ),
                ),
              ),
              const SizedBox(width: 24),
              ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 420),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      podcast != null ? 'PODCAST' : 'EN VIVO',
                      style: const TextStyle(
                        color: AppColors.primary,
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                        letterSpacing: 1.5,
                      ),
                    ),
                    const SizedBox(height: 6),
                    const Text(
                      'Ambiente Stereo 88.4 FM',
                      style: TextStyle(
                        color: Color(0xCCFFFFFF),
                        fontSize: 26,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    if (line.isNotEmpty) ...[
                      const SizedBox(height: 6),
                      Text(
                        line,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          color: Color(0x99FFFFFF),
                          fontSize: 17,
                          fontStyle: FontStyle.italic,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
