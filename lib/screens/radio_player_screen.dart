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
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _setupListeners();
    _initializeStates();
  }

  void _setupListeners() {
    // Listener de reproducción
    widget.audioManager.playingStream.listen((isPlaying) {
      if (mounted) {
        setState(() {
          _isPlaying = isPlaying;
        });
      }
    });

    // Listener de carga
    widget.audioManager.loadingStream.listen((isLoading) {
      if (mounted) {
        setState(() {
          _isLoading = isLoading;
        });
      }
    });

    // Listener de volumen
    widget.audioManager.volumeStream.listen((volume) {
      if (mounted) {
        setState(() {
          _volume = volume;
        });
      }
    });

    // NUEVO: Listener de errores y reconexiones
    widget.audioManager.errorStream.listen((error) {
      if (mounted) {
        setState(() {
          _errorMessage = error;
        });

        // Mostrar SnackBar con el estado
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                if (error.contains('Reconectado'))
                  const Icon(Icons.check_circle, color: Colors.white)
                else
                  const Icon(Icons.info, color: Colors.white),
                const SizedBox(width: 8),
                Expanded(child: Text(error)),
              ],
            ),
            backgroundColor: error.contains('Reconectado')
                ? AppColors.success
                : AppColors.warning,
            duration: const Duration(seconds: 3),
          ),
        );

        // Limpiar mensaje después de 3 segundos
        Future.delayed(const Duration(seconds: 3), () {
          if (mounted) {
            setState(() {
              _errorMessage = null;
            });
          }
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
    final screenSize = MediaQuery.of(context).size;
    final isTablet = screenSize.shortestSide >= 600;
    final textScale = MediaQuery.of(context).textScaler.scale(1.0);

    final padding = isTablet ? 32.0 : 20.0;
    final titleFontSize = (isTablet ? 14.0 : 10.0) * textScale;
    final subtitleFontSize = (isTablet ? 12.0 : 10.0) * textScale;
    final playButtonSize = isTablet ? 100.0 : 80.0;
    final playIconSize = isTablet ? 50.0 : 40.0;
    final loadingSize = isTablet ? 40.0 : 30.0;

    final topSpacing = isTablet ? 80.0 : 60.0;
    final sectionSpacing = isTablet ? 50.0 : 40.0;
    final smallSpacing = isTablet ? 16.0 : 12.0;

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
        // NUEVO: Indicador de reconexión en el AppBar
        actions: [
          if (_errorMessage != null)
            Padding(
              padding: const EdgeInsets.only(right: 16),
              child: Center(child: _buildReconnectingIndicator(isTablet)),
            ),
        ],
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

                // NUEVO: Subtítulo con estado mejorado
                _buildStatusText(subtitleFontSize),

                SizedBox(height: sectionSpacing),

                // Ondas de sonido animadas
                if (_isPlaying && !_isLoading)
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

  // NUEVO: Widget para mostrar el estado actual
  Widget _buildStatusText(double fontSize) {
    String statusText;
    Color statusColor;

    if (_isLoading) {
      statusText = 'Conectando...';
      statusColor = AppColors.warning;
    } else if (_isPlaying) {
      statusText = 'En vivo ahora';
      statusColor = AppColors.success;
    } else {
      statusText = 'La radio que si quieres';
      statusColor = AppColors.textMuted;
    }

    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        if (_isLoading || _isPlaying)
          Container(
            width: 8,
            height: 8,
            margin: const EdgeInsets.only(right: 8),
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: statusColor,
              boxShadow: [
                BoxShadow(
                  color: statusColor.withOpacity(0.5),
                  blurRadius: 8,
                  spreadRadius: 2,
                ),
              ],
            ),
          ),
        Text(
          statusText,
          style: TextStyle(
            fontSize: fontSize,
            color: statusColor,
            letterSpacing: 0.3,
            fontWeight: _isLoading ? FontWeight.w600 : FontWeight.normal,
          ),
          textAlign: TextAlign.center,
        ),
      ],
    );
  }

  // NUEVO: Indicador de reconexión en el AppBar
  Widget _buildReconnectingIndicator(bool isTablet) {
    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: isTablet ? 12 : 8,
        vertical: isTablet ? 6 : 4,
      ),
      decoration: BoxDecoration(
        color: AppColors.warning.withOpacity(0.2),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.warning.withOpacity(0.5), width: 1),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          SizedBox(
            width: isTablet ? 14 : 12,
            height: isTablet ? 14 : 12,
            child: CircularProgressIndicator(
              strokeWidth: 2,
              valueColor: AlwaysStoppedAnimation<Color>(AppColors.warning),
            ),
          ),
          SizedBox(width: isTablet ? 8 : 6),
          Text(
            'Reconectando...',
            style: TextStyle(
              fontSize: isTablet ? 12 : 10,
              color: AppColors.warning,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
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
