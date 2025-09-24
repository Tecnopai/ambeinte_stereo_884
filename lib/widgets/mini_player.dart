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
    return SlideTransition(
      position: _slideAnimation,
      child: Container(
        height: _showVolumeSlider
            ? 130
            : 82, // Ajustar a 82 para evitar overflow
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [
              AppColors.surface.withOpacity(0.95),
              AppColors.background.withOpacity(0.95),
            ],
          ),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: AppColors.primary.withOpacity(0.3),
            width: 1,
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.3),
              blurRadius: 10,
              spreadRadius: 2,
            ),
          ],
        ),
        child: Material(
          color: Colors.transparent,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              _buildMainControls(),
              if (_showVolumeSlider) _buildVolumeSlider(),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildMainControls() {
    return SizedBox(
      height: 80,
      child: Padding(
        padding: const EdgeInsets.symmetric(
          horizontal: 16,
          vertical: 10,
        ), // Reducir padding vertical
        child: Row(
          children: [
            _buildRadioIcon(),
            const SizedBox(width: 12),
            _buildRadioInfo(),
            _buildVolumeButton(),
            const SizedBox(width: 8),
            _buildPlayButton(),
          ],
        ),
      ),
    );
  }

  Widget _buildRadioIcon() {
    return AnimatedBuilder(
      animation: _pulseAnimation,
      builder: (context, child) {
        return Transform.scale(
          scale: _isPlaying ? _pulseAnimation.value : 1.0,
          child: Container(
            width: 50,
            height: 50,
            decoration: const BoxDecoration(
              shape: BoxShape.circle,
              gradient: AppColors.buttonGradient,
            ),
            child: const Icon(
              Icons.radio,
              color: AppColors.textPrimary,
              size: 24,
            ),
          ),
        );
      },
    );
  }

  Widget _buildRadioInfo() {
    return Expanded(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Ambient Stereo FM',
            style: TextStyle(
              color: AppColors.textPrimary,
              fontSize: 16,
              fontWeight: FontWeight.bold,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          const SizedBox(height: 2),
          Row(
            children: [
              Container(
                width: 8,
                height: 8,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: _isPlaying
                      ? AppColors.liveIndicator
                      : AppColors.textSecondary,
                ),
              ),
              const SizedBox(width: 6),
              Text(
                _isPlaying ? 'En vivo' : 'Desconectado',
                style: const TextStyle(
                  color: AppColors.textMuted,
                  fontSize: 12,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildVolumeButton() {
    return GestureDetector(
      onTap: () {
        setState(() {
          _showVolumeSlider = !_showVolumeSlider;
        });
      },
      child: Container(
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: const Color(0xFF374151).withOpacity(0.5),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Icon(_getVolumeIcon(), color: AppColors.primary, size: 20),
      ),
    );
  }

  Widget _buildPlayButton() {
    return GestureDetector(
      onTap: _togglePlayback,
      child: Container(
        width: 45,
        height: 45,
        decoration: const BoxDecoration(
          shape: BoxShape.circle,
          gradient: AppColors.buttonGradient,
        ),
        child: _isLoading
            ? const SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(
                  color: AppColors.textPrimary,
                  strokeWidth: 2,
                ),
              )
            : Icon(
                _isPlaying ? Icons.pause : Icons.play_arrow,
                color: AppColors.textPrimary,
                size: 24,
              ),
      ),
    );
  }

  Widget _buildVolumeSlider() {
    return Container(
      height: 50,
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Row(
        children: [
          const Icon(
            Icons.volume_down,
            color: AppColors.textSecondary,
            size: 16,
          ),
          const SizedBox(width: 8),
          Expanded(
            child: SliderTheme(
              data: SliderThemeData(
                activeTrackColor: AppColors.primary,
                inactiveTrackColor: const Color(0xFF374151),
                thumbColor: AppColors.primary,
                overlayColor: AppColors.primary.withOpacity(0.2),
                trackHeight: 2,
                thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 8),
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
          const SizedBox(width: 8),
          const Icon(Icons.volume_up, color: AppColors.textSecondary, size: 16),
          const SizedBox(width: 8),
          Text(
            '${(_volume * 100).round()}%',
            style: const TextStyle(color: AppColors.textMuted, fontSize: 12),
          ),
        ],
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
