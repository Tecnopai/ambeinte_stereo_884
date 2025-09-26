import 'package:flutter/material.dart';
import 'theme/app_theme.dart';
import '../screens/splash_screen.dart'; // Agregar import

class AmbientStereoApp extends StatelessWidget {
  const AmbientStereoApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Ambient Stereo 88.4 FM',
      theme: AppTheme.darkTheme,
      home: const SplashScreen(), // Cambiar de MainScreen a SplashScreen
      debugShowCheckedModeBanner: false,
    );
  }
}
