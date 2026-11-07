import 'package:flutter/material.dart';
import 'package:share_plus/share_plus.dart';

import '../core/theme/app_colors.dart';
import '../services/diagnostics_log.dart';

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
            TextField(
              controller: _descriptionController,
              maxLines: 3,
              textCapitalization: TextCapitalization.sentences,
              decoration: const InputDecoration(
                labelText: '¿Qué pasó? (opcional)',
                hintText: 'Ej.: con datos móviles se quedó reconectando',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 16),
            Builder(
              builder: (buttonContext) => ElevatedButton.icon(
                onPressed: _preview == null
                    ? null
                    : () => _send(buttonContext),
                icon: const Icon(Icons.send),
                label: const Text('Enviar reporte'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  foregroundColor: AppColors.textPrimary,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                ),
              ),
            ),
            const SizedBox(height: 24),
            const Text(
              'Esto es lo que se enviará:',
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: AppColors.textSecondary,
              ),
            ),
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
        ),
      ),
    );
  }
}
