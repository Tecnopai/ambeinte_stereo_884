import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_analytics/firebase_analytics.dart';
import 'firebase_options.dart';
import 'core/app.dart';
import 'package:logger/logger.dart';

final logger = Logger();

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  try {
    // Configurar orientaciones
    SystemChrome.setPreferredOrientations([
      DeviceOrientation.portraitUp,
      DeviceOrientation.portraitDown,
      DeviceOrientation.landscapeLeft,
      DeviceOrientation.landscapeRight,
    ]);

    // Configurar barra de estado
    SystemChrome.setSystemUIOverlayStyle(
      const SystemUiOverlayStyle(
        statusBarColor: Colors.transparent,
        statusBarBrightness: Brightness.dark,
        statusBarIconBrightness: Brightness.light,
      ),
    );

    // Firebase + Analytics (UNA SOLA VEZ)
    await Firebase.initializeApp(
      options: DefaultFirebaseOptions.currentPlatform,
    );

    final analytics = FirebaseAnalytics.instance;
    await analytics.setAnalyticsCollectionEnabled(true);
    await analytics.logAppOpen();

    logger.i('[Main] ✅ Inicialización completa (Firebase + Analytics)');
  } catch (e) {
    logger.e('[Main] ❌ Error: $e');
  }

  runApp(const AmbientStereoApp());
}
