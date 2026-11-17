import 'dart:io';

import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;
import 'package:path_provider/path_provider.dart';

import '../utils/tv.dart';
import 'audio_player_manager.dart';
import 'diagnostics_log.dart';

/// Configuración del despertador. Días: 0 = lunes … 6 = domingo; vacío = una
/// sola vez.
class RadioAlarmConfig {
  final bool enabled;
  final int hour;
  final int minute;
  final Set<int> days;

  /// Volumen del despertador, en % del volumen de alarma del teléfono.
  final int volume;

  const RadioAlarmConfig({
    required this.enabled,
    required this.hour,
    required this.minute,
    required this.days,
    this.volume = 70,
  });

  int get daysMask => days.fold(0, (m, d) => m | (1 << d));

  static Set<int> daysFromMask(int mask) => {
    for (var d = 0; d < 7; d++)
      if (mask & (1 << d) != 0) d,
  };

  RadioAlarmConfig copyWith({
    bool? enabled,
    int? hour,
    int? minute,
    Set<int>? days,
    int? volume,
  }) => RadioAlarmConfig(
    enabled: enabled ?? this.enabled,
    hour: hour ?? this.hour,
    minute: minute ?? this.minute,
    days: days ?? this.days,
    volume: volume ?? this.volume,
  );
}

/// Estado leído de Android.
class RadioAlarmState {
  final RadioAlarmConfig config;

  /// Próxima vez que suena, o null si está apagado.
  final DateTime? next;

  /// Android permite alarmas exactas (en Android 12+ hay que darlo).
  final bool canSchedule;

  const RadioAlarmState(this.config, this.next, this.canSchedule);
}

/// Despertador con la radio (solo Android, no TV). Todo el trabajo lo hace la
/// parte nativa (RadioAlarm.java / AlarmService.java), que funciona aunque la
/// app esté cerrada. Desde aquí se configura y se le pasan las direcciones de
/// los servidores y el audio de respaldo. Nada sale del teléfono.
class RadioAlarm {
  RadioAlarm._();
  static final RadioAlarm instance = RadioAlarm._();

  static const _channel = MethodChannel(
    'com.miltonbass.ambientestereo884/alarm',
  );

  static bool get supported => Platform.isAndroid && !Tv.isTv;

  Future<RadioAlarmState> load() async {
    final m = Map<String, dynamic>.from(
      await _channel.invokeMethod<Map>('getConfig') ?? {},
    );
    final config = RadioAlarmConfig(
      enabled: m['enabled'] == true,
      hour: (m['hour'] as int?) ?? 6,
      minute: (m['minute'] as int?) ?? 0,
      days: RadioAlarmConfig.daysFromMask((m['days'] as int?) ?? 0),
      volume: (m['volume'] as int?) ?? 70,
    );
    return RadioAlarmState(
      config,
      _toDate(m['next']),
      m['canSchedule'] != false,
    );
  }

  /// Guarda y programa. Devuelve el estado nuevo (si Android no dio permiso
  /// para alarmas exactas, `canSchedule` es false).
  Future<RadioAlarmState> save(RadioAlarmConfig config) async {
    if (config.enabled) {
      await _channel.invokeMethod('requestNotifications');
    }
    await _channel.invokeMethod('setConfig', {
      'enabled': config.enabled,
      'hour': config.hour,
      'minute': config.minute,
      'days': config.daysMask,
      'volume': config.volume,
    });
    DiagnosticsLog.instance.add(
      config.enabled
          ? 'Despertador: ${config.hour}:${config.minute.toString().padLeft(2, '0')}'
                ' (días ${config.daysMask})'
          : 'Despertador apagado',
    );
    return load();
  }

  Future<void> openPermissionSettings() =>
      _channel.invokeMethod('openExactAlarmSettings');

  /// Suena ya, para probar (no cambia la configuración).
  Future<void> test() async {
    await _channel.invokeMethod('requestNotifications');
    await _channel.invokeMethod('test');
  }

  Future<void> stop() => _channel.invokeMethod('stop');

  Future<void> snooze() => _channel.invokeMethod('snooze');

  /// Próxima alarma del teléfono si es de otra app (p. ej. el reloj), o null.
  /// Android solo informa la próxima alarma, no todas.
  Future<DateTime?> otherAlarm() async {
    if (!supported) return null;
    try {
      final m = await _channel.invokeMethod<Map>('otherAlarm');
      return m == null ? null : _toDate(m['time']);
    } catch (_) {
      return null;
    }
  }

  /// True mientras el despertador está sonando.
  Future<bool> isRinging() async {
    if (!supported) return false;
    try {
      return await _channel.invokeMethod<bool>('isRinging') ?? false;
    } catch (_) {
      return false;
    }
  }

  /// "Seguir escuchando": pone la radio normal y, cuando ya suena, apaga el
  /// despertador. Así no queda un silencio mientras la app se conecta.
  Future<void> keepListening() async {
    final radio = AudioPlayerManager();
    if (!radio.isPlaying) {
      await radio.play();
      try {
        await radio.playingStream
            .firstWhere((playing) => playing)
            .timeout(const Duration(seconds: 20));
      } catch (_) {
        // Si la app no logra sonar, igual se apaga el despertador.
      }
    }
    await stop();
  }

  /// Si el usuario tocó "Seguir escuchando" en el aviso, pone la radio.
  /// Se llama al abrir la app o al volver a ella.
  Future<void> handleKeepListening() async {
    if (!supported) return;
    try {
      final pending = await _channel.invokeMethod<bool>('takeKeepListening');
      if (pending == true) {
        DiagnosticsLog.instance.add('Despertador: seguir escuchando');
        await keepListening();
      }
    } catch (_) {}
  }

  /// Servidores de la radio, en orden (de Firebase).
  Future<void> syncStreams(List<String> urls) async {
    if (!supported) return;
    try {
      await _channel.invokeMethod('setStreams', {'urls': urls});
    } catch (_) {}
  }

  /// Audio de respaldo opcional (campo `audio_despertador` en Firebase): se
  /// descarga con wifi y se guarda en el teléfono, para que suene aunque a la
  /// hora de la alarma no haya internet. Sin el campo, suena el tono de la app.
  Future<void> updateFallbackAudio(String? url) async {
    if (!supported) return;
    try {
      final dir = await getApplicationSupportDirectory();
      final file = File('${dir.path}/despertador_audio');
      final meta = File('${dir.path}/despertador_audio.url');
      if (url == null || url.isEmpty) {
        if (await file.exists()) await file.delete();
        if (await meta.exists()) await meta.delete();
        await _channel.invokeMethod('setFallbackAudio', {'path': null});
        return;
      }
      final have =
          await file.exists() &&
          await meta.exists() &&
          await meta.readAsString() == url;
      if (!have) {
        final network = await Connectivity().checkConnectivity();
        if (!network.contains(ConnectivityResult.wifi)) return;
        final response = await http
            .get(Uri.parse(url))
            .timeout(const Duration(seconds: 60));
        if (response.statusCode != 200 || response.bodyBytes.isEmpty) return;
        await file.writeAsBytes(response.bodyBytes, flush: true);
        await meta.writeAsString(url, flush: true);
        DiagnosticsLog.instance.add(
          'Despertador: audio de respaldo descargado',
        );
      }
      await _channel.invokeMethod('setFallbackAudio', {'path': file.path});
    } catch (_) {
      // Sin el audio propio, suena el tono de la app.
    }
  }

  static DateTime? _toDate(Object? millis) {
    if (millis is! int || millis < 0) return null;
    return DateTime.fromMillisecondsSinceEpoch(millis);
  }
}
