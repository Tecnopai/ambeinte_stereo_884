import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:firebase_core/firebase_core.dart';
import 'firebase_options.dart';
import 'core/app.dart';
import 'services/diagnostics_log.dart';
import 'utils/tv.dart';
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

  // Registro de diagnóstico local (solo en el teléfono, ver DiagnosticsLog).
  // No se espera: si tarda, los eventos se guardan cuando termine de cargar.
  DiagnosticsLog.instance.init();

  // ¿Televisor? Cambia la interfaz para usarla con el control remoto.
  await Tv.init();

  try {
    // Configurar orientaciones permitidas para la aplicación (vertical y horizontal).
    SystemChrome.setPreferredOrientations([
      DeviceOrientation.portraitUp,
      DeviceOrientation.portraitDown,
      DeviceOrientation.landscapeLeft,
      DeviceOrientation.landscapeRight,
    ]);

    // De borde a borde (Google lo pide desde Android 15): la app se dibuja
    // detrás de la barra de estado y de la de navegación, que quedan
    // transparentes con iconos claros. El espacio de cada barra lo dejan
    // SafeArea y el Scaffold.
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
    SystemChrome.setSystemUIOverlayStyle(
      const SystemUiOverlayStyle(
        statusBarColor: Colors.transparent,
        statusBarBrightness: Brightness.dark,
        statusBarIconBrightness: Brightness.light,
        systemNavigationBarColor: Colors.transparent,
        systemNavigationBarIconBrightness: Brightness.light,
        systemNavigationBarContrastEnforced: false,
      ),
    );

    // Inicialización de Firebase. Solo se usa Firestore para LEER la
    // configuración (URL del stream y versión). La app no recopila datos de
    // los usuarios: no hay Analytics ni ningún otro SDK de rastreo.
    await Firebase.initializeApp(
      options: DefaultFirebaseOptions.currentPlatform,
    );
  } catch (e) {
    // En caso de fallo de inicialización (ej. configuración incorrecta de Firebase),
    // se registra el error usando la instancia global del logger.
    logger.e('[Main] ❌ Error durante la inicialización de Firebase: $e');
  }

  // Inicia la ejecución del widget principal de la aplicación.
  runApp(const AmbientStereoApp());
}
