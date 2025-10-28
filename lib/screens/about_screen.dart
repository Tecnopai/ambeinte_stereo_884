import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:http/http.dart' as http;
import 'package:html/parser.dart' as html_parser;
import 'package:html/dom.dart' as dom;
import 'package:flutter/gestures.dart';
import 'package:firebase_analytics/firebase_analytics.dart';
import '../services/audio_player_manager.dart';
import '../widgets/mini_player.dart';
import '../widgets/live_indicator.dart';
import '../core/theme/app_colors.dart';
import '../utils/responsive_helper.dart';

/// Pantalla "Acerca de" que muestra información sobre la aplicación y la emisora.
///
/// Incluye logo, descripción, versión, enlaces web y soporte,
/// extrayendo dinámicamente el contenido de la página 'Sobre Nosotros'
/// mediante web scraping.
class AboutScreen extends StatefulWidget {
  /// Constructor de AboutScreen.
  const AboutScreen({super.key});

  @override
  State<AboutScreen> createState() => _AboutScreenState();
}

/// Estado y lógica de la pantalla 'Acerca de'.
class _AboutScreenState extends State<AboutScreen> {
  /// Versión actual de la aplicación. Se inicializa como 'Cargando...'.
  String _version = 'Cargando...';

  /// Instancia del administrador de la reproducción de audio (Singleton).
  late final AudioPlayerManager _audioManager;

  /// Lista de widgets generados dinámicamente a partir del HTML extraído.
  List<Widget> _aboutContent = [];

  /// Indicador de estado para la carga del contenido web.
  bool _isLoadingContent = true;

  /// Instancia de Firebase Analytics para el seguimiento.
  final analytics = FirebaseAnalytics.instance;

  /// {inheritdoc}
  @override
  void initState() {
    super.initState();
    // ananlitica
    // Se registra la vista de pantalla para Firebase Analytics.
    analytics.logScreenView(screenName: 'about', screenClass: 'AboutScreen');
    // obtener singleton
    _audioManager = AudioPlayerManager();
    _loadVersion();
    _loadAboutContent();
  }

  /// Carga la versión de la aplicación desde el sistema.
  Future<void> _loadVersion() async {
    try {
      final packageInfo = await PackageInfo.fromPlatform();
      if (!mounted) return;
      setState(() {
        _version = packageInfo.version;
      });
    } catch (e) {
      // Fallback si no se puede obtener la versión (ej. entorno de pruebas)
      if (!mounted) return;
      setState(() {
        _version = '2.0.0';
      });
    }
  }

  /// Realiza web scraping para cargar el contenido de la página "Sobre Nosotros"
  /// y lo convierte a widgets de Flutter.
  Future<void> _loadAboutContent() async {
    try {
      final response = await http
          .get(Uri.parse('https://ambientestereo.fm/sitio/sobre-nosotros/'))
          .timeout(const Duration(seconds: 10));

      if (response.statusCode == 200) {
        final document = html_parser.parse(response.body);
        // Busca el contenedor principal del contenido (compatible con varios temas WP)
        var contentElement =
            document.querySelector('.entry-content') ??
            document.querySelector('article') ??
            document.querySelector('.post-content');

        List<Widget> widgets = [];

        if (contentElement != null) {
          // Eliminar el título de la página si está duplicado en el contenido
          contentElement.querySelector('h1.entry-title')?.remove();
          final children = contentElement.children;

          if (!mounted) return;

          final responsive = ResponsiveHelper(context);

          // Tamaños de fuente responsivos
          final headerSize = responsive.h3; // 14-20px
          final bodySize = responsive.bodyText; // 14-18px

          for (var element in children) {
            final tagName = element.localName;
            final text = element.text.trim();

            if (text.isEmpty) continue;

            final isHeader =
                tagName == 'h2' || tagName == 'h3' || tagName == 'h4';

            if (isHeader) {
              // Añadir espacio vertical antes de un nuevo encabezado
              if (widgets.isNotEmpty) {
                widgets.add(SizedBox(height: responsive.spacing(20)));
              }

              widgets.add(
                Text(
                  text,
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: headerSize,
                    color: AppColors.textPrimary,
                    height: 1.4,
                  ),
                ),
              );
              widgets.add(SizedBox(height: responsive.spacing(8)));
            } else if (tagName == 'p') {
              final strong = element.querySelector('strong');

              if (strong != null) {
                final strongText = strong.text.trim();
                // Heurística para identificar un subtítulo en mayúsculas dentro de un <p>
                final isAllCaps =
                    strongText == strongText.toUpperCase() &&
                    strongText.length > 3 &&
                    strongText.length < 50;

                if (isAllCaps) {
                  if (widgets.isNotEmpty) {
                    widgets.add(SizedBox(height: responsive.spacing(20)));
                  }

                  widgets.add(
                    Text(
                      strongText,
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: headerSize,
                        color: AppColors.textPrimary,
                        height: 1.4,
                      ),
                    ),
                  );
                  widgets.add(SizedBox(height: responsive.spacing(8)));

                  // Procesar el texto restante del párrafo
                  strong.remove();
                  final remainingText = element.text.trim();

                  if (remainingText.isNotEmpty) {
                    List<InlineSpan> spans = [];
                    _processParagraph(element, spans);

                    if (spans.isNotEmpty) {
                      widgets.add(
                        RichText(
                          text: TextSpan(
                            style: TextStyle(
                              fontSize: bodySize,
                              color: AppColors.textMuted,
                              height: 1.6,
                              letterSpacing: 0.2,
                            ),
                            children: spans,
                          ),
                          textAlign: TextAlign.left,
                        ),
                      );
                      widgets.add(SizedBox(height: responsive.spacing(10)));
                    }
                  }
                  continue;
                }
              }

              // Procesamiento normal del párrafo
              List<InlineSpan> spans = [];
              _processParagraph(element, spans);

              if (spans.isNotEmpty) {
                widgets.add(
                  RichText(
                    text: TextSpan(
                      style: TextStyle(
                        fontSize: bodySize,
                        color: AppColors.textMuted,
                        height: 1.6,
                        letterSpacing: 0.2,
                      ),
                      children: spans,
                    ),
                    textAlign: TextAlign.left,
                  ),
                );
                widgets.add(SizedBox(height: responsive.spacing(10)));
              }
            }
          }
        }

        if (widgets.isEmpty) {
          widgets = [const Text('No se pudo cargar el contenido.')];
        }

        if (!mounted) return;
        setState(() {
          _aboutContent = widgets;
          _isLoadingContent = false;
        });
      } else {
        // En caso de error HTTP, se lanza una excepción que es capturada por el catch.
        throw Exception('Error ${response.statusCode}');
      }
    } catch (e) {
      // Manejo de errores: Si falla la conexión o el scraping, se usa un texto de fallback.
      if (!mounted) return;
      final responsive = ResponsiveHelper(context);

      if (!mounted) return;
      setState(() {
        _aboutContent = [
          Text(
            'Nuestro propósito es promover la protección y conservación del medio ambiente, la participación ciudadana y los valores familiares y sociales a través de una programación variada, educativa y cristocéntrica.',
            style: TextStyle(
              fontSize: responsive.bodyText,
              color: AppColors.textMuted,
              height: 1.6,
            ),
          ),
        ];
        _isLoadingContent = false;
      });
    }
  }

  /// Procesa los nodos dentro de un párrafo o elemento de bloque HTML,
  /// convirtiéndolos en RichText spans, manejando enlaces y formato básico.
  ///
  /// [paragraph] - El elemento HTML de donde se extraen los nodos.
  /// [spans] - La lista de TextSpan a la que se añaden los resultados.
  void _processParagraph(dom.Element paragraph, List<InlineSpan> spans) {
    for (var node in paragraph.nodes) {
      if (node.nodeType == dom.Node.TEXT_NODE) {
        final text = node.text ?? '';
        if (text.trim().isNotEmpty) {
          spans.add(TextSpan(text: text));
        }
      } else if (node.nodeType == dom.Node.ELEMENT_NODE) {
        final element = node as dom.Element;
        final text = element.text.trim();

        if (text.isEmpty) continue;

        if (element.localName == 'a') {
          final href = element.attributes['href'] ?? '';
          spans.add(
            TextSpan(
              text: text,
              style: const TextStyle(
                color: AppColors.primary,
                decoration: TextDecoration.underline,
              ),
              recognizer: TapGestureRecognizer()
                ..onTap = () => _launchUrl(href),
            ),
          );
        } else if (element.localName == 'strong' || element.localName == 'b') {
          spans.add(
            TextSpan(
              text: text,
              style: const TextStyle(
                fontWeight: FontWeight.bold,
                color: AppColors.textPrimary,
              ),
            ),
          );
        } else if (element.localName == 'em' || element.localName == 'i') {
          spans.add(
            TextSpan(
              text: text,
              style: const TextStyle(fontStyle: FontStyle.italic),
            ),
          );
        } else {
          // Recurrente para elementos anidados que no son manejados explícitamente
          if (element.nodes.isNotEmpty) {
            _processParagraph(element, spans);
          } else {
            spans.add(TextSpan(text: text));
          }
        }
      }
    }
  }

  /// Lanza una URL externa utilizando [url_launcher].
  ///
  /// Abre la URL en el navegador externo del sistema para evitar problemas de compatibilidad.
  Future<void> _launchUrl(String url) async {
    final uri = Uri.parse(url);
    if (await canLaunchUrl(uri)) {
      // Usar externalApplication es preferible para abrir enlaces web.
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    }
  }

  /// {inheritdoc}
  @override
  Widget build(BuildContext context) {
    final responsive = ResponsiveHelper(context);

    return StreamBuilder<bool>(
      stream: _audioManager.playingStream,
      initialData: _audioManager.isPlaying,
      builder: (context, snapshot) {
        final isPlaying = snapshot.data ?? false;

        return Scaffold(
          appBar: AppBar(
            title: Row(
              children: [
                const Text('Nosotros'),
                // Muestra un indicador de 'LIVE' si la radio está reproduciendo.
                if (isPlaying) const LiveIndicator(),
              ],
            ),
            centerTitle: false,
          ),
          body: Stack(
            children: [
              SingleChildScrollView(
                padding: _getPadding(responsive, isPlaying),
                child: Column(
                  children: [
                    _buildLogo(responsive),
                    SizedBox(height: responsive.spacing(32)),
                    _buildTitle(responsive),
                    SizedBox(height: responsive.spacing(8)),
                    _buildSubtitle(responsive),
                    SizedBox(height: responsive.spacing(32)),
                    _buildDescriptionCard(responsive),
                    SizedBox(height: responsive.spacing(24)),
                    _buildInfoCard(responsive, 'Versión', _version),
                    SizedBox(height: responsive.spacing(14)),
                    _buildInfoCard(
                      responsive,
                      'Emisora oficial de',
                      'La Iglesia Cristiana PAI',
                    ),
                    SizedBox(height: responsive.spacing(14)),
                    // Botones de navegación externos
                    _buildWebsiteButton(responsive),
                    SizedBox(height: responsive.spacing(14)),
                    _buildWebsiteButton2(responsive),
                    SizedBox(height: responsive.spacing(14)),
                    _buildWebsiteButton1(responsive),
                    if (isPlaying) SizedBox(height: responsive.spacing(20)),
                  ],
                ),
              ),
              // Muestra el MiniPlayer en la parte inferior si la radio está activa.
              if (isPlaying)
                Positioned(
                  bottom: 16,
                  left: 16,
                  right: 16,
                  child: MiniPlayer(audioManager: _audioManager),
                ),
            ],
          ),
        );
      },
    );
  }

  /// Calcula el padding responsivo para el SingleChildScrollView.
  ///
  /// Ajusta el padding inferior para dejar espacio al MiniPlayer si está activo.
  EdgeInsets _getPadding(ResponsiveHelper responsive, bool isPlaying) {
    final horizontalPadding = responsive.getValue(
      smallPhone: 20.0,
      phone: 24.0,
      largePhone: 28.0,
      tablet: 40.0,
      desktop: 60.0,
      automotive: 32.0,
    );

    final topPadding = responsive.getValue(
      smallPhone: 20.0,
      phone: 24.0,
      largePhone: 28.0,
      tablet: 32.0,
      desktop: 40.0,
      automotive: 28.0,
    );

    // Si está reproduciendo, aumenta el padding inferior para el MiniPlayer.
    final bottomPadding = isPlaying
        ? responsive.getValue(
            smallPhone: 90.0,
            phone: 100.0,
            largePhone: 110.0,
            tablet: 120.0,
            desktop: 140.0,
            automotive: 110.0,
          )
        : responsive.getValue(
            smallPhone: 20.0,
            phone: 24.0,
            largePhone: 28.0,
            tablet: 32.0,
            desktop: 40.0,
            automotive: 28.0,
          );

    return EdgeInsets.only(
      top: topPadding,
      left: horizontalPadding,
      right: horizontalPadding,
      bottom: bottomPadding,
    );
  }

  /// Construye el logo de la aplicación con efectos de brillo.
  Widget _buildLogo(ResponsiveHelper responsive) {
    final logoSize = responsive.getValue(
      smallPhone: 100.0,
      phone: 120.0,
      largePhone: 130.0,
      tablet: 140.0,
      desktop: 160.0,
      automotive: 130.0,
    );

    final iconSize = logoSize * 0.5;

    return Container(
      width: logoSize,
      height: logoSize,
      decoration: const BoxDecoration(
        shape: BoxShape.circle,
        gradient: AppColors.logo,
        boxShadow: [
          BoxShadow(
            color: Color.fromARGB(76, 247, 247, 248),
            blurRadius: 10,
            spreadRadius: 3,
          ),
        ],
      ),
      child: ClipOval(
        child: Image.asset(
          'assets/images/ambiente_logo.png',
          width: iconSize,
          height: iconSize,
          fit: BoxFit.cover,
          // Muestra un ícono de radio en caso de que la imagen asset falle.
          errorBuilder: (context, error, stackTrace) {
            return Icon(
              Icons.radio,
              size: iconSize,
              color: AppColors.textPrimary,
            );
          },
        ),
      ),
    );
  }

  /// Construye el título principal de la emisora.
  Widget _buildTitle(ResponsiveHelper responsive) {
    return Text(
      'Ambiente Stereo 88.4 FM',
      style: TextStyle(
        fontSize: responsive.h1, // 22-32px
        fontWeight: FontWeight.bold,
        color: AppColors.textPrimary,
      ),
      textAlign: TextAlign.center,
    );
  }

  /// Construye el subtítulo/slogan de la emisora.
  Widget _buildSubtitle(ResponsiveHelper responsive) {
    return Text(
      'La radio que si quieres',
      style: TextStyle(
        fontSize: responsive.h3, // 16-20px
        color: AppColors.textMuted,
      ),
      textAlign: TextAlign.center,
    );
  }

  /// Construye la tarjeta principal que contiene la descripción obtenida por web scraping.
  Widget _buildDescriptionCard(ResponsiveHelper responsive) {
    final padding = responsive.getValue(
      smallPhone: 16.0,
      phone: 18.0,
      largePhone: 19.0,
      tablet: 20.0,
      desktop: 24.0,
      automotive: 19.0,
    );

    final borderRadius = responsive.getValue(
      smallPhone: 10.0,
      phone: 12.0,
      largePhone: 14.0,
      tablet: 16.0,
      desktop: 18.0,
      automotive: 14.0,
    );

    return Container(
      padding: EdgeInsets.all(padding),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(borderRadius),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 10,
            spreadRadius: 1,
          ),
        ],
      ),
      // Muestra un indicador de carga o el contenido procesado.
      child: _isLoadingContent
          ? const Center(child: CircularProgressIndicator())
          : Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: _aboutContent,
            ),
    );
  }

  /// Construye una tarjeta informativa genérica con un título y valor.
  Widget _buildInfoCard(
    ResponsiveHelper responsive,
    String title,
    String value,
  ) {
    final titleFontSize = responsive.caption; // 12-16px
    final valueFontSize = responsive.bodyText; // 14-18px

    final horizontalPadding = responsive.getValue(
      smallPhone: 18.0,
      phone: 20.0,
      largePhone: 22.0,
      tablet: 24.0,
      desktop: 28.0,
      automotive: 22.0,
    );

    final verticalPadding = responsive.getValue(
      smallPhone: 14.0,
      phone: 16.0,
      largePhone: 18.0,
      tablet: 20.0,
      desktop: 24.0,
      automotive: 18.0,
    );

    final borderRadius = responsive.getValue(
      smallPhone: 6.0,
      phone: 8.0,
      largePhone: 10.0,
      tablet: 12.0,
      desktop: 14.0,
      automotive: 10.0,
    );

    final spacing = responsive.getValue(
      smallPhone: 4.0,
      phone: 4.0,
      largePhone: 5.0,
      tablet: 6.0,
      desktop: 7.0,
      automotive: 5.0,
    );

    return Container(
      width: double.infinity,
      padding: EdgeInsets.symmetric(
        horizontal: horizontalPadding,
        vertical: verticalPadding,
      ),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(borderRadius),
        border: Border.all(
          color: const Color(0xFF374151).withValues(alpha: 0.5),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.03),
            blurRadius: 8,
            spreadRadius: 1,
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: TextStyle(
              fontSize: titleFontSize,
              color: AppColors.textMuted,
            ),
          ),
          SizedBox(height: spacing),
          Text(
            value,
            style: TextStyle(
              fontSize: valueFontSize,
              fontWeight: FontWeight.w600,
              color: AppColors.textPrimary,
            ),
          ),
        ],
      ),
    );
  }

  /// Construye el botón para el sitio web de Ambiente Stereo.
  Widget _buildWebsiteButton(ResponsiveHelper responsive) {
    return _buildButton(
      responsive,
      'Web Ambiente Stereo',
      Icons.web,
      () => _launchUrl('https://ambientestereo.fm'),
    );
  }

  /// Construye el botón para el sitio web de la Iglesia Cristiana PAI.
  Widget _buildWebsiteButton2(ResponsiveHelper responsive) {
    return _buildButton(
      responsive,
      'Web Iglesia Cristiana PAI',
      Icons.web,
      () => _launchUrl('https://iglesiacristianapai.org/'),
    );
  }

  /// Construye el botón para enviar un correo de soporte.
  Widget _buildWebsiteButton1(ResponsiveHelper responsive) {
    /// Helper para codificar parámetros de URL.
    String? encodeQueryParameters(Map<String, String> params) {
      return params.entries
          .map(
            (e) =>
                '${Uri.encodeComponent(e.key)}=${Uri.encodeComponent(e.value)}',
          )
          .join('&');
    }

    final Uri emailUri = Uri(
      scheme: 'mailto',
      path: 'tecnologia@iglesiacristianapai.org',
      query: encodeQueryParameters(<String, String>{
        'subject': 'Consulta desde la app Ambiente Stereo 88.4',
        'body': 'Hola, quisiera más información sobre...',
      })!,
    );

    return _buildButton(responsive, 'Soporte app', Icons.email, () async {
      if (await canLaunchUrl(emailUri)) {
        await launchUrl(emailUri);
      }
    });
  }

  /// Construye un botón elevado con un ícono y un estilo responsivo.
  Widget _buildButton(
    ResponsiveHelper responsive,
    String label,
    IconData icon,
    VoidCallback onPressed,
  ) {
    final fontSize = responsive.buttonText; // 14-18px
    final iconSize = responsive.getValue(
      smallPhone: 18.0,
      phone: 20.0,
      largePhone: 22.0,
      tablet: 24.0,
      desktop: 26.0,
      automotive: 22.0,
    );

    final horizontalPadding = responsive.getValue(
      smallPhone: 28.0,
      phone: 32.0,
      largePhone: 36.0,
      tablet: 40.0,
      desktop: 48.0,
      automotive: 36.0,
    );

    final verticalPadding = responsive.getValue(
      smallPhone: 10.0,
      phone: 12.0,
      largePhone: 14.0,
      tablet: 16.0,
      desktop: 18.0,
      automotive: 14.0,
    );

    final borderRadius = responsive.getValue(
      smallPhone: 6.0,
      phone: 8.0,
      largePhone: 10.0,
      tablet: 12.0,
      desktop: 14.0,
      automotive: 10.0,
    );

    return ElevatedButton.icon(
      onPressed: onPressed,
      icon: Icon(icon, size: iconSize),
      label: Text(label, style: TextStyle(fontSize: fontSize)),
      style: ElevatedButton.styleFrom(
        backgroundColor: AppColors.primary,
        foregroundColor: AppColors.textPrimary,
        padding: EdgeInsets.symmetric(
          horizontal: horizontalPadding,
          vertical: verticalPadding,
        ),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(borderRadius),
        ),
        elevation: 4,
        shadowColor: AppColors.primary.withValues(alpha: 0.3),
      ),
    );
  }
}
