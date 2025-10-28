import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_analytics/firebase_analytics.dart';
import 'firebase_options.dart';
import 'core/app.dart';
import 'package:logger/logger.dart';

/// Instancia global del logger para uso en toda la aplicación.
/// Se usa para registrar eventos, errores y depuración controlada.
final logger = Logger();

/// Función principal de entrada de la aplicación.
///
/// Inicializa las configuraciones críticas del framework (Bindings, Orientación, UI)
/// y configura los servicios de Firebase antes de ejecutar el widget principal.
void main() async {
  // Asegura que todos los bindings de widgets estén inicializados antes
  // de realizar operaciones asíncronas, como la inicialización de Firebase.
  WidgetsFlutterBinding.ensureInitialized();

  try {
    // Configurar orientaciones permitidas para la aplicación (vertical y horizontal).
    SystemChrome.setPreferredOrientations([
      DeviceOrientation.portraitUp,
      DeviceOrientation.portraitDown,
      DeviceOrientation.landscapeLeft,
      DeviceOrientation.landscapeRight,
    ]);

    // Configurar barra de estado del sistema (notch, hora, batería, etc.).
    SystemChrome.setSystemUIOverlayStyle(
      const SystemUiOverlayStyle(
        // Color transparente para la barra de estado.
        statusBarColor: Colors.transparent,
        // Brillo del contenido detrás de la barra de estado (normalmente oscuro).
        statusBarBrightness: Brightness.dark,
        // Color de los iconos de la barra de estado (claro/blanco).
        statusBarIconBrightness: Brightness.light,
      ),
    );

    // Inicialización de Firebase (requerido para todos los servicios como Analytics y Remote Config).
    await Firebase.initializeApp(
      options: DefaultFirebaseOptions.currentPlatform,
    );

    // Configuración inicial de Firebase Analytics.
    final analytics = FirebaseAnalytics.instance;
    // Habilita explícitamente la colección de datos de Analytics.
    await analytics.setAnalyticsCollectionEnabled(true);
    // Registra el evento de apertura de la aplicación.
    await analytics.logAppOpen();
  } catch (e) {
    // En caso de fallo de inicialización (ej. configuración incorrecta de Firebase),
    // se registra el error usando la instancia global del logger.
    logger.e('[Main] ❌ Error durante la inicialización de Firebase: $e');
  }

  // Inicia la ejecución del widget principal de la aplicación.
  runApp(const AmbientStereoApp());
}
