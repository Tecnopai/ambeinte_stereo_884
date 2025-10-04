import 'package:flutter/material.dart';
import '../services/audio_player_manager.dart';
import '../widgets/animated_disc.dart';
import '../widgets/volume_control.dart';
import '../widgets/sound_waves.dart';
import '../core/theme/app_colors.dart';

class RadioPlayerScreen extends StatefulWidget {
  final AudioPlayerManager audioManager;

  const RadioPlayerScreen({super.key, required this.audioManager});

  @override
  State<RadioPlayerScreen> createState() => _RadioPlayerScreenState();
}

class _RadioPlayerScreenState extends State<RadioPlayerScreen>
    with TickerProviderStateMixin {
  bool _isPlaying = true;
  bool _isLoading = true;
  double _volume = 0.7;

  @override
  void initState() {
    super.initState();
    _setupListeners();
    _initializeStates();
  }

  void _setupListeners() {
    widget.audioManager.playingStream.listen((isPlaying) {
      if (mounted) {
        setState(() {
          _isPlaying = isPlaying;
        });
      }
    });

    widget.audioManager.loadingStream.listen((isLoading) {
      if (mounted) {
        setState(() {
          _isLoading = isLoading;
        });
      }
    });

    widget.audioManager.volumeStream.listen((volume) {
      if (mounted) {
        setState(() {
          _volume = volume;
        });
      }
    });
  }

  void _initializeStates() {
    _isPlaying = widget.audioManager.isPlaying;
    _isLoading = widget.audioManager.isLoading;
    _volume = widget.audioManager.volume;
  }

  Future<void> _togglePlayback() async {
    try {
      await widget.audioManager.togglePlayback();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Error al conectar con la radio'),
            backgroundColor: AppColors.error,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    // Obtener información del dispositivo
    final screenSize = MediaQuery.of(context).size;
    final isTablet = screenSize.shortestSide >= 600;
    final textScale = MediaQuery.of(context).textScaler.scale(1.0);

    // Calcular tamaños dinámicos
    final padding = isTablet ? 32.0 : 20.0;
    final titleFontSize =
        (isTablet ? 14.0 : 10.0) * textScale; // Aumentado significativamente
    final subtitleFontSize = (isTablet ? 12.0 : 10.0) * textScale; // Aumentado
    final playButtonSize = isTablet ? 100.0 : 80.0;
    final playIconSize = isTablet ? 50.0 : 40.0;
    final loadingSize = isTablet ? 40.0 : 30.0;

    // Espaciados adaptativos
    final topSpacing = isTablet ? 80.0 : 60.0;
    final sectionSpacing = isTablet ? 50.0 : 40.0;
    final smallSpacing = isTablet ? 16.0 : 12.0;
    //Titulo player
    return Scaffold(
      appBar: AppBar(
        title: Text(
          'Ambiente Stereo 88.4 FM',
          style: TextStyle(
            fontSize: (isTablet ? 16.0 : 14.0) * textScale,
            fontWeight: FontWeight.w600,
          ),
        ),
        centerTitle: true,
      ),
      body: Container(
        width: double.infinity,
        height: double.infinity,
        decoration: const BoxDecoration(gradient: AppColors.primaryGradient),
        child: SingleChildScrollView(
          padding: EdgeInsets.all(padding),
          child: ConstrainedBox(
            constraints: BoxConstraints(
              minHeight:
                  screenSize.height -
                  (AppBar().preferredSize.height +
                      MediaQuery.of(context).padding.top +
                      padding * 2),
            ),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                SizedBox(height: topSpacing),

                // Logo/Disco animado
                AnimatedDisc(isPlaying: _isPlaying),

                SizedBox(height: sectionSpacing),

                // Título
                Text(
                  'Ambiente Stereo 88.4 FM',
                  style: TextStyle(
                    fontSize: titleFontSize,
                    fontWeight: FontWeight.bold,
                    color: AppColors.textPrimary,
                    letterSpacing: 0.5,
                  ),
                  textAlign: TextAlign.center,
                ),

                SizedBox(height: smallSpacing),

                // Subtítulo
                Text(
                  _isPlaying ? 'En vivo ahora' : 'La radio que si quieres',
                  style: TextStyle(
                    fontSize: subtitleFontSize,
                    color: AppColors.textMuted,
                    letterSpacing: 0.3,
                  ),
                  textAlign: TextAlign.center,
                ),

                SizedBox(height: sectionSpacing),

                // Ondas de sonido animadas
                if (_isPlaying)
                  Padding(
                    padding: EdgeInsets.symmetric(vertical: isTablet ? 30 : 20),
                    child: SoundWaves(isPlaying: _isPlaying),
                  ),

                SizedBox(height: sectionSpacing),

                // Control de reproducción
                _buildPlayButton(
                  size: playButtonSize,
                  iconSize: playIconSize,
                  loadingSize: loadingSize,
                  isTablet: isTablet,
                ),

                SizedBox(height: sectionSpacing + 10),

                // Control de volumen
                VolumeControl(
                  volume: _volume,
                  audioManager: widget.audioManager,
                ),

                SizedBox(height: sectionSpacing),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildPlayButton({
    required double size,
    required double iconSize,
    required double loadingSize,
    required bool isTablet,
  }) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: AppColors.buttonGradient,
        boxShadow: [
          BoxShadow(
            color: const Color.fromARGB(77, 203, 203, 229),
            blurRadius: isTablet ? 20 : 15,
            spreadRadius: isTablet ? 3 : 2,
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(size / 2),
          onTap: _togglePlayback,
          child: Center(
            child: _isLoading
                ? SizedBox(
                    width: loadingSize,
                    height: loadingSize,
                    child: CircularProgressIndicator(
                      color: AppColors.textPrimary,
                      strokeWidth: isTablet ? 4 : 3,
                    ),
                  )
                : Icon(
                    _isPlaying ? Icons.pause : Icons.play_arrow,
                    color: AppColors.textPrimary,
                    size: iconSize,
                  ),
          ),
        ),
      ),
    );
  }
}
