// lib/models/franchise_group.dart
import 'anime.dart';
import 'package:hive/hive.dart';

class FranchiseGroup {
  final int id;
  final String title;
  List<Anime> animes; // Изменено на изменяемый список
  final String imageUrl;

  // Локальные поля
  String status;
  bool isFavorite;
  double? score;
  String review;
  Map<int, bool> watchedAnimes; // malId -> isWatched

  FranchiseGroup({
    required this.id,
    required this.title,
    required this.animes,
    required this.imageUrl,
    this.status = 'Планирую',
    this.isFavorite = false,
    this.score,
    this.review = '',
    this.watchedAnimes = const {},
  });

  factory FranchiseGroup.fromMap(Map<String, dynamic> map) {
    try {
      // Конвертируем ID в int
      int id;
      final idVal = map['id'];
      if (idVal is int) {
        id = idVal;
      } else if (idVal is String) {
        id = int.tryParse(idVal.replaceAll('franchise_', '')) ?? 
             DateTime.now().millisecondsSinceEpoch;
      } else {
        id = DateTime.now().millisecondsSinceEpoch;
      }
      
      // Получаем изображение из map или из первого аниме
      String imageUrl = '';
      if (map['imageUrl'] is String && (map['imageUrl'] as String).isNotEmpty) {
        imageUrl = map['imageUrl'] as String;
      } else {
        final animesList = _parseAnimeList(map['animes']);
        if (animesList.isNotEmpty) {
          imageUrl = animesList.first.imageUrl;
        }
      }

      final animesList = _parseAnimeList(map['animes']);

      return FranchiseGroup(
        id: id,
        title: (map['title'] is String ? map['title'] : 'Неизвестная франшиза') as String,
        animes: animesList,
        imageUrl: imageUrl,
        status: (map['status'] is String ? map['status'] : 'Планирую') as String,
        isFavorite: map['isFavorite'] is bool ? map['isFavorite'] as bool : false,
        score: _parseScore(map['score']),
        review: (map['review'] is String ? map['review'] : '') as String,
        watchedAnimes: map['watchedAnimes'] is Map 
            ? Map<int, bool>.from((map['watchedAnimes'] as Map).map(
                (k, v) => MapEntry(int.tryParse(k.toString()) ?? 0, v == true)))
            : {},
      );
    } catch (e) {
      print('Критическая ошибка при десериализации FranchiseGroup: $e, map: $map');
      rethrow;
    }
  }

  static List<Anime> _parseAnimeList(dynamic list) {
    if (list is! List) return [];
    return list
        .map((x) {
          try {
            if (x is Map) {
              return Anime.fromMap(x.cast<String, dynamic>());
            }
            return null;
          } catch (e) {
            print('Ошибка при загрузке аниме: $e');
            return null;
          }
        })
        .whereType<Anime>()
        .toList();
  }

  static double? _parseScore(dynamic score) {
    if (score == null) return null;
    if (score is num) return score.toDouble();
    if (score is String) return double.tryParse(score);
    return null;
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'title': title,
      'animes': animes.map((x) => x.toMap()).toList(),
      'imageUrl': imageUrl,
      'status': status,
      'isFavorite': isFavorite,
      'score': score,
      'review': review,
      'watchedAnimes': watchedAnimes,
      'isGroup': true,
    };
  }

  // Геттеры для удобства
  int get totalEpisodes => animes.fold(0, (sum, anime) => sum + (anime.episodes ?? 0));
  
  int get watchedEpisodes {
    int total = 0;
    for (final anime in animes) {
      if (watchedAnimes[anime.malId] == true) {
        // Добавляем безопасную проверку
        final episodes = anime.episodes ?? 0;
        total += episodes;
        print('📺 Anime ${anime.malId}: ${anime.title} - episodes: $episodes, watched: ${watchedAnimes[anime.malId]}');
      }
    }
    print('🎯 Total watched episodes calculated: $total');
    return total;
  }

  int get watchedAnimesCount {
    return watchedAnimes.values.where((watched) => watched == true).length;
  }

  List<String>? get genres => animes.isNotEmpty ? animes.first.genres : null;

  // Методы для управления просмотренными аниме
  void toggleWatched(int malId) {
    final currentValue = watchedAnimes[malId] ?? false;
    watchedAnimes[malId] = !currentValue;
    print('🔄 Toggled anime $malId from $currentValue to ${!currentValue}');
  }

  bool isAnimeWatched(int malId) {
    return watchedAnimes[malId] == true;
  }

  /// Возвращает отсортированный список аниме по типу и году выхода
  /// TV сезоны → Фильмы → OVA/Специальное
  List<Anime> get sortedAnimes {
    final sorted = List<Anime>.from(animes);
    sorted.sort((a, b) {
      // Сначала сортируем по типу
      final typeOrderA = _getTypeOrder(a.type ?? a.kind ?? 'Unknown');
      final typeOrderB = _getTypeOrder(b.type ?? b.kind ?? 'Unknown');
      
      if (typeOrderA != typeOrderB) {
        return typeOrderA.compareTo(typeOrderB);
      }
      
      // Если типы одинаковые, сортируем по году
      final yearA = _extractYear(a);
      final yearB = _extractYear(b);
      
      return yearA.compareTo(yearB);
    });
    return sorted;
  }

  /// Определяет приоритет типа аниме для сортировки
  int _getTypeOrder(String type) {
    final normalized = type.toLowerCase();
    if (normalized.contains('tv') || normalized.contains('tv series')) return 0;
    if (normalized.contains('movie')) return 1;
    if (normalized.contains('ova')) return 2;
    if (normalized.contains('special')) return 3;
    if (normalized.contains('ona')) return 4;
    return 5;
  }

  /// Извлекает год выхода аниме
  int _extractYear(Anime anime) {
    // Временная реализация - возвращаем 0
    // Позже можно добавить поле year в модель Anime
    return 0;
  }
}

// Ручной Hive адаптер
class FranchiseGroupAdapter extends TypeAdapter<FranchiseGroup> {
  @override
  final int typeId = 2;

  @override
  FranchiseGroup read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    return FranchiseGroup(
      id: fields[0] as int,
      title: fields[1] as String,
      animes: (fields[2] as List).cast<Anime>(),
      imageUrl: fields[7] as String,
      status: fields[3] as String,
      isFavorite: fields[4] as bool,
      score: fields[5] as double?,
      review: fields[6] as String,
      watchedAnimes: Map<int, bool>.from(fields[8] as Map),
    );
  }

  @override
  void write(BinaryWriter writer, FranchiseGroup obj) {
    writer
      ..writeByte(9) // Увеличиваем на 1 для watchedAnimes
      ..writeByte(0)
      ..write(obj.id)
      ..writeByte(1)
      ..write(obj.title)
      ..writeByte(2)
      ..write(obj.animes)
      ..writeByte(3)
      ..write(obj.status)
      ..writeByte(4)
      ..write(obj.isFavorite)
      ..writeByte(5)
      ..write(obj.score)
      ..writeByte(6)
      ..write(obj.review)
      ..writeByte(7)
      ..write(obj.imageUrl)
      ..writeByte(8)
      ..write(obj.watchedAnimes);
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is FranchiseGroupAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}