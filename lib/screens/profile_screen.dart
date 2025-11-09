import 'package:flutter/material.dart';
import 'package:hive/hive.dart';
import 'dart:ui';
import 'dart:math' as math;
import 'statistics_screen.dart';
import 'achievements_screen.dart';
import '../models/achievement.dart';
import 'main_screen.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen>
    with TickerProviderStateMixin {
  String _nickname = 'Аниме Фанат';
  final TextEditingController _nickController = TextEditingController();
  
  late AnimationController _glowController;
  late AnimationController _fadeController;
  late Animation<double> _glowAnimation;
  late Animation<double> _fadeAnimation;

  int _watchedCount = 0;
  int _watchingCount = 0;
  int _plannedCount = 0;
  int _totalEpisodes = 0;
  int _unlockedAchievementsCount = 0;

  @override
  void initState() {
    super.initState();
    
    _glowController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2000),
    )..repeat(reverse: true);

    _glowAnimation = Tween<double>(begin: 0.7, end: 1.0).animate(
      CurvedAnimation(parent: _glowController, curve: Curves.easeInOut),
    );

    _fadeController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    );

    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _fadeController, curve: Curves.easeOut),
    );

    _loadProfile();
    _fadeController.forward();
  }

  Future<void> _checkAchievements() async {
    final achievementsBox = await Hive.openBox('achievementsBox');
    final unlockedIds = Set<String>.from(achievementsBox.get('unlockedIds', defaultValue: <String>[]));
    
    final allAchievements = Achievement.generateAll();
    
    for (var achievement in allAchievements) {
      if (unlockedIds.contains(achievement.id)) {
        achievement.isUnlocked = true;
        achievement.unlockedDate = DateTime.tryParse(achievementsBox.get('${achievement.id}_date') ?? '');
      }
    }
    
    await Achievement.checkAllAchievements(allAchievements, unlockedIds, achievementsBox);
    
    await achievementsBox.put('unlockedIds', unlockedIds.toList());

    if (mounted) {
      setState(() {
        _unlockedAchievementsCount = unlockedIds.length;
      });
    }
  }

  Future<void> _loadProfile() async {
    final profileBox = await Hive.openBox('profileBox');
    final myListBox = await Hive.openBox('myListBox');
    
    setState(() {
      _nickname = profileBox.get('nickname', defaultValue: 'Аниме Фанат');
      _nickController.text = _nickname;
      
      final allAnime = myListBox.values.map((item) => Map<String, dynamic>.from(item)).toList();
      
      _watchedCount = allAnime.where((a) => a['status'] == 'Просмотрено').length;
      _watchingCount = allAnime.where((a) => a['status'] == 'Смотрю').length;
      _plannedCount = allAnime.where((a) => a['status'] == 'Планирую' || a['status'] == 'Запланировано').length;
      
      _totalEpisodes = allAnime.fold(0, (sum, a) {
        final watchedEps = a['watchedEpisodes'];
        if (watchedEps is int) {
          return sum + watchedEps;
        }
        return sum;
      });
    });

    await _checkAchievements();
  }

  Future<void> _saveProfile() async {
    final box = await Hive.openBox('profileBox');
    await box.put('nickname', _nickname);
  }

  void _showEditNicknameDialog() {
    showDialog(
      context: context,
      builder: (context) => BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
        child: Dialog(
          backgroundColor: Colors.transparent,
          child: Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  Colors.grey[900]!.withOpacity(0.95),
                  Colors.grey[850]!.withOpacity(0.95),
                ],
              ),
              borderRadius: BorderRadius.circular(24),
              border: Border.all(
                color: Colors.white.withOpacity(0.1),
                width: 1.5,
              ),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text(
                  'Изменить никнейм',
                  style: TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.w700,
                    color: Colors.white,
                  ),
                ),
                const SizedBox(height: 24),
                TextField(
                  controller: _nickController,
                  style: const TextStyle(color: Colors.white, fontSize: 18),
                  decoration: InputDecoration(
                    filled: true,
                    fillColor: Colors.white.withOpacity(0.05),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide(color: Colors.white.withOpacity(0.2)),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: const BorderSide(color: Color(0xFFFF3366), width: 2),
                    ),
                  ),
                ),
                const SizedBox(height: 24),
                Row(
                  children: [
                    Expanded(
                      child: TextButton(
                        onPressed: () => Navigator.pop(context),
                        style: TextButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 16),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                        child: const Text(
                          'Отмена',
                          style: TextStyle(
                            color: Colors.white70,
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: ElevatedButton(
                        onPressed: () {
                          setState(() {
                            _nickname = _nickController.text;
                          });
                          _saveProfile();
                          Navigator.pop(context);
                        },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFFFF3366),
                          padding: const EdgeInsets.symmetric(vertical: 16),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                        child: const Text(
                          'Сохранить',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  void _showLevelProgressDialog() {
    showDialog(
      context: context,
      builder: (context) => BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
        child: Dialog(
          backgroundColor: Colors.transparent,
          child: Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  Colors.grey[900]!.withOpacity(0.95),
                  Colors.grey[850]!.withOpacity(0.95),
                ],
              ),
              borderRadius: BorderRadius.circular(24),
              border: Border.all(
                color: Colors.white.withOpacity(0.1),
                width: 1.5,
              ),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text(
                  'Прогресс уровней',
                  style: TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.w700,
                    color: Colors.white,
                  ),
                ),
                const SizedBox(height: 24),
                SizedBox(
                  height: 300,
                  child: ListView.builder(
                    itemCount: 10,
                    itemBuilder: (context, index) {
                      int level = index + 1;
                      int requiredAnime = level * 10;
                      bool isReached = _watchedCount >= requiredAnime;
                      bool isCurrent = (_watchedCount / 10).floor() + 1 == level;
                      
                      return Container(
                        margin: const EdgeInsets.only(bottom: 12),
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            colors: isReached || isCurrent
                                ? [Color(0xFFFF3366).withOpacity(0.3), Color(0xFFFF6B6B).withOpacity(0.2)]
                                : [Colors.white.withOpacity(0.05), Colors.white.withOpacity(0.02)],
                          ),
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(
                            color: isReached || isCurrent
                                ? Color(0xFFFF3366).withOpacity(0.5)
                                : Colors.white.withOpacity(0.1),
                          ),
                        ),
                        child: Row(
                          children: [
                            Container(
                              width: 50,
                              height: 50,
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                gradient: LinearGradient(
                                  colors: [
                                    Color.lerp(Color(0xFFFF3366), Color(0xFFFFD700), (level - 1) / 10)!,
                                    Color.lerp(Color(0xFFFF6B6B), Color(0xFFFFA500), (level - 1) / 10)!,
                                  ],
                                ),
                              ),
                              child: Center(
                                child: Text(
                                  level.toString(),
                                  style: const TextStyle(
                                    fontSize: 22,
                                    fontWeight: FontWeight.w800,
                                    color: Colors.white,
                                  ),
                                ),
                              ),
                            ),
                            const SizedBox(width: 16),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    'Уровень $level',
                                    style: const TextStyle(
                                      fontSize: 16,
                                      fontWeight: FontWeight.w700,
                                      color: Colors.white,
                                    ),
                                  ),
                                  Text(
                                    '$requiredAnime аниме',
                                    style: TextStyle(
                                      fontSize: 13,
                                      color: Colors.white.withOpacity(0.6),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            if (isReached)
                              Icon(
                                Icons.check_circle_rounded,
                                color: Color(0xFF4CAF50),
                                size: 28,
                              )
                            else if (isCurrent)
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                                decoration: BoxDecoration(
                                  gradient: const LinearGradient(
                                    colors: [Color(0xFFFF3366), Color(0xFFFF6B6B)],
                                  ),
                                  borderRadius: BorderRadius.circular(16),
                                ),
                                child: const Text(
                                  'Текущий',
                                  style: TextStyle(
                                    fontSize: 12,
                                    fontWeight: FontWeight.w700,
                                    color: Colors.white,
                                  ),
                                ),
                              ),
                          ],
                        ),
                      );
                    },
                  ),
                ),
                const SizedBox(height: 16),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: () => Navigator.pop(context),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFFFF3366),
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    child: const Text(
                      'Закрыть',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  void _showAchievementsDialog() {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (context) => const AchievementsScreen(),
      ),
    ).then((_) {
      _loadProfile();
    });
  }

  @override
  void dispose() {
    _glowController.dispose();
    _fadeController.dispose();
    _nickController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // 1. Оборачиваем Scaffold в WillPopScope для управления кнопкой "Назад"
    return WillPopScope(
      onWillPop: () async {
        // При нажатии "Назад" переходим на главный экран и очищаем стек
        Navigator.of(context).pushAndRemoveUntil(
          MaterialPageRoute(builder: (context) => MainScreen()),
          (Route<dynamic> route) => false,
        );
        // Блокируем стандартное поведение (закрытие приложения)
        return false;
      },
      child: Scaffold(
        // Добавляем цвет фона, который совпадает с верхним цветом градиента
        backgroundColor: const Color(0xFF1A0A0F),
        body: Stack(
          children: [
            _buildBackground(),
            _buildContent(),
          ],
        ),
      ),
    );
  }

  Widget _buildBackground() {
    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            const Color(0xFF1A0A0F),
            const Color(0xFF0A0A0A),
          ],
        ),
      ),
    );
  }

  Widget _buildContent() {
    return FadeTransition(
      opacity: _fadeAnimation,
      // 2. Оборачиваем контент в SafeArea, чтобы он не залезал под системные кнопки
      child: SafeArea(
        top: false, // SliverAppBar уже управляет отступом сверху
        child: CustomScrollView(
          slivers: [
            _buildAppBar(),
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.all(20.0),
                child: Column(
                  children: [
                    _buildProfileHeader(),
                    const SizedBox(height: 24),
                    _buildStatsGrid(),
                    const SizedBox(height: 24),
                    _buildLevelProgress(),
                    const SizedBox(height: 24),
                    _buildMenuSection(),
                    const SizedBox(height: 20),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildAppBar() {
    return SliverAppBar(
      expandedHeight: 120,
      floating: false,
      pinned: true,
      backgroundColor: Colors.transparent,
      flexibleSpace: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              const Color(0xFF2A0505).withOpacity(0.95),
              const Color(0xFF1A0A0F).withOpacity(0.95),
            ],
          ),
        ),
        child: FlexibleSpaceBar(
          centerTitle: true,
          title: const Text(
            'Профиль',
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.w700,
              color: Colors.white,
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildProfileHeader() {
    return AnimatedBuilder(
      animation: _glowAnimation,
      builder: (context, child) {
        return Container(
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                Colors.white.withOpacity(0.08),
                Colors.white.withOpacity(0.03),
              ],
            ),
            borderRadius: BorderRadius.circular(24),
            border: Border.all(
              color: Colors.white.withOpacity(0.1),
              width: 1.5,
            ),
            boxShadow: [
              BoxShadow(
                color: const Color(0xFFFF3366).withOpacity(_glowAnimation.value * 0.2),
                blurRadius: 30,
                spreadRadius: 2,
              ),
            ],
          ),
          child: Column(
            children: [
              Stack(
                children: [
                  Container(
                    width: 100,
                    height: 100,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      gradient: LinearGradient(
                        colors: [
                          Color.lerp(const Color(0xFFFF3366), const Color(0xFFFF5588), _glowAnimation.value * 0.3)!,
                          Color.lerp(const Color(0xFFFF6B6B), const Color(0xFFFF8888), _glowAnimation.value * 0.3)!,
                        ],
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: const Color(0xFFFF3366).withOpacity(_glowAnimation.value * 0.6),
                          blurRadius: 25,
                          spreadRadius: 3,
                        ),
                      ],
                    ),
                    child: const Icon(
                      Icons.person,
                      size: 50,
                      color: Colors.white,
                    ),
                  ),
                  Positioned(
                    bottom: 0,
                    right: 0,
                    child: Container(
                      padding: const EdgeInsets.all(6),
                      decoration: BoxDecoration(
                        color: const Color(0xFFFF3366),
                        shape: BoxShape.circle,
                        border: Border.all(color: Colors.black, width: 2),
                      ),
                      child: const Icon(
                        Icons.edit,
                        size: 16,
                        color: Colors.white,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    _nickname,
                    style: const TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.w800,
                      color: Colors.white,
                    ),
                  ),
                  const SizedBox(width: 8),
                  IconButton(
                    icon: const Icon(Icons.edit_outlined, color: Color(0xFFFF6B6B), size: 20),
                    onPressed: _showEditNicknameDialog,
                  ),
                ],
              ),
              const SizedBox(height: 4),
              Text(
                _getLevelTitle(),
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                  color: const Color(0xFFFF6B6B).withOpacity(0.8),
                  letterSpacing: 1,
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  String _getLevelTitle() {
    int currentLevel = (_watchedCount / 10).floor() + 1;
    if (currentLevel <= 2) return 'Начинающий отаку';
    if (currentLevel <= 5) return 'Опытный зритель';
    if (currentLevel <= 8) return 'Мастер аниме';
    return 'Легенда аниме';
  }

  Widget _buildStatsGrid() {
    return Row(
      children: [
        Expanded(child: _buildStatCard('Просмотрено', _watchedCount, Icons.check_circle_rounded, const Color(0xFF4CAF50))),
        const SizedBox(width: 12),
        Expanded(child: _buildStatCard('Смотрю', _watchingCount, Icons.play_circle_rounded, const Color(0xFFFF9800))),
      ],
    );
  }

  Widget _buildStatCard(String label, int value, IconData icon, Color color) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            Colors.white.withOpacity(0.08),
            Colors.white.withOpacity(0.03),
          ],
        ),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: Colors.white.withOpacity(0.1),
          width: 1.5,
        ),
      ),
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: color.withOpacity(0.2),
              shape: BoxShape.circle,
            ),
            child: Icon(icon, color: color, size: 28),
          ),
          const SizedBox(height: 12),
          Text(
            value.toString(),
            style: const TextStyle(
              fontSize: 28,
              fontWeight: FontWeight.w800,
              color: Colors.white,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            label,
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w500,
              color: Colors.white.withOpacity(0.6),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLevelProgress() {
    int currentLevel = (_watchedCount / 10).floor() + 1;
    int nextLevelAnime = currentLevel * 10;
    double progress = (_watchedCount % 10) / 10;

    return GestureDetector(
      onTap: _showLevelProgressDialog,
      child: Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              Colors.white.withOpacity(0.08),
              Colors.white.withOpacity(0.03),
            ],
          ),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: Colors.white.withOpacity(0.1),
            width: 1.5,
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  'Уровень',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    color: Colors.white,
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      colors: [Color(0xFFFF3366), Color(0xFFFF6B6B)],
                    ),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    'LVL $currentLevel',
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w800,
                      color: Colors.white,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            ClipRRect(
              borderRadius: BorderRadius.circular(10),
              child: LinearProgressIndicator(
                value: progress,
                minHeight: 12,
                backgroundColor: Colors.white.withOpacity(0.1),
                valueColor: const AlwaysStoppedAnimation<Color>(Color(0xFFFF3366)),
              ),
            ),
            const SizedBox(height: 12),
            Text(
              'До ${currentLevel + 1} уровня: ${nextLevelAnime - _watchedCount} аниме',
              style: TextStyle(
                fontSize: 13,
                color: Colors.white.withOpacity(0.6),
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Нажми для просмотра прогресса',
              style: TextStyle(
                fontSize: 12,
                color: const Color(0xFFFF3366).withOpacity(0.7),
                fontStyle: FontStyle.italic,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMenuSection() {
    return Column(
      children: [
        _buildMenuItem(
          Icons.assessment_rounded,
          'Статистика',
          'Просмотрено: $_watchedCount, Смотрю: $_watchingCount',
          const Color(0xFF2196F3),
          () {
            Navigator.of(context).push(
              MaterialPageRoute(
                builder: (context) => const StatisticsScreen(),
              ),
            );
          },
        ),
        const SizedBox(height: 12),
        _buildMenuItem(
          Icons.emoji_events_rounded,
          'Достижения',
          'Разблокировано: $_unlockedAchievementsCount',
          const Color(0xFFFFB300),
          _showAchievementsDialog,
        ),
        const SizedBox(height: 12),
        _buildMenuItem(
          Icons.settings_rounded,
          'Настройки',
          'Параметры приложения',
          const Color(0xFF9C27B0),
          () {
            // TODO: открыть настройки
          },
        ),
        const SizedBox(height: 12),
        _buildMenuItem(
          Icons.info_rounded,
          'О приложении',
          'Информация и поддержка',
          const Color(0xFF607D8B),
          () {
            showAboutDialog(
              context: context,
              applicationName: 'Aenima',
              applicationVersion: '1.0.0',
              applicationIcon: Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [Color(0xFFFF3366), Color(0xFFFF6B6B)],
                  ),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(Icons.movie_filter_rounded, color: Colors.white),
              ),
              children: const [
                Text('Автор: DeNKliN'),
                SizedBox(height: 8),
                Text(
                  'Приложение для удобного отслеживания аниме. '
                  'Разработано исключительно для личного пользования. '
                  'Запрещено передавать, распространять или продавать.',
                ),
              ],
            );
          },
        ),
      ],
    );
  }

  Widget _buildMenuItem(IconData icon, String title, String subtitle, Color color, VoidCallback onTap) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(20),
      child: Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              Colors.white.withOpacity(0.08),
              Colors.white.withOpacity(0.03),
            ],
          ),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: Colors.white.withOpacity(0.1),
            width: 1.5,
          ),
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: color.withOpacity(0.2),
                borderRadius: BorderRadius.circular(14),
              ),
              child: Icon(icon, color: color, size: 26),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: const TextStyle(
                      fontSize: 17,
                      fontWeight: FontWeight.w700,
                      color: Colors.white,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    subtitle,
                    style: TextStyle(
                      fontSize: 13,
                      color: Colors.white.withOpacity(0.6),
                    ),
                  ),
                ],
              ),
            ),
            Icon(
              Icons.arrow_forward_ios_rounded,
              color: Colors.white.withOpacity(0.4),
              size: 18,
            ),
          ],
        ),
      ),
    );
  }
}