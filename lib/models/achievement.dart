import 'package:hive/hive.dart';
import '../services/achievement_notification_service.dart';

part 'achievement.g.dart';

@HiveType(typeId: 0)
class Achievement {
  @HiveField(0)
  final String id;
  
  @HiveField(1)
  final String title;
  
  @HiveField(2)
  final String description;
  
  @HiveField(3)
  final String category;
  
  @HiveField(4)
  final String iconData;
  
  @HiveField(5)
  bool isUnlocked;
  
  @HiveField(6)
  DateTime? unlockedDate;
  
  // Поле оставлено для будущего использования
  @HiveField(7)
  final int coinReward;

  Achievement({
    required this.id,
    required this.title,
    required this.description,
    required this.category,
    required this.iconData,
    this.isUnlocked = false,
    this.unlockedDate,
    this.coinReward = 0, // По умолчанию 0
  });

  Achievement copyWith({
    bool? isUnlocked,
    DateTime? unlockedDate,
  }) {
    return Achievement(
      id: id,
      title: title,
      description: description,
      category: category,
      iconData: iconData,
      coinReward: coinReward,
      isUnlocked: isUnlocked ?? this.isUnlocked,
      unlockedDate: unlockedDate ?? this.unlockedDate,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'title': title,
      'description': description,
      'category': category,
      'iconData': iconData,
      'isUnlocked': isUnlocked,
      'unlockedDate': unlockedDate?.toIso8601String(),
      'coinReward': coinReward,
    };
  }

  factory Achievement.fromMap(Map<String, dynamic> map) {
    return Achievement(
      id: map['id'],
      title: map['title'],
      description: map['description'],
      category: map['category'],
      iconData: map['iconData'],
      isUnlocked: map['isUnlocked'] ?? false,
      unlockedDate: map['unlockedDate'] != null ? DateTime.parse(map['unlockedDate']) : null,
      coinReward: map['coinReward'] ?? 0,
    );
  }

  static List<Achievement> generateAll() {
    final allAchievements = [
      // 🟢 ОБЫЧНЫЕ (Первые шаги)
      Achievement(
        id: 'first_anime', 
        title: 'Первое в списке', 
        description: 'Добавьте первое аниме в свой список.', 
        category: 'ordinary', 
        iconData: 'add_circle',
        coinReward: 0,
      ),
      Achievement(
        id: 'first_favorite', 
        title: 'Мне нравится', 
        description: 'Добавьте первое аниме в избранное.', 
        category: 'ordinary', 
        iconData: 'favorite',
        coinReward: 0,
      ),
      Achievement(
        id: 'first_rating', 
        title: 'Критик-новичок', 
        description: 'Поставьте свою первую оценку аниме.', 
        category: 'ordinary', 
        iconData: 'star',
        coinReward: 0,
      ),
      Achievement(
        id: 'first_review', 
        title: 'Рецензент-дебютант', 
        description: 'Оставьте свой первый отзыв на аниме.', 
        category: 'ordinary', 
        iconData: 'rate_review',
        coinReward: 0,
      ),
      Achievement(
        id: 'status_change', 
        title: 'Всё решаемо', 
        description: 'Измените статус аниме впервые.', 
        category: 'ordinary', 
        iconData: 'swap_horiz',
        coinReward: 0,
      ),

      // 🔵 РЕДКИЕ (Небольшие усилия)
      Achievement(
        id: 'five_favorites', 
        title: 'Коллекционер', 
        description: 'Добавьте 5 аниме в избранное.', 
        category: 'rare', 
        iconData: 'favorite_list',
        coinReward: 0,
      ),
      Achievement(
        id: 'ten_ratings', 
        title: 'Опытный зритель', 
        description: 'Оцените 10 разных аниме.', 
        category: 'rare', 
        iconData: 'star_rate',
        coinReward: 0,
      ),
      Achievement(
        id: 'five_reviews', 
        title: 'Мыслитель', 
        description: 'Напишите 5 отзывов на аниме.', 
        category: 'rare', 
        iconData: 'comment',
        coinReward: 0,
      ),
      Achievement(
        id: 'all_statuses', 
        title: 'Исследователь', 
        description: 'Используйте каждый из 5 статусов хотя бы раз.', 
        category: 'rare', 
        iconData: 'checklist',
        coinReward: 0,
      ),

      // 🟣 ЭПИЧЕСКИЕ (Умеренный труд)
      Achievement(
        id: 'twenty_five_favorites', 
        title: 'Заядлый фанат', 
        description: 'Соберите 25 аниме в избранном.', 
        category: 'epic', 
        iconData: 'favorite_list',
        coinReward: 0,
      ),
      Achievement(
        id: 'fifty_ratings', 
        title: 'Мастер оценок', 
        description: 'Оцените 50 аниме.', 
        category: 'epic', 
        iconData: 'star_rate',
        coinReward: 0,
      ),
      Achievement(
        id: 'ten_reviews', 
        title: 'Опытный критик', 
        description: 'Напишите 10 отзывов.', 
        category: 'epic', 
        iconData: 'comment',
        coinReward: 0,
      ),
      Achievement(
        id: 'list_50', 
        title: 'Начинающий отаку', 
        description: 'В вашем списке 50 аниме.', 
        category: 'epic', 
        iconData: 'list_alt',
        coinReward: 0,
      ),

      // 🟠 ЛЕГЕНДАРНЫЕ (Высокие цели)
      Achievement(
        id: 'hundred_favorites', 
        title: 'Сердце отаку', 
        description: '100 аниме в избранном — это серьезно.', 
        category: 'legendary', 
        iconData: 'favorite_list',
        coinReward: 0,
      ),
      Achievement(
        id: 'hundred_ratings', 
        title: 'Критик мирового уровня', 
        description: 'Оцените 100 аниме.', 
        category: 'legendary', 
        iconData: 'star_rate',
        coinReward: 0,
      ),
      Achievement(
        id: 'twenty_five_reviews', 
        title: 'Философ 2D-мира', 
        description: 'Напишите 25 подробных отзывов.', 
        category: 'legendary', 
        iconData: 'comment',
        coinReward: 0,
      ),
      Achievement(
        id: 'list_100', 
        title: 'Знаток аниме', 
        description: 'Ваш список содержит 100 тайтлов.', 
        category: 'legendary', 
        iconData: 'list_alt',
        coinReward: 0,
      ),
      Achievement(
        id: 'all_favorites', 
        title: 'Люблю их всех!', 
        description: 'Добавьте в избранное каждое аниме из вашего списка.', 
        category: 'legendary', 
        iconData: 'favorite',
        coinReward: 0,
      ),

      // 🔴 БОЖЕСТВЕННЫЕ (Пиковые достижения)
      Achievement(
        id: 'two_hundred_favorites', 
        title: 'Бог избранного', 
        description: '200 аниме в избранном. Вау.', 
        category: 'divine', 
        iconData: 'favorite_list',
        coinReward: 0,
      ),
      Achievement(
        id: 'two_hundred_ratings', 
        title: 'Величайший критик', 
        description: 'Оцените 200 аниме.', 
        category: 'divine', 
        iconData: 'star_rate',
        coinReward: 0,
      ),
      Achievement(
        id: 'fifty_reviews', 
        title: 'Писатель-фантаст', 
        description: 'Напишите 50 отзывов.', 
        category: 'divine', 
        iconData: 'comment',
        coinReward: 0,
      ),
      Achievement(
        id: 'list_200', 
        title: 'Библиотекарь', 
        description: '200 аниме в вашем списке.', 
        category: 'divine', 
        iconData: 'list_alt',
        coinReward: 0,
      ),
      Achievement(
        id: 'perfectionist', 
        title: 'Перфекционист', 
        description: 'Оцените все аниме в вашем списке на 10/10.', 
        category: 'divine', 
        iconData: 'diamond',
        coinReward: 0,
      ),
      Achievement(
        id: 'all_achievements', 
        title: 'Легенда 2D', 
        description: 'Получите все остальные достижения.', 
        category: 'divine', 
        iconData: 'emoji_events',
        coinReward: 0,
      ),
    ];
    
    return allAchievements;
  }

  static Future<void> checkAllAchievements(
    List<Achievement> allAchievements,
    Set<String> unlockedIds,
    Box box,
  ) async {
    final myListBox = await Hive.openBox('myListBox');
    final allAnime = myListBox.values.map((item) => Map<String, dynamic>.from(item)).toList();

    // Сбор статистики
    final totalAnimeCount = allAnime.length;
    final favoritesCount = allAnime.where((a) => a['isFavorite'] == true).length;
    final ratingsCount = allAnime.where((a) => a['score'] != null && (a['score'] as int) > 0).length;
    final reviewsCount = allAnime.where((a) => a['review'] != null && (a['review'] as String).isNotEmpty).length;
    
    final usedStatuses = allAnime.map((a) => a['status'] as String? ?? '').toSet();
    final allTenRatings = allAnime.where((a) => a['score'] == 10).length;
    final isAllFavorites = totalAnimeCount > 0 && favoritesCount == totalAnimeCount;

    // Проверка достижений
    for (var achievement in allAchievements) {
      if (unlockedIds.contains(achievement.id)) continue;
      
      bool isUnlocked = false;
      
      switch (achievement.id) {
        // Обычные
        case 'first_anime': isUnlocked = totalAnimeCount >= 1; break;
        case 'first_favorite': isUnlocked = favoritesCount >= 1; break;
        case 'first_rating': isUnlocked = ratingsCount >= 1; break;
        case 'first_review': isUnlocked = reviewsCount >= 1; break;
        case 'status_change': isUnlocked = usedStatuses.length > 1; break;

        // Редкие
        case 'five_favorites': isUnlocked = favoritesCount >= 5; break;
        case 'ten_ratings': isUnlocked = ratingsCount >= 10; break;
        case 'five_reviews': isUnlocked = reviewsCount >= 5; break;
        case 'all_statuses': isUnlocked = usedStatuses.length >= 5; break;

        // Эпические
        case 'twenty_five_favorites': isUnlocked = favoritesCount >= 25; break;
        case 'fifty_ratings': isUnlocked = ratingsCount >= 50; break;
        case 'ten_reviews': isUnlocked = reviewsCount >= 10; break;
        case 'list_50': isUnlocked = totalAnimeCount >= 50; break;

        // Легендарные
        case 'hundred_favorites': isUnlocked = favoritesCount >= 100; break;
        case 'hundred_ratings': isUnlocked = ratingsCount >= 100; break;
        case 'twenty_five_reviews': isUnlocked = reviewsCount >= 25; break;
        case 'list_100': isUnlocked = totalAnimeCount >= 100; break;
        case 'all_favorites': isUnlocked = isAllFavorites; break;

        // Божественные
        case 'two_hundred_favorites': isUnlocked = favoritesCount >= 200; break;
        case 'two_hundred_ratings': isUnlocked = ratingsCount >= 200; break;
        case 'fifty_reviews': isUnlocked = reviewsCount >= 50; break;
        case 'list_200': isUnlocked = totalAnimeCount >= 200; break;
        case 'perfectionist': isUnlocked = totalAnimeCount > 0 && allTenRatings == totalAnimeCount; break;
        case 'all_achievements': isUnlocked = unlockedIds.length >= allAchievements.length - 1; break;
      }
      
      if (isUnlocked) {
        unlockedIds.add(achievement.id);
        achievement.isUnlocked = true;
        achievement.unlockedDate = DateTime.now();
        await box.put('${achievement.id}_date', achievement.unlockedDate!.toIso8601String());
        
        // Убрана выдача награды в виде монет
        
        // Показываем уведомление
        AchievementNotificationService.instance.show(achievement);
      }
    }
    
    // Сохраняем обновленный список ID
    await box.put('unlockedIds', unlockedIds.toList());
  }
  
  // Метод для сброса достижений
  static Future<void> resetAchievements() async {
    final box = await Hive.openBox('achievementsBox');
    await box.clear();
  }
}