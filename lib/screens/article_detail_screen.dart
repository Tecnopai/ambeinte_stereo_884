import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import '../models/article.dart';
import '../core/theme/app_colors.dart';

class ArticleDetailScreen extends StatelessWidget {
  final Article article;

  const ArticleDetailScreen({super.key, required this.article});

  @override
  Widget build(BuildContext context) {
    // Obtener información del dispositivo
    final screenSize = MediaQuery.of(context).size;
    final isTablet = screenSize.shortestSide >= 600;
    final textScale = MediaQuery.of(context).textScaler.scale(1.0);

    // Calcular tamaños dinámicos
    final padding = isTablet ? 22.0 : 14.0;
    final titleFontSize =
        (isTablet ? 20.0 : 16.0) * textScale; // Titulo del articulo
    final dateFontSize =
        (isTablet ? 10.0 : 8.0) * textScale; // Date fecha del articulo
    final contentFontSize = (isTablet ? 10.0 : 8.0) * textScale; // contenido
    final buttonFontSize = (isTablet ? 14.0 : 12.0) * textScale; // fuente icono
    final iconSize = (isTablet ? 18.0 : 16.0) * textScale; // Aumentado de 14
    final buttonIconSize = (isTablet ? 22.0 : 20.0) * textScale;
    final borderRadius = isTablet ? 16.0 : 12.0;
    final buttonPadding = isTablet ? 14.0 : 10.0;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Artículo'),
        centerTitle: true,
        actions: [
          IconButton(
            icon: Icon(Icons.share, size: isTablet ? 26 : 24),
            onPressed: () {
              // Implementar compartir si es necesario
            },
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: EdgeInsets.all(padding),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Título del artículo
            SelectableText(
              // Permite selección de texto
              article.title,
              style: TextStyle(
                fontSize: titleFontSize,
                fontWeight: FontWeight.bold,
                color: AppColors.textPrimary,
                height: 1.3,
              ),
            ),

            SizedBox(height: isTablet ? 20 : 16),

            // Fecha y hora
            Row(
              children: [
                Icon(
                  Icons.access_time,
                  size: iconSize,
                  color: AppColors.textSecondary,
                ),
                SizedBox(width: isTablet ? 6 : 4),
                Flexible(
                  // Evita overflow en textos largos
                  child: Text(
                    article.formattedDate,
                    style: TextStyle(
                      fontSize: dateFontSize,
                      color: AppColors.textSecondary,
                    ),
                  ),
                ),
              ],
            ),

            SizedBox(height: isTablet ? 32 : 24),

            // Contenido del artículo
            Container(
              width: double.infinity,
              padding: EdgeInsets.all(isTablet ? 18 : 14),
              decoration: BoxDecoration(
                color: AppColors.surface,
                borderRadius: BorderRadius.circular(borderRadius),
                border: Border.all(color: AppColors.primary.withOpacity(0.3)),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.05),
                    blurRadius: 10,
                    spreadRadius: 1,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: SelectableText(
                // Permite selección de texto
                article.content,
                style: TextStyle(
                  fontSize: contentFontSize,
                  color: AppColors.textMuted,
                  height: 1.6,
                ),
              ),
            ),

            SizedBox(height: isTablet ? 32 : 24),

            // Botón para ver artículo completo
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: () => _launchUrl(article.link),
                icon: Icon(Icons.open_in_browser, size: buttonIconSize),
                label: Text(
                  'Ver artículo completo',
                  style: TextStyle(fontSize: buttonFontSize),
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  foregroundColor: AppColors.textPrimary,
                  padding: EdgeInsets.symmetric(vertical: buttonPadding),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(borderRadius),
                  ),
                  elevation: 4,
                  shadowColor: AppColors.primary.withOpacity(0.3),
                ),
              ),
            ),

            // Padding extra para evitar que se corte en la parte inferior
            SizedBox(height: isTablet ? 32 : 24),
          ],
        ),
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
