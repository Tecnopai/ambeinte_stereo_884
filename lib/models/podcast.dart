/// Modelos de datos para los podcasts (feeds RSS públicos).
library;

/// Origen configurado de un podcast.
///
/// [url] puede ser el feed RSS o el enlace de la página del podcast en
/// Apple Podcasts, Spotify, RSS.com u otro sitio: el servicio encuentra el
/// feed automáticamente.
class PodcastSource {
  /// Enlace configurado (feed RSS o página del podcast).
  final String url;

  /// Enlace externo para el botón "Abrir en…" (Spotify, Apple, etc.).
  final String? externalUrl;

  const PodcastSource({required this.url, this.externalUrl});

  /// Clave estable para caché en memoria y en disco.
  String get key => url.replaceAll(RegExp(r'[^A-Za-z0-9]'), '_');
}

/// Podcast completo con sus episodios (del más reciente al más antiguo).
class Podcast {
  final PodcastSource source;
  final String title;
  final String author;
  final String description;
  final String? imageUrl;
  final String? websiteUrl;
  final List<PodcastEpisode> episodes;

  const Podcast({
    required this.source,
    required this.title,
    required this.author,
    required this.description,
    required this.imageUrl,
    required this.websiteUrl,
    required this.episodes,
  });

  /// Episodio más reciente, si hay.
  PodcastEpisode? get latest => episodes.isEmpty ? null : episodes.first;
}

/// Un episodio de un podcast.
class PodcastEpisode {
  /// Identificador estable (guid del feed o, si no tiene, la URL del audio).
  final String id;
  final String title;

  /// Notas del episodio en texto plano.
  final String description;
  final String audioUrl;
  final DateTime? pubDate;
  final Duration? duration;

  /// Portada del episodio (o la del podcast si el episodio no tiene).
  final String? imageUrl;
  final String podcastTitle;

  const PodcastEpisode({
    required this.id,
    required this.title,
    required this.description,
    required this.audioUrl,
    required this.pubDate,
    required this.duration,
    required this.imageUrl,
    required this.podcastTitle,
  });

  Map<String, dynamic> toJson() => {
    'id': id,
    'title': title,
    'description': description,
    'audioUrl': audioUrl,
    'pubDate': pubDate?.toIso8601String(),
    'duration': duration?.inSeconds,
    'imageUrl': imageUrl,
    'podcastTitle': podcastTitle,
  };

  static PodcastEpisode? fromJson(Object? json) {
    if (json is! Map) return null;
    final id = json['id'];
    final audioUrl = json['audioUrl'];
    if (id is! String || audioUrl is! String) return null;
    final seconds = json['duration'];
    final pub = json['pubDate'];
    return PodcastEpisode(
      id: id,
      title: (json['title'] as String?) ?? '',
      description: (json['description'] as String?) ?? '',
      audioUrl: audioUrl,
      pubDate: pub is String ? DateTime.tryParse(pub) : null,
      duration: seconds is int ? Duration(seconds: seconds) : null,
      imageUrl: json['imageUrl'] as String?,
      podcastTitle: (json['podcastTitle'] as String?) ?? '',
    );
  }
}
