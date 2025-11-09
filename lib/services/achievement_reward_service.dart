import 'package:hive/hive.dart';
import 'card_game_service.dart';

class AchievementRewardService {
  static final AchievementRewardService _instance = AchievementRewardService._internal();
  factory AchievementRewardService() => _instance;
  AchievementRewardService._internal();

  // Метод для выдачи награды за достижение
  static Future<void> grantReward(int coins) async {
    try {
      // Основное добавление монет через карточную игру
      await CardGameService.addCoins(coins);
      
      // Дополнительно можно сохранить в историю наград
      final box = await Hive.openBox('achievementRewards');
      final rewards = box.get('rewards', defaultValue: <Map<String, dynamic>>[]);
      rewards.add({
        'coins': coins,
        'date': DateTime.now().toIso8601String(),
      });
      await box.put('rewards', rewards);

      print('Награда выдана: $coins монет');
    } catch (e) {
      print('Ошибка при выдаче награды: $e');
    }
  }

  // Метод для получения текущего баланса
  static Future<int> getBalance() async {
    try {
      return await CardGameService.getCoins();
    } catch (e) {
      print('Ошибка при получении баланса: $e');
      return 0;
    }
  }

  // Метод для траты монет
  static Future<bool> spendCoins(int amount) async {
    try {
      return await CardGameService.spendCoins(amount);
    } catch (e) {
      print('Ошибка при трате монет: $e');
      return false;
    }
  }

  // Метод для получения истории наград
  static Future<List<Map<String, dynamic>>> getRewardsHistory() async {
    try {
      final box = await Hive.openBox('achievementRewards');
      final rewards = box.get('rewards', defaultValue: <Map<String, dynamic>>[]);
      return List<Map<String, dynamic>>.from(rewards);
    } catch (e) {
      print('Ошибка при получении истории наград: $e');
      return [];
    }
  }

  // Метод для получения общей суммы полученных наград
  static Future<int> getTotalRewardsReceived() async {
    try {
      final rewards = await getRewardsHistory();
      int total = 0;
      for (final reward in rewards) {
        total += (reward['coins'] as int);
      }
      return total;
    } catch (e) {
      print('Ошибка при подсчете общей суммы наград: $e');
      return 0;
    }
  }

  // Метод для очистки истории наград (для тестирования)
  static Future<void> clearRewardsHistory() async {
    try {
      final box = await Hive.openBox('achievementRewards');
      await box.put('rewards', <Map<String, dynamic>>[]);
    } catch (e) {
      print('Ошибка при очистке истории наград: $e');
    }
  }
}