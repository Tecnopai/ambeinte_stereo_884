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

  /// URL de la imagen destacada del artículo
  final String? imageUrl;

  /// URL del archivo de audio del artículo
  final String? audioUrl;

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
    this.audioUrl,
  });

  /// Crea una instancia de Article desde un JSON
  ///
  /// Parsea los datos de la API REST de WordPress,
  /// limpia el HTML de los campos de texto y extrae
  /// la URL de la imagen destacada y el audio si están disponibles
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
      audioUrl: _extractAudioUrl(json),
    );
  }

  /// Extrae la URL del archivo de audio del artículo
  ///
  /// Busca el audio en diferentes fuentes en orden de prioridad:
  /// 1. Campo personalizado 'audio_url' o 'audio'
  /// 2. ACF (Advanced Custom Fields) si está disponible
  /// 3. Meta fields del post
  /// 4. Archivos adjuntos de tipo audio
  /// 5. Dentro del contenido HTML (tags <audio>, <source>, URLs directas)
  /// 6. Shortcodes de WordPress [audio]
  /// 7. Enclosures (usado por podcasts)
  ///
  /// Retorna la URL del audio si se encuentra, null en caso contrario
  static String? _extractAudioUrl(Map<String, dynamic> json) {
    try {
      // 1. Campo personalizado directo
      if (json['audio_url'] != null) {
        return json['audio_url'] as String?;
      }

      if (json['audio'] != null) {
        return json['audio'] as String?;
      }

      // 2. ACF (Advanced Custom Fields)
      if (json['acf'] != null) {
        final acf = json['acf'];

        // ACF puede ser un Map o una List vacía
        if (acf is Map<String, dynamic>) {
          if (acf['audio_url'] != null) {
            return acf['audio_url'] as String?;
          }
          if (acf['audio'] != null) {
            final audio = acf['audio'];
            // Puede ser un string o un objeto
            if (audio is String) {
              return audio;
            } else if (audio is Map<String, dynamic> && audio['url'] != null) {
              return audio['url'] as String?;
            }
          }
        }
      }

      // 3. Meta fields
      if (json['meta'] != null) {
        final meta = json['meta'];

        if (meta is Map<String, dynamic>) {
          if (meta['audio_url'] != null) {
            return meta['audio_url'] as String?;
          }
        }
      }

      // 4. Archivos adjuntos embebidos de tipo audio
      if (json['_embedded'] != null) {
        final embedded = json['_embedded'] as Map<String, dynamic>;

        // Buscar en wp:attachment
        if (embedded['wp:attachment'] != null) {
          final attachments = embedded['wp:attachment'] as List<dynamic>;
          for (var attachment in attachments) {
            if (attachment is Map<String, dynamic>) {
              final mimeType = attachment['mime_type'] as String?;
              if (mimeType != null && mimeType.startsWith('audio/')) {
                return attachment['source_url'] as String?;
              }
            }
          }
        }
      }

      // 5. Enclosures (usado por podcasts y RSS)
      if (json['enclosure'] != null) {
        final enclosure = json['enclosure'];
        if (enclosure is String && enclosure.isNotEmpty) {
          return enclosure;
        } else if (enclosure is List && enclosure.isNotEmpty) {
          final firstEnclosure = enclosure[0];
          if (firstEnclosure is String) {
            return firstEnclosure;
          }
        }
      }

      // 6. Buscar en el contenido HTML
      if (json['content'] != null && json['content']['rendered'] != null) {
        final content = json['content']['rendered'] as String;

        // Buscar tag <audio> con src
        final audioTagRegex = RegExp(
          r'<audio[^>]+src=["'
          "'"
          r']([^"'
          "'"
          r']+)["'
          "'"
          r']',
          caseSensitive: false,
        );
        final audioTagMatch = audioTagRegex.firstMatch(content);
        if (audioTagMatch != null && audioTagMatch.group(1) != null) {
          return audioTagMatch.group(1)!;
        }

        // Buscar tag <source> dentro de <audio> con comillas dobles
        RegExp sourceTagRegex = RegExp(
          r'<source[^>]+src="([^"]+\.(?:mp3|wav|ogg|m4a|aac))"',
          caseSensitive: false,
        );
        Match? sourceTagMatch = sourceTagRegex.firstMatch(content);

        // Si no encuentra con comillas dobles, buscar con comillas simples
        if (sourceTagMatch == null) {
          sourceTagRegex = RegExp(
            r"<source[^>]+src='([^']+\.(?:mp3|wav|ogg|m4a|aac))'",
            caseSensitive: false,
          );
          sourceTagMatch = sourceTagRegex.firstMatch(content);
        }

        if (sourceTagMatch != null && sourceTagMatch.group(1) != null) {
          return sourceTagMatch.group(1)!;
        }

        // Buscar URLs directas de audio en el contenido
        final directUrlRegex = RegExp(
          r'https?://[^\s<>"]+\.(?:mp3|wav|ogg|m4a|aac)',
          caseSensitive: false,
        );
        final directUrlMatch = directUrlRegex.firstMatch(content);
        if (directUrlMatch != null) {
          return directUrlMatch.group(0)!;
        }

        // Buscar shortcode de WordPress [audio src="..."]
        RegExp shortcodeRegex = RegExp(
          r'\[audio[^\]]*src="([^"]+)"[^\]]*\]',
          caseSensitive: false,
        );
        Match? shortcodeMatch = shortcodeRegex.firstMatch(content);

        // Si no encuentra con comillas dobles, buscar con comillas simples
        if (shortcodeMatch == null) {
          shortcodeRegex = RegExp(
            r"\[audio[^\]]*src='([^']+)'[^\]]*\]",
            caseSensitive: false,
          );
          shortcodeMatch = shortcodeRegex.firstMatch(content);
        }

        if (shortcodeMatch != null && shortcodeMatch.group(1) != null) {
          return shortcodeMatch.group(1)!;
        }

        // Buscar player de Podlove
        RegExp podloveRegex = RegExp(
          r'data-episode-src="([^"]+)"',
          caseSensitive: false,
        );
        Match? podloveMatch = podloveRegex.firstMatch(content);

        // Si no encuentra con comillas dobles, buscar con comillas simples
        if (podloveMatch == null) {
          podloveRegex = RegExp(
            r"data-episode-src='([^']+)'",
            caseSensitive: false,
          );
          podloveMatch = podloveRegex.firstMatch(content);
        }

        if (podloveMatch != null && podloveMatch.group(1) != null) {
          return podloveMatch.group(1)!;
        }
      }

      // No se encontró audio en ninguna fuente
      return null;
    } catch (e) {
      return null;
    }
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
      'audioUrl': audioUrl,
    };
  }
}
