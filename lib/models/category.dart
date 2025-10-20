/// Modelo que representa una categoría de WordPress
class Category {
  /// Identificador único de la categoría
  final int id;

  /// Nombre de la categoría
  final String name;

  /// Slug de la categoría (URL amigable)
  final String slug;

  /// Cantidad de posts en esta categoría
  final int count;

  /// URL de la imagen asociada a la categoría (opcional)
  final String? imageUrl;

  /// Constructor de la clase Category
  Category({
    required this.id,
    required this.name,
    required this.slug,
    required this.count,
    this.imageUrl,
  });

  /// Crea una instancia de Category desde un JSON
  ///
  /// Parsea los datos provenientes de la API de WordPress
  /// y extrae la imagen de categoría si está disponible
  factory Category.fromJson(Map<String, dynamic> json) {
    return Category(
      id: json['id'] as int,
      name: json['name'] as String,
      slug: json['slug'] as String,
      count: json['count'] as int,
      imageUrl: _extractCategoryImage(json),
    );
  }

  /// Extrae la URL de la imagen de categoría desde diferentes fuentes
  ///
  /// WordPress puede almacenar imágenes de categorías en diferentes campos
  /// según los plugins instalados. Este método intenta extraer la imagen
  /// de las fuentes más comunes:
  /// - Category Featured Image plugin
  /// - Yoast SEO (Open Graph images)
  /// - ACF (Advanced Custom Fields)
  ///
  /// Retorna la URL de la imagen si se encuentra, null en caso contrario
  static String? _extractCategoryImage(Map<String, dynamic> json) {
    try {
      // Intenta obtener imagen desde Category Featured Image plugin
      if (json['category_image'] != null) {
        return json['category_image'] as String;
      }

      // Intenta obtener imagen desde Yoast SEO
      if (json['yoast_head_json'] != null) {
        final yoast = json['yoast_head_json'] as Map<String, dynamic>;
        if (yoast['og_image'] != null) {
          final images = yoast['og_image'] as List<dynamic>;
          if (images.isNotEmpty) {
            return images[0]['url'] as String?;
          }
        }
      }

      // Intenta obtener imagen desde ACF (Advanced Custom Fields)
      if (json['acf'] != null) {
        final acf = json['acf'] as Map<String, dynamic>;
        if (acf['image'] != null) {
          // ACF puede devolver la URL como String o como objeto
          if (acf['image'] is String) {
            return acf['image'] as String;
          } else if (acf['image'] is Map) {
            final imageData = acf['image'] as Map<String, dynamic>;
            return imageData['url'] as String?;
          }
        }
      }

      return null;
    } catch (e) {
      // Si ocurre algún error durante la extracción, retorna null
      return null;
    }
  }

  /// Convierte la instancia de Category a un Map JSON
  ///
  /// Útil para serialización y almacenamiento local
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'slug': slug,
      'count': count,
      'imageUrl': imageUrl,
    };
  }
}
