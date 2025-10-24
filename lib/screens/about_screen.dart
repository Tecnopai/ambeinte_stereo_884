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

/// Pantalla "Acerca de" que muestra información sobre la aplicación y la emisora
/// Incluye logo, descripción, versión, enlaces web y soporte
class AboutScreen extends StatefulWidget {
  const AboutScreen({super.key});

  @override
  State<AboutScreen> createState() => _AboutScreenState();
}

class _AboutScreenState extends State<AboutScreen> {
  String _version = 'Cargando...';
  late final AudioPlayerManager _audioManager;
  List<Widget> _aboutContent = [];
  bool _isLoadingContent = true;
  final analytics = FirebaseAnalytics.instance;

  @override
  void initState() {
    super.initState();
    // ananlitica
    analytics.logScreenView(screenName: 'about', screenClass: 'AboutScreen');
    // obtener singleton
    _audioManager = AudioPlayerManager();
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

          // Verificar que el widget sigue montado antes de usar context
          if (!mounted) return;

          final responsive = ResponsiveHelper(context);

          // Tamaños de fuente accesibles
          final headerSize = responsive.h3; // 14-20px
          final bodySize = responsive.bodyText; // 14-18px

          for (var element in children) {
            final tagName = element.localName;
            final text = element.text.trim();

            if (text.isEmpty) continue;

            final isHeader =
                tagName == 'h2' || tagName == 'h3' || tagName == 'h4';

            if (isHeader) {
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

        if (!mounted) return; // Verificar antes de setState
        setState(() {
          _aboutContent = widgets;
          _isLoadingContent = false;
        });
      } else {
        throw Exception('Error ${response.statusCode}');
      }
    } catch (e) {
      if (!mounted) return; // Verificar antes de usar context
      final responsive = ResponsiveHelper(context);

      if (!mounted) return; // Verificar antes de setState
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
                    _buildWebsiteButton(responsive),
                    SizedBox(height: responsive.spacing(14)),
                    _buildWebsiteButton2(responsive),
                    SizedBox(height: responsive.spacing(14)),
                    _buildWebsiteButton1(responsive),
                    if (isPlaying) SizedBox(height: responsive.spacing(20)),
                  ],
                ),
              ),
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
      child: _isLoadingContent
          ? const Center(child: CircularProgressIndicator())
          : Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: _aboutContent,
            ),
    );
  }

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

  Widget _buildWebsiteButton(ResponsiveHelper responsive) {
    return _buildButton(
      responsive,
      'Web Ambiente Stereo',
      Icons.web,
      () => _launchUrl('https://ambientestereo.fm'),
    );
  }

  Widget _buildWebsiteButton2(ResponsiveHelper responsive) {
    return _buildButton(
      responsive,
      'Web Iglesia Cristiana PAI',
      Icons.web,
      () => _launchUrl('https://iglesiacristianapai.org/'),
    );
  }

  Widget _buildWebsiteButton1(ResponsiveHelper responsive) {
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

  Future<void> _launchUrl(String url) async {
    final uri = Uri.parse(url);
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    }
  }
}
