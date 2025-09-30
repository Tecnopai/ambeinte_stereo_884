import 'package:flutter/material.dart';
import '../models/article.dart';
import '../models/category.dart';
import '../services/news_service.dart';
import '../core/theme/app_colors.dart';
import 'article_detail_screen.dart';

class NewsListScreen extends StatefulWidget {
  final Category? category;

  const NewsListScreen({super.key, this.category});

  @override
  State<NewsListScreen> createState() => _NewsListScreenState();
}

class _NewsListScreenState extends State<NewsListScreen> {
  final NewsService _newsService = NewsService();
  final ScrollController _scrollController = ScrollController();
  List<Article> _articles = [];
  bool _isLoading = true;
  bool _isLoadingMore = false;
  String? _error;
  int _currentPage = 1;
  bool _hasMore = true;

  @override
  void initState() {
    super.initState();
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

    setState(() {
      _isLoadingMore = true;
    });

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
    final screenSize = MediaQuery.of(context).size;
    final isTablet = screenSize.shortestSide >= 600;
    final padding = isTablet ? 20.0 : 16.0;

    return Scaffold(
      appBar: AppBar(
        title: Text(widget.category?.name ?? 'Todas las noticias'),
        centerTitle: true,
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
          ? Center(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                Icons.error_outline,
                size: isTablet ? 80 : 64,
                color: Colors.red.shade300,
              ),
              SizedBox(height: isTablet ? 24 : 16),
              Text(
                _error!,
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: isTablet ? 18 : 16,
                  color: AppColors.textSecondary,
                ),
              ),
              SizedBox(height: isTablet ? 24 : 16),
              ElevatedButton.icon(
                onPressed: _loadArticles,
                icon: const Icon(Icons.refresh),
                label: const Text('Reintentar'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  foregroundColor: Colors.white,
                  padding: EdgeInsets.symmetric(
                    horizontal: isTablet ? 32 : 24,
                    vertical: isTablet ? 16 : 12,
                  ),
                ),
              ),
            ],
          ),
        ),
      )
          : _articles.isEmpty
          ? Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.article_outlined,
              size: isTablet ? 80 : 64,
              color: AppColors.textSecondary.withOpacity(0.5),
            ),
            SizedBox(height: isTablet ? 24 : 16),
            Text(
              'No hay artículos disponibles',
              style: TextStyle(
                fontSize: isTablet ? 18 : 16,
                color: AppColors.textSecondary,
              ),
            ),
          ],
        ),
      )
          : RefreshIndicator(
        onRefresh: _loadArticles,
        child: ListView.builder(
          controller: _scrollController,
          padding: EdgeInsets.all(padding),
          itemCount:
          _articles.length + (_isLoadingMore ? 1 : 0),
          itemBuilder: (context, index) {
            if (index == _articles.length) {
              return const Center(
                child: Padding(
                  padding: EdgeInsets.all(16.0),
                  child: CircularProgressIndicator(),
                ),
              );
            }
            return _buildArticleCard(
                _articles[index], isTablet);
          },
        ),
      ),
    );
  }

  Widget _buildArticleCard(Article article, bool isTablet) {
    return Card(
      margin: EdgeInsets.only(bottom: isTablet ? 16 : 12),
      elevation: 2,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(isTablet ? 16 : 12),
      ),
      child: InkWell(
        onTap: () {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => ArticleDetailScreen(article: article),
            ),
          );
        },
        borderRadius: BorderRadius.circular(isTablet ? 16 : 12),
        child: Padding(
          padding: EdgeInsets.all(isTablet ? 18 : 14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                article.title,
                style: TextStyle(
                  fontSize: isTablet ? 18 : 16,
                  fontWeight: FontWeight.bold,
                  color: AppColors.textPrimary,
                  height: 1.3,
                ),
                maxLines: 3,
                overflow: TextOverflow.ellipsis,
              ),
              SizedBox(height: isTablet ? 12 : 8),
              Row(
                children: [
                  Icon(
                    Icons.access_time,
                    size: isTablet ? 16 : 14,
                    color: AppColors.textSecondary,
                  ),
                  SizedBox(width: isTablet ? 6 : 4),
                  Expanded(
                    child: Text(
                      article.formattedDate,
                      style: TextStyle(
                        fontSize: isTablet ? 13 : 11,
                        color: AppColors.textSecondary,
                      ),
                    ),
                  ),
                  Icon(
                    Icons.arrow_forward_ios,
                    size: isTablet ? 16 : 14,
                    color: AppColors.textSecondary.withOpacity(0.5),
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