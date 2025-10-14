import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:http/http.dart' as http;
import 'package:html/parser.dart' as html_parser;
import 'package:html/dom.dart' as dom;
import 'package:flutter/gestures.dart';
import '../services/audio_player_manager.dart';
import '../widgets/mini_player.dart';
import '../widgets/live_indicator.dart';
import '../core/theme/app_colors.dart';

class AboutScreen extends StatefulWidget {
  final AudioPlayerManager audioManager;

  const AboutScreen({super.key, required this.audioManager});

  @override
  State<AboutScreen> createState() => _AboutScreenState();
}

class _AboutScreenState extends State<AboutScreen> {
  String _version = 'Cargando...';
  List<Widget> _aboutContent = [];
  bool _isLoadingContent = true;

  @override
  void initState() {
    super.initState();
    _loadVersion();
    _loadAboutContent();
  }

  Future<void> _loadVersion() async {
    try {
      final packageInfo = await PackageInfo.fromPlatform();
      setState(() {
        _version = packageInfo.version;
      });
    } catch (e) {
      setState(() {
        _version = '2.0.0';
      });
    }
  }

  Future<void> _loadAboutContent() async {
    try {
      final response = await http
          .get(Uri.parse('https://ambientestereo.fm/sitio/sobre-nosotros/'))
          .timeout(const Duration(seconds: 10));

      if (response.statusCode == 200) {
        final document = html_parser.parse(response.body);

        var contentElement =
            document.querySelector('.entry-content') ??
            document.querySelector('article') ??
            document.querySelector('.post-content');

        List<Widget> widgets = [];

        if (contentElement != null) {
          contentElement.querySelector('h1.entry-title')?.remove();
          final children = contentElement.children;

          for (var element in children) {
            final tagName = element.localName;
            final text = element.text.trim();

            if (text.isEmpty) continue;

            // Detectar títulos (h2, h3, h4)
            final isHeader =
                tagName == 'h2' || tagName == 'h3' || tagName == 'h4';

            if (isHeader) {
              // Es un título de encabezado
              if (widgets.isNotEmpty) {
                widgets.add(const SizedBox(height: 20));
              }

              widgets.add(
                Text(
                  text,
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 11,
                    color: AppColors.textPrimary,
                    height: 1.4,
                  ),
                ),
              );

              widgets.add(const SizedBox(height: 8));
            } else if (tagName == 'p') {
              // Verificar si el párrafo comienza con un <strong> que es título
              final strong = element.querySelector('strong');

              if (strong != null) {
                final strongText = strong.text.trim();
                final isAllCaps =
                    strongText == strongText.toUpperCase() &&
                    strongText.length > 3 &&
                    strongText.length < 50;

                if (isAllCaps) {
                  // El <strong> es un título, separarlo del resto
                  if (widgets.isNotEmpty) {
                    widgets.add(const SizedBox(height: 20));
                  }

                  // Agregar el título
                  widgets.add(
                    Text(
                      strongText,
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 11,
                        color: AppColors.textPrimary,
                        height: 1.4,
                      ),
                    ),
                  );

                  widgets.add(const SizedBox(height: 8));

                  // Procesar el resto del contenido del párrafo (sin el strong)
                  strong.remove(); // Remover el strong del elemento
                  final remainingText = element.text.trim();

                  if (remainingText.isNotEmpty) {
                    List<InlineSpan> spans = [];
                    _processParagraph(element, spans);

                    if (spans.isNotEmpty) {
                      widgets.add(
                        RichText(
                          text: TextSpan(
                            style: const TextStyle(
                              fontSize: 8.5,
                              color: AppColors.textMuted,
                              height: 1.6,
                              letterSpacing: 0.2,
                            ),
                            children: spans,
                          ),
                          textAlign: TextAlign.left,
                        ),
                      );

                      widgets.add(const SizedBox(height: 10));
                    }
                  }

                  continue; // Ya procesamos este elemento
                }
              }

              // Es un párrafo normal (sin título strong)
              List<InlineSpan> spans = [];
              _processParagraph(element, spans);

              if (spans.isNotEmpty) {
                widgets.add(
                  RichText(
                    text: TextSpan(
                      style: const TextStyle(
                        fontSize: 8.5,
                        color: AppColors.textMuted,
                        height: 1.6,
                        letterSpacing: 0.2,
                      ),
                      children: spans,
                    ),
                    textAlign: TextAlign.left,
                  ),
                );

                widgets.add(const SizedBox(height: 10));
              }
            }
          }
        }

        if (widgets.isEmpty) {
          widgets = [const Text('No se pudo cargar el contenido.')];
        }

        setState(() {
          _aboutContent = widgets;
          _isLoadingContent = false;
        });
      } else {
        throw Exception('Error ${response.statusCode}');
      }
    } catch (e) {
      setState(() {
        _aboutContent = [
          const Text(
            'Nuestro propósito es promover la protección y conservación del medio ambiente, la participación ciudadana y los valores familiares y sociales a través de una programación variada, educativa y cristocéntrica.',
            style: TextStyle(
              fontSize: 8.5,
              color: AppColors.textMuted,
              height: 1.6,
            ),
          ),
        ];
        _isLoadingContent = false;
      });
    }
  }

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
          if (element.nodes.isNotEmpty) {
            _processParagraph(element, spans);
          } else {
            spans.add(TextSpan(text: text));
          }
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<bool>(
      stream: widget.audioManager.playingStream,
      initialData: widget.audioManager.isPlaying,
      builder: (context, snapshot) {
        final isPlaying = snapshot.data ?? false;

        return Scaffold(
          appBar: AppBar(
            title: Row(
              children: [
                const Text('Nosotros'),
                if (isPlaying) const LiveIndicator(),
              ],
            ),
            centerTitle: false,
          ),
          body: Stack(
            children: [
              SingleChildScrollView(
                padding: _getPadding(context, isPlaying),
                child: Column(
                  children: [
                    _buildLogo(context),
                    _getSpacing(context, 32),
                    _buildTitle(context),
                    _getSpacing(context, 8),
                    _buildSubtitle(context),
                    _getSpacing(context, 32),
                    _buildDescriptionCard(context),
                    _getSpacing(context, 24),
                    _buildInfoCard(context, 'Versión', _version),
                    _getSpacing(context, 14),
                    _buildInfoCard(
                      context,
                      'Emisora oficial de',
                      'La Iglesia Cristiana PAI',
                    ),
                    _getSpacing(context, 14),
                    _buildWebsiteButton(context),
                    _getSpacing(context, 14),
                    _buildWebsiteButton2(context),
                    _getSpacing(context, 14),
                    _buildWebsiteButton1(context),
                    if (isPlaying) _getSpacing(context, 20),
                  ],
                ),
              ),
              if (isPlaying)
                Positioned(
                  bottom: 16,
                  left: 16,
                  right: 16,
                  child: MiniPlayer(audioManager: widget.audioManager),
                ),
            ],
          ),
        );
      },
    );
  }

  EdgeInsets _getPadding(BuildContext context, bool isPlaying) {
    final screenSize = MediaQuery.of(context).size;
    final isTablet = screenSize.shortestSide >= 600;
    final horizontalPadding = isTablet ? 40.0 : 24.0;
    final topPadding = isTablet ? 32.0 : 24.0;
    final bottomPadding = isPlaying
        ? (isTablet ? 120.0 : 100.0)
        : (isTablet ? 32.0 : 24.0);

    return EdgeInsets.only(
      top: topPadding,
      left: horizontalPadding,
      right: horizontalPadding,
      bottom: bottomPadding,
    );
  }

  SizedBox _getSpacing(BuildContext context, double baseSize) {
    final screenSize = MediaQuery.of(context).size;
    final isTablet = screenSize.shortestSide >= 600;
    final spacing = isTablet ? baseSize * 1.2 : baseSize;
    return SizedBox(height: spacing);
  }

  Widget _buildLogo(BuildContext context) {
    final screenSize = MediaQuery.of(context).size;
    final isTablet = screenSize.shortestSide >= 600;
    final logoSize = isTablet ? 140.0 : 120.0;
    final iconSize = isTablet ? 70.0 : 60.0;

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

  Widget _buildTitle(BuildContext context) {
    final screenSize = MediaQuery.of(context).size;
    final isTablet = screenSize.shortestSide >= 600;
    final textScale = MediaQuery.of(context).textScaler.scale(1.0);
    final fontSize = (isTablet ? 28.0 : 14.0) * textScale;

    return Text(
      'Ambiente Stereo 88.4 FM',
      style: TextStyle(
        fontSize: fontSize,
        fontWeight: FontWeight.bold,
        color: AppColors.textPrimary,
      ),
      textAlign: TextAlign.center,
    );
  }

  Widget _buildSubtitle(BuildContext context) {
    final screenSize = MediaQuery.of(context).size;
    final isTablet = screenSize.shortestSide >= 600;
    final textScale = MediaQuery.of(context).textScaler.scale(1.0);
    final fontSize = (isTablet ? 14.0 : 12.0) * textScale;

    return Text(
      'La radio que si quieres',
      style: TextStyle(fontSize: fontSize, color: AppColors.textMuted),
      textAlign: TextAlign.center,
    );
  }

  Widget _buildDescriptionCard(BuildContext context) {
    final screenSize = MediaQuery.of(context).size;
    final isTablet = screenSize.shortestSide >= 600;
    final padding = isTablet ? 20.0 : 18.0;
    final borderRadius = isTablet ? 16.0 : 12.0;

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
      child: _isLoadingContent
          ? const Center(child: CircularProgressIndicator())
          : Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: _aboutContent,
            ),
    );
  }

  Widget _buildInfoCard(BuildContext context, String title, String value) {
    final screenSize = MediaQuery.of(context).size;
    final isTablet = screenSize.shortestSide >= 600;
    final textScale = MediaQuery.of(context).textScaler.scale(1.0);
    final titleFontSize = (isTablet ? 12.0 : 10.0) * textScale;
    final valueFontSize = (isTablet ? 10.0 : 8.0) * textScale;
    final horizontalPadding = isTablet ? 24.0 : 20.0;
    final verticalPadding = isTablet ? 20.0 : 16.0;
    final borderRadius = isTablet ? 12.0 : 8.0;

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
          SizedBox(height: isTablet ? 6 : 4),
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

  Widget _buildWebsiteButton2(BuildContext context) {
    final screenSize = MediaQuery.of(context).size;
    final isTablet = screenSize.shortestSide >= 600;
    final textScale = MediaQuery.of(context).textScaler.scale(1.0);
    final fontSize = (isTablet ? 10.0 : 8.0) * textScale;
    final iconSize = (isTablet ? 20.0 : 16.0) * textScale;
    final horizontalPadding = isTablet ? 40.0 : 32.0;
    final verticalPadding = isTablet ? 16.0 : 12.0;
    final borderRadius = isTablet ? 12.0 : 8.0;

    return ElevatedButton.icon(
      onPressed: () => _launchUrl('https://iglesiacristianapai.org/'),
      icon: Icon(Icons.web, size: iconSize),
      label: Text(
        'Web Iglesia Cristiana PAI',
        style: TextStyle(fontSize: fontSize),
      ),
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

  Widget _buildWebsiteButton(BuildContext context) {
    final screenSize = MediaQuery.of(context).size;
    final isTablet = screenSize.shortestSide >= 600;
    final textScale = MediaQuery.of(context).textScaler.scale(1.0);
    final fontSize = (isTablet ? 10.0 : 8.0) * textScale;
    final iconSize = (isTablet ? 20.0 : 16.0) * textScale;
    final horizontalPadding = isTablet ? 40.0 : 32.0;
    final verticalPadding = isTablet ? 16.0 : 12.0;
    final borderRadius = isTablet ? 12.0 : 8.0;

    return ElevatedButton.icon(
      onPressed: () => _launchUrl('https://ambientestereo.fm'),
      icon: Icon(Icons.web, size: iconSize),
      label: Text('Web Ambiente Stereo', style: TextStyle(fontSize: fontSize)),
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

  Widget _buildWebsiteButton1(BuildContext context) {
    final screenSize = MediaQuery.of(context).size;
    final isTablet = screenSize.shortestSide >= 600;
    final textScale = MediaQuery.of(context).textScaler.scale(1.0);
    final fontSize = (isTablet ? 10.0 : 8.0) * textScale;
    final iconSize = (isTablet ? 20.0 : 16.0) * textScale;
    final horizontalPadding = isTablet ? 40.0 : 32.0;
    final verticalPadding = isTablet ? 16.0 : 12.0;
    final borderRadius = isTablet ? 12.0 : 8.0;

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

    return ElevatedButton.icon(
      onPressed: () async {
        if (await canLaunchUrl(emailUri)) {
          await launchUrl(emailUri);
        }
      },
      icon: Icon(Icons.email, size: iconSize),
      label: Text('Soporte app', style: TextStyle(fontSize: fontSize)),
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

  Future<void> _launchUrl(String url) async {
    final uri = Uri.parse(url);
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    }
  }
}
