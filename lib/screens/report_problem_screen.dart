import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:share_plus/share_plus.dart';

import '../core/theme/app_colors.dart';
import '../services/diagnostics_log.dart';
import '../utils/tv.dart';

/// Correo al que se pide enviar el reporte.
const String supportEmail = 'tecnologia@iglesiacristianapai.org';

/// Pantalla para que el usuario envíe, si quiere, el registro de diagnóstico.
///
/// Muestra exactamente lo que se va a enviar. Nada sale del teléfono hasta que
/// el usuario pulsa "Enviar reporte" y elige con qué app compartirlo (correo,
/// WhatsApp...).
class ReportProblemScreen extends StatefulWidget {
  const ReportProblemScreen({super.key});

  /// Abre esta pantalla.
  static Future<void> open(BuildContext context) {
    return Navigator.of(
      context,
    ).push(MaterialPageRoute(builder: (_) => const ReportProblemScreen()));
  }

  /// Si la sesión anterior terminó con la radio fallando (y no se ha
  /// preguntado en los últimos 7 días), ofrece enviar un reporte con un aviso
  /// discreto en la parte inferior.
  static Future<void> offerIfPreviousSessionFailed(BuildContext context) async {
    final log = DiagnosticsLog.instance;
    if (!await log.shouldOfferReport()) return;
    if (!context.mounted) return;
    await log.markReportOffered();
    if (!context.mounted) return;

    final messenger = ScaffoldMessenger.of(context);
    messenger.showSnackBar(
      SnackBar(
        content: const Text(
          'La última vez la radio tuvo problemas para conectar. '
          '¿Nos ayudas enviando un reporte?',
        ),
        duration: const Duration(seconds: 15),
        behavior: SnackBarBehavior.floating,
        showCloseIcon: true,
        action: SnackBarAction(
          label: 'Enviar reporte',
          textColor: AppColors.accent,
          onPressed: () {
            if (context.mounted) open(context);
          },
        ),
      ),
    );
  }

  @override
  State<ReportProblemScreen> createState() => _ReportProblemScreenState();
}

class _ReportProblemScreenState extends State<ReportProblemScreen> {
  final TextEditingController _descriptionController = TextEditingController();
  String? _preview;

  /// El registro técnico solo se muestra si el usuario lo pide.
  bool _showDetails = false;

  /// TV: el usuario presionó OK sobre el cuadro de texto y está escribiendo.
  bool _tvEditing = false;

  @override
  void initState() {
    super.initState();
    _loadPreview();
  }

  @override
  void dispose() {
    _descriptionController.dispose();
    super.dispose();
  }

  Future<void> _loadPreview() async {
    final report = await DiagnosticsLog.instance.buildReport();
    if (mounted) setState(() => _preview = report);
  }

  Future<void> _send(BuildContext buttonContext) async {
    final report = await DiagnosticsLog.instance.buildReport(
      description: _descriptionController.text,
    );
    if (!buttonContext.mounted) return;

    // Un televisor no tiene correo ni WhatsApp: se muestra un QR que abre el
    // correo del celular con el reporte ya escrito. Nada sale del televisor.
    if (Tv.isTv) {
      await _showTvQr(buttonContext, report);
      return;
    }

    // En iPad el menú de compartir necesita saber desde dónde se abre.
    final box = buttonContext.findRenderObject() as RenderBox?;
    await SharePlus.instance.share(
      ShareParams(
        text: 'Para: $supportEmail\n\n$report',
        subject: 'Reporte de problema - App Ambiente Stereo 88.4',
        sharePositionOrigin: box == null
            ? null
            : box.localToGlobal(Offset.zero) & box.size,
      ),
    );
  }

  /// Máximo de caracteres del enlace dentro del QR, para que se pueda
  /// escanear desde el televisor (un QR admite unos 2.900 como máximo).
  static const int _maxQrLength = 1200;

  /// Enlace `mailto:` con el reporte. Si es muy largo, se quitan los eventos
  /// más viejos: los últimos son los que sirven para encontrar la falla.
  static String _mailtoForQr(String report) {
    String build(String body) =>
        'mailto:$supportEmail'
        '?subject=${Uri.encodeComponent('Reporte de problema - App Ambiente Stereo 88.4 (TV)')}'
        '&body=${Uri.encodeComponent(body)}';

    final lines = report.split('\n');
    final eventsAt = lines.indexWhere((l) => l.startsWith('Últimos eventos'));
    var start = eventsAt < 0 ? 0 : eventsAt + 1;
    var link = build(report);
    while (link.length > _maxQrLength && start < lines.length - 1) {
      lines.removeAt(start);
      link = build(lines.join('\n'));
    }
    return link;
  }

  Future<void> _showTvQr(BuildContext context, String report) {
    return showDialog<void>(
      context: context,
      builder: (context) => Dialog(
        backgroundColor: AppColors.surface,
        insetPadding: const EdgeInsets.all(16),
        child: SizedBox(
          width: 680,
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Row(
              children: [
                Container(
                  color: Colors.white,
                  padding: const EdgeInsets.all(10),
                  child: QrImageView(
                    data: _mailtoForQr(report),
                    size: 300,
                    padding: EdgeInsets.zero,
                    errorCorrectionLevel: QrErrorCorrectLevel.L,
                  ),
                ),
                const SizedBox(width: 28),
                Expanded(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Escanéalo con tu celular',
                        style: TextStyle(
                          color: AppColors.textPrimary,
                          fontSize: 24,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(height: 14),
                      const Text(
                        'Apunta la cámara del celular a este código. Se abrirá '
                        'tu correo con el reporte ya escrito: solo tienes que '
                        'enviarlo.\n\nSi no se abre, escríbenos a\n'
                        '$supportEmail',
                        style: TextStyle(
                          color: AppColors.textMuted,
                          fontSize: 15,
                          height: 1.4,
                        ),
                      ),
                      const SizedBox(height: 20),
                      Align(
                        alignment: Alignment.centerRight,
                        child: TextButton(
                          autofocus: true,
                          onPressed: () => Navigator.of(context).pop(),
                          child: const Text('Listo'),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  /// En TV, arriba y abajo salen del cuadro de texto (no mueven el cursor),
  /// para poder llegar al botón con el control remoto.
  Widget _tvTextField(Widget field) {
    if (!Tv.isTv) return field;
    return Focus(
      canRequestFocus: false,
      skipTraversal: true,
      onFocusChange: (inside) {
        // Al salir del cuadro se deja de escribir (se cierra el teclado).
        if (!inside && _tvEditing) setState(() => _tvEditing = false);
      },
      onKeyEvent: (node, event) {
        if (event is! KeyDownEvent) return KeyEventResult.ignored;
        // OK sobre el cuadro: recién ahí se abre el teclado del televisor.
        final ok =
            event.logicalKey == LogicalKeyboardKey.select ||
            event.logicalKey == LogicalKeyboardKey.enter;
        if (ok && !_tvEditing) {
          setState(() => _tvEditing = true);
          WidgetsBinding.instance.addPostFrameCallback((_) {
            SystemChannels.textInput.invokeMethod<void>('TextInput.show');
          });
          return KeyEventResult.handled;
        }
        final direction = switch (event.logicalKey) {
          LogicalKeyboardKey.arrowDown => TraversalDirection.down,
          LogicalKeyboardKey.arrowUp => TraversalDirection.up,
          _ => null,
        };
        if (direction == null) return KeyEventResult.ignored;
        FocusManager.instance.primaryFocus?.focusInDirection(direction);
        return KeyEventResult.handled;
      },
      child: field,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Reportar un problema')),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            const Text(
              'Si la radio se corta o se queda reconectando, puedes enviarnos '
              'este reporte para ayudarnos a encontrar la falla.',
              style: TextStyle(fontSize: 15, color: AppColors.textPrimary),
            ),
            const SizedBox(height: 8),
            const Text(
              'Solo contiene datos técnicos de la app: versión, modelo del '
              'teléfono y los últimos eventos de la radio. No incluye tu '
              'nombre, ubicación ni otros datos personales, y solo se envía si '
              'tú lo decides. Envíalo por correo a $supportEmail.',
              style: TextStyle(fontSize: 13, color: AppColors.textMuted),
            ),
            const SizedBox(height: 16),
            _tvTextField(
              TextField(
                controller: _descriptionController,
                // En TV el teclado se abre solo al presionar OK sobre el
                // cuadro; mientras tanto se puede pasar por encima.
                readOnly: Tv.isTv && !_tvEditing,
                maxLines: 3,
                textCapitalization: TextCapitalization.sentences,
                decoration: const InputDecoration(
                  labelText: '¿Qué pasó? (opcional)',
                  hintText: 'Ej.: con datos móviles se quedó reconectando',
                  border: OutlineInputBorder(),
                ),
              ),
            ),
            const SizedBox(height: 16),
            Builder(
              builder: (buttonContext) => ElevatedButton.icon(
                onPressed: _preview == null ? null : () => _send(buttonContext),
                icon: const Icon(Icons.send),
                label: const Text('Enviar reporte'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  foregroundColor: AppColors.textPrimary,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                ),
              ),
            ),
            const SizedBox(height: 16),
            // El detalle técnico queda oculto: quien quiera revisarlo antes
            // de enviarlo, lo abre.
            Center(
              child: TextButton.icon(
                onPressed: () => setState(() => _showDetails = !_showDetails),
                style: TextButton.styleFrom(
                  foregroundColor: AppColors.textSecondary,
                ),
                icon: Icon(
                  _showDetails
                      ? Icons.keyboard_arrow_up_rounded
                      : Icons.keyboard_arrow_down_rounded,
                ),
                label: Text(
                  _showDetails
                      ? 'Ocultar lo que se enviará'
                      : 'Ver lo que se enviará',
                ),
              ),
            ),
            if (_showDetails) ...[
              const SizedBox(height: 8),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: AppColors.surfaceVariant,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: _preview == null
                    ? const Center(child: CircularProgressIndicator())
                    : SelectableText(
                        _preview!,
                        style: const TextStyle(
                          fontFamily: 'monospace',
                          fontSize: 11,
                          color: AppColors.textMuted,
                        ),
                      ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
