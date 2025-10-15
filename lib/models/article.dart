/// Modelo que representa un artículo de WordPress
class Article {
  /// Identificador único del artículo
  final int id;

  /// Título del artículo
  final String title;

  /// Contenido completo del artículo
  final String content;

  /// Extracto o resumen del artículo
  final String excerpt;

  /// URL permanente del artículo
  final String link;

  /// Fecha de publicación del artículo
  final DateTime date;

  /// Lista de IDs de categorías asociadas al artículo
  final List<int> categories;

  /// URL de la imagen destacada del artículo (opcional)
  final String? imageUrl;

  /// Constructor de la clase Article
  Article({
    required this.id,
    required this.title,
    required this.content,
    required this.excerpt,
    required this.link,
    required this.date,
    this.categories = const [],
    this.imageUrl,
  });

  /// Crea una instancia de Article desde un JSON
  ///
  /// Parsea los datos de la API REST de WordPress,
  /// limpia el HTML de los campos de texto y extrae
  /// la URL de la imagen destacada si está disponible
  factory Article.fromJson(Map<String, dynamic> json) {
    return Article(
      id: json['id'] as int,
      title: _parseHtmlString(json['title']['rendered'] as String),
      content: _parseHtmlString(json['content']['rendered'] as String),
      excerpt: _parseHtmlString(json['excerpt']['rendered'] as String),
      link: json['link'] as String,
      date: DateTime.parse(json['date'] as String),
      categories:
          (json['categories'] as List<dynamic>?)
              ?.map((e) => e as int)
              .toList() ??
          [],
      imageUrl: _extractImageUrl(json),
    );
  }

  /// Extrae la URL de la imagen destacada del artículo
  ///
  /// Intenta obtener la imagen de diferentes fuentes:
  /// 1. Desde _embedded.wp:featuredmedia (cuando se usa ?_embed en la API)
  ///    - Prioriza tamaños: medium_large > medium > full
  /// 2. Desde jetpack_featured_media_url (si está disponible)
  ///
  /// Retorna la URL de la imagen si se encuentra, null en caso contrario
  static String? _extractImageUrl(Map<String, dynamic> json) {
    try {
      // Opción 1: Obtener desde datos embebidos (_embed)
      if (json['_embedded'] != null) {
        final embedded = json['_embedded'] as Map<String, dynamic>;
        if (embedded['wp:featuredmedia'] != null) {
          final featuredMedia = embedded['wp:featuredmedia'] as List<dynamic>;
          if (featuredMedia.isNotEmpty) {
            final media = featuredMedia[0] as Map<String, dynamic>;

            // Intentar obtener diferentes tamaños de imagen
            if (media['media_details'] != null) {
              final details = media['media_details'] as Map<String, dynamic>;
              if (details['sizes'] != null) {
                final sizes = details['sizes'] as Map<String, dynamic>;

                // Priorizar tamaños: medium_large > medium > full
                if (sizes['medium_large'] != null) {
                  return sizes['medium_large']['source_url'] as String?;
                } else if (sizes['medium'] != null) {
                  return sizes['medium']['source_url'] as String?;
                }
              }
            }

            // Si no hay tamaños específicos, usar la URL original
            return media['source_url'] as String?;
          }
        }
      }

      // Opción 2: URL directa de Jetpack (si está disponible)
      if (json['jetpack_featured_media_url'] != null) {
        return json['jetpack_featured_media_url'] as String;
      }

      return null;
    } catch (e) {
      // Si ocurre algún error durante la extracción, retorna null
      return null;
    }
  }

  /// Elimina etiquetas HTML y decodifica entidades HTML
  ///
  /// Limpia el texto HTML recibido de WordPress eliminando todas
  /// las etiquetas y convirtiendo las entidades HTML comunes a sus
  /// caracteres equivalentes
  ///
  /// Ejemplo: "&amp;nbsp;texto" → " texto"
  static String _parseHtmlString(String htmlString) {
    return htmlString
        .replaceAll(RegExp(r'<[^>]*>'), '') // Elimina todas las etiquetas HTML
        .replaceAll('&nbsp;', ' ') // Espacio no separable
        .replaceAll('&amp;', '&') // Ampersand
        .replaceAll('&quot;', '"') // Comillas dobles
        .replaceAll('&#8217;', "'") // Apóstrofe
        .replaceAll('&#8220;', '"') // Comilla izquierda
        .replaceAll('&#8221;', '"') // Comilla derecha
        .replaceAll('&#8230;', '...') // Puntos suspensivos
        .replaceAll('&#8211;', '-') // Guion corto
        .replaceAll('&lt;', '<') // Menor que
        .replaceAll('&gt;', '>') // Mayor que
        .replaceAll('[&hellip;]', '...') // Elipsis de WordPress
        .trim();
  }

  /// Retorna la fecha formateada en español
  ///
  /// Formato: "14 oct 2025 • 15:30"
  String get formattedDate {
    final months = [
      'ene',
      'feb',
      'mar',
      'abr',
      'may',
      'jun',
      'jul',
      'ago',
      'sep',
      'oct',
      'nov',
      'dic',
    ];
    return '${date.day} ${months[date.month - 1]} ${date.year} • ${date.hour}:${date.minute.toString().padLeft(2, '0')}';
  }

  /// Convierte la instancia de Article a un Map JSON
  ///
  /// Útil para serialización y almacenamiento local
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'title': {'rendered': title},
      'content': {'rendered': content},
      'excerpt': {'rendered': excerpt},
      'link': link,
      'date': date.toIso8601String(),
      'categories': categories,
      'imageUrl': imageUrl,
    };
  }
}
