import 'package:flutter/material.dart';
import '../models/article.dart';
import '../models/category.dart';
import '../services/news_service.dart';
import '../core/theme/app_colors.dart';
import 'article_detail_screen.dart';

/// Pantalla que muestra una lista de artículos de noticias
/// Puede mostrar todas las noticias o filtradas por categoría
/// Implementa carga paginada con infinite scroll
class NewsListScreen extends StatefulWidget {
  // Categoría opcional para filtrar artículos
  // Si es null, muestra todas las noticias
  final Category? category;

  const NewsListScreen({super.key, this.category});

  @override
  State<NewsListScreen> createState() => _NewsListScreenState();
}

class _NewsListScreenState extends State<NewsListScreen> {
  // Servicio para obtener artículos desde la API
  final NewsService _newsService = NewsService();

  // Controlador para detectar el scroll y cargar más artículos
  final ScrollController _scrollController = ScrollController();

  // Lista de artículos cargados
  List<Article> _articles = [];

  // Indica si se está cargando la primera página
  bool _isLoading = true;

  // Indica si se están cargando más artículos (paginación)
  bool _isLoadingMore = false;

  // Almacena el mensaje de error si ocurre algún problema
  String? _error;

  // Página actual para la paginación
  int _currentPage = 1;

  // Indica si hay más artículos para cargar
  bool _hasMore = true;

  @override
  void initState() {
    super.initState();
    // Cargar artículos iniciales
    _loadArticles();
    // Escuchar eventos de scroll para infinite scroll
    _scrollController.addListener(_onScroll);
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  /// Detecta cuando el usuario hace scroll cerca del final de la lista
  /// Carga más artículos automáticamente (infinite scroll)
  void _onScroll() {
    // Cargar más cuando esté al 80% del scroll
    if (_scrollController.position.pixels >=
            _scrollController.position.maxScrollExtent * 0.8 &&
        !_isLoadingMore &&
        _hasMore) {
      _loadMoreArticles();
    }
  }

  /// Carga la primera página de artículos
  /// Puede cargar todos los artículos o filtrados por categoría
  Future<void> _loadArticles() async {
    try {
      setState(() {
        _isLoading = true;
        _error = null;
        _currentPage = 1;
        _hasMore = true;
      });

      // Cargar artículos según si hay categoría seleccionada o no
      final articles = widget.category != null
          ? await _newsService.getArticlesByCategory(widget.category!.id)
          : await _newsService.getArticles();

      if (mounted) {
        setState(() {
          _articles = articles;
          _isLoading = false;
          // Si vienen menos de 20 artículos, no hay más páginas
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

  /// Carga la siguiente página de artículos (paginación)
  /// Se activa automáticamente cuando el usuario hace scroll hacia abajo
  Future<void> _loadMoreArticles() async {
    // Evitar múltiples cargas simultáneas
    if (_isLoadingMore || !_hasMore) return;

    setState(() {
      _isLoadingMore = true;
    });

    try {
      _currentPage++;

      // Cargar siguiente página según categoría
      final newArticles = widget.category != null
          ? await _newsService.getArticlesByCategory(
              widget.category!.id,
              page: _currentPage,
            )
          : await _newsService.getArticles(page: _currentPage);

      if (mounted) {
        setState(() {
          // Agregar nuevos artículos a la lista existente
          _articles.addAll(newArticles);
          _isLoadingMore = false;
          // Si vienen menos de 20, no hay más páginas
          _hasMore = newArticles.length >= 20;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoadingMore = false;
          // Revertir el incremento de página en caso de error
          _currentPage--;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    // Obtener dimensiones para diseño responsivo
    final screenSize = MediaQuery.of(context).size;
    final isTablet = screenSize.shortestSide >= 600;
    final padding = isTablet ? 20.0 : 16.0;

    return Scaffold(
      appBar: AppBar(
        // Mostrar nombre de categoría o "Todas las noticias"
        title: Text(widget.category?.name ?? 'Todas las noticias'),
        centerTitle: true,
      ),
      body: _isLoading
          // ===== ESTADO DE CARGA INICIAL =====
          ? const Center(child: CircularProgressIndicator())
          : _error != null
          // ===== ESTADO DE ERROR =====
          ? Center(
              child: Padding(
                padding: const EdgeInsets.all(24.0),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    // Icono de error
                    Icon(
                      Icons.error_outline,
                      size: isTablet ? 80 : 64,
                      color: Colors.red.shade300,
                    ),
                    SizedBox(height: isTablet ? 24 : 16),

                    // Mensaje de error
                    Text(
                      _error!,
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: isTablet ? 18 : 16,
                        color: AppColors.textSecondary,
                      ),
                    ),
                    SizedBox(height: isTablet ? 24 : 16),

                    // Botón para reintentar
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
          // ===== ESTADO VACÍO =====
          ? Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.article_outlined,
                    size: isTablet ? 80 : 64,
                    color: AppColors.textSecondary.withValues(alpha: 0.5),
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
          // ===== LISTA DE ARTÍCULOS =====
          : RefreshIndicator(
              // Pull-to-refresh para recargar artículos
              onRefresh: _loadArticles,
              child: ListView.builder(
                controller: _scrollController,
                padding: EdgeInsets.all(padding),
                // +1 item para mostrar indicador de carga al final
                itemCount: _articles.length + (_isLoadingMore ? 1 : 0),
                itemBuilder: (context, index) {
                  // Mostrar indicador de carga al final de la lista
                  if (index == _articles.length) {
                    return const Center(
                      child: Padding(
                        padding: EdgeInsets.all(16.0),
                        child: CircularProgressIndicator(),
                      ),
                    );
                  }
                  // Mostrar tarjeta de artículo
                  return _buildArticleCard(_articles[index], isTablet);
                },
              ),
            ),
    );
  }

  /// Construye una tarjeta individual para cada artículo
  /// Muestra título, fecha y permite navegar al detalle
  ///
  /// [article] - El artículo a mostrar
  /// [isTablet] - Indica si el dispositivo es una tablet para ajustar tamaños
  Widget _buildArticleCard(Article article, bool isTablet) {
    return Card(
      margin: EdgeInsets.only(bottom: isTablet ? 16 : 12),
      elevation: 2,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(isTablet ? 16 : 12),
      ),
      child: InkWell(
        // Navegar al detalle del artículo al tocar
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
              // ===== TÍTULO DEL ARTÍCULO =====
              Text(
                article.title,
                style: TextStyle(
                  fontSize: isTablet ? 18 : 16,
                  fontWeight: FontWeight.bold,
                  color: AppColors.textPrimary,
                  height: 1.3,
                ),
                maxLines: 3, // Máximo 3 líneas
                overflow:
                    TextOverflow.ellipsis, // Agregar "..." si es muy largo
              ),
              SizedBox(height: isTablet ? 12 : 8),

              // ===== FECHA Y FLECHA =====
              Row(
                children: [
                  // Icono de reloj
                  Icon(
                    Icons.access_time,
                    size: isTablet ? 16 : 14,
                    color: AppColors.textSecondary,
                  ),
                  SizedBox(width: isTablet ? 6 : 4),

                  // Fecha formateada
                  Expanded(
                    child: Text(
                      article.formattedDate,
                      style: TextStyle(
                        fontSize: isTablet ? 13 : 11,
                        color: AppColors.textSecondary,
                      ),
                    ),
                  ),

                  // Flecha indicadora de navegación
                  Icon(
                    Icons.arrow_forward_ios,
                    size: isTablet ? 16 : 14,
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
