// lib/services/anime_service.dart
import 'dart:convert';
import 'package:http/http.dart' as http;
import '../models/anime.dart';
import '../models/character.dart';

class AnimeService {
  static const String _baseUrl = 'https://shikimori.one/api';
  static const Map<String, String> _headers = {
    'User-Agent': 'AnimeTrackerApp[](https://github.com/johnyshalker)',
    'Accept': 'application/json',
  };

  static Future<List<Anime>> fetchAnimeList({String? query, String? filter, int limit = 20}) async {
    Uri url;

    if (query != null && query.isNotEmpty) {
      url = Uri.parse('$_baseUrl/animes?search=$query&limit=$limit&order=popularity');
    } else if (filter == 'airing') {
      url = Uri.parse('$_baseUrl/animes?status=ongoing&order=popularity&limit=$limit');
    } else if (filter == 'upcoming') {
      url = Uri.parse('$_baseUrl/animes?status=anons&order=popularity&limit=$limit');
    } else {
      url = Uri.parse('$_baseUrl/animes?order=ranked&limit=$limit');
    }

    final response = await http.get(url, headers: _headers);
    if (response.statusCode != 200) {
      throw Exception('Не удалось загрузить данные с Shikimori');
    }

    final List data = json.decode(response.body);
    return data.map((e) => Anime.fromJson(_mapShikimoriAnime(e))).toList();
  }

  static Future<Anime> fetchAnimeById(int id) async {
    final url = Uri.parse('$_baseUrl/animes/$id');
    final response = await http.get(url, headers: _headers);

    if (response.statusCode != 200) {
      throw Exception('Не удалось загрузить аниме с ID $id');
    }

    final data = json.decode(response.body);
    return Anime.fromJson(_mapShikimoriAnime(data));
  }

  static Future<List<Character>> fetchCharacters(int animeId) async {
    final url = Uri.parse('https://shikimori.one/api/animes/$animeId/roles');
    final response = await http.get(url, headers: _headers);

    if (response.statusCode != 200) {
      throw Exception('Не удалось загрузить персонажей');
    }

    final List data = json.decode(response.body);
    return data.map((e) {
      final char = e['character'] ?? {};
      final image = char['image'];
      String imageUrl = 'https://shikimori.one/images/static/noimage.png';
      if (image != null) {
        imageUrl = image['original'] ?? image['preview'] ?? image['x96'] ?? image['x48'] ?? imageUrl;
        if (!imageUrl.startsWith('http')) imageUrl = 'https://shikimori.one$imageUrl';
      }

      return Character(
        id: char['id'] ?? 0,
        name: char['name'] ?? 'Без имени',
        imageUrl: imageUrl,
      );
    }).toList();
  }

  static Future<List<Anime>> fetchFranchise(int animeId) async {
    final url = Uri.parse('$_baseUrl/animes/$animeId/franchise');
    final response = await http.get(url, headers: _headers);

    if (response.statusCode != 200) {
      throw Exception('Не удалось загрузить франшизу');
    }

    final data = json.decode(response.body);
    final List nodes = data['nodes'] ?? [];

    // Безопасная сортировка с обработкой null и разных типов
    try {
      nodes.sort((a, b) {
        // Безопасное извлечение года из даты
        final yearA = _extractYearFromDate(a['date']);
        final yearB = _extractYearFromDate(b['date']);
        
        return yearA.compareTo(yearB);
      });
    } catch (e) {
      print('⚠️ Ошибка при сортировке франшизы: $e');
      // Продолжаем без сортировки в случае ошибки
    }

    return nodes.map((node) => Anime.fromJson(_mapShikimoriAnime(node))).toList();
  }

  /// Безопасное извлечение года из даты
  static int _extractYearFromDate(dynamic date) {
    if (date == null) return 0;
    
    try {
      if (date is String) {
        final dateTime = DateTime.tryParse(date);
        return dateTime?.year ?? 0;
      } else if (date is int) {
        // Если дата представлена как timestamp
        final dateTime = DateTime.fromMillisecondsSinceEpoch(date * 1000);
        return dateTime.year;
      }
    } catch (e) {
      print('⚠️ Ошибка при парсинге даты: $date, ошибка: $e');
    }
    
    return 0;
  }

  static Map<String, dynamic> _mapShikimoriAnime(Map<String, dynamic> json) {
    String? imageUrl;
    final image = json['image'];
    if (image != null) {
      imageUrl = image['original'] ?? image['preview'] ?? image['x96'] ?? image['x48'];
      if (imageUrl != null && !imageUrl.startsWith('https')) {
        imageUrl = 'https://shikimori.one$imageUrl';
      }
    }

    // Безопасное извлечение жанров
    List<String> genres = [];
    if (json['genres'] != null && json['genres'] is List) {
      for (final genre in json['genres']) {
        if (genre is Map) {
          final name = genre['russian'] ?? genre['name'];
          if (name is String && name.isNotEmpty) {
            genres.add(name);
          }
        }
      }
    }

    // Безопасное извлечение тем
    List<String> themes = [];
    if (json['themes'] != null && json['themes'] is List) {
      for (final theme in json['themes']) {
        if (theme is Map) {
          final name = theme['russian'] ?? theme['name'];
          if (name is String && name.isNotEmpty) {
            themes.add(name);
          }
        }
      }
    }

    return {
      'mal_id': json['id'],
      'title': json['russian'] ?? json['name'] ?? 'Без названия',
      'images': {
        'jpg': {'image_url': imageUrl ?? 'https://shikimori.one/images/static/noimage.png'}
      },
      'synopsis': json['description'] ?? 'Описание отсутствует',
      'score': json['score'] ?? 0.0,
      'episodes': json['episodes'] ?? 0,
      'type': json['kind'] ?? 'TV',
      'year': json['released_on'] != null
          ? DateTime.tryParse(json['released_on'])?.year
          : null,
      'genres': genres,
      'themes': themes,
    };
  }
}