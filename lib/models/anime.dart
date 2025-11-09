import 'package:flutter/foundation.dart';

class Anime {
  final int malId;
  final String title;
  final String imageUrl;
  final String? synopsis;
  double? score;
  final int? episodes;
  final List<String>? genres;
  final List<String>? themes;
  final String? duration;
  final String? source;
  final List<String>? sequels;
  final String? orderInSeries;
  final String? type;
  final String? kind;
  final String? rating;
  final String? airStatus;
  final List<Map<String, dynamic>>? related;
  
  // Поля для группировки
  final String? franchiseId;
  final String? franchiseName;
  final List<Anime>? franchiseSeasons;
  final bool isFranchise;
  final bool isMainSeason;

  // Изменяемые поля (локальные)
  String status;
  bool isFavorite;
  int watchedEpisodes;
  bool isExpanded;

  Anime({
    required this.malId,
    required this.title,
    required this.imageUrl,
    this.synopsis,
    this.score,
    this.episodes,
    this.genres,
    this.themes,
    this.duration,
    this.source,
    this.sequels,
    this.orderInSeries,
    this.type,
    this.kind,
    this.rating,
    this.airStatus,
    this.related,
    this.franchiseId,
    this.franchiseName,
    this.franchiseSeasons,
    this.isFranchise = false,
    this.isMainSeason = true,
    this.status = 'Планирую',
    this.isFavorite = false,
    this.watchedEpisodes = 0,
    this.isExpanded = false,
  });

  /// Создание из JSON (API)
  factory Anime.fromJson(Map<String, dynamic> json) {
    try {
      // Извлекаем URL изображения
      String? imageUrl = json['images']?['jpg']?['image_url'] ??
          json['image']?['original'] ??
          json['image']?['preview'] ??
          json['imageUrl'];

      if (imageUrl == null || imageUrl.isEmpty) {
        imageUrl = 'https://shikimori.one/images/static/noimage.png';
      } else if (imageUrl.startsWith('/')) {
        imageUrl = 'https://shikimori.one$imageUrl';
      }

      return Anime(
        malId: _parseInt(json['mal_id'] ?? json['id'] ?? 0),
        title: _parseString(json['title'] ?? json['russian'] ?? json['name'] ?? 'Неизвестное аниме') ?? 'Неизвестное аниме',
        imageUrl: imageUrl,
        synopsis: _parseString(json['synopsis'] ?? json['description']),
        score: _parseScore(json['score']),
        episodes: _parseInt(json['episodes']),
        genres: _parseGenreList(json['genres']),
        themes: _parseGenreList(json['themes']),
        duration: _parseString(json['duration'] ?? json['duration_minutes']),
        source: _parseString(json['source']),
        sequels: _parseStringList(json['sequels']),
        orderInSeries: _parseString(json['order_in_series']),
        type: _parseString(json['type']),
        kind: _parseString(json['kind']),
        rating: _parseString(json['rating']),
        airStatus: _parseString(json['status'] ?? json['air_status']),
        related: (json['related'] is List)
            ? List<Map<String, dynamic>>.from(json['related'])
            : json['related_list'] is List
                ? List<Map<String, dynamic>>.from(json['related_list'])
                : [],
        franchiseId: _parseString(json['franchiseId']),
        franchiseName: _parseString(json['franchiseName']),
        franchiseSeasons: json['franchiseSeasons'] is List
            ? List<Anime>.from(
                json['franchiseSeasons']
                    .map((x) {
                      try {
                        return Anime.fromJson(x is Map ? x.cast<String, dynamic>() : {});
                      } catch (e) {
                        debugPrint('Ошибка при загрузке сезона: $e');
                        return null;
                      }
                    })
                    .whereType<Anime>())
            : null,
        isFranchise: json['isFranchise'] == true,
        isMainSeason: json['isMainSeason'] != false,
        status: _parseString(json['status']) ?? 'Планирую',
        isFavorite: json['isFavorite'] == true,
        watchedEpisodes: _parseInt(json['watchedEpisodes']),
      );
    } catch (e) {
      debugPrint('Ошибка при десериализации Anime из JSON: $e');
      rethrow;
    }
  }

  /// Создание из Hive (Map)
  factory Anime.fromMap(Map<String, dynamic> map) {
    try {
      // Безопасная конвертация malId
      final malId = _parseInt(map['malId'] ?? map['mal_id'] ?? map['id'] ?? 0);

      // Конвертируем imageUrl
      var imageUrl = _parseString(map['imageUrl']);
      if (imageUrl == null || imageUrl.isEmpty) {
        imageUrl = 'https://shikimori.one/images/static/noimage.png';
      }

      return Anime(
        malId: malId,
        title: _parseString(map['title']) ?? 'Неизвестное аниме',
        imageUrl: imageUrl,
        synopsis: _parseString(map['synopsis']),
        score: _parseScore(map['score']),
        episodes: _parseInt(map['episodes']),
        genres: _parseStringList(map['genres']),
        themes: _parseStringList(map['themes']),
        duration: _parseString(map['duration']),
        source: _parseString(map['source']),
        sequels: _parseStringList(map['sequels']),
        orderInSeries: _parseString(map['orderInSeries']),
        type: _parseString(map['type']),
        kind: _parseString(map['kind']),
        rating: _parseString(map['rating']),
        airStatus: _parseString(map['airStatus']),
        related: (map['related'] is List)
            ? List<Map<String, dynamic>>.from(map['related'])
            : [],
        franchiseId: _parseString(map['franchiseId']),
        franchiseName: _parseString(map['franchiseName']),
        franchiseSeasons: map['franchiseSeasons'] is List
            ? List<Anime>.from(
                map['franchiseSeasons']
                    .map((x) {
                      try {
                        return Anime.fromMap(x is Map ? x.cast<String, dynamic>() : {});
                      } catch (e) {
                        debugPrint('Ошибка при загрузке сезона: $e');
                        return null;
                      }
                    })
                    .whereType<Anime>())
            : null,
        isFranchise: map['isFranchise'] == true,
        isMainSeason: map['isMainSeason'] != false,
        status: _parseString(map['status']) ?? 'Планирую',
        isFavorite: map['isFavorite'] == true,
        watchedEpisodes: _parseInt(map['watchedEpisodes']),
      );
    } catch (e) {
      debugPrint('Ошибка при десериализации Anime из Map: $e, map: $map');
      rethrow;
    }
  }

  /// Конвертация в Map для сохранения в Hive
  Map<String, dynamic> toMap() {
    return {
      'malId': malId,
      'title': title,
      'imageUrl': imageUrl,
      'synopsis': synopsis,
      'score': score,
      'episodes': episodes,
      'genres': genres,
      'themes': themes,
      'duration': duration,
      'source': source,
      'sequels': sequels,
      'orderInSeries': orderInSeries,
      'type': type,
      'kind': kind,
      'rating': rating,
      'airStatus': airStatus,
      'related': related,
      'franchiseId': franchiseId,
      'franchiseName': franchiseName,
      'franchiseSeasons': franchiseSeasons?.map((x) => x.toMap()).toList(),
      'isFranchise': isFranchise,
      'isMainSeason': isMainSeason,
      'status': status,
      'isFavorite': isFavorite,
      'watchedEpisodes': watchedEpisodes,
    };
  }

  // ============ Вспомогательные методы парсинга ============

  /// Безопасный парс строки
  static String? _parseString(dynamic value) {
    if (value == null) return null;
    if (value is String) return value.isEmpty ? null : value;
    return value.toString();
  }

  /// Безопасный парс целого числа
  static int _parseInt(dynamic value) {
    if (value == null) return 0;
    if (value is int) return value;
    if (value is double) return value.toInt();
    if (value is String) return int.tryParse(value) ?? 0;
    return 0;
  }

  /// Безопасный парс рейтинга (double)
  static double? _parseScore(dynamic score) {
    if (score == null) return null;
    if (score is num) return score.toDouble();
    if (score is String) return double.tryParse(score);
    return null;
  }

  /// Парс списка жанров/тем из API
  static List<String>? _parseGenreList(dynamic list) {
    if (list == null) return null;
    if (list is! List) return null;
    
    final result = <String>[];
    for (final item in list) {
      if (item is Map) {
        final name = item['russian'] ?? item['name'];
        if (name is String && name.isNotEmpty) {
          result.add(name);
        }
      } else if (item is String && item.isNotEmpty) {
        result.add(item);
      }
    }
    return result.isEmpty ? null : result;
  }

  /// Парс простого списка строк
  static List<String>? _parseStringList(dynamic list) {
    if (list == null) return null;
    if (list is! List) return null;
    
    final result = <String>[];
    for (final item in list) {
      final str = _parseString(item);
      if (str != null) result.add(str);
    }
    return result.isEmpty ? null : result;
  }
}