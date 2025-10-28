import 'package:flutter/material.dart';
import 'package:package_info_plus/package_info_plus.dart'; // Añadir esta importación
import '../core/theme/app_colors.dart';
import '../utils/responsive_helper.dart';
import 'main_screen.dart';

/// Pantalla de bienvenida con animaciones
/// Muestra el logo, nombre de la emisora, versión y un indicador de carga
/// Se presenta al iniciar la aplicación antes de navegar a la pantalla principal
class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen>
    with TickerProviderStateMixin {
  // Controladores de animación
  late AnimationController _logoController;
  late AnimationController _pulseController;
  late AnimationController _fadeController;

  // Animaciones
  late Animation<double> _logoScale;
  late Animation<double> _logoOpacity;
  late Animation<double> _pulseScale;
  late Animation<double> _fadeAnimation;

  // Variable para almacenar la versión
  String _version = 'Cargando...';

  @override
  void initState() {
    super.initState();
    _initializeAnimations();
    _loadVersion(); // Cargar la versión
    _startSplashSequence();
  }

  /// Carga la versión de la aplicación
  Future<void> _loadVersion() async {
    try {
      final packageInfo = await PackageInfo.fromPlatform();
      if (mounted) {
        setState(() {
          _version = packageInfo.version;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _version = '2.0.0'; // Versión por defecto en caso de error
        });
      }
    }
  }

  /// Inicializa todas las animaciones de la pantalla splash
  void _initializeAnimations() {
    // Animación del logo (escala y opacidad)
    _logoController = AnimationController(
      duration: const Duration(milliseconds: 1000),
      vsync: this,
    );

    _logoScale = Tween<double>(begin: 0.3, end: 1.0).animate(
      CurvedAnimation(parent: _logoController, curve: Curves.elasticOut),
    );

    _logoOpacity = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _logoController,
        curve: const Interval(0.0, 0.6, curve: Curves.easeOut),
      ),
    );

    // Animación de pulso continuo
    _pulseController = AnimationController(
      duration: const Duration(milliseconds: 1500),
      vsync: this,
    );

    _pulseScale = Tween<double>(begin: 1.0, end: 1.1).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut),
    );

    // Animación de fade out final
    _fadeController = AnimationController(
      duration: const Duration(milliseconds: 500),
      vsync: this,
    );

    _fadeAnimation = Tween<double>(
      begin: 1.0,
      end: 0.0,
    ).animate(CurvedAnimation(parent: _fadeController, curve: Curves.easeOut));
  }

  /// Ejecuta la secuencia de animaciones del splash
  /// Espera 2 segundos antes de navegar a la pantalla principal
  Future<void> _startSplashSequence() async {
    // Iniciar animación del logo
    await _logoController.forward();

    // Esperar un momento
    await Future.delayed(const Duration(milliseconds: 300));

    // Iniciar pulso continuo
    _pulseController.repeat(reverse: true);

    // Simular carga de la aplicación (mínimo 2 segundos)
    await Future.delayed(const Duration(seconds: 2));

    // Fade out y navegar
    await _fadeController.forward();

    if (mounted) {
      Navigator.of(context).pushReplacement(
        PageRouteBuilder(
          pageBuilder: (context, animation, secondaryAnimation) =>
              const MainScreen(),
          transitionsBuilder: (context, animation, secondaryAnimation, child) {
            return FadeTransition(opacity: animation, child: child);
          },
          transitionDuration: const Duration(milliseconds: 300),
        ),
      );
    }
  }

  @override
  void dispose() {
    _logoController.dispose();
    _pulseController.dispose();
    _fadeController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final responsive = ResponsiveHelper(context);

    // Tamaños responsivos usando ResponsiveHelper
    final logoSize = responsive.getValue(
      smallPhone: 100.0,
      phone: 120.0,
      largePhone: 130.0,
      tablet: 160.0,
      desktop: 180.0,
      automotive: 140.0,
    );

    final titleFontSize = responsive.getValue(
      smallPhone: 22.0,
      phone: 24.0,
      largePhone: 26.0,
      tablet: 28.0,
      desktop: 32.0,
      automotive: 26.0,
    );

    final subtitleFontSize = responsive.getValue(
      smallPhone: 14.0,
      phone: 16.0,
      largePhone: 17.0,
      tablet: 18.0,
      desktop: 20.0,
      automotive: 18.0,
    );

    // Tamaño de fuente para la versión (más pequeño que el subtítulo)
    final versionFontSize = responsive.getValue(
      smallPhone: 12.0,
      phone: 13.0,
      largePhone: 14.0,
      tablet: 15.0,
      desktop: 16.0,
      automotive: 14.0,
    );

    final loadingSize = responsive.getValue(
      smallPhone: 28.0,
      phone: 32.0,
      largePhone: 36.0,
      tablet: 40.0,
      desktop: 44.0,
      automotive: 36.0,
    );

    final loadingStrokeWidth = responsive.getValue(
      smallPhone: 2.0,
      phone: 2.5,
      tablet: 3.0,
      desktop: 3.5,
      automotive: 3.0,
    );

    final loadingTextSize = responsive.getValue(
      smallPhone: 12.0,
      phone: 14.0,
      largePhone: 15.0,
      tablet: 16.0,
      desktop: 18.0,
      automotive: 16.0,
    );

    // Espaciados adaptativos
    final spacing1 = responsive.spacing(32);
    final spacing2 = responsive.spacing(10);
    final spacingVersion = responsive.spacing(4); // Espaciado para la versión
    final spacing3 = responsive.spacing(16);
    final spacing4 = responsive.spacing(40);

    // Blur radius para sombras
    final blurRadius = responsive.getValue(
      phone: 20.0,
      tablet: 30.0,
      desktop: 35.0,
      automotive: 25.0,
    );

    final spreadRadius = responsive.getValue(
      phone: 5.0,
      tablet: 10.0,
      desktop: 12.0,
      automotive: 8.0,
    );

    return Scaffold(
      body: AnimatedBuilder(
        animation: _fadeAnimation,
        builder: (context, child) {
          return Opacity(
            opacity: _fadeAnimation.value,
            child: Container(
              width: double.infinity,
              height: double.infinity,
              decoration: const BoxDecoration(
                gradient: AppColors.primaryGradient,
              ),
              child: SafeArea(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Spacer(flex: 2),

                    // Logo animado con efecto de escala y pulso
                    AnimatedBuilder(
                      animation: Listenable.merge([
                        _logoController,
                        _pulseController,
                      ]),
                      builder: (context, child) {
                        return Transform.scale(
                          scale: _logoScale.value * _pulseScale.value,
                          child: Opacity(
                            opacity: _logoOpacity.value,
                            child: Container(
                              width: logoSize,
                              height: logoSize,
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                gradient: const RadialGradient(
                                  colors: [
                                    Color.fromARGB(31, 136, 137, 239),
                                    Color.fromARGB(31, 138, 92, 246),
                                    Color.fromARGB(31, 124, 104, 238),
                                  ],
                                ),
                                boxShadow: [
                                  BoxShadow(
                                    color: const Color.fromARGB(
                                      104,
                                      200,
                                      201,
                                      242,
                                    ).withValues(alpha: 0.1),
                                    blurRadius: blurRadius,
                                    spreadRadius: spreadRadius,
                                  ),
                                ],
                              ),
                              child: ClipOval(
                                child: Image.asset(
                                  'assets/images/ambiente_logo.png',
                                  width: logoSize * 0.7,
                                  height: logoSize * 0.7,
                                  fit: BoxFit.cover,
                                  errorBuilder: (context, error, stackTrace) {
                                    return Icon(
                                      Icons.radio,
                                      color: AppColors.textPrimary,
                                      size: logoSize * 0.5,
                                    );
                                  },
                                ),
                              ),
                            ),
                          ),
                        );
                      },
                    ),

                    SizedBox(height: spacing1),

                    // Título de la emisora con animación de opacidad
                    AnimatedBuilder(
                      animation: _logoOpacity,
                      builder: (context, child) {
                        return Opacity(
                          opacity: _logoOpacity.value,
                          child: Text(
                            'Ambiente Stereo',
                            style: TextStyle(
                              fontSize: titleFontSize,
                              fontWeight: FontWeight.bold,
                              color: AppColors.textPrimary,
                              letterSpacing: 1.2,
                            ),
                          ),
                        );
                      },
                    ),

                    SizedBox(height: spacing2),

                    // Frecuencia de la emisora
                    AnimatedBuilder(
                      animation: _logoOpacity,
                      builder: (context, child) {
                        return Opacity(
                          opacity: _logoOpacity.value * 0.8,
                          child: Text(
                            '88.4 FM',
                            style: TextStyle(
                              fontSize: subtitleFontSize,
                              color: AppColors.textMuted,
                              letterSpacing: 2.0,
                            ),
                          ),
                        );
                      },
                    ),

                    // Versión de la aplicación
                    SizedBox(height: spacingVersion),
                    AnimatedBuilder(
                      animation: _logoOpacity,
                      builder: (context, child) {
                        return Opacity(
                          opacity: _logoOpacity.value * 0.6,
                          child: Text(
                            'v$_version',
                            style: TextStyle(
                              fontSize: versionFontSize,
                              color: AppColors.textMuted,
                              letterSpacing: 1.0,
                            ),
                          ),
                        );
                      },
                    ),

                    const Spacer(),

                    // Indicador de carga circular
                    AnimatedBuilder(
                      animation: _logoOpacity,
                      builder: (context, child) {
                        return Opacity(
                          opacity: _logoOpacity.value,
                          child: Column(
                            children: [
                              SizedBox(
                                width: loadingSize,
                                height: loadingSize,
                                child: CircularProgressIndicator(
                                  color: AppColors.primary,
                                  strokeWidth: loadingStrokeWidth,
                                ),
                              ),
                              SizedBox(height: spacing3),
                              Text(
                                'Cargando...',
                                style: TextStyle(
                                  color: AppColors.textMuted,
                                  fontSize: loadingTextSize,
                                  letterSpacing: 0.5,
                                ),
                              ),
                            ],
                          ),
                        );
                      },
                    ),

                    SizedBox(height: spacing4),
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}
