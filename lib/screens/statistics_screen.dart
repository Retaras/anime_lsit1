// lib/screens/statistics_screen.dart
import 'package:flutter/material.dart';
import 'package:hive/hive.dart';
import '../models/anime.dart';
import '../models/franchise_group.dart';

class StatisticsScreen extends StatefulWidget {
  const StatisticsScreen({super.key});

  @override
  State<StatisticsScreen> createState() => _StatisticsScreenState();
}

class _StatisticsScreenState extends State<StatisticsScreen> {
  List<dynamic> _items = [];
  StatisticsData _stats = StatisticsData();

  @override
  void initState() {
    super.initState();
    _loadItems();
  }

  Future<void> _loadItems() async {
    try {
      final box = await Hive.openBox('myListBox');
      final data = box.values.cast<Map>().toList();
      
      final List<dynamic> loadedItems = [];
      
      for (final e in data) {
        try {
          final map = Map<String, dynamic>.from(e);
          if (map['isGroup'] == true) {
            loadedItems.add(FranchiseGroup.fromMap(map));
          } else {
            loadedItems.add(Anime.fromMap(map));
          }
        } catch (e) {
          print('❌ Error loading item: $e');
        }
      }
      
      setState(() {
        _items = loadedItems;
        _stats = _calculateStatistics(loadedItems);
      });
    } catch (e) {
      print('❌ Error loading statistics: $e');
    }
  }

  StatisticsData _calculateStatistics(List<dynamic> items) {
    final stats = StatisticsData();
    
    for (final item in items) {
      if (item is FranchiseGroup) {
        // Обрабатываем франшизы - учитываем только просмотренные аниме внутри франшизы
        for (final anime in item.animes) {
          if (item.isAnimeWatched(anime.malId)) {
            _processAnimeStats(anime, stats, item.status);
          }
        }
      } else if (item is Anime) {
        // Обрабатываем отдельные аниме
        _processAnimeStats(item, stats, item.status);
      }
    }
    
    return stats;
  }

  void _processAnimeStats(Anime anime, StatisticsData stats, String status) {
    // Общее количество аниме
    stats.totalAnime++;
    
    // По типам
    final type = anime.type?.toLowerCase() ?? 'unknown';
    switch (type) {
      case 'tv':
        stats.tvSeries++;
        break;
      case 'movie':
        stats.movies++;
        break;
      case 'ova':
        stats.ova++;
        break;
      case 'ona':
        stats.ona++;
        break;
      case 'special':
        stats.specials++;
        break;
      default:
        stats.other++;
    }
    
    // По статусу
    final statusLower = status.toLowerCase();
    switch (statusLower) {
      case 'смотрю':
        stats.watching++;
        break;
      case 'просмотрено':
        stats.completed++;
        break;
      case 'брошено':
        stats.dropped++;
        break;
      case 'онгоинг':
        stats.ongoing++;
        break;
      case 'планирую':
        stats.planToWatch++;
        break;
    }
    
    // Просмотренные серии
    stats.totalEpisodes += anime.episodes ?? 0;
    stats.watchedEpisodes += anime.watchedEpisodes;
    
    // Избранное
    if (anime.isFavorite == true) {
      stats.favorites++;
    }
    
    // Рейтинги для статистики
    if (anime.score != null && anime.score! > 0) {
      stats.totalRatings++;
      stats.sumRatings += anime.score!;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0A0A0A),
      body: CustomScrollView(
        slivers: [
          SliverAppBar(
            backgroundColor: Colors.transparent,
            elevation: 0,
            pinned: true,
            expandedHeight: 200,
            flexibleSpace: FlexibleSpaceBar(
              background: Container(
                decoration: const BoxDecoration(
                  gradient: LinearGradient(
                    colors: [Color(0xFF1A1A1A), Color(0xFF0A0A0A)],
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                  ),
                ),
                child: Stack(
                  children: [
                    Positioned.fill(
                      child: Opacity(
                        opacity: 0.1,
                        child: Image.asset(
                          'assets/images/stats_bg.png',
                          fit: BoxFit.cover,
                        ),
                      ),
                    ),
                    Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Container(
                            padding: const EdgeInsets.all(16),
                            decoration: BoxDecoration(
                              gradient: const LinearGradient(
                                colors: [Color(0xFFFF6B6B), Color(0xFFFFD93D)],
                              ),
                              shape: BoxShape.circle,
                            ),
                            child: const Icon(
                              Icons.analytics,
                              color: Colors.white,
                              size: 40,
                            ),
                          ),
                          const SizedBox(height: 16),
                          const Text(
                            'Статистика',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 28,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            '${_stats.totalAnime} аниме в списке',
                            style: const TextStyle(
                              color: Colors.white70,
                              fontSize: 16,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
          
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Общая статистика
                  _buildSection(
                    title: 'Общая статистика',
                    icon: Icons.dashboard,
                    children: [
                      _buildStatCard(
                        'Всего аниме',
                        '${_stats.totalAnime}',
                        Icons.movie,
                        Colors.blue,
                      ),
                      _buildStatCard(
                        'Избранное',
                        '${_stats.favorites}',
                        Icons.favorite,
                        Colors.red,
                      ),
                      _buildStatCard(
                        'Просмотрено серий',
                        '${_stats.watchedEpisodes}',
                        Icons.play_arrow,
                        Colors.green,
                      ),
                      if (_stats.totalRatings > 0)
                        _buildStatCard(
                          'Средняя оценка',
                          '${(_stats.sumRatings / _stats.totalRatings).toStringAsFixed(1)}',
                          Icons.star,
                          Colors.orange,
                        ),
                    ],
                  ),
                  
                  const SizedBox(height: 24),
                  
                  // Статистика по типам
                  _buildSection(
                    title: 'По типам контента',
                    icon: Icons.category,
                    children: [
                      if (_stats.tvSeries > 0) _buildTypeCard('TV Сериалы', _stats.tvSeries, Icons.tv, Colors.blue),
                      if (_stats.movies > 0) _buildTypeCard('Фильмы', _stats.movies, Icons.movie, Colors.red),
                      if (_stats.ova > 0) _buildTypeCard('OVA', _stats.ova, Icons.video_library, Colors.orange),
                      if (_stats.ona > 0) _buildTypeCard('ONA', _stats.ona, Icons.language, Colors.green),
                      if (_stats.specials > 0) _buildTypeCard('Спешлы', _stats.specials, Icons.star, Colors.yellow),
                      if (_stats.other > 0) _buildTypeCard('Другие', _stats.other, Icons.more_horiz, Colors.grey),
                    ],
                  ),
                  
                  const SizedBox(height: 24),
                  
                  // Статистика по статусам
                  _buildSection(
                    title: 'По статусам',
                    icon: Icons.list_alt,
                    children: [
                      if (_stats.watching > 0) _buildStatusCard('Смотрю', _stats.watching, Icons.play_arrow, const Color(0xFF4FC3F7)),
                      if (_stats.completed > 0) _buildStatusCard('Просмотрено', _stats.completed, Icons.check_circle, const Color(0xFF4CAF50)),
                      if (_stats.dropped > 0) _buildStatusCard('Брошено', _stats.dropped, Icons.cancel, const Color(0xFFF44336)),
                      if (_stats.ongoing > 0) _buildStatusCard('Онгоинг', _stats.ongoing, Icons.trending_up, const Color(0xFF1565C0)),
                      if (_stats.planToWatch > 0) _buildStatusCard('В планах', _stats.planToWatch, Icons.schedule, const Color(0xFFFFD54F)),
                    ],
                  ),
                  
                  const SizedBox(height: 40),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSection({
    required String title,
    required IconData icon,
    required List<Widget> children,
  }) {
    if (children.isEmpty) return const SizedBox.shrink();
    
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(icon, color: Colors.white, size: 20),
            const SizedBox(width: 8),
            Text(
              title,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 20,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),
        GridView.count(
          crossAxisCount: 2,
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          crossAxisSpacing: 12,
          mainAxisSpacing: 12,
          childAspectRatio: 1.2,
          children: children,
        ),
      ],
    );
  }

  Widget _buildStatCard(String title, String value, IconData icon, Color color) {
    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            color.withOpacity(0.2),
            color.withOpacity(0.1),
          ],
        ),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: color.withOpacity(0.3)),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(icon, color: color, size: 30),
          const SizedBox(height: 8),
          Text(
            value,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 18,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            title,
            style: TextStyle(
              color: Colors.white.withOpacity(0.7),
              fontSize: 12,
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  Widget _buildTypeCard(String title, int count, IconData icon, Color color) {
    return _buildStatCard(title, '$count', icon, color);
  }

  Widget _buildStatusCard(String title, int count, IconData icon, Color color) {
    return _buildStatCard(title, '$count', icon, color);
  }
}

class StatisticsData {
  int totalAnime = 0;
  int tvSeries = 0;
  int movies = 0;
  int ova = 0;
  int ona = 0;
  int specials = 0;
  int other = 0;
  int watching = 0;
  int completed = 0;
  int dropped = 0;
  int ongoing = 0;
  int planToWatch = 0;
  int totalEpisodes = 0;
  int watchedEpisodes = 0;
  int favorites = 0;
  int totalRatings = 0;
  double sumRatings = 0;
}