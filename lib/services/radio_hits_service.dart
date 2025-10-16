import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:html/parser.dart' as html_parser;
import 'package:html/dom.dart' as dom;
import '../models/radio_hit.dart';

/// Servicio para obtener los Radio Hits desde la página web
/// Utiliza web scraping para extraer el ranking de canciones con sus imágenes
class RadioHitsService {
  static const String _radioHitsUrl =
      'https://ambientestereo.fm/sitio/radio-hits-ambiente-stereo/';
  static const Duration _timeout = Duration(seconds: 15);

  Future<List<RadioHit>> getRadioHits() async {
    try {
      final response = await http
          .get(Uri.parse(_radioHitsUrl))
          .timeout(_timeout);

      if (response.statusCode == 200) {
        final document = html_parser.parse(utf8.decode(response.bodyBytes));
        return _parseRadioHits(document);
      } else {
        throw Exception('Error al cargar Radio Hits: ${response.statusCode}');
      }
    } catch (e) {
      throw Exception('Error al conectar con el servidor: $e');
    }
  }

  List<RadioHit> _parseRadioHits(dom.Document document) {
    final List<RadioHit> radioHits = [];

    try {
      final contentDiv =
          document.querySelector('.entry-content') ??
          document.querySelector('.post-content') ??
          document.querySelector('article .content') ??
          document.querySelector('.post-body');

      if (contentDiv == null) {
        return [];
      }

      final figures = contentDiv.querySelectorAll('figure');
      List<String?> imageUrls = [];

      for (var figure in figures) {
        final img = figure.querySelector('img');
        if (img != null) {
          String? imageUrl =
              img.attributes['src'] ??
              img.attributes['data-src'] ??
              img.attributes['data-lazy-src'];

          if (imageUrl != null && imageUrl.contains(' ')) {
            imageUrl = imageUrl.split(' ').first;
          }
          imageUrls.add(imageUrl);
        }
      }

      final allParagraphs = contentDiv.querySelectorAll('p');

      for (int i = 0; i < allParagraphs.length; i++) {
        final p = allParagraphs[i];
        final strong = p.querySelector('strong, b');

        if (strong == null) {
          continue;
        }

        final titleText = strong.text.trim();
        if (titleText.isEmpty) {
          continue;
        }

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
        final artistText = fullText.replaceFirst(titleText, '').trim();

        if (artistText.isNotEmpty) {
          artist = artistText;
        } else {
          if (i + 1 < allParagraphs.length) {
            final nextP = allParagraphs[i + 1];
            final nextText = nextP.text.trim();

            if (nextText.isNotEmpty &&
                !RegExp(r'^\d+[\.\-\)\s]+').hasMatch(nextText)) {
              artist = nextText;
            }
          }
        }

        String? imageUrl;
        if (position <= imageUrls.length) {
          imageUrl = imageUrls[position - 1];
        }

        final hit = RadioHit(
          position: position,
          songTitle: songTitle,
          artist: artist,
          imageUrl: _cleanImageUrl(imageUrl),
        );

        radioHits.add(hit);
      }

      radioHits.sort((a, b) => a.position.compareTo(b.position));
      return radioHits;
    } catch (e) {
      return [];
    }
  }

  String? _cleanImageUrl(String? imageUrl) {
    if (imageUrl == null || imageUrl.isEmpty) return null;

    if (imageUrl.startsWith('//')) {
      return 'https:$imageUrl';
    } else if (imageUrl.startsWith('/')) {
      return 'https://ambientestereo.fm$imageUrl';
    } else if (!imageUrl.startsWith('http')) {
      return 'https://ambientestereo.fm/sitio/$imageUrl';
    }

    return imageUrl;
  }
}
