import 'package:flutter/material.dart';
import '../services/audio_player_manager.dart';
import '../services/news_service.dart';
import '../services/radio_hits_service.dart';
import '../models/article.dart';
import '../models/category.dart';
import '../models/radio_hit.dart';
import '../widgets/mini_player.dart';
import '../widgets/live_indicator.dart';
import '../core/theme/app_colors.dart';
import 'article_detail_screen.dart';

/// Pantalla principal de noticias con tres pestañas: Todas, Categorías y Radio Hits
/// Muestra artículos con imágenes y permite navegación por categorías
/// Incluye infinite scroll y mini player cuando hay reproducción activa
class NewsScreen extends StatefulWidget {
  final AudioPlayerManager audioManager;
  const NewsScreen({super.key, required this.audioManager});
  @override
  State<NewsScreen> createState() => _NewsScreenState();
}

class _NewsScreenState extends State<NewsScreen>
    with SingleTickerProviderStateMixin {
  // Controlador de pestañas
  late TabController _tabController;

  // Servicios para obtener datos
  final NewsService _newsService = NewsService();
  final RadioHitsService _radioHitsService = RadioHitsService();

  // Estado de la pestaña de noticias
  List<Article> _articles = [];
  bool _isLoadingNews = true;
  int _newsPage = 1;
  bool _hasMoreNews = true;
  bool _isLoadingMoreNews = false;
  final ScrollController _newsScrollController = ScrollController();

  // Estado de la pestaña de categorías
  List<Category> _categories = [];
  bool _isLoadingCategories = true;

  // Estado de la pestaña de Radio Hits
  List<RadioHit> _radioHits = [];
  bool _isLoadingRadioHits = true;

  // Estado de reproducción del audio
  bool _isPlaying = false;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    _loadArticles();
    _loadCategories();
    _loadRadioHits();
    _setupAudioListener();
    _newsScrollController.addListener(_onNewsScroll);
  }

  @override
  void dispose() {
    _tabController.dispose();
    _newsScrollController.dispose();
    super.dispose();
  }

  /// Configura el listener para detectar cambios en el estado de reproducción
  void _setupAudioListener() {
    widget.audioManager.playingStream.listen((isPlaying) {
      if (mounted) setState(() => _isPlaying = isPlaying);
    });
    _isPlaying = widget.audioManager.isPlaying;
  }

  /// Detecta cuando el usuario hace scroll cerca del final (80%)
  /// para activar la carga automática de más noticias
  void _onNewsScroll() {
    if (_newsScrollController.position.pixels >=
            _newsScrollController.position.maxScrollExtent * 0.8 &&
        !_isLoadingMoreNews &&
        _hasMoreNews) {
      _loadMoreNews();
    }
  }

  /// Carga la primera página de artículos
  Future<void> _loadArticles() async {
    try {
      setState(() {
        _isLoadingNews = true;
        _newsPage = 1;
        _hasMoreNews = true;
      });
      final articles = await _newsService.getArticles();
      if (mounted) {
        setState(() {
          _articles = articles;
          _isLoadingNews = false;
          _hasMoreNews = articles.length >= 20;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoadingNews = false);
        _showErrorSnackBar('Error al cargar las noticias');
      }
    }
  }

  /// Carga más artículos (paginación) para la pestaña de noticias
  Future<void> _loadMoreNews() async {
    if (_isLoadingMoreNews || !_hasMoreNews) return;
    setState(() => _isLoadingMoreNews = true);
    try {
      _newsPage++;
      final newArticles = await _newsService.getArticles(page: _newsPage);
      if (mounted) {
        setState(() {
          _articles.addAll(newArticles);
          _isLoadingMoreNews = false;
          _hasMoreNews = newArticles.length >= 20;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoadingMoreNews = false;
          _newsPage--;
        });
      }
    }
  }

  /// Carga las categorías disponibles desde la API
  Future<void> _loadCategories() async {
    try {
      final categories = await _newsService.getCategories();
      if (mounted) {
        setState(() {
          _categories = categories;
          _isLoadingCategories = false;
        });
      }
    } catch (e) {
      if (mounted) setState(() => _isLoadingCategories = false);
    }
  }

  /// Carga el ranking de Radio Hits desde la página web
  Future<void> _loadRadioHits() async {
    try {
      setState(() => _isLoadingRadioHits = true);
      final radioHits = await _radioHitsService.getRadioHits();
      if (mounted) {
        setState(() {
          _radioHits = radioHits;
          _isLoadingRadioHits = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoadingRadioHits = false);
        _showErrorSnackBar('Error al cargar Radio Hits');
      }
    }
  }

  /// Muestra un mensaje de error en un SnackBar
  void _showErrorSnackBar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), backgroundColor: AppColors.error),
    );
  }

  @override
  Widget build(BuildContext context) {
    final screenSize = MediaQuery.of(context).size;
    final isTablet = screenSize.shortestSide >= 600;
    final textScale = MediaQuery.of(context).textScaler.scale(1.0);

    return Scaffold(
      appBar: AppBar(
        title: Row(
          children: [
            const Text('Noticias'),
            if (_isPlaying) const LiveIndicator(),
          ],
        ),
        centerTitle: false,
        bottom: TabBar(
          controller: _tabController,
          indicatorColor: Colors.white,
          indicatorWeight: 3,
          labelColor: Colors.white,
          unselectedLabelColor: Colors.white.withValues(alpha: 0.7),
          labelStyle: TextStyle(
            fontSize: (isTablet ? 11.0 : 9.0) * textScale,
            fontWeight: FontWeight.bold,
          ),
          unselectedLabelStyle: TextStyle(
            fontSize: (isTablet ? 12.0 : 10.0) * textScale,
            fontWeight: FontWeight.normal,
          ),
          tabs: const [
            Tab(text: 'Todas'),
            Tab(text: 'Categorías'),
            Tab(text: 'Radio Hits'),
          ],
        ),
      ),
      body: Stack(
        children: [
          TabBarView(
            controller: _tabController,
            children: [
              _buildNewsTab(),
              _buildCategoriesTab(),
              _buildRadioHitsTab(),
            ],
          ),
          // Mini player flotante cuando hay audio reproduciéndose
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

  /// Construye la pestaña de categorías
  Widget _buildCategoriesTab() {
    final screenSize = MediaQuery.of(context).size;
    final isTablet = screenSize.shortestSide >= 600;
    final textScale = MediaQuery.of(context).textScaler.scale(1.0);

    // Estado de carga
    if (_isLoadingCategories) {
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
              'Cargando categorías...',
              style: TextStyle(
                color: AppColors.textMuted,
                fontSize: (isTablet ? 16.0 : 14.0) * textScale,
              ),
            ),
          ],
        ),
      );
    }

    // Estado vacío
    if (_categories.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.category_outlined,
              size: (isTablet ? 80.0 : 64.0) * textScale,
              color: AppColors.textSecondary.withValues(alpha: 0.5),
            ),
            SizedBox(height: isTablet ? 24 : 16),
            Text(
              'No hay categorías disponibles',
              style: TextStyle(
                fontSize: (isTablet ? 16.0 : 14.0) * textScale,
                color: AppColors.textSecondary,
              ),
            ),
          ],
        ),
      );
    }

    // Lista de categorías
    return RefreshIndicator(
      onRefresh: _loadCategories,
      color: AppColors.primary,
      child: ListView.builder(
        padding: EdgeInsets.only(
          top: isTablet ? 20 : 16,
          left: isTablet ? 20 : 16,
          right: isTablet ? 20 : 16,
          bottom: _isPlaying ? (isTablet ? 120 : 100) : (isTablet ? 20 : 16),
        ),
        itemCount: _categories.length,
        itemBuilder: (context, index) => _buildCategoryCard(_categories[index]),
      ),
    );
  }

  /// Construye la pestaña de noticias
  Widget _buildNewsTab() {
    final screenSize = MediaQuery.of(context).size;
    final isTablet = screenSize.shortestSide >= 600;
    final textScale = MediaQuery.of(context).textScaler.scale(1.0);

    // Estado de carga
    if (_isLoadingNews) {
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

    // Estado vacío
    if (_articles.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.article_outlined,
              size: (isTablet ? 80.0 : 64.0) * textScale,
              color: AppColors.textSecondary.withValues(alpha: 0.5),
            ),
            SizedBox(height: isTablet ? 24 : 16),
            Text(
              'No hay artículos disponibles',
              style: TextStyle(
                fontSize: (isTablet ? 16.0 : 14.0) * textScale,
                color: AppColors.textSecondary,
              ),
            ),
          ],
        ),
      );
    }

    // Lista de artículos con infinite scroll
    return RefreshIndicator(
      onRefresh: _loadArticles,
      color: AppColors.primary,
      child: ListView.builder(
        controller: _newsScrollController,
        padding: EdgeInsets.only(
          top: isTablet ? 20 : 16,
          left: isTablet ? 20 : 16,
          right: isTablet ? 20 : 16,
          bottom: _isPlaying ? (isTablet ? 120 : 100) : (isTablet ? 20 : 16),
        ),
        itemCount: _articles.length + (_isLoadingMoreNews ? 1 : 0),
        itemBuilder: (context, index) {
          // Indicador de carga al final de la lista
          if (index == _articles.length) {
            return Center(
              child: Padding(
                padding: EdgeInsets.all(isTablet ? 20.0 : 16.0),
                child: CircularProgressIndicator(
                  color: AppColors.primary,
                  strokeWidth: isTablet ? 3.5 : 3,
                ),
              ),
            );
          }
          return _buildArticleCard(_articles[index]);
        },
      ),
    );
  }

  /// Construye la pestaña de Radio Hits
  Widget _buildRadioHitsTab() {
    final screenSize = MediaQuery.of(context).size;
    final isTablet = screenSize.shortestSide >= 600;
    final textScale = MediaQuery.of(context).textScaler.scale(1.0);

    // Estado de carga
    if (_isLoadingRadioHits) {
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
              'Cargando Radio Hits...',
              style: TextStyle(
                color: AppColors.textMuted,
                fontSize: (isTablet ? 16.0 : 14.0) * textScale,
              ),
            ),
          ],
        ),
      );
    }

    // Estado vacío
    if (_radioHits.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.music_note_outlined,
              size: (isTablet ? 80.0 : 64.0) * textScale,
              color: AppColors.textSecondary.withValues(alpha: 0.5),
            ),
            SizedBox(height: isTablet ? 24 : 16),
            Text(
              'No hay Radio Hits disponibles',
              style: TextStyle(
                fontSize: (isTablet ? 16.0 : 14.0) * textScale,
                color: AppColors.textSecondary,
              ),
            ),
            SizedBox(height: 16),
            ElevatedButton.icon(
              onPressed: _loadRadioHits,
              icon: const Icon(Icons.refresh),
              label: const Text('Reintentar'),
            ),
          ],
        ),
      );
    }

    // Lista de Radio Hits
    return RefreshIndicator(
      onRefresh: _loadRadioHits,
      color: AppColors.primary,
      child: ListView.builder(
        padding: EdgeInsets.only(
          top: isTablet ? 20 : 16,
          left: isTablet ? 20 : 16,
          right: isTablet ? 20 : 16,
          bottom: _isPlaying ? (isTablet ? 120 : 100) : (isTablet ? 20 : 16),
        ),
        itemCount: _radioHits.length,
        itemBuilder: (context, index) => _buildRadioHitCard(_radioHits[index]),
      ),
    );
  }

  /// Construye una tarjeta de Radio Hit con imagen, posición y datos de la canción
  Widget _buildRadioHitCard(RadioHit hit) {
    final screenSize = MediaQuery.of(context).size;
    final isTablet = screenSize.shortestSide >= 600;
    final textScale = MediaQuery.of(context).textScaler.scale(1.0);

    // Tamaños responsivos
    final positionSize = (isTablet ? 10.0 : 8.0) * textScale;
    final titleFontSize = (isTablet ? 14.0 : 12.0) * textScale;
    final artistFontSize = (isTablet ? 12.0 : 10.0) * textScale;
    final cardPadding = isTablet ? 16.0 : 12.0;
    final borderRadius = isTablet ? 16.0 : 12.0;
    final cardMargin = isTablet ? 16.0 : 12.0;
    final imageSize = isTablet ? 80.0 : 70.0;
    final positionBadgeSize = (isTablet ? 24.0 : 20.0) * textScale;

    // Determinar color según posición (Top 3 destacados)
    Color positionColor;
    IconData positionIcon;
    if (hit.position == 1) {
      positionColor = const Color(0xFFFFD700); // Oro
      positionIcon = Icons.emoji_events;
    } else if (hit.position == 2) {
      positionColor = const Color(0xFFC0C0C0); // Plata
      positionIcon = Icons.emoji_events;
    } else if (hit.position == 3) {
      positionColor = const Color(0xFFCD7F32); // Bronce
      positionIcon = Icons.emoji_events;
    } else {
      positionColor = AppColors.primary;
      positionIcon = Icons.music_note;
    }

    return Card(
      color: AppColors.cardBackground,
      margin: EdgeInsets.only(bottom: cardMargin),
      elevation: isTablet ? 6 : 4,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(borderRadius),
      ),
      child: Padding(
        padding: EdgeInsets.all(cardPadding),
        child: Row(
          children: [
            // Imagen de la canción con badge de posición
            Stack(
              children: [
                ClipRRect(
                  borderRadius: BorderRadius.circular(isTablet ? 12 : 10),
                  child: hit.imageUrl != null
                      ? Image.network(
                          hit.imageUrl!,
                          width: imageSize,
                          height: imageSize,
                          fit: BoxFit.cover,
                          loadingBuilder: (context, child, loadingProgress) {
                            if (loadingProgress == null) return child;
                            return Container(
                              width: imageSize,
                              height: imageSize,
                              decoration: BoxDecoration(
                                gradient: LinearGradient(
                                  colors: [
                                    positionColor.withValues(alpha: 0.3),
                                    positionColor.withValues(alpha: 0.1),
                                  ],
                                  begin: Alignment.topLeft,
                                  end: Alignment.bottomRight,
                                ),
                              ),
                              child: Center(
                                child: CircularProgressIndicator(
                                  color: positionColor,
                                  strokeWidth: 2,
                                ),
                              ),
                            );
                          },
                          errorBuilder: (context, error, stackTrace) =>
                              Container(
                                width: imageSize,
                                height: imageSize,
                                decoration: BoxDecoration(
                                  gradient: LinearGradient(
                                    colors: [
                                      positionColor.withValues(alpha: 0.3),
                                      positionColor.withValues(alpha: 0.1),
                                    ],
                                    begin: Alignment.topLeft,
                                    end: Alignment.bottomRight,
                                  ),
                                ),
                                child: Icon(
                                  Icons.album,
                                  color: positionColor,
                                  size: (isTablet ? 40.0 : 35.0) * textScale,
                                ),
                              ),
                        )
                      : Container(
                          width: imageSize,
                          height: imageSize,
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              colors: [
                                positionColor.withValues(alpha: 0.3),
                                positionColor.withValues(alpha: 0.1),
                              ],
                              begin: Alignment.topLeft,
                              end: Alignment.bottomRight,
                            ),
                            borderRadius: BorderRadius.circular(
                              isTablet ? 12 : 10,
                            ),
                          ),
                          child: Icon(
                            Icons.album,
                            color: positionColor,
                            size: (isTablet ? 40.0 : 35.0) * textScale,
                          ),
                        ),
                ),
                // Badge de posición superpuesto
                Positioned(
                  top: 0,
                  left: 0,
                  child: Container(
                    width: positionBadgeSize,
                    height: positionBadgeSize,
                    decoration: BoxDecoration(
                      color: positionColor,
                      borderRadius: BorderRadius.only(
                        topLeft: Radius.circular(isTablet ? 12 : 10),
                        bottomRight: Radius.circular(isTablet ? 12 : 10),
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: positionColor.withValues(alpha: 0.4),
                          blurRadius: 8,
                          offset: const Offset(0, 2),
                        ),
                      ],
                    ),
                    child: Center(
                      child: Text(
                        '${hit.position}',
                        style: TextStyle(
                          fontSize: positionSize,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
            SizedBox(width: isTablet ? 16 : 12),
            // Información de la canción
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    hit.songTitle,
                    style: TextStyle(
                      fontSize: titleFontSize,
                      fontWeight: FontWeight.bold,
                      color: AppColors.textPrimary,
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                  SizedBox(height: isTablet ? 6 : 4),
                  Row(
                    children: [
                      Icon(
                        Icons.person_outline,
                        size: (isTablet ? 14.0 : 12.0) * textScale,
                        color: AppColors.textSecondary,
                      ),
                      SizedBox(width: 4),
                      Expanded(
                        child: Text(
                          hit.artist,
                          style: TextStyle(
                            fontSize: artistFontSize,
                            color: AppColors.textSecondary,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            // Icono de trofeo para el Top 3
            if (hit.position <= 3)
              Icon(
                positionIcon,
                color: positionColor,
                size: (isTablet ? 28.0 : 24.0) * textScale,
              ),
          ],
        ),
      ),
    );
  }

  /// Construye una tarjeta de artículo con imagen
  Widget _buildArticleCard(Article article) {
    final screenSize = MediaQuery.of(context).size;
    final isTablet = screenSize.shortestSide >= 600;
    final textScale = MediaQuery.of(context).textScaler.scale(1.0);

    // Tamaños responsivos
    final titleFontSize = (isTablet ? 14.0 : 12.0) * textScale;
    final excerptFontSize = (isTablet ? 10.0 : 8.0) * textScale;
    final dateFontSize = (isTablet ? 10.0 : 8.0) * textScale;
    final cardPadding = isTablet ? 16.0 : 12.0;
    final borderRadius = isTablet ? 16.0 : 12.0;
    final timeIconSize = (isTablet ? 16.0 : 14.0) * textScale;
    final arrowIconSize = (isTablet ? 18.0 : 16.0) * textScale;
    final cardMargin = isTablet ? 20.0 : 16.0;
    final imageHeight = isTablet ? 200.0 : 180.0;

    return Card(
      color: AppColors.cardBackground,
      margin: EdgeInsets.only(bottom: cardMargin),
      elevation: isTablet ? 6 : 4,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(borderRadius),
      ),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: () => Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => ArticleDetailScreen(article: article),
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Imagen del artículo
            if (article.imageUrl != null)
              Image.network(
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
                        strokeWidth: 2,
                        value: loadingProgress.expectedTotalBytes != null
                            ? loadingProgress.cumulativeBytesLoaded /
                                  loadingProgress.expectedTotalBytes!
                            : null,
                      ),
                    ),
                  );
                },
                errorBuilder: (context, error, stackTrace) => Container(
                  height: imageHeight,
                  color: AppColors.primary.withValues(alpha: 0.1),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        Icons.image_not_supported,
                        size: isTablet ? 48 : 40,
                        color: AppColors.textSecondary.withValues(alpha: 0.5),
                      ),
                      SizedBox(height: 8),
                      Text(
                        'Imagen no disponible',
                        style: TextStyle(
                          fontSize: (isTablet ? 12.0 : 10.0) * textScale,
                          color: AppColors.textSecondary,
                        ),
                      ),
                    ],
                  ),
                ),
              )
            else
              Container(
                height: imageHeight,
                color: AppColors.primary.withValues(alpha: 0.1),
                child: Center(
                  child: Icon(
                    Icons.article,
                    size: isTablet ? 60 : 50,
                    color: AppColors.primary.withValues(alpha: 0.3),
                  ),
                ),
              ),
            // Contenido de la tarjeta
            Padding(
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
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                  SizedBox(height: isTablet ? 12 : 10),
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
          ],
        ),
      ),
    );
  }

  /// Construye una tarjeta de categoría con imagen opcional
  Widget _buildCategoryCard(Category category) {
    final screenSize = MediaQuery.of(context).size;
    final isTablet = screenSize.shortestSide >= 600;
    final textScale = MediaQuery.of(context).textScaler.scale(1.0);

    // Tamaños responsivos
    final titleFontSize = (isTablet ? 14.0 : 12.0) * textScale;
    final countFontSize = (isTablet ? 10.0 : 8.0) * textScale;
    final cardPadding = isTablet ? 20.0 : 16.0;
    final borderRadius = isTablet ? 16.0 : 12.0;
    final imageSize = isTablet ? 70.0 : 60.0;
    final arrowIconSize = (isTablet ? 20.0 : 18.0) * textScale;
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
        onTap: () => Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => CategoryNewsScreen(
              category: category,
              audioManager: widget.audioManager,
            ),
          ),
        ),
        child: Padding(
          padding: EdgeInsets.all(cardPadding),
          child: Row(
            children: [
              // Imagen o icono de categoría
              ClipRRect(
                borderRadius: BorderRadius.circular(isTablet ? 12 : 10),
                child: category.imageUrl != null
                    ? Image.network(
                        category.imageUrl!,
                        width: imageSize,
                        height: imageSize,
                        fit: BoxFit.cover,
                        loadingBuilder: (context, child, loadingProgress) {
                          if (loadingProgress == null) return child;
                          return Container(
                            width: imageSize,
                            height: imageSize,
                            decoration: BoxDecoration(
                              gradient: LinearGradient(
                                colors: [
                                  AppColors.primary.withValues(alpha: 0.2),
                                  AppColors.primary.withValues(alpha: 0.05),
                                ],
                                begin: Alignment.topLeft,
                                end: Alignment.bottomRight,
                              ),
                            ),
                            child: Center(
                              child: CircularProgressIndicator(
                                color: AppColors.primary,
                                strokeWidth: 2,
                              ),
                            ),
                          );
                        },
                        errorBuilder: (context, error, stackTrace) => Container(
                          width: imageSize,
                          height: imageSize,
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              colors: [
                                AppColors.primary.withValues(alpha: 0.2),
                                AppColors.primary.withValues(alpha: 0.05),
                              ],
                              begin: Alignment.topLeft,
                              end: Alignment.bottomRight,
                            ),
                          ),
                          child: Icon(
                            Icons.label,
                            color: AppColors.primary,
                            size: (isTablet ? 32.0 : 28.0) * textScale,
                          ),
                        ),
                      )
                    : Container(
                        width: imageSize,
                        height: imageSize,
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            colors: [
                              AppColors.primary.withValues(alpha: 0.2),
                              AppColors.primary.withValues(alpha: 0.05),
                            ],
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                          ),
                        ),
                        child: Icon(
                          Icons.label,
                          color: AppColors.primary,
                          size: (isTablet ? 32.0 : 28.0) * textScale,
                        ),
                      ),
              ),
              SizedBox(width: isTablet ? 16 : 12),
              // Información de la categoría
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      category.name,
                      style: TextStyle(
                        fontSize: titleFontSize,
                        fontWeight: FontWeight.bold,
                        color: AppColors.textPrimary,
                      ),
                    ),
                    SizedBox(height: isTablet ? 6 : 4),
                    Text(
                      '${category.count} ${category.count == 1 ? 'artículo' : 'artículos'}',
                      style: TextStyle(
                        fontSize: countFontSize,
                        color: AppColors.textSecondary,
                      ),
                    ),
                  ],
                ),
              ),
              Icon(
                Icons.arrow_forward_ios,
                size: arrowIconSize,
                color: AppColors.primary,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Pantalla de artículos filtrados por categoría
/// Muestra todos los artículos que pertenecen a una categoría específica
/// Incluye infinite scroll y mini player
class CategoryNewsScreen extends StatefulWidget {
  final Category category;
  final AudioPlayerManager audioManager;

  const CategoryNewsScreen({
    super.key,
    required this.category,
    required this.audioManager,
  });

  @override
  State<CategoryNewsScreen> createState() => _CategoryNewsScreenState();
}

class _CategoryNewsScreenState extends State<CategoryNewsScreen> {
  final NewsService _newsService = NewsService();
  final ScrollController _scrollController = ScrollController();

  // Estado de la pantalla
  List<Article> _articles = [];
  bool _isLoading = true;
  bool _isLoadingMore = false;
  bool _isPlaying = false;
  int _currentPage = 1;
  bool _hasMore = true;

  @override
  void initState() {
    super.initState();
    _loadArticles();
    _setupAudioListener();
    _scrollController.addListener(_onScroll);
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  /// Configura el listener para el estado de reproducción
  void _setupAudioListener() {
    widget.audioManager.playingStream.listen((isPlaying) {
      if (mounted) setState(() => _isPlaying = isPlaying);
    });
    _isPlaying = widget.audioManager.isPlaying;
  }

  /// Detecta scroll para activar infinite scroll
  void _onScroll() {
    if (_scrollController.position.pixels >=
            _scrollController.position.maxScrollExtent * 0.8 &&
        !_isLoadingMore &&
        _hasMore) {
      _loadMoreArticles();
    }
  }

  /// Carga artículos de la categoría seleccionada
  Future<void> _loadArticles() async {
    try {
      setState(() {
        _isLoading = true;
        _currentPage = 1;
        _hasMore = true;
      });
      final articles = await _newsService.getArticlesByCategory(
        widget.category.id,
      );
      if (mounted) {
        setState(() {
          _articles = articles;
          _isLoading = false;
          _hasMore = articles.length >= 20;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
        _showErrorSnackBar('Error al cargar artículos');
      }
    }
  }

  /// Carga más artículos (paginación)
  Future<void> _loadMoreArticles() async {
    if (_isLoadingMore || !_hasMore) return;
    setState(() => _isLoadingMore = true);
    try {
      _currentPage++;
      final newArticles = await _newsService.getArticlesByCategory(
        widget.category.id,
        page: _currentPage,
      );
      if (mounted) {
        setState(() {
          _articles.addAll(newArticles);
          _isLoadingMore = false;
          _hasMore = newArticles.length >= 20;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoadingMore = false;
          _currentPage--;
        });
      }
    }
  }

  /// Muestra mensaje de error
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
            Expanded(
              child: Text(
                widget.category.name,
                overflow: TextOverflow.ellipsis,
              ),
            ),
            if (_isPlaying) const LiveIndicator(),
          ],
        ),
        centerTitle: false,
      ),
      body: Stack(
        children: [
          _buildContent(),
          // Mini player flotante
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

  /// Construye el contenido principal con estados de carga, vacío y lista
  Widget _buildContent() {
    final screenSize = MediaQuery.of(context).size;
    final isTablet = screenSize.shortestSide >= 600;
    final textScale = MediaQuery.of(context).textScaler.scale(1.0);

    // Estado de carga
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
              'Cargando artículos...',
              style: TextStyle(
                color: AppColors.textMuted,
                fontSize: (isTablet ? 16.0 : 14.0) * textScale,
              ),
            ),
          ],
        ),
      );
    }

    // Estado vacío
    if (_articles.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.article_outlined,
              size: (isTablet ? 80.0 : 64.0) * textScale,
              color: AppColors.textSecondary.withValues(alpha: 0.5),
            ),
            SizedBox(height: isTablet ? 24 : 16),
            Text(
              'No hay artículos en esta categoría',
              style: TextStyle(
                fontSize: (isTablet ? 16.0 : 14.0) * textScale,
                color: AppColors.textSecondary,
              ),
            ),
          ],
        ),
      );
    }

    // Lista de artículos
    return RefreshIndicator(
      onRefresh: _loadArticles,
      color: AppColors.primary,
      child: ListView.builder(
        controller: _scrollController,
        padding: EdgeInsets.only(
          top: isTablet ? 20 : 16,
          left: isTablet ? 20 : 16,
          right: isTablet ? 20 : 16,
          bottom: _isPlaying ? (isTablet ? 120 : 100) : (isTablet ? 20 : 16),
        ),
        itemCount: _articles.length + (_isLoadingMore ? 1 : 0),
        itemBuilder: (context, index) {
          // Indicador de carga al final de la lista
          if (index == _articles.length) {
            return Center(
              child: Padding(
                padding: EdgeInsets.all(isTablet ? 20.0 : 16.0),
                child: CircularProgressIndicator(
                  color: AppColors.primary,
                  strokeWidth: isTablet ? 3.5 : 3,
                ),
              ),
            );
          }
          return _buildArticleCard(_articles[index]);
        },
      ),
    );
  }

  /// Construye una tarjeta de artículo con imagen para la vista de categoría
  Widget _buildArticleCard(Article article) {
    final screenSize = MediaQuery.of(context).size;
    final isTablet = screenSize.shortestSide >= 600;
    final textScale = MediaQuery.of(context).textScaler.scale(1.0);

    // Tamaños responsivos
    final titleFontSize = (isTablet ? 12.0 : 10.0) * textScale;
    final excerptFontSize = (isTablet ? 10.0 : 8.0) * textScale;
    final dateFontSize = (isTablet ? 10.0 : 8.0) * textScale;
    final cardPadding = isTablet ? 16.0 : 12.0;
    final borderRadius = isTablet ? 16.0 : 12.0;
    final timeIconSize = (isTablet ? 16.0 : 14.0) * textScale;
    final arrowIconSize = (isTablet ? 18.0 : 16.0) * textScale;
    final cardMargin = isTablet ? 20.0 : 16.0;
    final imageHeight = isTablet ? 180.0 : 160.0;

    return Card(
      color: AppColors.cardBackground,
      margin: EdgeInsets.only(bottom: cardMargin),
      elevation: isTablet ? 6 : 4,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(borderRadius),
      ),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: () => Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => ArticleDetailScreen(article: article),
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Imagen del artículo
            if (article.imageUrl != null)
              Image.network(
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
                        strokeWidth: 2,
                      ),
                    ),
                  );
                },
                errorBuilder: (context, error, stackTrace) => Container(
                  height: imageHeight,
                  color: AppColors.primary.withValues(alpha: 0.1),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        Icons.image_not_supported,
                        size: isTablet ? 48 : 40,
                        color: AppColors.textSecondary.withValues(alpha: 0.5),
                      ),
                      SizedBox(height: 8),
                      Text(
                        'Imagen no disponible',
                        style: TextStyle(
                          fontSize: (isTablet ? 12.0 : 10.0) * textScale,
                          color: AppColors.textSecondary,
                        ),
                      ),
                    ],
                  ),
                ),
              )
            else
              Container(
                height: imageHeight,
                color: AppColors.primary.withValues(alpha: 0.1),
                child: Center(
                  child: Icon(
                    Icons.article,
                    size: isTablet ? 60 : 50,
                    color: AppColors.primary.withValues(alpha: 0.3),
                  ),
                ),
              ),
            // Contenido de la tarjeta
            Padding(
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
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                  SizedBox(height: isTablet ? 12 : 10),
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
          ],
        ),
      ),
    );
  }
}
