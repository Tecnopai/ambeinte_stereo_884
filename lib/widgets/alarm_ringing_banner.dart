import 'dart:async';

import 'package:flutter/material.dart';

import '../core/theme/app_colors.dart';
import '../services/radio_alarm.dart';

/// Aviso grande arriba de la pantalla de la radio mientras el despertador
/// suena: así se apaga sin buscar la notificación. Revisa cada 2 s (el
/// despertador suena aparte de la app, en Android).
class AlarmRingingBanner extends StatefulWidget {
  const AlarmRingingBanner({super.key});

  @override
  State<AlarmRingingBanner> createState() => _AlarmRingingBannerState();
}

class _AlarmRingingBannerState extends State<AlarmRingingBanner>
    with WidgetsBindingObserver {
  final _alarm = RadioAlarm.instance;
  Timer? _poll;
  bool _ringing = false;

  @override
  void initState() {
    super.initState();
    if (!RadioAlarm.supported) return;
    WidgetsBinding.instance.addObserver(this);
    _check();
    // La app se abrió desde "Seguir escuchando" del aviso.
    Future<void>.delayed(
      const Duration(seconds: 1),
      _alarm.handleKeepListening,
    );
    _poll = Timer.periodic(const Duration(seconds: 2), (_) => _check());
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _poll?.cancel();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _check();
      _alarm.handleKeepListening();
    }
  }

  Future<void> _check() async {
    final ringing = await _alarm.isRinging();
    if (mounted && ringing != _ringing) setState(() => _ringing = ringing);
  }

  Future<void> _do(Future<void> Function() action) async {
    setState(() => _ringing = false);
    await action();
    await Future<void>.delayed(const Duration(milliseconds: 500));
    _check();
  }

  @override
  Widget build(BuildContext context) {
    if (!_ringing) return const SizedBox.shrink();
    return SafeArea(
      bottom: false,
      child: Container(
        margin: const EdgeInsets.fromLTRB(16, 12, 16, 0),
        padding: const EdgeInsets.fromLTRB(16, 14, 16, 8),
        decoration: BoxDecoration(
          color: AppColors.primary.withValues(alpha: 0.22),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: AppColors.accent.withValues(alpha: 0.6)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Row(
              children: [
                Icon(Icons.alarm, color: AppColors.accent),
                SizedBox(width: 10),
                Text(
                  'El despertador está sonando',
                  style: TextStyle(
                    color: AppColors.textPrimary,
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
            Wrap(
              spacing: 4,
              children: [
                TextButton(
                  onPressed: () => _do(_alarm.stop),
                  child: const Text('Apagar'),
                ),
                TextButton(
                  onPressed: () => _do(_alarm.snooze),
                  child: const Text('5 min más'),
                ),
                TextButton(
                  onPressed: () => _do(_alarm.keepListening),
                  child: const Text('Seguir escuchando'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
