class Article {
  final int id;
  final String title;
  final String content;
  final String excerpt;
  final String link;
  final DateTime date;
  final List<int> categories;

  Article({
    required this.id,
    required this.title,
    required this.content,
    required this.excerpt,
    required this.link,
    required this.date,
    this.categories = const [],
  });

  factory Article.fromJson(Map<String, dynamic> json) {
    return Article(
      id: json['id'] as int,
      title: _parseHtmlString(json['title']['rendered'] as String),
      content: _parseHtmlString(json['content']['rendered'] as String),
      excerpt: _parseHtmlString(json['excerpt']['rendered'] as String),
      link: json['link'] as String,
      date: DateTime.parse(json['date'] as String),
      categories: (json['categories'] as List<dynamic>?)
          ?.map((e) => e as int)
          .toList() ?? [],
    );
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
        .replaceAll('&lt;', '<')
        .replaceAll('&gt;', '>')
        .replaceAll('[&hellip;]', '...')
        .trim();
  }

  String get formattedDate {
    final months = [
      'ene', 'feb', 'mar', 'abr', 'may', 'jun',
      'jul', 'ago', 'sep', 'oct', 'nov', 'dic'
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
    };
  }
}