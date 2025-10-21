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
import '../utils/responsive_helper.dart';

/// Pantalla principal de noticias mejorada con Radio Hits
class NewsScreen extends StatefulWidget {
  final AudioPlayerManager audioManager;
  const NewsScreen({super.key, required this.audioManager});

  @override
  State<NewsScreen> createState() => _NewsScreenState();
}

class _NewsScreenState extends State<NewsScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final NewsService _newsService = NewsService();
  final RadioHitsService _radioHitsService = RadioHitsService();

  List<Article> _articles = [];
  bool _isLoadingNews = true;
  int _newsPage = 1;
  bool _hasMoreNews = true;
  bool _isLoadingMoreNews = false;
  final ScrollController _newsScrollController = ScrollController();

  List<Category> _categories = [];
  bool _isLoadingCategories = true;

  List<RadioHit> _radioHits = [];
  bool _isLoadingRadioHits = true;

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

  void _setupAudioListener() {
    widget.audioManager.playingStream.listen((isPlaying) {
      if (mounted) setState(() => _isPlaying = isPlaying);
    });
    _isPlaying = widget.audioManager.isPlaying;
  }

  void _onNewsScroll() {
    if (_newsScrollController.position.pixels >=
            _newsScrollController.position.maxScrollExtent * 0.8 &&
        !_isLoadingMoreNews &&
        _hasMoreNews) {
      _loadMoreNews();
    }
  }

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

  void _showErrorSnackBar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: AppColors.error,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final responsive = ResponsiveHelper(context);

    return Scaffold(
      appBar: AppBar(
        title: Row(
          children: [
            Text('Noticias', style: TextStyle(fontSize: responsive.h2)),
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
            fontSize: responsive.caption,
            fontWeight: FontWeight.bold,
          ),
          unselectedLabelStyle: TextStyle(
            fontSize: responsive.caption,
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
              _buildNewsTab(responsive),
              _buildCategoriesTab(responsive),
              _buildRadioHitsTab(responsive),
            ],
          ),
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

  Widget _buildNewsTab(ResponsiveHelper responsive) {
    if (_isLoadingNews) {
      return _buildLoadingState(responsive, 'Cargando noticias...');
    }

    if (_articles.isEmpty) {
      return _buildEmptyState(
        responsive,
        Icons.article_outlined,
        'No hay artículos disponibles',
      );
    }

    return _buildArticlesList(
      responsive,
      _articles,
      _newsScrollController,
      _isLoadingMoreNews,
    );
  }

  Widget _buildCategoriesTab(ResponsiveHelper responsive) {
    if (_isLoadingCategories) {
      return _buildLoadingState(responsive, 'Cargando categorías...');
    }

    if (_categories.isEmpty) {
      return _buildEmptyState(
        responsive,
        Icons.category_outlined,
        'No hay categorías disponibles',
      );
    }

    return _buildCategoriesList(responsive);
  }

  Widget _buildRadioHitsTab(ResponsiveHelper responsive) {
    if (_isLoadingRadioHits) {
      return _buildLoadingState(responsive, 'Cargando Radio Hits...');
    }

    if (_radioHits.isEmpty) {
      return Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.music_note_outlined,
            size: responsive.getValue(phone: 64.0, tablet: 80.0, desktop: 96.0),
            color: AppColors.textSecondary.withValues(alpha: 0.5),
          ),
          SizedBox(height: responsive.spacing(24)),
          Text(
            'No hay Radio Hits disponibles',
            style: TextStyle(
              fontSize: responsive.h3,
              color: AppColors.textSecondary,
            ),
          ),
          SizedBox(height: responsive.spacing(16)),
          ElevatedButton.icon(
            onPressed: _loadRadioHits,
            icon: const Icon(Icons.refresh),
            label: const Text('Reintentar'),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primary,
              padding: EdgeInsets.symmetric(
                horizontal: responsive.spacing(24),
                vertical: responsive.spacing(12),
              ),
            ),
          ),
        ],
      );
    }

    return _buildRadioHitsList(responsive);
  }

  Widget _buildLoadingState(ResponsiveHelper responsive, String message) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          CircularProgressIndicator(
            color: AppColors.primary,
            strokeWidth: responsive.getValue(phone: 3.0, tablet: 4.0),
          ),
          SizedBox(height: responsive.spacing(20)),
          Text(
            message,
            style: TextStyle(
              color: AppColors.textMuted,
              fontSize: responsive.bodyText,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState(
    ResponsiveHelper responsive,
    IconData icon,
    String message,
  ) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            icon,
            size: responsive.getValue(phone: 64.0, tablet: 80.0, desktop: 96.0),
            color: AppColors.textSecondary.withValues(alpha: 0.5),
          ),
          SizedBox(height: responsive.spacing(24)),
          Text(
            message,
            style: TextStyle(
              fontSize: responsive.h3,
              color: AppColors.textSecondary,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildArticlesList(
    ResponsiveHelper responsive,
    List<Article> articles,
    ScrollController scrollController,
    bool isLoadingMore,
  ) {
    final padding = responsive.getValue(
      phone: 16.0,
      largePhone: 18.0,
      tablet: 24.0,
      desktop: 32.0,
    );

    final bottomPadding = _isPlaying
        ? responsive.getValue(phone: 100.0, tablet: 120.0, desktop: 140.0)
        : padding;

    // Grid para tablets/desktop - CON AJUSTE PARA EVITAR OVERFLOW
    if (responsive.gridColumns > 1) {
      return RefreshIndicator(
        onRefresh: _loadArticles,
        color: AppColors.primary,
        child: Center(
          child: ConstrainedBox(
            constraints: BoxConstraints(maxWidth: responsive.maxContentWidth),
            child: GridView.builder(
              controller: scrollController,
              padding: EdgeInsets.only(
                top: padding,
                left: padding,
                right: padding,
                bottom: bottomPadding,
              ),
              gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: responsive.gridColumns,
                crossAxisSpacing: padding,
                mainAxisSpacing: padding,
                childAspectRatio:
                    0.72, // ✅ Ajustado de 0.75 a 0.72 para dar más altura
              ),
              itemCount: articles.length + (isLoadingMore ? 1 : 0),
              itemBuilder: (context, index) {
                if (index == articles.length) {
                  return Center(
                    child: CircularProgressIndicator(color: AppColors.primary),
                  );
                }
                return _buildArticleCard(
                  articles[index],
                  responsive,
                  isGrid: true,
                );
              },
            ),
          ),
        ),
      );
    }

    // Lista para móviles
    return RefreshIndicator(
      onRefresh: _loadArticles,
      color: AppColors.primary,
      child: ListView.builder(
        controller: scrollController,
        padding: EdgeInsets.only(
          top: padding,
          left: padding,
          right: padding,
          bottom: bottomPadding,
        ),
        itemCount: articles.length + (isLoadingMore ? 1 : 0),
        itemBuilder: (context, index) {
          if (index == articles.length) {
            return Center(
              child: Padding(
                padding: EdgeInsets.all(padding),
                child: CircularProgressIndicator(color: AppColors.primary),
              ),
            );
          }
          return Padding(
            padding: EdgeInsets.only(bottom: padding),
            child: _buildArticleCard(
              articles[index],
              responsive,
              isGrid: false,
            ),
          );
        },
      ),
    );
  }

  Widget _buildCategoriesList(ResponsiveHelper responsive) {
    final padding = responsive.getValue(
      phone: 16.0,
      largePhone: 18.0,
      tablet: 24.0,
      desktop: 32.0,
    );

    final bottomPadding = _isPlaying
        ? responsive.getValue(phone: 100.0, tablet: 120.0, desktop: 140.0)
        : padding;

    return RefreshIndicator(
      onRefresh: _loadCategories,
      color: AppColors.primary,
      child: ListView.builder(
        padding: EdgeInsets.only(
          top: padding,
          left: padding,
          right: padding,
          bottom: bottomPadding,
        ),
        itemCount: _categories.length,
        itemBuilder: (context, index) => Padding(
          padding: EdgeInsets.only(bottom: padding),
          child: _buildCategoryCard(_categories[index], responsive),
        ),
      ),
    );
  }

  Widget _buildRadioHitsList(ResponsiveHelper responsive) {
    final padding = responsive.getValue(
      phone: 16.0,
      largePhone: 18.0,
      tablet: 24.0,
      desktop: 32.0,
    );

    final bottomPadding = _isPlaying
        ? responsive.getValue(phone: 100.0, tablet: 120.0, desktop: 140.0)
        : padding;

    return RefreshIndicator(
      onRefresh: _loadRadioHits,
      color: AppColors.primary,
      child: ListView.builder(
        padding: EdgeInsets.only(
          top: padding,
          left: padding,
          right: padding,
          bottom: bottomPadding,
        ),
        itemCount: _radioHits.length,
        itemBuilder: (context, index) => Padding(
          padding: EdgeInsets.only(bottom: padding),
          child: _buildRadioHitCard(_radioHits[index], responsive),
        ),
      ),
    );
  }

  /// ✅ MÉTODO CORREGIDO - Evita overflow en tablets con Grid
  Widget _buildArticleCard(
    Article article,
    ResponsiveHelper responsive, {
    required bool isGrid,
  }) {
    // ✅ Detectar orientación
    final isLandscape =
        MediaQuery.of(context).orientation == Orientation.landscape;

    final borderRadius = responsive.getValue(
      phone: 12.0,
      largePhone: 14.0,
      tablet: 16.0,
      desktop: 18.0,
    );

    // ✅ Reducir padding en grid para ahorrar espacio
    final padding = isGrid
        ? responsive.getValue(
            phone: 12.0,
            largePhone: 12.0,
            tablet: isLandscape ? 8.0 : 10.0, // Aún menos padding en landscape
            desktop: 12.0,
          )
        : responsive.getValue(
            phone: 12.0,
            largePhone: 14.0,
            tablet: 16.0,
            desktop: 18.0,
          );

    return Card(
      color: AppColors.cardBackground,
      elevation: responsive.getValue(phone: 4.0, tablet: 6.0),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(borderRadius),
      ),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: () => Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => ArticleDetailScreen(
              article: article,
              audioManager: widget.audioManager,
            ),
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ✅ Imagen con Expanded para usar espacio flexible
            Expanded(
              flex: isGrid
                  ? (isLandscape ? 7 : 6)
                  : 0, // Más imagen en landscape
              child: article.imageUrl != null
                  ? Image.network(
                      article.imageUrl!,
                      height: isGrid
                          ? null
                          : responsive.getValue(
                              phone: 180.0,
                              largePhone: 200.0,
                              tablet: 220.0,
                              desktop: 240.0,
                            ),
                      width: double.infinity,
                      fit: BoxFit.cover,
                      loadingBuilder: (context, child, loadingProgress) {
                        if (loadingProgress == null) return child;
                        return Container(
                          height: isGrid
                              ? null
                              : responsive.getValue(
                                  phone: 180.0,
                                  largePhone: 200.0,
                                  tablet: 220.0,
                                  desktop: 240.0,
                                ),
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
                        height: isGrid
                            ? null
                            : responsive.getValue(phone: 180.0, tablet: 220.0),
                        color: AppColors.primary.withValues(alpha: 0.1),
                        child: Icon(
                          Icons.image_not_supported,
                          size: responsive.getValue(phone: 40.0, tablet: 48.0),
                          color: AppColors.textSecondary.withValues(alpha: 0.5),
                        ),
                      ),
                    )
                  : Container(
                      height: isGrid
                          ? null
                          : responsive.getValue(phone: 180.0, tablet: 220.0),
                      color: AppColors.primary.withValues(alpha: 0.1),
                      child: Icon(
                        Icons.article,
                        size: responsive.getValue(phone: 50.0, tablet: 60.0),
                        color: AppColors.primary.withValues(alpha: 0.3),
                      ),
                    ),
            ),

            // ✅ Contenido de texto con Expanded en grid
            if (isGrid)
              Expanded(
                flex: 4,
                child: Padding(
                  padding: EdgeInsets.all(padding),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      // Título
                      Flexible(
                        child: Text(
                          article.title,
                          style: TextStyle(
                            fontSize: responsive.getValue(
                              phone: 14.0,
                              tablet: 13.0, // Reducido para tablets
                              desktop: 14.0,
                            ),
                            fontWeight: FontWeight.bold,
                            color: AppColors.textPrimary,
                            height: 1.2,
                          ),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),

                      // Espaciador
                      SizedBox(height: responsive.spacing(6)),

                      // Fecha
                      Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            Icons.access_time,
                            size: responsive.getValue(
                              phone: 12.0,
                              tablet: 11.0, // Reducido para tablets
                              desktop: 12.0,
                            ),
                            color: AppColors.textSecondary,
                          ),
                          const SizedBox(width: 4),
                          Flexible(
                            child: Text(
                              article.formattedDate,
                              style: TextStyle(
                                fontSize: responsive.getValue(
                                  phone: 11.0,
                                  tablet: 10.0, // Reducido para tablets
                                  desktop: 11.0,
                                ),
                                color: AppColors.textSecondary,
                              ),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              )
            else
              // Contenido normal para ListView
              Padding(
                padding: EdgeInsets.all(padding),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      article.title,
                      style: TextStyle(
                        fontSize: responsive.h3,
                        fontWeight: FontWeight.bold,
                        color: AppColors.textPrimary,
                        height: 1.3,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                    SizedBox(height: responsive.spacing(12)),
                    Text(
                      article.excerpt,
                      style: TextStyle(
                        fontSize: responsive.caption,
                        color: AppColors.textMuted,
                        height: 1.4,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                    SizedBox(height: responsive.spacing(12)),
                    Row(
                      children: [
                        Icon(
                          Icons.access_time,
                          size: responsive.getValue(
                            phone: 14.0,
                            tablet: 16.0,
                            desktop: 18.0,
                          ),
                          color: AppColors.textSecondary,
                        ),
                        const SizedBox(width: 6),
                        Expanded(
                          child: Text(
                            article.formattedDate,
                            style: TextStyle(
                              fontSize: responsive.caption,
                              color: AppColors.textSecondary,
                            ),
                          ),
                        ),
                        Icon(
                          Icons.arrow_forward_ios,
                          size: responsive.getValue(
                            phone: 14.0,
                            tablet: 16.0,
                            desktop: 18.0,
                          ),
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

  Widget _buildCategoryCard(Category category, ResponsiveHelper responsive) {
    final borderRadius = responsive.getValue(
      phone: 12.0,
      largePhone: 14.0,
      tablet: 16.0,
      desktop: 18.0,
    );

    final padding = responsive.getValue(
      phone: 16.0,
      largePhone: 18.0,
      tablet: 20.0,
      desktop: 24.0,
    );

    final imageSize = responsive.getValue(
      phone: 60.0,
      largePhone: 65.0,
      tablet: 70.0,
      desktop: 80.0,
    );

    return Card(
      color: AppColors.cardBackground,
      elevation: responsive.getValue(phone: 4.0, tablet: 6.0),
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
          padding: EdgeInsets.all(padding),
          child: Row(
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(borderRadius * 0.7),
                child: category.imageUrl != null
                    ? Image.network(
                        category.imageUrl!,
                        width: imageSize,
                        height: imageSize,
                        fit: BoxFit.cover,
                        errorBuilder: (context, error, stackTrace) => Container(
                          width: imageSize,
                          height: imageSize,
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              colors: [
                                AppColors.primary.withValues(alpha: 0.2),
                                AppColors.primary.withValues(alpha: 0.05),
                              ],
                            ),
                          ),
                          child: Icon(
                            Icons.label,
                            color: AppColors.primary,
                            size: imageSize * 0.5,
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
                          ),
                        ),
                        child: Icon(
                          Icons.label,
                          color: AppColors.primary,
                          size: imageSize * 0.5,
                        ),
                      ),
              ),
              SizedBox(width: responsive.spacing(16)),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      category.name,
                      style: TextStyle(
                        fontSize: responsive.h3,
                        fontWeight: FontWeight.bold,
                        color: AppColors.textPrimary,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '${category.count} ${category.count == 1 ? 'artículo' : 'artículos'}',
                      style: TextStyle(
                        fontSize: responsive.caption,
                        color: AppColors.textSecondary,
                      ),
                    ),
                  ],
                ),
              ),
              Icon(
                Icons.arrow_forward_ios,
                size: responsive.getValue(phone: 18.0, tablet: 20.0),
                color: AppColors.primary,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildRadioHitCard(RadioHit hit, ResponsiveHelper responsive) {
    final borderRadius = responsive.getValue(
      phone: 12.0,
      largePhone: 14.0,
      tablet: 16.0,
      desktop: 18.0,
    );

    final padding = responsive.getValue(
      phone: 12.0,
      largePhone: 14.0,
      tablet: 16.0,
      desktop: 18.0,
    );

    final imageSize = responsive.getValue(
      phone: 70.0,
      largePhone: 75.0,
      tablet: 80.0,
      desktop: 90.0,
    );

    final badgeSize = responsive.getValue(
      phone: 20.0,
      largePhone: 22.0,
      tablet: 24.0,
      desktop: 28.0,
    );

    Color positionColor;
    IconData positionIcon;
    if (hit.position == 1) {
      positionColor = const Color(0xFFFFD700);
      positionIcon = Icons.emoji_events;
    } else if (hit.position == 2) {
      positionColor = const Color(0xFFC0C0C0);
      positionIcon = Icons.emoji_events;
    } else if (hit.position == 3) {
      positionColor = const Color(0xFFCD7F32);
      positionIcon = Icons.emoji_events;
    } else {
      positionColor = AppColors.primary;
      positionIcon = Icons.music_note;
    }

    return Card(
      color: AppColors.cardBackground,
      elevation: responsive.getValue(phone: 4.0, tablet: 6.0),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(borderRadius),
      ),
      child: Padding(
        padding: EdgeInsets.all(padding),
        child: Row(
          children: [
            Stack(
              children: [
                ClipRRect(
                  borderRadius: BorderRadius.circular(borderRadius * 0.7),
                  child: hit.imageUrl != null
                      ? Image.network(
                          hit.imageUrl!,
                          width: imageSize,
                          height: imageSize,
                          fit: BoxFit.cover,
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
                                  ),
                                ),
                                child: Icon(
                                  Icons.album,
                                  color: positionColor,
                                  size: imageSize * 0.5,
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
                            ),
                          ),
                          child: Icon(
                            Icons.album,
                            color: positionColor,
                            size: imageSize * 0.5,
                          ),
                        ),
                ),
                Positioned(
                  top: 0,
                  left: 0,
                  child: Container(
                    width: badgeSize,
                    height: badgeSize,
                    decoration: BoxDecoration(
                      color: positionColor,
                      borderRadius: BorderRadius.only(
                        topLeft: Radius.circular(borderRadius * 0.7),
                        bottomRight: Radius.circular(borderRadius * 0.7),
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
                          fontSize: responsive.getValue(
                            phone: 10.0,
                            largePhone: 11.0,
                            tablet: 12.0,
                            desktop: 14.0,
                          ),
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
            SizedBox(width: responsive.spacing(12)),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    hit.songTitle,
                    style: TextStyle(
                      fontSize: responsive.h3,
                      fontWeight: FontWeight.bold,
                      color: AppColors.textPrimary,
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                  SizedBox(
                    height: responsive.getValue(phone: 4.0, tablet: 6.0),
                  ),
                  Row(
                    children: [
                      Icon(
                        Icons.person_outline,
                        size: responsive.getValue(
                          phone: 12.0,
                          tablet: 14.0,
                          desktop: 16.0,
                        ),
                        color: AppColors.textSecondary,
                      ),
                      const SizedBox(width: 4),
                      Expanded(
                        child: Text(
                          hit.artist,
                          style: TextStyle(
                            fontSize: responsive.caption,
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
            if (hit.position <= 3)
              Icon(
                positionIcon,
                color: positionColor,
                size: responsive.getValue(
                  phone: 24.0,
                  largePhone: 26.0,
                  tablet: 28.0,
                  desktop: 32.0,
                ),
              ),
          ],
        ),
      ),
    );
  }
}

/// Pantalla de artículos por categoría (responsive)
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

  void _setupAudioListener() {
    widget.audioManager.playingStream.listen((isPlaying) {
      if (mounted) setState(() => _isPlaying = isPlaying);
    });
    _isPlaying = widget.audioManager.isPlaying;
  }

  void _onScroll() {
    if (_scrollController.position.pixels >=
            _scrollController.position.maxScrollExtent * 0.8 &&
        !_isLoadingMore &&
        _hasMore) {
      _loadMoreArticles();
    }
  }

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
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text('Error al cargar artículos'),
            backgroundColor: AppColors.error,
          ),
        );
      }
    }
  }

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

  @override
  Widget build(BuildContext context) {
    final responsive = ResponsiveHelper(context);

    return Scaffold(
      appBar: AppBar(
        title: Row(
          children: [
            Expanded(
              child: Text(
                widget.category.name,
                style: TextStyle(fontSize: responsive.h2),
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
          _buildContent(responsive),
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

  Widget _buildContent(ResponsiveHelper responsive) {
    if (_isLoading) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            CircularProgressIndicator(
              color: AppColors.primary,
              strokeWidth: responsive.getValue(phone: 3.0, tablet: 4.0),
            ),
            SizedBox(height: responsive.spacing(20)),
            Text(
              'Cargando artículos...',
              style: TextStyle(
                color: AppColors.textMuted,
                fontSize: responsive.bodyText,
              ),
            ),
          ],
        ),
      );
    }

    if (_articles.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.article_outlined,
              size: responsive.getValue(phone: 64.0, tablet: 80.0),
              color: AppColors.textSecondary.withValues(alpha: 0.5),
            ),
            SizedBox(height: responsive.spacing(24)),
            Text(
              'No hay artículos en esta categoría',
              style: TextStyle(
                fontSize: responsive.h3,
                color: AppColors.textSecondary,
              ),
            ),
          ],
        ),
      );
    }

    final padding = responsive.getValue(
      phone: 16.0,
      largePhone: 18.0,
      tablet: 24.0,
      desktop: 32.0,
    );

    final bottomPadding = _isPlaying
        ? responsive.getValue(phone: 100.0, tablet: 120.0, desktop: 140.0)
        : padding;

    return RefreshIndicator(
      onRefresh: _loadArticles,
      color: AppColors.primary,
      child: ListView.builder(
        controller: _scrollController,
        padding: EdgeInsets.only(
          top: padding,
          left: padding,
          right: padding,
          bottom: bottomPadding,
        ),
        itemCount: _articles.length + (_isLoadingMore ? 1 : 0),
        itemBuilder: (context, index) {
          if (index == _articles.length) {
            return Center(
              child: Padding(
                padding: EdgeInsets.all(padding),
                child: CircularProgressIndicator(color: AppColors.primary),
              ),
            );
          }
          return Padding(
            padding: EdgeInsets.only(bottom: padding),
            child: _buildArticleCard(_articles[index], responsive),
          );
        },
      ),
    );
  }

  Widget _buildArticleCard(Article article, ResponsiveHelper responsive) {
    final borderRadius = responsive.getValue(
      phone: 12.0,
      largePhone: 14.0,
      tablet: 16.0,
      desktop: 18.0,
    );

    final padding = responsive.getValue(
      phone: 12.0,
      largePhone: 14.0,
      tablet: 16.0,
      desktop: 18.0,
    );

    final imageHeight = responsive.getValue(
      phone: 160.0,
      largePhone: 180.0,
      tablet: 200.0,
      desktop: 220.0,
    );

    return Card(
      color: AppColors.cardBackground,
      elevation: responsive.getValue(phone: 4.0, tablet: 6.0),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(borderRadius),
      ),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: () => Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => ArticleDetailScreen(
              article: article,
              audioManager: widget.audioManager,
            ),
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
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
                  child: Icon(
                    Icons.image_not_supported,
                    size: responsive.getValue(phone: 40.0, tablet: 48.0),
                    color: AppColors.textSecondary.withValues(alpha: 0.5),
                  ),
                ),
              )
            else
              Container(
                height: imageHeight,
                color: AppColors.primary.withValues(alpha: 0.1),
                child: Icon(
                  Icons.article,
                  size: responsive.getValue(phone: 50.0, tablet: 60.0),
                  color: AppColors.primary.withValues(alpha: 0.3),
                ),
              ),
            Padding(
              padding: EdgeInsets.all(padding),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    article.title,
                    style: TextStyle(
                      fontSize: responsive.h3,
                      fontWeight: FontWeight.bold,
                      color: AppColors.textPrimary,
                      height: 1.3,
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                  SizedBox(height: responsive.spacing(12)),
                  Text(
                    article.excerpt,
                    style: TextStyle(
                      fontSize: responsive.caption,
                      color: AppColors.textMuted,
                      height: 1.4,
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                  SizedBox(height: responsive.spacing(12)),
                  Row(
                    children: [
                      Icon(
                        Icons.access_time,
                        size: responsive.getValue(
                          phone: 14.0,
                          tablet: 16.0,
                          desktop: 18.0,
                        ),
                        color: AppColors.textSecondary,
                      ),
                      const SizedBox(width: 6),
                      Expanded(
                        child: Text(
                          article.formattedDate,
                          style: TextStyle(
                            fontSize: responsive.caption,
                            color: AppColors.textSecondary,
                          ),
                        ),
                      ),
                      Icon(
                        Icons.arrow_forward_ios,
                        size: responsive.getValue(
                          phone: 14.0,
                          tablet: 16.0,
                          desktop: 18.0,
                        ),
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
