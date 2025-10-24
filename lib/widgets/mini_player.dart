import 'package:flutter/material.dart';
import 'package:volume_controller/volume_controller.dart';
import '../services/audio_player_manager.dart';
import '../core/theme/app_colors.dart';
import '../utils/responsive_helper.dart';

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
        //Escuchar botones físicos
        VolumeController.instance.addListener((volume) {
          if (mounted) {
            setState(() => _volume = volume);
            widget.audioManager.setVolume(volume);
          }
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
    final responsive = ResponsiveHelper(context);

    final minHeight = responsive.getValue(
      smallPhone: 65.0,
      phone: 70.0,
      largePhone: 75.0,
      tablet: 80.0,
      desktop: 90.0,
      automotive: 75.0,
    );

    final maxHeight = responsive.getValue(
      smallPhone: 160.0,
      phone: 180.0,
      largePhone: 190.0,
      tablet: 200.0,
      desktop: 220.0,
      automotive: 180.0,
    );

    final borderRadius = responsive.getValue(
      smallPhone: 14.0,
      phone: 16.0,
      largePhone: 18.0,
      tablet: 20.0,
      desktop: 24.0,
      automotive: 18.0,
    );

    final shadowBlur = responsive.getValue(
      smallPhone: 8.0,
      phone: 10.0,
      tablet: 15.0,
      desktop: 20.0,
      automotive: 12.0,
    );

    final shadowSpread = responsive.getValue(
      smallPhone: 1.5,
      phone: 2.0,
      tablet: 3.0,
      desktop: 4.0,
      automotive: 2.5,
    );

    return SlideTransition(
      position: _slideAnimation,
      child: Container(
        constraints: BoxConstraints(minHeight: minHeight, maxHeight: maxHeight),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [
              AppColors.surface.withValues(alpha: 0.95),
              AppColors.background.withValues(alpha: 0.95),
            ],
          ),
          borderRadius: BorderRadius.circular(borderRadius),
          border: Border.all(
            color: AppColors.primary.withValues(alpha: 0.3),
            width: 1,
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.3),
              blurRadius: shadowBlur,
              spreadRadius: shadowSpread,
            ),
          ],
        ),
        child: Material(
          color: Colors.transparent,
          child: IntrinsicHeight(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                _buildMainControls(responsive),
                if (_showVolumeSlider) _buildVolumeSlider(responsive),
              ],
            ),
          ),
        ),
      ),
    );
  }

  /// Construye la fila principal de controles
  Widget _buildMainControls(ResponsiveHelper responsive) {
    final minHeight = responsive.getValue(
      smallPhone: 55.0,
      phone: 60.0,
      largePhone: 65.0,
      tablet: 70.0,
      desktop: 80.0,
      automotive: 65.0,
    );

    final padding = responsive.getValue(
      smallPhone: 10.0,
      phone: 12.0,
      largePhone: 14.0,
      tablet: 16.0,
      desktop: 18.0,
      automotive: 14.0,
    );

    final spacing1 = responsive.getValue(
      smallPhone: 10.0,
      phone: 12.0,
      largePhone: 14.0,
      tablet: 16.0,
      desktop: 18.0,
      automotive: 14.0,
    );

    final spacing2 = responsive.getValue(
      smallPhone: 6.0,
      phone: 8.0,
      largePhone: 10.0,
      tablet: 12.0,
      desktop: 14.0,
      automotive: 10.0,
    );

    return Flexible(
      child: Container(
        constraints: BoxConstraints(minHeight: minHeight),
        padding: EdgeInsets.all(padding),
        child: Row(
          children: [
            _buildRadioIcon(responsive),
            SizedBox(width: spacing1),
            _buildRadioInfo(responsive),
            _buildVolumeButton(responsive),
            SizedBox(width: spacing2),
            _buildPlayButton(responsive),
          ],
        ),
      ),
    );
  }

  /// Construye el icono circular de la radio con efecto de pulso
  Widget _buildRadioIcon(ResponsiveHelper responsive) {
    final iconSize = responsive.getValue(
      smallPhone: 44.0,
      phone: 48.0,
      largePhone: 52.0,
      tablet: 56.0,
      desktop: 64.0,
      automotive: 52.0,
    );

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
  Widget _buildRadioInfo(ResponsiveHelper responsive) {
    final titleSize = responsive.getValue(
      smallPhone: 14.0,
      phone: 16.0,
      largePhone: 17.0,
      tablet: 18.0,
      desktop: 20.0,
      automotive: 17.0,
    );

    final statusSize = responsive.getValue(
      smallPhone: 11.0,
      phone: 12.0,
      largePhone: 13.0,
      tablet: 14.0,
      desktop: 16.0,
      automotive: 13.0,
    );

    final indicatorSize = responsive.getValue(
      smallPhone: 5.0,
      phone: 6.0,
      largePhone: 7.0,
      tablet: 8.0,
      desktop: 9.0,
      automotive: 7.0,
    );

    final spacing1 = responsive.getValue(
      smallPhone: 2.0,
      phone: 2.0,
      largePhone: 3.0,
      tablet: 4.0,
      desktop: 5.0,
      automotive: 3.0,
    );

    final spacing2 = responsive.getValue(
      smallPhone: 3.0,
      phone: 4.0,
      largePhone: 5.0,
      tablet: 6.0,
      desktop: 7.0,
      automotive: 5.0,
    );

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
                fontSize: titleSize,
                fontWeight: FontWeight.bold,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
          SizedBox(height: spacing1),
          // Estado de la transmisión
          FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.centerLeft,
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Indicador circular de estado
                Container(
                  width: indicatorSize,
                  height: indicatorSize,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: _isPlaying
                        ? AppColors.liveIndicator
                        : AppColors.textSecondary,
                  ),
                ),
                SizedBox(width: spacing2),
                Text(
                  _isPlaying ? 'En vivo' : 'Desconectado',
                  style: TextStyle(
                    color: AppColors.textMuted,
                    fontSize: statusSize,
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
  Widget _buildVolumeButton(ResponsiveHelper responsive) {
    final borderRadius = responsive.getValue(
      smallPhone: 6.0,
      phone: 8.0,
      largePhone: 10.0,
      tablet: 12.0,
      desktop: 14.0,
      automotive: 10.0,
    );

    final padding = responsive.getValue(
      smallPhone: 5.0,
      phone: 6.0,
      largePhone: 7.0,
      tablet: 8.0,
      desktop: 9.0,
      automotive: 7.0,
    );

    final iconSize = responsive.getValue(
      smallPhone: 15.0,
      phone: 16.0,
      largePhone: 18.0,
      tablet: 20.0,
      desktop: 22.0,
      automotive: 18.0,
    );

    final spacing = responsive.getValue(
      smallPhone: 3.0,
      phone: 4.0,
      largePhone: 5.0,
      tablet: 6.0,
      desktop: 7.0,
      automotive: 5.0,
    );

    final fontSize = responsive.getValue(
      smallPhone: 9.0,
      phone: 10.0,
      largePhone: 11.0,
      tablet: 12.0,
      desktop: 14.0,
      automotive: 11.0,
    );

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
          borderRadius: BorderRadius.circular(borderRadius),
          child: Container(
            padding: EdgeInsets.all(padding),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  _getVolumeIcon(currentVolume),
                  color: AppColors.textSecondary,
                  size: iconSize,
                ),
                SizedBox(width: spacing),
                Text(
                  '${(currentVolume * 100).round()}%',
                  style: TextStyle(
                    color: AppColors.textMuted,
                    fontSize: fontSize,
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
  Widget _buildPlayButton(ResponsiveHelper responsive) {
    final buttonSize = responsive.getValue(
      smallPhone: 40.0,
      phone: 44.0,
      largePhone: 48.0,
      tablet: 52.0,
      desktop: 58.0,
      automotive: 48.0,
    );

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
  Widget _buildVolumeSlider(ResponsiveHelper responsive) {
    final minHeight = responsive.getValue(
      smallPhone: 32.0,
      phone: 35.0,
      largePhone: 38.0,
      tablet: 40.0,
      desktop: 45.0,
      automotive: 38.0,
    );

    final maxHeight = responsive.getValue(
      smallPhone: 42.0,
      phone: 45.0,
      largePhone: 48.0,
      tablet: 50.0,
      desktop: 55.0,
      automotive: 48.0,
    );

    final horizontalPadding = responsive.getValue(
      smallPhone: 10.0,
      phone: 12.0,
      largePhone: 14.0,
      tablet: 16.0,
      desktop: 18.0,
      automotive: 14.0,
    );

    final verticalPadding = responsive.getValue(
      smallPhone: 2.5,
      phone: 3.0,
      largePhone: 3.5,
      tablet: 4.0,
      desktop: 5.0,
      automotive: 3.5,
    );

    final iconSize = responsive.getValue(
      smallPhone: 13.0,
      phone: 14.0,
      largePhone: 16.0,
      tablet: 18.0,
      desktop: 20.0,
      automotive: 16.0,
    );

    final spacing1 = responsive.getValue(
      smallPhone: 5.0,
      phone: 6.0,
      largePhone: 7.0,
      tablet: 8.0,
      desktop: 10.0,
      automotive: 7.0,
    );

    final spacing2 = responsive.getValue(
      smallPhone: 3.0,
      phone: 4.0,
      largePhone: 5.0,
      tablet: 6.0,
      desktop: 7.0,
      automotive: 5.0,
    );

    final sliderWidth = responsive.getValue(
      smallPhone: 90.0,
      phone: 100.0,
      largePhone: 110.0,
      tablet: 120.0,
      desktop: 140.0,
      automotive: 110.0,
    );

    final trackHeight = responsive.getValue(
      smallPhone: 1.8,
      phone: 2.0,
      tablet: 2.5,
      desktop: 3.0,
      automotive: 2.2,
    );

    final thumbRadius = responsive.getValue(
      smallPhone: 5.5,
      phone: 6.0,
      largePhone: 7.0,
      tablet: 8.0,
      desktop: 9.0,
      automotive: 7.0,
    );

    final fontSize = responsive.getValue(
      smallPhone: 9.0,
      phone: 10.0,
      largePhone: 11.0,
      tablet: 12.0,
      desktop: 14.0,
      automotive: 11.0,
    );

    final percentWidth = responsive.getValue(
      smallPhone: 32.0,
      phone: 35.0,
      largePhone: 38.0,
      tablet: 40.0,
      desktop: 45.0,
      automotive: 38.0,
    );

    return StreamBuilder<double>(
      stream: widget.audioManager.volumeStream,
      initialData: _volume,
      builder: (context, snapshot) {
        final currentVolume = snapshot.data ?? _volume;

        return Container(
          constraints: BoxConstraints(
            minHeight: minHeight,
            maxHeight: maxHeight,
          ),
          padding: EdgeInsets.symmetric(
            horizontal: horizontalPadding,
            vertical: verticalPadding,
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                Icons.volume_down,
                color: AppColors.textSecondary,
                size: iconSize,
              ),
              SizedBox(width: spacing1),
              SizedBox(
                width: sliderWidth,
                child: SliderTheme(
                  data: SliderThemeData(
                    activeTrackColor: AppColors.primary,
                    inactiveTrackColor: const Color(0xFF374151),
                    thumbColor: AppColors.primary,
                    overlayColor: AppColors.primary.withValues(alpha: 0.2),
                    trackHeight: trackHeight,
                    thumbShape: RoundSliderThumbShape(
                      enabledThumbRadius: thumbRadius,
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
              SizedBox(width: spacing1),
              Icon(
                Icons.volume_up,
                color: AppColors.textSecondary,
                size: iconSize,
              ),
              SizedBox(width: spacing2),
              SizedBox(
                width: percentWidth,
                child: Text(
                  '${(currentVolume * 100).round()}%',
                  style: TextStyle(
                    color: AppColors.textMuted,
                    fontSize: fontSize,
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
