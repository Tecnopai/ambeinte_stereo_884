import 'package:flutter/material.dart';
import 'package:firebase_analytics/firebase_analytics.dart';
import 'theme/app_theme.dart';
import '../screens/splash_screen.dart';

/// Widget raíz de la aplicación Ambiente Stereo
class AmbientStereoApp extends StatefulWidget {
  const AmbientStereoApp({super.key});

  @override
  State<AmbientStereoApp> createState() => _AmbientStereoAppState();
}

// WidgetsBindingObserver para escuchar eventos de la app
class _AmbientStereoAppState extends State<AmbientStereoApp>
    with WidgetsBindingObserver {
  // Analytics
  static FirebaseAnalytics analytics = FirebaseAnalytics.instance;
  static FirebaseAnalyticsObserver observer = FirebaseAnalyticsObserver(
    analytics: analytics,
  );

  @override
  void initState() {
    super.initState();

    // Registra esta clase para que escuche el ciclo de vida de la app
    WidgetsBinding.instance.addObserver(this);

    // El singleton se inicializa automáticamente cuando cualquier pantalla lo necesite
  }

  // Limpia el observador cuando la app se cierre
  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  // Se ejecuta cada vez que la app cambia de estado
  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    // Si la app vuelve a primer plano, enviamos un evento para mantener al usuario activo
    if (state == AppLifecycleState.resumed) {
      analytics.logEvent(name: 'app_resumed');
    }
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Ambiente Stereo 88.4 FM',
      theme: AppTheme.darkTheme,
      debugShowCheckedModeBanner: false,
      // Observer de Firebase Analytics
      navigatorObservers: [observer],
      home: const SplashScreen(),
    );
  }
}
