class Article {
  final int id;
  final String title;
  final String content;
  final String excerpt;
  final String link;
  final DateTime date;
  final List<int> categories;
  final String? imageUrl; // ✨ NUEVO: URL de la imagen destacada

  Article({
    required this.id,
    required this.title,
    required this.content,
    required this.excerpt,
    required this.link,
    required this.date,
    this.categories = const [],
    this.imageUrl, // ✨ NUEVO
  });

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
      // ✨ NUEVO: Extraer URL de la imagen
      imageUrl: _extractImageUrl(json),
    );
  }

  // ✨ NUEVO: Método para extraer la URL de la imagen
  static String? _extractImageUrl(Map<String, dynamic> json) {
    try {
      // Opción 1: Desde _embedded (si usamos ?_embed en la API)
      if (json['_embedded'] != null) {
        final embedded = json['_embedded'] as Map<String, dynamic>;
        if (embedded['wp:featuredmedia'] != null) {
          final featuredMedia = embedded['wp:featuredmedia'] as List<dynamic>;
          if (featuredMedia.isNotEmpty) {
            final media = featuredMedia[0] as Map<String, dynamic>;
            // Intentar obtener diferentes tamaños
            if (media['media_details'] != null) {
              final details = media['media_details'] as Map<String, dynamic>;
              if (details['sizes'] != null) {
                final sizes = details['sizes'] as Map<String, dynamic>;
                // Prioridad: medium_large > medium > full
                if (sizes['medium_large'] != null) {
                  return sizes['medium_large']['source_url'] as String?;
                } else if (sizes['medium'] != null) {
                  return sizes['medium']['source_url'] as String?;
                }
              }
            }
            // Si no hay tamaños específicos, usar source_url
            return media['source_url'] as String?;
          }
        }
      }

      // Opción 2: URL directa si está disponible
      if (json['jetpack_featured_media_url'] != null) {
        return json['jetpack_featured_media_url'] as String;
      }

      return null;
    } catch (e) {
      return null;
    }
  }

  static String _parseHtmlString(String htmlString) {
    return htmlString
        .replaceAll(RegExp(r'<[^>]*>'), '')
        .replaceAll('&nbsp;', ' ')
        .replaceAll('&amp;', '&')
        .replaceAll('&quot;', '"')
        .replaceAll('&#8217;', "'")
        .replaceAll('&#8220;', '"')
        .replaceAll('&#8221;', '"')
        .replaceAll('&#8230;', '...')
        .replaceAll('&lt;', '<')
        .replaceAll('&gt;', '>')
        .replaceAll('[&hellip;]', '...')
        .trim();
  }

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

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'title': {'rendered': title},
      'content': {'rendered': content},
      'excerpt': {'rendered': excerpt},
      'link': link,
      'date': date.toIso8601String(),
      'categories': categories,
      'imageUrl': imageUrl, // ✨ NUEVO
    };
  }
}
