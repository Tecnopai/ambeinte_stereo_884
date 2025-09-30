import 'dart:convert';
import 'package:http/http.dart' as http;
import '../models/article.dart';
import '../models/category.dart';

/// Servicio para manejar las noticias desde la API de WordPress
class NewsService {
  static const String _baseUrl =
      'https://ambientestereo.fm/sitio/wp-json/wp/v2';
  static const int _itemsPerPage = 20;
  static const Duration _timeout = Duration(seconds: 15);

  /// Obtiene todas las categorías disponibles
  Future<List<Category>> getCategories() async {
    try {
      final uri = Uri.parse('$_baseUrl/categories?per_page=100&hide_empty=true');
      final response = await http.get(uri).timeout(_timeout);

      if (response.statusCode == 200) {
        final List<dynamic> data = json.decode(response.body);
        return data
            .map((item) => Category.fromJson(item as Map<String, dynamic>))
            .where((category) => category.count > 0)
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
      final uri = Uri.parse(
        '$_baseUrl/posts?categories=$categoryId&page=$page&per_page=$_itemsPerPage',
      );
      final response = await http.get(uri).timeout(_timeout);

      if (response.statusCode == 200) {
        final List<dynamic> data = json.decode(response.body);
        return data
            .map((item) => Article.fromJson(item as Map<String, dynamic>))
            .toList();
      } else if (response.statusCode == 400) {
        // Página fuera de rango
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
      final uri =
      Uri.parse('$_baseUrl/posts?page=$page&per_page=$_itemsPerPage');
      final response = await http.get(uri).timeout(_timeout);

      if (response.statusCode == 200) {
        final List<dynamic> data = json.decode(response.body);
        return data
            .map((item) => Article.fromJson(item as Map<String, dynamic>))
            .toList();
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
      final uri = Uri.parse('$_baseUrl/posts/$id');
      final response = await http.get(uri).timeout(_timeout);

      if (response.statusCode == 200) {
        final Map<String, dynamic> data = json.decode(response.body);
        return Article.fromJson(data);
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
      final uri = Uri.parse(
        '$_baseUrl/posts?search=$encodedSearch&per_page=$_itemsPerPage',
      );
      final response = await http.get(uri).timeout(_timeout);

      if (response.statusCode == 200) {
        final List<dynamic> data = json.decode(response.body);
        return data
            .map((item) => Article.fromJson(item as Map<String, dynamic>))
            .toList();
      } else {
        throw Exception('Error en la búsqueda: ${response.statusCode}');
      }
    } catch (e) {
      throw Exception('Error al buscar artículos: $e');
    }
  }

  /// Obtiene artículos con paginación (método legacy, usar getArticles con page)
  @Deprecated('Usar getArticles(page: page) en su lugar')
  Future<List<Article>> getArticlesPaginated(int page) async {
    return getArticles(page: page);
  }
}