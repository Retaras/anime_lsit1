import 'package:hive/hive.dart';
import '../models/achievement.dart'; // Правильный путь

class AchievementHelper {
  static Future<void> checkAndShowAchievements() async {
    try {
      final allAchievements = Achievement.generateAll();
      final box = await Hive.openBox('achievementsBox');
      final unlockedIds = Set<String>.from(box.get('unlockedIds', defaultValue: <String>[]));
      
      await Achievement.checkAllAchievements(allAchievements, unlockedIds, box);
    } catch (e) {
      print('Ошибка при проверке достижений: $e');
    }
  }

  /// Получить список всех разблокированных достижений
  static Future<List<Achievement>> getUnlockedAchievements() async {
    try {
      final box = await Hive.openBox('achievementsBox');
      final unlockedIds = Set<String>.from(box.get('unlockedIds', defaultValue: <String>[]));
      final allAchievements = Achievement.generateAll();
      
      return allAchievements.where((achievement) => unlockedIds.contains(achievement.id)).toList();
    } catch (e) {
      print('Ошибка при получении разблокированных достижений: $e');
      return [];
    }
  }

  /// Получить список всех достижений с информацией о статусе разблокировки
  static Future<List<Achievement>> getAllAchievementsWithStatus() async {
    try {
      final box = await Hive.openBox('achievementsBox');
      final unlockedIds = Set<String>.from(box.get('unlockedIds', defaultValue: <String>[]));
      final allAchievements = Achievement.generateAll();
      
      // Обновляем статус каждого достижения
      for (final achievement in allAchievements) {
        achievement.isUnlocked = unlockedIds.contains(achievement.id);
      }
      
      return allAchievements;
    } catch (e) {
      print('Ошибка при получении достижений: $e');
      return [];
    }
  }

  /// Сбросить все достижения (для тестирования)
  static Future<void> resetAllAchievements() async {
    try {
      final box = await Hive.openBox('achievementsBox');
      await box.put('unlockedIds', <String>[]);
    } catch (e) {
      print('Ошибка при сбросе достижений: $e');
    }
  }

  /// Получить количество разблокированных достижений
  static Future<int> getUnlockedCount() async {
    try {
      final box = await Hive.openBox('achievementsBox');
      final unlockedIds = Set<String>.from(box.get('unlockedIds', defaultValue: <String>[]));
      return unlockedIds.length;
    } catch (e) {
      print('Ошибка при получении количества достижений: $e');
      return 0;
    }
  }

  /// Получить общее количество достижений
  static int getTotalAchievementsCount() {
    return Achievement.generateAll().length;
  }

  /// Закрыть Hive box при необходимости
  static Future<void> close() async {
    try {
      await Hive.close();
    } catch (e) {
      print('Ошибка при закрытии Hive: $e');
    }
  }
}