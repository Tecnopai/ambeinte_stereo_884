import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:share_plus/share_plus.dart';
import 'package:just_audio/just_audio.dart';
import 'package:firebase_analytics/firebase_analytics.dart';
import '../models/article.dart';
import '../core/theme/app_colors.dart';
import '../utils/responsive_helper.dart';
import '../services/audio_player_manager.dart';
import '../widgets/mini_player.dart';
import '../widgets/live_indicator.dart';

/// Pantalla mejorada de detalle de artículo con reproductor de audio
/// Completamente responsive para todos los dispositivos incluyendo automotive
class ArticleDetailScreen extends StatefulWidget {
  final Article article;
  final AudioPlayerManager? audioManager;

  const ArticleDetailScreen({
    super.key,
    required this.article,
    this.audioManager,
  });

  @override
  State<ArticleDetailScreen> createState() => _ArticleDetailScreenState();
}

class _ArticleDetailScreenState extends State<ArticleDetailScreen> {
  AudioPlayer? _audioPlayer;
  bool _isInitialized = false;
  Duration _duration = Duration.zero;
  Duration _position = Duration.zero;
  bool _hasError = false;
  String? _errorMessage;
  bool _isStreamingPlaying = false;
  final analytics = FirebaseAnalytics.instance;

  @override
  void initState() {
    super.initState();

    // analitica
    analytics.logScreenView(
      screenName: 'article_detail',
      screenClass: 'ArticleDetailScreen',
    );

    // (registrar lectura)
    analytics.logEvent(
      name: 'article_view',
      parameters: {
        'article_id': widget.article.id,
        'article_title': widget.article.title,
      },
    );

    _initializeAudio();
    _setupStreamingListener();
  }

  void _setupStreamingListener() {
    widget.audioManager?.playingStream.listen((isPlaying) {
      if (mounted) {
        setState(() => _isStreamingPlaying = isPlaying);
      }
    });
    _isStreamingPlaying = widget.audioManager?.isPlaying ?? false;
  }

  Future<void> _initializeAudio() async {
    // Solo inicializar si hay URL de audio
    if (widget.article.audioUrl == null || widget.article.audioUrl!.isEmpty) {
      return;
    }

    try {
      _audioPlayer = AudioPlayer();

      // Escuchar cambios de duración
      _audioPlayer!.durationStream.listen((duration) {
        if (mounted) {
          setState(() {
            _duration = duration ?? Duration.zero;
          });
        }
      });

      // Escuchar cambios de posición
      _audioPlayer!.positionStream.listen((position) {
        if (mounted) {
          setState(() {
            _position = position;
          });
        }
      });

      // Cargar audio
      await _audioPlayer!.setUrl(widget.article.audioUrl!);

      if (mounted) {
        setState(() {
          _isInitialized = true;
          _hasError = false;
          _errorMessage = null;
        });
      }
    } catch (e) {
      debugPrint('❌ Error cargando audio: $e');
      if (mounted) {
        setState(() {
          _hasError = true;
          _errorMessage = e.toString();
        });
      }
    }
  }

  @override
  void dispose() {
    _audioPlayer?.dispose();
    super.dispose();
  }

  String _formatDuration(Duration duration) {
    String twoDigits(int n) => n.toString().padLeft(2, '0');
    final hours = twoDigits(duration.inHours);
    final minutes = twoDigits(duration.inMinutes.remainder(60));
    final seconds = twoDigits(duration.inSeconds.remainder(60));

    if (duration.inHours > 0) {
      return '$hours:$minutes:$seconds';
    }
    return '$minutes:$seconds';
  }

  @override
  Widget build(BuildContext context) {
    final responsive = ResponsiveHelper(context);

    // Layout especial para automotive
    if (responsive.isAutomotive) {
      return _buildAutomotiveLayout(context, responsive);
    }

    // Layout estándar para móvil/tablet
    return _buildStandardLayout(context, responsive);
  }

  /// Layout optimizado para radios de vehículos
  Widget _buildAutomotiveLayout(
    BuildContext context,
    ResponsiveHelper responsive,
  ) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        title: Row(
          children: [
            Text(
              'Artículo',
              style: TextStyle(fontSize: responsive.h2, color: Colors.white),
            ),
            if (_isStreamingPlaying) const LiveIndicator(),
          ],
        ),
        iconTheme: IconThemeData(color: Colors.white, size: 32),
      ),
      body: SafeArea(
        child: Padding(
          padding: EdgeInsets.all(20),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Panel izquierdo - Imagen (si existe)
              if (widget.article.imageUrl != null)
                Expanded(
                  flex: 2,
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(12),
                    child: Image.network(
                      widget.article.imageUrl!,
                      fit: BoxFit.cover,
                      height: double.infinity,
                      errorBuilder: (context, error, stackTrace) {
                        return Container(
                          decoration: BoxDecoration(
                            color: Colors.grey[900],
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Icon(
                            Icons.broken_image,
                            size: 80,
                            color: Colors.grey[700],
                          ),
                        );
                      },
                    ),
                  ),
                ),

              if (widget.article.imageUrl != null) SizedBox(width: 24),

              // Panel derecho - Contenido
              Expanded(
                flex: 3,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Título y contenido scrolleable
                    Expanded(
                      child: SingleChildScrollView(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              widget.article.title,
                              style: TextStyle(
                                fontSize: responsive.h2,
                                fontWeight: FontWeight.bold,
                                color: Colors.white,
                                height: 1.3,
                              ),
                            ),
                            SizedBox(height: 16),

                            // Fecha
                            Row(
                              children: [
                                Icon(
                                  Icons.access_time,
                                  size: 20,
                                  color: Colors.grey[400],
                                ),
                                SizedBox(width: 8),
                                Text(
                                  widget.article.formattedDate,
                                  style: TextStyle(
                                    fontSize: responsive.caption,
                                    color: Colors.grey[400],
                                  ),
                                ),
                              ],
                            ),
                            SizedBox(height: 20),

                            // Reproductor de audio para automotive
                            if (_isInitialized && !_hasError)
                              _buildAutomotiveAudioPlayer(responsive),

                            if (_isInitialized && !_hasError)
                              SizedBox(height: 20),

                            // Contenido resumido
                            Text(
                              widget.article.content,
                              style: TextStyle(
                                fontSize: responsive.bodyText,
                                color: Colors.grey[300],
                                height: 1.6,
                              ),
                              maxLines: 8,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ],
                        ),
                      ),
                    ),

                    SizedBox(height: 20),

                    // Botón grande para ver completo
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton.icon(
                        onPressed: () => _launchUrl(widget.article.link),
                        icon: Icon(Icons.open_in_browser, size: 28),
                        label: Text(
                          'VER COMPLETO',
                          style: TextStyle(
                            fontSize: responsive.buttonText,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.green,
                          foregroundColor: Colors.white,
                          minimumSize: Size(double.infinity, 70),
                          padding: EdgeInsets.symmetric(vertical: 20),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// Reproductor de audio optimizado para automotive
  Widget _buildAutomotiveAudioPlayer(ResponsiveHelper responsive) {
    return Container(
      padding: EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.grey[900],
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.green, width: 2),
      ),
      child: Column(
        children: [
          // Header
          Row(
            children: [
              Icon(Icons.headphones, color: Colors.green, size: 28),
              SizedBox(width: 12),
              Text(
                'Audio del artículo',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: responsive.bodyText,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
          SizedBox(height: 20),

          // Barra de progreso
          Column(
            children: [
              SliderTheme(
                data: SliderThemeData(
                  activeTrackColor: Colors.green,
                  inactiveTrackColor: Colors.grey[700],
                  thumbColor: Colors.green,
                  thumbShape: RoundSliderThumbShape(enabledThumbRadius: 8),
                  overlayShape: RoundSliderOverlayShape(overlayRadius: 16),
                ),
                child: Slider(
                  value: _position.inSeconds.toDouble(),
                  max: _duration.inSeconds.toDouble() > 0
                      ? _duration.inSeconds.toDouble()
                      : 1.0,
                  onChanged: (value) {
                    _audioPlayer?.seek(Duration(seconds: value.toInt()));
                  },
                ),
              ),
              Padding(
                padding: EdgeInsets.symmetric(horizontal: 12),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      _formatDuration(_position),
                      style: TextStyle(color: Colors.grey[400], fontSize: 16),
                    ),
                    Text(
                      _formatDuration(_duration),
                      style: TextStyle(color: Colors.grey[400], fontSize: 16),
                    ),
                  ],
                ),
              ),
            ],
          ),

          SizedBox(height: 16),

          // Controles grandes para automotive
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              IconButton(
                icon: Icon(Icons.replay_10, color: Colors.white),
                iconSize: 48,
                onPressed: () {
                  final newPosition = _position - Duration(seconds: 10);
                  _audioPlayer?.seek(
                    newPosition < Duration.zero ? Duration.zero : newPosition,
                  );
                },
              ),
              SizedBox(width: 20),

              StreamBuilder<PlayerState>(
                stream: _audioPlayer?.playerStateStream,
                builder: (context, snapshot) {
                  final playerState = snapshot.data;
                  final playing = playerState?.playing ?? false;
                  final processingState = playerState?.processingState;

                  if (processingState == ProcessingState.loading ||
                      processingState == ProcessingState.buffering) {
                    return Container(
                      width: 64,
                      height: 64,
                      padding: EdgeInsets.all(16),
                      child: CircularProgressIndicator(
                        color: Colors.green,
                        strokeWidth: 3,
                      ),
                    );
                  }

                  return IconButton(
                    icon: Icon(
                      playing ? Icons.pause_circle : Icons.play_circle,
                      color: Colors.green,
                    ),
                    iconSize: 64,
                    onPressed: () {
                      if (playing) {
                        _audioPlayer?.pause();
                      } else {
                        _audioPlayer?.play();
                      }
                    },
                  );
                },
              ),

              SizedBox(width: 20),
              IconButton(
                icon: Icon(Icons.forward_10, color: Colors.white),
                iconSize: 48,
                onPressed: () {
                  final newPosition = _position + Duration(seconds: 10);
                  _audioPlayer?.seek(
                    newPosition > _duration ? _duration : newPosition,
                  );
                },
              ),
            ],
          ),
        ],
      ),
    );
  }

  /// Layout estándar para móvil y tablet
  Widget _buildStandardLayout(
    BuildContext context,
    ResponsiveHelper responsive,
  ) {
    final padding = responsive.getValue(
      smallPhone: 16.0,
      phone: 20.0,
      largePhone: 22.0,
      tablet: 28.0,
      desktop: 32.0,
    );

    final borderRadius = responsive.getValue(
      phone: 12.0,
      largePhone: 14.0,
      tablet: 16.0,
      desktop: 20.0,
    );

    final imageHeight = responsive.getValue(
      smallPhone: 200.0,
      phone: 220.0,
      largePhone: 240.0,
      tablet: 300.0,
      desktop: 400.0,
    );

    final iconSize = responsive.getValue(
      phone: 18.0,
      largePhone: 20.0,
      tablet: 22.0,
      desktop: 24.0,
    );

    return Scaffold(
      appBar: AppBar(
        title: Row(
          children: [
            Expanded(
              child: Text(
                'Artículo',
                style: TextStyle(fontSize: responsive.h2),
              ),
            ),
            if (_isStreamingPlaying) const LiveIndicator(),
          ],
        ),
        centerTitle: true,
        actions: [
          // Botón compartir
          IconButton(
            icon: Icon(Icons.share, size: iconSize),
            tooltip: 'Compartir',
            onPressed: () => _shareArticle(context),
          ),
          // Botón copiar enlace
          IconButton(
            icon: Icon(Icons.link, size: iconSize),
            tooltip: 'Copiar enlace',
            onPressed: () => _copyLink(context),
          ),
        ],
      ),
      body: Stack(
        children: [
          Center(
            child: ConstrainedBox(
              constraints: BoxConstraints(maxWidth: responsive.maxContentWidth),
              child: SingleChildScrollView(
                padding: EdgeInsets.only(
                  top: padding,
                  left: padding,
                  right: padding,
                  bottom: _isStreamingPlaying
                      ? responsive.getValue(
                          phone: 100.0,
                          tablet: 120.0,
                          desktop: 140.0,
                        )
                      : padding,
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Imagen destacada
                    if (widget.article.imageUrl != null)
                      _buildImage(
                        context,
                        responsive,
                        imageHeight,
                        borderRadius,
                      ),

                    if (widget.article.imageUrl != null)
                      SizedBox(height: responsive.spacing(24)),

                    // Título
                    SelectableText(
                      widget.article.title,
                      style: TextStyle(
                        fontSize: responsive.h1,
                        fontWeight: FontWeight.bold,
                        color: AppColors.textPrimary,
                        height: 1.3,
                      ),
                    ),

                    SizedBox(height: responsive.spacing(20)),

                    // Fecha y hora
                    _buildDateRow(responsive, iconSize),

                    SizedBox(height: responsive.spacing(24)),

                    // Reproductor de audio estándar
                    if (_isInitialized && !_hasError)
                      _buildAudioPlayer(responsive, borderRadius),

                    if (_isInitialized && !_hasError)
                      SizedBox(height: responsive.spacing(24)),

                    // Mensaje de error de audio
                    if (_hasError && widget.article.audioUrl != null)
                      _buildAudioError(responsive, borderRadius),

                    if (_hasError && widget.article.audioUrl != null)
                      SizedBox(height: responsive.spacing(24)),

                    // Contenido
                    _buildContentCard(responsive, borderRadius),

                    SizedBox(height: responsive.spacing(32)),

                    // Botones de acción
                    if (responsive.isDesktop || responsive.isLargeTablet)
                      _buildButtonsRow(responsive, borderRadius)
                    else
                      _buildButtonsColumn(responsive, borderRadius),

                    SizedBox(height: responsive.spacing(24)),
                  ],
                ),
              ),
            ),
          ),

          // MiniPlayer del streaming - siempre presente, se anima automáticamente
          if (widget.audioManager != null)
            Positioned(
              bottom: 16,
              left: 16,
              right: 16,
              child: Builder(
                builder: (context) {
                  debugPrint(
                    '🟢 Construyendo MiniPlayer en ArticleDetailScreen',
                  );
                  return MiniPlayer(audioManager: widget.audioManager!);
                },
              ),
            ),
        ],
      ),
    );
  }

  /// Reproductor de audio estándar para móvil/tablet
  Widget _buildAudioPlayer(ResponsiveHelper responsive, double borderRadius) {
    return Container(
      padding: EdgeInsets.all(
        responsive.getValue(phone: 16.0, tablet: 20.0, desktop: 24.0),
      ),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            AppColors.primary.withValues(alpha: 0.15),
            AppColors.primary.withValues(alpha: 0.05),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(borderRadius),
        border: Border.all(
          color: AppColors.primary.withValues(alpha: 0.4),
          width: 1.5,
        ),
      ),
      child: Column(
        children: [
          // Header del reproductor
          Row(
            children: [
              Container(
                padding: EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: AppColors.primary.withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(
                  Icons.headphones,
                  color: AppColors.primary,
                  size: responsive.getValue(
                    phone: 24.0,
                    tablet: 28.0,
                    desktop: 32.0,
                  ),
                ),
              ),
              SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Audio del artículo',
                      style: TextStyle(
                        fontSize: responsive.bodyText,
                        fontWeight: FontWeight.bold,
                        color: AppColors.textPrimary,
                      ),
                    ),
                    SizedBox(height: 4),
                    Text(
                      'Escucha el contenido completo',
                      style: TextStyle(
                        fontSize: responsive.caption,
                        color: AppColors.textSecondary,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),

          SizedBox(height: 20),

          // Barra de progreso
          Column(
            children: [
              SliderTheme(
                data: SliderThemeData(
                  activeTrackColor: AppColors.primary,
                  inactiveTrackColor: AppColors.primary.withValues(alpha: 0.2),
                  thumbColor: AppColors.primary,
                  thumbShape: RoundSliderThumbShape(
                    enabledThumbRadius: responsive.getValue(
                      phone: 6.0,
                      tablet: 8.0,
                      desktop: 10.0,
                    ),
                  ),
                  overlayShape: RoundSliderOverlayShape(
                    overlayRadius: responsive.getValue(
                      phone: 14.0,
                      tablet: 16.0,
                      desktop: 18.0,
                    ),
                  ),
                ),
                child: Slider(
                  value: _position.inSeconds.toDouble(),
                  max: _duration.inSeconds.toDouble() > 0
                      ? _duration.inSeconds.toDouble()
                      : 1.0,
                  onChanged: (value) {
                    _audioPlayer?.seek(Duration(seconds: value.toInt()));
                  },
                ),
              ),
              Padding(
                padding: EdgeInsets.symmetric(horizontal: 4),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      _formatDuration(_position),
                      style: TextStyle(
                        color: AppColors.textSecondary,
                        fontSize: responsive.caption,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    Text(
                      _formatDuration(_duration),
                      style: TextStyle(
                        color: AppColors.textSecondary,
                        fontSize: responsive.caption,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),

          SizedBox(height: 16),

          // Controles de reproducción
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              // Retroceder 10s
              IconButton(
                icon: Icon(Icons.replay_10),
                iconSize: responsive.getValue(
                  phone: 28.0,
                  tablet: 32.0,
                  desktop: 36.0,
                ),
                color: AppColors.textPrimary,
                onPressed: () {
                  final newPosition = _position - Duration(seconds: 10);
                  _audioPlayer?.seek(
                    newPosition < Duration.zero ? Duration.zero : newPosition,
                  );
                },
              ),

              SizedBox(
                width: responsive.getValue(
                  phone: 16.0,
                  tablet: 20.0,
                  desktop: 24.0,
                ),
              ),

              // Play/Pause
              StreamBuilder<PlayerState>(
                stream: _audioPlayer?.playerStateStream,
                builder: (context, snapshot) {
                  final playerState = snapshot.data;
                  final playing = playerState?.playing ?? false;
                  final processingState = playerState?.processingState;

                  if (processingState == ProcessingState.loading ||
                      processingState == ProcessingState.buffering) {
                    return Container(
                      width: responsive.getValue(
                        phone: 48.0,
                        tablet: 56.0,
                        desktop: 64.0,
                      ),
                      height: responsive.getValue(
                        phone: 48.0,
                        tablet: 56.0,
                        desktop: 64.0,
                      ),
                      padding: EdgeInsets.all(12),
                      child: CircularProgressIndicator(
                        color: AppColors.primary,
                        strokeWidth: 3,
                      ),
                    );
                  }

                  return Container(
                    decoration: BoxDecoration(
                      color: AppColors.primary,
                      shape: BoxShape.circle,
                      boxShadow: [
                        BoxShadow(
                          color: AppColors.primary.withValues(alpha: 0.3),
                          blurRadius: 8,
                          spreadRadius: 2,
                        ),
                      ],
                    ),
                    child: IconButton(
                      icon: Icon(
                        playing ? Icons.pause : Icons.play_arrow,
                        color: Colors.white,
                      ),
                      iconSize: responsive.getValue(
                        phone: 32.0,
                        tablet: 38.0,
                        desktop: 44.0,
                      ),
                      onPressed: () {
                        if (playing) {
                          _audioPlayer?.pause();
                        } else {
                          _audioPlayer?.play();
                        }
                      },
                    ),
                  );
                },
              ),

              SizedBox(
                width: responsive.getValue(
                  phone: 16.0,
                  tablet: 20.0,
                  desktop: 24.0,
                ),
              ),

              // Adelantar 10s
              IconButton(
                icon: Icon(Icons.forward_10),
                iconSize: responsive.getValue(
                  phone: 28.0,
                  tablet: 32.0,
                  desktop: 36.0,
                ),
                color: AppColors.textPrimary,
                onPressed: () {
                  final newPosition = _position + Duration(seconds: 10);
                  _audioPlayer?.seek(
                    newPosition > _duration ? _duration : newPosition,
                  );
                },
              ),
            ],
          ),
        ],
      ),
    );
  }

  /// Widget de error de audio
  Widget _buildAudioError(ResponsiveHelper responsive, double borderRadius) {
    return Container(
      padding: EdgeInsets.all(
        responsive.getValue(phone: 16.0, tablet: 20.0, desktop: 24.0),
      ),
      decoration: BoxDecoration(
        color: Colors.red.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(borderRadius),
        border: Border.all(
          color: Colors.red.withValues(alpha: 0.3),
          width: 1.5,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                Icons.error_outline,
                color: Colors.red,
                size: responsive.getValue(
                  phone: 24.0,
                  tablet: 28.0,
                  desktop: 32.0,
                ),
              ),
              SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Error al cargar audio',
                      style: TextStyle(
                        fontSize: responsive.bodyText,
                        fontWeight: FontWeight.bold,
                        color: Colors.red,
                      ),
                    ),
                    SizedBox(height: 4),
                    Text(
                      'No se pudo reproducir el archivo de audio',
                      style: TextStyle(
                        fontSize: responsive.caption,
                        color: AppColors.textSecondary,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          if (_errorMessage != null) ...[
            SizedBox(height: 12),
            Container(
              padding: EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: Colors.red.withValues(alpha: 0.05),
                borderRadius: BorderRadius.circular(6),
              ),
              child: SelectableText(
                _errorMessage!,
                style: TextStyle(
                  fontSize: 11,
                  color: Colors.red[700],
                  fontFamily: 'monospace',
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  /// Construye la imagen del artículo con estados de carga y error
  Widget _buildImage(
    BuildContext context,
    ResponsiveHelper responsive,
    double height,
    double borderRadius,
  ) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(borderRadius),
      child: Image.network(
        widget.article.imageUrl!,
        height: height,
        width: double.infinity,
        fit: BoxFit.cover,
        loadingBuilder: (context, child, loadingProgress) {
          if (loadingProgress == null) return child;
          return Container(
            height: height,
            decoration: BoxDecoration(
              color: AppColors.primary.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(borderRadius),
            ),
            child: Center(
              child: CircularProgressIndicator(
                color: AppColors.primary,
                strokeWidth: 3,
                value: loadingProgress.expectedTotalBytes != null
                    ? loadingProgress.cumulativeBytesLoaded /
                          loadingProgress.expectedTotalBytes!
                    : null,
              ),
            ),
          );
        },
        errorBuilder: (context, error, stackTrace) {
          return Container(
            height: height,
            decoration: BoxDecoration(
              color: AppColors.primary.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(borderRadius),
            ),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  Icons.broken_image_outlined,
                  size: responsive.getValue(
                    phone: 50.0,
                    tablet: 64.0,
                    desktop: 80.0,
                  ),
                  color: AppColors.textSecondary.withValues(alpha: 0.5),
                ),
                SizedBox(height: 12),
                Text(
                  'Imagen no disponible',
                  style: TextStyle(
                    fontSize: responsive.caption,
                    color: AppColors.textSecondary,
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  /// Fila con fecha y hora
  Widget _buildDateRow(ResponsiveHelper responsive, double iconSize) {
    return Row(
      children: [
        Icon(Icons.access_time, size: iconSize, color: AppColors.textSecondary),
        SizedBox(width: 8),
        Flexible(
          child: Text(
            widget.article.formattedDate,
            style: TextStyle(
              fontSize: responsive.caption,
              color: AppColors.textSecondary,
            ),
          ),
        ),
      ],
    );
  }

  /// Tarjeta con el contenido del artículo
  Widget _buildContentCard(ResponsiveHelper responsive, double borderRadius) {
    final cardPadding = responsive.getValue(
      phone: 18.0,
      largePhone: 20.0,
      tablet: 24.0,
      desktop: 28.0,
    );

    return Container(
      width: double.infinity,
      padding: EdgeInsets.all(cardPadding),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(borderRadius),
        border: Border.all(
          color: AppColors.primary.withValues(alpha: 0.3),
          width: 1.5,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 10,
            spreadRadius: 1,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: SelectableText(
        widget.article.content,
        style: TextStyle(
          fontSize: responsive.bodyText,
          color: AppColors.textMuted,
          height: 1.6,
          letterSpacing: 0.2,
        ),
      ),
    );
  }

  /// Botones en columna (móvil)
  Widget _buildButtonsColumn(ResponsiveHelper responsive, double borderRadius) {
    return Column(
      children: [
        _buildActionButton(
          responsive,
          borderRadius,
          'Ver artículo completo',
          Icons.open_in_browser,
          AppColors.primary,
          () => _launchUrl(widget.article.link),
        ),
        SizedBox(height: responsive.spacing(12)),
        _buildActionButton(
          responsive,
          borderRadius,
          'Compartir',
          Icons.share,
          Colors.blue,
          () => _shareArticle(context),
        ),
      ],
    );
  }

  /// Botones en fila (tablet/desktop)
  Widget _buildButtonsRow(ResponsiveHelper responsive, double borderRadius) {
    return Row(
      children: [
        Expanded(
          flex: 2,
          child: _buildActionButton(
            responsive,
            borderRadius,
            'Ver completo',
            Icons.open_in_browser,
            AppColors.primary,
            () => _launchUrl(widget.article.link),
          ),
        ),
        SizedBox(width: 16),
        Expanded(
          child: _buildActionButton(
            responsive,
            borderRadius,
            'Compartir',
            Icons.share,
            Colors.blue,
            () => _shareArticle(context),
          ),
        ),
      ],
    );
  }

  /// Botón de acción reutilizable
  Widget _buildActionButton(
    ResponsiveHelper responsive,
    double borderRadius,
    String label,
    IconData icon,
    Color color,
    VoidCallback onPressed,
  ) {
    final iconSize = responsive.getValue(
      phone: 20.0,
      largePhone: 22.0,
      tablet: 24.0,
      desktop: 26.0,
    );

    final padding = responsive.getValue(
      phone: 14.0,
      largePhone: 16.0,
      tablet: 18.0,
      desktop: 20.0,
    );

    return SizedBox(
      width: double.infinity,
      child: ElevatedButton.icon(
        onPressed: onPressed,
        icon: Icon(icon, size: iconSize),
        label: Text(
          label,
          style: TextStyle(
            fontSize: responsive.buttonText,
            fontWeight: FontWeight.w600,
          ),
        ),
        style: ElevatedButton.styleFrom(
          backgroundColor: color,
          foregroundColor: Colors.white,
          padding: EdgeInsets.symmetric(vertical: padding),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(borderRadius),
          ),
          elevation: 4,
          shadowColor: color.withValues(alpha: 0.3),
        ),
      ),
    );
  }

  /// Abre URL en navegador externo
  Future<void> _launchUrl(String url) async {
    final uri = Uri.parse(url);
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    }
  }

  /// Comparte el artículo
  void _shareArticle(BuildContext context) {
    final shareText = '${widget.article.title}\n\n${widget.article.link}';
    Share.share(shareText, subject: widget.article.title);
  }

  /// Copia el enlace al portapapeles
  void _copyLink(BuildContext context) {
    Clipboard.setData(ClipboardData(text: widget.article.link));
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            Icon(Icons.check_circle, color: Colors.white),
            SizedBox(width: 12),
            Expanded(
              child: Text(
                'Enlace copiado al portapapeles',
                style: TextStyle(fontSize: 14),
              ),
            ),
          ],
        ),
        backgroundColor: Colors.green,
        behavior: SnackBarBehavior.floating,
        duration: Duration(seconds: 2),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      ),
    );
  }
}
