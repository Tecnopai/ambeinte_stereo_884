import 'dart:convert';
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

  /// Filtra artículos para mostrar solo los de categorías permitidas.
  /// Verifica que el artículo tenga al menos una categoría incluida en
  /// [AppConstants.allowedCategoryIds].
  List<Article> _filterByAllowedCategories(List<Article> articles) {
    return articles.where((article) {
      // Si el artículo no tiene categorías asociadas, es descartado.
      if (article.categories.isEmpty) return false;

      // Retorna true si alguna de las categorías del artículo está en la lista permitida.
      return article.categories.any(
        (categoryId) => AppConstants.allowedCategoryIds.contains(categoryId),
      );
    }).toList();
  }

  /// Obtiene todas las categorías disponibles desde WordPress.
  /// Incluye el parámetro [_embed] para obtener imágenes asociadas y otros datos.
  /// Filtra categorías con contador cero (vacías) y las no permitidas.
  Future<List<Category>> getCategories() async {
    try {
      final uri = Uri.parse(
        '$_baseUrl/categories?per_page=100&hide_empty=true&_embed',
      );
      final response = await http.get(uri).timeout(_timeout);

      if (response.statusCode == 200) {
        final List<dynamic> data = json.decode(response.body);
        return data
            .map((item) => Category.fromJson(item as Map<String, dynamic>))
            // 1. Filtrar categorías que no tienen artículos publicados (count > 0)
            .where((category) => category.count > 0)
            // 2. Filtrar categorías que no están en la lista de IDs permitidos
            .where(
              (category) =>
                  AppConstants.allowedCategoryIds.contains(category.id),
            )
            .toList();
      } else {
        throw Exception('Error al cargar categorías: ${response.statusCode}');
      }
    } catch (e) {
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
      // Verificación de seguridad: si la categoría no está permitida, se ignora la petición.
      if (!AppConstants.allowedCategoryIds.contains(categoryId)) {
        return [];
      }

      final uri = Uri.parse(
        '$_baseUrl/posts?categories=$categoryId&page=$page&per_page=$_itemsPerPage&_embed',
      );
      final response = await http.get(uri).timeout(_timeout);

      if (response.statusCode == 200) {
        final List<dynamic> data = json.decode(response.body);
        final articles = data
            .map((item) => Article.fromJson(item as Map<String, dynamic>))
            .toList();

        // Aplicar el filtro de categorías permitidas post-carga
        return _filterByAllowedCategories(articles);
      } else if (response.statusCode == 400) {
        // El código 400 (Bad Request) a menudo se da cuando se pide una página
        // que está fuera del rango, indicando el final de la lista.
        return [];
      } else {
        throw Exception('Error al cargar artículos: ${response.statusCode}');
      }
    } catch (e) {
      throw Exception('Error al cargar artículos por categoría: $e');
    }
  }

  /// Obtiene la lista de todos los artículos recientes (todas las categorías permitidas).
  /// Soporta paginación.
  ///
  /// [page] - Número de página para la paginación (por defecto 1).
  Future<List<Article>> getArticles({int page = 1}) async {
    try {
      final uri = Uri.parse(
        '$_baseUrl/posts?page=$page&per_page=$_itemsPerPage&_embed',
      );
      final response = await http.get(uri).timeout(_timeout);

      if (response.statusCode == 200) {
        final List<dynamic> data = json.decode(response.body);
        final articles = data
            .map((item) => Article.fromJson(item as Map<String, dynamic>))
            .toList();

        // Aplicar el filtro de categorías permitidas
        return _filterByAllowedCategories(articles);
      } else if (response.statusCode == 400) {
        // Página fuera de rango o sin resultados.
        return [];
      } else {
        throw Exception('Error al cargar artículos: ${response.statusCode}');
      }
    } catch (e) {
      throw Exception('Error al conectar con el servidor: $e');
    }
  }

  /// Obtiene un artículo específico por su ID.
  /// Verifica que el artículo pertenezca a una categoría permitida.
  ///
  /// [id] - ID del artículo en WordPress.
  Future<Article> getArticleById(int id) async {
    try {
      final uri = Uri.parse('$_baseUrl/posts/$id?_embed');
      final response = await http.get(uri).timeout(_timeout);

      if (response.statusCode == 200) {
        final Map<String, dynamic> data = json.decode(response.body);
        final article = Article.fromJson(data);

        // Verificar que el artículo tenga al menos una categoría permitida
        final hasAllowedCategory = article.categories.any(
          (categoryId) => AppConstants.allowedCategoryIds.contains(categoryId),
        );

        if (!hasAllowedCategory) {
          throw Exception('Artículo no pertenece a una categoría permitida');
        }

        return article;
      } else {
        throw Exception('Error al cargar artículo: ${response.statusCode}');
      }
    } catch (e) {
      throw Exception('Error al conectar con el servidor: $e');
    }
  }

  /// Busca artículos por término de búsqueda.
  /// Si el término está vacío, retorna todos los artículos recientes.
  ///
  /// [searchTerm] - Término a buscar en títulos y contenido.
  Future<List<Article>> searchArticles(String searchTerm) async {
    try {
      // Si no hay término de búsqueda, retornar la lista de artículos recientes.
      if (searchTerm.trim().isEmpty) {
        return getArticles();
      }

      final encodedSearch = Uri.encodeComponent(searchTerm.trim());
      final uri = Uri.parse(
        '$_baseUrl/posts?search=$encodedSearch&per_page=$_itemsPerPage&_embed',
      );
      final response = await http.get(uri).timeout(_timeout);

      if (response.statusCode == 200) {
        final List<dynamic> data = json.decode(response.body);
        final articles = data
            .map((item) => Article.fromJson(item as Map<String, dynamic>))
            .toList();

        // Aplicar el filtro de categorías permitidas a los resultados de búsqueda.
        return _filterByAllowedCategories(articles);
      } else {
        throw Exception('Error en la búsqueda: ${response.statusCode}');
      }
    } catch (e) {
      throw Exception('Error al buscar artículos: $e');
    }
  }

  /// Método deprecado - Usar getArticles(page: page) en su lugar
  @Deprecated('Usar getArticles(page: page) en su lugar')
  Future<List<Article>> getArticlesPaginated(int page) async {
    return getArticles(page: page);
  }
}
