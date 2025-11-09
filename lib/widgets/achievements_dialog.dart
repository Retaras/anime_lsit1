import 'package:flutter/material.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:hive/hive.dart';
import 'dart:ui';
import 'achievement.dart';

class AchievementsDialog extends StatefulWidget {
  final VoidCallback onRefresh;
  
  const AchievementsDialog({required this.onRefresh, super.key});

  @override
  State<AchievementsDialog> createState() => _AchievementsDialogState();
}

class _AchievementsDialogState extends State<AchievementsDialog> with TickerProviderStateMixin {
  late TabController _tabController;
  List<Achievement> allAchievements = [];
  bool isLoading = true;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 5, vsync: this);
    _loadAndCheckAchievements();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _loadAndCheckAchievements() async {
    final generatedList = Achievement.generateAll();
    
    final box = await Hive.openBox('achievementsBox');
    final unlockedIds = Set<String>.from(box.get('unlockedIds', defaultValue: <String>[]));
    
    List<Achievement> updatedAchievements = generatedList.map((achievement) {
      if (unlockedIds.contains(achievement.id)) {
        return achievement.copyWith(
          isUnlocked: true,
          unlockedDate: DateTime.tryParse(box.get('${achievement.id}_date') ?? ''),
        );
      }
      return achievement;
    }).toList();

    final newlyUnlocked = <String>[];
    final myListBox = await Hive.openBox('myListBox');
    final allAnime = myListBox.values.map((item) => Map<String, dynamic>.from(item)).toList();

    for (var achievement in updatedAchievements) {
      if (!achievement.isUnlocked) {
        bool isUnlocked = await _checkAchievement(achievement, allAnime);
        if (isUnlocked) {
          newlyUnlocked.add(achievement.id);
          
          // Убрана выдача награды в виде монет
        }
      }
    }

    if (newlyUnlocked.isNotEmpty) {
      unlockedIds.addAll(newlyUnlocked);
      await box.put('unlockedIds', unlockedIds.toList());
      
      final now = DateTime.now();
      for (var id in newlyUnlocked) {
        await box.put('${id}_date', now.toIso8601String());
      }
      
      updatedAchievements = updatedAchievements.map((a) {
        if (newlyUnlocked.contains(a.id)) {
          return a.copyWith(isUnlocked: true, unlockedDate: now);
        }
        return a;
      }).toList();
    }
    
    if (mounted) {
      setState(() {
        allAchievements = updatedAchievements;
        isLoading = false;
      });
    }
  }

  Future<bool> _checkAchievement(Achievement achievement, List<Map<String, dynamic>> allAnime) async {
    final totalAnimeCount = allAnime.length;
    final favoritesCount = allAnime.where((a) => a['isFavorite'] == true).length;
    final ratingsCount = allAnime.where((a) => a['score'] != null && (a['score'] as int) > 0).length;
    final reviewsCount = allAnime.where((a) => a['review'] != null && (a['review'] as String).isNotEmpty).length;
    
    final usedStatuses = allAnime.map((a) => a['status'] as String? ?? '').toSet();
    final allTenRatings = allAnime.where((a) => a['score'] == 10).length;
    final isAllFavorites = totalAnimeCount > 0 && favoritesCount == totalAnimeCount;

    switch (achievement.id) {
      case 'first_anime': return totalAnimeCount >= 1;
      case 'first_favorite': return favoritesCount >= 1;
      case 'first_rating': return ratingsCount >= 1;
      case 'first_review': return reviewsCount >= 1;
      case 'status_change': return usedStatuses.length > 1;
      case 'five_favorites': return favoritesCount >= 5;
      case 'ten_ratings': return ratingsCount >= 10;
      case 'five_reviews': return reviewsCount >= 5;
      case 'all_statuses': return usedStatuses.length >= 5;
      case 'twenty_five_favorites': return favoritesCount >= 25;
      case 'fifty_ratings': return ratingsCount >= 50;
      case 'ten_reviews': return reviewsCount >= 10;
      case 'list_50': return totalAnimeCount >= 50;
      case 'hundred_favorites': return favoritesCount >= 100;
      case 'hundred_ratings': return ratingsCount >= 100;
      case 'twenty_five_reviews': return reviewsCount >= 25;
      case 'list_100': return totalAnimeCount >= 100;
      case 'all_favorites': return isAllFavorites;
      case 'two_hundred_favorites': return favoritesCount >= 200;
      case 'two_hundred_ratings': return ratingsCount >= 200;
      case 'fifty_reviews': return reviewsCount >= 50;
      case 'list_200': return totalAnimeCount >= 200;
      case 'perfectionist': return totalAnimeCount > 0 && allTenRatings == totalAnimeCount;
      case 'all_achievements': 
        final box = await Hive.openBox('achievementsBox');
        final unlockedIds = Set<String>.from(box.get('unlockedIds', defaultValue: <String>[]));
        return unlockedIds.length >= allAchievements.length - 1;
      default: return false;
    }
  }

  @override
  Widget build(BuildContext context) {
    final unlockedCount = allAchievements.where((a) => a.isUnlocked).length;
    final totalCount = allAchievements.length;

    return BackdropFilter(
      filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
      child: Dialog(
        backgroundColor: Colors.transparent,
        child: Container(
          width: MediaQuery.of(context).size.width * 0.9,
          height: MediaQuery.of(context).size.height * 0.8,
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
            border: Border.all(color: Colors.white.withOpacity(0.1), width: 1.5),
          ),
          child: Column(
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(24, 24, 24, 16),
                child: Row(
                  children: [
                    const Text(
                      'Достижения',
                      style: TextStyle(fontSize: 24, fontWeight: FontWeight.w800, color: Colors.white),
                    ),
                    const Spacer(),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Text(
                        '$unlockedCount/$totalCount',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                    const SizedBox(width: 16),
                    IconButton(
                      icon: const Icon(Icons.close_rounded, color: Colors.white),
                      onPressed: () {
                        widget.onRefresh();
                        Navigator.pop(context);
                      },
                    ),
                  ],
                ),
              ),
              TabBar(
                controller: _tabController,
                isScrollable: true,
                indicatorColor: const Color(0xFFFF3366),
                labelColor: Colors.white,
                unselectedLabelColor: Colors.white54,
                labelStyle: const TextStyle(fontWeight: FontWeight.bold),
                tabs: const [
                  Tab(text: 'Все'),
                  Tab(text: '🟢 Обычные'),
                  Tab(text: '🔵 Редкие'),
                  Tab(text: '🟣 Эпические'),
                  Tab(text: '🟠 Легенд.'),
                ],
              ),
              const SizedBox(height: 16),
              Expanded(
                child: isLoading
                    ? const Center(child: CircularProgressIndicator(color: Color(0xFFFF3366)))
                    : TabBarView(
                        controller: _tabController,
                        children: [
                          _buildAchievementList(allAchievements),
                          _buildAchievementList(allAchievements.where((a) => a.category == 'ordinary').toList()),
                          _buildAchievementList(allAchievements.where((a) => a.category == 'rare').toList()),
                          _buildAchievementList(allAchievements.where((a) => a.category == 'epic').toList()),
                          _buildAchievementList(allAchievements.where((a) => a.category == 'legendary' || a.category == 'divine').toList()),
                        ],
                      ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildAchievementList(List<Achievement> achievements) {
    if (achievements.isEmpty) {
      return Center(
        child: Text(
          'Нет достижений в этой категории',
          style: TextStyle(color: Colors.white.withOpacity(0.5)),
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      itemCount: achievements.length,
      itemBuilder: (context, index) {
        final achievement = achievements[index];
        return _buildAchievementTile(achievement);
      },
    );
  }

  Widget _buildAchievementTile(Achievement achievement) {
    final color = _getCategoryColor(achievement.category);
    final isUnlocked = achievement.isUnlocked;
    
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: isUnlocked
              ? [color.withOpacity(0.3), color.withOpacity(0.1)]
              : [Colors.white.withOpacity(0.05), Colors.white.withOpacity(0.02)],
        ),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isUnlocked ? color.withOpacity(0.5) : Colors.white.withOpacity(0.1),
        ),
      ),
      child: Row(
        children: [
          Container(
            width: 50,
            height: 50,
            decoration: BoxDecoration(
              color: isUnlocked ? color.withOpacity(0.2) : Colors.white.withOpacity(0.1),
              shape: BoxShape.circle,
            ),
            child: Icon(
              _getIconData(achievement.iconData),
              color: isUnlocked ? color : Colors.white.withOpacity(0.4),
              size: 28,
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  achievement.title,
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                    color: isUnlocked ? Colors.white : Colors.white.withOpacity(0.7),
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  achievement.description,
                  style: TextStyle(
                    fontSize: 12,
                    color: isUnlocked ? Colors.white70 : Colors.white.withOpacity(0.4),
                  ),
                ),
              ],
            ),
          ),
          if (isUnlocked)
            const Icon(Icons.check_circle, color: Color(0xFF4CAF50), size: 24)
          else
            Icon(Icons.lock, color: Colors.white.withOpacity(0.3), size: 24),
        ],
      ),
    );
  }

  Color _getCategoryColor(String category) {
    switch (category) {
      case 'ordinary': return const Color(0xFF4CAF50);
      case 'rare': return const Color(0xFF2196F3);
      case 'epic': return const Color(0xFF9C27B0);
      case 'legendary': return const Color(0xFFFF9800);
      case 'divine': return const Color(0xFFFF3366);
      default: return Colors.grey;
    }
  }

  IconData _getIconData(String iconName) {
    switch (iconName) {
      case 'add_circle': return Icons.add_circle_rounded;
      case 'favorite': return Icons.favorite_rounded;
      case 'star': return Icons.star_rounded;
      case 'rate_review': return Icons.rate_review_rounded;
      case 'swap_horiz': return Icons.swap_horiz_rounded;
      case 'favorite_list': return Icons.favorite;
      case 'star_rate': return Icons.star_rate_rounded;
      case 'comment': return Icons.comment_rounded;
      case 'checklist': return Icons.checklist_rounded;
      case 'list_alt': return Icons.list_alt_rounded;
      case 'diamond': return Icons.diamond_rounded;
      case 'emoji_events': return Icons.emoji_events_rounded;
      default: return Icons.emoji_events_rounded;
    }
  }
}