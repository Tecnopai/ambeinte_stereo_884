class Category {
  final int id;
  final String name;
  final String slug;
  final int count;
  final String? imageUrl; // ✨ NUEVO: URL de la imagen de categoría

  Category({
    required this.id,
    required this.name,
    required this.slug,
    required this.count,
    this.imageUrl, // ✨ NUEVO
  });

  factory Category.fromJson(Map<String, dynamic> json) {
    return Category(
      id: json['id'] as int,
      name: json['name'] as String,
      slug: json['slug'] as String,
      count: json['count'] as int,
      // ✨ NUEVO: Extraer imagen de categoría (si existe)
      imageUrl: _extractCategoryImage(json),
    );
  }

  // ✨ NUEVO: Método para extraer imagen de categoría
  static String? _extractCategoryImage(Map<String, dynamic> json) {
    try {
      // WordPress puede tener la imagen en diferentes campos según plugins
      // Category Featured Image plugin
      if (json['category_image'] != null) {
        return json['category_image'] as String;
      }

      // Yoast SEO
      if (json['yoast_head_json'] != null) {
        final yoast = json['yoast_head_json'] as Map<String, dynamic>;
        if (yoast['og_image'] != null) {
          final images = yoast['og_image'] as List<dynamic>;
          if (images.isNotEmpty) {
            return images[0]['url'] as String?;
          }
        }
      }

      // ACF (Advanced Custom Fields)
      if (json['acf'] != null) {
        final acf = json['acf'] as Map<String, dynamic>;
        if (acf['image'] != null) {
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
      return null;
    }
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'slug': slug,
      'count': count,
      'imageUrl': imageUrl, // ✨ NUEVO
    };
  }
}
