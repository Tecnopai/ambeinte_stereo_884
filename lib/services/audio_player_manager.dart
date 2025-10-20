import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:just_audio/just_audio.dart';
import 'package:audio_session/audio_session.dart';
import 'package:volume_controller/volume_controller.dart';

/// Gestor global del reproductor de audio para streaming de radio
/// Implementa patrón Singleton para mantener una única instancia
/// Maneja reproducción, volumen, reconexión automática y estados
/// ✅ OPTIMIZADO PARA REPRODUCCIÓN EN SEGUNDO PLANO INDEFINIDA
class AudioPlayerManager {
  static final AudioPlayerManager _instance = AudioPlayerManager._internal();
  factory AudioPlayerManager() => _instance;
  AudioPlayerManager._internal();

  // Instancia del reproductor de audio
  AudioPlayer? _audioPlayer;
  AudioSession? _audioSession;

  // Estados del reproductor
  bool _isPlaying = false;
  bool _isLoading = false;
  bool _userStoppedManually = false;
  bool _isDisposed = false;
  double _volume = 0.7;

  // Configuración del stream
  static const String streamUrl = 'https://radio06.cehis.net:9036/stream';
  static const String radioName = 'Ambiente Stereo 88.4 FM';

  // Configuración de reconexión automática
  static const int _maxRetries = 3;
  static const Duration _minDelayBetweenAttempts = Duration(seconds: 2);

  int _retryCount = 0;
  int _consecutiveErrors = 0;
  DateTime? _lastAttemptTime;

  bool _isRestarting = false;
  StreamSubscription? _playerStateSubscription;
  StreamSubscription? _playbackEventSubscription;
  StreamSubscription? _interruptionSubscription;
  StreamSubscription? _becomingNoisySubscription;

  // Stream controllers para emitir cambios de estado
  final _playingController = StreamController<bool>.broadcast();
  final _loadingController = StreamController<bool>.broadcast();
  final _volumeStreamController = StreamController<double>.broadcast();
  final _errorController = StreamController<String>.broadcast();

  // Getters para los streams
  Stream<bool> get playingStream => _playingController.stream;
  Stream<bool> get loadingStream => _loadingController.stream;
  Stream<double> get volumeStream => _volumeStreamController.stream;
  Stream<String> get errorStream => _errorController.stream;

  // Getters para los estados actuales
  bool get isPlaying => _isPlaying;
  bool get isLoading => _isLoading;
  double get volume => _volume;

  /// Inicializa el gestor de audio y el controlador de volumen
  /// Inicia la reproducción si no fue detenida manualmente.
  Future<void> init() async {
    if (_isDisposed) return;

    try {
      await _initializeVolumeController();
      await _initializePlayer();

      // Auto-Play: Intenta reproducir solo si el usuario no detuvo
      if (!_userStoppedManually) {
        await play();
      }
    } catch (e) {
      if (kDebugMode) {
        print('[AudioPlayerManager] Error al inicializar: $e');
      }
      if (!_errorController.isClosed) {
        _errorController.add('Error al inicializar el reproductor.');
      }
    }
  }

  /// Inicializa el controlador de volumen del sistema
  Future<void> _initializeVolumeController() async {
    try {
      final systemVolume = await VolumeController.instance.getVolume();
      _volume = systemVolume;

      if (!_volumeStreamController.isClosed) {
        _volumeStreamController.add(_volume);
      }

      VolumeController.instance.showSystemUI = false;

      VolumeController.instance.addListener((newVolume) {
        if (_isDisposed) return;
        _volume = newVolume;
        if (!_volumeStreamController.isClosed) {
          _volumeStreamController.add(_volume);
        }
        _audioPlayer?.setVolume(_volume);
      });
    } catch (e) {
      if (kDebugMode) {
        print('[AudioPlayerManager] Error al inicializar VolumeController: $e');
      }
      _volume = 0.7;
      if (!_volumeStreamController.isClosed) {
        _volumeStreamController.add(_volume);
      }
    }
  }

  /// Inicializa el reproductor de audio con configuración optimizada
  /// ✅ OPTIMIZADO PARA SEGUNDO PLANO CON AUDIO SESSION
  Future<void> _initializePlayer() async {
    if (_isDisposed) return;

    try {
      // ✅ PASO 1: CONFIGURAR SESIÓN DE AUDIO PRIMERO
      _audioSession = await AudioSession.instance;
      await _audioSession!.configure(const AudioSessionConfiguration.music());

      // ✅ PASO 2: MANEJAR INTERRUPCIONES (llamadas, alarmas, etc.)
      _interruptionSubscription?.cancel();
      _interruptionSubscription = _audioSession!.interruptionEventStream.listen(
        (event) {
          if (_isDisposed) return;

          if (event.begin) {
            // Interrupción comenzó (llamada entrante, alarma, etc.)
            if (kDebugMode) {
              print(
                '[AudioPlayerManager] Interrupción detectada: ${event.type}',
              );
            }
            _audioPlayer?.pause();
          } else {
            // Interrupción terminó
            if (kDebugMode) {
              print('[AudioPlayerManager] Interrupción terminada');
            }
            // Solo reanudar si el usuario no detuvo manualmente
            if (!_userStoppedManually &&
                event.type == AudioInterruptionType.pause) {
              Future.delayed(const Duration(milliseconds: 500), () {
                if (!_userStoppedManually && !_isDisposed) {
                  _audioPlayer?.play();
                }
              });
            }
          }
        },
      );

      // ✅ PASO 3: MANEJAR DESCONEXIÓN DE AURICULARES
      _becomingNoisySubscription?.cancel();
      _becomingNoisySubscription = _audioSession!.becomingNoisyEventStream
          .listen((_) {
            if (_isDisposed) return;
            if (kDebugMode) {
              print('[AudioPlayerManager] Auriculares desconectados');
            }
            _audioPlayer?.pause();
          });

      // ✅ PASO 4: LIMPIAR Y CREAR NUEVO REPRODUCTOR
      _cleanupPlayer();
      _audioPlayer = AudioPlayer();

      // ✅ PASO 5: CONFIGURAR AUDIO SOURCE CON METADATA PARA NOTIFICACIÓN
      await _audioPlayer!.setAudioSource(
        AudioSource.uri(
          Uri.parse(streamUrl),
          tag: {
            'id': 'ambiente_stereo_live',
            'album': 'Radio en Vivo',
            'title': radioName,
            'artist': 'En vivo',
            // Opcional: agrega un logo/artwork si tienes una URL
            // 'artUri': 'https://tudominio.com/logo.png',
          },
        ),
        preload: true,
      );

      // ✅ PASO 6: CONFIGURACIONES PARA MANTENER REPRODUCCIÓN CONTINUA
      await _audioPlayer!.setLoopMode(LoopMode.off);
      await _audioPlayer!.setCanUseNetworkResourcesForLiveStreamingWhilePaused(
        true,
      );

      // ✅ PASO 7: ESCUCHAR CAMBIOS DE ESTADO DEL REPRODUCTOR
      _playerStateSubscription = _audioPlayer!.playerStateStream.listen(
        _handlePlayerStateChange,
        onError: _handlePlayerError,
        cancelOnError: false,
      );

      // ✅ PASO 8: ESCUCHAR EVENTOS DE PLAYBACK
      _playbackEventSubscription = _audioPlayer!.playbackEventStream.listen(
        null,
        onError: _handlePlayerError,
        cancelOnError: false,
      );

      // ✅ PASO 9: APLICAR VOLUMEN INICIAL
      await _audioPlayer!.setVolume(_volume);

      if (kDebugMode) {
        print(
          '[AudioPlayerManager] Player inicializado correctamente con AudioSession',
        );
      }
    } catch (e) {
      if (kDebugMode) {
        print('[AudioPlayerManager] Error al inicializar player: $e');
      }
      rethrow;
    }
  }

  /// Maneja cambios en el estado del reproductor
  /// ✅ OPTIMIZADO: Reconexión inmediata sin Timers
  void _handlePlayerStateChange(PlayerState state) {
    if (_isDisposed || _isRestarting) return;

    final wasPlaying = _isPlaying;
    final newIsPlaying = state.playing;
    final newIsLoading =
        state.processingState == ProcessingState.loading ||
        state.processingState == ProcessingState.buffering;

    _isPlaying = newIsPlaying;
    _isLoading = newIsLoading;

    if (kDebugMode) {
      print(
        '[AudioPlayerManager] Estado: playing=$newIsPlaying, processingState=${state.processingState}',
      );
    }

    // Si está reproduciendo correctamente, resetear contadores
    if (_isPlaying && state.processingState == ProcessingState.ready) {
      _retryCount = 0;
      _consecutiveErrors = 0;
      if (!_errorController.isClosed) {
        _errorController.add('');
      }
    }

    // ✅ DETECTAR DESCONEXIÓN INMEDIATAMENTE
    if (state.processingState == ProcessingState.idle &&
        !_userStoppedManually) {
      if (kDebugMode) {
        print(
          '[AudioPlayerManager] Stream desconectado, reconectando inmediatamente...',
        );
      }
      _consecutiveErrors++;
      _reconnectImmediately();
    }

    // Si se detuvo inesperadamente
    if (wasPlaying && !newIsPlaying && !_userStoppedManually) {
      if (state.processingState == ProcessingState.completed) {
        if (kDebugMode) {
          print('[AudioPlayerManager] Reproducción completada inesperadamente');
        }
        _consecutiveErrors++;
        _reconnectImmediately();
      }
    }

    // Emitir cambios de estado
    if (!_playingController.isClosed) {
      _playingController.add(_isPlaying);
    }
    if (!_loadingController.isClosed) {
      _loadingController.add(_isLoading);
    }
  }

  /// ✅ NUEVO: Reconexión inmediata sin Timers (funciona en segundo plano)
  Future<void> _reconnectImmediately() async {
    if (_isDisposed || _userStoppedManually || _isRestarting) return;

    _retryCount++;

    if (kDebugMode) {
      print('[AudioPlayerManager] Intento de reconexión #$_retryCount');
    }

    // Si hay demasiados errores, forzar reinicio completo
    if (_consecutiveErrors > 3 || _retryCount > _maxRetries) {
      if (kDebugMode) {
        print(
          '[AudioPlayerManager] Demasiados errores, forzando reinicio completo',
        );
      }
      await _forceRestart();
      return;
    }

    try {
      _isLoading = true;
      if (!_loadingController.isClosed) {
        _loadingController.add(_isLoading);
      }

      // Espera breve antes de reintentar (aumenta con cada reintento)
      await Future.delayed(Duration(seconds: 2 * _retryCount));

      if (_userStoppedManually || _isDisposed) return;

      await _audioPlayer?.stop();
      await Future.delayed(const Duration(milliseconds: 500));

      if (_userStoppedManually || _isDisposed) return;

      await _audioPlayer?.play();

      if (!_errorController.isClosed) {
        _errorController.add('');
      }

      if (kDebugMode) {
        print('[AudioPlayerManager] Reconexión exitosa');
      }
    } catch (e) {
      if (kDebugMode) {
        print('[AudioPlayerManager] Error en reconexión: $e');
      }
      _consecutiveErrors++;
      _isLoading = false;
      if (!_loadingController.isClosed) {
        _loadingController.add(_isLoading);
      }
      // El siguiente cambio de estado intentará reconectar nuevamente
    }
  }

  /// Alterna entre reproducir y pausar
  Future<void> togglePlayback() async {
    if (_isPlaying) {
      await stop();
    } else {
      await play();
    }
  }

  /// Inicia la reproducción del stream
  Future<void> play() async {
    if (_isDisposed || _isRestarting || _isPlaying) return;

    // Prevenir intentos muy frecuentes
    if (_lastAttemptTime != null) {
      final timeSinceLastAttempt = DateTime.now().difference(_lastAttemptTime!);
      if (timeSinceLastAttempt < _minDelayBetweenAttempts) {
        if (kDebugMode) {
          print('[AudioPlayerManager] Intento demasiado frecuente, ignorando');
        }
        return;
      }
    }
    _lastAttemptTime = DateTime.now();

    try {
      _userStoppedManually = false;
      _isLoading = true;
      if (!_loadingController.isClosed) {
        _loadingController.add(_isLoading);
      }

      // Si hay muchos errores consecutivos, forzar reinicio
      if (_consecutiveErrors > 5) {
        await _forceRestart();
        return;
      }

      if (kDebugMode) {
        print('[AudioPlayerManager] Iniciando reproducción...');
      }

      // Reproducir
      await _audioPlayer?.play();
      _retryCount = 0;
    } catch (e) {
      if (kDebugMode) {
        print('[AudioPlayerManager] Error al reproducir: $e');
      }
      _consecutiveErrors++;
      _isLoading = false;
      _isPlaying = false;
      if (!_loadingController.isClosed) {
        _loadingController.add(_isLoading);
      }
      if (!_playingController.isClosed) {
        _playingController.add(_isPlaying);
      }
      if (!_errorController.isClosed) {
        _errorController.add('Error de conexión');
      }
      _reconnectImmediately();
    }
  }

  /// Detiene la reproducción
  Future<void> stop() async {
    if (_isDisposed) return;

    try {
      if (kDebugMode) {
        print('[AudioPlayerManager] Deteniendo reproducción manualmente');
      }

      _userStoppedManually = true;
      _isRestarting = false;

      await _audioPlayer?.stop();

      _isPlaying = false;
      _isLoading = false;
      _consecutiveErrors = 0;
      _retryCount = 0;

      if (!_playingController.isClosed) {
        _playingController.add(_isPlaying);
      }
      if (!_loadingController.isClosed) {
        _loadingController.add(_isLoading);
      }
      if (!_errorController.isClosed) {
        _errorController.add('');
      }
    } catch (e) {
      if (kDebugMode) {
        print('[AudioPlayerManager] Error en stop: $e');
      }
      _isPlaying = false;
      _isLoading = false;
      if (!_playingController.isClosed) {
        _playingController.add(_isPlaying);
      }
      if (!_loadingController.isClosed) {
        _loadingController.add(_isLoading);
      }
    }
  }

  /// Realiza un reinicio forzado del reproductor
  Future<void> _forceRestart() async {
    if (_isDisposed || _isRestarting) return;

    _isRestarting = true;

    try {
      if (kDebugMode) {
        print('[AudioPlayerManager] Iniciando reinicio forzado...');
      }

      _isLoading = true;
      _isPlaying = false;
      if (!_loadingController.isClosed) {
        _loadingController.add(_isLoading);
      }
      if (!_playingController.isClosed) {
        _playingController.add(_isPlaying);
      }
      if (!_errorController.isClosed) {
        _errorController.add('Reiniciando...');
      }

      await _audioPlayer?.stop();
      await _audioPlayer?.dispose();
      await Future.delayed(const Duration(seconds: 2));

      await _initializePlayer();
      await Future.delayed(const Duration(milliseconds: 500));

      _consecutiveErrors = 0;
      _retryCount = 0;

      if (_userStoppedManually) {
        _isRestarting = false;
        _isLoading = false;
        if (!_loadingController.isClosed) {
          _loadingController.add(_isLoading);
        }
        if (kDebugMode) {
          print(
            '[AudioPlayerManager] Reinicio cancelado (usuario detuvo manualmente)',
          );
        }
        return;
      }

      await _audioPlayer?.play();

      if (!_errorController.isClosed) {
        _errorController.add('');
      }

      if (kDebugMode) {
        print('[AudioPlayerManager] Reinicio forzado completado');
      }
    } catch (e) {
      if (kDebugMode) {
        print('[AudioPlayerManager] Error en reinicio: $e');
      }
      _isLoading = false;
      if (!_loadingController.isClosed) {
        _loadingController.add(_isLoading);
      }
      if (!_errorController.isClosed) {
        _errorController.add('Error al reiniciar');
      }
      _reconnectImmediately();
    } finally {
      _isRestarting = false;
      _isLoading = false;
      if (!_loadingController.isClosed) {
        _loadingController.add(_isLoading);
      }
    }
  }

  /// Maneja errores del reproductor
  void _handlePlayerError(dynamic error) {
    if (_isDisposed || _isRestarting || _userStoppedManually) return;

    if (kDebugMode) {
      print('[AudioPlayerManager] Error del reproductor: $error');
    }

    _consecutiveErrors++;
    _isLoading = false;
    _isPlaying = false;

    if (!_loadingController.isClosed) {
      _loadingController.add(_isLoading);
    }
    if (!_playingController.isClosed) {
      _playingController.add(_isPlaying);
    }

    if (_consecutiveErrors > 3) {
      if (!_errorController.isClosed) {
        _errorController.add('Reiniciando...');
      }
      _forceRestart();
    } else {
      if (!_errorController.isClosed) {
        _errorController.add('Error de reproducción');
      }
      _reconnectImmediately();
    }
  }

  /// Establece el volumen tanto en el reproductor como en el sistema
  Future<void> setVolume(double volume) async {
    if (_isDisposed) return;

    try {
      _volume = volume.clamp(0.0, 1.0);
      await _audioPlayer?.setVolume(_volume);
      VolumeController.instance.setVolume(_volume);

      if (!_volumeStreamController.isClosed) {
        _volumeStreamController.add(_volume);
      }
    } catch (e) {
      if (kDebugMode) {
        print('[AudioPlayerManager] Error al establecer volumen: $e');
      }
    }
  }

  /// Limpia el reproductor actual
  void _cleanupPlayer() {
    _playerStateSubscription?.cancel();
    _playerStateSubscription = null;

    _playbackEventSubscription?.cancel();
    _playbackEventSubscription = null;

    _audioPlayer?.dispose();
    _audioPlayer = null;
  }

  /// Libera todos los recursos utilizados
  void dispose() {
    if (_isDisposed) return;

    if (kDebugMode) {
      print('[AudioPlayerManager] Liberando recursos...');
    }

    _isDisposed = true;
    _isRestarting = false;
    _userStoppedManually = true;

    _interruptionSubscription?.cancel();
    _interruptionSubscription = null;

    _becomingNoisySubscription?.cancel();
    _becomingNoisySubscription = null;

    _cleanupPlayer();

    _playingController.close();
    _loadingController.close();
    _volumeStreamController.close();
    _errorController.close();

    VolumeController.instance.removeListener();
  }
}
