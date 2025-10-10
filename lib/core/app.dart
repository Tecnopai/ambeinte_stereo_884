import 'package:flutter/material.dart';
import 'theme/app_theme.dart';
import '../services/audio_player_manager.dart';
import '../screens/splash_screen.dart';

class AmbientStereoApp extends StatefulWidget {
  const AmbientStereoApp({super.key});

  @override
  State<AmbientStereoApp> createState() => _AmbientStereoAppState();
}

class _AmbientStereoAppState extends State<AmbientStereoApp> {
  // ✅ Crear UNA SOLA instancia del AudioPlayerManager aquí
  late final AudioPlayerManager _audioManager;

  @override
  void initState() {
    super.initState();
    // Inicializar el singleton
    _audioManager = AudioPlayerManager();
    _audioManager.init();

    // Log de diagnóstico
    debugPrint('🎵 AudioPlayerManager inicializado: ${_audioManager.hashCode}');
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Ambiente Stereo 88.4 FM',
      theme: AppTheme.darkTheme,
      debugShowCheckedModeBanner: false,
      // ✅ Pasar la instancia al SplashScreen
      home: SplashScreen(audioManager: _audioManager),
    );
  }
}
