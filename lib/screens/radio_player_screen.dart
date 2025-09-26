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
    return Scaffold(
      appBar: AppBar(
        title: const Text('Ambient Stereo 88.4 FM'),
        centerTitle: true,
      ),
      body: Container(
        width: double.infinity,
        height: double.infinity,
        decoration: const BoxDecoration(gradient: AppColors.primaryGradient),
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(20.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const SizedBox(height: 60),
              // Logo/Disco animado
              AnimatedDisc(isPlaying: _isPlaying),
              const SizedBox(height: 40),
              // Título
              const Text(
                'Ambient Stereo 88.4 FM',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.bold,
                  color: AppColors.textPrimary,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 12),
              // Subtítulo
              Text(
                _isPlaying ? 'En vivo ahora' : 'La radio que si quieres',
                style: const TextStyle(
                  fontSize: 14,
                  color: AppColors.textMuted,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 40),
              // Ondas de sonido animadas
              if (_isPlaying)
                const Padding(
                  padding: EdgeInsets.symmetric(vertical: 20),
                  child: SoundWaves(),
                ),
              const SizedBox(height: 40),
              // Control de reproducción
              _buildPlayButton(),
              const SizedBox(height: 50),
              // Control de volumen
              VolumeControl(volume: _volume, audioManager: widget.audioManager),
              const SizedBox(height: 40),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildPlayButton() {
    return Container(
      width: 80,
      height: 80,
      decoration: const BoxDecoration(
        shape: BoxShape.circle,
        gradient: AppColors.buttonGradient,
        boxShadow: [
          BoxShadow(
            color: Color.fromARGB(77, 203, 203, 229),
            blurRadius: 15,
            spreadRadius: 2,
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(40),
          onTap: _togglePlayback,
          child: Center(
            child: _isLoading
                ? const SizedBox(
                    width: 30,
                    height: 30,
                    child: CircularProgressIndicator(
                      color: AppColors.textPrimary,
                      strokeWidth: 3,
                    ),
                  )
                : Icon(
                    _isPlaying ? Icons.pause : Icons.play_arrow,
                    color: AppColors.textPrimary,
                    size: 40,
                  ),
          ),
        ),
      ),
    );
  }
}
