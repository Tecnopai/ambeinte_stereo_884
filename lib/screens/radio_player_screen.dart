import 'package:flutter/material.dart';
import 'package:firebase_analytics/firebase_analytics.dart';
import '../services/audio_player_manager.dart';
import '../widgets/animated_disc.dart';
import '../widgets/volume_control.dart';
import '../widgets/sound_waves.dart';
import '../core/theme/app_colors.dart';
import '../utils/responsive_helper.dart';

/// Pantalla principal del reproductor de radio
/// Muestra controles de reproducción, animaciones visuales y estado de conexión.
/// Incluye disco animado, ondas de sonido y control de volumen.
class RadioPlayerScreen extends StatefulWidget {
  /// Constructor de RadioPlayerScreen.
  const RadioPlayerScreen({super.key});

  @override
  State<RadioPlayerScreen> createState() => _RadioPlayerScreenState();
}

/// Estado y lógica principal para el reproductor de radio.
/// Utiliza [TickerProviderStateMixin] para manejar animaciones (como SoundWaves o AnimatedDisc).
class _RadioPlayerScreenState extends State<RadioPlayerScreen>
    with TickerProviderStateMixin {
  /// Obtiene la instancia singleton del [AudioPlayerManager] para controlar el audio.
  late final AudioPlayerManager _audioManager;

  /// Instancia de [FirebaseAnalytics] para registrar eventos del usuario.
  final analytics = FirebaseAnalytics.instance;

  // --- Variables de Estado ---

  /// Estado de reproducción actual (true si está sonando).
  bool _isPlaying = true;

  /// Indica si la radio está cargando o intentando reconectar.
  bool _isLoading = true;

  /// Mensaje de error o estado de reconexión a mostrar en la interfaz.
  String? _errorMessage;

  /// Inicializa el Audio Manager, configura los listeners y registra la vista.
  @override
  void initState() {
    super.initState();

    // Registrar vista de pantalla en Firebase Analytics.
    analytics.logScreenView(
      screenName: 'radio_player',
      screenClass: 'RadioPlayerScreen',
    );

    // Obtener singleton en initState.
    _audioManager = AudioPlayerManager();
    _setupListeners();
    _initializeStates();
  }

  /// Configura los listeners para los diferentes streams del audio manager
  /// para actualizar el estado local de la UI.
  void _setupListeners() {
    // Listener de reproducción: Actualiza el estado local [_isPlaying].
    _audioManager.playingStream.listen((isPlaying) {
      if (mounted) {
        setState(() {
          _isPlaying = isPlaying;
        });
      }
    });

    // Listener de carga: Actualiza el estado local [_isLoading].
    _audioManager.loadingStream.listen((isLoading) {
      if (mounted) {
        setState(() {
          _isLoading = isLoading;
        });
      }
    });

    // Listener de errores y reconexiones: Muestra mensajes temporales.
    _audioManager.errorStream.listen((error) {
      if (mounted) {
        setState(() {
          _errorMessage = error;
        });

        // Mostrar SnackBar con el estado de error o reconexión
        if (error.isNotEmpty) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Row(
                children: [
                  // Icono de éxito si es un mensaje de reconexión exitosa
                  if (error.contains('Reconectado'))
                    const Icon(Icons.check_circle, color: Colors.white)
                  // Icono de información para otros errores/avisos
                  else
                    const Icon(Icons.info, color: Colors.white),
                  const SizedBox(width: 8),
                  Expanded(child: Text(error)),
                ],
              ),
              // Color verde para reconexión exitosa, amarillo para advertencia/error
              backgroundColor: error.contains('Reconectado')
                  ? AppColors.success
                  : AppColors.warning,
              duration: const Duration(seconds: 3),
            ),
          );

          // Limpiar el mensaje de error de la interfaz después de un breve retraso.
          Future.delayed(const Duration(seconds: 3), () {
            if (mounted) {
              setState(() {
                _errorMessage = null;
              });
            }
          });
        }
      }
    });
  }

  /// Inicializa los estados con los valores actuales del [AudioPlayerManager].
  void _initializeStates() {
    _isPlaying = _audioManager.isPlaying;
    _isLoading = _audioManager.isLoading;
  }

  /// Alterna entre reproducir y pausar la radio.
  Future<void> _togglePlayback() async {
    try {
      await _audioManager.togglePlayback();

      // Registrar evento de play/pause en Firebase Analytics.
      await analytics.logEvent(
        name: _audioManager.isPlaying ? 'audio_play' : 'audio_pause',
        parameters: {'station': 'Ambiente Stereo 88.4'},
      );
    } catch (e) {
      // Muestra un SnackBar si la conexión inicial falla.
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

  /// Construye el widget principal de la pantalla.
  @override
  Widget build(BuildContext context) {
    final responsive = ResponsiveHelper(context);
    final isLandscape =
        MediaQuery.of(context).orientation == Orientation.landscape;

    return Scaffold(
      appBar: AppBar(
        title: Text(
          'Ambiente Stereo 88.4 FM',
          style: TextStyle(
            fontSize: responsive.getValue(
              smallPhone: 16.0,
              phone: 18.0,
              largePhone: 19.0,
              tablet: 20.0,
              desktop: 22.0,
              automotive: 20.0,
            ),
            fontWeight: FontWeight.w600,
          ),
        ),
        centerTitle: true,
        actions: [
          if (_errorMessage != null &&
              _errorMessage!.isNotEmpty &&
              !_errorMessage!.contains('Reconectado'))
            Padding(
              padding: const EdgeInsets.only(right: 16),
              child: Center(child: _buildReconnectingIndicator(responsive)),
            ),
        ],
      ),
      body: Container(
        width: double.infinity,
        height: double.infinity,
        decoration: const BoxDecoration(gradient: AppColors.primaryGradient),
        // ✅ Layout diferente para landscape vs portrait
        child: isLandscape
            ? _buildLandscapeLayout(responsive)
            : _buildPortraitLayout(responsive),
      ),
    );
  }

  /// Construye el layout para orientación portrait (vertical)
  Widget _buildPortraitLayout(ResponsiveHelper responsive) {
    final padding = responsive.getValue(
      smallPhone: 16.0,
      phone: 20.0,
      largePhone: 24.0,
      tablet: 32.0,
      desktop: 40.0,
      automotive: 24.0,
    );

    return SingleChildScrollView(
      padding: EdgeInsets.all(padding),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          SizedBox(height: responsive.spacing(20)),

          // Disco animado
          Transform.scale(
            scale: responsive.getValue(
              smallPhone: 0.7,
              phone: 0.8,
              largePhone: 0.9,
              tablet: 1.0,
              desktop: 1.1,
              automotive: 0.9,
            ),
            child: AnimatedDisc(isPlaying: _isPlaying),
          ),

          SizedBox(height: responsive.spacing(25)),

          // Información de la estación
          Text(
            'Ambiente Stereo 88.4 FM',
            style: TextStyle(
              fontSize: responsive.getValue(
                smallPhone: 14.0,
                phone: 16.0,
                largePhone: 18.0,
                tablet: 20.0,
                desktop: 22.0,
                automotive: 18.0,
              ),
              fontWeight: FontWeight.bold,
              color: AppColors.textPrimary,
              letterSpacing: 0.5,
            ),
            textAlign: TextAlign.center,
          ),

          SizedBox(height: responsive.spacing(12)),

          // Texto de estado
          _buildStatusText(
            responsive,
            responsive.getValue(
              smallPhone: 12.0,
              phone: 14.0,
              largePhone: 15.0,
              tablet: 16.0,
              desktop: 18.0,
              automotive: 15.0,
            ),
          ),

          SizedBox(height: responsive.spacing(25)),

          // Ondas de sonido
          if (_isPlaying && !_isLoading)
            Padding(
              padding: EdgeInsets.symmetric(
                vertical: responsive.getValue(
                  smallPhone: 3.0,
                  phone: 5.0,
                  largePhone: 8.0,
                  tablet: 12.0,
                  desktop: 15.0,
                  automotive: 8.0,
                ),
              ),
              child: SoundWaves(isPlaying: _isPlaying),
            ),

          if (_isPlaying && !_isLoading)
            SizedBox(height: responsive.spacing(25)),

          // Botón de play/pause
          _buildPlayButton(
            responsive: responsive,
            size: responsive.getValue(
              smallPhone: 70.0,
              phone: 80.0,
              largePhone: 90.0,
              tablet: 100.0,
              desktop: 120.0,
              automotive: 90.0,
            ),
            iconSize: responsive.getValue(
              smallPhone: 35.0,
              phone: 40.0,
              largePhone: 45.0,
              tablet: 50.0,
              desktop: 60.0,
              automotive: 45.0,
            ),
            loadingSize: responsive.getValue(
              smallPhone: 26.0,
              phone: 30.0,
              largePhone: 34.0,
              tablet: 40.0,
              desktop: 48.0,
              automotive: 36.0,
            ),
          ),

          SizedBox(height: responsive.spacing(25)),

          // Control de volumen
          SizedBox(
            width: responsive.getValue(
              smallPhone: 250.0,
              phone: 280.0,
              largePhone: 320.0,
              tablet: 400.0,
              desktop: 500.0,
              automotive: 320.0,
            ),
            child: VolumeControl(audioManager: _audioManager),
          ),

          SizedBox(height: responsive.spacing(20)),
        ],
      ),
    );
  }

  /// Construye el layout para orientación landscape (horizontal)
  Widget _buildLandscapeLayout(ResponsiveHelper responsive) {
    return Padding(
      padding: EdgeInsets.symmetric(
        horizontal: responsive.getValue(
          smallPhone: 12.0,
          phone: 16.0,
          largePhone: 20.0,
          tablet: 24.0,
          desktop: 32.0,
          automotive: 20.0,
        ),
        vertical: responsive.getValue(
          // ✅ Menos altura vertical
          smallPhone: 8.0,
          phone: 10.0,
          largePhone: 12.0,
          tablet: 16.0,
          desktop: 20.0,
          automotive: 12.0,
        ),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          // Columna izquierda: Disco más grande
          Expanded(
            flex: 2, // ✅ Más espacio para el disco
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              mainAxisSize: MainAxisSize.min,
              children: [
                // Disco animado - MÁS GRANDE en landscape
                Transform.scale(
                  scale: responsive.getValue(
                    smallPhone: 0.8, // ✅ Más grande
                    phone: 0.9,
                    largePhone: 1.0,
                    tablet: 1.1,
                    desktop: 1.2,
                    automotive: 1.0,
                  ),
                  child: AnimatedDisc(isPlaying: _isPlaying),
                ),

                SizedBox(height: responsive.spacing(8)), // ✅ Menos espaciado
                // Información compacta
                Text(
                  'Ambiente Stereo 88.4 FM',
                  style: TextStyle(
                    fontSize: responsive.getValue(
                      smallPhone: 11.0,
                      phone: 13.0,
                      largePhone: 15.0,
                      tablet: 17.0,
                      desktop: 19.0,
                      automotive: 15.0,
                    ),
                    fontWeight: FontWeight.bold,
                    color: AppColors.textPrimary,
                  ),
                  textAlign: TextAlign.center,
                  maxLines: 2,
                ),

                SizedBox(height: responsive.spacing(4)), // ✅ Menos espaciado

                _buildStatusText(
                  responsive,
                  responsive.getValue(
                    smallPhone: 9.0,
                    phone: 10.0,
                    largePhone: 11.0,
                    tablet: 12.0,
                    desktop: 13.0,
                    automotive: 11.0,
                  ),
                ),
              ],
            ),
          ),

          SizedBox(
            width: responsive.spacing(12),
          ), // ✅ Menos espacio entre columnas
          // Columna derecha: Controles compactos
          Expanded(
            flex: 1, // ✅ Menos espacio para controles
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              mainAxisSize: MainAxisSize.min,
              children: [
                // Eliminamos las ondas de sonido en landscape para ahorrar espacio

                // Botón de play/pause compacto
                _buildPlayButton(
                  responsive: responsive,
                  size: responsive.getValue(
                    smallPhone: 60.0,
                    phone: 70.0,
                    largePhone: 80.0,
                    tablet: 90.0,
                    desktop: 100.0,
                    automotive: 80.0,
                  ),
                  iconSize: responsive.getValue(
                    smallPhone: 28.0,
                    phone: 32.0,
                    largePhone: 36.0,
                    tablet: 40.0,
                    desktop: 44.0,
                    automotive: 36.0,
                  ),
                  loadingSize: responsive.getValue(
                    smallPhone: 22.0,
                    phone: 26.0,
                    largePhone: 30.0,
                    tablet: 34.0,
                    desktop: 38.0,
                    automotive: 30.0,
                  ),
                ),

                SizedBox(height: responsive.spacing(8)), // ✅ Menos espaciado
                // Control de volumen
                SizedBox(
                  width: responsive.getValue(
                    smallPhone: 140.0,
                    phone: 160.0,
                    largePhone: 180.0,
                    tablet: 200.0,
                    desktop: 220.0,
                    automotive: 180.0,
                  ),
                  child: VolumeControl(audioManager: _audioManager),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  /// Construye el widget de texto de estado (Conectando / En vivo / Pausado).
  Widget _buildStatusText(ResponsiveHelper responsive, double fontSize) {
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

    final indicatorSize = responsive.getValue(
      smallPhone: 6.0,
      phone: 7.0,
      largePhone: 8.0,
      tablet: 9.0,
      desktop: 10.0,
      automotive: 8.0,
    );

    final indicatorSpacing = responsive.getValue(
      smallPhone: 4.0,
      phone: 5.0,
      largePhone: 6.0,
      tablet: 7.0,
      desktop: 8.0,
      automotive: 6.0,
    );

    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        // Indicador circular de estado (punto animado)
        if (_isLoading || _isPlaying)
          Container(
            width: indicatorSize,
            height: indicatorSize,
            margin: EdgeInsets.only(right: indicatorSpacing),
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: statusColor,
              boxShadow: [
                BoxShadow(
                  color: statusColor.withValues(alpha: 0.5),
                  blurRadius: 6,
                  spreadRadius: 1,
                ),
              ],
            ),
          ),
        Text(
          statusText,
          style: TextStyle(
            fontSize: fontSize,
            color: statusColor,
            letterSpacing: 0.2,
            fontWeight: _isLoading ? FontWeight.w600 : FontWeight.normal,
          ),
          textAlign: TextAlign.center,
        ),
      ],
    );
  }

  /// Construye el indicador de reconexión que aparece en el AppBar
  Widget _buildReconnectingIndicator(ResponsiveHelper responsive) {
    final horizontalPadding = responsive.getValue(
      smallPhone: 4.0,
      phone: 6.0,
      largePhone: 8.0,
      tablet: 10.0,
      desktop: 12.0,
      automotive: 8.0,
    );

    final verticalPadding = responsive.getValue(
      smallPhone: 2.0,
      phone: 3.0,
      largePhone: 4.0,
      tablet: 5.0,
      desktop: 6.0,
      automotive: 4.0,
    );

    final indicatorSize = responsive.getValue(
      smallPhone: 9.0,
      phone: 10.0,
      largePhone: 11.0,
      tablet: 12.0,
      desktop: 14.0,
      automotive: 11.0,
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
      smallPhone: 7.0,
      phone: 8.0,
      largePhone: 9.0,
      tablet: 10.0,
      desktop: 11.0,
      automotive: 9.0,
    );

    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: horizontalPadding,
        vertical: verticalPadding,
      ),
      decoration: BoxDecoration(
        color: AppColors.warning.withValues(alpha: 0.2),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(
          color: AppColors.warning.withValues(alpha: 0.5),
          width: 1,
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          SizedBox(
            width: indicatorSize,
            height: indicatorSize,
            child: const CircularProgressIndicator(
              strokeWidth: 1.5,
              valueColor: AlwaysStoppedAnimation<Color>(AppColors.warning),
            ),
          ),
          SizedBox(width: spacing),
          Text(
            'Reconectando...',
            style: TextStyle(
              fontSize: fontSize,
              color: AppColors.warning,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }

  /// Construye el botón circular de reproducción/pausa.
  /// Muestra un indicador de carga si [_isLoading] es true.
  Widget _buildPlayButton({
    required ResponsiveHelper responsive,
    required double size,
    required double iconSize,
    required double loadingSize,
  }) {
    final shadowBlur = responsive.getValue(
      smallPhone: 8.0,
      phone: 10.0,
      largePhone: 12.0,
      tablet: 15.0,
      desktop: 18.0,
      automotive: 12.0,
    );

    final shadowSpread = responsive.getValue(
      smallPhone: 1.0,
      phone: 1.5,
      largePhone: 2.0,
      tablet: 2.5,
      desktop: 3.0,
      automotive: 2.0,
    );

    final strokeWidth = responsive.getValue(
      smallPhone: 2.0,
      phone: 2.5,
      largePhone: 3.0,
      tablet: 3.5,
      desktop: 4.0,
      automotive: 3.0,
    );

    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: AppColors.buttonGradient,
        boxShadow: [
          BoxShadow(
            color: const Color.fromARGB(77, 203, 203, 229),
            blurRadius: shadowBlur,
            spreadRadius: shadowSpread,
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
                      strokeWidth: strokeWidth,
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
