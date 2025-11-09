// lib/screens/anime_detail_screen.dart
import 'package:flutter/material.dart';
import 'package:hive/hive.dart';
import 'package:flutter_animate/flutter_animate.dart';
import '../models/anime.dart';
import '../models/character.dart';
import '../models/franchise_group.dart';
import '../widgets/rating_review_block.dart';
import '../helpers/achievement_helper.dart';
import '../services/anime_service.dart';
import 'group_detail_screen.dart';

class AnimeDetailScreen extends StatefulWidget {
  final Anime anime;
  const AnimeDetailScreen({required this.anime, super.key});

  @override
  State<AnimeDetailScreen> createState() => _AnimeDetailScreenState();
}

class _AnimeDetailScreenState extends State<AnimeDetailScreen> with SingleTickerProviderStateMixin {
  String? status;
  bool showFullDescription = false;
  bool isFavorite = false;
  int rating = 0;
  final TextEditingController reviewController = TextEditingController();
  final FocusNode _reviewFocusNode = FocusNode();

  late AnimationController _animController;
  late Animation<double> _fadeAnimation;
  late Animation<Offset> _slideAnimation;

  List<Character> characters = [];
  bool isLoadingCharacters = true;

  final List<String> statuses = ["Планирую", "Смотрю", "Просмотрено", "Брошено", "Онгоинг"];
  final Map<String, Color> statusColors = {
    "Планирую": const Color(0xFFFFD54F),
    "Смотрю": const Color(0xFF4FC3F7),
    "Просмотрено": const Color(0xFF81C784),
    "Брошено": const Color(0xFFE57373),
    "Онгоинг": const Color(0xFF1565C0),
  };
  final Map<String, IconData> statusIcons = {
    "Планирую": Icons.schedule,
    "Смотрю": Icons.play_circle_filled,
    "Просмотрено": Icons.check_circle,
    "Брошено": Icons.cancel,
    "Онгоинг": Icons.trending_up,
  };

  @override
  void initState() {
    super.initState();

    _reviewFocusNode.addListener(() {
      if (!_reviewFocusNode.hasFocus) _updateHive();
    });

    _animController = AnimationController(vsync: this, duration: const Duration(milliseconds: 800));
    _fadeAnimation = CurvedAnimation(parent: _animController, curve: Curves.easeOut);
    _slideAnimation = Tween<Offset>(begin: const Offset(0, 0.3), end: Offset.zero)
        .animate(CurvedAnimation(parent: _animController, curve: Curves.easeOut));
    _animController.forward();

    _loadFromHive();
    _loadCharacters();
  }

  Future<void> _loadFromHive() async {
    final box = await Hive.openBox('myListBox');
    final data = box.get(widget.anime.malId);
    if (data != null) {
      setState(() {
        status = data['status'] ?? widget.anime.status ?? 'Планирую';
        rating = data['score'] ?? 0;
        isFavorite = data['isFavorite'] ?? false;
        reviewController.text = data['review'] ?? '';
      });
    }
  }

  Future<void> _updateHive() async {
    final box = Hive.box('myListBox');
    final data = {
      'malId': widget.anime.malId,
      'title': widget.anime.title,
      'imageUrl': widget.anime.imageUrl,
      'status': status,
      'score': rating,
      'isFavorite': isFavorite,
      'review': reviewController.text,
    };
    await box.put(widget.anime.malId, data);
    await AchievementHelper.checkAndShowAchievements();
  }

  Future<void> _loadCharacters() async {
    setState(() => isLoadingCharacters = true);
    try {
      final result = await AnimeService.fetchCharacters(widget.anime.malId);
      print("Loaded characters: $result"); // <-- вот это
      setState(() {
        characters = result;
      });
    } catch (e) {
      debugPrint('Ошибка загрузки персонажей: $e');
    } finally {
      setState(() => isLoadingCharacters = false);
    }
  }

  Future<void> _addEntireFranchise() async {
  try {
    print('🎬 Начало добавления франшизы для аниме: ${widget.anime.malId}');
    
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => Center(
        child: Container(
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            color: const Color(0xFF1A1A1A),
            borderRadius: BorderRadius.circular(20),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const CircularProgressIndicator(
                valueColor: AlwaysStoppedAnimation<Color>(Color(0xFFFF6B6B)),
              ),
              const SizedBox(height: 16),
              const Text(
                'Загрузка франшизы...',
                style: TextStyle(color: Colors.white, fontSize: 16),
              ),
            ],
          ),
        ),
      ),
    );

    // Получаем франшизу
    print('📡 Запрос франшизы для ID: ${widget.anime.malId}');
    final franchiseAnimes = await AnimeService.fetchFranchise(widget.anime.malId);
    print('✅ Получено элементов франшизы: ${franchiseAnimes.length}');
    
    if (!mounted) return;
    Navigator.pop(context);

    if (franchiseAnimes.isEmpty || franchiseAnimes.length == 1) {
      print('ℹ️ Франшиза не найдена или содержит только 1 элемент');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('Франшиза не найдена или содержит только это аниме'),
          backgroundColor: const Color(0xFF1A1A1A),
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        ),
      );
      return;
    }

    // Очищаем аниме от сложных объектов для сохранения в Hive
    final cleanedAnimes = franchiseAnimes.map((anime) {
      return Anime(
        malId: anime.malId,
        title: anime.title,
        imageUrl: anime.imageUrl,
        synopsis: anime.synopsis,
        score: anime.score,
        episodes: anime.episodes,
        genres: anime.genres,
        type: anime.type,
        kind: anime.kind,
        status: 'Планирую',
        isFavorite: false,
        watchedEpisodes: 0,
      );
    }).toList();

    print('🧹 Очищено аниме: ${cleanedAnimes.length} элементов');

    // Создаём группу
    final franchiseGroup = FranchiseGroup(
  id: widget.anime.malId,
  title: widget.anime.title
      .replaceAll(RegExp(r'\s*(?:Сезон|Season)\s*\d+', caseSensitive: false), '')
      .trim(),
  animes: cleanedAnimes,
  imageUrl: widget.anime.imageUrl, // Добавляем изображение
  status: 'Планирую',
  isFavorite: false,
  review: '',
);

    print('✅ FranchiseGroup создана с ID: ${franchiseGroup.id}');

    // Сохраняем группу
    final box = await Hive.openBox('myListBox');
    final hiveKey = 'group_${franchiseGroup.id}';
    print('💾 Сохранение в Hive с ключом: $hiveKey');
    
    await box.put(hiveKey, franchiseGroup.toMap());
    print('💽 Успешно сохранено в Hive');

    if (!mounted) return;

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          'Франшиза "${franchiseGroup.title}" добавлена (${cleanedAnimes.length} элементов)',
        ),
        backgroundColor: const Color(0xFF1A1A1A),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        action: SnackBarAction(
          label: 'Открыть',
          textColor: const Color(0xFFFF6B6B),
          onPressed: () {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => GroupDetailScreen(group: franchiseGroup),
              ),
            );
          },
        ),
      ),
    );

    setState(() {});
  } catch (e, stackTrace) {
    print('❌ КРИТИЧЕСКАЯ ОШИБКА при добавлении франшизы: $e');
    print('📋 Stack trace: $stackTrace');
    
    if (!mounted) return;
    
    if (Navigator.canPop(context)) {
      Navigator.pop(context);
    }
    
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Ошибка загрузки франшизы: ${e.toString()}'),
        backgroundColor: const Color(0xFFEF4444),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        duration: const Duration(seconds: 5),
      ),
    );
  }
}

  Widget _buildFranchiseButton() {
  return Container(
    margin: const EdgeInsets.symmetric(vertical: 8),
    padding: const EdgeInsets.all(0),
    decoration: BoxDecoration(
      borderRadius: BorderRadius.circular(20),
      gradient: const LinearGradient(
        colors: [Color(0xFF1E1B2E), Color(0xFF111827)],
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
      ),
      border: Border.all(
        color: const Color(0xFF8B5CF6).withOpacity(0.3),
        width: 1.5,
      ),
      boxShadow: [
        BoxShadow(
          color: const Color(0xFF8B5CF6).withOpacity(0.15),
          blurRadius: 20,
          offset: const Offset(0, 10),
        ),
      ],
    ),
    child: Material(
      color: Colors.transparent,
      borderRadius: BorderRadius.circular(20),
      child: InkWell(
        onTap: _addEntireFranchise,
        borderRadius: BorderRadius.circular(20),
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Row(
            children: [
              Container(
                width: 50,
                height: 50,
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [Color(0xFF8B5CF6), Color(0xFFEC4899)],
                  ),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(Icons.layers, color: Colors.white, size: 28),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Франшиза',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Добавить все части и сезоны',
                      style: TextStyle(
                        color: Colors.white.withOpacity(0.7),
                        fontSize: 13,
                      ),
                    ),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: const Color(0xFF8B5CF6).withOpacity(0.2),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(
                    color: const Color(0xFF8B5CF6).withOpacity(0.5),
                  ),
                ),
                child: const Icon(
                  Icons.arrow_forward,
                  color: Color(0xFF8B5CF6),
                  size: 20,
                ),
              ),
            ],
          ),
        ),
      ),
    ),
  ).animate()
    .fadeIn(duration: 400.ms, delay: 100.ms)
    .slideY(begin: 0.2, end: 0, duration: 400.ms, curve: Curves.easeOut);
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
    final anime = widget.anime;
    final description = anime.synopsis ?? "Описание отсутствует";
    final shortDescription = description.length > 300 ? "${description.substring(0, 300)}..." : description;

    return Scaffold(
      backgroundColor: const Color(0xFF0A0A0A),
      body: CustomScrollView(
        slivers: [
          _buildAppBar(anime),
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
                      _buildInfoCard(anime),
                      const SizedBox(height: 20),
                      _buildFranchiseButton(), // ПЕРЕМЕЩЕНО ВЫШЕ
                      const SizedBox(height: 20),
                      _buildDescriptionCard(description, shortDescription),
                      const SizedBox(height: 20),
                      _buildCharactersBlock(),
                      const SizedBox(height: 20),
                      _buildInteractionCard(),
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

  Widget _buildAppBar(Anime anime) {
    return SliverAppBar(
      expandedHeight: 320,
      pinned: true,
      backgroundColor: const Color(0xFF0A0A0A),
      leading: _buildIconButton(Icons.arrow_back_ios_new, () => Navigator.pop(context)),
      actions: [
        _buildIconButton(
          isFavorite ? Icons.favorite : Icons.favorite_border,
          () async {
            setState(() => isFavorite = !isFavorite);
            await _updateHive();
          },
          color: isFavorite ? Colors.pinkAccent : Colors.white,
        ),
      ],
      flexibleSpace: FlexibleSpaceBar(
        background: Stack(
          fit: StackFit.expand,
          children: [
            Image.network(anime.imageUrl, fit: BoxFit.cover),
            Container(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [Colors.transparent, Colors.black.withOpacity(0.8), const Color(0xFF0A0A0A)],
                ),
              ),
            ),
            Positioned(
              bottom: 20,
              left: 20,
              right: 20,
              child: Text(
                anime.title,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 28,
                  fontWeight: FontWeight.bold,
                  shadows: [Shadow(color: Colors.black, blurRadius: 8)],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildIconButton(IconData icon, VoidCallback onPressed, {Color color = Colors.white}) {
    return Container(
      margin: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: Colors.black.withOpacity(0.5),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.white.withOpacity(0.1)),
      ),
      child: IconButton(icon: Icon(icon, color: color), onPressed: onPressed),
    );
  }

  Widget _buildInfoCard(Anime anime) {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: _cardDecoration(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildSectionHeader(Icons.info_outline, "Информация",
              gradient: const LinearGradient(colors: [Color(0xFF6366F1), Color(0xFF8B5CF6)])),
          const SizedBox(height: 20),
          _buildInfoGrid(anime),
          if (anime.genres != null && anime.genres!.isNotEmpty) ...[
            const SizedBox(height: 20),
            const Text('Жанры:', style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold)),
            const SizedBox(height: 12),
            Wrap(spacing: 8, runSpacing: 8, children: anime.genres!.map((g) => _buildGenreChip(g)).toList()),
          ],
        ],
      ),
    );
  }

  Widget _buildInfoGrid(Anime anime) {
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
              Expanded(child: _buildInfoItem(Icons.category, 'Тип', anime.type ?? '?')),
              const SizedBox(width: 16),
              Expanded(child: _buildInfoItem(Icons.timelapse, 'Статус', anime.status ?? '?')),
            ],
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(child: _buildInfoItem(Icons.movie_filter, 'Эпизоды', anime.episodes?.toString() ?? '?')),
              const SizedBox(width: 16),
              Expanded(child: _buildInfoItem(Icons.star_rate_rounded, 'Оценка', anime.score?.toString() ?? '?')),
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
          _buildSectionHeader(Icons.description, "Описание",
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
            height: 150, // чуть меньше, чтобы избежать overflow
            child: isLoadingCharacters
                ? Center(
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
                  )
                : characters.isEmpty
                    ? Center(
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
                      )
                    : ListView.separated(
                        scrollDirection: Axis.horizontal,
                        physics: const BouncingScrollPhysics(),
                        itemCount: characters.length,
                        separatorBuilder: (_, __) => const SizedBox(width: 16),
                        itemBuilder: (context, index) {
                          final c = characters[index];
                          final displayName = c.name ?? 'Без имени';
                          final imageUrl = c.imageUrl ?? 'https://shikimori.one/images/static/noimage.png';

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
                                    child: Image.network(
                                      imageUrl,
                                      width: double.infinity,
                                      height: double.infinity,
                                      fit: BoxFit.cover,
                                      errorBuilder: (context, error, stackTrace) => Container(
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
                                      ),
                                    ),
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
                      ),
          ),
        ],
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
            currentRating: rating,
            reviewController: reviewController,
            reviewFocusNode: _reviewFocusNode,
            onRatingChanged: (newRating) async {
              setState(() => rating = newRating);
              await _updateHive();
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
        final selected = s == status;
        return InkWell(
          onTap: () async {
            setState(() => status = selected ? null : s);
            await _updateHive();
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