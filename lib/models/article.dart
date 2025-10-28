/// Modelo de datos para un artículo o publicación de WordPress.
/// {@template article_model}
/// Modelo de datos que representa un artículo o publicación obtenido
/// de la API REST de WordPress.
///
/// Contiene lógica para deserializar JSON, limpiar HTML y extraer
/// información de medios (imagen destacada y URL de audio) de múltiples fuentes.
/// {@endtemplate}
class Article {
  /// Identificador único del artículo en WordPress.
  final int id;

  /// Título del artículo, con el HTML ya eliminado.
  final String title;

  /// Contenido completo del artículo, con el HTML ya eliminado.
  final String content;

  /// Extracto o resumen del artículo, con el HTML ya eliminado.
  final String excerpt;

  /// URL permanente (permalink) del artículo.
  final String link;

  /// Fecha y hora de publicación del artículo (UTC).
  final DateTime date;

  /// Lista de IDs de categorías asociadas al artículo.
  final List<int> categories;

  /// URL de la imagen destacada (featured image) del artículo. Puede ser `null`.
  final String? imageUrl;

  /// URL del archivo de audio embebido o asociado al artículo. Puede ser `null`.
  final String? audioUrl;

  /// {@macro article_model}
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

  /// {@template article_from_json}
  /// Crea una instancia de [Article] desde un [Map] JSON.
  ///
  /// Parsea los datos de la API REST de WordPress. Se utiliza [_parseHtmlString]
  /// para limpiar los campos de texto y se llama a los extractores de medios.
  ///
  /// @param json El mapa JSON proveniente de la API de WordPress.
  /// @return Una nueva instancia de [Article].
  /// {@endtemplate}
  factory Article.fromJson(Map<String, dynamic> json) {
    return Article(
      id: json['id'] as int,
      // Los títulos vienen en un objeto 'rendered' y deben limpiarse de HTML.
      title: _parseHtmlString(json['title']['rendered'] as String),
      content: _parseHtmlString(json['content']['rendered'] as String),
      excerpt: _parseHtmlString(json['excerpt']['rendered'] as String),
      link: json['link'] as String,
      date: DateTime.parse(json['date'] as String),
      categories:
          (json['categories'] as List<dynamic>?)
              // Mapea la lista de dynamic a List<int>
              ?.map((e) => e as int)
              .toList() ??
          [],
      // Extracción robusta de las URLs de medios.
      imageUrl: _extractImageUrl(json),
      audioUrl: _extractAudioUrl(json),
    );
  }

  /// {@template extract_audio_url}
  /// Extrae la URL del archivo de audio del artículo a partir del JSON.
  ///
  /// Sigue un orden de prioridad riguroso para asegurar la fuente más confiable:
  /// 1. Campos personalizados directos ('audio_url', 'audio').
  /// 2. Campos personalizados de ACF (Advanced Custom Fields).
  /// 3. Campos Meta del post.
  /// 4. Archivos adjuntos embebidos de tipo audio (`_embedded`).
  /// 5. Enclosures (utilizado frecuentemente por plugins de podcasting).
  /// 6. Búsqueda en el contenido HTML (`<audio>`, `<source>`, shortcodes, Podlove).
  ///
  /// @param json El mapa JSON completo de la publicación de WordPress.
  /// @return La URL del audio si se encuentra, `null` en caso contrario.
  /// {@endtemplate}
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

        if (acf is Map<String, dynamic>) {
          if (acf['audio_url'] != null) {
            return acf['audio_url'] as String?;
          }
          if (acf['audio'] != null) {
            final audio = acf['audio'];
            // Puede ser un string (URL) o un objeto complejo (archivo adjunto de ACF).
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

        // Buscar en wp:attachment (medios adjuntos al post)
        if (embedded['wp:attachment'] != null) {
          final attachments = embedded['wp:attachment'] as List<dynamic>;
          for (var attachment in attachments) {
            if (attachment is Map<String, dynamic>) {
              final mimeType = attachment['mime_type'] as String?;
              // Si el adjunto es de tipo audio, usar su URL.
              if (mimeType != null && mimeType.startsWith('audio/')) {
                return attachment['source_url'] as String?;
              }
            }
          }
        }
      }

      // 5. Enclosures (Usado por RSS/Podcasts)
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

      // 6. Buscar en el contenido HTML renderizado
      if (json['content'] != null && json['content']['rendered'] != null) {
        final content = json['content']['rendered'] as String;

        // Buscar tag <audio> con atributo src
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

        // Buscar tag <source> dentro de <audio>
        RegExp sourceTagRegex = RegExp(
          r'<source[^>]+src="([^"]+\.(?:mp3|wav|ogg|m4a|aac))"',
          caseSensitive: false,
        );
        Match? sourceTagMatch = sourceTagRegex.firstMatch(content);

        // Intento con comillas simples si falla el doble
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

        // Intento con comillas simples si falla el doble
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

        // Buscar player de Podlove (u otro reproductor con data-episode-src)
        RegExp podloveRegex = RegExp(
          r'data-episode-src="([^"]+)"',
          caseSensitive: false,
        );
        Match? podloveMatch = podloveRegex.firstMatch(content);

        // Intento con comillas simples si falla el doble
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

      // Si no se encontró audio en ninguna fuente
      return null;
    } catch (e) {
      // Retorna null si ocurre algún error durante la extracción
      return null;
    }
  }

  /// {@template extract_image_url}
  /// Extrae la URL de la imagen destacada (featured media) del artículo.
  ///
  /// Prioriza fuentes de datos embebidas para obtener la mejor calidad:
  /// 1. Desde `_embedded.wp:featuredmedia` (Requiere el parámetro `?_embed` en la solicitud API).
  ///    - Prioriza tamaños intermedios: `medium_large` > `medium` > URL original.
  /// 2. Desde `jetpack_featured_media_url` (Proporcionado por Jetpack).
  ///
  /// @param json El mapa JSON completo de la publicación de WordPress.
  /// @return La URL de la imagen si se encuentra, `null` en caso contrario.
  /// {@endtemplate}
  static String? _extractImageUrl(Map<String, dynamic> json) {
    try {
      // 1. Obtener desde datos embebidos (_embed)
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

                // Priorizar tamaños para un mejor rendimiento: medium_large > medium
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

      // 2. URL directa de Jetpack (si está disponible)
      if (json['jetpack_featured_media_url'] != null) {
        return json['jetpack_featured_media_url'] as String;
      }

      return null;
    } catch (e) {
      // Si ocurre algún error durante la extracción, retorna null
      return null;
    }
  }

  /// {@template parse_html_string}
  /// Elimina etiquetas HTML y decodifica entidades HTML.
  ///
  /// Limpia el texto HTML recibido de WordPress eliminando todas
  /// las etiquetas y convirtiendo las entidades HTML comunes a sus
  /// caracteres equivalentes para ser mostradas como texto plano.
  ///
  /// @param htmlString La cadena de texto con formato HTML.
  /// @return La cadena de texto limpia.
  /// {@endtemplate}
  static String _parseHtmlString(String htmlString) {
    return htmlString
        .replaceAll(RegExp(r'<[^>]*>'), '') // Elimina todas las etiquetas HTML
        .replaceAll('&nbsp;', ' ') // Espacio no separable
        .replaceAll('&amp;', '&') // Ampersand
        .replaceAll('&quot;', '"') // Comillas dobles
        .replaceAll('&#8217;', "'") // Apóstrofe derecho (curvado)
        .replaceAll('&#8220;', '"') // Comilla izquierda (curvada)
        .replaceAll('&#8221;', '"') // Comilla derecha (curvada)
        .replaceAll('&#8230;', '...') // Puntos suspensivos
        .replaceAll('&#8211;', '-') // Guion corto
        .replaceAll('&lt;', '<') // Menor que
        .replaceAll('&gt;', '>') // Mayor que
        .replaceAll('[&hellip;]', '...') // Elipsis de WordPress
        .trim();
  }

  /// Retorna la fecha de publicación formateada en español.
  ///
  /// Formato: "Día Mes Año • HH:MM" (ej: "14 oct 2025 • 15:30").
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
    // Asegura que los minutos tengan dos dígitos, rellenando con '0' si es necesario.
    return '${date.day} ${months[date.month - 1]} ${date.year} • ${date.hour}:${date.minute.toString().padLeft(2, '0')}';
  }

  /// Convierte la instancia de [Article] a un [Map] JSON.
  ///
  /// Útil para la serialización de datos (ej. almacenamiento local o caché).
  ///
  /// @return Un mapa que representa el objeto para su serialización.
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      // Se mantiene el formato anidado para consistencia, aunque los valores ya están limpios.
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
