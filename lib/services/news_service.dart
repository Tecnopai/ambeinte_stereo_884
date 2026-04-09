import 'dart:convert';
import 'dart:developer' as developer;
import 'package:http/http.dart' as http;
import '../models/article.dart';
import '../models/category.dart';
import '../core/constants/app_constants.dart';

/// Servicio para obtener noticias desde la API REST de WordPress
/// Maneja la comunicación con el servidor y el filtrado de contenido.
class NewsService {
  // URL base de la API de WordPress
  static const String _baseUrl =
      'https://ambientestereo.fm/sitio/wp-json/wp/v2';

  // Número de artículos por página para paginación y listas
  static const int _itemsPerPage = 20;

  // Timeout para las peticiones HTTP, para evitar esperas indefinidas
  static const Duration _timeout = Duration(seconds: 15);

  // Caché simple para evitar peticiones duplicadas de media
  static final Map<int, Map<String, dynamic>> _mediaCache = {};

  /// Filtra artículos para mostrar solo los de categorías permitidas.
  /// Verifica que el artículo tenga al menos una categoría incluida en
  /// [AppConstants.allowedCategoryIds].
  List<Article> _filterByAllowedCategories(List<Article> articles) {
    developer.log(
      '🔍 Filtrando ${articles.length} artículos',
      name: 'NewsService',
    );

    // Si no hay categorías permitidas configuradas, retornar todos
    if (AppConstants.allowedCategoryIds.isEmpty) {
      developer.log(
        '⚠️ No hay categorías permitidas configuradas - retornando todos los artículos',
        name: 'NewsService',
      );
      return articles;
    }

    final filtered = articles.where((article) {
      // Si el artículo no tiene categorías asociadas, es descartado.
      if (article.categories.isEmpty) {
        developer.log(
          '❌ Artículo ${article.id} sin categorías',
          name: 'NewsService',
        );
        return false;
      }

      // Retorna true si alguna de las categorías del artículo está en la lista permitida.
      final hasAllowed = article.categories.any(
        (categoryId) => AppConstants.allowedCategoryIds.contains(categoryId),
      );

      if (!hasAllowed) {
        developer.log(
          '❌ Artículo ${article.id} filtrado - categorías: ${article.categories}',
          name: 'NewsService',
        );
      }

      return hasAllowed;
    }).toList();

    developer.log(
      '✅ Filtrados: ${filtered.length}/${articles.length} artículos',
      name: 'NewsService',
    );

    return filtered;
  }

  /// Obtiene todas las categorías disponibles desde WordPress.
  /// Incluye el parámetro [_embed] para obtener imágenes asociadas y otros datos.
  /// Filtra categorías con contador cero (vacías) y las no permitidas.
  Future<List<Category>> getCategories() async {
    try {
      developer.log('📋 Obteniendo categorías...', name: 'NewsService');

      final uri = Uri.parse(
        '$_baseUrl/categories?per_page=100&hide_empty=true&_embed',
      );
      final response = await http.get(uri).timeout(_timeout);

      developer.log(
        '📋 Respuesta categorías: ${response.statusCode}',
        name: 'NewsService',
      );

      if (response.statusCode == 200) {
        final List<dynamic> data = json.decode(response.body);
        developer.log(
          '📋 Total categorías recibidas: ${data.length}',
          name: 'NewsService',
        );

        final categories = data
            .map((item) => Category.fromJson(item as Map<String, dynamic>))
            // 1. Filtrar categorías que no tienen artículos publicados (count > 0)
            .where((category) => category.count > 0)
            // 2. Filtrar categorías que no están en la lista de IDs permitidos
            .where(
              (category) =>
                  AppConstants.allowedCategoryIds.isEmpty ||
                  AppConstants.allowedCategoryIds.contains(category.id),
            )
            .toList();

        developer.log(
          '✅ Categorías filtradas: ${categories.length}',
          name: 'NewsService',
        );
        return categories;
      } else {
        throw Exception('Error al cargar categorías: ${response.statusCode}');
      }
    } catch (e) {
      developer.log('❌ Error: $e', name: 'NewsService', error: e);
      throw Exception('Error al conectar con el servidor: $e');
    }
  }

  /// Obtiene artículos filtrados por ID de categoría, con soporte para paginación.
  ///
  /// [categoryId] - ID de la categoría de WordPress para filtrar.
  /// [page] - Número de página para la paginación (por defecto 1).
  Future<List<Article>> getArticlesByCategory(
    int categoryId, {
    int page = 1,
  }) async {
    try {
      developer.log(
        '📰 Obteniendo artículos - Categoría: $categoryId, Página: $page',
        name: 'NewsService',
      );

      // Verificación de seguridad: si la categoría no está permitida, se ignora la petición.
      if (AppConstants.allowedCategoryIds.isNotEmpty &&
          !AppConstants.allowedCategoryIds.contains(categoryId)) {
        developer.log(
          '⚠️ Categoría $categoryId no permitida',
          name: 'NewsService',
        );
        return [];
      }

      // Primero obtenemos los artículos básicos sin _embed
      final uri = Uri.parse(
        '$_baseUrl/posts?categories=$categoryId&page=$page&per_page=$_itemsPerPage',
      );

      developer.log('🌐 URL: $uri', name: 'NewsService');
      final response = await http.get(uri).timeout(_timeout);

      developer.log(
        '📡 Respuesta: ${response.statusCode}',
        name: 'NewsService',
      );

      if (response.statusCode == 200) {
        final List<dynamic> data = json.decode(response.body);
        developer.log(
          '📦 Artículos recibidos: ${data.length}',
          name: 'NewsService',
        );

        // Enriquecer cada artículo con su imagen (en paralelo)
        final enrichedData = await _enrichArticlesDataParallel(data);

        final articles = enrichedData
            .map((item) => Article.fromJson(item))
            .toList();

        // Aplicar el filtro de categorías permitidas post-carga
        return _filterByAllowedCategories(articles);
      } else if (response.statusCode == 400) {
        developer.log('ℹ️ Página fuera de rango', name: 'NewsService');
        return [];
      } else {
        throw Exception('Error al cargar artículos: ${response.statusCode}');
      }
    } catch (e) {
      developer.log('❌ Error: $e', name: 'NewsService', error: e);
      throw Exception('Error al cargar artículos por categoría: $e');
    }
  }

  /// Obtiene la lista de todos los artículos recientes (todas las categorías permitidas).
  /// Soporta paginación.
  ///
  /// [page] - Número de página para la paginación (por defecto 1).
  Future<List<Article>> getArticles({int page = 1}) async {
    try {
      developer.log(
        '📰 Obteniendo todos los artículos - Página: $page',
        name: 'NewsService',
      );

      // Construir URL con filtro de categorías si está configurado
      String url = '$_baseUrl/posts?page=$page&per_page=$_itemsPerPage';

      // Si hay categorías permitidas, filtrar en la API
      if (AppConstants.allowedCategoryIds.isNotEmpty) {
        final categoryIds = AppConstants.allowedCategoryIds.join(',');
        url += '&categories=$categoryIds';
        developer.log(
          '🔖 Filtrando por categorías: $categoryIds',
          name: 'NewsService',
        );
      }

      final uri = Uri.parse(url);
      developer.log('🌐 URL: $uri', name: 'NewsService');

      final response = await http.get(uri).timeout(_timeout);

      developer.log(
        '📡 Respuesta: ${response.statusCode}',
        name: 'NewsService',
      );

      if (response.statusCode == 200) {
        final List<dynamic> data = json.decode(response.body);
        developer.log(
          '📦 Artículos recibidos: ${data.length}',
          name: 'NewsService',
        );

        // Enriquecer cada artículo con su imagen (en paralelo)
        final enrichedData = await _enrichArticlesDataParallel(data);

        final articles = enrichedData
            .map((item) => Article.fromJson(item))
            .toList();

        // Aplicar el filtro de categorías permitidas solo si no se filtró en la API
        if (AppConstants.allowedCategoryIds.isEmpty) {
          return articles;
        }
        return _filterByAllowedCategories(articles);
      } else if (response.statusCode == 400) {
        developer.log('ℹ️ Página fuera de rango', name: 'NewsService');
        return [];
      } else {
        throw Exception('Error al cargar artículos: ${response.statusCode}');
      }
    } catch (e) {
      developer.log('❌ Error: $e', name: 'NewsService', error: e);
      throw Exception('Error al conectar con el servidor: $e');
    }
  }

  /// Enriquece los datos de artículos con información de medios embebidos.
  /// Usa carga PARALELA para mejorar significativamente el rendimiento.
  /// Agrega el campo _embedded con la imagen destacada para que el modelo
  /// Article.fromJson() pueda extraerla correctamente.
  Future<List<Map<String, dynamic>>> _enrichArticlesDataParallel(
    List<dynamic> articlesData,
  ) async {
    developer.log(
      '🖼️ Enriqueciendo ${articlesData.length} artículos con imágenes',
      name: 'NewsService',
    );

    // Recolectar todos los IDs de media únicos que necesitamos
    final mediaIds = <int>{};
    for (var articleData in articlesData) {
      final article = articleData as Map<String, dynamic>;
      final featuredMediaId = article['featured_media'] as int?;
      if (featuredMediaId != null && featuredMediaId > 0) {
        mediaIds.add(featuredMediaId);
      }
    }

    developer.log(
      '🖼️ IDs de media únicos: ${mediaIds.length}',
      name: 'NewsService',
    );

    // Obtener todos los medios en PARALELO
    final mediaFutures = mediaIds
        .where(
          (id) => !_mediaCache.containsKey(id),
        ) // Solo los que no están en caché
        .map((id) => _fetchMedia(id));

    if (mediaFutures.isNotEmpty) {
      developer.log(
        '⬇️ Descargando ${mediaFutures.length} imágenes nuevas',
        name: 'NewsService',
      );
      await Future.wait(mediaFutures);
    }

    // Ahora enriquecer los artículos con los datos de media
    final enrichedList = <Map<String, dynamic>>[];
    for (var articleData in articlesData) {
      final article = articleData as Map<String, dynamic>;
      final featuredMediaId = article['featured_media'] as int?;

      // Si tiene imagen destacada y está en caché, agregarla
      if (featuredMediaId != null &&
          featuredMediaId > 0 &&
          _mediaCache.containsKey(featuredMediaId)) {
        article['_embedded'] = {
          'wp:featuredmedia': [_mediaCache[featuredMediaId]!],
        };
      }

      enrichedList.add(article);
    }

    developer.log('✅ Artículos enriquecidos', name: 'NewsService');
    return enrichedList;
  }

  /// Obtiene los datos de un medio y los guarda en caché.
  Future<void> _fetchMedia(int mediaId) async {
    try {
      final mediaUri = Uri.parse('$_baseUrl/media/$mediaId');
      final mediaResponse = await http.get(mediaUri).timeout(_timeout);

      if (mediaResponse.statusCode == 200) {
        final mediaData = json.decode(mediaResponse.body);
        _mediaCache[mediaId] = mediaData;
      } else {
        developer.log(
          '⚠️ Error al obtener media $mediaId: ${mediaResponse.statusCode}',
          name: 'NewsService',
        );
      }
    } catch (e) {
      developer.log(
        '❌ Error al obtener media $mediaId: $e',
        name: 'NewsService',
      );
    }
  }

  /// Obtiene un artículo específico por su ID.
  /// Verifica que el artículo pertenezca a una categoría permitida.
  ///
  /// [id] - ID del artículo en WordPress.
  Future<Article> getArticleById(int id) async {
    try {
      developer.log('📄 Obteniendo artículo ID: $id', name: 'NewsService');

      final uri = Uri.parse('$_baseUrl/posts/$id');
      final response = await http.get(uri).timeout(_timeout);

      developer.log(
        '📡 Respuesta artículo: ${response.statusCode}',
        name: 'NewsService',
      );

      if (response.statusCode == 200) {
        final Map<String, dynamic> data = json.decode(response.body);

        // Enriquecer con imagen destacada
        final enrichedData = await _enrichArticlesDataParallel([data]);
        final article = Article.fromJson(enrichedData.first);

        // Verificar que el artículo tenga al menos una categoría permitida
        if (AppConstants.allowedCategoryIds.isNotEmpty) {
          final hasAllowedCategory = article.categories.any(
            (categoryId) =>
                AppConstants.allowedCategoryIds.contains(categoryId),
          );

          if (!hasAllowedCategory) {
            throw Exception('Artículo no pertenece a una categoría permitida');
          }
        }

        return article;
      } else {
        throw Exception('Error al cargar artículo: ${response.statusCode}');
      }
    } catch (e) {
      developer.log('❌ Error: $e', name: 'NewsService', error: e);
      throw Exception('Error al conectar con el servidor: $e');
    }
  }

  /// Busca artículos por término de búsqueda.
  /// Si el término está vacío, retorna todos los artículos recientes.
  ///
  /// [searchTerm] - Término a buscar en títulos y contenido.
  Future<List<Article>> searchArticles(String searchTerm) async {
    try {
      developer.log('🔍 Buscando: "$searchTerm"', name: 'NewsService');

      // Si no hay término de búsqueda, retornar la lista de artículos recientes.
      if (searchTerm.trim().isEmpty) {
        return getArticles();
      }

      final encodedSearch = Uri.encodeComponent(searchTerm.trim());

      // Construir URL con filtro de categorías si está configurado
      String url =
          '$_baseUrl/posts?search=$encodedSearch&per_page=$_itemsPerPage';

      if (AppConstants.allowedCategoryIds.isNotEmpty) {
        final categoryIds = AppConstants.allowedCategoryIds.join(',');
        url += '&categories=$categoryIds';
      }

      final uri = Uri.parse(url);
      developer.log('🌐 URL búsqueda: $uri', name: 'NewsService');

      final response = await http.get(uri).timeout(_timeout);

      developer.log(
        '📡 Respuesta búsqueda: ${response.statusCode}',
        name: 'NewsService',
      );

      if (response.statusCode == 200) {
        final List<dynamic> data = json.decode(response.body);
        developer.log('📦 Resultados: ${data.length}', name: 'NewsService');

        // Enriquecer cada artículo con su imagen (en paralelo)
        final enrichedData = await _enrichArticlesDataParallel(data);

        final articles = enrichedData
            .map((item) => Article.fromJson(item))
            .toList();

        // Aplicar el filtro de categorías permitidas solo si no se filtró en la API
        if (AppConstants.allowedCategoryIds.isEmpty) {
          return articles;
        }
        return _filterByAllowedCategories(articles);
      } else {
        throw Exception('Error en la búsqueda: ${response.statusCode}');
      }
    } catch (e) {
      developer.log('❌ Error: $e', name: 'NewsService', error: e);
      throw Exception('Error al buscar artículos: $e');
    }
  }

  /// Limpia la caché de medios. Útil para liberar memoria si es necesario.
  static void clearMediaCache() {
    developer.log('🧹 Limpiando caché de medios', name: 'NewsService');
    _mediaCache.clear();
  }

  /// Método deprecado - Usar getArticles(page: page) en su lugar
  @Deprecated('Usar getArticles(page: page) en su lugar')
  Future<List<Article>> getArticlesPaginated(int page) async {
    return getArticles(page: page);
  }
}
