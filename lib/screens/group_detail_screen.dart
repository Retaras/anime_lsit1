// lib/screens/group_detail_screen.dart
import 'package:flutter/material.dart';
import 'package:hive/hive.dart';
import 'package:flutter_animate/flutter_animate.dart';
import '../models/anime.dart';
import '../models/franchise_group.dart';
import '../models/character.dart';
import '../widgets/rating_review_block.dart';
import '../helpers/achievement_helper.dart';
import '../services/anime_service.dart';
import 'anime_detail_screen.dart';

class GroupDetailScreen extends StatefulWidget {
  final FranchiseGroup group;
  final VoidCallback? onGroupUpdated;
  
  const GroupDetailScreen({
    super.key, 
    required this.group,
    this.onGroupUpdated,
  });

  @override
  State<GroupDetailScreen> createState() => _GroupDetailScreenState();
}

class _GroupDetailScreenState extends State<GroupDetailScreen> with SingleTickerProviderStateMixin {
  late FranchiseGroup _group;
  List<Anime> _updatedAnimes = [];
  bool showFullDescription = false;
  final TextEditingController reviewController = TextEditingController();
  final FocusNode _reviewFocusNode = FocusNode();

  late AnimationController _animController;
  late Animation<double> _fadeAnimation;
  late Animation<Offset> _slideAnimation;

  List<Character> characters = [];
  bool isLoadingCharacters = true;

  final List<String> statuses = ['Планирую', 'Смотрю', 'Просмотрено', 'Брошено', 'Онгоинг'];
  final Map<String, Color> statusColors = {
    'Планирую': const Color(0xFFFFD54F),
    'Смотрю': const Color(0xFF4FC3F7),
    'Просмотрено': const Color(0xFF81C784),
    'Брошено': const Color(0xFFE57373),
    'Онгоинг': const Color(0xFF1565C0),
  };
  final Map<String, IconData> statusIcons = {
    'Планирую': Icons.schedule,
    'Смотрю': Icons.play_circle_filled,
    'Просмотрено': Icons.check_circle,
    'Брошено': Icons.cancel,
    'Онгоинг': Icons.trending_up,
  };

  @override
  void initState() {
    super.initState();

    _reviewFocusNode.addListener(() {
      if (!_reviewFocusNode.hasFocus) _updateHive();
    });

    _animController = AnimationController(vsync: this, duration: const Duration(milliseconds: 600));
    _fadeAnimation = CurvedAnimation(parent: _animController, curve: Curves.easeOut);
    _slideAnimation = Tween<Offset>(begin: const Offset(0, 0.3), end: Offset.zero)
        .animate(CurvedAnimation(parent: _animController, curve: Curves.easeOut));
    
    _group = widget.group;
    _updatedAnimes = _group.animes;
    
    // Быстрая загрузка - запускаем все параллельно
    _loadDataFast();
  }

  // Оптимизированная загрузка данных
  Future<void> _loadDataFast() async {
    _animController.forward(); // Запускаем анимации сразу
    
    // Параллельная загрузка данных
    await Future.wait([
      _loadFullAnimeData(),
      _loadFromHive(),
      _loadCharacters(),
    ], eagerError: false);
  }

  // Быстрая загрузка данных аниме с кэшированием
  Future<void> _loadFullAnimeData() async {
    final List<Future<Anime>> futures = [];
    
    for (final anime in _group.animes) {
      // Всегда загружаем полные данные, чтобы получить episodes
      futures.add(AnimeService.fetchAnimeById(anime.malId).catchError((e) {
        print('❌ Ошибка загрузки ${anime.title}: $e');
        return anime; // Возвращаем оригинальные данные при ошибке
      }));
    }

    final results = await Future.wait(futures);
    
    // Обновляем все аниме
    final updatedList = <Anime>[];
    for (int i = 0; i < results.length; i++) {
      final loaded = results[i];
      updatedList.add(loaded);
      print('📥 Loaded anime: ${loaded.title} - episodes: ${loaded.episodes}');
    }
    
    setState(() {
      _updatedAnimes = updatedList;
      _group.animes = updatedList; // Обновляем аниме в группе
    });
    
    print('✅ Total loaded animes: ${_updatedAnimes.length}');
  }

  // Обновляем данные конкретного аниме
  Future<void> _updateAnimeData(int malId) async {
    try {
      final index = _updatedAnimes.indexWhere((anime) => anime.malId == malId);
      if (index != -1) {
        final updatedAnime = await AnimeService.fetchAnimeById(malId);
        setState(() {
          _updatedAnimes[index] = updatedAnime;
          _group.animes[index] = updatedAnime; // Обновляем в группе
        });
        print('✅ Updated anime data for $malId: ${updatedAnime.episodes} episodes');
      }
    } catch (e) {
      print('❌ Error updating anime data for $malId: $e');
    }
  }

  // Проверяем, есть ли полные данные у аниме
  bool _hasCompleteData(Anime anime) {
    return (anime.episodes ?? 0) > 0 && 
           anime.imageUrl != null && 
           anime.imageUrl!.isNotEmpty && 
           !anime.imageUrl!.contains('noimage');
  }

  Future<void> _loadFromHive() async {
    final box = await Hive.openBox('myListBox');
    final data = box.get('group_${_group.id}');
    if (data != null) {
      setState(() {
        _group.status = data['status'] ?? 'Планирую';
        _group.score = data['score'] ?? 0.0;
        _group.isFavorite = data['isFavorite'] ?? false;
        reviewController.text = data['review'] ?? '';
      });
    }
  }

  Future<void> _loadCharacters() async {
    if (_updatedAnimes.isEmpty) return;
    
    setState(() => isLoadingCharacters = true);
    try {
      // Используем первое аниме с полными данными
      final firstCompleteAnime = _updatedAnimes.firstWhere(
        (anime) => _hasCompleteData(anime),
        orElse: () => _updatedAnimes.first,
      );
      
      final result = await AnimeService.fetchCharacters(firstCompleteAnime.malId);
      setState(() => characters = result);
    } catch (e) {
      debugPrint('Ошибка загрузки персонажей: $e');
    } finally {
      setState(() => isLoadingCharacters = false);
    }
  }

  Future<void> _updateHive() async {
    try {
      final box = await Hive.openBox('myListBox');
      final hiveKey = 'group_${_group.id}';
      
      print('💾 Saving to Hive with key: $hiveKey');
      print('💾 Watched animes: ${_group.watchedAnimes}');
      print('💾 Watched episodes: ${_group.watchedEpisodes}');
      
      await box.put(hiveKey, _group.toMap());
      
      // Проверяем, что сохранилось
      final savedData = box.get(hiveKey);
      print('💾 Saved data: ${savedData?['watchedAnimes']}');
      
      await AchievementHelper.checkAndShowAchievements();
    } catch (e) {
      print('❌ Error saving to Hive: $e');
    }
  }

  Future<void> _updateGroupStatus(String newStatus) async {
    setState(() => _group.status = newStatus);
    await _updateHive();
  }

  Future<void> _updateGroupScore(double newScore) async {
    setState(() => _group.score = newScore);
    await _updateHive();
  }

  Future<void> _toggleFavorite() async {
    setState(() => _group.isFavorite = !_group.isFavorite);
    await _updateHive();
  }

  // Переключение статуса просмотра для элемента франшизы
  Future<void> _toggleAnimeWatched(int malId) async {
    print('🎯 Before toggle - watchedAnimes: ${_group.watchedAnimes}');
    
    // Сначала обновляем данные аниме
    await _updateAnimeData(malId);
    
    setState(() {
      _group.toggleWatched(malId);
    });
    
    print('🎯 After toggle - watchedAnimes: ${_group.watchedAnimes}');
    print('🎯 Watched episodes: ${_group.watchedEpisodes}');
    print('🎯 Watched animes count: ${_group.watchedAnimesCount}');
    
    await _updateHive();
    
    // Принудительно обновляем интерфейс
    if (mounted) {
      setState(() {});
    }

    // Уведомляем родительский экран об обновлении
    if (widget.onGroupUpdated != null) {
      widget.onGroupUpdated!();
    }
  }

  // Вычисляем средний рейтинг франшизы
  double? get _averageScore {
    if (_updatedAnimes.isEmpty) return null;
    final scores = _updatedAnimes.where((anime) => anime.score != null && anime.score! > 0).map((anime) => anime.score!).toList();
    if (scores.isEmpty) return null;
    return scores.reduce((a, b) => a + b) / scores.length;
  }

  // Получаем все жанры из франшизы
  List<String> get _allGenres {
    final genres = <String>{};
    for (final anime in _updatedAnimes) {
      if (anime.genres != null) {
        genres.addAll(anime.genres!);
      }
    }
    return genres.toList();
  }

  // Вычисляем общее количество серий во франшизе
  int get _totalEpisodes {
    return _updatedAnimes.fold(0, (sum, anime) => sum + (anime.episodes ?? 0));
  }

  // Вычисляем общее количество просмотренных серий
  int get _totalWatchedEpisodes {
    return _group.watchedEpisodes;
  }

  @override
  void dispose() {
    _reviewFocusNode.dispose();
    _animController.dispose();
    reviewController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final description = "Франшиза ${_group.title} включает ${_updatedAnimes.length} элементов.";
    final shortDescription = description.length > 300 ? "${description.substring(0, 300)}..." : description;

    return Scaffold(
      backgroundColor: const Color(0xFF0A0A0A),
      body: CustomScrollView(
        slivers: [
          _buildAppBar(),
          SliverToBoxAdapter(
            child: FadeTransition(
              opacity: _fadeAnimation,
              child: SlideTransition(
                position: _slideAnimation,
                child: Padding(
                  padding: const EdgeInsets.all(20),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _buildInfoCard(),
                      const SizedBox(height: 20),
                      _buildDescriptionCard(description, shortDescription),
                      const SizedBox(height: 20),
                      _buildCharactersBlock(),
                      const SizedBox(height: 20),
                      _buildInteractionCard(),
                      const SizedBox(height: 20),
                      _buildFranchiseList(),
                      const SizedBox(height: 30),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAppBar() {
    return SliverAppBar(
      expandedHeight: 400,
      pinned: true,
      backgroundColor: Colors.transparent,
      elevation: 0,
      leading: Container(
        margin: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: Colors.black.withOpacity(0.5),
          shape: BoxShape.circle,
        ),
        child: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      actions: [
        Container(
          margin: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: Colors.black.withOpacity(0.5),
            shape: BoxShape.circle,
          ),
          child: IconButton(
            icon: Icon(
              _group.isFavorite ? Icons.favorite : Icons.favorite_border,
              color: _group.isFavorite ? const Color(0xFFEC4899) : Colors.white,
            ),
            onPressed: _toggleFavorite,
          ),
        ),
      ],
      flexibleSpace: FlexibleSpaceBar(
        background: Stack(
          children: [
            Positioned.fill(
              child: _buildAppBarImage(),
            ),
            Positioned.fill(
              child: Container(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [
                      Colors.transparent,
                      Colors.black.withOpacity(0.7),
                      Colors.black.withOpacity(0.95),
                    ],
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    stops: const [0.3, 0.7, 1.0],
                  ),
                ),
              ),
            ),
            Positioned(
              bottom: 20,
              left: 20,
              right: 20,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(
                        colors: [Color(0xFFFF6B6B), Color(0xFFFFD93D)],
                      ),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(Icons.layers, color: Colors.white, size: 16),
                        const SizedBox(width: 6),
                        Text(
                          'ФРАНШИЗА (${_updatedAnimes.length})',
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    _group.title,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 28,
                      fontWeight: FontWeight.bold,
                      height: 1.2,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Всего эпизодов: $_totalEpisodes • Просмотрено: ${_group.watchedEpisodes}',
                    style: TextStyle(
                      color: Colors.white.withOpacity(0.8),
                      fontSize: 16,
                    ),
                  ),
                  const SizedBox(height: 8),
                  // Прогресс-бар
                  Container(
                    height: 6,
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.2),
                      borderRadius: BorderRadius.circular(3),
                    ),
                    child: Stack(
                      children: [
                        LayoutBuilder(
                          builder: (context, constraints) {
                            final progress = _totalEpisodes > 0 
                                ? _group.watchedEpisodes / _totalEpisodes 
                                : 0.0;
                            return Container(
                              width: constraints.maxWidth * progress,
                              decoration: BoxDecoration(
                                gradient: const LinearGradient(
                                  colors: [Color(0xFF4FC3F7), Color(0xFF2196F3)],
                                ),
                                borderRadius: BorderRadius.circular(3),
                              ),
                            );
                          },
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildAppBarImage() {
    for (final anime in _updatedAnimes) {
      if (anime.imageUrl != null && 
          anime.imageUrl!.isNotEmpty && 
          !anime.imageUrl!.contains('noimage')) {
        return Image.network(
          anime.imageUrl!,
          fit: BoxFit.cover,
          errorBuilder: (_, __, ___) => Container(
            color: Colors.white.withOpacity(0.1),
          ),
        );
      }
    }
    return Image.network(
      _group.imageUrl,
      fit: BoxFit.cover,
      errorBuilder: (_, __, ___) => Container(
        color: Colors.white.withOpacity(0.1),
      ),
    );
  }

  Widget _buildInfoCard() {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: _cardDecoration(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildSectionHeader(Icons.info_outline, "Информация",
              gradient: const LinearGradient(colors: [Color(0xFF6366F1), Color(0xFF8B5CF6)])),
          const SizedBox(height: 20),
          _buildInfoGrid(),
          if (_allGenres.isNotEmpty) ...[
            const SizedBox(height: 20),
            const Text('Жанры:', style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold)),
            const SizedBox(height: 12),
            Wrap(spacing: 8, runSpacing: 8, children: _allGenres.map((g) => _buildGenreChip(g)).toList()),
          ],
        ],
      ),
    );
  }

  Widget _buildInfoGrid() {
    return Container(
      decoration: BoxDecoration(
        color: Colors.black.withOpacity(0.2),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white.withOpacity(0.05)),
      ),
      padding: const EdgeInsets.all(16),
      child: Column(
        children: [
          Row(
            children: [
              Expanded(child: _buildInfoItem(Icons.layers, 'Элементов', '${_updatedAnimes.length}')),
              const SizedBox(width: 16),
              Expanded(child: _buildInfoItem(Icons.movie_filter, 'Эпизоды', '$_totalEpisodes')),
            ],
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(child: _buildInfoItem(Icons.check_circle, 'Просмотрено', '${_group.watchedAnimesCount}/${_updatedAnimes.length}')),
              const SizedBox(width: 16),
              Expanded(child: _buildInfoItem(Icons.star_rate_rounded, 'Рейтинг', _averageScore?.toStringAsFixed(1) ?? '—')),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildInfoItem(IconData icon, String label, String value) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFF1A1A1A),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.white.withOpacity(0.08)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, color: const Color(0xFF6366F1), size: 20),
              const SizedBox(width: 6),
              Text(label, style: const TextStyle(color: Colors.white70, fontSize: 14, fontWeight: FontWeight.w500)),
            ],
          ),
          const SizedBox(height: 6),
          Text(value, style: const TextStyle(color: Colors.white, fontSize: 17, fontWeight: FontWeight.bold)),
        ],
      ),
    );
  }

  Widget _buildGenreChip(String label) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            const Color(0xFF6366F1).withOpacity(0.2),
            const Color(0xFF8B5CF6).withOpacity(0.2),
          ],
        ),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFF6366F1).withOpacity(0.3)),
      ),
      child: Text(label, style: const TextStyle(color: Colors.white70, fontSize: 14, fontWeight: FontWeight.w500)),
    );
  }

  Widget _buildDescriptionCard(String description, String shortDescription) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: _cardDecoration(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildSectionHeader(Icons.description, "Описание франшизы",
              gradient: const LinearGradient(colors: [Color(0xFFEC4899), Color(0xFFF97316)])),
          const SizedBox(height: 16),
          Text(showFullDescription ? description : shortDescription,
              style: const TextStyle(color: Colors.white70, fontSize: 15, height: 1.6)),
          if (description.length > 300)
            Padding(
              padding: const EdgeInsets.only(top: 12),
              child: InkWell(
                onTap: () => setState(() => showFullDescription = !showFullDescription),
                child: _buildGradientButton(
                  showFullDescription ? "Скрыть" : "Читать далее",
                  icon: showFullDescription ? Icons.expand_less : Icons.expand_more,
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildCharactersBlock() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            const Color(0xFF1A1A1A),
            const Color(0xFF0F0F0F).withOpacity(0.95),
          ],
        ),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(
          color: const Color(0xFFEC4899).withOpacity(0.15),
          width: 1.5,
        ),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFFEC4899).withOpacity(0.1),
            blurRadius: 20,
            offset: const Offset(0, 10),
          ),
          BoxShadow(
            color: Colors.black.withOpacity(0.4),
            blurRadius: 15,
            offset: const Offset(0, 5),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildSectionHeader(Icons.people, "Персонажи",
              gradient: const LinearGradient(colors: [Color(0xFFEC4899), Color(0xFF8B5CF6)])),
          const SizedBox(height: 16),
          SizedBox(
            height: 150,
            child: isLoadingCharacters
                ? _buildCharactersLoading()
                : characters.isEmpty
                    ? _buildCharactersEmpty()
                    : _buildCharactersList(),
          ),
        ],
      ),
    );
  }

  Widget _buildCharactersLoading() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            width: 50,
            height: 50,
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [Color(0xFFEC4899), Color(0xFF8B5CF6)],
              ),
              borderRadius: BorderRadius.circular(25),
              boxShadow: [
                BoxShadow(
                  color: const Color(0xFFEC4899).withOpacity(0.4),
                  blurRadius: 15,
                  offset: const Offset(0, 5),
                ),
              ],
            ),
            child: const Center(
              child: CircularProgressIndicator(
                strokeWidth: 3,
                valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
              ),
            ),
          ),
          const SizedBox(height: 12),
          const Text(
            'Загрузка персонажей...',
            style: TextStyle(color: Colors.white70, fontSize: 16, fontWeight: FontWeight.w500),
          ),
        ],
      ),
    );
  }

  Widget _buildCharactersEmpty() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            width: 60,
            height: 60,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  const Color(0xFFEC4899).withOpacity(0.2),
                  const Color(0xFF8B5CF6).withOpacity(0.2),
                ],
              ),
              borderRadius: BorderRadius.circular(30),
              border: Border.all(
                color: const Color(0xFFEC4899).withOpacity(0.3),
                width: 1.5,
              ),
            ),
            child: const Icon(Icons.person_off, color: Color(0xFFEC4899), size: 30),
          ),
          const SizedBox(height: 12),
          const Text(
            'Персонажи не найдены',
            style: TextStyle(color: Colors.white70, fontSize: 16, fontWeight: FontWeight.w500),
          ),
        ],
      ),
    );
  }

  Widget _buildCharactersList() {
    return ListView.separated(
      scrollDirection: Axis.horizontal,
      physics: const BouncingScrollPhysics(),
      itemCount: characters.length,
      separatorBuilder: (_, __) => const SizedBox(width: 16),
      itemBuilder: (context, index) {
        final c = characters[index];
        final displayName = c.name ?? 'Без имени';
        final imageUrl = c.imageUrl ?? '';

        return Container(
          width: 100,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(20),
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [
                const Color(0xFF2D1B69).withOpacity(0.3),
                const Color(0xFF0F0C29).withOpacity(0.5),
              ],
            ),
            border: Border.all(
              color: const Color(0xFFEC4899).withOpacity(0.15),
              width: 1,
            ),
            boxShadow: [
              BoxShadow(
                color: const Color(0xFFEC4899).withOpacity(0.1),
                blurRadius: 10,
                offset: const Offset(0, 5),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                flex: 3,
                child: ClipRRect(
                  borderRadius: const BorderRadius.only(
                    topLeft: Radius.circular(20),
                    topRight: Radius.circular(20),
                  ),
                  child: imageUrl.isNotEmpty
                      ? Image.network(
                          imageUrl,
                          width: double.infinity,
                          height: double.infinity,
                          fit: BoxFit.cover,
                          errorBuilder: (context, error, stackTrace) => _buildCharacterPlaceholder(),
                        )
                      : _buildCharacterPlaceholder(),
                ),
              ),
              Expanded(
                flex: 1,
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 4),
                  child: Center(
                    child: Text(
                      displayName,
                      textAlign: TextAlign.center,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        height: 1.2,
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildCharacterPlaceholder() {
    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            const Color(0xFF2D1B69).withOpacity(0.3),
            const Color(0xFF0F0C29).withOpacity(0.5),
          ],
        ),
      ),
      child: const Icon(Icons.person, color: Colors.white30, size: 40),
    );
  }

  Widget _buildInteractionCard() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: _cardDecoration(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildSectionHeader(Icons.star, "Статус просмотра",
              gradient: const LinearGradient(colors: [Color(0xFF10B981), Color(0xFF059669)])),
          const SizedBox(height: 20),
          _buildStatusSelector(),
          const SizedBox(height: 24),
          RatingReviewBlock(
            currentRating: _group.score?.toInt() ?? 0,
            reviewController: reviewController,
            reviewFocusNode: _reviewFocusNode,
            onRatingChanged: (newRating) async {
              await _updateGroupScore(newRating.toDouble());
            },
          ),
        ],
      ),
    );
  }

  Widget _buildStatusSelector() {
    return Wrap(
      spacing: 10,
      runSpacing: 10,
      children: statuses.map((s) {
        final selected = s == _group.status;
        return InkWell(
          onTap: () async {
            await _updateGroupStatus(s);
          },
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(
              gradient: selected
                  ? LinearGradient(colors: [statusColors[s]!, statusColors[s]!.withOpacity(0.7)])
                  : null,
              color: selected ? null : const Color(0xFF2A2A2A),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: selected ? statusColors[s]!.withOpacity(0.5) : Colors.white.withOpacity(0.1),
                width: selected ? 2 : 1,
              ),
              boxShadow: selected
                  ? [BoxShadow(color: statusColors[s]!.withOpacity(0.4), blurRadius: 12, offset: const Offset(0, 4))]
                  : null,
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(statusIcons[s], color: selected ? Colors.white : Colors.white60, size: 18),
                const SizedBox(width: 8),
                Text(s,
                    style: TextStyle(color: selected ? Colors.white : Colors.white60, fontWeight: FontWeight.bold, fontSize: 14)),
              ],
            ),
          ),
        );
      }).toList(),
    );
  }

  Widget _buildFranchiseList() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: _cardDecoration(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildSectionHeader(Icons.layers, "Элементы франшизы (${_updatedAnimes.length})",
              gradient: const LinearGradient(colors: [Color(0xFFFF6B6B), Color(0xFFFFD93D)])),
          
          // Счетчик просмотренных
          Container(
            margin: const EdgeInsets.only(bottom: 16),
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.05),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Просмотрено элементов:',
                  style: TextStyle(
                    color: Colors.white.withOpacity(0.7),
                    fontSize: 14,
                  ),
                ),
                Text(
                  '${_group.watchedAnimesCount}/${_updatedAnimes.length}',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
          ),
          
          const SizedBox(height: 8),
          
          ..._updatedAnimes.asMap().entries.map((entry) {
            final index = entry.key;
            final anime = entry.value;
            final isWatched = _group.isAnimeWatched(anime.malId);
            
            return _buildFranchiseItem(anime, index, isWatched);
          }).toList(),
        ],
      ),
    );
  }

  Widget _buildFranchiseItem(Anime anime, int index, bool isWatched) {
    final watchedEpisodes = anime.watchedEpisodes ?? 0;
    final totalEpisodes = anime.episodes ?? 0;
    final hasProgress = watchedEpisodes > 0 && totalEpisodes > 0;
    final hasValidImage = anime.imageUrl != null && 
                         anime.imageUrl!.isNotEmpty && 
                         !anime.imageUrl!.contains('noimage');
    
    // Отладочная информация
    print('🎬 Building item: ${anime.title} (${anime.malId}) - episodes: $totalEpisodes, watched: $isWatched');
    
    return GestureDetector(
      onTap: () async {
        Anime fullAnime;
        try {
          fullAnime = await AnimeService.fetchAnimeById(anime.malId);
        } catch (_) {
          fullAnime = anime;
        }
        
        if (mounted) {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => AnimeDetailScreen(anime: fullAnime),
            ),
          );
        }
      },
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [
              Colors.white.withOpacity(0.05),
              Colors.white.withOpacity(0.02),
            ],
          ),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: isWatched ? const Color(0xFF81C784).withOpacity(0.3) : Colors.white.withOpacity(0.1),
          ),
        ),
        child: Row(
          children: [
            // Галочка просмотра
            GestureDetector(
              onTap: () => _toggleAnimeWatched(anime.malId),
              child: Container(
                width: 24,
                height: 24,
                decoration: BoxDecoration(
                  color: isWatched ? const Color(0xFF81C784) : Colors.transparent,
                  borderRadius: BorderRadius.circular(6),
                  border: Border.all(
                    color: isWatched ? const Color(0xFF81C784) : Colors.white.withOpacity(0.3),
                    width: 2,
                  ),
                ),
                child: isWatched
                    ? const Icon(
                        Icons.check,
                        color: Colors.white,
                        size: 16,
                      )
                    : null,
              ),
            ),
            const SizedBox(width: 12),
            
            // Номер элемента
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [Color(0xFFFF6B6B), Color(0xFFFFD93D)],
                ),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Center(
                child: Text(
                  '${index + 1}',
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                  ),
                ),
              ),
            ),
            const SizedBox(width: 12),
            
            // Изображение аниме
            Container(
              width: 50,
              height: 70,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(8),
                color: Colors.white.withOpacity(0.1),
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: hasValidImage
                    ? Image.network(
                        anime.imageUrl!,
                        fit: BoxFit.cover,
                        errorBuilder: (_, __, ___) => _buildAnimeImagePlaceholder(),
                      )
                    : _buildAnimeImagePlaceholder(),
              ),
            ),
            const SizedBox(width: 12),
            
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    anime.title,
                    style: TextStyle(
                      color: isWatched ? const Color(0xFF81C784) : Colors.white,
                      fontSize: 14,
                      fontWeight: FontWeight.bold,
                      decoration: isWatched ? TextDecoration.lineThrough : TextDecoration.none,
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      if (anime.score != null && anime.score! > 0) ...[
                        const Icon(
                          Icons.star,
                          color: Color(0xFFFFD93D),
                          size: 14,
                        ),
                        const SizedBox(width: 4),
                        Text(
                          '${anime.score}',
                          style: const TextStyle(
                            color: Color(0xFFFFD93D),
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(width: 12),
                      ],
                      if (anime.episodes != null && anime.episodes! > 0) ...[
                        Icon(
                          Icons.movie_filter,
                          color: Colors.white.withOpacity(0.5),
                          size: 14,
                        ),
                        const SizedBox(width: 4),
                        Text(
                          '${anime.episodes} эп',
                          style: TextStyle(
                            color: Colors.white.withOpacity(0.5),
                            fontSize: 12,
                          ),
                        ),
                      ],
                    ],
                  ),
                ],
              ),
            ),
            Icon(
              Icons.arrow_forward_ios,
              color: Colors.white.withOpacity(0.3),
              size: 16,
            ),
          ],
        ),
      ).animate().fadeIn(duration: 300.ms, delay: (index * 50).ms).slideX(
        begin: -0.1,
        end: 0,
        duration: 300.ms,
        curve: Curves.easeOut,
      ),
    );
  }

  Widget _buildAnimeImagePlaceholder() {
    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            Colors.white.withOpacity(0.1),
            Colors.white.withOpacity(0.05),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
      ),
      child: const Icon(
        Icons.movie,
        color: Colors.white30,
        size: 24,
      ),
    );
  }

  Widget _buildGradientButton(String text, {required IconData icon}) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      decoration: BoxDecoration(
        gradient: const LinearGradient(colors: [Color(0xFF6366F1), Color(0xFF8B5CF6)]),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(mainAxisSize: MainAxisSize.min, children: [
        Text(text, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 14)),
        const SizedBox(width: 4),
        Icon(icon, color: Colors.white, size: 18),
      ]),
    );
  }

  BoxDecoration _cardDecoration() => BoxDecoration(
        gradient: const LinearGradient(colors: [Color(0xFF1A1A1A), Color(0xFF0F0F0F)]),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: Colors.white.withOpacity(0.1)),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.3), blurRadius: 20, offset: const Offset(0, 10))],
      );

  Widget _buildSectionHeader(IconData icon, String title, {LinearGradient? gradient}) {
    return Row(
      children: [
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(gradient: gradient, borderRadius: BorderRadius.circular(16)),
          child: Icon(icon, color: Colors.white, size: 24),
        ),
        const SizedBox(width: 12),
        Text(title, style: const TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold)),
      ],
    );
  }
}