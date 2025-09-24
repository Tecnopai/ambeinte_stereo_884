import 'dart:convert';
import 'package:http/http.dart' as http;
import '../models/article.dart';

/// Servicio para manejar las noticias desde la API de WordPress
class NewsService {
  static const String _baseUrl =
      'https://ambientestereo.fm/sitio/wp-json/wp/v2/posts';
  static const int _itemsPerPage = 20;

  /// Obtiene la lista de artículos desde la API
  Future<List<Article>> getArticles() async {
    try {
      final uri = Uri.parse('$_baseUrl?per_page=$_itemsPerPage');
      final response = await http.get(uri);

      if (response.statusCode == 200) {
        final List<dynamic> data = json.decode(response.body);
        return data
            .map((item) => Article.fromJson(item as Map<String, dynamic>))
            .toList();
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
      final uri = Uri.parse('$_baseUrl/$id');
      final response = await http.get(uri);

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
      final uri = Uri.parse(
        '$_baseUrl?search=$searchTerm&per_page=$_itemsPerPage',
      );
      final response = await http.get(uri);

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

  /// Obtiene artículos con paginación
  Future<List<Article>> getArticlesPaginated(int page) async {
    try {
      final uri = Uri.parse('$_baseUrl?page=$page&per_page=$_itemsPerPage');
      final response = await http.get(uri);

      if (response.statusCode == 200) {
        final List<dynamic> data = json.decode(response.body);
        return data
            .map((item) => Article.fromJson(item as Map<String, dynamic>))
            .toList();
      } else {
        throw Exception('Error al cargar página $page: ${response.statusCode}');
      }
    } catch (e) {
      throw Exception('Error al cargar más artículos: $e');
    }
  }
}
