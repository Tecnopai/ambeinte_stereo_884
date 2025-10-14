import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import '../models/article.dart';
import '../core/theme/app_colors.dart';

class ArticleDetailScreen extends StatelessWidget {
  final Article article;

  const ArticleDetailScreen({super.key, required this.article});

  @override
  Widget build(BuildContext context) {
    final screenSize = MediaQuery.of(context).size;
    final isTablet = screenSize.shortestSide >= 600;
    final textScale = MediaQuery.of(context).textScaler.scale(1.0);

    final padding = isTablet ? 22.0 : 14.0;
    final titleFontSize = (isTablet ? 18.0 : 14.0) * textScale;
    final dateFontSize = (isTablet ? 10.0 : 8.0) * textScale;
    final contentFontSize = (isTablet ? 10.0 : 8.0) * textScale;
    final buttonFontSize = (isTablet ? 14.0 : 12.0) * textScale;
    final iconSize = (isTablet ? 18.0 : 16.0) * textScale;
    final buttonIconSize = (isTablet ? 22.0 : 20.0) * textScale;
    final borderRadius = isTablet ? 16.0 : 12.0;
    final buttonPadding = isTablet ? 14.0 : 10.0;
    final imageHeight = isTablet ? 280.0 : 220.0;

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
            // ✨ IMAGEN DESTACADA DEL ARTÍCULO
            if (article.imageUrl != null)
              ClipRRect(
                borderRadius: BorderRadius.circular(borderRadius),
                child: Image.network(
                  article.imageUrl!,
                  height: imageHeight,
                  width: double.infinity,
                  fit: BoxFit.cover,
                  loadingBuilder: (context, child, loadingProgress) {
                    if (loadingProgress == null) return child;
                    return Container(
                      height: imageHeight,
                      color: AppColors.primary.withValues(alpha: 0.1),
                      child: Center(
                        child: CircularProgressIndicator(
                          color: AppColors.primary,
                          strokeWidth: 3,
                        ),
                      ),
                    );
                  },
                  errorBuilder: (context, error, stackTrace) {
                    return Container(
                      height: imageHeight,
                      decoration: BoxDecoration(
                        color: AppColors.primary.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(borderRadius),
                      ),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            Icons.broken_image_outlined,
                            size: isTablet ? 64 : 50,
                            color: AppColors.textSecondary.withValues(
                              alpha: 0.5,
                            ),
                          ),
                          SizedBox(height: 12),
                          Text(
                            'Imagen no disponible',
                            style: TextStyle(
                              fontSize: (isTablet ? 14.0 : 12.0) * textScale,
                              color: AppColors.textSecondary,
                            ),
                          ),
                        ],
                      ),
                    );
                  },
                ),
              ),

            SizedBox(
              height: article.imageUrl != null ? (isTablet ? 24 : 20) : 0,
            ),

            // Título del artículo
            SelectableText(
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
                border: Border.all(
                  color: AppColors.primary.withValues(alpha: 0.3),
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
                  shadowColor: AppColors.primary.withValues(alpha: 0.3),
                ),
              ),
            ),

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
