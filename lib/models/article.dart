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
  static String _stripHtmlTags(String html) {
    final RegExp exp = RegExp(r"<[^>]*>", multiLine: true, caseSensitive: true);
    return html.replaceAll(exp, '').trim();
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
