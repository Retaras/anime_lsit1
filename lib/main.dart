import 'package:flutter/material.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'screens/loading_screen.dart';
import 'screens/main_screen.dart';
import 'services/achievement_notification_service.dart';
import 'models/franchise_group.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Инициализация Hive
  await Hive.initFlutter();
  
  // Регистрация адаптеров
  Hive.registerAdapter(FranchiseGroupAdapter());
  
  // Открываем все необходимые коробки заранее
  await Hive.openBox('anime');
  await Hive.openBox('myListBox');
  await Hive.openBox('profileBox');
  await Hive.openBox('achievementsBox');
  await Hive.openBox('gameData');

  // ИНИЦИАЛИЗАЦИЯ БОЕВОЙ СИСТЕМЫ И ГОРОДА
  await _initializeGameSystems();

  runApp(const AnimeTrackerApp());
}

Future<void> _initializeGameSystems() async {
  try {
    final box = await Hive.openBox('gameData');
    
    // Инициализация данных для карточной игры
    if (!box.containsKey('coins')) {
      await box.put('coins', 1000);
    }
    if (!box.containsKey('playerLevel')) {
      await box.put('playerLevel', 1);
    }
    if (!box.containsKey('playerExp')) {
      await box.put('playerExp', 0);
    }
    
    // Инициализация данных для города
    if (!box.containsKey('city_coins')) {
      await box.put('city_coins', 100);
    }
    
    print('🎮 Игровые системы инициализированы');
  } catch (e) {
    print('❌ Ошибка инициализации игровых систем: $e');
  }
}

class AnimeTrackerApp extends StatelessWidget {
  const AnimeTrackerApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Anime Tracker',
      debugShowCheckedModeBanner: false,
      debugShowMaterialGrid: false,
      showPerformanceOverlay: false,
      checkerboardRasterCacheImages: false,
      checkerboardOffscreenLayers: false,
      navigatorKey: AchievementNotificationService.navigatorKey,
      theme: ThemeData.dark().copyWith(
        primaryColor: const Color(0xFFFF3366),
        scaffoldBackgroundColor: const Color(0xFF1A0A0F),
        colorScheme: ColorScheme.fromSwatch(
          primarySwatch: Colors.red,
          brightness: Brightness.dark,
        ).copyWith(
          secondary: const Color(0xFFFF6B6B),
        ),
        cardTheme: CardThemeData(
          elevation: 4,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          color: const Color(0xFF2A1A2F),
        ),
        buttonTheme: ButtonThemeData(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
        elevatedButtonTheme: ElevatedButtonThemeData(
          style: ElevatedButton.styleFrom(
            backgroundColor: const Color(0xFFFF3366),
            foregroundColor: Colors.white,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
          ),
        ),
      ),
      home: const LoadingScreen(),
      routes: {
        '/home': (_) => const MainScreen(),
      },
    );
  }
}