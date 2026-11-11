import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import 'package:html/parser.dart' as html_parser;
import 'package:http/http.dart' as http;
import 'package:path_provider/path_provider.dart';
import 'package:xml/xml.dart';

import '../models/podcast.dart';
import 'diagnostics_log.dart';

/// Carga la lista de podcasts y sus episodios desde feeds RSS públicos.
///
/// La lista se lee (solo lectura) de Firestore en `app_config/podcasts`,
/// campo `feeds` (arreglo). Cada elemento puede ser:
///   - un texto con el enlace del podcast: el feed RSS o la página del
///     podcast en Apple Podcasts, Spotify, RSS.com u otro sitio;
///   - un mapa `{rss: "<enlace>", externo: "<enlace para el botón Abrir>"}`.
/// Así se pueden agregar podcasts sin publicar una nueva versión. Si Firestore
/// no responde se usa la lista por defecto de [defaultSources].
///
/// Cada feed se guarda en disco para mostrarlo al instante y sin conexión;
/// después se actualiza desde internet.
class PodcastService {
  PodcastService._();
  static final PodcastService instance = PodcastService._();

  static const String _configPath = 'app_config/podcasts';
  static const Duration _timeout = Duration(seconds: 20);

  /// Podcasts por defecto (si Firestore no responde o no tiene la lista).
  static const List<PodcastSource> defaultSources = [
    PodcastSource(
      url: 'https://media.rss.com/iglesia-pai/feed.xml',
      externalUrl: 'https://rss.com/es/podcasts/iglesia-pai/',
    ),
    PodcastSource(
      url: 'https://anchor.fm/s/109e4ce74/podcast/rss',
      externalUrl: 'https://open.spotify.com/show/2V4bLbcdpF5VQUyhbH5R96',
    ),
  ];

  List<PodcastSource>? _sources;
  final Map<String, Podcast> _memory = {};

  /// Feed RSS encontrado para cada enlace configurado.
  final Map<String, String> _resolvedFeeds = {};

  void _diag(String message) {
    debugPrint('[Podcast] $message');
    DiagnosticsLog.instance.add('Podcast: $message');
  }

  /// Lista de podcasts a mostrar, en orden.
  Future<List<PodcastSource>> loadSources() async {
    if (_sources != null) return _sources!;
    final docRef = FirebaseFirestore.instance.doc(_configPath);
    for (final source in [Source.server, Source.cache]) {
      try {
        final doc = await docRef
            .get(GetOptions(source: source))
            .timeout(Duration(seconds: source == Source.server ? 5 : 2));
        final data = doc.data() ?? const <String, dynamic>{};
        // Se tolera el nombre del campo con espacios o mayúsculas.
        final key = data.keys.firstWhere(
          (k) => k.trim().toLowerCase() == 'feeds',
          orElse: () => 'feeds',
        );
        final raw = data[key];
        final parsed = _parseSources(raw);
        if (parsed.isNotEmpty) {
          _diag('${parsed.length} podcasts desde Firebase (${source.name})');
          return _sources = parsed;
        }
        if (doc.exists) {
          final shown = '$raw';
          _diag(
            'Firebase (${source.name}) sin lista "feeds" válida. '
            'Campos: ${data.keys.map((k) => '"$k"').join(', ')}; '
            'valor (${raw.runtimeType}): '
            '${shown.length > 300 ? '${shown.substring(0, 300)}…' : shown}',
          );
        } else {
          _diag('Firebase (${source.name}): no existe app_config/podcasts');
        }
      } catch (e) {
        _diag('Firebase (${source.name}) no disponible: $e');
      }
    }
    _diag('usando lista por defecto');
    return _sources = defaultSources;
  }

  List<PodcastSource> _parseSources(Object? raw) {
    if (raw is! List) return const [];
    final result = <PodcastSource>[];
    for (final item in raw) {
      String? url;
      String? external;
      if (item is String) {
        url = item;
      } else if (item is Map) {
        url = item['rss'] as String?;
        external = item['externo'] as String?;
      }
      url = url == null ? null : _cleanUrl(url);
      external = external == null ? null : _cleanUrl(external);
      if (url == null || !_isHttpUrl(url)) continue;
      // Si el enlace es la página del podcast, sirve también para "Abrir en…".
      if (external == null && _isPageLink(url)) external = url;
      result.add(
        PodcastSource(
          url: url,
          externalUrl: external != null && _isHttpUrl(external)
              ? external.trim()
              : null,
        ),
      );
    }
    return result;
  }

  /// Quita espacios y comillas que se cuelan al copiar y pegar el enlace.
  String _cleanUrl(String value) =>
      value.trim().replaceAll(RegExp(r'''^["'“”‘’<\s]+|["'“”‘’>\s]+$'''), '');

  bool _isHttpUrl(String value) {
    final uri = Uri.tryParse(value.trim());
    return uri != null &&
        (uri.scheme == 'https' || uri.scheme == 'http') &&
        uri.host.isNotEmpty;
  }

  bool _isPageLink(String url) {
    final host = Uri.tryParse(url)?.host.toLowerCase() ?? '';
    return host.endsWith('spotify.com') ||
        host == 'podcasts.apple.com' ||
        host == 'rss.com' ||
        host == 'www.rss.com';
  }

  /// Emite primero la copia guardada (si existe) y luego la versión
  /// actualizada desde internet. Si no hay ninguna de las dos, emite error.
  Stream<Podcast> watch(PodcastSource source) async* {
    final inMemory = _memory[source.key];
    if (inMemory != null) {
      yield inMemory;
      return;
    }

    final cached = await _readCache(source);
    if (cached != null) {
      await _track(cached);
      yield cached;
    }

    try {
      final fresh = await refresh(source);
      if (fresh != null) yield fresh;
    } catch (e) {
      if (cached == null) rethrow;
    }
  }

  /// Revisa todos los podcasts para saber si hay episodios nuevos (punto
  /// verde en la pestaña). Se hace una vez por sesión; si el feed no cambió,
  /// el servidor responde "sin cambios" y no se descarga nada.
  Future<void> checkForNew() => _checkForNew ??= () async {
    final sources = await loadSources();
    for (final source in sources) {
      try {
        if (_memory.containsKey(source.key)) continue;
        await refresh(source);
      } catch (_) {
        // Sin conexión o feed caído: se intentará al abrir la pestaña.
      }
    }
  }();
  Future<void>? _checkForNew;

  /// Descarga el feed si cambió, lo guarda en disco y lo devuelve.
  /// Si ya hay una descarga en curso del mismo podcast, se reutiliza.
  Future<Podcast?> refresh(PodcastSource source) {
    final running = _inFlight[source.key];
    if (running != null) return running;
    final future = _refresh(source);
    _inFlight[source.key] = future;
    return future.whenComplete(() => _inFlight.remove(source.key));
  }

  final Map<String, Future<Podcast?>> _inFlight = {};

  Future<Podcast?> _refresh(PodcastSource source) async {
    try {
      final meta = await _readMeta(source);
      final savedFeed = meta['feed'];
      // El feed encontrado antes se reutiliza (evita volver a consultar
      // Spotify/Apple en cada arranque).
      if (savedFeed is String) {
        _resolvedFeeds.putIfAbsent(source.key, () => savedFeed);
      }
      final feedUrl = await _resolveFeedUrl(source);

      final cacheFile = await _cacheFile(source);
      final hasCache = await cacheFile.exists();
      final headers = <String, String>{};
      if (hasCache && savedFeed == feedUrl) {
        final etag = meta['etag'], modified = meta['modificado'];
        if (etag is String) headers['If-None-Match'] = etag;
        if (modified is String) headers['If-Modified-Since'] = modified;
      }

      var url = feedUrl;
      var response = await _request(Uri.parse(url), headers);

      // Sin cambios desde la última descarga: se usa la copia guardada.
      if (response.statusCode == 304 && hasCache) {
        final podcast = _memory[source.key] ?? await _readCache(source);
        if (podcast != null) {
          _memory[source.key] = podcast;
          await _track(podcast);
          return podcast;
        }
        response = await _request(Uri.parse(url), const {});
      }
      var body = _bodyOf(response);

      // Si en vez de un feed llegó una página web, buscar el feed que anuncia.
      if (!_looksLikeFeed(body)) {
        final alternate = _alternateFeedLink(body, Uri.parse(url));
        if (alternate == null) {
          throw const FormatException('el enlace no es un feed RSS');
        }
        url = alternate;
        _resolvedFeeds[source.key] = url;
        response = await _request(Uri.parse(url), const {});
        body = _bodyOf(response);
      }

      final podcast = await compute(_parseFeed, _FeedInput(source, body));
      if (podcast == null) throw const FormatException('feed inválido');
      _memory[source.key] = podcast;
      await _track(podcast);
      try {
        await cacheFile.writeAsString(body, flush: true);
        await _writeMeta(source, {
          'feed': url,
          if (response.headers['etag'] != null)
            'etag': response.headers['etag'],
          if (response.headers['last-modified'] != null)
            'modificado': response.headers['last-modified'],
        });
      } catch (_) {
        // No poder guardar la caché no impide mostrar el podcast.
      }
      return podcast;
    } catch (e) {
      _diag('no se pudo cargar ${source.url}: $e');
      rethrow;
    }
  }

  Future<http.Response> _request(Uri uri, Map<String, String> headers) {
    return http.get(uri, headers: headers).timeout(_timeout);
  }

  String _bodyOf(http.Response response) {
    if (response.statusCode != 200) {
      throw HttpException(
        'HTTP ${response.statusCode} en ${response.request?.url.host}',
      );
    }
    // Los feeds son UTF-8; se decodifica explícitamente por si el servidor
    // no declara el charset.
    return _utf8Decode(response.bodyBytes);
  }

  Future<String> _get(Uri uri) async => _bodyOf(await _request(uri, const {}));

  Future<Podcast?> _readCache(PodcastSource source) async {
    try {
      final file = await _cacheFile(source);
      if (!await file.exists()) return null;
      return await compute(
        _parseFeed,
        _FeedInput(source, await file.readAsString()),
      );
    } catch (_) {
      return null; // Caché dañada: se descargará de nuevo.
    }
  }

  Future<File> _metaFile(PodcastSource source) async {
    final cache = await _cacheFile(source);
    return File(cache.path.replaceFirst(RegExp(r'\.xml$'), '.json'));
  }

  Future<Map<String, dynamic>> _readMeta(PodcastSource source) async {
    try {
      final file = await _metaFile(source);
      if (!await file.exists()) return {};
      final data = jsonDecode(await file.readAsString());
      return data is Map<String, dynamic> ? data : {};
    } catch (_) {
      return {};
    }
  }

  Future<void> _writeMeta(
    PodcastSource source,
    Map<String, dynamic> data,
  ) async {
    final file = await _metaFile(source);
    await file.writeAsString(jsonEncode(data), flush: true);
  }

  // ============================================
  // EPISODIOS NUEVOS (solo en el teléfono)
  // ============================================

  /// Episodios nuevos por podcast (clave de [PodcastSource]).
  final ValueNotifier<Map<String, int>> newCounts = ValueNotifier(const {});

  /// True si algún podcast tiene episodios nuevos (punto en la pestaña).
  final ValueNotifier<bool> hasNew = ValueNotifier(false);

  /// Fecha del episodio más reciente que el usuario ya vio, por podcast.
  Map<String, DateTime>? _seen;

  Future<File> _seenFile() async {
    final dir = await getApplicationSupportDirectory();
    return File('${dir.path}/podcast_vistos.json');
  }

  Future<Map<String, DateTime>> _loadSeen() async {
    if (_seen != null) return _seen!;
    final map = <String, DateTime>{};
    try {
      final file = await _seenFile();
      if (await file.exists()) {
        final data = jsonDecode(await file.readAsString());
        if (data is Map) {
          data.forEach((k, v) {
            final date = v is String ? DateTime.tryParse(v) : null;
            if (k is String && date != null) map[k] = date;
          });
        }
      }
    } catch (_) {
      // Archivo dañado: se empieza de cero.
    }
    return _seen ??= map;
  }

  Future<void> _saveSeen() async {
    try {
      final file = await _seenFile();
      await file.writeAsString(
        jsonEncode(_seen!.map((k, v) => MapEntry(k, v.toIso8601String()))),
        flush: true,
      );
    } catch (_) {
      // Si no se puede guardar, solo se repetirá el aviso de "nuevo".
    }
  }

  /// Cuenta los episodios publicados después de la última visita.
  /// La primera vez que se ve un podcast no se marca nada como nuevo.
  Future<void> _track(Podcast podcast) async {
    final latest = podcast.latest?.pubDate;
    if (latest == null) return;
    final seen = await _loadSeen();
    final marker = seen[podcast.source.key];
    var count = 0;
    if (marker == null) {
      seen[podcast.source.key] = latest;
      await _saveSeen();
    } else {
      count = podcast.episodes
          .where((e) => e.pubDate != null && e.pubDate!.isAfter(marker))
          .length;
    }
    _setCount(podcast.source.key, count);
  }

  /// Marca como vistos los episodios de [podcast] y devuelve la fecha de la
  /// visita anterior (para resaltar lo nuevo mientras se está en la pantalla).
  DateTime? markSeen(Podcast podcast) {
    final latest = podcast.latest?.pubDate;
    final seen = _seen;
    if (latest == null || seen == null) return null;
    final previous = seen[podcast.source.key];
    if (previous == null || latest.isAfter(previous)) {
      seen[podcast.source.key] = latest;
      _saveSeen();
    }
    _setCount(podcast.source.key, 0);
    return previous;
  }

  void _setCount(String key, int count) {
    if ((newCounts.value[key] ?? 0) == count) return;
    newCounts.value = {...newCounts.value, key: count};
    final active = _sources?.map((s) => s.key).toSet();
    hasNew.value = newCounts.value.entries.any(
      (e) => e.value > 0 && (active == null || active.contains(e.key)),
    );
  }

  /// Convierte el enlace configurado en la URL de su feed RSS.
  Future<String> _resolveFeedUrl(PodcastSource source) async {
    final known = _resolvedFeeds[source.key];
    if (known != null) return known;

    final uri = Uri.parse(source.url);
    final host = uri.host.toLowerCase();
    String? feed;

    if (host == 'podcasts.apple.com' || host == 'itunes.apple.com') {
      // https://podcasts.apple.com/co/podcast/nombre/id1161558295
      final id = RegExp(r'id(\d+)').firstMatch(uri.path)?.group(1);
      if (id == null) throw const FormatException('enlace de Apple sin id');
      feed = await _itunesFeed({'id': id, 'entity': 'podcast'}, null);
    } else if (host.endsWith('spotify.com')) {
      // Spotify no publica el feed: se busca el mismo podcast por su nombre
      // en el directorio público de Apple, que sí indica el feed RSS.
      final page = await _get(uri);
      final match = RegExp(
        r'''property=["']og:title["']\s+content=["']([^"']+)["']''',
      ).firstMatch(page);
      final title = match == null
          ? null
          : html_parser.parseFragment(match.group(1)!).text?.trim();
      if (title == null || title.isEmpty) {
        throw const FormatException('no se encontró el nombre en Spotify');
      }
      feed = await _itunesFeed({
        'media': 'podcast',
        'entity': 'podcast',
        'term': title,
      }, title);
    } else if (host == 'rss.com' || host == 'www.rss.com') {
      // https://rss.com/es/podcasts/<nombre>/ → https://media.rss.com/<nombre>/feed.xml
      final segments = uri.pathSegments.where((s) => s.isNotEmpty).toList();
      final i = segments.indexOf('podcasts');
      if (i >= 0 && i + 1 < segments.length) {
        feed = 'https://media.rss.com/${segments[i + 1]}/feed.xml';
      }
    }

    feed ??= source.url;
    if (feed != source.url) _diag('${source.url} → $feed');
    return _resolvedFeeds[source.key] = feed;
  }

  /// Consulta el directorio público de Apple Podcasts y devuelve el feed.
  /// Con [title], elige el resultado cuyo nombre coincide.
  Future<String> _itunesFeed(Map<String, String> query, String? title) async {
    final path = query.containsKey('id') ? '/lookup' : '/search';
    final body = await _get(Uri.https('itunes.apple.com', path, query));
    final results = (jsonDecode(body) as Map)['results'];
    if (results is! List) throw const FormatException('respuesta de Apple');
    final candidates = results
        .whereType<Map>()
        .where((r) => r['feedUrl'] is String)
        .toList();
    if (candidates.isEmpty) {
      throw const FormatException('Apple no tiene el feed de este podcast');
    }
    if (title == null) return candidates.first['feedUrl'] as String;
    final wanted = _simplify(title);
    final exact = candidates.where(
      (r) => _simplify('${r['collectionName']}') == wanted,
    );
    if (exact.isEmpty) {
      throw FormatException('no se encontró "$title" en el directorio');
    }
    return exact.first['feedUrl'] as String;
  }

  static String _simplify(String s) =>
      s.toLowerCase().replaceAll(RegExp(r'[^a-z0-9áéíóúüñ]'), '');

  bool _looksLikeFeed(String body) {
    final head = body.length > 2000 ? body.substring(0, 2000) : body;
    return head.contains('<rss') || head.contains('<channel');
  }

  /// `<link rel="alternate" type="application/rss+xml" href="...">`
  String? _alternateFeedLink(String html, Uri base) {
    final tag = RegExp(
      r'''<link[^>]+type=["']application/rss\+xml["'][^>]*>''',
      caseSensitive: false,
    ).firstMatch(html)?.group(0);
    if (tag == null) return null;
    final href = RegExp(r'''href=["']([^"']+)["']''').firstMatch(tag)?.group(1);
    return href == null ? null : base.resolve(href).toString();
  }

  Future<File> _cacheFile(PodcastSource source) async {
    final dir = await getApplicationSupportDirectory();
    final folder = Directory('${dir.path}/podcasts');
    if (!await folder.exists()) await folder.create(recursive: true);
    return File('${folder.path}/${source.key}.xml');
  }
}

String _utf8Decode(List<int> bytes) =>
    const Utf8Decoder(allowMalformed: true).convert(bytes);

class _FeedInput {
  final PodcastSource source;
  final String xml;
  const _FeedInput(this.source, this.xml);
}

/// Convierte el XML de un feed RSS (con etiquetas de iTunes) en [Podcast].
/// Se ejecuta en un isolate aparte porque algunos feeds pesan más de 1 MB.
Podcast? _parseFeed(_FeedInput input) {
  final XmlDocument doc;
  try {
    doc = XmlDocument.parse(input.xml);
  } catch (_) {
    return null;
  }
  final channel = doc.findAllElements('channel').firstOrNull;
  if (channel == null) return null;

  final title = _text(channel, 'title') ?? 'Podcast';
  final podcastImage =
      _itunesImage(channel) ??
      channel.getElement('image')?.getElement('url')?.innerText.trim();

  final episodes = <PodcastEpisode>[];
  for (final item in channel.findElements('item')) {
    final enclosure = item.getElement('enclosure');
    final audioUrl = enclosure?.getAttribute('url')?.trim();
    if (audioUrl == null || audioUrl.isEmpty) continue;
    final rawDescription =
        _text(item, 'content:encoded') ??
        _text(item, 'description') ??
        _text(item, 'itunes:summary') ??
        '';
    episodes.add(
      PodcastEpisode(
        id: _text(item, 'guid') ?? audioUrl,
        title: _text(item, 'title') ?? 'Episodio',
        description: _htmlToText(rawDescription),
        audioUrl: audioUrl,
        pubDate: _parseRfc822(_text(item, 'pubDate')),
        duration: _parseDuration(_text(item, 'itunes:duration')),
        imageUrl: _itunesImage(item) ?? podcastImage,
        podcastTitle: title,
      ),
    );
  }

  // Del más reciente al más antiguo, aunque el feed venga desordenado.
  episodes.sort((a, b) {
    final da = a.pubDate, db = b.pubDate;
    if (da == null && db == null) return 0;
    if (da == null) return 1;
    if (db == null) return -1;
    return db.compareTo(da);
  });

  return Podcast(
    source: input.source,
    title: title,
    author: _text(channel, 'itunes:author') ?? _text(channel, 'author') ?? '',
    description: _htmlToText(
      _text(channel, 'description') ?? _text(channel, 'itunes:summary') ?? '',
    ),
    imageUrl: podcastImage,
    websiteUrl: _text(channel, 'link'),
    episodes: episodes,
  );
}

String? _text(XmlElement parent, String qualifiedName) {
  final element = parent.getElement(qualifiedName);
  final value = element?.innerText.trim();
  return (value == null || value.isEmpty) ? null : value;
}

String? _itunesImage(XmlElement parent) {
  final href = parent.getElement('itunes:image')?.getAttribute('href')?.trim();
  return (href == null || href.isEmpty) ? null : href;
}

String _htmlToText(String html) {
  if (!html.contains('<')) return html.trim();
  final withBreaks = html
      .replaceAll(RegExp(r'<br\s*/?>', caseSensitive: false), '\n')
      .replaceAll(RegExp(r'</p>', caseSensitive: false), '\n\n')
      .replaceAll(RegExp(r'</li>', caseSensitive: false), '\n');
  final text = html_parser.parse(withBreaks).body?.text ?? '';
  return text.replaceAll(RegExp(r'\n{3,}'), '\n\n').trim();
}

/// `itunes:duration` puede venir en segundos ("586") o como "HH:MM:SS"/"MM:SS".
Duration? _parseDuration(String? value) {
  if (value == null) return null;
  final parts = value.split(':').map((p) => int.tryParse(p.trim())).toList();
  if (parts.isEmpty || parts.any((p) => p == null)) return null;
  var seconds = 0;
  for (final p in parts) {
    seconds = seconds * 60 + p!;
  }
  return seconds > 0 ? Duration(seconds: seconds) : null;
}

const _months = {
  'jan': 1,
  'feb': 2,
  'mar': 3,
  'apr': 4,
  'may': 5,
  'jun': 6,
  'jul': 7,
  'aug': 8,
  'sep': 9,
  'oct': 10,
  'nov': 11,
  'dec': 12,
};

/// Fechas RSS: "Tue, 10 Nov 2026 06:00:00 GMT" o con zona "+0000"/"-0500".
DateTime? _parseRfc822(String? value) {
  if (value == null) return null;
  final match = RegExp(
    r'(\d{1,2})\s+([A-Za-z]{3})[a-z]*\s+(\d{4})\s+(\d{1,2}):(\d{2})(?::(\d{2}))?\s*([+-]\d{4}|[A-Z]{1,4})?',
  ).firstMatch(value);
  if (match == null) return DateTime.tryParse(value);
  final month = _months[match.group(2)!.toLowerCase()];
  if (month == null) return null;
  var date = DateTime.utc(
    int.parse(match.group(3)!),
    month,
    int.parse(match.group(1)!),
    int.parse(match.group(4)!),
    int.parse(match.group(5)!),
    int.parse(match.group(6) ?? '0'),
  );
  final zone = match.group(7);
  if (zone != null && (zone.startsWith('+') || zone.startsWith('-'))) {
    final sign = zone.startsWith('-') ? -1 : 1;
    final offset = Duration(
      hours: int.parse(zone.substring(1, 3)),
      minutes: int.parse(zone.substring(3, 5)),
    );
    date = sign > 0 ? date.subtract(offset) : date.add(offset);
  }
  return date;
}
