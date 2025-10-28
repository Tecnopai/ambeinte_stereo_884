import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:html/parser.dart' as html_parser;
import 'package:html/dom.dart' as dom;
import '../models/radio_hit.dart';

/// Servicio para obtener los Radio Hits desde la página web.
/// Utiliza web scraping para extraer el ranking de canciones con sus imágenes
/// desde una URL estática.
class RadioHitsService {
  // URL de la página que contiene el ranking musical.
  static const String _radioHitsUrl =
      'https://ambientestereo.fm/sitio/radio-hits-ambiente-stereo/';

  // Timeout para las peticiones HTTP.
  static const Duration _timeout = Duration(seconds: 15);

  /// Realiza la solicitud HTTP y parsea la respuesta HTML.
  Future<List<RadioHit>> getRadioHits() async {
    try {
      final response = await http
          .get(Uri.parse(_radioHitsUrl))
          .timeout(_timeout);

      if (response.statusCode == 200) {
        // Decodificar el cuerpo de la respuesta a una cadena UTF-8 para evitar errores de caracteres.
        final document = html_parser.parse(utf8.decode(response.bodyBytes));
        return _parseRadioHits(document);
      } else {
        throw Exception('Error al cargar Radio Hits: ${response.statusCode}');
      }
    } catch (e) {
      throw Exception('Error al conectar con el servidor: $e');
    }
  }

  /// Lógica principal de web scraping para extraer los datos de las canciones.
  List<RadioHit> _parseRadioHits(dom.Document document) {
    final List<RadioHit> radioHits = [];

    try {
      // 1. Encontrar el contenedor principal del contenido (puede variar).
      final contentDiv =
          document.querySelector('.entry-content') ??
          document.querySelector('.post-content') ??
          document.querySelector('article .content') ??
          document.querySelector('.post-body');

      if (contentDiv == null) {
        // Si no se encuentra el contenedor, retorna una lista vacía.
        return [];
      }

      // 2. Extraer todas las URLs de imágenes contenidas en etiquetas <figure>.
      // Asume que las imágenes aparecen en orden antes de los títulos.
      final figures = contentDiv.querySelectorAll('figure');
      List<String?> imageUrls = [];

      for (var figure in figures) {
        final img = figure.querySelector('img');
        if (img != null) {
          // Intentar obtener la URL desde los atributos 'src', 'data-src' o 'data-lazy-src'.
          String? imageUrl =
              img.attributes['src'] ??
              img.attributes['data-src'] ??
              img.attributes['data-lazy-src'];

          // Manejo de URLs que pueden contener espacios o múltiplos URLs (srcset), tomando solo la primera.
          if (imageUrl != null && imageUrl.contains(' ')) {
            imageUrl = imageUrl.split(' ').first;
          }
          imageUrls.add(imageUrl);
        }
      }

      // 3. Extraer títulos, artistas y posiciones a partir de los párrafos.
      final allParagraphs = contentDiv.querySelectorAll('p');

      for (int i = 0; i < allParagraphs.length; i++) {
        final p = allParagraphs[i];
        // Busca el texto fuerte (título/posición) dentro del párrafo.
        final strong = p.querySelector('strong, b');

        if (strong == null) {
          continue;
        }

        final titleText = strong.text.trim();
        if (titleText.isEmpty) {
          continue;
        }

        // Expresión regular para parsear la posición y el título:
        // Ejemplo: "1. Título de la Canción" -> grupo(1)=1, grupo(2)=Título de la Canción
        final match = RegExp(r'^(\d+)[\.\-\)\s]+(.+)').firstMatch(titleText);
        if (match == null) {
          continue;
        }

        final position = int.tryParse(match.group(1) ?? '');
        final songTitle = match.group(2)?.trim();

        if (position == null || songTitle == null || songTitle.isEmpty) {
          continue;
        }

        String artist = 'Artista Desconocido';
        final fullText = p.text.trim();
        // El artista se asume que es el texto restante en el párrafo después del título fuerte (strong).
        final artistText = fullText.replaceFirst(titleText, '').trim();

        if (artistText.isNotEmpty) {
          artist = artistText;
        } else {
          // Lógica de respaldo: si el artista no está en el mismo párrafo,
          // verifica el siguiente párrafo si no contiene una nueva posición de ranking.
          if (i + 1 < allParagraphs.length) {
            final nextP = allParagraphs[i + 1];
            final nextText = nextP.text.trim();

            if (nextText.isNotEmpty &&
                // Asegura que el siguiente párrafo no sea el inicio de otra canción (ej: '2. ...')
                !RegExp(r'^\d+[\.\-\)\s]+').hasMatch(nextText)) {
              artist = nextText;
            }
          }
        }

        // Asignar la URL de la imagen en base a la posición (posición 1 -> index 0)
        String? imageUrl;
        if (position <= imageUrls.length) {
          imageUrl = imageUrls[position - 1];
        }

        final hit = RadioHit(
          position: position,
          songTitle: songTitle,
          artist: artist,
          // Limpiar y completar la URL si es relativa o incompleta.
          imageUrl: _cleanImageUrl(imageUrl),
        );

        radioHits.add(hit);
      }

      // Asegurar que la lista esté ordenada por posición.
      radioHits.sort((a, b) => a.position.compareTo(b.position));
      return radioHits;
    } catch (e) {
      // Manejar cualquier error de parsing y devolver una lista vacía.
      return [];
    }
  }

  /// Limpia y estandariza la URL de la imagen para garantizar que sea absoluta y use HTTPS.
  String? _cleanImageUrl(String? imageUrl) {
    if (imageUrl == null || imageUrl.isEmpty) return null;

    // Si comienza con '//' (protocol relative URL)
    if (imageUrl.startsWith('//')) {
      return 'https:$imageUrl';
      // Si comienza con '/' (URL relativa a la raíz)
    } else if (imageUrl.startsWith('/')) {
      return 'https://ambientestereo.fm$imageUrl';
      // Si no tiene protocolo (a veces solo la ruta relativa al sitio)
    } else if (!imageUrl.startsWith('http')) {
      return 'https://ambientestereo.fm/sitio/$imageUrl';
    }

    return imageUrl;
  }
}
