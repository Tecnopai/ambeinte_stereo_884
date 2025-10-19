import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:share_plus/share_plus.dart';
import '../models/article.dart';
import '../core/theme/app_colors.dart';
import '../utils/responsive_helper.dart';

/// Pantalla mejorada de detalle de artículo
/// Completamente responsive para todos los dispositivos incluyendo automotive
class ArticleDetailScreen extends StatelessWidget {
  final Article article;

  const ArticleDetailScreen({super.key, required this.article});

  @override
  Widget build(BuildContext context) {
    final responsive = ResponsiveHelper(context);

    // Layout especial para automotive
    if (responsive.isAutomotive) {
      return _buildAutomotiveLayout(context, responsive);
    }

    // Layout estándar para móvil/tablet
    return _buildStandardLayout(context, responsive);
  }

  /// Layout optimizado para radios de vehículos
  Widget _buildAutomotiveLayout(
    BuildContext context,
    ResponsiveHelper responsive,
  ) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        title: Text(
          'Artículo',
          style: TextStyle(fontSize: responsive.h2, color: Colors.white),
        ),
        iconTheme: IconThemeData(color: Colors.white, size: 32),
      ),
      body: SafeArea(
        child: Padding(
          padding: EdgeInsets.all(20),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Panel izquierdo - Imagen (si existe)
              if (article.imageUrl != null)
                Expanded(
                  flex: 2,
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(12),
                    child: Image.network(
                      article.imageUrl!,
                      fit: BoxFit.cover,
                      height: double.infinity,
                      errorBuilder: (context, error, stackTrace) {
                        return Container(
                          decoration: BoxDecoration(
                            color: Colors.grey[900],
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Icon(
                            Icons.broken_image,
                            size: 80,
                            color: Colors.grey[700],
                          ),
                        );
                      },
                    ),
                  ),
                ),

              if (article.imageUrl != null) SizedBox(width: 24),

              // Panel derecho - Contenido
              Expanded(
                flex: 3,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Título
                    Expanded(
                      child: SingleChildScrollView(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              article.title,
                              style: TextStyle(
                                fontSize: responsive.h2,
                                fontWeight: FontWeight.bold,
                                color: Colors.white,
                                height: 1.3,
                              ),
                            ),
                            SizedBox(height: 16),

                            // Fecha
                            Row(
                              children: [
                                Icon(
                                  Icons.access_time,
                                  size: 20,
                                  color: Colors.grey[400],
                                ),
                                SizedBox(width: 8),
                                Text(
                                  article.formattedDate,
                                  style: TextStyle(
                                    fontSize: responsive.caption,
                                    color: Colors.grey[400],
                                  ),
                                ),
                              ],
                            ),
                            SizedBox(height: 20),

                            // Contenido resumido
                            Text(
                              article.content,
                              style: TextStyle(
                                fontSize: responsive.bodyText,
                                color: Colors.grey[300],
                                height: 1.6,
                              ),
                              maxLines: 8,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ],
                        ),
                      ),
                    ),

                    SizedBox(height: 20),

                    // Botón grande para ver completo
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton.icon(
                        onPressed: () => _launchUrl(article.link),
                        icon: Icon(Icons.open_in_browser, size: 28),
                        label: Text(
                          'VER COMPLETO',
                          style: TextStyle(
                            fontSize: responsive.buttonText,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.green,
                          foregroundColor: Colors.white,
                          minimumSize: Size(double.infinity, 70),
                          padding: EdgeInsets.symmetric(vertical: 20),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// Layout estándar para móvil y tablet
  Widget _buildStandardLayout(
    BuildContext context,
    ResponsiveHelper responsive,
  ) {
    final padding = responsive.getValue(
      smallPhone: 16.0,
      phone: 20.0,
      largePhone: 22.0,
      tablet: 28.0,
      desktop: 32.0,
    );

    final borderRadius = responsive.getValue(
      phone: 12.0,
      largePhone: 14.0,
      tablet: 16.0,
      desktop: 20.0,
    );

    final imageHeight = responsive.getValue(
      smallPhone: 200.0,
      phone: 220.0,
      largePhone: 240.0,
      tablet: 300.0,
      desktop: 400.0,
    );

    final iconSize = responsive.getValue(
      phone: 18.0,
      largePhone: 20.0,
      tablet: 22.0,
      desktop: 24.0,
    );

    return Scaffold(
      appBar: AppBar(
        title: Text('Artículo', style: TextStyle(fontSize: responsive.h2)),
        centerTitle: true,
        actions: [
          // Botón compartir
          IconButton(
            icon: Icon(Icons.share, size: iconSize),
            tooltip: 'Compartir',
            onPressed: () => _shareArticle(context),
          ),
          // Botón copiar enlace
          IconButton(
            icon: Icon(Icons.link, size: iconSize),
            tooltip: 'Copiar enlace',
            onPressed: () => _copyLink(context),
          ),
        ],
      ),
      body: Center(
        child: ConstrainedBox(
          constraints: BoxConstraints(maxWidth: responsive.maxContentWidth),
          child: SingleChildScrollView(
            padding: EdgeInsets.all(padding),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Imagen destacada
                if (article.imageUrl != null)
                  _buildImage(context, responsive, imageHeight, borderRadius),

                if (article.imageUrl != null)
                  SizedBox(height: responsive.spacing(24)),

                // Título
                SelectableText(
                  article.title,
                  style: TextStyle(
                    fontSize: responsive.h1,
                    fontWeight: FontWeight.bold,
                    color: AppColors.textPrimary,
                    height: 1.3,
                  ),
                ),

                SizedBox(height: responsive.spacing(20)),

                // Fecha y hora
                _buildDateRow(responsive, iconSize),

                SizedBox(height: responsive.spacing(32)),

                // Contenido
                _buildContentCard(responsive, borderRadius),

                SizedBox(height: responsive.spacing(32)),

                // Botones de acción
                if (responsive.isDesktop || responsive.isLargeTablet)
                  _buildButtonsRow(responsive, borderRadius)
                else
                  _buildButtonsColumn(responsive, borderRadius),

                SizedBox(height: responsive.spacing(24)),
              ],
            ),
          ),
        ),
      ),
    );
  }

  /// Construye la imagen del artículo con estados de carga y error
  Widget _buildImage(
    BuildContext context,
    ResponsiveHelper responsive,
    double height,
    double borderRadius,
  ) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(borderRadius),
      child: Image.network(
        article.imageUrl!,
        height: height,
        width: double.infinity,
        fit: BoxFit.cover,
        loadingBuilder: (context, child, loadingProgress) {
          if (loadingProgress == null) return child;
          return Container(
            height: height,
            decoration: BoxDecoration(
              color: AppColors.primary.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(borderRadius),
            ),
            child: Center(
              child: CircularProgressIndicator(
                color: AppColors.primary,
                strokeWidth: 3,
                value: loadingProgress.expectedTotalBytes != null
                    ? loadingProgress.cumulativeBytesLoaded /
                          loadingProgress.expectedTotalBytes!
                    : null,
              ),
            ),
          );
        },
        errorBuilder: (context, error, stackTrace) {
          return Container(
            height: height,
            decoration: BoxDecoration(
              color: AppColors.primary.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(borderRadius),
            ),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  Icons.broken_image_outlined,
                  size: responsive.getValue(
                    phone: 50.0,
                    tablet: 64.0,
                    desktop: 80.0,
                  ),
                  color: AppColors.textSecondary.withValues(alpha: 0.5),
                ),
                SizedBox(height: 12),
                Text(
                  'Imagen no disponible',
                  style: TextStyle(
                    fontSize: responsive.caption,
                    color: AppColors.textSecondary,
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  /// Fila con fecha y hora
  Widget _buildDateRow(ResponsiveHelper responsive, double iconSize) {
    return Row(
      children: [
        Icon(Icons.access_time, size: iconSize, color: AppColors.textSecondary),
        SizedBox(width: 8),
        Flexible(
          child: Text(
            article.formattedDate,
            style: TextStyle(
              fontSize: responsive.caption,
              color: AppColors.textSecondary,
            ),
          ),
        ),
      ],
    );
  }

  /// Tarjeta con el contenido del artículo
  Widget _buildContentCard(ResponsiveHelper responsive, double borderRadius) {
    final cardPadding = responsive.getValue(
      phone: 18.0,
      largePhone: 20.0,
      tablet: 24.0,
      desktop: 28.0,
    );

    return Container(
      width: double.infinity,
      padding: EdgeInsets.all(cardPadding),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(borderRadius),
        border: Border.all(
          color: AppColors.primary.withValues(alpha: 0.3),
          width: 1.5,
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
          fontSize: responsive.bodyText,
          color: AppColors.textMuted,
          height: 1.6,
          letterSpacing: 0.2,
        ),
      ),
    );
  }

  /// Botones en columna (móvil)
  Widget _buildButtonsColumn(ResponsiveHelper responsive, double borderRadius) {
    return Column(
      children: [
        _buildActionButton(
          responsive,
          borderRadius,
          'Ver artículo completo',
          Icons.open_in_browser,
          AppColors.primary,
          () => _launchUrl(article.link),
        ),
        SizedBox(height: responsive.spacing(12)),
        _buildActionButton(
          responsive,
          borderRadius,
          'Compartir',
          Icons.share,
          Colors.blue,
          () => _shareArticle(null),
        ),
      ],
    );
  }

  /// Botones en fila (tablet/desktop)
  Widget _buildButtonsRow(ResponsiveHelper responsive, double borderRadius) {
    return Row(
      children: [
        Expanded(
          flex: 2,
          child: _buildActionButton(
            responsive,
            borderRadius,
            'Ver completo',
            Icons.open_in_browser,
            AppColors.primary,
            () => _launchUrl(article.link),
          ),
        ),
        SizedBox(width: 16),
        Expanded(
          child: _buildActionButton(
            responsive,
            borderRadius,
            'Compartir',
            Icons.share,
            Colors.blue,
            () => _shareArticle(null),
          ),
        ),
      ],
    );
  }

  /// Botón de acción reutilizable
  Widget _buildActionButton(
    ResponsiveHelper responsive,
    double borderRadius,
    String label,
    IconData icon,
    Color color,
    VoidCallback onPressed,
  ) {
    final iconSize = responsive.getValue(
      phone: 20.0,
      largePhone: 22.0,
      tablet: 24.0,
      desktop: 26.0,
    );

    final padding = responsive.getValue(
      phone: 14.0,
      largePhone: 16.0,
      tablet: 18.0,
      desktop: 20.0,
    );

    return SizedBox(
      width: double.infinity,
      child: ElevatedButton.icon(
        onPressed: onPressed,
        icon: Icon(icon, size: iconSize),
        label: Text(
          label,
          style: TextStyle(
            fontSize: responsive.buttonText,
            fontWeight: FontWeight.w600,
          ),
        ),
        style: ElevatedButton.styleFrom(
          backgroundColor: color,
          foregroundColor: Colors.white,
          padding: EdgeInsets.symmetric(vertical: padding),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(borderRadius),
          ),
          elevation: 4,
          shadowColor: color.withValues(alpha: 0.3),
        ),
      ),
    );
  }

  /// Abre URL en navegador externo
  Future<void> _launchUrl(String url) async {
    final uri = Uri.parse(url);
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    }
  }

  /// Comparte el artículo
  void _shareArticle(BuildContext? context) {
    final shareText = '${article.title}\n\n${article.link}';
    Share.share(shareText, subject: article.title);
  }

  /// Copia el enlace al portapapeles
  void _copyLink(BuildContext context) {
    Clipboard.setData(ClipboardData(text: article.link));
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            Icon(Icons.check_circle, color: Colors.white),
            SizedBox(width: 12),
            Expanded(
              child: Text(
                'Enlace copiado al portapapeles',
                style: TextStyle(fontSize: 14),
              ),
            ),
          ],
        ),
        backgroundColor: Colors.green,
        behavior: SnackBarBehavior.floating,
        duration: Duration(seconds: 2),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      ),
    );
  }
}
