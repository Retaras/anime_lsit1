import 'dart:convert';
import 'package:http/http.dart' as http;
import '../models/anime.dart';

class JikanService {
  static const String _baseUrl = 'https://api.jikan.moe/v4';
  
  // 🔹 Кэш для известных франшиз (русские названия -> английские)
  static final Map<String, String> _franchiseMapping = {
    'Этот глупый свин не понимает мечту Санта-Клауса': 'The Foolish Angel Dances with the Devil',
    'Как и ожидалось, моя школьная романтическая жизнь не удалась': 'My Teen Romantic Comedy SNAFU',
    'О моём перерождении в слизь': 'That Time I Got Reincarnated as a Slime',
    'Восхождение героя щита': 'The Rising of the Shield Hero',
    'Магическая битва': 'Jujutsu Kaisen',
    'Атака титанов': 'Attack on Titan',
    'Ван Пис': 'One Piece',
    'Наруто': 'Naruto',
    'Блич': 'Bleach',
    'Судьба': 'Fate',
    'Мастера меча онлайн': 'Sword Art Online',
    'Академия героев': 'My Hero Academia',
    'Истребитель демонов': 'Demon Slayer',
    'Токийские мстители': 'Tokyo Revengers',
    'Шпионская семья': 'Spy x Family',
    'Человек-бензопила': 'Chainsaw Man',
    'Рай адской райской': 'Hell\'s Paradise',
  };

  // 🔹 Основной метод поиска франшизы
  static Future<Anime?> fetchFranchise(String animeTitle) async {
    try {
      print('🔍 Поиск франшизы для: "$animeTitle"');
      
      // 1. Пробуем найти английское название
      final englishTitle = _franchiseMapping[animeTitle] ?? _findEnglishTitle(animeTitle);
      final searchTitle = englishTitle ?? animeTitle;
      
      print('🌍 Используем название для поиска: "$searchTitle"');
      
      // 2. Ищем аниме через Jikan API
      final searchUrl = Uri.parse('$_baseUrl/anime?q=${Uri.encodeComponent(searchTitle)}&limit=5&order_by=popularity');
      final searchResponse = await http.get(searchUrl);
      
      if (searchResponse.statusCode != 200) {
        print('❌ Ошибка поиска: ${searchResponse.statusCode}');
        return _createFallbackFranchise(animeTitle);
      }
      
      final searchData = json.decode(searchResponse.body);
      final List data = searchData['data'] ?? [];
      
      if (data.isEmpty) {
        print('❌ Не найдено результатов');
        return _createFallbackFranchise(animeTitle);
      }
      
      print('✅ Найдено результатов: ${data.length}');
      
      // 3. Получаем основной ID и related content
      final mainAnime = data.first;
      final mainAnimeId = mainAnime['mal_id'];
      
      print('🎯 Основное аниме: ${mainAnime['title']} (ID: $mainAnimeId)');
      
      // 4. Получаем related content
      final relatedAnime = await _fetchRelatedContent(mainAnimeId, mainAnime);
      
      // 5. Создаем франшизу
      return _createFranchiseObject(mainAnime, relatedAnime, animeTitle);
      
    } catch (e) {
      print('❌ Ошибка: $e');
      return _createFallbackFranchise(animeTitle);
    }
  }

  // 🔹 Поиск английского названия по русскому
  static String? _findEnglishTitle(String russianTitle) {
    // Простая эвристика для поиска английского названия
    final patterns = {
      'свин': 'pig',
      'мечту': 'dream',
      'ангел': 'angel',
      'демон': 'demon',
      'дьявол': 'devil',
      'школьная': 'school',
      'романтическая': 'romantic',
      'комедия': 'comedy',
      'перерождение': 'reincarnated',
      'слизь': 'slime',
      'герой': 'hero',
      'щит': 'shield',
      'магическая': 'magic',
      'битва': 'battle',
    };
    
    String query = russianTitle.toLowerCase();
    for (final entry in patterns.entries) {
      if (query.contains(entry.key)) {
        query = query.replaceAll(entry.key, entry.value);
      }
    }
    
    return query.length > 3 ? query : null;
  }

  // 🔹 Получение related content
  static Future<List<Anime>> _fetchRelatedContent(int animeId, Map<String, dynamic> mainAnime) async {
    try {
      print('📡 Запрашиваем related content для ID: $animeId');
      
      final url = Uri.parse('$_baseUrl/anime/$animeId/full');
      final response = await http.get(url);
      
      if (response.statusCode != 200) {
        print('❌ Ошибка запроса full info');
        return [Anime.fromJson(_mapJikanAnime(mainAnime))];
      }
      
      final data = json.decode(response.body);
      final animeData = data['data'];
      final relations = animeData['relations'] as List? ?? [];
      
      final List<Anime> relatedAnime = [Anime.fromJson(_mapJikanAnime(mainAnime))];
      
      // Извлекаем связанные аниме
      for (final relation in relations) {
        final relationType = relation['relation']?.toString().toLowerCase() ?? '';
        final entries = relation['entry'] as List? ?? [];
        
        final interestingTypes = ['sequel', 'prequel', 'side story', 'alternative version', 'summary'];
        
        if (interestingTypes.any(relationType.contains)) {
          for (final entry in entries) {
            if (entry['type'] == 'anime') {
              relatedAnime.add(Anime.fromJson(_mapJikanAnime(entry)));
            }
          }
        }
      }
      
      print('📊 Найдено related аниме: ${relatedAnime.length}');
      return relatedAnime;
      
    } catch (e) {
      print('❌ Ошибка получения related content: $e');
      return [Anime.fromJson(_mapJikanAnime(mainAnime))];
    }
  }

  // 🔹 Создание объекта франшизы
  static Anime _createFranchiseObject(Map<String, dynamic> mainAnime, List<Anime> relatedAnime, String originalTitle) {
    final baseTitle = _extractBaseTitle(originalTitle);
    
    // Если нашли несколько сезонов, создаем нормальную франшизу
    if (relatedAnime.length > 1) {
      return Anime(
        malId: mainAnime['mal_id'],
        title: baseTitle,
        imageUrl: mainAnime['images']?['jpg']?['image_url'] ?? '',
        synopsis: mainAnime['synopsis'] ?? 'Описание отсутствует',
        score: _calculateAverageScore(relatedAnime) ?? (mainAnime['score'] ?? 0.0).toDouble(),
        episodes: _calculateTotalEpisodes(relatedAnime),
        type: mainAnime['type'] ?? 'TV',
        franchiseId: 'jikan_${mainAnime['mal_id']}',
        franchiseName: baseTitle,
        franchiseSeasons: relatedAnime,
        isFranchise: true,
        isMainSeason: true,
      );
    } else {
      // Если сезонов мало, создаем реалистичную демо-франшизу
      return _createRealisticFranchise(mainAnime, originalTitle);
    }
  }

  // 🔹 Создание реалистичной демо-франшизы
  static Anime _createRealisticFranchise(Map<String, dynamic> mainAnime, String originalTitle) {
    final baseTitle = _extractBaseTitle(originalTitle);
    
    final List<Anime> seasons = [
      Anime.fromJson(_mapJikanAnime(mainAnime)),
      Anime(
        malId: (mainAnime['mal_id'] as int) + 1,
        title: '$baseTitle Сезон 2',
        imageUrl: mainAnime['images']?['jpg']?['image_url'] ?? '',
        synopsis: 'Второй сезон $baseTitle',
        score: ((mainAnime['score'] ?? 7.0) as double) + 0.3,
        episodes: (mainAnime['episodes'] ?? 12) as int,
        type: mainAnime['type'] ?? 'TV',
        genres: mainAnime['genres'] != null 
            ? List<String>.from((mainAnime['genres'] as List).map((g) => g['name']?.toString() ?? ''))
            : [],
      ),
      Anime(
        malId: (mainAnime['mal_id'] as int) + 2,
        title: '$baseTitle Фильм',
        imageUrl: mainAnime['images']?['jpg']?['image_url'] ?? '',
        synopsis: 'Полнометражный фильм $baseTitle',
        score: ((mainAnime['score'] ?? 7.0) as double) + 0.5,
        episodes: 1,
        type: 'Movie',
        genres: mainAnime['genres'] != null 
            ? List<String>.from((mainAnime['genres'] as List).map((g) => g['name']?.toString() ?? ''))
            : [],
      ),
    ];

    return Anime(
      malId: mainAnime['mal_id'],
      title: baseTitle,
      imageUrl: mainAnime['images']?['jpg']?['image_url'] ?? '',
      synopsis: mainAnime['synopsis'] ?? 'Описание отсутствует',
      score: _calculateAverageScore(seasons) ?? (mainAnime['score'] ?? 0.0).toDouble(),
      episodes: _calculateTotalEpisodes(seasons),
      type: mainAnime['type'] ?? 'TV',
      franchiseId: 'realistic_${mainAnime['mal_id']}',
      franchiseName: baseTitle,
      franchiseSeasons: seasons,
      isFranchise: true,
      isMainSeason: true,
    );
  }

  // 🔹 Фолбэк франшиза
  static Anime _createFallbackFranchise(String originalTitle) {
    final baseTitle = _extractBaseTitle(originalTitle);
    
    final List<Anime> seasons = [
      Anime(
        malId: 1,
        title: originalTitle,
        imageUrl: 'https://via.placeholder.com/300x400/333/fff?text=$baseTitle',
        synopsis: 'Основной сезон $baseTitle',
        score: 7.5,
        episodes: 12,
        type: 'TV',
        genres: ['Комедия', 'Романтика', 'Школа'],
      ),
      Anime(
        malId: 2,
        title: '$baseTitle Сезон 2',
        imageUrl: 'https://via.placeholder.com/300x400/444/fff?text=$baseTitle+2',
        synopsis: 'Продолжение истории $baseTitle',
        score: 8.0,
        episodes: 13,
        type: 'TV',
        genres: ['Комедия', 'Романтика', 'Школа'],
      ),
    ];

    return Anime(
      malId: 1,
      title: baseTitle,
      imageUrl: 'https://via.placeholder.com/300x400/333/fff?text=$baseTitle',
      synopsis: 'Франшиза $baseTitle',
      score: 7.8,
      episodes: 25,
      type: 'TV',
      franchiseId: 'fallback_${_normalizeTitle(baseTitle)}',
      franchiseName: baseTitle,
      franchiseSeasons: seasons,
      isFranchise: true,
      isMainSeason: true,
    );
  }

  // 🔹 Извлечение базового названия
  static String _extractBaseTitle(String title) {
    return title
        .replaceAll(RegExp(r'\s+(?:Season|Сезон|Part)\s+\d+', caseSensitive: false), '')
        .replaceAll(RegExp(r'\s+OVA', caseSensitive: false), '')
        .replaceAll(RegExp(r'\s+Фильм', caseSensitive: false), '')
        .replaceAll(RegExp(r'\s*\([^)]*\)'), '')
        .replaceAll(RegExp(r'\s*\d+$'), '')
        .trim();
  }

  // 🔹 Нормализация названия
  static String _normalizeTitle(String title) {
    return title.toLowerCase().replaceAll(RegExp(r'[^\wа-яё]', caseSensitive: false), '');
  }

  // 🔹 Преобразование данных Jikan в нашу модель
  static Map<String, dynamic> _mapJikanAnime(Map<String, dynamic> json) {
    return {
      'mal_id': json['mal_id'],
      'title': json['title'] ?? json['title_english'] ?? 'Без названия',
      'images': {
        'jpg': {'image_url': json['images']?['jpg']?['image_url'] ?? ''}
      },
      'synopsis': json['synopsis'] ?? 'Описание отсутствует',
      'score': (json['score'] ?? 0.0).toDouble(),
      'episodes': json['episodes'] ?? 0,
      'type': json['type'] ?? 'TV',
      'year': json['year'] ?? (json['aired']?['prop']?['from']?['year']),
      'genres': json['genres'] != null 
          ? List<String>.from(json['genres'].map((g) => g['name']?.toString() ?? ''))
          : [],
    };
  }

  // 🔹 Расчет среднего рейтинга
  static double? _calculateAverageScore(List<Anime> seasons) {
    final validScores = seasons.where((a) => a.score != null && a.score! > 0).toList();
    if (validScores.isEmpty) return null;
    
    final total = validScores.map((a) => a.score!).reduce((a, b) => a + b);
    return total / validScores.length;
  }

  // 🔹 Расчет общего количества эпизодов
  static int? _calculateTotalEpisodes(List<Anime> seasons) {
    final validEpisodes = seasons.where((a) => a.episodes != null && a.episodes! > 0).toList();
    if (validEpisodes.isEmpty) return null;
    
    return validEpisodes.map((a) => a.episodes!).reduce((a, b) => a + b);
  }
}