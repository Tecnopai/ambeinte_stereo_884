import 'dart:async';

import 'package:flutter/material.dart';

import '../core/theme/app_colors.dart';
import '../services/radio_alarm.dart';

/// Despertador con la radio: hora, días y encendido. Se guarda al cambiar
/// cualquier cosa. A la hora, en Android el teléfono pone la emisora aunque la
/// app esté cerrada; en iPhone suena una alarma con el botón "Escuchar la
/// radio" (ver RadioAlarm).
class AlarmScreen extends StatefulWidget {
  const AlarmScreen({super.key});

  static Future<void> open(BuildContext context) => Navigator.of(
    context,
  ).push(MaterialPageRoute(builder: (_) => const AlarmScreen()));

  @override
  State<AlarmScreen> createState() => _AlarmScreenState();
}

class _AlarmScreenState extends State<AlarmScreen> with WidgetsBindingObserver {
  final _alarm = RadioAlarm.instance;
  RadioAlarmState? _state;

  /// Próxima alarma de otra app del teléfono (p. ej. el reloj), si la hay.
  DateTime? _otherAlarm;

  /// Hay otra alarma cerca de la nuestra (sonarían las dos).
  bool get _clash {
    final other = _otherAlarm;
    final ours = _state?.next;
    if (other == null || ours == null || !(_state?.config.enabled ?? false)) {
      return false;
    }
    return other.difference(ours).abs() <= const Duration(minutes: 30);
  }

  static const _dayLetters = ['L', 'M', 'M', 'J', 'V', 'S', 'D'];
  static const _dayNames = [
    'lunes',
    'martes',
    'miércoles',
    'jueves',
    'viernes',
    'sábado',
    'domingo',
  ];

  static const _monthNames = [
    'enero',
    'febrero',
    'marzo',
    'abril',
    'mayo',
    'junio',
    'julio',
    'agosto',
    'septiembre',
    'octubre',
    'noviembre',
    'diciembre',
  ];

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _reload();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _testTimer?.cancel();
    super.dispose();
  }

  /// Sonando la prueba (se apaga sola a los 30 s en Android; en iPhone suena
  /// a los 5 s como una alarma y se apaga desde ella o con "Detener").
  bool _testing = false;
  Timer? _testTimer;

  Future<void> _startTest() async {
    await _alarm.test();
    if (!mounted) return;
    setState(() => _testing = true);
    _testTimer?.cancel();
    _testTimer = Timer(const Duration(seconds: 31), () {
      if (mounted) setState(() => _testing = false);
    });
  }

  Future<void> _stopTest() async {
    _testTimer?.cancel();
    await _alarm.stop();
    if (mounted) setState(() => _testing = false);
  }

  /// Al volver de los ajustes de Android (permiso de alarmas), se revisa.
  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) _reload(saveAgain: true);
  }

  Future<void> _reload({bool saveAgain = false}) async {
    final hadPermission = _state?.canSchedule ?? true;
    var s = await _alarm.load();
    // Si recién dio el permiso de alarmas, se programa ahora.
    if (saveAgain && !hadPermission && s.config.enabled && s.canSchedule) {
      s = await _alarm.save(s.config);
    }
    final other = await _alarm.otherAlarm();
    if (mounted) {
      setState(() {
        _state = s;
        _otherAlarm = other;
      });
    }
  }

  Future<void> _save(RadioAlarmConfig config) async {
    setState(() => _state = RadioAlarmState(config, _state?.next, true));
    final s = await _alarm.save(config);
    if (mounted) setState(() => _state = s);
  }

  Future<void> _pickTime(RadioAlarmConfig c) async {
    final picked = await showTimePicker(
      context: context,
      initialTime: TimeOfDay(hour: c.hour, minute: c.minute),
      // Escribir la hora es más difícil de equivocar que la esfera (desde
      // aquí también se puede pasar a la esfera).
      initialEntryMode: TimePickerEntryMode.input,
      helpText: 'Hora del despertador',
      cancelText: 'Cancelar',
      confirmText: 'Listo',
    );
    if (picked == null) return;
    await _save(
      c.copyWith(hour: picked.hour, minute: picked.minute, enabled: true),
    );
  }

  String _time(int hour, int minute) {
    final h12 = hour % 12 == 0 ? 12 : hour % 12;
    final ampm = hour < 12 ? 'a. m.' : 'p. m.';
    return '$h12:${minute.toString().padLeft(2, '0')} $ampm';
  }

  String _nextText(RadioAlarmState s) {
    final next = s.next;
    if (!s.config.enabled || next == null) return 'Despertador apagado';
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final day = DateTime(next.year, next.month, next.day);
    final diff = day.difference(today).inDays;
    // Con fecha exacta, para que se note si algo quedó mal programado.
    final when = switch (diff) {
      0 => 'hoy',
      1 => 'mañana',
      _ =>
        'el ${_dayNames[next.weekday - 1]} ${next.day} de '
            '${_monthNames[next.month - 1]}',
    };
    return 'Sonará $when a las ${_time(next.hour, next.minute)}';
  }

  @override
  Widget build(BuildContext context) {
    final s = _state;
    return Scaffold(
      appBar: AppBar(title: const Text('Despertador')),
      body: s == null
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              padding: const EdgeInsets.all(20),
              children: [
                _buildMain(s),
                if (s.config.enabled && !s.canSchedule) ...[
                  const SizedBox(height: 16),
                  _buildPermissionCard(),
                ],
                const SizedBox(height: 16),
                _buildOtherAlarmNotice(),
                const SizedBox(height: 24),
                const Text(
                  'Repetir',
                  style: TextStyle(
                    color: AppColors.textPrimary,
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 10),
                _buildDays(s.config),
                const SizedBox(height: 6),
                Text(
                  s.config.days.isEmpty
                      ? 'Sin días marcados suena una sola vez.'
                      : s.config.days.length == 7
                      ? 'Todos los días.'
                      : 'Los días marcados.',
                  style: const TextStyle(color: AppColors.textMuted),
                ),
                // En iPhone suena con el volumen de alarma del sistema.
                if (!RadioAlarm.isIOS) ...[
                  const SizedBox(height: 24),
                  _buildVolume(s.config),
                ],
                const SizedBox(height: 20),
                // Escuchar el despertador 30 s (volumen, y comprobar que el
                // teléfono lo deja sonar). "Detener" solo mientras suena.
                if (!_testing)
                  OutlinedButton.icon(
                    onPressed: _startTest,
                    icon: const Icon(Icons.play_circle_outline),
                    label: Text(
                      RadioAlarm.isIOS
                          ? 'Probar (suena en 5 segundos)'
                          : 'Escuchar cómo sonará',
                    ),
                  )
                else
                  FilledButton.icon(
                    style: FilledButton.styleFrom(
                      backgroundColor: AppColors.primary,
                    ),
                    onPressed: _stopTest,
                    icon: const Icon(Icons.stop),
                    label: const Text('Detener'),
                  ),
                const SizedBox(height: 20),
                Text(
                  RadioAlarm.isIOS
                      ? 'A la hora suena una alarma como la del reloj del '
                            'iPhone, aunque esté en silencio. Toca "Escuchar la '
                            'radio" para poner Ambiente Stereo, o "Apagar". '
                            'Apple no permite que una app empiece a sonar sola, '
                            'por eso la radio se pone con ese botón. Para probar, '
                            'toca "Probar" y bloquea el teléfono.'
                      : 'A la hora, el teléfono pone Ambiente Stereo aunque la app '
                            'esté cerrada, con el volumen de alarma y subiendo de a poco. '
                            'Si no hay internet, suena un tono para que no te quedes '
                            'dormido. Desde el aviso puedes apagarlo o pedir 5 minutos más.',
                  style: const TextStyle(
                    color: AppColors.textMuted,
                    height: 1.45,
                  ),
                ),
              ],
            ),
    );
  }

  Widget _buildMain(RadioAlarmState s) {
    final c = s.config;
    return Container(
      padding: const EdgeInsets.fromLTRB(20, 16, 12, 16),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppColors.primary.withValues(alpha: 0.2)),
      ),
      child: Row(
        children: [
          Expanded(
            child: InkWell(
              borderRadius: BorderRadius.circular(12),
              onTap: () => _pickTime(c),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    _time(c.hour, c.minute),
                    style: TextStyle(
                      color: c.enabled
                          ? AppColors.textPrimary
                          : AppColors.textMuted,
                      fontSize: 44,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    _nextText(s),
                    style: TextStyle(
                      color: c.enabled ? AppColors.accent : AppColors.textMuted,
                    ),
                  ),
                  const SizedBox(height: 2),
                  const Text(
                    'Toca la hora para cambiarla',
                    style: TextStyle(color: AppColors.textMuted, fontSize: 12),
                  ),
                ],
              ),
            ),
          ),
          Switch(
            value: c.enabled,
            activeTrackColor: AppColors.primary,
            onChanged: (v) => _save(c.copyWith(enabled: v)),
          ),
        ],
      ),
    );
  }

  Widget _buildDays(RadioAlarmConfig c) {
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: [
        for (var d = 0; d < 7; d++)
          FilterChip(
            label: Text(_dayLetters[d]),
            tooltip: _dayNames[d],
            selected: c.days.contains(d),
            showCheckmark: false,
            selectedColor: AppColors.primary,
            onSelected: (on) {
              final days = {...c.days};
              on ? days.add(d) : days.remove(d);
              _save(c.copyWith(days: days, enabled: true));
            },
          ),
      ],
    );
  }

  /// Volumen con el que despierta (se guarda al soltar la barra). Al apagar
  /// el despertador, el volumen de alarma del teléfono vuelve a como estaba.
  Widget _buildVolume(RadioAlarmConfig c) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            const Expanded(
              child: Text(
                'Volumen del despertador',
                style: TextStyle(
                  color: AppColors.textPrimary,
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
            Text(
              '${c.volume} %',
              style: const TextStyle(color: AppColors.accent, fontSize: 16),
            ),
          ],
        ),
        Row(
          children: [
            const Icon(Icons.volume_down, color: AppColors.textMuted),
            Expanded(
              child: Slider(
                value: c.volume.toDouble(),
                min: 10,
                max: 100,
                divisions: 18,
                activeColor: AppColors.primary,
                onChanged: (v) => setState(
                  () => _state = RadioAlarmState(
                    c.copyWith(volume: v.round()),
                    _state?.next,
                    _state?.canSchedule ?? true,
                  ),
                ),
                onChangeEnd: (v) => _save(c.copyWith(volume: v.round())),
              ),
            ),
            const Icon(Icons.volume_up, color: AppColors.textMuted),
          ],
        ),
        const Text(
          'Empieza bajito y sube hasta este volumen. Usa "Escuchar cómo '
          'sonará" para oírlo.',
          style: TextStyle(color: AppColors.textMuted, fontSize: 13),
        ),
      ],
    );
  }

  /// Aviso para no tener también una alarma del reloj del teléfono a la misma
  /// hora (sonarían las dos). Si se detecta una cerca, el aviso es más fuerte.
  Widget _buildOtherAlarmNotice() {
    final clash = _clash;
    final other = _otherAlarm;
    final color = clash ? AppColors.warning : AppColors.textMuted;
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: clash
            ? AppColors.warning.withValues(alpha: 0.12)
            : AppColors.surface.withValues(alpha: 0.6),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: color.withValues(alpha: 0.5)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(
            clash ? Icons.warning_amber_rounded : Icons.info_outline,
            color: color,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              clash && other != null
                  ? 'Tienes otra alarma a las ${_time(other.hour, other.minute)} '
                        'en otra app del teléfono (por ejemplo, el reloj). '
                        'Desactívala para que no suenen las dos al tiempo.'
                  : 'Usa solo este despertador. Si también tienes una alarma '
                        'del reloj del teléfono a la misma hora, desactívala '
                        'para que no suenen las dos al tiempo.',
              style: TextStyle(
                color: clash ? AppColors.textPrimary : AppColors.textMuted,
                height: 1.4,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPermissionCard() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.warning.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.warning.withValues(alpha: 0.5)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Falta un permiso',
            style: TextStyle(
              color: AppColors.textPrimary,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            RadioAlarm.isIOS
                ? 'Para que el despertador suene, activa "Alarmas" (o '
                      '"Notificaciones") en los Ajustes del iPhone para '
                      'Ambiente Stereo.'
                : 'Para que el despertador suene a la hora exacta, Android pide '
                      'activar "Alarmas y recordatorios" para esta app.',
            style: const TextStyle(color: AppColors.textMuted, height: 1.4),
          ),
          const SizedBox(height: 10),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: AppColors.primary),
            onPressed: _alarm.openPermissionSettings,
            child: Text(RadioAlarm.isIOS ? 'Abrir Ajustes' : 'Activar permiso'),
          ),
        ],
      ),
    );
  }
}
