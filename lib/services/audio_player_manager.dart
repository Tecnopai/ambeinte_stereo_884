import 'dart:async';
import 'dart:convert';
import 'dart:io' show HttpDate, Platform;
import 'package:flutter/foundation.dart' show kDebugMode;
import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;
import 'package:radio_player/radio_player.dart';
import 'package:rxdart/rxdart.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'diagnostics_log.dart';

/// Gestor centralizado del reproductor de audio usando radio_player
/// Implementa el patrón Singleton para mantener una única instancia
/// Maneja el streaming de radio, control de volumen y estado de reproducción
/// Incluye notificaciones automáticas y manejo robusto de errores
class AudioPlayerManager {
  // ========== SINGLETON PATTERN ==========
  static AudioPlayerManager? _instance;

  factory AudioPlayerManager() {
    _instance ??= AudioPlayerManager._internal();
    return _instance!;
  }

  // ========== FIREBASE STREAMING CONFIG ==========
  // Firebase path: app_config/streaming
  // Reglas Firestore: Lectura pública, escritura autenticada
  // Fallback URL si Firebase no disponible
  static const String _firebaseStreamConfigPath = 'app_config/streaming';
  static String _streamUrl = 'https://radio06.cehis.net:9036/stream'; // Default
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  bool _isStreamUrlLoaded = false;

  AudioPlayerManager._internal() {
    _log('[AudioPlayerManager] Creando instancia singleton');
    if (Platform.isIOS) {
      _audioSessionChannel.setMethodCallHandler(_handleNativeCall);
    }
    _initAsync();
  }

  /// Llamadas desde AppDelegate.swift (solo iOS).
  Future<void> _handleNativeCall(MethodCall call) async {
    if (call.method == 'remotePause') {
      _log('[AudioPlayerManager] ⏸️ Pausa desde pantalla de bloqueo');
      _diag('Pausa desde pantalla de bloqueo');
      // Pausa del usuario: no reconectar.
      _userWantsPlayback = false;
      _resumeAfterInterruption = false;
      _reconnectTimer?.cancel();
      _deferredReconnectTimer?.cancel();
      _attemptWatchdog?.cancel();
      _isReconnecting = false;
      _reconnectAttempts = 0;
      _endOutage();
      _stopHealthChecks();
      _progressiveBufferingTimer?.cancel();
      _progressiveBufferingTimer = null;
      _isInBufferingState = false;
      _playingController.add(false);
      _loadingController.add(false);
      _errorController.add('');
      _endAudioSession();
    } else if (call.method == 'remotePlay') {
      _log('[AudioPlayerManager] ▶️ Play desde pantalla de bloqueo');
      _diag('Play desde pantalla de bloqueo');
      // Mismo camino que el botón de play: conexión nueva al stream y
      // vigilancia de la carga con reintentos.
      if (!_isPausedForArticle) await play();
    } else if (call.method == 'interruptionBegan') {
      // Siri, llamada, nota de voz...: la pausa que viene no es del usuario.
      _interruptionActive = true;
      _resumeAfterInterruption =
          _userWantsPlayback || _lastPlaybackState == PlaybackState.playing;
      _diag('Interrupción del sistema (Siri, llamada...)');
      if (_resumeAfterInterruption) _watchInterruptionEnd();
    } else if (call.method == 'interruptionEnded') {
      final args = call.arguments;
      final shouldResume = args is Map && args['shouldResume'] == true;
      _diag('Fin de la interrupción (iOS sugiere reanudar: $shouldResume)');
      await _resumeFromInterruption();
    }
  }

  /// iOS: hay una interrupción del sistema en curso (Siri, llamada...).
  bool _interruptionActive = false;

  /// iOS: la radio sonaba cuando empezó la interrupción.
  bool _resumeAfterInterruption = false;

  Timer? _interruptionWatch;

  /// iOS no garantiza el aviso de fin de una interrupción (Siri a veces no lo
  /// envía). Mientras dure, se revisa cada segundo si otro audio del sistema
  /// sigue sonando; cuando ya no, se reanuda. Tras 5 minutos se deja de
  /// esperar para no reanudar por sorpresa mucho después.
  void _watchInterruptionEnd() {
    _interruptionWatch?.cancel();
    final startedAt = DateTime.now();
    var quietChecks = 0;
    _interruptionWatch = Timer.periodic(const Duration(seconds: 1), (
      timer,
    ) async {
      if (!_interruptionActive || !_resumeAfterInterruption) {
        timer.cancel();
        return;
      }
      if (DateTime.now().difference(startedAt) > const Duration(minutes: 5)) {
        timer.cancel();
        _interruptionActive = false;
        _resumeAfterInterruption = false;
        _diag('Interrupción larga: no se reanuda automáticamente');
        _userPausedExternally();
        return;
      }
      bool otherAudio;
      try {
        otherAudio =
            await _audioSessionChannel.invokeMethod<bool>(
              'isOtherAudioPlaying',
            ) ??
            false;
      } catch (_) {
        otherAudio = false;
      }
      // Siri interrumpe por etapas (escuchar, responder, cerrar) con
      // silencios cortos entre ellas: se esperan 3 s seguidos sin otro audio
      // para no reanudar en medio y que Siri vuelva a cortar la radio.
      quietChecks = otherAudio ? 0 : quietChecks + 1;
      if (quietChecks >= 3) {
        timer.cancel();
        _diag('Fin de la interrupción detectado (sin aviso de iOS)');
        await _resumeFromInterruption();
      }
    });
  }

  /// Si el usuario estaba escuchando, se reanuda siempre (es una radio), con
  /// conexión nueva, aunque iOS no lo sugiera.
  Future<void> _resumeFromInterruption() async {
    _interruptionWatch?.cancel();
    _interruptionActive = false;
    if (!_resumeAfterInterruption || _isPausedForArticle) return;
    _resumeAfterInterruption = false;
    await Future.delayed(const Duration(milliseconds: 500));
    if (!_isPausedForArticle) await play();
  }

  // ========== CONSTANTES ==========
  static const Duration _reconnectDelay = Duration(seconds: 5);
  static const int _maxReconnectAttempts = 4;
  static const bool _autoPlay = true;
  static const Duration _playTimeout = Duration(seconds: 15);
  static const Duration _initTimeout = Duration(seconds: 10);

  /// Tras los intentos rápidos se sigue intentando, más espaciado, durante
  /// este tiempo antes de rendirse (una caída de la emisora puede durar
  /// varios minutos).
  static const Duration _slowRetryInterval = Duration(seconds: 30);
  static const Duration _maxOutage = Duration(minutes: 15);

  /// Cada cuánto se consulta el estado público del servidor mientras suena.
  static const Duration _healthInterval = Duration(minutes: 1);

  // ========== BUFFER INTELIGENTE - CONSTANTES ==========
  static const Duration _progressiveBufferingCheck = Duration(seconds: 3);
  static const Duration _minReconnectInterval = Duration(seconds: 15);

  // ========== SESIÓN DE ESCUCHA (solo local) ==========
  DateTime? _startTime;
  int _totalReconnections = 0;

  // ========== WAKE LOCK ==========
  static const _wakeLockChannel = MethodChannel(
    'com.miltonbass.ambeinte_stereo_884/wakelock',
  );
  bool _wakeLockAvailable = false;
  bool _wakeLockAcquired = false;

  // ========== iOS: SESIÓN DE AUDIO Y METADATA ==========
  // Ver AppDelegate.swift: restaura la sesión exclusiva que volume_controller
  // cambia a `.mixWithOthers` (eso oculta los controles de la pantalla de bloqueo).
  static const _audioSessionChannel = MethodChannel(
    'com.miltonbass.ambientestereo884/audio_session',
  );
  // En iOS el AVPlayer no siempre entrega la metadata ICY del stream, así que se
  // consulta el título actual al servidor Icecast (status-json.xsl).
  static const Duration _iosMetadataInterval = Duration(seconds: 15);
  Timer? _iosMetadataTimer;
  String? _lastPolledTitle;

  // ========== ESTADO ==========
  bool _isInitialized = false;
  bool _isInitializing = false;
  final Completer<void> _initCompleter = Completer<void>();

  /// El usuario quiere oír la radio. Solo cambia por acciones del usuario
  /// (play/pausa en la app, en la notificación o en la pantalla de bloqueo),
  /// nunca por un corte de red: así la reconexión no se rinde por error.
  bool _userWantsPlayback = false;
  bool _isAppInBackground = false; // Track estado de app

  // ========== CONTROL PARA ARTÍCULOS ==========
  bool _isPausedForArticle = false;

  // ========== ESTADO DE BUFFER INTELIGENTE ==========
  int _currentBufferHealth = 3; // Salud inicial máxima
  Timer? _progressiveBufferingTimer;
  DateTime? _lastStablePlayback;
  final List<Duration> _recentBufferingDurations = [];
  double _networkStabilityScore = 1.0; // 0.0 a 1.0
  bool _isNetworkDegraded = false;
  DateTime? _lastBufferingStart;
  bool _isInBufferingState = false;
  DateTime? _lastSuccessfulReconnect;

  // ========== STREAMS DE ESTADO ==========
  final BehaviorSubject<bool> _playingController = BehaviorSubject<bool>.seeded(
    false,
  );
  final BehaviorSubject<bool> _loadingController = BehaviorSubject<bool>.seeded(
    false,
  );
  final BehaviorSubject<String> _errorController =
      BehaviorSubject<String>.seeded('');
  final BehaviorSubject<double> _volumeController =
      BehaviorSubject<double>.seeded(1.0);
  final BehaviorSubject<Map<String, String>> _metadataController =
      BehaviorSubject<Map<String, String>>.seeded({});

  // ========== CONTROL DE RECONEXIÓN ==========
  int _reconnectAttempts = 0;
  Timer? _reconnectTimer;
  Timer? _deferredReconnectTimer;
  bool _isReconnecting = false;
  DateTime? _lastReconnectAttempt;

  /// Si un intento de reconexión no logra sonar en este tiempo, se pasa al
  /// siguiente intento (antes la app podía quedarse "Reconectando..." sin fin).
  Timer? _attemptWatchdog;

  /// Último estado recibido del reproductor, para distinguir una pausa del
  /// usuario (playing → paused) de un corte de red (buffering → paused).
  PlaybackState? _lastPlaybackState;

  /// Tipo de red actual (wifi, datos móviles...), para reconectar al cambiar.
  String? _lastNetwork;
  DateTime? _lastNetworkChangeAt;

  /// Se agotaron los intentos de reconexión: si la red vuelve o cambia, se
  /// reintenta solo sin que el usuario tenga que tocar nada.
  bool _gaveUpWaitingForNetwork = false;

  /// La estación se acaba de configurar y aún no se ha usado. Al dar play
  /// después de una pausa se configura de nuevo para abrir una conexión
  /// nueva y escuchar la señal en vivo, no la que quedó en el búfer.
  bool _stationIsFresh = false;

  // ========== CAÍDAS DE LA EMISORA ==========

  /// Cuándo empezó la falla actual (null = sin falla).
  DateTime? _outageStart;

  /// Ya pasó la espera larga: el próximo intento lento se hace de verdad.
  bool _slowRetryDue = false;

  /// El servidor responde pero no está transmitiendo (no existe el punto de
  /// montaje del stream).
  bool _offAir = false;

  /// Dónde está la falla actual, para mostrar el mensaje correcto.
  _OutageCause _cause = _OutageCause.unknown;

  Timer? _healthTimer;
  bool _healthCheckInFlight = false;

  /// Hora de inicio de la transmisión que recibe la conexión actual, según
  /// el servidor. Si cambia, la transmisión se reinició y la conexión vieja
  /// puede quedar sonando mal (ruido): se abre una nueva.
  String? _connectedStreamStart;
  static const String _offAirMarker = '<fuera del aire>';

  final BehaviorSubject<String> _outageController =
      BehaviorSubject<String>.seeded('');
  final BehaviorSubject<String> _noticeController =
      BehaviorSubject<String>.seeded('');
  StreamSubscription? _noticeSubscription;

  // Subscription para los streams del player
  StreamSubscription? _playbackStateSubscription;
  StreamSubscription? _metadataSubscription;
  StreamSubscription<List<ConnectivityResult>>? _connectivitySubscription;

  // ========== GETTERS PÚBLICOS ==========
  Stream<bool> get playingStream => _playingController.stream;
  Stream<bool> get loadingStream => _loadingController.stream;
  Stream<String> get errorStream => _errorController.stream;
  Stream<double> get volumeStream => _volumeController.stream;
  Stream<Map<String, String>> get metadataStream => _metadataController.stream;

  /// Mensaje fijo mientras la radio no logra sonar por una falla larga
  /// ('' = sin falla).
  Stream<String> get outageStream => _outageController.stream;
  String get outage => _outageController.value;

  /// La falla actual es que el teléfono no tiene internet (entonces no tiene
  /// sentido sugerir los podcasts, que también lo necesitan).
  bool get outageIsNoInternet =>
      _lastNetwork == _noNetwork || _cause == _OutageCause.noInternet;

  /// Aviso escrito por el equipo en Firebase (`app_config/streaming`, campo
  /// `aviso`), p. ej. "Estamos presentando fallas técnicas". '' = sin aviso.
  Stream<String> get noticeStream => _noticeController.stream;
  String get notice => _noticeController.value;

  bool get isPlaying => _playingController.value;
  bool get isLoading => _loadingController.value;
  double get volume => _volumeController.value;
  bool get isInitialized => _isInitialized;

  // ========== GETTER PARA CONTROL DE ARTÍCULOS ==========
  bool get isPausedForArticle => _isPausedForArticle;

  /// Carga la URL del streaming desde Firestore (`app_config/streaming`).
  /// Campos:
  ///   - `stream_urls` (lista, opcional): servidores en orden de preferencia;
  ///     si uno falla, la app pasa al siguiente.
  ///   - `stream_url` (texto): servidor único; lo usan también las versiones
  ///     anteriores de la app. Se usa si `stream_urls` no existe.
  /// Orden de prioridad:
  ///   1. Servidor de Firestore (máx. 5 s).
  ///   2. Caché local de Firestore: la última URL descargada con éxito
  ///      (sirve sin internet estable o si el servidor tarda).
  ///   3. URL por defecto definida en el código.
  /// Solo se acepta una URL http/https válida, para que un valor mal escrito
  /// en Firebase no deje la app sin audio.
  Future<void> _loadStreamUrlFromFirebase() async {
    _log('[AudioPlayerManager] 📡 Cargando URL desde Firebase...');
    final docRef = _firestore.doc(_firebaseStreamConfigPath);

    // 1. Servidor
    try {
      final doc = await docRef
          .get(const GetOptions(source: Source.server))
          .timeout(const Duration(seconds: 5));
      if (_applyStreamConfig(doc.data(), 'servidor')) return;
    } catch (e) {
      _log('[AudioPlayerManager] ⚠️ Firestore (servidor) no disponible: $e');
    }

    // 2. Caché local (última URL buena)
    try {
      final cached = await docRef
          .get(const GetOptions(source: Source.cache))
          .timeout(const Duration(seconds: 2));
      if (_applyStreamConfig(cached.data(), 'caché')) return;
    } catch (e) {
      _log('[AudioPlayerManager] ⚠️ Sin URL en caché: $e');
    }

    // 3. URL por defecto
    _log('[AudioPlayerManager] ⚠️ Usando URL por defecto: $_streamUrl');
    _diag('URL del stream: por defecto ($_streamUrl)');
  }

  /// Escucha el campo `aviso` de `app_config/streaming` en tiempo real, para
  /// que el equipo pueda avisar de una falla sin publicar una actualización.
  void _listenForNotice() {
    _noticeSubscription ??= _firestore
        .doc(_firebaseStreamConfigPath)
        .snapshots()
        .listen((doc) {
          // La dirección de los títulos también se puede cambiar en vivo.
          final titlesUrl = _validUrl(_field(doc.data(), 'titulos_url'));
          if (titlesUrl != _titlesUrl) {
            _titlesUrl = titlesUrl;
            if (titlesUrl == null) _applyWebTitle('');
          }

          final value = _field(doc.data(), 'aviso');
          final text = value is String ? value.trim() : '';
          if (text == _noticeController.value) return;
          _noticeController.add(text);
          if (text.isNotEmpty) _diag('Aviso de la emisora: $text');
        }, onError: (Object e) => _log('[AudioPlayerManager] ⚠️ Aviso: $e'));
  }

  /// Valor del campo [name] de [data], aunque en Firebase el nombre tenga
  /// espacios o mayúsculas ("aviso ", "Stream_urls"): en la consola no se
  /// notan.
  static Object? _field(Map<String, dynamic>? data, String name) {
    if (data == null) return null;
    for (final entry in data.entries) {
      if (entry.key.trim().toLowerCase() == name) return entry.value;
    }
    return null;
  }

  /// [value] limpio si es una URL http/https válida; si no, null.
  static String? _validUrl(Object? value) {
    if (value is! String) return null;
    final url = value.trim();
    final uri = Uri.tryParse(url);
    final isValid =
        uri != null &&
        (uri.scheme == 'https' || uri.scheme == 'http') &&
        uri.host.isNotEmpty;
    return isValid ? url : null;
  }

  /// Aplica los servidores de [data] (`stream_urls` o, si no hay, `stream_url`).
  /// Solo se aceptan URLs http/https válidas, para que un valor mal escrito en
  /// Firebase no deje la app sin audio.
  bool _applyStreamConfig(Map<String, dynamic>? data, String origen) {
    final urls = <String>[];
    final list = _field(data, 'stream_urls');
    if (list is List) {
      for (final value in list) {
        final url = _validUrl(value);
        if (url != null && !urls.contains(url)) urls.add(url);
      }
    }
    if (urls.isEmpty) {
      final url = _validUrl(_field(data, 'stream_url'));
      if (url != null) urls.add(url);
    }
    if (urls.isEmpty) {
      _log('[AudioPlayerManager] ⚠️ Sin URL válida en Firebase ($origen)');
      return false;
    }
    _streamUrls = urls;
    _serverIndex = 0;
    _streamUrl = urls.first;
    _isStreamUrlLoaded = true;
    _streamHasTitles = false;
    _titlesUrl = _validUrl(_field(data, 'titulos_url'));
    _log('[AudioPlayerManager] ✅ URL cargada desde Firebase ($origen): $urls');
    _diag(
      'URL del stream: $origen (${urls.first})'
      '${urls.length > 1 ? ' + ${urls.length - 1} de respaldo' : ''}',
    );
    return true;
  }

  // ========== SERVIDORES DE RESPALDO ==========

  /// Servidores configurados en Firebase, en orden de preferencia.
  List<String> _streamUrls = const [];
  int _serverIndex = 0;

  /// Intentos seguidos que no lograron sonar con el servidor actual.
  int _failuresOnServer = 0;
  static const int _failuresBeforeSwitch = 2;

  bool get _hasBackupServers => _streamUrls.length > 1;

  /// Pasa al siguiente servidor de la lista (y vuelve al primero al final).
  /// La próxima conexión ya usa el nuevo.
  void _switchToNextServer(String reason) {
    if (!_hasBackupServers) return;
    _serverIndex = (_serverIndex + 1) % _streamUrls.length;
    _streamUrl = _streamUrls[_serverIndex];
    _failuresOnServer = 0;
    _offAir = false;
    _connectedStreamStart = null;
    _stationIsFresh = false;
    _streamHasTitles = false;
    _diag(
      'Cambio al servidor ${_serverIndex + 1} de ${_streamUrls.length} '
      '($reason): $_streamUrl',
    );
  }

  /// Tiempo tras un cambio de red en el que una falla de conexión se atribuye
  /// a ese cambio y no al servidor.
  static const Duration _networkSettleTime = Duration(seconds: 10);

  /// Si la red del teléfono cambió desde [since] (o poco antes). Mientras la
  /// red cambia, las conexiones abiertas se cortan aunque el servidor esté bien.
  bool _networkChangedSince(DateTime since) {
    final changedAt = _lastNetworkChangeAt;
    return changedAt != null &&
        changedAt.isAfter(since.subtract(_networkSettleTime));
  }

  // ========== INICIALIZACIÓN ==========
  Future<void> _initAsync() async {
    if (_isInitialized || _isInitializing) {
      _log('[AudioPlayerManager] Ya está inicializado o en proceso');
      return;
    }

    _isInitializing = true;
    _loadingController.add(true);
    _log('[AudioPlayerManager] Iniciando inicialización...');

    try {
      await _initializeWakeLock();

      // Esperar a que Firebase cargue la URL ANTES de configurar el player
      await _loadStreamUrlFromFirebase();

      await _setStation();
      _log('[AudioPlayerManager] ✅ Estación configurada con URL: $_streamUrl');

      _setupPlayerListeners();
      _setupConnectivityListener();
      _listenForNotice();

      _isInitialized = true;
      _isInitializing = false;

      _playingController.add(false);
      _loadingController.add(false);

      if (!_initCompleter.isCompleted) {
        _initCompleter.complete();
      }

      _log('[AudioPlayerManager] ✅ Inicialización completa');

      if (_autoPlay) {
        _log('[AudioPlayerManager] 🎵 Auto-iniciando reproducción...');
        Future.delayed(const Duration(milliseconds: 500), () {
          play();
        });
      }
    } catch (e, stackTrace) {
      _isInitializing = false;
      _isInitialized = false;

      _log('[AudioPlayerManager] ❌ Error en inicialización: $e');
      _log('[AudioPlayerManager] Stack trace: $stackTrace');
      _diag('Error al iniciar el reproductor: $e');

      _errorController.add('Error al inicializar: $e');
      _loadingController.add(false);

      if (!_initCompleter.isCompleted) {
        _initCompleter.completeError(e, stackTrace);
      }
    }
  }

  Future<void> _initializeWakeLock() async {
    try {
      await _wakeLockChannel
          .invokeMethod<bool>('acquireWakeLock')
          .timeout(const Duration(seconds: 2));

      _wakeLockAvailable = true;
      _wakeLockAcquired = true;
      _log('[AudioPlayerManager] ✅ WakeLock activado');
    } on MissingPluginException {
      _wakeLockAvailable = false;
      _log(
        '[AudioPlayerManager] ⚠️ WakeLock no disponible - implementación nativa faltante',
      );
      _log('[AudioPlayerManager] ℹ️ La app funcionará sin WakeLock');
    } on TimeoutException {
      _wakeLockAvailable = false;
      _log('[AudioPlayerManager] ⚠️ WakeLock timeout - no disponible');
    } catch (e) {
      _wakeLockAvailable = false;
      _log('[AudioPlayerManager] ⚠️ Error verificando WakeLock: $e');
    }
  }

  void _setupPlayerListeners() {
    _playbackStateSubscription = RadioPlayer.playbackStateStream.listen(
      (state) {
        _log('[AudioPlayerManager] 📊 Estado: $state');
        _diag('Estado: ${state.name}');
        final previous = _lastPlaybackState;
        _lastPlaybackState = state;

        switch (state) {
          case PlaybackState.playing:
            _handlePlayingState();
            break;

          case PlaybackState.paused:
            _handlePausedState(previous);
            break;

          case PlaybackState.buffering:
            _handleBufferingState();
            break;

          case PlaybackState.unknown:
            _handleUnknownState();
            break;
        }
      },
      onError: (error) {
        _log('[AudioPlayerManager] ❌ Error en playbackStateStream: $error');
        _diag('Error del reproductor: $error');
        _errorController.add('Error de conexión');
        _loadingController.add(false);

        if (_userWantsPlayback && !_isPausedForArticle) {
          _scheduleReconnectionWithDelay();
        }
      },
      cancelOnError: false,
    );

    _metadataSubscription = RadioPlayer.metadataStream.listen(
      (metadata) {
        final artist = metadata.artist?.trim() ?? '';
        final title = metadata.title?.trim() ?? '';
        if (artist.isEmpty && title.isEmpty) return;

        // El reproductor también devuelve los títulos que pone la propia app
        // (los de la web o el nombre de la emisora): esos ya se mostraron y
        // no indican que el servidor envíe títulos.
        final isOwn =
            (title == _webSong && artist == (_webArtist ?? '')) ||
            (title == _stationName && artist.isEmpty);
        if (isOwn) return;

        if (!_streamHasTitles) {
          _streamHasTitles = true;
          _diag('El servidor envía los títulos en la señal');
        }

        final data = {
          'artist': metadata.artist ?? 'Desconocido',
          'title': metadata.title ?? 'Sin título',
        };
        _log(
          '[AudioPlayerManager] 🎵 Metadata: ${data['artist']} - ${data['title']}',
        );
        _metadataController.add(data);
      },
      onError: (error) {
        _log('[AudioPlayerManager] ⚠️ Error en metadataStream: $error');
      },
      cancelOnError: false,
    );
  }

  // ========== MANEJO INTELIGENTE DE ESTADOS ==========

  /// Maneja el estado de reproducción normal
  void _handlePlayingState() {
    _deferredReconnectTimer?.cancel();
    _attemptWatchdog?.cancel();
    if (_reconnectAttempts > 0 || _isReconnecting) {
      _diag('Reconectado en el intento $_reconnectAttempts');
      _lastSuccessfulReconnect = DateTime.now();
    }
    _playingController.add(true);
    _loadingController.add(false);
    _reconnectAttempts = 0;
    _failuresOnServer = 0;
    _isReconnecting = false;
    _userWantsPlayback = true;
    _errorController.add('');
    _isInBufferingState = false;
    _endOutage();
    _startHealthChecks();

    // Cancelar todos los timers de buffering
    _progressiveBufferingTimer?.cancel();
    _progressiveBufferingTimer = null;

    // Registrar recuperación exitosa del buffer
    _onPlaybackRecovered();
    _onBufferingResolved();

    _startAudioSession();

    restoreExclusiveAudioSession();
    _startIosMetadataPolling();

    _log(
      '[AudioPlayerManager] ✅ Reproducción normal - Buffer inteligente activo',
    );
  }

  // ========== iOS: NOW PLAYING ==========

  /// Restaura la sesión de audio exclusiva en iOS para que aparezcan los
  /// controles en la pantalla de bloqueo y el Centro de control.
  /// No hace nada en Android.
  Future<void> restoreExclusiveAudioSession() async {
    if (!Platform.isIOS) return;
    try {
      final changed =
          await _audioSessionChannel.invokeMethod<bool>(
            'setExclusivePlayback',
          ) ??
          false;
      // Cambiar la categoría con el audio sonando puede pausar el reproductor
      // nativo: si estaba sonando, se reanuda de inmediato.
      if (changed && _userWantsPlayback && !_isPausedForArticle) {
        _log('[AudioPlayerManager] 🔁 Sesión restaurada, reanudando audio');
        await RadioPlayer.play();
      }
    } catch (e) {
      _log(
        '[AudioPlayerManager] ⚠️ No se pudo restaurar la sesión de audio: $e',
      );
    }
  }

  void _startIosMetadataPolling() {
    if (!Platform.isIOS || _iosMetadataTimer != null) return;
    _pollStreamTitle();
    _iosMetadataTimer = Timer.periodic(
      _iosMetadataInterval,
      (_) => _pollStreamTitle(),
    );
  }

  void _stopIosMetadataPolling() {
    _iosMetadataTimer?.cancel();
    _iosMetadataTimer = null;
  }

  /// Consulta el estado público del servidor Icecast (status-json.xsl).
  /// Devuelve null si el servidor no respondió; si respondió, `mount` es el
  /// punto de montaje del stream, o null si no está transmitiendo.
  /// No envía ningún dato del usuario.
  Future<({Map? mount})?> _fetchServerStatus() async {
    try {
      final streamUri = Uri.parse(_streamUrl);
      final statusUri = Uri(
        scheme: streamUri.scheme,
        host: streamUri.host,
        port: streamUri.port,
        path: '/status-json.xsl',
      );
      final response = await http
          .get(statusUri)
          .timeout(const Duration(seconds: 5));
      if (response.statusCode != 200) return null;

      final icestats =
          (json.decode(response.body) as Map<String, dynamic>)['icestats'];
      if (icestats is! Map) return null;
      final source = icestats['source'];

      bool matches(Map s) =>
          (s['listenurl'] as String? ?? '').endsWith(streamUri.path);

      Map? mount;
      if (source is Map) {
        if (matches(source)) mount = source;
      } else if (source is List) {
        for (final s in source) {
          if (s is Map && matches(s)) {
            mount = s;
            break;
          }
        }
      }
      // Tras un reinicio, el servidor puede publicar el punto de montaje
      // como relleno ("dummy", sin hora de inicio) mientras la emisora aún no
      // envía su señal. Quien se conecta ahí oye ruido: cuenta como fuera
      // del aire.
      if (mount != null &&
          (mount.containsKey('dummy') ||
              (mount['stream_start'] == null &&
                  mount['stream_start_iso8601'] == null))) {
        mount = null;
      }
      return (mount: mount);
    } catch (e) {
      _log('[AudioPlayerManager] ⚠️ Estado del servidor: $e');
      return null;
    }
  }

  /// Lee el título actual desde el status-json.xsl de Icecast y lo envía al
  /// reproductor nativo, que actualiza la pantalla de bloqueo y emite el
  /// evento en metadataStream.
  Future<void> _pollStreamTitle() async {
    if (!isPlaying) return;
    try {
      final mount = (await _fetchServerStatus())?.mount;

      final streamTitle = (mount?['title'] ?? mount?['yp_currently_playing'])
          ?.toString()
          .trim();
      if (streamTitle == null ||
          streamTitle.isEmpty ||
          streamTitle == _lastPolledTitle) {
        return;
      }
      _lastPolledTitle = streamTitle;

      // Mismo formato que la metadata ICY: "Artista - Título".
      final separator = streamTitle.indexOf(' - ');
      final artist = separator > 0
          ? streamTitle.substring(0, separator).trim()
          : null;
      final title = separator > 0
          ? streamTitle.substring(separator + 3).trim()
          : streamTitle;

      await RadioPlayer.setCustomMetadata(artist: artist, title: title);
    } catch (e) {
      _log('[AudioPlayerManager] ⚠️ Error leyendo título del stream: $e');
    }
  }

  /// Maneja el estado de pausa
  /// En Android, radio_player reporta "paused" tanto cuando el usuario pausa
  /// (notificación, audífonos, llamada) como cuando el stream falla (el
  /// reproductor queda en IDLE). Se distinguen por el estado anterior:
  ///   - playing → paused: pausa del usuario o del sistema.
  ///   - buffering/unknown → paused: el stream se cortó.
  void _handlePausedState(PlaybackState? previous) {
    // Limpiar estado de buffering
    _isInBufferingState = false;
    _progressiveBufferingTimer?.cancel();
    _progressiveBufferingTimer = null;

    // Durante una reconexión los cambios de estado los provoca la propia
    // reconexión: el vigilante del intento decide si funcionó.
    if (_isReconnecting) return;

    // Sin red, una pausa tampoco puede ser del usuario de forma fiable: se
    // trata como corte y se reconecta cuando vuelva la red.
    final streamFailed =
        previous == PlaybackState.buffering ||
        previous == PlaybackState.unknown ||
        _lastNetwork == _noNetwork;

    // Una pausa causada por Siri o una llamada no es una caída del stream:
    // la reanudación la maneja la vigilancia de la interrupción.
    if (_interruptionActive) {
      _playingController.add(false);
      _loadingController.add(false);
      return;
    }

    if (_userWantsPlayback && streamFailed && !_isPausedForArticle) {
      _log(
        '[AudioPlayerManager] ⚠️ El stream se detuvo mientras cargaba - posible error de red',
      );
      _diag('El stream se detuvo mientras cargaba');
      _playingController.add(false);
      _scheduleReconnectionWithDelay();
      return;
    }

    _playingController.add(false);
    _loadingController.add(false);
    if (_isPausedForArticle) return;

    // playing → paused sin pasar por pause() de la app: puede ser una pausa
    // desde la notificación o los audífonos, o un corte de red (al apagar el
    // wifi el reproductor falla y queda en pausa sin pasar por "buffering").
    // El reproductor no avisa cuál fue, así que se espera un momento: si en
    // ese lapso cambió o se perdió la red, fue un corte y se reconecta.
    if (_userWantsPlayback && previous == PlaybackState.playing) {
      final pausedAt = DateTime.now();
      Timer(const Duration(seconds: 3), () {
        if (_lastPlaybackState != PlaybackState.paused ||
            !_userWantsPlayback ||
            _isReconnecting ||
            _isPausedForArticle ||
            // iOS: la pausa la causó una interrupción del sistema; se reanuda
            // al terminar (ver interruptionEnded).
            _interruptionActive) {
          return;
        }
        final changedAt = _lastNetworkChangeAt;
        final networkChanged =
            changedAt != null &&
            changedAt.isAfter(pausedAt.subtract(const Duration(seconds: 5)));
        if (networkChanged || _lastNetwork == _noNetwork) {
          _diag('La radio se detuvo por un cambio de red');
          _scheduleReconnectionWithDelay();
        } else {
          _userPausedExternally();
        }
      });
      return;
    }

    // Solo es una pausa del usuario si antes estaba sonando. Un "paused" sin
    // haber sonado lo emite el reproductor al preparar una conexión nueva
    // (setStation) y no debe apagar la vigilancia de la carga que sigue.
    if (previous == PlaybackState.playing) _userPausedExternally();
  }

  /// Pausa del usuario o del sistema (notificación, audífonos): no reconectar.
  void _userPausedExternally() {
    _userWantsPlayback = false;
    _stopHealthChecks();
    _endAudioSession();
  }

  // ========== ESTADO DEL SERVIDOR ==========

  // ========== TÍTULOS DESDE LA WEB ==========
  // Si el servidor de streaming no envía los títulos en la señal (p. ej. con
  // el Comrex conectado directo), se leen de una dirección web configurada en
  // Firebase (`titulos_url`), donde el computador de emisión publica
  // {"titulo": "...", "actualizado": <segundos unix>}. No usa lecturas de
  // Firebase y no depende del servidor de streaming.

  static const String _stationName = 'Ambiente Stereo 88.4 FM';
  static const Duration _webTitleInterval = Duration(seconds: 20);

  /// Un título más viejo que esto no se muestra (ningún audio dura más de
  /// 55 min: si no cambió en una hora, el envío de títulos se detuvo).
  static const Duration _webTitleMaxAge = Duration(minutes: 60);

  String? _titlesUrl;
  bool _streamHasTitles = false;
  Timer? _webTitleTimer;
  String _webTitle = '';
  String? _webArtist;
  String? _webSong;

  void _startWebTitles() {
    if (_webTitleTimer != null) return;
    unawaited(_pollWebTitle());
    _webTitleTimer = Timer.periodic(_webTitleInterval, (_) => _pollWebTitle());
  }

  void _stopWebTitles() {
    _webTitleTimer?.cancel();
    _webTitleTimer = null;
  }

  Future<void> _pollWebTitle() async {
    final url = _titlesUrl;
    if (url == null || _streamHasTitles || !isPlaying) return;
    try {
      final response = await http
          .get(Uri.parse(url))
          .timeout(const Duration(seconds: 5));
      if (response.statusCode != 200) return;
      final data = json.decode(utf8.decode(response.bodyBytes));
      if (data is! Map) return;

      final text = '${data['titulo'] ?? ''}'.trim();
      final updated = data['actualizado'];
      // La antigüedad se mide con la hora del servidor web, no la del
      // teléfono (que puede estar mal configurada).
      final serverDate = response.headers['date'];
      DateTime now = DateTime.now();
      if (serverDate != null) {
        try {
          now = HttpDate.parse(serverDate);
        } catch (_) {}
      }
      final fresh =
          updated is num &&
          now.difference(
                DateTime.fromMillisecondsSinceEpoch(
                  (updated * 1000).round(),
                  isUtc: true,
                ),
              ) <=
              _webTitleMaxAge;

      if (_streamHasTitles || !isPlaying) return;
      _applyWebTitle(fresh ? text : '');
    } catch (e) {
      _log('[AudioPlayerManager] ⚠️ Títulos web: $e');
    }
  }

  /// Muestra [text] tal cual en la app, la notificación y la pantalla de
  /// bloqueo. '' = sin título.
  void _applyWebTitle(String text) {
    if (text == _webTitle) return;
    _webTitle = text;
    if (text.isEmpty) {
      _webArtist = null;
      _webSong = null;
      _metadataController.add(const {});
      if (isPlaying) {
        RadioPlayer.setCustomMetadata(
          title: _stationName,
        ).catchError((Object e) => _log('[AudioPlayerManager] ⚠️ $e'));
      }
      return;
    }
    // El texto se muestra completo, sin separar artista y canción: el
    // programa de emisión no siempre usa el mismo orden (SARA escribe
    // "Canción - Artista") y separarlo podía dejarlo al revés.
    _webArtist = null;
    _webSong = text;
    _metadataController.add({'artist': _webArtist ?? '', 'title': _webSong!});
    RadioPlayer.setCustomMetadata(
      artist: _webArtist,
      title: _webSong,
    ).catchError((Object e) => _log('[AudioPlayerManager] ⚠️ $e'));
  }

  void _startHealthChecks() {
    _startWebTitles();
    // Al abrir una conexión se revisa de inmediato, para anotar qué
    // transmisión está recibiendo.
    unawaited(_checkServerHealth());
    _healthTimer ??= Timer.periodic(
      _healthInterval,
      (_) => _checkServerHealth(),
    );
  }

  void _stopHealthChecks() {
    _stopWebTitles();
    _healthTimer?.cancel();
    _healthTimer = null;
  }

  /// Revisa si la emisora está al aire y si la transmisión se reinició desde
  /// que se abrió la conexión actual. En ese caso la conexión vieja puede
  /// seguir "sonando" con ruido o silencio aunque el servidor ya esté bien,
  /// así que se abre una nueva.
  Future<void> _checkServerHealth() async {
    if (_healthCheckInFlight) return;
    if (!_userWantsPlayback || _isPausedForArticle) {
      _stopHealthChecks();
      return;
    }
    _healthCheckInFlight = true;
    try {
      final status = await _fetchServerStatus();
      if (status == null) return; // el servidor no respondió: no se concluye
      final mount = status.mount;
      _setOffAir(mount == null);

      final start = mount == null
          ? _offAirMarker
          : '${mount['stream_start_iso8601'] ?? mount['stream_start'] ?? ''}';

      // Solo se compara con una conexión que esté sonando.
      if (_lastPlaybackState != PlaybackState.playing || _isReconnecting) {
        return;
      }

      if (mount == null) {
        // Suena algo, pero el servidor dice que la emisora no transmite: es
        // relleno o ruido. Se detiene el audio y se espera a que vuelva.
        _diag('Sonando sin transmisión real en el servidor; se detiene');
        _connectedStreamStart = null;
        if (_hasBackupServers) {
          // Hay otro servidor: se pasa a ese de inmediato.
          _switchToNextServer('fuera del aire');
          _outageStart ??= DateTime.now();
          _reconnectAttempts = 0;
          _handleReconnection();
          return;
        }
        _reconnectAttempts = _maxReconnectAttempts;
        _cause = _OutageCause.offAir;
        _waitForSlowRetry();
        return;
      }

      final known = _connectedStreamStart;
      if (known == null) {
        _connectedStreamStart = start;
        return;
      }
      if (known == start) return;

      _diag('La transmisión se reinició en el servidor; conexión nueva');
      await _refreshConnection();
    } finally {
      _healthCheckInFlight = false;
    }
  }

  void _setOffAir(bool value) {
    if (_offAir == value) return;
    _offAir = value;
    _diag(
      value
          ? 'Servidor: la emisora no está transmitiendo'
          : 'Servidor: emisora al aire',
    );
    if (_outageController.value.isNotEmpty) {
      _outageController.add(_outageMessage());
    }
  }

  /// Abre una conexión nueva sin que el usuario note más que un corte breve.
  Future<void> _refreshConnection() async {
    if (!_userWantsPlayback || _isPausedForArticle || _isReconnecting) return;
    // Mientras dure, los cambios de estado del reproductor no se toman como
    // una pausa del usuario.
    _isReconnecting = true;
    try {
      await _setStation().timeout(const Duration(seconds: 10));
      _stationIsFresh = false;
      await RadioPlayer.play().timeout(_playTimeout);
    } catch (e) {
      _diag('Error al abrir conexión nueva: $e');
    }
    _attemptWatchdog?.cancel();
    _attemptWatchdog = Timer(_playTimeout, () {
      if (!_isReconnecting) return;
      _isReconnecting = false;
      _lastReconnectAttempt = null;
      _handleReconnection();
    });
  }

  /// Mensaje según dónde está la falla, para no culpar a la emisora cuando
  /// el problema es la conexión del teléfono (ni al revés).
  String _outageMessage() {
    switch (_lastNetwork == _noNetwork ? _OutageCause.noInternet : _cause) {
      case _OutageCause.noInternet:
        return 'Tu teléfono no tiene conexión a internet. '
            'Revisa el wifi o los datos; la radio vuelve sola cuando '
            'regrese la conexión.';
      case _OutageCause.weakConnection:
        return 'La emisora está al aire, pero tu conexión a internet está '
            'lenta o inestable. Seguimos intentando; puedes bloquear el '
            'teléfono y la radio vuelve sola.';
      case _OutageCause.offAir:
        return 'La emisora no está transmitiendo en este momento. '
            'Puedes bloquear el teléfono: la radio vuelve sola apenas '
            'regrese la señal.';
      case _OutageCause.serverDown:
        return 'El servidor de la emisora no responde en este momento. '
            'Puedes bloquear el teléfono: la radio vuelve sola apenas '
            'se restablezca.';
      case _OutageCause.unknown:
        return 'Reconectando con la emisora…';
    }
  }

  /// Averigua dónde está la falla:
  ///   - el servidor responde y transmite → la conexión del teléfono;
  ///   - el servidor responde sin transmitir → la emisora está fuera del aire;
  ///   - el servidor no responde pero internet sí → el servidor;
  ///   - nada responde → el teléfono no tiene internet.
  Future<void> _diagnoseOutage() async {
    final startedAt = DateTime.now();
    final status = await _fetchServerStatus();
    _OutageCause cause;
    if (status != null) {
      _setOffAir(status.mount == null);
      cause = _offAir ? _OutageCause.offAir : _OutageCause.weakConnection;
    } else if (!await _hasInternet()) {
      cause = _OutageCause.noInternet;
    } else if (_networkChangedSince(startedAt)) {
      // La consulta al servidor se cortó por el cambio de red, no porque el
      // servidor esté caído.
      cause = _OutageCause.weakConnection;
    } else {
      cause = _OutageCause.serverDown;
    }
    // La revisión tarda unos segundos: si mientras tanto la radio volvió a
    // sonar, el resultado ya no aplica y no debe usarse en la próxima falla.
    if (_outageStart == null) return;
    if (cause != _cause) {
      _cause = cause;
      _diag('Causa de la falla: ${cause.name}');
    }
    // La falla es del servidor (no del teléfono): si hay otro, se usa ese en
    // el próximo intento.
    if (_hasBackupServers &&
        (cause == _OutageCause.offAir || cause == _OutageCause.serverDown)) {
      _switchToNextServer(
        cause == _OutageCause.offAir ? 'fuera del aire' : 'no responde',
      );
      _cause = _OutageCause.unknown;
    }
    if (_outageController.value.isNotEmpty) {
      _outageController.add(_outageMessage());
    }
  }

  /// Muestra el aviso fijo durante los intentos rápidos solo si la causa es
  /// clara. Una conexión lenta puede ser un corte de segundos: ese aviso
  /// espera a que se agoten los intentos rápidos.
  Future<void> _showEarlyDiagnosis() async {
    await _diagnoseOutage();
    // _outageStart se borra en cuanto la radio vuelve a sonar de verdad
    // (_handlePlayingState). No se mira el estado "playing" del reproductor:
    // al cortarse la red sigue reportándolo unos segundos con el audio que
    // le quedaba en el búfer.
    final stillFailing =
        _userWantsPlayback && !_isPausedForArticle && _outageStart != null;
    if (!stillFailing) return;
    final cause = _lastNetwork == _noNetwork ? _OutageCause.noInternet : _cause;
    if (cause == _OutageCause.noInternet ||
        cause == _OutageCause.offAir ||
        cause == _OutageCause.serverDown) {
      _outageController.add(_outageMessage());
    }
  }

  /// Comprueba si hay internet con la misma dirección que usa Android para
  /// detectar conexión (responde vacío; no se envía ningún dato).
  Future<bool> _hasInternet() async {
    try {
      final response = await http
          .get(Uri.parse('https://clients3.google.com/generate_204'))
          .timeout(const Duration(seconds: 5));
      return response.statusCode == 204 || response.statusCode == 200;
    } catch (_) {
      return false;
    }
  }

  /// Termina el modo de falla larga (la radio sonó, o el usuario pausó).
  void _endOutage() {
    _outageStart = null;
    _cause = _OutageCause.unknown;
    _slowRetryDue = false;
    if (_outageController.value.isNotEmpty) _outageController.add('');
  }

  /// Maneja el estado de buffering con inteligencia
  void _handleBufferingState() {
    _loadingController.add(true);
    _isInBufferingState = true;

    // iOS: el reproductor solo pasa a buffering cuando se le pidió reproducir.
    // Si la app creía que el usuario había pausado, la reanudación vino de
    // fuera (fin de una interrupción como una notificación o Siri, audífonos,
    // Centro de control, CarPlay) y la app no se enteró. Se trata como un play
    // para vigilar la carga; si no suena, se reconecta con conexión nueva.
    // (En Android el reproductor puede reportar buffering estando en pausa.)
    if (Platform.isIOS && !_userWantsPlayback && !_isPausedForArticle) {
      _diag('Reanudación externa (iOS)');
      _userWantsPlayback = true;
      _endOutage();
    }

    _log('[AudioPlayerManager] ⏳ Buffering inteligente activado');

    // Solo vigilar el buffering si el usuario quiere oír la radio. También en
    // segundo plano: ahí es donde más se corta con datos móviles. Durante una
    // reconexión el vigilante del intento se encarga.
    if (_userWantsPlayback && !_isReconnecting && !_isPausedForArticle) {
      _handleIntelligentBuffering();
    }
  }

  /// Maneja estado desconocido del reproductor
  void _handleUnknownState() {
    _log('[AudioPlayerManager] ⚠️ Estado desconocido');

    // Ser más conservador con el estado unknown - esperar antes de reconectar
    if (_userWantsPlayback && !_isReconnecting && !_isPausedForArticle) {
      Future.delayed(const Duration(seconds: 3), () {
        if (_userWantsPlayback &&
            !_isReconnecting &&
            _lastPlaybackState == PlaybackState.unknown) {
          _scheduleReconnectionWithDelay();
        }
      });
    }
  }

  // ========== LÓGICA DE BUFFER INTELIGENTE ==========

  /// Maneja el buffering de forma inteligente evaluando la salud del buffer
  void _handleIntelligentBuffering() {
    _log(
      '[AudioPlayerManager] ⏳ Buffering detectado - Evaluando salud: $_currentBufferHealth/3',
    );

    // Registrar inicio de buffering para tracking
    _lastBufferingStart ??= DateTime.now();

    // Evaluar salud actual de la red
    _evaluateBufferHealth();

    if (_currentBufferHealth > 0) _currentBufferHealth--;

    // Se deja que el reproductor recupere el audio por su cuenta: tras un
    // corte junta una reserva antes de seguir (ver packages/radio_player).
    // Reconectar antes de tiempo tira esa reserva y, con internet móvil
    // malo, causa el ciclo "suena, se corta, suena". Solo se reconecta si
    // lleva [_bufferingTimeout] sin poder cargar; si la conexión falla del
    // todo, el reproductor queda en pausa y eso ya dispara la reconexión.
    _startProgressiveBufferingCheck(_bufferingTimeout);
  }

  /// Pruebas con internet móvil malo: esperar más que esto deja silencios
  /// largos; reconectar trae audio de inmediato (el servidor envía de golpe
  /// unos segundos al conectar).
  static const Duration _bufferingTimeout = Duration(seconds: 15);

  /// Evalúa la salud del buffer basado en historial reciente
  void _evaluateBufferHealth() {
    // Limpiar eventos de buffering antiguos (más de 5 minutos)
    _recentBufferingDurations.removeWhere(
      (duration) => duration > const Duration(minutes: 5),
    );

    // Calcular score de estabilidad de red (0.0 a 1.0)
    if (_recentBufferingDurations.isEmpty) {
      _networkStabilityScore = 1.0;
    } else {
      final totalBufferingTime = _recentBufferingDurations.fold(
        Duration.zero,
        (prev, element) => prev + element,
      );
      final totalWindow = const Duration(minutes: 5);
      final bufferingRatio =
          totalBufferingTime.inSeconds / totalWindow.inSeconds;
      _networkStabilityScore = (1.0 - bufferingRatio).clamp(0.1, 1.0);
    }

    _isNetworkDegraded = _networkStabilityScore < 0.6;
    _log(
      '[AudioPlayerManager] 📊 Health Score: ${(_networkStabilityScore * 100).toStringAsFixed(1)}%',
    );
  }

  /// Calcula timeout adaptativo basado en historial de red
  Duration _calculateAdaptiveBufferingTimeout() {
    if (_networkStabilityScore > 0.8) {
      return const Duration(
        seconds: 15,
      ); // Red buena - dar más tiempo para recuperación
    } else if (_networkStabilityScore > 0.5) {
      return const Duration(seconds: 10); // Red regular - timeout moderado
    } else {
      return const Duration(seconds: 8); // Red mala - ser más agresivo
    }
  }

  /// Inicia el monitoreo progresivo del buffering
  void _startProgressiveBufferingCheck(Duration timeout) {
    _progressiveBufferingTimer?.cancel();

    int checkCount = 0;
    final maxChecks = timeout.inSeconds ~/ _progressiveBufferingCheck.inSeconds;

    _progressiveBufferingTimer = Timer.periodic(_progressiveBufferingCheck, (
      timer,
    ) {
      checkCount++;

      // Verificar si sigue en estado de buffering
      if (_loadingController.value && _userWantsPlayback) {
        if (checkCount >= maxChecks) {
          _log(
            '[AudioPlayerManager] ⚠️ Buffering persistente después de $maxChecks checks',
          );
          timer.cancel();
          _handleReconnection();
          return;
        }

        // Mostrar mensaje progresivo al usuario
        _showIntelligentBufferingMessage(checkCount, maxChecks);
      } else {
        // Buffering se resolvió naturalmente
        _onBufferingResolved();
        timer.cancel();
      }
    });

    // Timeout general como fallback
    Timer(timeout, () {
      if (_progressiveBufferingTimer?.isActive == true) {
        _progressiveBufferingTimer?.cancel();
        if (_loadingController.value) {
          _log(
            '[AudioPlayerManager] ⏱️ Timeout de buffering adaptativo alcanzado',
          );
          _handleReconnection();
        }
      }
    });
  }

  /// Muestra mensajes inteligentes al usuario según el progreso
  void _showIntelligentBufferingMessage(int currentCheck, int maxChecks) {
    final messages = [
      'Optimizando conexión...',
      'Ajustando calidad de audio...',
      'Buscando mejor señal...',
    ];

    String message;
    if (_isNetworkDegraded) {
      message = 'Red lenta - ajustando...';
    } else if (currentCheck < messages.length) {
      message = messages[currentCheck - 1];
    } else {
      message = 'Reconectando...';
    }

    // Un solo aviso por corte (antes salía uno cada 3 s).
    if (currentCheck == 2) {
      _errorController.add(
        _isNetworkDegraded
            ? 'Internet inestable: recuperando el audio…'
            : 'Recuperando el audio…',
      );
    }
    _log('[AudioPlayerManager] $message ($currentCheck/$maxChecks)');
  }

  /// Se ejecuta cuando el buffering se resuelve naturalmente
  void _onBufferingResolved() {
    if (_lastBufferingStart != null) {
      final bufferingDuration = DateTime.now().difference(_lastBufferingStart!);
      _recentBufferingDurations.add(bufferingDuration);
      _lastBufferingStart = null;

      // Restaurar salud gradualmente (pero no inmediatamente a máximo)
      _currentBufferHealth = (_currentBufferHealth + 1).clamp(0, 3);

      _log(
        '[AudioPlayerManager] ✅ Buffering resuelto en ${bufferingDuration.inSeconds}s',
      );
      _log(
        '[AudioPlayerManager] 🟢 Buffer Health restaurado: $_currentBufferHealth/3',
      );

      _errorController.add('');
    }
  }

  /// Se ejecuta cuando la reproducción se recupera exitosamente
  void _onPlaybackRecovered() {
    _currentBufferHealth = 3; // Salud máxima
    _lastStablePlayback = DateTime.now();
    _progressiveBufferingTimer?.cancel();
    _lastBufferingStart = null;

    _log(
      '[AudioPlayerManager] 🎉 Playback recuperado - Salud del buffer restaurada',
    );
  }

  // ========== RECONEXIÓN INTELIGENTE ==========

  /// Programa una reconexión con delay para evitar ciclos agresivos.
  /// Si en ese tiempo el audio vuelve solo, no se reconecta.
  void _scheduleReconnectionWithDelay() {
    Future.delayed(const Duration(seconds: 3), () {
      if (_userWantsPlayback &&
          !_isReconnecting &&
          !_isPausedForArticle &&
          _lastPlaybackState != PlaybackState.playing) {
        _handleReconnection();
      }
    });
  }

  /// Vuelve a configurar la estación con la URL del stream. En Android esto
  /// reemplaza la fuente del reproductor y obliga a abrir una conexión nueva;
  /// pausar y reanudar reutiliza la conexión vieja, que tras un cambio de red
  /// (wifi ↔ datos, cambio de antena) puede quedar muerta.
  Future<void> _setStation() async {
    await RadioPlayer.setStation(
      title: 'Ambiente Stereo 88.4 FM',
      url: _streamUrl,
      logoAssetPath: 'assets/images/icon.png',
    );
    _stationIsFresh = true;
    _connectedStreamStart = null;
  }

  /// Maneja la lógica de reconexión con inteligencia
  void _handleReconnection() {
    // No reconectar si está pausado para artículo
    if (_isPausedForArticle) {
      _log(
        '[AudioPlayerManager] ℹ️ Ignorando reconexión - pausado para artículo',
      );
      return;
    }

    // Verificar intervalo mínimo entre reconexiones
    if (_lastSuccessfulReconnect != null) {
      final timeSinceLastReconnect = DateTime.now().difference(
        _lastSuccessfulReconnect!,
      );
      if (timeSinceLastReconnect < _minReconnectInterval) {
        final wait = _minReconnectInterval - timeSinceLastReconnect;
        _log(
          '[AudioPlayerManager] ⏳ Reconexión muy reciente - reintento en ${wait.inSeconds}s',
        );
        _deferredReconnectTimer?.cancel();
        _deferredReconnectTimer = Timer(wait, _handleReconnection);
        return;
      }
    }

    if (_isReconnecting) {
      _log('[AudioPlayerManager] ⚠️ Reconexión ya en progreso...');
      return;
    }

    if (!_userWantsPlayback) {
      _log('[AudioPlayerManager] ℹ️ No reconectar - usuario pausó manualmente');
      return;
    }

    // Pasados los intentos rápidos, se sigue intentando cada 30 s durante
    // un rato, con un mensaje fijo en pantalla, antes de rendirse.
    final outage = _outageStart == null
        ? Duration.zero
        : DateTime.now().difference(_outageStart!);
    if (_reconnectAttempts >= _maxReconnectAttempts && outage < _maxOutage) {
      if (!_slowRetryDue) {
        _waitForSlowRetry();
        return;
      }
      _slowRetryDue = false;
    } else if (_reconnectAttempts >= _maxReconnectAttempts) {
      _log('[AudioPlayerManager] ❌ Máximo de reconexiones alcanzado');
      _endOutage();
      _stopHealthChecks();
      _diag(
        'Sin conexión tras $_maxReconnectAttempts intentos; '
        'se reintentará si cambia la red',
      );
      _userWantsPlayback = false;
      // Si vuelve la red o cambia (wifi ↔ datos), se reintenta solo.
      _gaveUpWaitingForNetwork = true;
      _errorController.add(
        'No se pudo reconectar. Presiona ▶ para reintentar.',
      );
      _loadingController.add(false);
      _playingController.add(false);
      RadioPlayer.pause().catchError((_) {});
      return;
    }

    if (_lastReconnectAttempt != null) {
      final timeSinceLastAttempt = DateTime.now().difference(
        _lastReconnectAttempt!,
      );
      if (timeSinceLastAttempt.inSeconds < 2) {
        _log('[AudioPlayerManager] ⏳ Esperando antes de reintentar...');
        _deferredReconnectTimer?.cancel();
        _deferredReconnectTimer = Timer(
          const Duration(seconds: 2),
          _handleReconnection,
        );
        return;
      }
    }

    _isReconnecting = true;
    _reconnectAttempts++;
    _totalReconnections++;
    _lastReconnectAttempt = DateTime.now();
    _outageStart ??= DateTime.now();
    _loadingController.add(true);

    // En el primer intento se averigua la causa, para avisar enseguida si
    // es clara (sin internet, emisora fuera del aire, servidor caído).
    if (_reconnectAttempts == 1) unawaited(_showEarlyDiagnosis());

    // Intentos lentos: el mensaje fijo ya informa; sin avisos repetidos.
    if (_reconnectAttempts > _maxReconnectAttempts) {
      _diag(
        'Reintento tras falla larga (red: ${_lastNetwork ?? 'desconocida'})',
      );
      _reconnectTimer?.cancel();
      _reconnectTimer = Timer(Duration.zero, () => _attemptConnection());
      return;
    }

    // Mensaje inteligente basado en salud de red
    String userMessage;
    if (_lastNetwork == _noNetwork) {
      userMessage = 'Sin conexión a internet...';
    } else if (_isNetworkDegraded) {
      userMessage = 'Mejorando conexión de red...';
    } else if (_currentBufferHealth <= 0) {
      userMessage = 'Reiniciando stream...';
    } else {
      userMessage = 'Reconectando...';
    }

    _errorController.add(
      '$userMessage ($_reconnectAttempts/$_maxReconnectAttempts)',
    );

    _log(
      '[AudioPlayerManager] 🔄 Intento de reconexión $_reconnectAttempts/$_maxReconnectAttempts',
    );
    _diag(
      'Reconexión $_reconnectAttempts/$_maxReconnectAttempts '
      '(red: ${_lastNetwork ?? 'desconocida'})',
    );

    // El primer intento va rápido; los siguientes esperan más.
    final delay = _reconnectAttempts == 1
        ? const Duration(seconds: 1)
        : _reconnectDelay;

    _reconnectTimer?.cancel();
    _reconnectTimer = Timer(delay, _attemptConnection);
  }

  /// Un intento de reconexión: conexión nueva al stream y play.
  Future<void> _attemptConnection() async {
    if (!_userWantsPlayback || _isPausedForArticle) {
      _isReconnecting = false;
      return;
    }

    try {
      _log('[AudioPlayerManager] 🔄 Abriendo conexión nueva al stream...');
      await _setStation().timeout(const Duration(seconds: 10));
      await RadioPlayer.play().timeout(_playTimeout);
    } catch (e) {
      _log('[AudioPlayerManager] ❌ Error en reconexión: $e');
      _diag('Error al reconectar: $e');
    }

    // El intento solo cuenta como exitoso cuando el reproductor llega a
    // "playing" (_handlePlayingState). Si no suena a tiempo, se pasa al
    // siguiente intento en vez de quedarse cargando para siempre.
    _attemptWatchdog?.cancel();
    _attemptWatchdog = Timer(_playTimeout, () {
      if (!_isReconnecting) return;
      _log('[AudioPlayerManager] ⏱️ El intento no logró sonar a tiempo');
      _diag(
        'Intento $_reconnectAttempts sin audio tras '
        '${_playTimeout.inSeconds} s',
      );
      // Si la red cambió durante el intento, la falla no es del servidor.
      if (!_networkChangedSince(DateTime.now().subtract(_playTimeout))) {
        _failuresOnServer++;
      }
      if (_failuresOnServer >= _failuresBeforeSwitch) {
        _switchToNextServer('no conecta');
      }
      _isReconnecting = false;
      _lastReconnectAttempt = null;
      _handleReconnection();
    });
  }

  /// Espera [_slowRetryInterval] antes del siguiente intento, con el
  /// reproductor detenido (para no gastar datos) y un mensaje fijo.
  void _waitForSlowRetry() {
    _outageStart ??= DateTime.now();
    // Mientras se espera, los cambios de estado del reproductor no se toman
    // como una pausa del usuario.
    _isReconnecting = true;
    _attemptWatchdog?.cancel();
    _errorController.add('');
    _outageController.add(_outageMessage());
    _loadingController.add(false);
    _playingController.add(false);
    RadioPlayer.pause().catchError((_) {});
    unawaited(_diagnoseOutage());

    _reconnectTimer?.cancel();
    _reconnectTimer = Timer(_slowRetryInterval, () async {
      // Si el servidor dice que la emisora no transmite, se sigue esperando
      // sin intentar conectar.
      await _diagnoseOutage();
      if (!_userWantsPlayback || _isPausedForArticle || !_isReconnecting) {
        return;
      }
      _isReconnecting = false;
      _lastReconnectAttempt = null;
      _slowRetryDue = !_offAir;
      _handleReconnection();
    });
  }

  // ========== CAMBIOS DE RED ==========

  static const String _noNetwork = 'sin red';

  void _setupConnectivityListener() {
    final connectivity = Connectivity();
    connectivity
        .checkConnectivity()
        .then(_onNetworkChanged)
        .catchError((Object e) => _log('[AudioPlayerManager] ⚠️ Red: $e'));
    _connectivitySubscription = connectivity.onConnectivityChanged.listen(
      _onNetworkChanged,
      onError: (Object e) => _log('[AudioPlayerManager] ⚠️ Red: $e'),
    );
  }

  static String _describeNetwork(List<ConnectivityResult> results) {
    const names = {
      ConnectivityResult.wifi: 'wifi',
      ConnectivityResult.mobile: 'datos móviles',
      ConnectivityResult.ethernet: 'cable',
      ConnectivityResult.vpn: 'vpn',
      ConnectivityResult.bluetooth: 'bluetooth',
    };
    final active =
        results
            .where((r) => r != ConnectivityResult.none)
            .map((r) => names[r] ?? r.name)
            .toSet()
            .toList()
          ..sort();
    return active.isEmpty ? _noNetwork : active.join(' + ');
  }

  void _onNetworkChanged(List<ConnectivityResult> results) {
    final network = _describeNetwork(results);
    final previous = _lastNetwork;
    if (network == previous) return;
    _lastNetwork = network;
    _lastNetworkChangeAt = DateTime.now();

    _log('[AudioPlayerManager] 📶 Red: ${previous ?? '-'} → $network');
    _diag('Red: ${previous ?? 'inicio'} → $network');

    // Se fue la red con la radio encendida: se avisa de inmediato (el audio
    // en búfer puede seguir sonando unos segundos).
    if (network == _noNetwork &&
        previous != null &&
        _userWantsPlayback &&
        !_isPausedForArticle) {
      _outageStart ??= DateTime.now();
      _cause = _OutageCause.noInternet;
      _outageController.add(_outageMessage());
    }

    // Primera lectura, o se fue la red: se espera a que vuelva.
    if (previous == null || network == _noNetwork) return;
    if (_isPausedForArticle) return;
    if (!_userWantsPlayback && !_gaveUpWaitingForNetwork) return;

    // Si sigue sonando y solo se agregó una red (p. ej. wifi + vpn), no se
    // interrumpe. Si cambió de red (wifi → datos) o volvió la conexión, la
    // conexión vieja ya no sirve: se abre una nueva de inmediato.
    final previousParts = previous.split(' + ').toSet();
    final sharesNetwork = network.split(' + ').any(previousParts.contains);
    if (_lastPlaybackState == PlaybackState.playing && sharesNetwork) return;

    _log('[AudioPlayerManager] 🔁 Cambio de red - reconectando');
    _userWantsPlayback = true;
    _gaveUpWaitingForNetwork = false;
    _reconnectTimer?.cancel();
    _deferredReconnectTimer?.cancel();
    _attemptWatchdog?.cancel();
    _progressiveBufferingTimer?.cancel();
    _progressiveBufferingTimer = null;
    _isReconnecting = false;
    _reconnectAttempts = 0;
    _lastReconnectAttempt = null;
    _lastSuccessfulReconnect = null;
    _handleReconnection();
  }

  void _diag(String message) => DiagnosticsLog.instance.add(message);

  Future<void> _ensureInitialized() async {
    if (_isInitialized) return;

    if (_isInitializing) {
      _log('[AudioPlayerManager] ⏳ Esperando inicialización en curso...');
      try {
        await _initCompleter.future.timeout(_initTimeout);
        _log('[AudioPlayerManager] ✅ Inicialización completada');
      } on TimeoutException {
        _log('[AudioPlayerManager] ⏱️ Timeout esperando inicialización');
        throw Exception('Timeout en inicialización');
      } catch (e) {
        _log('[AudioPlayerManager] ❌ Error esperando inicialización: $e');
        rethrow;
      }
      return;
    }

    if (!_isInitialized) {
      _log('[AudioPlayerManager] 🔄 Iniciando inicialización...');
      await _initAsync();
    }
  }

  // ========== SESIÓN DE ESCUCHA (solo local, para depuración) ==========
  // No se envía a ningún servidor; solo se usa en los logs de depuración y en
  // getDebugInfo().

  void _startAudioSession() {
    if (_startTime == null) {
      _startTime = DateTime.now();
      _log('[AudioPlayerManager] 📊 Sesión de escucha iniciada');
    }
  }

  void _endAudioSession() {
    if (_startTime != null) {
      final duration = DateTime.now().difference(_startTime!);
      _log(
        '[AudioPlayerManager] 📊 Sesión finalizada: ${duration.inSeconds}s - '
        'reconexiones: $_totalReconnections',
      );
      _startTime = null;
      _totalReconnections = 0;
    }
  }

  // Lifecycle tracking con flag de background
  void onAppPaused() {
    if (_isAppInBackground) return;
    _log('[AudioPlayerManager] 🔵 App pausada/background');
    _diag('App en segundo plano');
    _isAppInBackground = true;
  }

  void onAppResumed() {
    if (!_isAppInBackground) return;
    _log('[AudioPlayerManager] 🟢 App resumida/foreground');
    _diag('App en primer plano');
    _isAppInBackground = false;

    // Si la radio estaba esperando el siguiente reintento lento, al volver a
    // la app se intenta de inmediato en vez de hacer esperar al usuario.
    if (_outageController.value.isNotEmpty &&
        _userWantsPlayback &&
        !_isPausedForArticle &&
        _attemptWatchdog?.isActive != true) {
      _reconnectTimer?.cancel();
      _isReconnecting = false;
      _lastReconnectAttempt = null;
      _slowRetryDue = true;
      _handleReconnection();
    }
  }

  // ========== MÉTODOS PARA CONTROL DE ARTÍCULOS ==========

  /// Pausar la radio temporalmente para reproducir un artículo
  Future<void> pauseForArticle() async {
    if (isPlaying && !_isPausedForArticle) {
      _isPausedForArticle = true;
      _userWantsPlayback = false; // Importante: evitar reconexión
      await pause();
      _log('[AudioPlayerManager] ⏸️ Pausado temporalmente para artículo');
    }
  }

  /// Reanudar la radio después de terminar un artículo
  Future<void> resumeAfterArticle() async {
    if (_isPausedForArticle) {
      _isPausedForArticle = false;
      _log('[AudioPlayerManager] ▶️ Reanudando después de artículo');

      // Esperar un poco antes de reanudar
      await Future.delayed(const Duration(milliseconds: 500));
      await play();
    }
  }

  // ========== TOGGLE PLAYBACK ==========
  Future<void> togglePlayback() async {
    try {
      await _ensureInitialized();

      if (!_isInitialized) {
        _errorController.add('No se pudo inicializar el reproductor');
        return;
      }

      if (isPlaying) {
        await pause();
      } else {
        await play();
      }
    } catch (e) {
      _log('[AudioPlayerManager] ❌ Error en togglePlayback: $e');
      _errorController.add('Error al cambiar reproducción');
      rethrow;
    }
  }

  // ========== CONTROL DE REPRODUCCIÓN ==========

  Future<void> play() async {
    try {
      await _ensureInitialized();

      if (!_isInitialized) {
        _errorController.add('Reproductor no disponible');
        _loadingController.add(false);
        return;
      }

      _diag('Play');
      _userWantsPlayback = true;
      _gaveUpWaitingForNetwork = false;
      // Un play del usuario empieza de cero: cancela cualquier reconexión.
      _reconnectTimer?.cancel();
      _deferredReconnectTimer?.cancel();
      _attemptWatchdog?.cancel();
      _isReconnecting = false;
      _reconnectAttempts = 0;
      _lastReconnectAttempt = null;
      _endOutage();
      _loadingController.add(true);
      _errorController.add('');

      _log(
        '[AudioPlayerManager] ▶️ Iniciando reproducción con buffer inteligente...',
      );

      // Después de una pausa o de una falla, conexión nueva al stream.
      if (!_stationIsFresh) {
        await _setStation().timeout(const Duration(seconds: 10));
      }
      _stationIsFresh = false;

      await RadioPlayer.play().timeout(
        _playTimeout,
        onTimeout: () {
          throw TimeoutException('La conexión tardó demasiado');
        },
      );

      // No se marca aquí _lastSuccessfulReconnect: play() vuelve antes de
      // que suene, y si la conexión falla, esa marca retrasaba 15 s el
      // primer reintento. Se marca al sonar de verdad (_handlePlayingState).
      _recentBufferingDurations.clear(); // Limpiar historial en nueva conexión
    } on TimeoutException catch (e) {
      _log('[AudioPlayerManager] ⏱️ Timeout al reproducir: $e');
      _diag('Play tardó demasiado: $e');
      _loadingController.add(false);
      _errorController.add('Conexión lenta. Reintentando...');
      _lastSuccessfulReconnect = null;
      _handleReconnection();
    } catch (e) {
      _log('[AudioPlayerManager] ❌ Error al reproducir: $e');
      _diag('Error al reproducir: $e');
      _loadingController.add(false);
      _errorController.add('Error al conectar');
    }
  }

  Future<void> pause() async {
    try {
      await _ensureInitialized();

      _log('[AudioPlayerManager] ⏸️ Pausando reproducción...');
      _diag('Pausa');
      _userWantsPlayback = false;
      _resumeAfterInterruption = false;
      _gaveUpWaitingForNetwork = false;
      _reconnectTimer?.cancel();
      _deferredReconnectTimer?.cancel();
      _attemptWatchdog?.cancel();
      _isReconnecting = false;
      _reconnectAttempts = 0;
      _endOutage();
      _stopHealthChecks();

      await RadioPlayer.pause();
      _loadingController.add(false);
    } catch (e) {
      _log('[AudioPlayerManager] ❌ Error al pausar: $e');
      _errorController.add('Error al pausar');
    }
  }

  // ========== CONTROL DE VOLUMEN ==========
  Future<void> setVolume(double volume) async {
    try {
      await _ensureInitialized();

      final clampedVolume = volume.clamp(0.0, 1.0);
      _volumeController.add(clampedVolume);

      final volumePercent = (clampedVolume * 100).toInt();
      _log('[AudioPlayerManager] 🔊 Volumen: $volumePercent%');
    } catch (e) {
      _log('[AudioPlayerManager] ❌ Error al cambiar volumen: $e');
    }
  }

  void resetReconnectionAttempts() {
    _reconnectAttempts = 0;
    _isReconnecting = false;
    _reconnectTimer?.cancel();
    _errorController.add('');
    _userWantsPlayback = false;
    _log('[AudioPlayerManager] 🔄 Contador de reconexión reseteado');
  }

  // ========== CLEANUP ==========
  Future<void> dispose() async {
    _log('[AudioPlayerManager] 🧹 Liberando recursos...');

    // Detener todos los timers
    _stopIosMetadataPolling();
    _progressiveBufferingTimer?.cancel();
    _progressiveBufferingTimer = null;

    _endAudioSession();
    _reconnectTimer?.cancel();
    _deferredReconnectTimer?.cancel();
    _attemptWatchdog?.cancel();
    _stopHealthChecks();
    await _playbackStateSubscription?.cancel();
    await _metadataSubscription?.cancel();
    await _connectivitySubscription?.cancel();
    await _noticeSubscription?.cancel();

    await _outageController.close();
    await _noticeController.close();
    await _playingController.close();
    await _loadingController.close();
    await _errorController.close();
    await _volumeController.close();
    await _metadataController.close();

    if (_wakeLockAvailable && _wakeLockAcquired) {
      try {
        await _wakeLockChannel.invokeMethod<bool>('releaseWakeLock');
        _wakeLockAcquired = false;
        _log('[AudioPlayerManager] ✅ WakeLock liberado');
      } catch (e) {
        _log('[AudioPlayerManager] ⚠️ Error liberando WakeLock: $e');
      }
    }

    try {
      await RadioPlayer.reset();
      _log('[AudioPlayerManager] ✅ Player reseteado');
    } catch (e) {
      _log('[AudioPlayerManager] ⚠️ Error al resetear player: $e');
    }

    _log('[AudioPlayerManager] ✅ Recursos liberados completamente');
  }

  // ========== LOGGING ==========
  void _log(String message) {
    if (kDebugMode) {
      // ignore: avoid_print
      print(message);
    }
  }

  // ========== DEBUG INFO MEJORADO ==========
  Map<String, dynamic> getDebugInfo() {
    return {
      'isInitialized': _isInitialized,
      'isPlaying': isPlaying,
      'isLoading': isLoading,
      'isPausedForArticle': _isPausedForArticle,
      'streamUrl': _streamUrl,
      'streamUrlSource': _isStreamUrlLoaded ? 'firebase' : 'default',
      'reconnectAttempts': _reconnectAttempts,
      'totalReconnections': _totalReconnections,
      'isReconnecting': _isReconnecting,
      'userWantsPlayback': _userWantsPlayback,
      'isAppInBackground': _isAppInBackground,
      'volume': volume,
      'sessionActive': _startTime != null,
      'sessionDuration': _startTime != null
          ? DateTime.now().difference(_startTime!).inSeconds
          : 0,
      'wakeLockAvailable': _wakeLockAvailable,
      'wakeLockAcquired': _wakeLockAcquired,
      // INFO DE BUFFER INTELIGENTE
      'bufferIntelligence': {
        'buffer_health': '$_currentBufferHealth/3',
        'network_stability_score':
            '${(_networkStabilityScore * 100).toStringAsFixed(1)}%',
        'is_network_degraded': _isNetworkDegraded,
        'recent_buffering_events': _recentBufferingDurations.length,
        'last_stable_playback': _lastStablePlayback?.toIso8601String(),
        'adaptive_timeout_seconds':
            _calculateAdaptiveBufferingTimeout().inSeconds,
        'last_buffering_start': _lastBufferingStart?.toIso8601String(),
        'is_in_buffering_state': _isInBufferingState,
      },
    };
  }
}

/// Dónde está una falla larga de la radio.
enum _OutageCause { unknown, noInternet, weakConnection, offAir, serverDown }
