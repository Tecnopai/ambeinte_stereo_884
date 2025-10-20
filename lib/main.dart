import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'core/app.dart';

/// Punto de entrada principal de la aplicación Ambiente Stereo
/// Configura las orientaciones permitidas y el estilo de la barra de estado
void main() async {
  // Asegurar que los bindings de Flutter estén inicializados
  WidgetsFlutterBinding.ensureInitialized();

  // Configurar orientación de pantalla
  await SystemChrome.setPreferredOrientations([
    DeviceOrientation.portraitUp,
    DeviceOrientation.portraitDown,
    DeviceOrientation.landscapeLeft,
    DeviceOrientation.landscapeRight,
  ]);

  // Configurar estilo de la barra de estado del sistema
  SystemChrome.setSystemUIOverlayStyle(
    const SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      statusBarBrightness: Brightness.dark,
      statusBarIconBrightness: Brightness.light,
    ),
  );

  // Iniciar la aplicación
  runApp(const AmbientStereoApp());
}
