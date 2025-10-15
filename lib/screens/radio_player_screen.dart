import 'package:flutter/material.dart';
import '../services/audio_player_manager.dart';
import '../widgets/animated_disc.dart';
import '../widgets/volume_control.dart';
import '../widgets/sound_waves.dart';
import '../core/theme/app_colors.dart';

/// Pantalla principal del reproductor de radio
/// Muestra controles de reproducción, animaciones visuales y estado de conexión
/// Incluye disco animado, ondas de sonido y control de volumen
class RadioPlayerScreen extends StatefulWidget {
  final AudioPlayerManager audioManager;

  const RadioPlayerScreen({super.key, required this.audioManager});

  @override
  State<RadioPlayerScreen> createState() => _RadioPlayerScreenState();
}

class _RadioPlayerScreenState extends State<RadioPlayerScreen>
    with TickerProviderStateMixin {
  // Estado de reproducción actual
  bool _isPlaying = true;

  // Indica si está cargando/conectando
  bool _isLoading = true;

  // Mensaje de error o reconexión
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _setupListeners();
    _initializeStates();
  }

  /// Configura los listeners para los diferentes streams del audio manager
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

    // Listener de errores y reconexiones
    widget.audioManager.errorStream.listen((error) {
      if (mounted) {
        setState(() {
          _errorMessage = error;
        });

        // Mostrar SnackBar con el estado de error o reconexión
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

  /// Inicializa los estados desde el audio manager
  void _initializeStates() {
    _isPlaying = widget.audioManager.isPlaying;
    _isLoading = widget.audioManager.isLoading;
  }

  /// Alterna entre reproducir y pausar la radio
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
    // Obtener información de pantalla para diseño responsivo
    final screenSize = MediaQuery.of(context).size;
    final isTablet = screenSize.shortestSide >= 600;
    final textScale = MediaQuery.of(context).textScaler.scale(1.0);

    // Tamaños responsivos
    final padding = isTablet ? 32.0 : 20.0;
    final titleFontSize = (isTablet ? 14.0 : 10.0) * textScale;
    final subtitleFontSize = (isTablet ? 12.0 : 10.0) * textScale;
    final playButtonSize = isTablet ? 100.0 : 80.0;
    final playIconSize = isTablet ? 50.0 : 40.0;
    final loadingSize = isTablet ? 40.0 : 30.0;

    // Espaciados responsivos
    final topSpacing = isTablet ? 80.0 : 60.0;
    final sectionSpacing = isTablet ? 40.0 : 30.0;
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
        // Indicador de reconexión en el AppBar
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

                // Logo/Disco animado que gira cuando está reproduciendo
                AnimatedDisc(isPlaying: _isPlaying),

                SizedBox(height: sectionSpacing),

                // Título de la emisora
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

                // Subtítulo con estado actual (Conectando/En vivo/Pausado)
                _buildStatusText(subtitleFontSize),

                SizedBox(height: sectionSpacing),

                // Ondas de sonido animadas (solo cuando está reproduciendo)
                if (_isPlaying && !_isLoading)
                  Padding(
                    padding: EdgeInsets.symmetric(vertical: isTablet ? 15 : 5),
                    child: SoundWaves(isPlaying: _isPlaying),
                  ),

                SizedBox(height: sectionSpacing),

                // Botón principal de reproducción/pausa
                _buildPlayButton(
                  size: playButtonSize,
                  iconSize: playIconSize,
                  loadingSize: loadingSize,
                  isTablet: isTablet,
                ),

                SizedBox(height: sectionSpacing + 10),

                // Control de volumen
                VolumeControl(audioManager: widget.audioManager),

                SizedBox(height: sectionSpacing),
              ],
            ),
          ),
        ),
      ),
    );
  }

  /// Construye el widget de texto de estado
  /// Muestra "Conectando...", "En vivo ahora" o "La radio que si quieres"
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
        // Indicador circular de estado (solo cuando está cargando o reproduciendo)
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
                  color: statusColor.withValues(alpha: 0.5),
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

  /// Construye el indicador de reconexión que aparece en el AppBar
  Widget _buildReconnectingIndicator(bool isTablet) {
    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: isTablet ? 12 : 8,
        vertical: isTablet ? 6 : 4,
      ),
      decoration: BoxDecoration(
        color: AppColors.warning.withValues(alpha: 0.2),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: AppColors.warning.withValues(alpha: 0.5),
          width: 1,
        ),
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

  /// Construye el botón circular de reproducción/pausa
  /// Muestra un indicador de carga cuando está conectando
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
                // Mostrar indicador de carga
                ? SizedBox(
                    width: loadingSize,
                    height: loadingSize,
                    child: CircularProgressIndicator(
                      color: AppColors.textPrimary,
                      strokeWidth: isTablet ? 4 : 3,
                    ),
                  )
                // Mostrar icono de play o pausa
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
