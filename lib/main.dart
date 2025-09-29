import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:webview_flutter/webview_flutter.dart';
import 'package:firebase_core/firebase_core.dart';
import 'firebase_options.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Permitir todas las orientaciones para mejor responsividad
  await SystemChrome.setPreferredOrientations([
    DeviceOrientation.portraitUp,
    DeviceOrientation.portraitDown,
    DeviceOrientation.landscapeLeft,
    DeviceOrientation.landscapeRight,
  ]);

  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);

  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Ambientestereo884.fm',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFF39A935),
          brightness: Brightness.light,
        ),
        useMaterial3: true,
        appBarTheme: const AppBarTheme(
          systemOverlayStyle: SystemUiOverlayStyle.dark,
        ),
      ),
      home: const MyHomePage(),
    );
  }
}

// Enum para tipos de dispositivo
enum DeviceType { mobile, tablet, desktop }

// Clase para obtener información del dispositivo
class ResponsiveHelper {
  static DeviceType getDeviceType(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;

    if (screenWidth < 600) {
      return DeviceType.mobile;
    } else if (screenWidth < 1200) {
      return DeviceType.tablet;
    } else {
      return DeviceType.desktop;
    }
  }

  static bool isLandscape(BuildContext context) {
    return MediaQuery.of(context).orientation == Orientation.landscape;
  }

  static double getResponsiveSize(BuildContext context, {
    required double mobile,
    required double tablet,
    required double desktop,
  }) {
    switch (getDeviceType(context)) {
      case DeviceType.mobile:
        return mobile;
      case DeviceType.tablet:
        return tablet;
      case DeviceType.desktop:
        return desktop;
    }
  }
}

class MyHomePage extends StatefulWidget {
  const MyHomePage({super.key});

  @override
  State<MyHomePage> createState() => _MyHomePageState();
}

class _MyHomePageState extends State<MyHomePage> with TickerProviderStateMixin {
  late WebViewController _controller;
  int _progress = 0;
  bool _isLoading = true;
  bool _hasError = false;
  String _errorMessage = '';

  late AnimationController _logoAnimationController;
  late Animation<double> _logoScaleAnimation;
  late Animation<double> _logoOpacityAnimation;

  @override
  void initState() {
    super.initState();
    _initializeAnimations();
    _initializeWebView();
  }

  void _initializeAnimations() {
    _logoAnimationController = AnimationController(
      duration: const Duration(milliseconds: 1500),
      vsync: this,
    );

    _logoScaleAnimation = Tween<double>(begin: 0.8, end: 1.2).animate(
      CurvedAnimation(
        parent: _logoAnimationController,
        curve: Curves.easeInOut,
      ),
    );

    _logoOpacityAnimation = Tween<double>(begin: 0.7, end: 1.0).animate(
      CurvedAnimation(
        parent: _logoAnimationController,
        curve: Curves.easeInOut,
      ),
    );

    _logoAnimationController.repeat(reverse: true);
  }

  void _initializeWebView() {
    _controller = WebViewController()
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..setBackgroundColor(Colors.white)
      ..setUserAgent(
        'Mozilla/5.0 (Linux; Android 13; SM-G991B) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Mobile Safari/537.36',
      )
      ..enableZoom(false)
      ..setNavigationDelegate(
        NavigationDelegate(
          onProgress: (int progress) {
            if (mounted && progress != _progress) {
              setState(() {
                _progress = progress;
              });
            }
          },
          onPageStarted: (String url) {
            if (mounted) {
              setState(() {
                _isLoading = true;
                _hasError = false;
                _progress = 0;
              });
            }
          },
          onPageFinished: (String url) {
            if (mounted) {
              Future.delayed(const Duration(milliseconds: 500), () {
                if (mounted) {
                  setState(() {
                    _progress = 100;
                    _isLoading = false;
                  });
                  _logoAnimationController.stop();
                }
              });
            }
          },
          onWebResourceError: (WebResourceError error) {
            if (mounted && error.errorType != WebResourceErrorType.unknown) {
              setState(() {
                _hasError = true;
                _isLoading = false;
                _errorMessage = error.description;
              });
            }
          },
          onNavigationRequest: (NavigationRequest request) {
            if (request.url.startsWith('https://ambientestereo.fm/')) {
              return NavigationDecision.navigate;
            }
            return NavigationDecision.prevent;
          },
        ),
      );

    _loadWebsite();
  }

  void _loadWebsite() async {
    try {
      await _controller.loadRequest(
        Uri.parse('https://ambientestereo.fm/sitio/'),
      );
    } catch (e) {
      if (mounted) {
        setState(() {
          _hasError = true;
          _isLoading = false;
          _errorMessage = 'Error al cargar la página';
        });
      }
    }
  }

  void _reloadPage() {
    setState(() {
      _hasError = false;
      _isLoading = true;
      _progress = 0;
    });
    _logoAnimationController.repeat(reverse: true);
    _loadWebsite();
  }

  // Logo responsive que se adapta al dispositivo
  Widget _buildResponsiveLogo(BuildContext context) {
    final logoSize = ResponsiveHelper.getResponsiveSize(
      context,
      mobile: 100.0,
      tablet: 140.0,
      desktop: 160.0,
    );

    final isLandscape = ResponsiveHelper.isLandscape(context);
    final adjustedSize = isLandscape ? logoSize * 0.8 : logoSize;

    return Container(
      width: adjustedSize,
      height: adjustedSize,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(20),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(20),
        child: Image.asset(
          'assets/images/ambiente_logo.png',
          width: adjustedSize,
          height: adjustedSize,
          fit: BoxFit.cover,
        ),
      ),
    );
  }

  // Pantalla de carga responsive
  Widget _buildLoadingScreen(BuildContext context) {
    final isLandscape = ResponsiveHelper.isLandscape(context);
    final deviceType = ResponsiveHelper.getDeviceType(context);

    // Ajustar layout para landscape en móviles
    if (isLandscape && deviceType == DeviceType.mobile) {
      return Container(
        width: double.infinity,
        height: double.infinity,
        color: Colors.white,
        child: Row(
          children: [
            // Logo en el lado izquierdo
            Expanded(
              flex: 1,
              child: Center(
                child: AnimatedBuilder(
                  animation: _logoAnimationController,
                  builder: (context, child) {
                    return Transform.scale(
                      scale: _logoScaleAnimation.value,
                      child: Opacity(
                        opacity: _logoOpacityAnimation.value,
                        child: _buildResponsiveLogo(context),
                      ),
                    );
                  },
                ),
              ),
            ),
            // Información en el lado derecho
            Expanded(
              flex: 1,
              child: Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    _buildTitleAndProgress(context),
                  ],
                ),
              ),
            ),
          ],
        ),
      );
    }

    // Layout vertical para portrait y tablets
    return Container(
      width: double.infinity,
      height: double.infinity,
      color: Colors.white,
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          // Logo animado
          AnimatedBuilder(
            animation: _logoAnimationController,
            builder: (context, child) {
              return Transform.scale(
                scale: _logoScaleAnimation.value,
                child: Opacity(
                  opacity: _logoOpacityAnimation.value,
                  child: _buildResponsiveLogo(context),
                ),
              );
            },
          ),

          SizedBox(height: isLandscape ? 20 : 30),

          _buildTitleAndProgress(context),
        ],
      ),
    );
  }

  // Widget para título y barra de progreso
  Widget _buildTitleAndProgress(BuildContext context) {
    final titleSize = ResponsiveHelper.getResponsiveSize(
      context,
      mobile: 24.0,
      tablet: 28.0,
      desktop: 32.0,
    );

    final progressBarWidth = ResponsiveHelper.getResponsiveSize(
      context,
      mobile: MediaQuery.of(context).size.width * 0.6,
      tablet: 300.0,
      desktop: 400.0,
    );

    return Column(
      children: [
        // Título responsive
        Text(
          'Ambientestereo.fm',
          style: TextStyle(
            fontSize: titleSize,
            fontWeight: FontWeight.bold,
            color: const Color(0xFF39A935),
            letterSpacing: 1.2,
          ),
        ),
        const SizedBox(height: 10),

        // Subtítulo
        Text(
          'Cargando...',
          style: TextStyle(
            fontSize: ResponsiveHelper.getResponsiveSize(
              context,
              mobile: 16.0,
              tablet: 18.0,
              desktop: 20.0,
            ),
            color: Colors.grey[600],
          ),
        ),
        const SizedBox(height: 40),

        // Barra de progreso responsive
        Container(
          width: progressBarWidth,
          height: 6,
          decoration: BoxDecoration(
            color: Colors.grey[200],
            borderRadius: BorderRadius.circular(3),
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(3),
            child: LinearProgressIndicator(
              value: _progress / 100,
              backgroundColor: Colors.transparent,
              valueColor: const AlwaysStoppedAnimation<Color>(
                Color(0xFF6B73FF),
              ),
            ),
          ),
        ),
        const SizedBox(height: 15),

        // Porcentaje de carga
        Text(
          '${_progress}%',
          style: TextStyle(
            fontSize: ResponsiveHelper.getResponsiveSize(
              context,
              mobile: 14.0,
              tablet: 16.0,
              desktop: 18.0,
            ),
            color: Colors.grey[600],
            fontWeight: FontWeight.w500,
          ),
        ),
      ],
    );
  }

  // Pantalla de error responsive
  Widget _buildErrorScreen(BuildContext context) {
    final iconSize = ResponsiveHelper.getResponsiveSize(
      context,
      mobile: 80.0,
      tablet: 100.0,
      desktop: 120.0,
    );

    final buttonPadding = ResponsiveHelper.getResponsiveSize(
      context,
      mobile: 30.0,
      tablet: 40.0,
      desktop: 50.0,
    );

    return Container(
      width: double.infinity,
      height: double.infinity,
      color: Colors.white,
      child: SingleChildScrollView(
        child: Padding(
          padding: EdgeInsets.symmetric(horizontal: buttonPadding),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              SizedBox(height: MediaQuery.of(context).size.height * 0.2),

              Icon(
                Icons.error_outline,
                size: iconSize,
                color: Colors.red[400],
              ),
              const SizedBox(height: 20),

              Text(
                'Error de conexión',
                style: TextStyle(
                  fontSize: ResponsiveHelper.getResponsiveSize(
                    context,
                    mobile: 22.0,
                    tablet: 26.0,
                    desktop: 30.0,
                  ),
                  fontWeight: FontWeight.bold,
                  color: Colors.red,
                ),
              ),
              const SizedBox(height: 10),

              Text(
                _errorMessage.isNotEmpty
                    ? _errorMessage
                    : 'No se pudo cargar la página. Verifica tu conexión a internet.',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: ResponsiveHelper.getResponsiveSize(
                    context,
                    mobile: 16.0,
                    tablet: 18.0,
                    desktop: 20.0,
                  ),
                  color: Colors.grey[600],
                ),
              ),
              const SizedBox(height: 30),

              ElevatedButton.icon(
                onPressed: _reloadPage,
                icon: const Icon(Icons.refresh),
                label: const Text('Reintentar'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF6B73FF),
                  foregroundColor: Colors.white,
                  padding: EdgeInsets.symmetric(
                    horizontal: buttonPadding,
                    vertical: 15,
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(25),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  void dispose() {
    _logoAnimationController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: Stack(
          children: [
            // WebView
            WebViewWidget(controller: _controller),

            // Pantalla de carga responsive
            if (_isLoading && !_hasError) _buildLoadingScreen(context),

            // Pantalla de error responsive
            if (_hasError) _buildErrorScreen(context),
          ],
        ),
      ),
    );
  }
}