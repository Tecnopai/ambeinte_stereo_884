import 'package:flutter/material.dart';
import 'package:firebase_analytics/firebase_analytics.dart';
import '../models/article.dart';
import '../models/category.dart';
import '../services/news_service.dart';
import '../core/theme/app_colors.dart';
import 'article_detail_screen.dart';
import '../utils/responsive_helper.dart';

/// Pantalla mejorada de lista de artículos con responsive design
class NewsListScreen extends StatefulWidget {
  final Category? category;

  const NewsListScreen({super.key, this.category});

  @override
  State<NewsListScreen> createState() => _NewsListScreenState();
}

class _NewsListScreenState extends State<NewsListScreen> {
  final NewsService _newsService = NewsService();
  final ScrollController _scrollController = ScrollController();
  final analytics = FirebaseAnalytics.instance; // ✅ AGREGADO

  List<Article> _articles = [];
  bool _isLoading = true;
  bool _isLoadingMore = false;
  String? _error;
  int _currentPage = 1;
  bool _hasMore = true;

  @override
  void initState() {
    super.initState();

    // Registrar vista de pantalla
    analytics.logScreenView(
      screenName: 'news_list',
      screenClass: 'NewsListScreen',
    );

    _loadArticles();
    _scrollController.addListener(_onScroll);
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
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
        _error = null;
        _currentPage = 1;
        _hasMore = true;
      });

      final articles = widget.category != null
          ? await _newsService.getArticlesByCategory(widget.category!.id)
          : await _newsService.getArticles();

      if (mounted) {
        setState(() {
          _articles = articles;
          _isLoading = false;
          _hasMore = articles.length >= 20;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = 'Error al cargar artículos';
          _isLoading = false;
        });
      }
    }
  }

  Future<void> _loadMoreArticles() async {
    if (_isLoadingMore || !_hasMore) return;

    setState(() => _isLoadingMore = true);

    try {
      _currentPage++;

      final newArticles = widget.category != null
          ? await _newsService.getArticlesByCategory(
              widget.category!.id,
              page: _currentPage,
            )
          : await _newsService.getArticles(page: _currentPage);

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
        title: Text(
          widget.category?.name ?? 'Todas las noticias',
          style: TextStyle(fontSize: responsive.h2),
        ),
        centerTitle: true,
      ),
      body: _buildBody(responsive),
    );
  }

  Widget _buildBody(ResponsiveHelper responsive) {
    if (_isLoading) {
      return _buildLoadingState(responsive);
    }

    if (_error != null) {
      return _buildErrorState(responsive);
    }

    if (_articles.isEmpty) {
      return _buildEmptyState(responsive);
    }

    return _buildArticlesList(responsive);
  }

  Widget _buildLoadingState(ResponsiveHelper responsive) {
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

  Widget _buildErrorState(ResponsiveHelper responsive) {
    final iconSize = responsive.getValue(
      phone: 64.0,
      largePhone: 70.0,
      tablet: 80.0,
      desktop: 96.0,
    );

    return Center(
      child: Padding(
        padding: EdgeInsets.all(responsive.spacing(24)),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.error_outline,
              size: iconSize,
              color: Colors.red.shade300,
            ),
            SizedBox(height: responsive.spacing(24)),
            Text(
              _error!,
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: responsive.h3,
                color: AppColors.textSecondary,
              ),
            ),
            SizedBox(height: responsive.spacing(24)),
            ElevatedButton.icon(
              onPressed: _loadArticles,
              icon: Icon(
                Icons.refresh,
                size: responsive.getValue(phone: 20.0, tablet: 24.0),
              ),
              label: Text(
                'Reintentar',
                style: TextStyle(fontSize: responsive.bodyText),
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primary,
                foregroundColor: Colors.white,
                padding: EdgeInsets.symmetric(
                  horizontal: responsive.getValue(
                    phone: 24.0,
                    largePhone: 28.0,
                    tablet: 32.0,
                    desktop: 40.0,
                  ),
                  vertical: responsive.getValue(
                    phone: 12.0,
                    largePhone: 14.0,
                    tablet: 16.0,
                    desktop: 20.0,
                  ),
                ),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(
                    responsive.getValue(
                      phone: 8.0,
                      tablet: 12.0,
                      desktop: 16.0,
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEmptyState(ResponsiveHelper responsive) {
    final iconSize = responsive.getValue(
      phone: 64.0,
      largePhone: 70.0,
      tablet: 80.0,
      desktop: 96.0,
    );

    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.article_outlined,
            size: iconSize,
            color: AppColors.textSecondary.withValues(alpha: 0.5),
          ),
          SizedBox(height: responsive.spacing(24)),
          Text(
            'No hay artículos disponibles',
            style: TextStyle(
              fontSize: responsive.h3,
              color: AppColors.textSecondary,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildArticlesList(ResponsiveHelper responsive) {
    final padding = responsive.getValue(
      smallPhone: 12.0,
      phone: 16.0,
      largePhone: 18.0,
      tablet: 24.0,
      desktop: 32.0,
      automotive: 20.0,
    );

    // Grid layout para tablets y desktop
    if (responsive.gridColumns > 1) {
      return RefreshIndicator(
        onRefresh: _loadArticles,
        color: AppColors.primary,
        child: Center(
          child: ConstrainedBox(
            constraints: BoxConstraints(maxWidth: responsive.maxContentWidth),
            child: GridView.builder(
              controller: _scrollController,
              padding: EdgeInsets.all(padding),
              gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: responsive.gridColumns,
                crossAxisSpacing: padding,
                mainAxisSpacing: padding,
                childAspectRatio: responsive.getValue(
                  phone: 3.0,
                  tablet: 3.0,
                  desktop: 3.5,
                  automotive: 3.0,
                ),
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
        padding: EdgeInsets.all(padding),
        itemCount: _articles.length + (_isLoadingMore ? 1 : 0),
        itemBuilder: (context, index) {
          if (index == _articles.length) {
            return Center(
              child: Padding(
                padding: EdgeInsets.all(responsive.spacing(16)),
                child: CircularProgressIndicator(color: AppColors.primary),
              ),
            );
          }
          return Padding(
            padding: EdgeInsets.only(
              bottom: responsive.getValue(
                phone: 12.0,
                largePhone: 14.0,
                tablet: 16.0,
              ),
            ),
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
      phone: 14.0,
      largePhone: 16.0,
      tablet: 18.0,
      desktop: 20.0,
    );

    final elevation = responsive.getValue(
      phone: 2.0,
      tablet: 4.0,
      desktop: 6.0,
    );

    return Card(
      color: AppColors.cardBackground,
      elevation: elevation,
      shadowColor: Colors.black.withValues(alpha: 0.1),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(borderRadius),
      ),
      child: InkWell(
        onTap: () {
          // Registrar evento antes de navegar
          analytics.logEvent(
            name: 'article_open',
            parameters: {
              'article_id': article.id,
              'article_title': article.title,
            },
          );

          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => ArticleDetailScreen(article: article),
            ),
          );
        },
        borderRadius: BorderRadius.circular(borderRadius),
        child: Padding(
          padding: EdgeInsets.all(padding),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              // Título
              Text(
                article.title,
                style: TextStyle(
                  fontSize: responsive.h3,
                  fontWeight: FontWeight.bold,
                  color: AppColors.textPrimary,
                  height: 1.3,
                ),
                maxLines: responsive.getValue(
                  phone: 3,
                  tablet: 2,
                  automotive: 2,
                ),
                overflow: TextOverflow.ellipsis,
              ),

              SizedBox(height: responsive.spacing(12)),

              // Fecha y flecha
              Row(
                children: [
                  Icon(
                    Icons.access_time,
                    size: responsive.getValue(
                      phone: 14.0,
                      largePhone: 15.0,
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
                      largePhone: 15.0,
                      tablet: 16.0,
                      desktop: 18.0,
                    ),
                    color: AppColors.textSecondary.withValues(alpha: 0.5),
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
