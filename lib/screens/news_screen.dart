import 'package:flutter/material.dart';
import '../services/audio_player_manager.dart';
import '../services/news_service.dart';
import '../models/article.dart';
import '../widgets/mini_player.dart';
import '../widgets/live_indicator.dart';
import '../core/theme/app_colors.dart';
import 'article_detail_screen.dart';

class NewsScreen extends StatefulWidget {
  final AudioPlayerManager audioManager;

  const NewsScreen({super.key, required this.audioManager});

  @override
  State<NewsScreen> createState() => _NewsScreenState();
}

class _NewsScreenState extends State<NewsScreen> {
  final NewsService _newsService = NewsService();
  List<Article> _articles = [];
  bool _isLoading = true;
  bool _isPlaying = false;

  @override
  void initState() {
    super.initState();
    _loadArticles();
    _setupAudioListener();
  }

  void _setupAudioListener() {
    widget.audioManager.playingStream.listen((isPlaying) {
      if (mounted) {
        setState(() {
          _isPlaying = isPlaying;
        });
      }
    });

    _isPlaying = widget.audioManager.isPlaying;
  }

  Future<void> _loadArticles() async {
    try {
      final articles = await _newsService.getArticles();
      if (mounted) {
        setState(() {
          _articles = articles;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
        _showErrorSnackBar('Error al cargar las noticias');
      }
    }
  }

  void _showErrorSnackBar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), backgroundColor: AppColors.error),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Row(
          children: [
            const Text('Últimas Noticias'),
            if (_isPlaying) const LiveIndicator(),
          ],
        ),
        centerTitle: false,
      ),
      body: Stack(
        children: [
          _buildContent(),
          if (_isPlaying)
            Positioned(
              bottom: 16,
              left: 16,
              right: 16,
              child: MiniPlayer(audioManager: widget.audioManager),
            ),
        ],
      ),
    );
  }

  Widget _buildContent() {
    // Obtener información del dispositivo para responsividad
    final screenSize = MediaQuery.of(context).size;
    final isTablet = screenSize.shortestSide >= 600;
    final textScale = MediaQuery.of(context).textScaler.scale(1.0);

    if (_isLoading) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            CircularProgressIndicator(
              color: AppColors.primary,
              strokeWidth: isTablet ? 4 : 3,
            ),
            SizedBox(height: isTablet ? 20 : 16),
            Text(
              'Cargando noticias...',
              style: TextStyle(
                color: AppColors.textMuted,
                fontSize: (isTablet ? 16.0 : 14.0) * textScale,
              ),
            ),
          ],
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: _loadArticles,
      color: AppColors.primary,
      child: ListView.builder(
        padding: EdgeInsets.only(
          top: isTablet ? 20 : 16,
          left: isTablet ? 20 : 16,
          right: isTablet ? 20 : 16,
          bottom: _isPlaying ? (isTablet ? 120 : 100) : (isTablet ? 20 : 16),
        ),
        itemCount: _articles.length,
        itemBuilder: (context, index) => _buildArticleCard(_articles[index]),
      ),
    );
  }

  Widget _buildArticleCard(Article article) {
    // Calcular tamaños responsivos
    final screenSize = MediaQuery.of(context).size;
    final isTablet = screenSize.shortestSide >= 600;
    final textScale = MediaQuery.of(context).textScaler.scale(1.0);

    final titleFontSize = (isTablet ? 16.0 : 14.0) * textScale; // Titulo fuente
    final excerptFontSize = (isTablet ? 12.0 : 10.0) * textScale;
    final dateFontSize = (isTablet ? 10.0 : 8.0) * textScale; // fecha
    final cardPadding = isTablet ? 20.0 : 16.0;
    final borderRadius = isTablet ? 16.0 : 12.0;
    final timeIconSize = (isTablet ? 16.0 : 14.0) * textScale;
    final arrowIconSize = (isTablet ? 18.0 : 16.0) * textScale;
    final cardMargin = isTablet ? 20.0 : 16.0;

    return Card(
      color: AppColors.cardBackground,
      margin: EdgeInsets.only(bottom: cardMargin),
      elevation: isTablet ? 6 : 4,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(borderRadius),
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(borderRadius),
        onTap: () {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => ArticleDetailScreen(article: article),
            ),
          );
        },
        child: Padding(
          padding: EdgeInsets.all(cardPadding),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                article.title,
                style: TextStyle(
                  fontSize: titleFontSize,
                  fontWeight: FontWeight.bold,
                  color: AppColors.textPrimary,
                ),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
              SizedBox(height: isTablet ? 12 : 8),
              Text(
                article.excerpt,
                style: TextStyle(
                  fontSize: excerptFontSize,
                  color: AppColors.textMuted,
                ),
                maxLines: 3,
                overflow: TextOverflow.ellipsis,
              ),
              SizedBox(height: isTablet ? 16 : 12),
              Row(
                children: [
                  Icon(
                    Icons.access_time,
                    size: timeIconSize,
                    color: AppColors.textSecondary,
                  ),
                  SizedBox(width: isTablet ? 6 : 4),
                  Expanded(
                    child: Text(
                      article.formattedDate,
                      style: TextStyle(
                        fontSize: dateFontSize,
                        color: AppColors.textSecondary,
                      ),
                    ),
                  ),
                  Icon(
                    Icons.arrow_forward_ios,
                    size: arrowIconSize,
                    color: AppColors.primary,
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
