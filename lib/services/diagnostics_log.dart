import 'dart:async';
import 'dart:io';

import 'package:device_info_plus/device_info_plus.dart';
import 'package:flutter/foundation.dart' show kDebugMode;
import 'package:package_info_plus/package_info_plus.dart';
import 'package:path_provider/path_provider.dart';

/// Registro de diagnóstico que se guarda SOLO en el teléfono.
///
/// Anota eventos técnicos del reproductor (cambios de estado, reconexiones,
/// cambios de red) para poder entender fallas como "se queda reconectando".
/// Nunca se envía automáticamente: el usuario lo ve y decide si lo comparte
/// desde "Reportar un problema". No contiene datos personales (ni ubicación,
/// ni identificadores del dispositivo o del usuario).
///
/// Se guarda en un archivo para que sobreviva a cerrar la app, que es
/// justo lo que hace el usuario cuando la radio falla.
class DiagnosticsLog {
  DiagnosticsLog._();
  static final DiagnosticsLog instance = DiagnosticsLog._();

  /// Líneas que se conservan en el archivo.
  static const int _maxLines = 400;

  /// Líneas que se incluyen en el reporte.
  static const int _reportLines = 150;

  static const String _fileName = 'diagnostico.log';

  /// Guarda cuándo se ofreció el reporte por última vez.
  static const String _offerFileName = 'aviso_reporte.txt';

  /// Tiempo mínimo entre dos avisos de "¿nos envías un reporte?".
  static const Duration _offerInterval = Duration(days: 7);

  static const String _sessionMarker = '--- App iniciada ---';

  /// Largo del prefijo de fecha y hora de cada línea ("2026-11-07 14:32:05 ").
  static const int _stampLength = 20;

  final List<String> _lines = [];
  File? _file;
  Directory? _dir;

  /// La sesión anterior terminó con la radio fallando (reconectando sin
  /// lograrlo), típicamente porque el usuario cerró la app para arreglarlo.
  bool _previousSessionFailed = false;
  Future<void>? _ready;
  Future<void> _pendingWrite = Future.value();

  /// Carga el archivo anterior y anota el inicio de la app.
  /// Se puede llamar varias veces; solo se ejecuta una.
  Future<void> init() => _ready ??= _load();

  Future<void> _load() async {
    try {
      final dir = await getApplicationSupportDirectory();
      _dir = dir;
      _file = File('${dir.path}/$_fileName');
      if (await _file!.exists()) {
        final previous = await _file!.readAsLines();
        final start = previous.length > _maxLines
            ? previous.length - _maxLines
            : 0;
        final kept = previous.sublist(start);
        _previousSessionFailed = _sessionEndedFailing(kept);
        _lines.insertAll(0, kept);
      }
    } catch (_) {
      // Sin archivo el registro sigue funcionando en memoria.
      _file = null;
    }
    _append(_sessionMarker);
    if (_previousSessionFailed) {
      _append('La sesión anterior terminó con la radio fallando');
    }
    _scheduleWrite();
  }

  /// Revisa la última sesión guardada: si lo último que pasó fue una falla
  /// del stream (sin que volviera a sonar ni el usuario pausara), terminó
  /// fallando.
  static bool _sessionEndedFailing(List<String> lines) {
    var start = 0;
    for (var i = lines.length - 1; i >= 0; i--) {
      if (lines[i].endsWith(_sessionMarker)) {
        start = i;
        break;
      }
    }
    var failing = false;
    for (final line in lines.skip(start)) {
      if (line.length <= _stampLength) continue;
      final event = line.substring(_stampLength);
      if (event.startsWith('Reconexión ') ||
          event.startsWith('El stream se detuvo') ||
          event.startsWith('Sin conexión tras') ||
          event.startsWith('Error al reconectar') ||
          event.startsWith('Error al reproducir') ||
          event.startsWith('Play tardó demasiado')) {
        failing = true;
      } else if (event == 'Estado: playing' ||
          event.startsWith('Pausa')) {
        failing = false;
      }
    }
    return failing;
  }

  /// Indica si conviene ofrecer el reporte al abrir la app: la sesión
  /// anterior terminó fallando y no se ha ofrecido en los últimos 7 días.
  Future<bool> shouldOfferReport() async {
    await init();
    if (!_previousSessionFailed) return false;
    final dir = _dir;
    if (dir == null) return true;
    try {
      final file = File('${dir.path}/$_offerFileName');
      if (!await file.exists()) return true;
      final last = DateTime.tryParse((await file.readAsString()).trim());
      return last == null || DateTime.now().difference(last) >= _offerInterval;
    } catch (_) {
      return true;
    }
  }

  /// Anota que ya se ofreció el reporte (para no repetirlo por 7 días).
  Future<void> markReportOffered() async {
    _previousSessionFailed = false;
    final dir = _dir;
    if (dir == null) return;
    try {
      await File(
        '${dir.path}/$_offerFileName',
      ).writeAsString(DateTime.now().toIso8601String(), flush: true);
    } catch (_) {
      // Si no se puede guardar, como mucho se vuelve a ofrecer.
    }
  }

  /// Anota un evento con fecha y hora.
  void add(String message) {
    _append(message);
    if (kDebugMode) {
      // ignore: avoid_print
      print('[Diagnóstico] $message');
    }
    // Si el archivo aún no cargó, se escribe cuando termine init().
    if (_ready != null) _scheduleWrite();
  }

  void _append(String message) {
    final now = DateTime.now();
    String two(int n) => n.toString().padLeft(2, '0');
    final stamp =
        '${now.year}-${two(now.month)}-${two(now.day)} '
        '${two(now.hour)}:${two(now.minute)}:${two(now.second)}';
    _lines.add('$stamp $message');
    if (_lines.length > _maxLines) {
      _lines.removeRange(0, _lines.length - _maxLines);
    }
  }

  /// Escribe el archivo completo. Las escrituras se encadenan para que no se
  /// pisen entre sí.
  void _scheduleWrite() {
    _pendingWrite = _pendingWrite.then((_) async {
      await _ready;
      final file = _file;
      if (file == null) return;
      try {
        await file.writeAsString('${_lines.join('\n')}\n', flush: true);
      } catch (_) {
        // Un fallo al escribir no debe afectar la reproducción.
      }
    });
  }

  /// Texto del reporte: datos básicos del teléfono y los últimos eventos.
  /// [description] es lo que el usuario escribió sobre el problema.
  Future<String> buildReport({String description = ''}) async {
    await init();
    final buffer = StringBuffer()
      ..writeln('Reporte de problema - Ambiente Stereo 88.4')
      ..writeln();

    if (description.trim().isNotEmpty) {
      buffer
        ..writeln('Qué pasó:')
        ..writeln(description.trim())
        ..writeln();
    }

    buffer.writeln('App: ${await _appVersion()}');
    buffer.writeln('Teléfono: ${await _deviceDescription()}');
    buffer
      ..writeln()
      ..writeln('Últimos eventos:');

    final start = _lines.length > _reportLines
        ? _lines.length - _reportLines
        : 0;
    for (final line in _lines.sublist(start)) {
      buffer.writeln(line);
    }
    return buffer.toString();
  }

  Future<String> _appVersion() async {
    try {
      final info = await PackageInfo.fromPlatform();
      return '${info.version} (${info.buildNumber})';
    } catch (_) {
      return 'desconocida';
    }
  }

  /// Solo marca, modelo y versión del sistema: nada que identifique a la
  /// persona ni al aparato concreto.
  Future<String> _deviceDescription() async {
    try {
      final plugin = DeviceInfoPlugin();
      if (Platform.isAndroid) {
        final a = await plugin.androidInfo;
        return '${a.manufacturer} ${a.model}, Android ${a.version.release} '
            '(API ${a.version.sdkInt})';
      }
      if (Platform.isIOS) {
        final i = await plugin.iosInfo;
        return '${i.utsname.machine}, iOS ${i.systemVersion}';
      }
    } catch (_) {
      // Se usa el valor genérico de abajo.
    }
    return Platform.operatingSystemVersion;
  }
}
