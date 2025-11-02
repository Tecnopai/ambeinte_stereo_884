import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:responsive_framework/responsive_framework.dart';
import '../core/theme/app_theme.dart';
import '../core/theme/app_colors.dart';

/// ============================================================================
/// Clase: VersionChecker
/// ----------------------------------------------------------------------------
/// Responsable de verificar si existe una versión más reciente de la aplicación
/// en Firebase Firestore. Si hay una actualización disponible, muestra un
/// cuadro de diálogo invitando al usuario a actualizar.
///
/// Estructura esperada en Firestore:
///   Colección: app_config
///   Documento: version_info
///   Campos:
///     - latest_version : string (ej. "1.2.3")
///     - update_url     : string (link a Play Store o App Gallery)
/// ============================================================================
class VersionChecker {
  /// Verifica la versión actual de la app contra la versión publicada en Firestore.
  /// Si hay una versión más reciente, muestra un diálogo de actualización.
  static Future<void> checkVersion(BuildContext context) async {
    try {
      // ------------------------------------------------------------------------
      // 1. Obtener la versión local instalada (del paquete actual)
      // ------------------------------------------------------------------------
      final packageInfo = await PackageInfo.fromPlatform();
      final localVersion = packageInfo.version;

      // ------------------------------------------------------------------------
      // 2. Consultar la versión más reciente almacenada en Firestore
      // ------------------------------------------------------------------------
      final snapshot = await FirebaseFirestore.instance
          .collection('app_config')
          .doc('version_info')
          .get();

      // Si no existe el documento, salir sin hacer nada
      if (!snapshot.exists) return;

      final data = snapshot.data();
      final latestVersion = data?['latest_version'] ?? localVersion;
      final updateUrl = data?['update_url'];

      // ------------------------------------------------------------------------
      // 3. Comparar versiones y decidir si se requiere actualización
      // ------------------------------------------------------------------------
      if (_isVersionNewer(latestVersion, localVersion)) {
        // Programamos la apertura del diálogo en el siguiente frame de la UI
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (context.mounted) {
            _showUpdateDialog(context, latestVersion, updateUrl);
          }
        });
      }
    } catch (e) {
      // Captura y registro de errores en consola (útil para debug o Crashlytics)
      debugPrint('Error verificando versión: $e');
    }
  }

  /// --------------------------------------------------------------------------
  /// Determina si la versión remota es más reciente que la versión local.
  /// Compara cada segmento de versión (ej. 1.2.3 vs 1.1.9).
  /// --------------------------------------------------------------------------
  static bool _isVersionNewer(String remote, String local) {
    final r = remote.split('.').map(int.parse).toList();
    final l = local.split('.').map(int.parse).toList();

    for (int i = 0; i < r.length; i++) {
      if (r[i] > l[i]) return true;
      if (r[i] < l[i]) return false;
    }
    return false;
  }

  /// --------------------------------------------------------------------------
  /// Muestra un cuadro de diálogo que notifica al usuario sobre una nueva
  /// versión disponible. Permite actualizar o posponer la acción.
  /// --------------------------------------------------------------------------
  static void _showUpdateDialog(
    BuildContext context,
    String newVersion,
    String? url,
  ) {
    showDialog(
      context: context,
      barrierDismissible: false,
      barrierColor: Colors.black.withValues(alpha: 0.6),
      builder: (_) {
        final theme = Theme.of(context);
        final borderRadius = AppTheme.getResponsiveBorderRadius(
          context,
          baseRadius: 16,
        );

        // Obtener el tamaño de la pantalla
        final screenHeight = MediaQuery.of(context).size.height;
        final isSmallScreen = ResponsiveBreakpoints.of(context).isMobile;

        // Ajustar padding según el tamaño de pantalla
        final horizontalPadding = isSmallScreen ? 16.0 : 24.0;
        final verticalPadding = isSmallScreen ? 16.0 : 20.0;
        final iconSize = isSmallScreen ? 28.0 : 36.0;
        final iconPadding = isSmallScreen ? 10.0 : 12.0;

        return Dialog(
          backgroundColor: AppColors.surface,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(borderRadius),
          ),
          elevation: 8,
          insetPadding: EdgeInsets.symmetric(
            horizontal: isSmallScreen ? 16 : 40,
            vertical: 24,
          ),
          child: ConstrainedBox(
            constraints: BoxConstraints(
              maxHeight: screenHeight * 0.8, // Máximo 80% de la altura
              maxWidth: isSmallScreen ? double.infinity : 400,
            ),
            child: SingleChildScrollView(
              child: Container(
                decoration: BoxDecoration(
                  gradient: AppColors.getCardGradient(context),
                  borderRadius: BorderRadius.circular(borderRadius),
                  boxShadow: [
                    BoxShadow(
                      color: AppColors.getShadowColor(context, opacity: 0.25),
                      blurRadius: 12,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                padding: EdgeInsets.symmetric(
                  horizontal: horizontalPadding,
                  vertical: verticalPadding,
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    // Ícono decorativo
                    Container(
                      decoration: const BoxDecoration(
                        shape: BoxShape.circle,
                        gradient: AppColors.buttonGradient,
                      ),
                      padding: EdgeInsets.all(iconPadding),
                      child: Icon(
                        Icons.system_update,
                        color: Colors.white,
                        size: iconSize,
                      ),
                    ),
                    SizedBox(height: isSmallScreen ? 12 : 16),
                    Text(
                      'Actualización disponible',
                      style: theme.textTheme.titleLarge?.copyWith(
                        color: AppColors.textPrimary,
                        fontWeight: FontWeight.bold,
                        fontSize: isSmallScreen ? 18 : 22,
                      ),
                      textAlign: TextAlign.center,
                    ),
                    SizedBox(height: isSmallScreen ? 8 : 12),
                    Text(
                      'Se ha lanzado una nueva versión ($newVersion).\n\n'
                      'Actualiza ahora para disfrutar de las mejoras y correcciones más recientes.',
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: AppColors.textMuted,
                        height: 1.4,
                        fontSize: isSmallScreen ? 13 : 14,
                      ),
                      textAlign: TextAlign.center,
                    ),
                    SizedBox(height: isSmallScreen ? 16 : 24),
                    // Botones adaptativos
                    isSmallScreen
                        ? Column(
                            mainAxisSize: MainAxisSize.min,
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              //boton actualizar
                              ElevatedButton(
                                style: ElevatedButton.styleFrom(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 28,
                                    vertical: 12,
                                  ),
                                  backgroundColor: AppColors.primary,
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                ),
                                onPressed: () async {
                                  if (url != null &&
                                      await canLaunchUrl(Uri.parse(url))) {
                                    await launchUrl(
                                      Uri.parse(url),
                                      mode: LaunchMode.externalApplication,
                                    );
                                  }
                                },
                                child: const Text(
                                  'Actualizar',
                                  style: TextStyle(fontWeight: FontWeight.bold),
                                ),
                              ),
                              // Boton Mas tarde
                              /*const SizedBox(height: 8),
                              TextButton(
                                style: TextButton.styleFrom(
                                  foregroundColor: AppColors.textSecondary,
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 20,
                                    vertical: 10,
                                  ),
                                ),
                                onPressed: () => Navigator.pop(context),
                                child: const Text('Más tarde'),
                              ),*/
                            ],
                          )
                        : Row(
                            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                            children: [
                              // Botón "Más tarde"
                              TextButton(
                                style: TextButton.styleFrom(
                                  foregroundColor: AppColors.textSecondary,
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 20,
                                    vertical: 10,
                                  ),
                                ),
                                onPressed: () => Navigator.pop(context),
                                child: const Text('Más tarde'),
                              ),

                              // Botón "Actualizar"
                              ElevatedButton(
                                style: ElevatedButton.styleFrom(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 28,
                                    vertical: 12,
                                  ),
                                  backgroundColor: AppColors.primary,
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                ),
                                onPressed: () async {
                                  if (url != null &&
                                      await canLaunchUrl(Uri.parse(url))) {
                                    await launchUrl(
                                      Uri.parse(url),
                                      mode: LaunchMode.externalApplication,
                                    );
                                  }
                                },
                                child: const Text(
                                  'Actualizar',
                                  style: TextStyle(fontWeight: FontWeight.bold),
                                ),
                              ),
                            ],
                          ),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}
