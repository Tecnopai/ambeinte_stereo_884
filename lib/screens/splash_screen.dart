import 'package:flutter/material.dart';
import '../core/theme/app_colors.dart';
import 'main_screen.dart';

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen>
    with TickerProviderStateMixin {
  late AnimationController _logoController;
  late AnimationController _pulseController;
  late AnimationController _fadeController;

  late Animation<double> _logoScale;
  late Animation<double> _logoOpacity;
  late Animation<double> _pulseScale;
  late Animation<double> _fadeAnimation;

  @override
  void initState() {
    super.initState();
    _initializeAnimations();
    _startSplashSequence();
  }

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
    // Información del dispositivo para responsividad
    final screenSize = MediaQuery.of(context).size;
    final isTablet = screenSize.shortestSide >= 600;

    // Tamaños responsivos
    final logoSize = isTablet ? 160.0 : 120.0;
    final titleFontSize = isTablet ? 28.0 : 24.0;
    final subtitleFontSize = isTablet ? 18.0 : 16.0;
    final loadingSize = isTablet ? 40.0 : 32.0;

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

                    // Logo animado
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
                                    blurRadius: isTablet ? 30 : 20,
                                    spreadRadius: isTablet ? 10 : 5,
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

                    SizedBox(height: isTablet ? 40 : 32),

                    // Título
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

                    SizedBox(height: isTablet ? 12 : 8),

                    // Subtítulo
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

                    const Spacer(),

                    // Indicador de carga
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
                                  strokeWidth: isTablet ? 3 : 2.5,
                                ),
                              ),
                              SizedBox(height: isTablet ? 20 : 16),
                              Text(
                                'Cargando...',
                                style: TextStyle(
                                  color: AppColors.textMuted,
                                  fontSize: isTablet ? 16 : 14,
                                  letterSpacing: 0.5,
                                ),
                              ),
                            ],
                          ),
                        );
                      },
                    ),

                    SizedBox(height: isTablet ? 60 : 40),
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
