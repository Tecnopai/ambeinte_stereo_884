import 'package:flutter/material.dart';
import '../services/audio_player_manager.dart';
import '../core/theme/app_colors.dart';

/// Mini reproductor flotante que aparece en la parte inferior de la pantalla
/// Muestra controles de reproducción, volumen y estado de la transmisión
/// Se desliza hacia arriba cuando está reproduciendo
class MiniPlayer extends StatefulWidget {
  final AudioPlayerManager audioManager;

  const MiniPlayer({super.key, required this.audioManager});

  @override
  State<MiniPlayer> createState() => _MiniPlayerState();
}

class _MiniPlayerState extends State<MiniPlayer> with TickerProviderStateMixin {
  // Estados del reproductor
  bool _isPlaying = false;
  bool _isLoading = false;
  double _volume = 0.7;
  bool _showVolumeSlider = false;

  // Controladores de animación
  late AnimationController _slideController;
  late Animation<Offset> _slideAnimation;
  late AnimationController _pulseController;
  late Animation<double> _pulseAnimation;

  @override
  void initState() {
    super.initState();
    _initializeAnimations();
    _setupListeners();
    _initializeStates();
  }

  /// Inicializa las animaciones de deslizamiento y pulso
  void _initializeAnimations() {
    // Animación de deslizamiento vertical
    _slideController = AnimationController(
      duration: const Duration(milliseconds: 300),
      vsync: this,
    );

    _slideAnimation = Tween<Offset>(
      begin: const Offset(0, 1), // Comienza fuera de pantalla (abajo)
      end: Offset.zero, // Termina en posición normal
    ).animate(CurvedAnimation(parent: _slideController, curve: Curves.easeOut));

    // Animación de pulso para el icono de radio
    _pulseController = AnimationController(
      duration: const Duration(milliseconds: 1000),
      vsync: this,
    )..repeat(reverse: true);

    _pulseAnimation = Tween<double>(begin: 0.8, end: 1.2).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut),
    );
  }

  /// Configura los listeners para los streams del audio manager
  void _setupListeners() {
    // Listener de reproducción
    widget.audioManager.playingStream.listen((isPlaying) {
      if (mounted) {
        setState(() {
          _isPlaying = isPlaying;
        });

        // Animar entrada/salida del mini player
        if (_isPlaying) {
          _slideController.forward();
        } else {
          _slideController.reverse();
        }
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
  }

  /// Inicializa los estados desde el audio manager
  void _initializeStates() {
    _isPlaying = widget.audioManager.isPlaying;
    _isLoading = widget.audioManager.isLoading;
    _volume = widget.audioManager.volume;

    // Mostrar el mini player si está reproduciendo
    if (_isPlaying) {
      _slideController.forward();
    }
  }

  /// Alterna entre reproducir y pausar
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

    return SlideTransition(
      position: _slideAnimation,
      child: Container(
        constraints: BoxConstraints(
          minHeight: isTablet ? 80 : 70,
          maxHeight: isTablet ? 200 : 180,
        ),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [
              AppColors.surface.withValues(alpha: 0.95),
              AppColors.background.withValues(alpha: 0.95),
            ],
          ),
          borderRadius: BorderRadius.circular(isTablet ? 20 : 16),
          border: Border.all(
            color: AppColors.primary.withValues(alpha: 0.3),
            width: 1,
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.3),
              blurRadius: isTablet ? 15 : 10,
              spreadRadius: isTablet ? 3 : 2,
            ),
          ],
        ),
        child: Material(
          color: Colors.transparent,
          child: IntrinsicHeight(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                _buildMainControls(isTablet),
                if (_showVolumeSlider) _buildVolumeSlider(isTablet),
              ],
            ),
          ),
        ),
      ),
    );
  }

  /// Construye la fila principal de controles
  Widget _buildMainControls(bool isTablet) {
    return Flexible(
      child: Container(
        constraints: BoxConstraints(minHeight: isTablet ? 70 : 60),
        padding: EdgeInsets.all(isTablet ? 16 : 12),
        child: Row(
          children: [
            _buildRadioIcon(isTablet),
            SizedBox(width: isTablet ? 16 : 12),
            _buildRadioInfo(isTablet),
            _buildVolumeButton(isTablet),
            SizedBox(width: isTablet ? 12 : 8),
            _buildPlayButton(isTablet),
          ],
        ),
      ),
    );
  }

  /// Construye el icono circular de la radio con efecto de pulso
  Widget _buildRadioIcon(bool isTablet) {
    final iconSize = isTablet ? 56.0 : 48.0;

    return AnimatedBuilder(
      animation: _pulseAnimation,
      builder: (context, child) {
        return Transform.scale(
          scale: _isPlaying ? _pulseAnimation.value : 1.0,
          child: Container(
            width: iconSize,
            height: iconSize,
            decoration: const BoxDecoration(
              shape: BoxShape.circle,
              color: Colors.white,
            ),
            child: ClipOval(
              child: ColorFiltered(
                colorFilter: ColorFilter.mode(
                  AppColors.primary.withValues(alpha: 0.3),
                  BlendMode.srcOver,
                ),
                child: Image.asset(
                  'assets/images/ambiente_logo.png',
                  width: iconSize * 0.6,
                  height: iconSize * 0.6,
                  fit: BoxFit.cover,
                  errorBuilder: (context, error, stackTrace) {
                    return Icon(
                      Icons.radio,
                      color: AppColors.textPrimary,
                      size: iconSize * 0.5,
                    );
                  },
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  /// Construye la información de la radio (nombre y estado)
  Widget _buildRadioInfo(bool isTablet) {
    return Expanded(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          // Nombre de la emisora
          FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.centerLeft,
            child: Text(
              'Ambiente Stereo FM',
              style: TextStyle(
                color: AppColors.textPrimary,
                fontSize: isTablet ? 18 : 16,
                fontWeight: FontWeight.bold,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
          SizedBox(height: isTablet ? 4 : 2),
          // Estado de la transmisión
          FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.centerLeft,
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Indicador circular de estado
                Container(
                  width: isTablet ? 8 : 6,
                  height: isTablet ? 8 : 6,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: _isPlaying
                        ? AppColors.liveIndicator
                        : AppColors.textSecondary,
                  ),
                ),
                SizedBox(width: isTablet ? 6 : 4),
                Text(
                  _isPlaying ? 'En vivo' : 'Desconectado',
                  style: TextStyle(
                    color: AppColors.textMuted,
                    fontSize: isTablet ? 14 : 12,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  /// Construye el botón de volumen con indicador de porcentaje
  /// Al tocarlo, muestra/oculta el slider de volumen
  Widget _buildVolumeButton(bool isTablet) {
    return StreamBuilder<double>(
      stream: widget.audioManager.volumeStream,
      initialData: _volume,
      builder: (context, snapshot) {
        final currentVolume = snapshot.data ?? _volume;

        return InkWell(
          onTap: () {
            setState(() {
              _showVolumeSlider = !_showVolumeSlider;
            });
          },
          borderRadius: BorderRadius.circular(isTablet ? 12 : 8),
          child: Container(
            padding: EdgeInsets.all(isTablet ? 8 : 6),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  _getVolumeIcon(currentVolume),
                  color: AppColors.textSecondary,
                  size: isTablet ? 20 : 16,
                ),
                SizedBox(width: isTablet ? 6 : 4),
                Text(
                  '${(currentVolume * 100).round()}%',
                  style: TextStyle(
                    color: AppColors.textMuted,
                    fontSize: isTablet ? 12 : 10,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  /// Construye el botón circular de reproducción/pausa
  Widget _buildPlayButton(bool isTablet) {
    final buttonSize = isTablet ? 52.0 : 44.0;

    return GestureDetector(
      onTap: _togglePlayback,
      child: Container(
        width: buttonSize,
        height: buttonSize,
        decoration: const BoxDecoration(
          shape: BoxShape.circle,
          gradient: AppColors.buttonGradient,
        ),
        child: _isLoading
            ? SizedBox(
                width: buttonSize * 0.4,
                height: buttonSize * 0.4,
                child: const CircularProgressIndicator(
                  color: AppColors.textPrimary,
                  strokeWidth: 2,
                ),
              )
            : Icon(
                _isPlaying ? Icons.pause : Icons.play_arrow,
                color: AppColors.textPrimary,
                size: buttonSize * 0.45,
              ),
      ),
    );
  }

  /// Construye el slider de volumen expandible
  /// Muestra controles de volumen bajo, alto y porcentaje
  Widget _buildVolumeSlider(bool isTablet) {
    return StreamBuilder<double>(
      stream: widget.audioManager.volumeStream,
      initialData: _volume,
      builder: (context, snapshot) {
        final currentVolume = snapshot.data ?? _volume;

        return Container(
          constraints: BoxConstraints(
            minHeight: isTablet ? 40 : 35,
            maxHeight: isTablet ? 50 : 45,
          ),
          padding: EdgeInsets.symmetric(
            horizontal: isTablet ? 16 : 12,
            vertical: isTablet ? 4 : 3,
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                Icons.volume_down,
                color: AppColors.textSecondary,
                size: isTablet ? 18 : 14,
              ),
              SizedBox(width: isTablet ? 8 : 6),
              SizedBox(
                width: isTablet ? 120 : 100,
                child: SliderTheme(
                  data: SliderThemeData(
                    activeTrackColor: AppColors.primary,
                    inactiveTrackColor: const Color(0xFF374151),
                    thumbColor: AppColors.primary,
                    overlayColor: AppColors.primary.withValues(alpha: 0.2),
                    trackHeight: isTablet ? 2.5 : 2,
                    thumbShape: RoundSliderThumbShape(
                      enabledThumbRadius: isTablet ? 8 : 6,
                    ),
                  ),
                  child: Slider(
                    value: currentVolume,
                    onChanged: (value) {
                      setState(() {
                        _volume = value;
                      });
                      widget.audioManager.setVolume(value);
                    },
                    min: 0.0,
                    max: 1.0,
                  ),
                ),
              ),
              SizedBox(width: isTablet ? 8 : 6),
              Icon(
                Icons.volume_up,
                color: AppColors.textSecondary,
                size: isTablet ? 18 : 14,
              ),
              SizedBox(width: isTablet ? 6 : 4),
              SizedBox(
                width: isTablet ? 40 : 35,
                child: Text(
                  '${(currentVolume * 100).round()}%',
                  style: TextStyle(
                    color: AppColors.textMuted,
                    fontSize: isTablet ? 12 : 10,
                    fontWeight: FontWeight.w500,
                  ),
                  textAlign: TextAlign.end,
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  /// Retorna el icono apropiado según el nivel de volumen
  IconData _getVolumeIcon(double volume) {
    if (volume == 0) return Icons.volume_off;
    if (volume < 0.5) return Icons.volume_down;
    return Icons.volume_up;
  }

  @override
  void dispose() {
    _slideController.dispose();
    _pulseController.dispose();
    super.dispose();
  }
}
