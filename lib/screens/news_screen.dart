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
// Se omite la importación de 'news_list_screen.dart' ya que CategoryNewsScreen está en este archivo.

/// Pantalla principal de noticias mejorada con Radio Hits
///
/// Implementa la vista principal de la aplicación, organizada en pestañas,
/// y gestiona el estado de reproducción de audio en vivo.
class NewsScreen extends StatefulWidget {
  /// Constructor de NewsScreen.
  const NewsScreen({super.key});

  @override
  State<NewsScreen> createState() => _NewsScreenState();
}

/// Estado y lógica de la pantalla principal de noticias y rankings.
class _NewsScreenState extends State<NewsScreen>
    with SingleTickerProviderStateMixin {
  /// Controlador para gestionar las pestañas (Todas, Categorías, Radio Hits).
  late TabController _tabController;

  /// Servicio para la obtención de datos de noticias.
  final NewsService _newsService = NewsService();

  /// Manager para controlar la reproducción de audio (Singleton).
  late final AudioPlayerManager _audioManager;

  /// Servicio para la obtención de datos del ranking musical.
  final RadioHitsService _radioHitsService = RadioHitsService();

  // --- Estado de la pestaña 'Todas' (Noticias) ---
  /// Lista de artículos a mostrar.
  List<Article> _articles = [];

  /// Indicador de si la carga inicial de noticias está en curso.
  bool _isLoadingNews = true;

  /// Página actual de noticias cargada (para paginación/scroll infinito).
  int _newsPage = 1;

  /// Indica si hay más artículos disponibles para cargar.
  bool _hasMoreNews = true;

  /// Indicador de si la carga de la siguiente página está en curso.
  bool _isLoadingMoreNews = false;

  /// Controlador para detectar eventos de scroll y disparar la carga infinita.
  final ScrollController _newsScrollController = ScrollController();

  // --- Estado de la pestaña 'Categorías' ---
  /// Lista de categorías disponibles.
  List<Category> _categories = [];

  /// Indicador de si la carga inicial de categorías está en curso.
  bool _isLoadingCategories = true;

  // --- Estado de la pestaña 'Radio Hits' ---
  /// Lista de canciones del ranking.
  List<RadioHit> _radioHits = [];

  /// Indicador de si la carga inicial de Radio Hits está en curso.
  bool _isLoadingRadioHits = true;

  // --- Estado del Audio en Vivo ---
  /// Indica si el audio en vivo se está reproduciendo actualmente.
  bool _isPlaying = false;

  /// Inicializa el controlador de pestañas, el manager de audio y los listeners.
  @override
  void initState() {
    super.initState();
    _audioManager = AudioPlayerManager();
    _tabController = TabController(length: 3, vsync: this);
    _loadArticles();
    _loadCategories();
    _loadRadioHits();
    _setupAudioListener();
    _newsScrollController.addListener(_onNewsScroll);
  }

  /// Limpia los controladores para evitar fugas de memoria.
  @override
  void dispose() {
    _tabController.dispose();
    _newsScrollController.dispose();
    super.dispose();
  }

  /// Configura el listener para actualizar el estado del MiniPlayer.
  void _setupAudioListener() {
    _audioManager.playingStream.listen((isPlaying) {
      if (mounted) setState(() => _isPlaying = isPlaying);
    });
    _isPlaying = _audioManager.isPlaying;
  }

  /// Maneja el evento de scroll para cargar más noticias cuando se acerca al final.
  void _onNewsScroll() {
    // Carga si el usuario ha scrollado el 80% del contenido y hay más por cargar.
    if (_newsScrollController.position.pixels >=
            _newsScrollController.position.maxScrollExtent * 0.8 &&
        !_isLoadingMoreNews &&
        _hasMoreNews) {
      _loadMoreNews();
    }
  }

  /// Carga la primera página de artículos de noticias.
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
          // Asume que si devuelve 20 artículos, puede haber otra página.
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

  /// Carga la siguiente página de artículos para el scroll infinito.
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
      // Revertir la paginación en caso de error
      if (mounted) {
        setState(() {
          _isLoadingMoreNews = false;
          _newsPage--;
        });
      }
    }
  }

  /// Carga la lista de categorías.
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
      // Si falla, solo muestra el estado vacío o de carga terminada.
      if (mounted) setState(() => _isLoadingCategories = false);
    }
  }

  /// Carga el ranking de Radio Hits.
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

  /// Muestra una notificación de error en la parte inferior de la pantalla.
  void _showErrorSnackBar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: AppColors.error,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  /// Construye la interfaz principal con AppBar, TabBar y TabBarView.
  @override
  Widget build(BuildContext context) {
    final responsive = ResponsiveHelper(context);

    return Scaffold(
      appBar: AppBar(
        title: Row(
          children: [
            Text('Noticias', style: TextStyle(fontSize: responsive.h2)),
            // Muestra el indicador de "Live" si la radio está activa.
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
          // Vistas de las pestañas
          TabBarView(
            controller: _tabController,
            children: [
              _buildNewsTab(responsive),
              _buildCategoriesTab(responsive),
              _buildRadioHitsTab(responsive),
            ],
          ),
          // MiniPlayer flotante si la reproducción de audio está activa
          if (_isPlaying)
            Positioned(
              bottom: 16,
              left: 16,
              right: 16,
              child: MiniPlayer(audioManager: _audioManager),
            ),
        ],
      ),
    );
  }

  /// Lógica para construir la pestaña de noticias 'Todas'.
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

    // Retorna la lista de artículos con scroll infinito.
    return _buildArticlesList(
      responsive,
      _articles,
      _newsScrollController,
      _isLoadingMoreNews,
    );
  }

  /// Lógica para construir la pestaña 'Categorías'.
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

  /// Lógica para construir la pestaña 'Radio Hits'.
  Widget _buildRadioHitsTab(ResponsiveHelper responsive) {
    if (_isLoadingRadioHits) {
      return _buildLoadingState(responsive, 'Cargando Radio Hits...');
    }

    if (_radioHits.isEmpty) {
      // Muestra un estado de error con opción de reintento.
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
            onPressed: _loadRadioHits, // Llama a la función de recarga
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

  /// Widget genérico para el estado de carga (Loading).
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

  /// Widget genérico para el estado vacío (Empty State).
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

  /// Construye la lista principal de artículos, alternando entre lista y grid.
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

    // Ajuste de padding para dejar espacio al MiniPlayer en la parte inferior.
    final bottomPadding = _isPlaying
        ? responsive.getValue(phone: 100.0, tablet: 120.0, desktop: 140.0)
        : padding;

    // Si hay más de una columna (tablet/desktop), usa GridView.
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
                // Proporción ajustada (altura/ancho) para prevenir overflow en el texto.
                childAspectRatio: 0.72,
              ),
              itemCount: articles.length + (isLoadingMore ? 1 : 0),
              itemBuilder: (context, index) {
                // Indicador de carga al final de la lista
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

    // Por defecto (móvil), usa ListView.
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

  /// Construye la lista de tarjetas de categorías.
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
      // Se utiliza ListView para mostrar una lista vertical de categorías.
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

  /// Construye la lista de elementos del ranking Radio Hits.
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

  /// Construye la tarjeta de visualización de un artículo, adaptándose a Grid/List.
  Widget _buildArticleCard(
    Article article,
    ResponsiveHelper responsive, {
    required bool isGrid,
  }) {
    // Detectar orientación para ajustes finos en Grid
    final isLandscape =
        MediaQuery.of(context).orientation == Orientation.landscape;

    final borderRadius = responsive.getValue(
      phone: 12.0,
      largePhone: 14.0,
      tablet: 16.0,
      desktop: 18.0,
    );

    // Ajuste de padding: reducido en Grid para optimizar espacio.
    final padding = isGrid
        ? responsive.getValue(
            phone: 12.0,
            largePhone: 12.0,
            tablet: isLandscape ? 8.0 : 10.0,
            desktop: 12.0,
          )
        : responsive.getValue(
            phone: 12.0,
            largePhone: 14.0,
            tablet: 16.0,
            desktop: 18.0,
          );

    // Altura de la imagen en modo lista (ListView). Ignorada en Grid (Expanded).
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
        // Navegación al detalle del artículo.
        onTap: () => Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => ArticleDetailScreen(
              article: article,
              audioManager: _audioManager, // Inyecta el manager de audio
            ),
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // 1. Imagen - Usa Expanded para control de espacio en Grid.
            Expanded(
              // Mayor proporción de imagen en Grid
              flex: isGrid ? (isLandscape ? 7 : 6) : 0,
              child: article.imageUrl != null
                  ? Image.network(
                      article.imageUrl!,
                      // Usa altura fija solo en modo lista (no Grid)
                      height: isGrid ? null : imageHeight,
                      width: double.infinity,
                      fit: BoxFit.cover,
                      // Indicador de carga
                      loadingBuilder: (context, child, loadingProgress) {
                        if (loadingProgress == null) return child;
                        return Container(
                          height: isGrid ? null : imageHeight,
                          color: AppColors.primary.withValues(alpha: 0.1),
                          child: Center(
                            child: CircularProgressIndicator(
                              color: AppColors.primary,
                              strokeWidth: 2,
                            ),
                          ),
                        );
                      },
                      // Placeholder de error
                      errorBuilder: (context, error, stackTrace) => Container(
                        height: isGrid ? null : imageHeight,
                        color: AppColors.primary.withValues(alpha: 0.1),
                        child: Icon(
                          Icons.image_not_supported,
                          size: responsive.getValue(phone: 40.0, tablet: 48.0),
                          color: AppColors.textSecondary.withValues(alpha: 0.5),
                        ),
                      ),
                    )
                  : Container(
                      // Placeholder si la URL es nula
                      height: isGrid ? null : imageHeight,
                      color: AppColors.primary.withValues(alpha: 0.1),
                      child: Icon(
                        Icons.article,
                        size: responsive.getValue(phone: 50.0, tablet: 60.0),
                        color: AppColors.primary.withValues(alpha: 0.3),
                      ),
                    ),
            ),

            // 2. Contenido de texto
            if (isGrid)
              // Layout para Grid (usa Expanded/Flexible para el texto)
              Expanded(
                flex: 4,
                child: Padding(
                  padding: EdgeInsets.all(padding),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      // Título (Flexible para evitar overflow)
                      Flexible(
                        child: Text(
                          article.title,
                          style: TextStyle(
                            fontSize: responsive.getValue(
                              phone: 14.0,
                              tablet: 13.0,
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

                      SizedBox(height: responsive.spacing(6)),

                      // Fecha de publicación
                      Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            Icons.access_time,
                            size: responsive.getValue(
                              phone: 12.0,
                              tablet: 11.0,
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
                                  tablet: 10.0,
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
              // Layout para Lista (usa Padding para el texto)
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

  /// Construye la tarjeta de visualización de una categoría.
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
        // Navegación a la pantalla de artículos filtrados por categoría.
        onTap: () => Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => CategoryNewsScreen(
              category: category,
              audioManager: _audioManager,
            ),
          ),
        ),
        child: Padding(
          padding: EdgeInsets.all(padding),
          child: Row(
            children: [
              // Imagen/Icono de la categoría
              ClipRRect(
                borderRadius: BorderRadius.circular(borderRadius * 0.7),
                child: category.imageUrl != null
                    ? Image.network(
                        category.imageUrl!,
                        width: imageSize,
                        height: imageSize,
                        fit: BoxFit.cover,
                        // Fallback en caso de error de imagen
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
                        // Fallback si no hay URL
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
              // Nombre y contador de artículos
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
              // Flecha de navegación
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

  /// Construye la tarjeta para un elemento del ranking Radio Hit.
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

    // Determina el color y el icono según el puesto en el ranking.
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
      elevation: responsive.getValue(phone: 4.0, tablet: 6.0),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(borderRadius),
      ),
      child: Padding(
        padding: EdgeInsets.all(padding),
        child: Row(
          children: [
            // Imagen del álbum con insignia de posición
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
                // Badge de posición numérica
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
            // Información de la canción/artista
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
            // Muestra el icono de medalla solo para los top 3
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

// -----------------------------------------------------------------------------
// --- PANTALLA SECUNDARIA: CategoryNewsScreen (Artículos por Categoría) ---
// -----------------------------------------------------------------------------

/// Pantalla que muestra artículos filtrados por una categoría específica.
///
/// Implementa scroll infinito para cargar más artículos dentro de la categoría.
class CategoryNewsScreen extends StatefulWidget {
  /// Categoría cuyos artículos se mostrarán.
  final Category category;

  /// Manager de audio inyectado para mantener el MiniPlayer.
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

  /// Controlador para el scroll infinito.
  final ScrollController _scrollController = ScrollController();

  /// Manager de audio (se accede como singleton dentro de la clase)
  final AudioPlayerManager _audioManager = AudioPlayerManager();

  /// Lista de artículos de la categoría.
  List<Article> _articles = [];

  /// Estado de carga inicial.
  bool _isLoading = true;

  /// Estado de carga de más artículos por scroll.
  bool _isLoadingMore = false;

  /// Estado de reproducción de audio.
  bool _isPlaying = false;

  /// Página actual de la paginación.
  int _currentPage = 1;

  /// Indica si hay más artículos en el servidor.
  bool _hasMore = true;

  /// Inicializa la carga de datos y los listeners.
  @override
  void initState() {
    super.initState();
    _loadArticles();
    _setupAudioListener();
    _scrollController.addListener(_onScroll);
  }

  /// Limpia el controlador de scroll al salir de la pantalla.
  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  /// Configura el listener para el estado de reproducción del MiniPlayer.
  void _setupAudioListener() {
    _audioManager.playingStream.listen((isPlaying) {
      if (mounted) setState(() => _isPlaying = isPlaying);
    });
    _isPlaying = _audioManager.isPlaying;
  }

  /// Detecta el scroll para cargar más artículos (similar a NewsScreen).
  void _onScroll() {
    if (_scrollController.position.pixels >=
            _scrollController.position.maxScrollExtent * 0.8 &&
        !_isLoadingMore &&
        _hasMore) {
      _loadMoreArticles();
    }
  }

  /// Carga la primera página de artículos filtrados por la categoría.
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

  /// Carga más artículos para el scroll infinito.
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

  /// Construye la interfaz de la pantalla de categoría.
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
            // Indicador de radio en vivo
            if (_isPlaying) const LiveIndicator(),
          ],
        ),
        centerTitle: false,
      ),
      body: Stack(
        children: [
          _buildContent(responsive),
          // MiniPlayer flotante
          if (_isPlaying)
            Positioned(
              bottom: 16,
              left: 16,
              right: 16,
              child: MiniPlayer(audioManager: _audioManager),
            ),
        ],
      ),
    );
  }

  /// Construye el contenido principal (Carga, Vacío o Lista de artículos).
  Widget _buildContent(ResponsiveHelper responsive) {
    if (_isLoading) {
      // Estado de carga
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
      // Estado vacío
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

    // Ajuste de padding inferior para el MiniPlayer
    final bottomPadding = _isPlaying
        ? responsive.getValue(phone: 100.0, tablet: 120.0, desktop: 140.0)
        : padding;

    // Lista de artículos con indicador de recarga (pull-to-refresh).
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
          // Indicador de carga al final de la lista.
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
            // Construye la tarjeta del artículo (solo modo lista).
            child: _buildArticleCard(_articles[index], responsive),
          );
        },
      ),
    );
  }

  /// Construye la tarjeta de visualización de un artículo (en modo lista para esta pantalla).
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
              audioManager: _audioManager,
            ),
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Imagen del artículo con placeholders y builders
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
              // Fallback si no hay imagen
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
                  // Título del artículo
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
                  // Extracto/resumen del artículo
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
                  // Fila de metadatos (fecha y flecha de navegación)
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
