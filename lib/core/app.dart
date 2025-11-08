import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'dart:io';
import 'package:firebase_analytics/firebase_analytics.dart';
import 'package:responsive_framework/responsive_framework.dart';
// Importa el tema de la aplicación.
import 'theme/app_theme.dart';
// Importa la pantalla inicial de la aplicación.
import '../screens/splash_screen.dart';

/// {@template ambient_stereo_app}
/// Widget raíz de la aplicación Ambiente Stereo 88.4 FM.
///
/// Este widget es un [StatefulWidget] que administra el estado del ciclo de vida
/// de la aplicación mediante [WidgetsBindingObserver] para fines de analítica.
/// {@endtemplate}
class AmbientStereoApp extends StatefulWidget {
  /// Constructor constante para [AmbientStereoApp].
  const AmbientStereoApp({super.key});

  @override
  State<AmbientStereoApp> createState() => _AmbientStereoAppState();
}

/// Estado asociado al widget [AmbientStereoApp].
///
/// Implementa [WidgetsBindingObserver] para escuchar los cambios en el estado
/// del ciclo de vida de la aplicación (ej. suspendida, reanudada, inactiva).
class _AmbientStereoAppState extends State<AmbientStereoApp>
    with WidgetsBindingObserver {
  // Instancia de Firebase Analytics para registrar eventos.
  static FirebaseAnalytics analytics = FirebaseAnalytics.instance;

  // Observador utilizado para registrar automáticamente los cambios de ruta
  // de navegación en Firebase Analytics.
  static FirebaseAnalyticsObserver observer = FirebaseAnalyticsObserver(
    analytics: analytics,
  );

  /// Inicializa el estado del widget.
  @override
  void initState() {
    super.initState();

    // Registra esta clase como observador del ciclo de vida de la aplicación.
    WidgetsBinding.instance.addObserver(this);

    // Nota: El singleton se inicializa automáticamente cuando cualquier pantalla lo necesite
  }

  /// Limpia el observador cuando el widget se cierra o se elimina.
  @override
  void dispose() {
    // Es crucial remover el observador para evitar fugas de memoria.
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  /// Se ejecuta cada vez que el estado del ciclo de vida de la aplicación cambia.
  ///
  /// @param state El nuevo estado del ciclo de vida ([AppLifecycleState]).
  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    // Si la aplicación vuelve a primer plano (resumed), se registra un evento en Analytics.
    if (state == AppLifecycleState.resumed) {
      analytics.logEvent(name: 'app_resumed');
    } else if (state == AppLifecycleState.paused) {
      // Podrías activar PiP automáticamente aquí
      _enterPipMode();
    }
  }

  // Método para entrar en PiP (solo Android)
  Future<void> _enterPipMode() async {
    if (Platform.isAndroid) {
      await MethodChannel('your_channel_name').invokeMethod('enterPipMode');
    }
  }

  /// Construye la interfaz de usuario principal de la aplicación.
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Ambiente Stereo 88.4 FM',
      // Aplica el tema oscuro definido en app_theme.dart.
      theme: AppTheme.darkTheme,
      // Desactiva la etiqueta de "DEBUG" en la esquina superior derecha.
      debugShowCheckedModeBanner: false,
      // Asigna el observador de Firebase Analytics al navegador de la aplicación.
      navigatorObservers: [observer],
      // La pantalla de inicio de la aplicación es la SplashScreen.
      home: const SplashScreen(),

      builder: (context, widget) => ResponsiveBreakpoints.builder(
        child: ClampingScrollWrapper.builder(context, widget!),
        breakpoints: [
          const Breakpoint(start: 0, end: 450, name: MOBILE),
          const Breakpoint(start: 451, end: 800, name: TABLET),
          const Breakpoint(start: 801, end: 1200, name: DESKTOP),
          const Breakpoint(start: 1201, end: double.infinity, name: '4K'),
        ],
      ),
    );
  }
}
