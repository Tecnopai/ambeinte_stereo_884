/// Modelo que representa una canción del ranking Radio Hits
class RadioHit {
  /// Posición en el ranking
  final int position;

  /// Título de la canción
  final String songTitle;

  /// Nombre del artista
  final String artist;

  /// URL de la imagen/portada (opcional)
  final String? imageUrl;

  /// URL del artículo completo (opcional)
  final String? articleUrl;

  /// Información adicional (opcional)
  final String? additionalInfo;

  /// Constructor de la clase RadioHit
  RadioHit({
    required this.position,
    required this.songTitle,
    required this.artist,
    this.imageUrl,
    this.articleUrl,
    this.additionalInfo,
  });

  /// Crea una instancia desde un Map (para parsing manual)
  factory RadioHit.fromMap(Map<String, dynamic> map) {
    return RadioHit(
      position: map['position'] as int,
      songTitle: map['songTitle'] as String,
      artist: map['artist'] as String,
      imageUrl: map['imageUrl'] as String?,
      articleUrl: map['articleUrl'] as String?,
      additionalInfo: map['additionalInfo'] as String?,
    );
  }

  /// Convierte la instancia a Map
  Map<String, dynamic> toMap() {
    return {
      'position': position,
      'songTitle': songTitle,
      'artist': artist,
      'imageUrl': imageUrl,
      'articleUrl': articleUrl,
      'additionalInfo': additionalInfo,
    };
  }
}
