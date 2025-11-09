// lib/screens/my_list_screen.dart
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:hive/hive.dart';
import '../models/anime.dart';
import '../models/franchise_group.dart';
import '../services/anime_service.dart';
import 'anime_detail_screen.dart';
import 'group_detail_screen.dart';
import 'main_screen.dart';
import '../helpers/achievement_helper.dart';
import 'statistics_screen.dart'; // Добавляем импорт

class MyListScreen extends StatefulWidget {
  const MyListScreen({super.key});
  @override
  State<MyListScreen> createState() => _MyListScreenState();
}

class _MyListScreenState extends State<MyListScreen> with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final List<String> categories = [
    'Смотрю', 'Планирую', 'Просмотрено', 'Онгоинг', 'Брошено', 'Избранное',
  ];

  List<dynamic> _items = [];
  String _searchQuery = '';
  final TextEditingController _searchController = TextEditingController();
  bool _premiumMode = true;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: categories.length, vsync: this);
    _loadItems();
    _loadPremiumMode();
  }

  @override
  void dispose() {
    _tabController.dispose();
    _searchController.dispose();
    super.dispose();
  }

  // Получаем общее количество просмотренных серий
  int get _totalWatchedEpisodes {
    int total = 0;
    
    for (final item in _items) {
      if (item is FranchiseGroup) {
        total += item.watchedEpisodes;
        print('📊 Franchise ${item.title}: ${item.watchedEpisodes} watched episodes');
      } else if (item is Anime) {
        total += item.watchedEpisodes;
        print('📊 Anime ${item.title}: ${item.watchedEpisodes} watched episodes');
      }
    }
    
    print('🎯 TOTAL WATCHED EPISODES: $total');
    return total;
  }

  Future<void> _loadItems() async {
    try {
      final box = await Hive.openBox('myListBox');
      final data = box.values.cast<Map>().toList();
      
      print('📥 Loading ${data.length} items from Hive');
      
      final List<dynamic> loadedItems = [];
      
      for (final e in data) {
        try {
          final map = Map<String, dynamic>.from(e);
          if (map['isGroup'] == true) {
            final group = FranchiseGroup.fromMap(map);
            // Загружаем полные данные для франшизы
            await _loadFullGroupData(group);
            loadedItems.add(group);
            print('🏷️ Loaded franchise: ${group.title} - watched: ${group.watchedEpisodes} - animes: ${group.watchedAnimes}');
          } else {
            final anime = Anime.fromMap(map);
            loadedItems.add(anime);
            print('🎬 Loaded anime: ${anime.title} - watched: ${anime.watchedEpisodes}');
          }
        } catch (e) {
          print('❌ Error loading item: $e');
        }
      }
      
      setState(() {
        _items = loadedItems;
      });
      
      print('🎯 Final item count: ${_items.length}');
      print('🎯 Total watched episodes: $_totalWatchedEpisodes');
      
      await AchievementHelper.checkAndShowAchievements();
    } catch (e) {
      print('❌ Critical error loading list: $e');
      setState(() {
        _items = [];
      });
    }
  }

  // Метод для загрузки полных данных франшизы
  Future<void> _loadFullGroupData(FranchiseGroup group) async {
    try {
      final List<Future<Anime>> futures = [];
      
      for (final anime in group.animes) {
        futures.add(AnimeService.fetchAnimeById(anime.malId).catchError((e) {
          print('❌ Error loading anime ${anime.malId}: $e');
          return anime;
        }));
      }
      
      final results = await Future.wait(futures);
      final updatedAnimes = <Anime>[];
      
      for (int i = 0; i < results.length; i++) {
        updatedAnimes.add(results[i]);
      }
      
      // Обновляем аниме в группе
      group.animes = updatedAnimes;
      
      print('✅ Updated franchise ${group.title} with ${updatedAnimes.length} animes');
    } catch (e) {
      print('❌ Error loading full group data: $e');
    }
  }

  Future<void> _loadPremiumMode() async {
    final box = await Hive.openBox('settingsBox');
    setState(() {
      _premiumMode = box.get('premiumMode', defaultValue: true);
    });
  }

  Future<void> _savePremiumMode(bool value) async {
    final box = await Hive.openBox('settingsBox');
    await box.put('premiumMode', value);
  }

  List<dynamic> _filteredItems(String category) {
    return _items.where((item) {
      final matchesCategory = category == 'Избранное'
          ? item.isFavorite == true
          : item.status == category;
      
      final matchesSearch = _searchQuery.isEmpty || 
          item.title.toLowerCase().contains(_searchQuery.toLowerCase());
      
      return matchesCategory && matchesSearch;
    }).toList();
  }

  Future<void> _deleteItem(dynamic item) async {
    final String title = item.title;
    String key;
    
    if (item is FranchiseGroup) {
      key = 'group_${item.id}';
    } else if (item is Anime) {
      key = item.malId.toString();
    } else {
      return;
    }

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF1A1A1A),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text(
          'Удалить?',
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
        ),
        content: Text(
          'Вы уверены, что хотите удалить "$title" из списка?',
          style: const TextStyle(color: Colors.white70),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Отмена', style: TextStyle(color: Colors.white60)),
          ),
          Container(
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [Color(0xFFEF4444), Color(0xFFDC2626)],
              ),
              borderRadius: BorderRadius.circular(12),
            ),
            child: TextButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text('Удалить', style: TextStyle(color: Colors.white)),
            ),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      try {
        final box = await Hive.openBox('myListBox');
        await box.delete(key);
        await _loadItems();
        
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('$title удалено из списка'),
              backgroundColor: const Color(0xFF1A1A1A),
              behavior: SnackBarBehavior.floating,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
          );
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Ошибка при удалении: $e'),
              backgroundColor: const Color(0xFFEF4444),
              behavior: SnackBarBehavior.floating,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
          );
        }
      }
    }
  }

  // ИСПРАВЛЕННЫЙ МЕТОД: Добавляем контекстное меню для удаления
  void _showContextMenu(dynamic item, BuildContext context) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (context) => Container(
        margin: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: const Color(0xFF1A1A1A),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: Colors.white.withOpacity(0.1)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.delete, color: Colors.red),
              title: const Text('Удалить', style: TextStyle(color: Colors.white)),
              onTap: () {
                Navigator.pop(context);
                _deleteItem(item);
              },
            ),
            ListTile(
              leading: const Icon(Icons.cancel, color: Colors.white60),
              title: const Text('Отмена', style: TextStyle(color: Colors.white60)),
              onTap: () => Navigator.pop(context),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _clearAllData() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF1A1A1A),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text(
          'Очистить все данные?',
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
        ),
        content: const Text(
          'Это удалит ВСЕ аниме и франшизы из списка. Действие нельзя отменить.',
          style: TextStyle(color: Colors.white70),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Отмена', style: TextStyle(color: Colors.white60)),
          ),
          Container(
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [Color(0xFFEF4444), Color(0xFFDC2626)],
              ),
              borderRadius: BorderRadius.circular(12),
            ),
            child: TextButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text('Очистить всё', style: TextStyle(color: Colors.white)),
            ),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      try {
        final box = await Hive.openBox('myListBox');
        await box.clear();
        await _loadItems();
        
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: const Text('Все данные очищены'),
              backgroundColor: const Color(0xFF1A1A1A),
              behavior: SnackBarBehavior.floating,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
          );
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Ошибка при очистке: $e'),
              backgroundColor: const Color(0xFFEF4444),
              behavior: SnackBarBehavior.floating,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
          );
        }
      }
    }
  }

  Widget _buildAnimatedCard(dynamic item, int index) {
    return GestureDetector(
      onTap: () async {
        if (item is FranchiseGroup) {
          await Navigator.of(context).push(
            MaterialPageRoute(
              builder: (_) => GroupDetailScreen(
                group: item,
                onGroupUpdated: _loadItems, // Добавляем callback
              ),
            ),
          ).then((_) {
            // Принудительно обновляем данные при возврате
            _loadItems();
          });
        } else if (item is Anime) {
          Anime fullAnime;
          try {
            fullAnime = await AnimeService.fetchAnimeById(item.malId);
          } catch (_) {
            fullAnime = item;
          }
          
          await Navigator.of(context).push(
            MaterialPageRoute(
              builder: (_) => AnimeDetailScreen(anime: fullAnime),
            ),
          ).then((_) {
            // Принудительно обновляем данные при возврате
            _loadItems();
          });
        }
      },
      child: _premiumMode
          ? _PremiumCard(
              item: item,
              index: index,
              onDelete: () => _showContextMenu(item, context), // Используем исправленный метод
              totalWatchedEpisodes: _totalWatchedEpisodes,
            )
              .animate()
              .fadeIn(duration: 350.ms, delay: (index * 60).ms)
              .slideY(begin: 0.15, end: 0, duration: 350.ms, curve: Curves.easeOut)
          : _CompactCard(
              item: item,
              onDelete: () => _showContextMenu(item, context), // Используем исправленный метод
              totalWatchedEpisodes: _totalWatchedEpisodes,
            )
              .animate()
              .fadeIn(duration: 250.ms, delay: (index * 40).ms)
              .slideX(begin: -0.08, end: 0, duration: 250.ms, curve: Curves.easeOut),
    );
  }

  @override
  Widget build(BuildContext context) {
    return WillPopScope(
      onWillPop: () async {
        // Принудительно обновляем данные при возврате
        await _loadItems();
        Navigator.of(context).pushAndRemoveUntil(
          MaterialPageRoute(builder: (_) => const MainScreen()),
          (route) => false,
        );
        return false;
      },
      child: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            colors: [Color(0xFF0A0A0A), Color(0xFF1A1A1A)],
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
          ),
        ),
        child: Scaffold(
          backgroundColor: Colors.transparent,
          appBar: AppBar(
            backgroundColor: Colors.transparent,
            elevation: 0,
            flexibleSpace: ClipRect(
              child: BackdropFilter(
                filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
                child: Container(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [
                        Colors.black.withOpacity(0.7),
                        Colors.black.withOpacity(0.3),
                      ],
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                    ),
                  ),
                ),
              ),
            ),
            title: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      colors: [Color(0xFFFF6B6B), Color(0xFFFFD93D)],
                    ),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Icon(Icons.list_alt, color: Colors.white, size: 24),
                ),
                const SizedBox(width: 12),
                const Text(
                  'Мой список',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 22,
                    color: Colors.white,
                  ),
                ),
              ],
            ),
            actions: [
              // Счетчик просмотренных серий
              GestureDetector(
                onTap: () {
                  // Открываем экран статистики при нажатии на значок
                  Navigator.push(
                    context,
                    MaterialPageRoute(builder: (_) => const StatisticsScreen()),
                  );
                },
                child: Container(
                  margin: const EdgeInsets.only(right: 8),
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: Colors.white.withOpacity(0.2)),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.play_arrow, color: Color(0xFF4FC3F7), size: 16),
                      const SizedBox(width: 4),
                      Text(
                        '$_totalWatchedEpisodes эп.',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              IconButton(
                icon: const Icon(Icons.cleaning_services, color: Colors.white),
                onPressed: _clearAllData,
                tooltip: 'Очистить все данные',
              ),
            ],
            bottom: PreferredSize(
              preferredSize: const Size.fromHeight(50),
              child: Container(
                decoration: BoxDecoration(
                  border: Border(
                    bottom: BorderSide(
                      color: Colors.white.withOpacity(0.1),
                      width: 1,
                    ),
                  ),
                ),
                child: TabBar(
                  controller: _tabController,
                  isScrollable: true,
                  indicatorColor: const Color(0xFFFF6B6B),
                  indicatorWeight: 3,
                  indicatorSize: TabBarIndicatorSize.label,
                  labelColor: Colors.white,
                  unselectedLabelColor: Colors.white60,
                  labelStyle: const TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.bold,
                  ),
                  unselectedLabelStyle: const TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.normal,
                  ),
                  tabs: categories
                      .map((cat) => Tab(
                            child: Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8),
                              child: Text(cat),
                            ),
                          ))
                      .toList(),
                ),
              ),
            ),
          ),
          body: Column(
            children: [
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [
                      Colors.black.withOpacity(0.3),
                      Colors.transparent,
                    ],
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                  ),
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: Container(
                        decoration: BoxDecoration(
                          color: const Color(0xFF1E1E1E),
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(
                            color: Colors.white.withOpacity(0.1),
                          ),
                        ),
                        child: TextField(
                          controller: _searchController,
                          style: const TextStyle(color: Colors.white),
                          decoration: InputDecoration(
                            hintText: 'Поиск...',
                            hintStyle: TextStyle(
                              color: Colors.white.withOpacity(0.4),
                            ),
                            filled: false,
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(16),
                              borderSide: BorderSide.none,
                            ),
                            prefixIcon: Icon(
                              Icons.search,
                              color: Colors.white.withOpacity(0.6),
                            ),
                            suffixIcon: _searchQuery.isNotEmpty
                                ? IconButton(
                                    icon: Icon(
                                      Icons.clear,
                                      color: Colors.white.withOpacity(0.6),
                                    ),
                                    onPressed: () {
                                      setState(() {
                                        _searchQuery = '';
                                        _searchController.clear();
                                      });
                                    },
                                  )
                                : null,
                            contentPadding: const EdgeInsets.symmetric(
                              horizontal: 16,
                              vertical: 12,
                            ),
                          ),
                          onChanged: (val) => setState(() => _searchQuery = val),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    GestureDetector(
                      onTap: () {
                        setState(() => _premiumMode = !_premiumMode);
                        _savePremiumMode(_premiumMode);
                      },
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 12,
                        ),
                        decoration: BoxDecoration(
                          gradient: _premiumMode
                              ? const LinearGradient(
                                  colors: [Color(0xFFFF6B6B), Color(0xFFFFD93D)],
                                )
                              : null,
                          color: _premiumMode ? null : const Color(0xFF2A2A2A),
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(
                            color: Colors.white.withOpacity(0.1),
                          ),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              _premiumMode ? Icons.auto_awesome : Icons.view_list,
                              color: Colors.white,
                              size: 18,
                            ),
                            const SizedBox(width: 6),
                            Text(
                              _premiumMode ? 'Premium' : 'Компакт',
                              style: const TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.bold,
                                fontSize: 13,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              
              Expanded(
                child: TabBarView(
                  controller: _tabController,
                  children: categories.map((cat) {
                    final list = _filteredItems(cat);
                    if (list.isEmpty) {
                      return Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(
                              Icons.inbox_outlined,
                              size: 80,
                              color: Colors.white.withOpacity(0.2),
                            ),
                            const SizedBox(height: 16),
                            Text(
                              'Список пуст',
                              style: TextStyle(
                                color: Colors.white.withOpacity(0.4),
                                fontSize: 18,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                            const SizedBox(height: 8),
                            Text(
                              'Добавьте аниме из каталога',
                              style: TextStyle(
                                color: Colors.white.withOpacity(0.3),
                                fontSize: 14,
                              ),
                            ),
                          ],
                        ),
                      );
                    }
                    return ListView.builder(
                      padding: const EdgeInsets.fromLTRB(16, 8, 16, 100),
                      itemCount: list.length,
                      itemBuilder: (context, index) => _buildAnimatedCard(list[index], index),
                    );
                  }).toList(),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ---------------- Premium Card ----------------
class _PremiumCard extends StatefulWidget {
  final dynamic item;
  final int index;
  final VoidCallback onDelete;
  final int totalWatchedEpisodes;
  
  const _PremiumCard({
    required this.item,
    required this.index,
    required this.onDelete,
    required this.totalWatchedEpisodes,
  });

  @override
  State<_PremiumCard> createState() => _PremiumCardState();
}

class _PremiumCardState extends State<_PremiumCard> {
  @override
  Widget build(BuildContext context) {
    final isGroup = widget.item is FranchiseGroup;
    final title = widget.item.title;
    final imageUrl = widget.item.imageUrl;
    final score = widget.item.score;
    final episodes = isGroup 
        ? (widget.item as FranchiseGroup).totalEpisodes
        : (widget.item as Anime).episodes;
    final watchedEpisodes = isGroup
        ? (widget.item as FranchiseGroup).watchedEpisodes
        : (widget.item as Anime).watchedEpisodes;
    final genres = isGroup 
        ? (widget.item as FranchiseGroup).genres
        : (widget.item as Anime).genres;
    final isFavorite = widget.item.isFavorite ?? false;

    // Отладочная информация
    print('🎬 Building card for $title - watched: $watchedEpisodes, total: $episodes');

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      height: 220,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(24),
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            Color(0xFF1A1A1A),
            Color(0xFF0F0F0F),
          ],
        ),
        border: Border.all(
          color: isGroup 
              ? const Color(0xFF9333EA).withOpacity(0.3)
              : Colors.white.withOpacity(0.1),
          width: isGroup ? 2 : 1,
        ),
        boxShadow: [
          BoxShadow(
            color: isGroup 
                ? const Color(0xFF9333EA).withOpacity(0.2)
                : Colors.black.withOpacity(0.4),
            blurRadius: 12,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(24),
        child: Stack(
          children: [
            // Фон с изображением
            Positioned.fill(
              child: Image.network(
                imageUrl,
                fit: BoxFit.cover,
                errorBuilder: (_, __, ___) => Container(
                  color: Colors.white.withOpacity(0.1),
                  child: const Icon(Icons.movie, color: Colors.white30, size: 50),
                ),
              ),
            ),
            
            // Градиент поверх изображения
            Positioned.fill(
              child: Container(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.centerLeft,
                    end: Alignment.centerRight,
                    colors: [
                      Colors.black.withOpacity(0.7),
                      Colors.black.withOpacity(0.4),
                      Colors.transparent,
                    ],
                    stops: const [0.0, 0.4, 0.8],
                  ),
                ),
              ),
            ),
            
            // Контент
            Positioned.fill(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Row(
                  children: [
                    const SizedBox(width: 120), // Отступ для изображения
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          if (isGroup)
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                              margin: const EdgeInsets.only(bottom: 8),
                              decoration: BoxDecoration(
                                gradient: const LinearGradient(
                                  colors: [Color(0xFF9333EA), Color(0xFFC026D3)],
                                ),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  const Icon(Icons.layers, color: Colors.white, size: 12),
                                  const SizedBox(width: 4),
                                  Text(
                                    'ФРАНШИЗА (${(widget.item as FranchiseGroup).animes.length})',
                                    style: const TextStyle(
                                      color: Colors.white,
                                      fontSize: 10,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          
                          Text(
                            title,
                            style: const TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.bold,
                              fontSize: 17,
                              height: 1.2,
                            ),
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),
                          const SizedBox(height: 10),
                          
                          // Прогресс просмотра
                          if (episodes != null && episodes > 0)
                            Container(
                              margin: const EdgeInsets.only(bottom: 8),
                              child: Row(
                                children: [
                                  Expanded(
                                    child: LinearProgressIndicator(
                                      value: watchedEpisodes / episodes,
                                      backgroundColor: Colors.white.withOpacity(0.2),
                                      valueColor: const AlwaysStoppedAnimation<Color>(Color(0xFF4FC3F7)),
                                      borderRadius: BorderRadius.circular(4),
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  Text(
                                    '$watchedEpisodes/$episodes',
                                    style: const TextStyle(
                                      color: Colors.white70,
                                      fontSize: 12,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          
                          Row(
                            children: [
                              if (score != null && score > 0)
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 10,
                                    vertical: 5,
                                  ),
                                  decoration: BoxDecoration(
                                    gradient: const LinearGradient(
                                      colors: [Color(0xFFFFD93D), Color(0xFFFFA726)],
                                    ),
                                    borderRadius: BorderRadius.circular(10),
                                    boxShadow: [
                                      BoxShadow(
                                        color: const Color(0xFFFFD93D).withOpacity(0.3),
                                        blurRadius: 6,
                                        offset: const Offset(0, 2),
                                      ),
                                    ],
                                  ),
                                  child: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      const Icon(
                                        Icons.star,
                                        color: Colors.white,
                                        size: 14,
                                      ),
                                      const SizedBox(width: 4),
                                      Text(
                                        '$score/10',
                                        style: const TextStyle(
                                          color: Colors.white,
                                          fontWeight: FontWeight.bold,
                                          fontSize: 12,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              const SizedBox(width: 8),
                              if (episodes != null && episodes > 0)
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 10,
                                    vertical: 5,
                                  ),
                                  decoration: BoxDecoration(
                                    color: Colors.white.withOpacity(0.1),
                                    borderRadius: BorderRadius.circular(10),
                                    border: Border.all(
                                      color: Colors.white.withOpacity(0.2),
                                    ),
                                  ),
                                  child: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Icon(
                                        Icons.movie_filter,
                                        color: Colors.white.withOpacity(0.7),
                                        size: 14,
                                      ),
                                      const SizedBox(width: 4),
                                      Text(
                                        '$episodes эп',
                                        style: TextStyle(
                                          color: Colors.white.withOpacity(0.7),
                                          fontSize: 12,
                                          fontWeight: FontWeight.w600,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                            ],
                          ),
                          
                          const SizedBox(height: 10),
                          
                          if (genres != null && genres.isNotEmpty)
                            Wrap(
                              spacing: 6,
                              runSpacing: 6,
                              children: genres
                                  .take(3)
                                  .map((g) => Container(
                                        padding: const EdgeInsets.symmetric(
                                          horizontal: 8,
                                          vertical: 4,
                                        ),
                                        decoration: BoxDecoration(
                                          color: Colors.white.withOpacity(0.1),
                                          borderRadius: BorderRadius.circular(8),
                                          border: Border.all(
                                            color: Colors.white.withOpacity(0.2),
                                          ),
                                        ),
                                        child: Text(
                                          g,
                                          style: const TextStyle(
                                            color: Colors.white70,
                                            fontSize: 10,
                                            fontWeight: FontWeight.w500,
                                          ),
                                        ),
                                      ))
                                  .toList(),
                            ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
            
            // Иконка избранного
            if (isFavorite)
              Positioned(
                top: 12,
                right: 12,
                child: Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      colors: [Color(0xFFEC4899), Color(0xFFF43F5E)],
                    ),
                    shape: BoxShape.circle,
                    boxShadow: [
                      BoxShadow(
                        color: const Color(0xFFEC4899).withOpacity(0.5),
                        blurRadius: 12,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  child: const Icon(
                    Icons.favorite,
                    color: Colors.white,
                    size: 18,
                  ),
                ),
              ),
            
            // Кнопка удаления
            Positioned(
              top: 12,
              right: isFavorite ? 56 : 12,
              child: GestureDetector(
                onTap: widget.onDelete,
                child: Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: const Color(0xFF2A2A2A),
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: Colors.white.withOpacity(0.1),
                    ),
                  ),
                  child: Icon(
                    Icons.more_vert,
                    color: Colors.white.withOpacity(0.7),
                    size: 18,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ---------------- Compact Card ----------------
class _CompactCard extends StatelessWidget {
  final dynamic item;
  final VoidCallback onDelete;
  final int totalWatchedEpisodes;
  
  const _CompactCard({
    required this.item,
    required this.onDelete,
    required this.totalWatchedEpisodes,
  });

  @override
  Widget build(BuildContext context) {
    final isGroup = item is FranchiseGroup;
    final title = item.title;
    final imageUrl = item.imageUrl;
    final score = item.score;
    final episodes = isGroup 
        ? (item as FranchiseGroup).totalEpisodes
        : (item as Anime).episodes;
    final watchedEpisodes = isGroup
        ? (item as FranchiseGroup).watchedEpisodes
        : (item as Anime).watchedEpisodes;
    final status = item.status;
    final isFavorite = item.isFavorite ?? false;

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [
            Color(0xFF1A1A1A),
            Color(0xFF0F0F0F),
          ],
        ),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isGroup 
              ? const Color(0xFF9333EA).withOpacity(0.3)
              : Colors.white.withOpacity(0.1),
          width: isGroup ? 2 : 1,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.3),
            blurRadius: 8,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        children: [
          // Изображение
          ClipRRect(
            borderRadius: BorderRadius.circular(12),
            child: Image.network(
              imageUrl,
              width: 70,
              height: 100,
              fit: BoxFit.cover,
              errorBuilder: (_, __, ___) => Container(
                width: 70,
                height: 100,
                color: Colors.white.withOpacity(0.1),
                child: const Icon(Icons.movie, color: Colors.white30, size: 30),
              ),
            ),
          ),
          const SizedBox(width: 12),
          
          // Информация
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (isGroup)
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
                    margin: const EdgeInsets.only(bottom: 6),
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(
                        colors: [Color(0xFF9333EA), Color(0xFFC026D3)],
                      ),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(Icons.layers, color: Colors.white, size: 10),
                        const SizedBox(width: 4),
                        Text(
                          'Франшиза (${(item as FranchiseGroup).animes.length})',
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 9,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                  ),
                
                Text(
                  title,
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                    fontSize: 15,
                  ),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 8),
                
                // Прогресс просмотра
                if (episodes != null && episodes > 0)
                  Container(
                    margin: const EdgeInsets.only(bottom: 6),
                    child: Row(
                      children: [
                        Expanded(
                          flex: 3,
                          child: LinearProgressIndicator(
                            value: watchedEpisodes / episodes,
                            backgroundColor: Colors.white.withOpacity(0.2),
                            valueColor: const AlwaysStoppedAnimation<Color>(Color(0xFF4FC3F7)),
                            borderRadius: BorderRadius.circular(4),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          flex: 2,
                          child: Text(
                            '$watchedEpisodes/$episodes',
                            style: const TextStyle(
                              color: Colors.white70,
                              fontSize: 11,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                
                Row(
                  children: [
                    if (score != null && score > 0)
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 4,
                        ),
                        decoration: BoxDecoration(
                          gradient: const LinearGradient(
                            colors: [Color(0xFFFFD93D), Color(0xFFFFA726)],
                          ),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(
                              Icons.star,
                              color: Colors.white,
                              size: 12,
                            ),
                            const SizedBox(width: 4),
                            Text(
                              '$score/10',
                              style: const TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.bold,
                                fontSize: 11,
                              ),
                            ),
                          ],
                        ),
                      ),
                    const Spacer(),
                    GestureDetector(
                      onTap: onDelete,
                      child: Container(
                        padding: const EdgeInsets.all(6),
                        decoration: BoxDecoration(
                          color: const Color(0xFF2A2A2A),
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(
                            color: Colors.white.withOpacity(0.1),
                          ),
                        ),
                        child: Icon(
                          Icons.more_vert,
                          color: Colors.white.withOpacity(0.7),
                          size: 16,
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}