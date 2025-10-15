import 'package:flutter/material.dart';
import 'theme/app_theme.dart';
import '../services/audio_player_manager.dart';
import '../screens/splash_screen.dart';

/// Widget raíz de la aplicación Ambiente Stereo
///
/// Gestiona la inicialización del AudioPlayerManager y configura
/// el MaterialApp con el tema y la pantalla inicial
class AmbientStereoApp extends StatefulWidget {
  const AmbientStereoApp({super.key});

  @override
  State<AmbientStereoApp> createState() => _AmbientStereoAppState();
}

class _AmbientStereoAppState extends State<AmbientStereoApp> {
  /// Instancia única del gestor de reproducción de audio
  ///
  /// Se inicializa en initState y se mantiene durante toda
  /// la vida de la aplicación para garantizar una única
  /// instancia del reproductor de audio
  late final AudioPlayerManager _audioManager;

  @override
  void initState() {
    super.initState();

    // Inicializar el AudioPlayerManager singleton
    _audioManager = AudioPlayerManager();
    _audioManager.init();
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Ambiente Stereo 88.4 FM',
      theme: AppTheme.darkTheme,
      debugShowCheckedModeBanner: false,
      // Pasar la instancia del audioManager al SplashScreen
      home: SplashScreen(audioManager: _audioManager),
    );
  }
}
