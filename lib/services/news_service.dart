import 'dart:convert';
import 'package:http/http.dart' as http;
import '../models/article.dart';
import '../models/category.dart';
import '../core/constants/app_constants.dart';

/// Servicio para manejar las noticias desde la API de WordPress
class NewsService {
  static const String _baseUrl =
      'https://ambientestereo.fm/sitio/wp-json/wp/v2';
  static const int _itemsPerPage = 20;
  static const Duration _timeout = Duration(seconds: 15);

  List<Article> _filterByAllowedCategories(List<Article> articles) {
    return articles.where((article) {
      if (article.categories.isEmpty) return false;
      return article.categories.any(
        (categoryId) => AppConstants.allowedCategoryIds.contains(categoryId),
      );
    }).toList();
  }

  /// Obtiene todas las categorías disponibles
  Future<List<Category>> getCategories() async {
    try {
      // ✨ MODIFICADO: Agregar _embed para obtener imágenes
      final uri = Uri.parse(
        '$_baseUrl/categories?per_page=100&hide_empty=true&_embed',
      );
      final response = await http.get(uri).timeout(_timeout);

      if (response.statusCode == 200) {
        final List<dynamic> data = json.decode(response.body);
        return data
            .map((item) => Category.fromJson(item as Map<String, dynamic>))
            .where((category) => category.count > 0)
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

  /// Obtiene artículos filtrados por categoría
  Future<List<Article>> getArticlesByCategory(
    int categoryId, {
    int page = 1,
  }) async {
    try {
      if (!AppConstants.allowedCategoryIds.contains(categoryId)) {
        return [];
      }

      // ✨ MODIFICADO: Agregar _embed para obtener imágenes
      final uri = Uri.parse(
        '$_baseUrl/posts?categories=$categoryId&page=$page&per_page=$_itemsPerPage&_embed',
      );
      final response = await http.get(uri).timeout(_timeout);

      if (response.statusCode == 200) {
        final List<dynamic> data = json.decode(response.body);
        final articles = data
            .map((item) => Article.fromJson(item as Map<String, dynamic>))
            .toList();

        return _filterByAllowedCategories(articles);
      } else if (response.statusCode == 400) {
        return [];
      } else {
        throw Exception('Error al cargar artículos: ${response.statusCode}');
      }
    } catch (e) {
      throw Exception('Error al cargar artículos por categoría: $e');
    }
  }

  /// Obtiene la lista de artículos desde la API
  Future<List<Article>> getArticles({int page = 1}) async {
    try {
      // ✨ MODIFICADO: Agregar _embed para obtener imágenes
      final uri = Uri.parse(
        '$_baseUrl/posts?page=$page&per_page=$_itemsPerPage&_embed',
      );
      final response = await http.get(uri).timeout(_timeout);

      if (response.statusCode == 200) {
        final List<dynamic> data = json.decode(response.body);
        final articles = data
            .map((item) => Article.fromJson(item as Map<String, dynamic>))
            .toList();

        return _filterByAllowedCategories(articles);
      } else if (response.statusCode == 400) {
        return [];
      } else {
        throw Exception('Error al cargar artículos: ${response.statusCode}');
      }
    } catch (e) {
      throw Exception('Error al conectar con el servidor: $e');
    }
  }

  /// Obtiene un artículo específico por ID
  Future<Article> getArticleById(int id) async {
    try {
      // ✨ MODIFICADO: Agregar _embed para obtener imágenes
      final uri = Uri.parse('$_baseUrl/posts/$id?_embed');
      final response = await http.get(uri).timeout(_timeout);

      if (response.statusCode == 200) {
        final Map<String, dynamic> data = json.decode(response.body);
        final article = Article.fromJson(data);

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

  /// Busca artículos por término de búsqueda
  Future<List<Article>> searchArticles(String searchTerm) async {
    try {
      if (searchTerm.trim().isEmpty) {
        return getArticles();
      }

      final encodedSearch = Uri.encodeComponent(searchTerm.trim());
      // ✨ MODIFICADO: Agregar _embed para obtener imágenes
      final uri = Uri.parse(
        '$_baseUrl/posts?search=$encodedSearch&per_page=$_itemsPerPage&_embed',
      );
      final response = await http.get(uri).timeout(_timeout);

      if (response.statusCode == 200) {
        final List<dynamic> data = json.decode(response.body);
        final articles = data
            .map((item) => Article.fromJson(item as Map<String, dynamic>))
            .toList();

        return _filterByAllowedCategories(articles);
      } else {
        throw Exception('Error en la búsqueda: ${response.statusCode}');
      }
    } catch (e) {
      throw Exception('Error al buscar artículos: $e');
    }
  }

  @Deprecated('Usar getArticles(page: page) en su lugar')
  Future<List<Article>> getArticlesPaginated(int page) async {
    return getArticles(page: page);
  }
}
