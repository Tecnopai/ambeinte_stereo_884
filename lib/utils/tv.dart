import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:url_launcher/url_launcher.dart';

import '../core/theme/app_colors.dart';

/// Detección de televisor (Android TV / Google TV).
///
/// En un televisor no hay pantalla táctil: todo se maneja con las flechas y el
/// botón OK del control remoto. Las pantallas usan [Tv.isTv] para mostrar una
/// interfaz pensada para eso; en teléfonos y tablets no cambia nada.
class Tv {
  Tv._();

  /// Canal de MainActivity.java (la actividad que usa la app).
  static const _channel = MethodChannel(
    'com.miltonbass.ambientestereo884/device',
  );

  /// True si la app corre en un televisor. Se lee una vez al arrancar.
  static bool isTv = false;

  /// Pregunta a Android si es un televisor. Si falla, se asume que no.
  static Future<void> init() async {
    if (!Platform.isAndroid) return;
    try {
      isTv = await _channel.invokeMethod<bool>('isTv') ?? false;
    } catch (_) {
      isTv = false;
    }
  }

  /// Pide al televisor que no ponga el protector de pantalla ni se apague
  /// (mientras suena el audio). Sin efecto fuera de TV.
  static Future<void> keepScreenOn(bool on) async {
    if (!isTv) return;
    try {
      await _channel.invokeMethod<void>('keepScreenOn', on);
    } catch (_) {}
  }

  /// Abre un enlace en TV. Muchos televisores no tienen navegador ni correo:
  /// si no hay con qué abrirlo, muestra la dirección para abrirla en el
  /// celular. (En teléfonos no se usa: cada pantalla abre sus enlaces.)
  static Future<void> openLink(BuildContext context, Uri uri) async {
    var opened = false;
    try {
      opened = await launchUrl(
        uri,
        mode: uri.scheme == 'mailto'
            ? LaunchMode.platformDefault
            : LaunchMode.externalApplication,
      );
    } catch (_) {
      opened = false;
    }
    if (opened || !context.mounted) return;
    final shown = uri.scheme == 'mailto'
        ? uri.path
        : uri.toString().replaceFirst(RegExp(r'^https?://(www\.)?'), '');
    await showDialog<void>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: AppColors.surface,
        title: const Text('Ábrelo en tu celular'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Este televisor no puede abrirlo. Escribe esta dirección en tu '
              'celular o computador:',
              style: TextStyle(color: AppColors.textMuted),
            ),
            const SizedBox(height: 16),
            SelectableText(
              shown,
              style: const TextStyle(
                color: AppColors.accent,
                fontSize: 22,
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            autofocus: true,
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Entendido'),
          ),
        ],
      ),
    );
  }

  /// Teclas del control que equivalen a "tocar" lo seleccionado. Android TV
  /// envía el botón central como `select`; algunos controles envían Enter.
  static const Map<ShortcutActivator, Intent> activateShortcuts = {
    SingleActivator(LogicalKeyboardKey.select): ActivateIntent(),
    SingleActivator(LogicalKeyboardKey.enter): ActivateIntent(),
    SingleActivator(LogicalKeyboardKey.numpadEnter): ActivateIntent(),
    SingleActivator(LogicalKeyboardKey.gameButtonA): ActivateIntent(),
  };
}

/// Elemento que se puede seleccionar con el control remoto y "tocar" con OK.
///
/// Cuando está seleccionado muestra un borde verde claro y se agranda un poco,
/// para que se vea desde lejos qué elemento está activo.
class TvFocusable extends StatefulWidget {
  final Widget child;
  final VoidCallback? onPressed;
  final BorderRadius borderRadius;
  final bool autofocus;
  final FocusNode? focusNode;

  /// Agrandamiento al estar seleccionado.
  final double focusScale;

  const TvFocusable({
    super.key,
    required this.child,
    required this.onPressed,
    this.borderRadius = const BorderRadius.all(Radius.circular(16)),
    this.autofocus = false,
    this.focusNode,
    this.focusScale = 1.05,
  });

  @override
  State<TvFocusable> createState() => _TvFocusableState();
}

class _TvFocusableState extends State<TvFocusable> {
  bool _focused = false;

  @override
  Widget build(BuildContext context) {
    return FocusableActionDetector(
      focusNode: widget.focusNode,
      autofocus: widget.autofocus,
      enabled: widget.onPressed != null,
      shortcuts: Tv.activateShortcuts,
      actions: {
        ActivateIntent: CallbackAction<ActivateIntent>(
          onInvoke: (_) {
            widget.onPressed?.call();
            return null;
          },
        ),
      },
      onShowFocusHighlight: (v) => setState(() => _focused = v),
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: widget.onPressed,
        child: AnimatedScale(
          scale: _focused ? widget.focusScale : 1.0,
          duration: const Duration(milliseconds: 150),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 150),
            decoration: BoxDecoration(
              borderRadius: widget.borderRadius,
              border: Border.all(
                color: _focused ? AppColors.accent : Colors.transparent,
                width: 3,
              ),
              color: _focused
                  ? AppColors.primary.withValues(alpha: 0.22)
                  : Colors.transparent,
              boxShadow: _focused
                  ? [
                      BoxShadow(
                        color: AppColors.primary.withValues(alpha: 0.45),
                        blurRadius: 18,
                      ),
                    ]
                  : null,
            ),
            child: widget.child,
          ),
        ),
      ),
    );
  }
}
