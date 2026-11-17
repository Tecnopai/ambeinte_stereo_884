import 'package:flutter/material.dart';

import '../core/theme/app_colors.dart';
import '../services/sleep_timer.dart';

/// Botón de apagado programado: "Apagar en…" o, si está activo,
/// "Se apaga en 23 min". Al tocarlo se elige el tiempo o se cancela.
/// Sirve en teléfono y en TV (el botón se puede seleccionar con el control).
class SleepTimerButton extends StatelessWidget {
  final double fontSize;

  const SleepTimerButton({super.key, this.fontSize = 14});

  @override
  Widget build(BuildContext context) {
    final timer = SleepTimer.instance;
    return ValueListenableBuilder<Duration?>(
      valueListenable: timer.remaining,
      builder: (context, left, _) {
        final active = left != null;
        return TextButton.icon(
          onPressed: () => showSleepTimerSheet(context),
          style: TextButton.styleFrom(
            foregroundColor: active
                ? AppColors.accent
                : AppColors.textPrimary.withValues(alpha: 0.75),
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
          ),
          icon: Icon(
            active ? Icons.bedtime : Icons.bedtime_outlined,
            size: fontSize + 6,
          ),
          label: Text(
            active ? 'Se apaga en ${_format(left)}' : 'Apagar en…',
            style: TextStyle(fontSize: fontSize),
          ),
        );
      },
    );
  }

  static String _format(Duration left) {
    if (left.inMinutes >= 1) {
      // Se redondea hacia arriba: con 22 min 10 s quedan "23 min".
      final minutes = (left.inSeconds / 60).ceil();
      return '$minutes min';
    }
    return '${left.inSeconds} s';
  }
}

/// Menú para elegir en cuánto se apaga la radio.
Future<void> showSleepTimerSheet(BuildContext context) {
  final timer = SleepTimer.instance;
  return showModalBottomSheet<void>(
    context: context,
    backgroundColor: AppColors.surface,
    showDragHandle: true,
    builder: (sheetContext) => SafeArea(
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Padding(
              padding: EdgeInsets.fromLTRB(24, 0, 24, 8),
              child: Text(
                'Apagar la radio en…',
                style: TextStyle(
                  color: AppColors.textPrimary,
                  fontSize: 18,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
            for (final (i, minutes) in SleepTimer.presets.indexed)
              ListTile(
                autofocus: i == 0,
                leading: const Icon(Icons.timer_outlined),
                title: Text('$minutes minutos'),
                onTap: () {
                  Navigator.of(sheetContext).pop();
                  timer.start(Duration(minutes: minutes));
                },
              ),
            ListTile(
              leading: const Icon(Icons.tune),
              title: const Text('Personalizado…'),
              onTap: () async {
                Navigator.of(sheetContext).pop();
                final minutes = await _askCustomMinutes(context);
                if (minutes != null) timer.start(Duration(minutes: minutes));
              },
            ),
            if (timer.active)
              ListTile(
                leading: const Icon(Icons.close, color: AppColors.error),
                title: const Text('Cancelar el apagado'),
                onTap: () {
                  Navigator.of(sheetContext).pop();
                  timer.cancel();
                },
              ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    ),
  );
}

/// Tiempo personalizado, de 5 en 5 minutos. Con el control remoto se mueve
/// con las flechas izquierda/derecha.
Future<int?> _askCustomMinutes(BuildContext context) {
  var minutes = 60.0;
  return showDialog<int>(
    context: context,
    builder: (dialogContext) => StatefulBuilder(
      builder: (context, setState) => AlertDialog(
        backgroundColor: AppColors.surface,
        title: const Text('Apagar en…'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              _label(minutes.round()),
              style: const TextStyle(
                color: AppColors.accent,
                fontSize: 32,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 8),
            Slider(
              autofocus: true,
              value: minutes,
              min: SleepTimer.minMinutes.toDouble(),
              max: SleepTimer.maxMinutes.toDouble(),
              divisions: (SleepTimer.maxMinutes - SleepTimer.minMinutes) ~/ 5,
              activeColor: AppColors.primary,
              onChanged: (v) => setState(() => minutes = v),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(),
            child: const Text('Cancelar'),
          ),
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(minutes.round()),
            child: const Text('Aceptar'),
          ),
        ],
      ),
    ),
  );
}

String _label(int minutes) {
  if (minutes < 60) return '$minutes min';
  final h = minutes ~/ 60;
  final m = minutes % 60;
  return m == 0 ? '$h h' : '$h h $m min';
}
