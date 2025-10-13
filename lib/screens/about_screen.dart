import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import '../services/audio_player_manager.dart';
import '../widgets/mini_player.dart';
import '../widgets/live_indicator.dart';
import '../core/theme/app_colors.dart';

class AboutScreen extends StatelessWidget {
  final AudioPlayerManager audioManager;

  const AboutScreen({super.key, required this.audioManager});

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<bool>(
      stream: audioManager.playingStream,
      initialData: audioManager.isPlaying,
      builder: (context, snapshot) {
        final isPlaying = snapshot.data ?? false;

        return Scaffold(
          appBar: AppBar(
            title: Row(
              children: [
                const Text('Acerca de'),
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
                    _getSpacing(context, 32),
                    _buildInfoCard(context, 'Versión', '2.0.0'),
                    _getSpacing(context, 14),
                    _buildInfoCard(context, 'Sitio Web', 'ambientestereo.fm'),
                    _getSpacing(context, 32),
                    _buildWebsiteButton(context),
                    _getSpacing(context, 32),
                    _buildWebsiteButton1(context),
                    // Padding extra para evitar que el MiniPlayer tape contenido
                    if (isPlaying) _getSpacing(context, 20),
                  ],
                ),
              ),
              if (isPlaying)
                Positioned(
                  bottom: 16,
                  left: 16,
                  right: 16,
                  child: MiniPlayer(audioManager: audioManager),
                ),
            ],
          ),
        );
      },
    );
  }

  // Calcula padding dinámico
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

  // Espaciado responsivo
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
    final textScale = MediaQuery.of(context).textScaler.scale(1.0);
    final fontSize =
        (isTablet ? 12.0 : 10.0) * textScale; // Aumentado significativamente
    final padding = isTablet ? 24.0 : 20.0;
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
      child: Column(
        children: [
          Text(
            'Nuestro propósito es promover la protección y conservación del medio ambiente, la participación ciudadana y los valores familiares y sociales a través de una programación variada, educativa y cristocéntrica.',
            style: TextStyle(
              fontSize: fontSize, // Mejorado de 10 a 14-16
              color: AppColors.textMuted,
              height: 1.6,
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  Widget _buildInfoCard(BuildContext context, String title, String value) {
    final screenSize = MediaQuery.of(context).size;
    final isTablet = screenSize.shortestSide >= 600;
    final textScale = MediaQuery.of(context).textScaler.scale(1.0);
    final titleFontSize = (isTablet ? 12.0 : 10.0) * textScale;
    final valueFontSize = (isTablet ? 10.0 : 8.0) * textScale; // Aumentado
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
              fontSize: valueFontSize, // Mejorado de 12 a 14-16
              fontWeight: FontWeight.w600,
              color: AppColors.textPrimary,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildWebsiteButton(BuildContext context) {
    final screenSize = MediaQuery.of(context).size;
    final isTablet = screenSize.shortestSide >= 600;
    final textScale = MediaQuery.of(context).textScaler.scale(1.0);
    final fontSize = (isTablet ? 14.0 : 12.0) * textScale;
    final iconSize = (isTablet ? 24.0 : 20.0) * textScale;
    final horizontalPadding = isTablet ? 40.0 : 32.0;
    final verticalPadding = isTablet ? 16.0 : 12.0;
    final borderRadius = isTablet ? 12.0 : 8.0;

    return ElevatedButton.icon(
      onPressed: () => _launchUrl('https://ambientestereo.fm'),
      icon: Icon(Icons.web, size: iconSize),
      label: Text('Visitar sitio web', style: TextStyle(fontSize: fontSize)),
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
    final fontSize = (isTablet ? 14.0 : 12.0) * textScale;
    final iconSize = (isTablet ? 24.0 : 20.0) * textScale;
    final horizontalPadding = isTablet ? 40.0 : 32.0;
    final verticalPadding = isTablet ? 16.0 : 12.0;
    final borderRadius = isTablet ? 12.0 : 8.0;

    // 🔹 Helper para codificar parámetros del correo
    String? encodeQueryParameters(Map<String, String> params) {
      return params.entries
          .map(
            (e) =>
                '${Uri.encodeComponent(e.key)}=${Uri.encodeComponent(e.value)}',
          )
          .join('&');
    }

    // 🔹 URI del correo electrónico
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
        } else {
          throw 'No se pudo abrir el cliente de correo.';
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
