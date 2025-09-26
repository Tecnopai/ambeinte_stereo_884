import 'package:flutter/material.dart';
import '../services/audio_player_manager.dart';
import '../core/theme/app_colors.dart';

class MiniPlayer extends StatefulWidget {
  final AudioPlayerManager audioManager;

  const MiniPlayer({super.key, required this.audioManager});

  @override
  State<MiniPlayer> createState() => _MiniPlayerState();
}

class _MiniPlayerState extends State<MiniPlayer> with TickerProviderStateMixin {
  bool _isPlaying = false;
  bool _isLoading = false;
  double _volume = 0.7;
  bool _showVolumeSlider = false;

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

  void _initializeAnimations() {
    _slideController = AnimationController(
      duration: const Duration(milliseconds: 300),
      vsync: this,
    );

    _slideAnimation = Tween<Offset>(
      begin: const Offset(0, 1),
      end: Offset.zero,
    ).animate(CurvedAnimation(parent: _slideController, curve: Curves.easeOut));

    _pulseController = AnimationController(
      duration: const Duration(milliseconds: 1000),
      vsync: this,
    )..repeat(reverse: true);

    _pulseAnimation = Tween<double>(begin: 0.8, end: 1.2).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut),
    );
  }

  void _setupListeners() {
    widget.audioManager.playingStream.listen((isPlaying) {
      if (mounted) {
        setState(() {
          _isPlaying = isPlaying;
        });

        if (_isPlaying) {
          _slideController.forward();
        } else {
          _slideController.reverse();
        }
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

    if (_isPlaying) {
      _slideController.forward();
    }
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

    return SlideTransition(
      position: _slideAnimation,
      child: Container(
        // Removemos altura fija - dejamos que el contenido defina el tamaño
        constraints: BoxConstraints(
          minHeight: isTablet ? 80 : 70,
          maxHeight: isTablet ? 200 : 180, // Límite máximo generoso
        ),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [
              AppColors.surface.withOpacity(0.95),
              AppColors.background.withOpacity(0.95),
            ],
          ),
          borderRadius: BorderRadius.circular(isTablet ? 20 : 16),
          border: Border.all(
            color: AppColors.primary.withOpacity(0.3),
            width: 1,
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.3),
              blurRadius: isTablet ? 15 : 10,
              spreadRadius: isTablet ? 3 : 2,
            ),
          ],
        ),
        child: Material(
          color: Colors.transparent,
          child: IntrinsicHeight(
            // Permite que el Column se ajuste al contenido
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

  Widget _buildMainControls(bool isTablet) {
    return Flexible(
      // Permite flexibilidad en el tamaño
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
              color: Colors.white, // Fondo blanco sólido
              // gradient: AppColors.buttonGradient, // Comentado el gradiente
            ),
            child: ClipOval(
              child: ColorFiltered(
                colorFilter: ColorFilter.mode(
                  AppColors.primary.withOpacity(
                    0.3,
                  ), // Tinte de color sobre la imagen
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
                      color:
                          AppColors.textPrimary, // Color del ícono de fallback
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

  Widget _buildRadioInfo(bool isTablet) {
    return Expanded(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min, // Importante: min size
        children: [
          FittedBox(
            // Ajusta el texto al espacio disponible
            fit: BoxFit.scaleDown,
            alignment: Alignment.centerLeft,
            child: Text(
              'Ambient Stereo FM',
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
          FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.centerLeft,
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
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

  Widget _buildVolumeButton(bool isTablet) {
    return GestureDetector(
      onTap: () {
        setState(() {
          _showVolumeSlider = !_showVolumeSlider;
        });
      },
      child: Container(
        padding: EdgeInsets.all(isTablet ? 10 : 8),
        decoration: BoxDecoration(
          color: const Color(0xFF374151).withOpacity(0.5),
          borderRadius: BorderRadius.circular(isTablet ? 10 : 8),
        ),
        child: Icon(
          _getVolumeIcon(),
          color: AppColors.textPrimary,
          size: isTablet ? 22 : 18,
        ),
      ),
    );
  }

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

  Widget _buildVolumeSlider(bool isTablet) {
    return Flexible(
      // Permite flexibilidad
      child: Container(
        constraints: BoxConstraints(
          minHeight: isTablet ? 50 : 45,
          maxHeight: isTablet ? 80 : 70,
        ),
        padding: EdgeInsets.symmetric(
          horizontal: isTablet ? 20 : 16,
          vertical: isTablet ? 8 : 6,
        ),
        child: Row(
          children: [
            Icon(
              Icons.volume_down,
              color: AppColors.textSecondary,
              size: isTablet ? 20 : 16,
            ),
            SizedBox(width: isTablet ? 12 : 8),
            Expanded(
              child: SliderTheme(
                data: SliderThemeData(
                  activeTrackColor: AppColors.primary,
                  inactiveTrackColor: const Color(0xFF374151),
                  thumbColor: AppColors.primary,
                  overlayColor: AppColors.primary.withOpacity(0.2),
                  trackHeight: isTablet ? 3 : 2,
                  thumbShape: RoundSliderThumbShape(
                    enabledThumbRadius: isTablet ? 10 : 8,
                  ),
                ),
                child: Slider(
                  value: _volume,
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
            SizedBox(width: isTablet ? 12 : 8),
            Icon(
              Icons.volume_up,
              color: AppColors.textSecondary,
              size: isTablet ? 20 : 16,
            ),
            SizedBox(width: isTablet ? 8 : 6),
            FittedBox(
              // Ajusta el porcentaje si es necesario
              child: Text(
                '${(_volume * 100).round()}%',
                style: TextStyle(
                  color: AppColors.textMuted,
                  fontSize: isTablet ? 14 : 12,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  IconData _getVolumeIcon() {
    if (_volume == 0) return Icons.volume_off;
    if (_volume < 0.5) return Icons.volume_down;
    return Icons.volume_up;
  }

  @override
  void dispose() {
    _slideController.dispose();
    _pulseController.dispose();
    super.dispose();
  }
}
