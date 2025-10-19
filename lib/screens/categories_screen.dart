import 'package:flutter/material.dart';
import '../services/audio_player_manager.dart';
import '../services/news_service.dart';
import '../models/article.dart';
import '../models/category.dart';
import '../widgets/mini_player.dart';
import '../widgets/live_indicator.dart';
import '../core/theme/app_colors.dart';
import 'article_detail_screen.dart';
import '../utils/responsive_helper.dart';

/// Pantalla principal de noticias mejorada
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

  // Estado de noticias
  List<Article> _articles = [];
  bool _isLoadingNews = true;
  int _newsPage = 1;
  bool _hasMoreNews = true;
  bool _isLoadingMoreNews = false;
  final ScrollController _newsScrollController = ScrollController();

  // Estado de categorías
  List<Category> _categories = [];
  bool _isLoadingCategories = true;

  bool _isPlaying = false;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _loadArticles();
    _loadCategories();
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

    final padding = responsive.getValue(
      phone: 16.0,
      largePhone: 18.0,
      tablet: 24.0,
      desktop: 32.0,
    );

    final bottomPadding = _isPlaying
        ? responsive.getValue(phone: 100.0, tablet: 120.0, desktop: 140.0)
        : padding;

    // Grid layout para tablets y desktop
    if (responsive.gridColumns > 1) {
      return RefreshIndicator(
        onRefresh: _loadArticles,
        color: AppColors.primary,
        child: Center(
          child: ConstrainedBox(
            constraints: BoxConstraints(maxWidth: responsive.maxContentWidth),
            child: GridView.builder(
              controller: _newsScrollController,
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
                childAspectRatio: 0.75,
              ),
              itemCount: _articles.length + (_isLoadingMoreNews ? 1 : 0),
              itemBuilder: (context, index) {
                if (index == _articles.length) {
                  return Center(
                    child: CircularProgressIndicator(color: AppColors.primary),
                  );
                }
                return _buildArticleCard(_articles[index], responsive);
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
        controller: _newsScrollController,
        padding: EdgeInsets.only(
          top: padding,
          left: padding,
          right: padding,
          bottom: bottomPadding,
        ),
        itemCount: _articles.length + (_isLoadingMoreNews ? 1 : 0),
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

    final padding = responsive.getValue(
      phone: 16.0,
      largePhone: 18.0,
      tablet: 24.0,
      desktop: 32.0,
    );

    final bottomPadding = _isPlaying
        ? responsive.getValue(phone: 100.0, tablet: 120.0, desktop: 140.0)
        : padding;

    // Grid para tablets/desktop
    if (responsive.gridColumns > 1) {
      return RefreshIndicator(
        onRefresh: _loadCategories,
        color: AppColors.primary,
        child: Center(
          child: ConstrainedBox(
            constraints: BoxConstraints(maxWidth: responsive.maxContentWidth),
            child: GridView.builder(
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
                childAspectRatio: 3,
              ),
              itemCount: _categories.length,
              itemBuilder: (context, index) =>
                  _buildCategoryCard(_categories[index], responsive),
            ),
          ),
        ),
      );
    }

    // Lista para móviles
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
              fontSize: responsive.bodyText,
              color: AppColors.textSecondary,
            ),
          ),
        ],
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
      phone: 180.0,
      largePhone: 200.0,
      tablet: 220.0,
      desktop: 240.0,
    );

    return Card(
      color: AppColors.cardBackground,
      elevation: responsive.getValue(phone: 4.0, tablet: 6.0),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(borderRadius),
      ),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: () {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => ArticleDetailScreen(article: article),
            ),
          );
        },
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Imagen
            _buildArticleImage(article, responsive, imageHeight, borderRadius),

            // Contenido
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
                          phone: 16.0,
                          tablet: 18.0,
                          desktop: 20.0,
                        ),
                        color: AppColors.textSecondary,
                      ),
                      SizedBox(width: 6),
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
                          phone: 16.0,
                          tablet: 18.0,
                          desktop: 20.0,
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

  Widget _buildArticleImage(
    Article article,
    ResponsiveHelper responsive,
    double height,
    double borderRadius,
  ) {
    if (article.imageUrl != null) {
      return Image.network(
        article.imageUrl!,
        height: height,
        width: double.infinity,
        fit: BoxFit.cover,
        loadingBuilder: (context, child, loadingProgress) {
          if (loadingProgress == null) return child;
          return Container(
            height: height,
            color: AppColors.primary.withValues(alpha: 0.1),
            child: Center(
              child: CircularProgressIndicator(
                color: AppColors.primary,
                strokeWidth: 2,
              ),
            ),
          );
        },
        errorBuilder: (context, error, stackTrace) {
          return Container(
            height: height,
            color: AppColors.primary.withValues(alpha: 0.1),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  Icons.image_not_supported,
                  size: responsive.getValue(phone: 40.0, tablet: 48.0),
                  color: AppColors.textSecondary.withValues(alpha: 0.5),
                ),
                SizedBox(height: 8),
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
      );
    }

    return Container(
      height: height,
      color: AppColors.primary.withValues(alpha: 0.1),
      child: Center(
        child: Icon(
          Icons.article,
          size: responsive.getValue(phone: 50.0, tablet: 60.0, desktop: 70.0),
          color: AppColors.primary.withValues(alpha: 0.3),
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
        onTap: () {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => CategoryNewsScreen(
                category: category,
                audioManager: widget.audioManager,
              ),
            ),
          );
        },
        child: Padding(
          padding: EdgeInsets.all(padding),
          child: Row(
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(borderRadius * 0.7),
                child: _buildCategoryImage(category, responsive, imageSize),
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
                    SizedBox(height: 4),
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
                size: responsive.getValue(
                  phone: 18.0,
                  tablet: 20.0,
                  desktop: 22.0,
                ),
                color: AppColors.primary,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildCategoryImage(
    Category category,
    ResponsiveHelper responsive,
    double size,
  ) {
    if (category.imageUrl != null) {
      return Image.network(
        category.imageUrl!,
        width: size,
        height: size,
        fit: BoxFit.cover,
        loadingBuilder: (context, child, loadingProgress) {
          if (loadingProgress == null) return child;
          return Container(
            width: size,
            height: size,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  AppColors.primary.withValues(alpha: 0.2),
                  AppColors.primary.withValues(alpha: 0.05),
                ],
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
        errorBuilder: (context, error, stackTrace) {
          return Container(
            width: size,
            height: size,
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
              size: size * 0.5,
            ),
          );
        },
      );
    }

    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            AppColors.primary.withValues(alpha: 0.2),
            AppColors.primary.withValues(alpha: 0.05),
          ],
        ),
      ),
      child: Icon(Icons.label, color: AppColors.primary, size: size * 0.5),
    );
  }
}

/// Pantalla de artículos por categoría (se mantiene igual pero con responsive helper)
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
        _showErrorSnackBar('Error al cargar artículos');
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
              size: responsive.getValue(
                phone: 64.0,
                tablet: 80.0,
                desktop: 96.0,
              ),
              color: AppColors.textSecondary.withValues(alpha: 0.5),
            ),
            SizedBox(height: responsive.spacing(24)),
            Text(
              'No hay artículos en esta categoría',
              style: TextStyle(
                fontSize: responsive.bodyText,
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

    // Grid para tablets/desktop
    if (responsive.gridColumns > 1) {
      return RefreshIndicator(
        onRefresh: _loadArticles,
        color: AppColors.primary,
        child: Center(
          child: ConstrainedBox(
            constraints: BoxConstraints(maxWidth: responsive.maxContentWidth),
            child: GridView.builder(
              controller: _scrollController,
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
                childAspectRatio: 0.75,
              ),
              itemCount: _articles.length + (_isLoadingMore ? 1 : 0),
              itemBuilder: (context, index) {
                if (index == _articles.length) {
                  return Center(
                    child: CircularProgressIndicator(color: AppColors.primary),
                  );
                }
                return _buildArticleCard(_articles[index], responsive);
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
        onTap: () {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => ArticleDetailScreen(article: article),
            ),
          );
        },
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Imagen
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
                errorBuilder: (context, error, stackTrace) {
                  return Container(
                    height: imageHeight,
                    color: AppColors.primary.withValues(alpha: 0.1),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.image_not_supported,
                          size: responsive.getValue(phone: 40.0, tablet: 48.0),
                          color: AppColors.textSecondary.withValues(alpha: 0.5),
                        ),
                        SizedBox(height: 8),
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
              )
            else
              Container(
                height: imageHeight,
                color: AppColors.primary.withValues(alpha: 0.1),
                child: Center(
                  child: Icon(
                    Icons.article,
                    size: responsive.getValue(
                      phone: 50.0,
                      tablet: 60.0,
                      desktop: 70.0,
                    ),
                    color: AppColors.primary.withValues(alpha: 0.3),
                  ),
                ),
              ),

            // Contenido
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
                          phone: 16.0,
                          tablet: 18.0,
                          desktop: 20.0,
                        ),
                        color: AppColors.textSecondary,
                      ),
                      SizedBox(width: 6),
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
                          phone: 16.0,
                          tablet: 18.0,
                          desktop: 20.0,
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
