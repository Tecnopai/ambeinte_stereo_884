/// Modelo que representa un artículo de noticias
class Article {
  final String title;
  final String content;
  final String excerpt;
  final String link;
  final DateTime date;

  Article({
    required this.title,
    required this.content,
    required this.excerpt,
    required this.link,
    required this.date,
  });

  /// Crea un artículo desde JSON de la API de WordPress
  factory Article.fromJson(Map<String, dynamic> json) {
    return Article(
      title: _stripHtmlTags(json['title']['rendered'] ?? ''),
      content: _stripHtmlTags(json['content']['rendered'] ?? ''),
      excerpt: _stripHtmlTags(json['excerpt']['rendered'] ?? ''),
      link: json['link'] ?? '',
      date: DateTime.parse(json['date'] ?? DateTime.now().toString()),
    );
  }

  /// Convierte el artículo a JSON
  Map<String, dynamic> toJson() {
    return {
      'title': title,
      'content': content,
      'excerpt': excerpt,
      'link': link,
      'date': date.toIso8601String(),
    };
  }

  /// Obtiene la fecha formateada en español
  String get formattedDate {
    const months = [
      'enero',
      'febrero',
      'marzo',
      'abril',
      'mayo',
      'junio',
      'julio',
      'agosto',
      'septiembre',
      'octubre',
      'noviembre',
      'diciembre',
    ];
    return '${date.day} de ${months[date.month - 1]} de ${date.year}';
  }

  /// Remueve las etiquetas HTML de un texto
  /// Remueve las etiquetas HTML y entidades HTML de un texto
  static String _stripHtmlTags(String html) {
    // Primero remover tags HTML
    final RegExp exp = RegExp(r"<[^>]*>", multiLine: true, caseSensitive: true);
    String cleanText = html.replaceAll(exp, '');

    // Luego limpiar entidades HTML
    cleanText = cleanText
        .replaceAll('&#8230;', '...') // Puntos suspensivos
        .replaceAll('&amp;', '&') // Ampersand
        .replaceAll('&lt;', '<') // Menor que
        .replaceAll('&gt;', '>') // Mayor que
        .replaceAll('&quot;', '"') // Comillas dobles
        .replaceAll('&#8217;', "'") // Apóstrofe
        .replaceAll('&#8220;', '"') // Comilla izquierda
        .replaceAll('&#8221;', '"') // Comilla derecha
        .replaceAll('&#8211;', '–') // Guión corto
        .replaceAll('&#8212;', '—') // Guión largo
        .replaceAll('&nbsp;', ' ') // Espacio sin separar
        .replaceAll('&hellip;', '...') // Puntos suspensivos (alternativa)
        .replaceAll('&lsquo;', "'") // Comilla simple izquierda
        .replaceAll('&rsquo;', "'") // Comilla simple derecha
        .replaceAll('&ldquo;', '"') // Comilla doble izquierda
        .replaceAll('&rdquo;', '"') // Comilla doble derecha
        .replaceAll('&ndash;', '–') // Guión corto (alternativa)
        .replaceAll('&mdash;', '—'); // Guión largo (alternativa)

    // Limpiar espacios extras y devolver
    return cleanText.replaceAll(RegExp(r'\s+'), ' ').trim();
  }

  @override
  String toString() {
    return 'Article(title: $title, date: $date)';
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is Article &&
        other.title == title &&
        other.content == content &&
        other.excerpt == excerpt &&
        other.link == link &&
        other.date == date;
  }

  @override
  int get hashCode {
    return title.hashCode ^
        content.hashCode ^
        excerpt.hashCode ^
        link.hashCode ^
        date.hashCode;
  }
}
