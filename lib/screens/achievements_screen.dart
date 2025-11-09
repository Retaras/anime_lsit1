import 'package:flutter/material.dart';
import 'package:hive/hive.dart';
import '../models/achievement.dart';

class AchievementsScreen extends StatefulWidget {
  const AchievementsScreen({super.key});

  @override
  State<AchievementsScreen> createState() => _AchievementsScreenState();
}

class _AchievementsScreenState extends State<AchievementsScreen>
    with TickerProviderStateMixin {
  late AnimationController _fadeController;
  late AnimationController _glowController;
  late AnimationController _cardController;
  late TabController _tabController;

  List<Achievement> _allAchievements = [];
  List<Achievement> _unlockedAchievements = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 5, vsync: this);
    _fadeController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 800),
    );
    _glowController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1000),
    )..repeat(reverse: true);
    _cardController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 500),
    );
    _loadData();
    _fadeController.forward();
  }

  @override
  void dispose() {
    _glowController.dispose();
    _fadeController.dispose();
    _tabController.dispose();
    _cardController.dispose();
    super.dispose();
  }

  Future<void> _loadData() async {
    if (!mounted) return;
    setState(() => _isLoading = true);

    try {
      final allAchievements = Achievement.generateAll();
      final box = await Hive.openBox('achievementsBox');
      final unlockedIdsList = box.get('unlockedIds', defaultValue: <String>[]);
      final unlockedIds = Set<String>.from(unlockedIdsList);

      for (var achievement in allAchievements) {
        if (unlockedIds.contains(achievement.id)) {
          achievement.isUnlocked = true;
          achievement.unlockedDate = DateTime.tryParse(box.get('${achievement.id}_date') ?? '');
        }
      }
      await Achievement.checkAllAchievements(allAchievements, unlockedIds, box);
      await box.put('unlockedIds', unlockedIds.toList());

      if (mounted) {
        setState(() {
          _allAchievements = allAchievements;
          _unlockedAchievements = allAchievements.where((a) => a.isUnlocked).toList();
          _isLoading = false;
        });
      }
    } catch (e) {
      print("Ошибка при загрузке достижений: $e");
      if (mounted) setState(() => _isLoading = false);
    }
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF1A0A0F),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator(color: Color(0xFFFF3366)))
          : NestedScrollView(
              headerSliverBuilder: (BuildContext context, bool innerBoxIsScrolled) {
                return [
                  SliverOverlapAbsorber(
                    handle: NestedScrollView.sliverOverlapAbsorberHandleFor(context),
                    sliver: _buildSliverAppBar(),
                  ),
                ];
              },
              body: TabBarView(
                controller: _tabController,
                children: [
                  _AchievementListTab(
                    achievements: _allAchievements,
                    cardController: _cardController,
                    getCategoryColor: _getCategoryColor,
                    getIconData: _getIconData,
                    unlockedCount: _unlockedAchievements.length,
                    totalCount: _allAchievements.length,
                  ),
                  _AchievementListTab(
                    achievements: _allAchievements.where((a) => a.category == 'ordinary').toList(),
                    cardController: _cardController,
                    getCategoryColor: _getCategoryColor,
                    getIconData: _getIconData,
                    unlockedCount: _unlockedAchievements.where((a) => a.category == 'ordinary').length,
                    totalCount: _allAchievements.where((a) => a.category == 'ordinary').length,
                  ),
                  _AchievementListTab(
                    achievements: _allAchievements.where((a) => a.category == 'rare').toList(),
                    cardController: _cardController,
                    getCategoryColor: _getCategoryColor,
                    getIconData: _getIconData,
                    unlockedCount: _unlockedAchievements.where((a) => a.category == 'rare').length,
                    totalCount: _allAchievements.where((a) => a.category == 'rare').length,
                  ),
                  _AchievementListTab(
                    achievements: _allAchievements.where((a) => a.category == 'epic').toList(),
                    cardController: _cardController,
                    getCategoryColor: _getCategoryColor,
                    getIconData: _getIconData,
                    unlockedCount: _unlockedAchievements.where((a) => a.category == 'epic').length,
                    totalCount: _allAchievements.where((a) => a.category == 'epic').length,
                  ),
                  _AchievementListTab(
                    achievements: _allAchievements.where((a) => a.category == 'legendary' || a.category == 'divine').toList(),
                    cardController: _cardController,
                    getCategoryColor: _getCategoryColor,
                    getIconData: _getIconData,
                    unlockedCount: _unlockedAchievements.where((a) => a.category == 'legendary' || a.category == 'divine').length,
                    totalCount: _allAchievements.where((a) => a.category == 'legendary' || a.category == 'divine').length,
                  ),
                ],
              ),
            ),
      floatingActionButton: FloatingActionButton.small(
        onPressed: _showResetConfirmationDialog,
        backgroundColor: const Color(0xFFFF3366),
        child: const Icon(Icons.refresh),
      ),
    );
  }

  Widget _buildSliverAppBar() {
    final unlockedCount = _unlockedAchievements.length;
    final totalCount = _allAchievements.length;
    final progress = totalCount == 0 ? 0.0 : unlockedCount / totalCount;

    return SliverAppBar(
      expandedHeight: 140.0,
      pinned: true,
      backgroundColor: Colors.transparent,
      flexibleSpace: FlexibleSpaceBar(
        centerTitle: true,
        title: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text(
              'Достижения',
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.w900, color: Colors.white),
            ),
            const SizedBox(height: 4),
            Text(
              '$unlockedCount/$totalCount',
              style: const TextStyle(fontSize: 14, color: Colors.white70),
            ),
            const SizedBox(height: 4),
            Container(
              width: 100,
              height: 4,
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.2),
                borderRadius: BorderRadius.circular(2),
              ),
              child: Stack(
                children: [
                  Container(
                    width: 100 * progress,
                    decoration: BoxDecoration(
                      color: const Color(0xFFFF3366),
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
        background: Container(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [Color(0xFF2A0505), Color(0xFF1A0A0F)],
            ),
          ),
        ),
      ),
      bottom: TabBar(
        controller: _tabController,
        indicator: const UnderlineTabIndicator(
          borderSide: BorderSide(color: Color(0xFFFF3366), width: 3),
        ),
        tabs: const [
          Tab(icon: Icon(Icons.grid_view), text: 'Все'),
          Tab(icon: Icon(Icons.star_outline), text: 'Обычные'),
          Tab(icon: Icon(Icons.auto_awesome), text: 'Редкие'),
          Tab(icon: Icon(Icons.bolt), text: 'Эпические'),
          Tab(icon: Icon(Icons.military_tech), text: 'Легенд.'),
        ],
        labelColor: Colors.white,
        unselectedLabelColor: Colors.white.withOpacity(0.6),
        labelStyle: const TextStyle(fontWeight: FontWeight.w700, fontSize: 16),
        indicatorSize: TabBarIndicatorSize.tab,
        labelPadding: const EdgeInsets.symmetric(vertical: 8),
      ),
    );
  }

  void _showResetConfirmationDialog() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF1E1E1E),
        title: const Text('Сбросить достижения?', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
        content: const Text('Вы уверены, что хотите сбросить все достижения? Это действие нельзя отменить.', style: TextStyle(color: Colors.white70)),
        actions: [
          TextButton(onPressed: () => Navigator.of(context).pop(), child: const Text('Отмена', style: TextStyle(color: Color(0xFF2196F3)))),
          TextButton(
            onPressed: () {
              Navigator.of(context).pop();
              _showFinalConfirmationDialog();
            },
            style: TextButton.styleFrom(backgroundColor: const Color(0xFFFF3366)),
            child: const Text('СБРОСИТЬ!', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  void _showFinalConfirmationDialog() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF1E1E1E),
        title: const Text('ВНИМАНИЕ!', style: TextStyle(color: Colors.red, fontWeight: FontWeight.bold)),
        content: const Text('Вы ДЕЙСТВИТЕЛЬНО уверены? Это удалит ВСЕ ваши разблокированные достижения навсегда!', style: TextStyle(color: Colors.white70)),
        actions: [
          TextButton(onPressed: () => Navigator.of(context).pop(), child: const Text('Нет, я передумал', style: TextStyle(color: Colors.grey))),
          TextButton(
            onPressed: () async {
              Navigator.of(context).pop();
              await Achievement.resetAchievements();
              _loadData();
            },
            style: TextButton.styleFrom(backgroundColor: Colors.red, foregroundColor: Colors.white),
            child: const Text('ДА, СБРОСИТЬ!'),
          ),
        ],
      ),
    );
  }
}

class _AchievementListTab extends StatelessWidget {
  final List<Achievement> achievements;
  final AnimationController cardController;
  final Color Function(String) getCategoryColor;
  final IconData Function(String) getIconData;
  final int unlockedCount;
  final int totalCount;

  const _AchievementListTab({
    Key? key,
    required this.achievements,
    required this.cardController,
    required this.getCategoryColor,
    required this.getIconData,
    required this.unlockedCount,
    required this.totalCount,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return CustomScrollView(
      slivers: [
        SliverOverlapInjector(handle: NestedScrollView.sliverOverlapAbsorberHandleFor(context)),
        if (totalCount > 0)
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: _buildProgressIndicator(),
            ),
          ),
        if (achievements.isEmpty)
          const SliverFillRemaining(
            child: Center(child: Text('В этой категории пока нет достижений', style: TextStyle(color: Colors.white54, fontSize: 16))),
          )
        else
          SliverList(
            delegate: SliverChildBuilderDelegate(
              (context, index) {
                final achievement = achievements[index];
                return _buildAchievementTile(achievement);
              },
              childCount: achievements.length,
            ),
          ),
      ],
    );
  }

  Widget _buildProgressIndicator() {
    final progress = totalCount == 0 ? 0.0 : unlockedCount / totalCount;
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.white.withOpacity(0.2)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('Прогресс категории', style: TextStyle(color: Colors.white.withOpacity(0.8), fontSize: 14)),
              Text(
                '$unlockedCount / $totalCount',
                style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold),
              ),
            ],
          ),
          const SizedBox(height: 8),
          LinearProgressIndicator(
            value: progress,
            backgroundColor: Colors.white.withOpacity(0.2),
            valueColor: AlwaysStoppedAnimation<Color>(
              progress == 1.0 ? const Color(0xFF4CAF50) : const Color(0xFFFF3366),
            ),
            borderRadius: BorderRadius.circular(8),
          ),
        ],
      ),
    );
  }

  Widget _buildAchievementTile(Achievement achievement) {
    final color = getCategoryColor(achievement.category);
    final isUnlocked = achievement.isUnlocked;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 300),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(16),
          color: isUnlocked ? color.withOpacity(0.15) : Colors.grey.withOpacity(0.08),
          border: Border.all(color: isUnlocked ? color.withOpacity(0.3) : Colors.transparent),
          boxShadow: isUnlocked
              ? [BoxShadow(color: color.withOpacity(0.2), blurRadius: 8, offset: const Offset(0, 4))]
              : null,
        ),
        child: ListTile(
          contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          leading: Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: isUnlocked ? color.withOpacity(0.25) : Colors.grey.withOpacity(0.15),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(getIconData(achievement.iconData), color: isUnlocked ? color : Colors.grey.shade600, size: 28),
          ),
          title: Text(
            achievement.title,
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w800,
              color: isUnlocked ? Colors.white : Colors.grey.shade500,
            ),
          ),
          subtitle: Padding(
            padding: const EdgeInsets.only(top: 4.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  achievement.description,
                  style: TextStyle(
                    fontSize: 13,
                    color: isUnlocked ? Colors.white70 : Colors.grey.shade600,
                  ),
                ),
              ],
            ),
          ),
          trailing: isUnlocked
              ? Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.check_circle, color: color, size: 22),
                    if (achievement.unlockedDate != null)
                      Padding(
                        padding: const EdgeInsets.only(top: 2.0),
                        child: Text(
                          '${achievement.unlockedDate!.day}.${achievement.unlockedDate!.month}',
                          style: TextStyle(fontSize: 9, color: color.withOpacity(0.8)),
                        ),
                      ),
                  ],
                )
              : Icon(Icons.lock, color: Colors.grey.shade600, size: 22),
        ),
      ),
    );
  }
}