// card_gallery_screen.dart
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:hive/hive.dart';
import 'dart:ui';
import 'dart:math' as math;
import '../models/anime_card.dart';
import '../services/card_game_service.dart';

class CardGalleryScreen extends StatefulWidget {
  const CardGalleryScreen({super.key});

  @override
  State<CardGalleryScreen> createState() => _CardGalleryScreenState();
}

class _CardGalleryScreenState extends State<CardGalleryScreen>
    with TickerProviderStateMixin {
  late AnimationController _fadeController;
  late AnimationController _bgAnimController;
  
  List<AnimeCard> _allCards = [];
  List<AnimeCard> _playerCollection = [];
  Set<String> _ownedCardIds = {};
  bool _isLoading = true;
  
  String _searchQuery = '';
  CardRarity? _selectedRarity;
  GallerySortType _sortType = GallerySortType.recent;

  @override
  void initState() {
    super.initState();
    
    _fadeController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 800),
    );
    
    _bgAnimController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 10),
    )..repeat();
    
    _loadGalleryData();
  }

  Future<void> _loadGalleryData() async {
    try {
      final collection = await CardGameService.getCollection();
      final ownedIds = collection.map((card) => card.baseCardId).toSet();
      
      final allCards = <AnimeCard>[];
      
      // Собираем все возможные карты из всех рарити
      for (final rarity in CardRarity.values) {
        final cardsOfRarity = CardGameService.getCardsByRarity(rarity);
        allCards.addAll(cardsOfRarity);
      }
      
      if (mounted) {
        setState(() {
          _allCards = allCards;
          _playerCollection = collection;
          _ownedCardIds = ownedIds;
          _isLoading = false;
        });
        _fadeController.forward();
      }
    } catch (e) {
      debugPrint('Ошибка при загрузке галереи: $e');
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  List<AnimeCard> get _filteredCards {
    var cards = _allCards;
    
    // Фильтр по рарити
    if (_selectedRarity != null) {
      cards = cards.where((c) => c.rarity == _selectedRarity).toList();
    }
    
    // Фильтр по поиску
    if (_searchQuery.isNotEmpty) {
      cards = cards
          .where((c) =>
              c.characterName.toLowerCase().contains(_searchQuery.toLowerCase()) ||
              c.animeName.toLowerCase().contains(_searchQuery.toLowerCase()))
          .toList();
    }
    
    // Сортировка
    cards = _applySorting(cards);
    
    return cards;
  }

  List<AnimeCard> _applySorting(List<AnimeCard> cards) {
    switch (_sortType) {
      case GallerySortType.recent:
        // Для недавно полученных сортируем коллекцию игрока
        final recentlyObtained = _playerCollection
          ..sort((a, b) => b.obtainedAt.compareTo(a.obtainedAt));
        final recentIds = recentlyObtained.map((c) => c.baseCardId).toSet();
        
        return cards
          ..sort((a, b) {
            final aRecent = recentIds.contains(a.baseCardId);
            final bRecent = recentIds.contains(b.baseCardId);
            if (aRecent && !bRecent) return -1;
            if (!aRecent && bRecent) return 1;
            return a.rarity.index.compareTo(b.rarity.index);
          });
        
      case GallerySortType.rarity:
        return cards
          ..sort((a, b) => b.rarity.index.compareTo(a.rarity.index));
        
      case GallerySortType.name:
        return cards
          ..sort((a, b) => a.characterName.compareTo(b.characterName));
        
      case GallerySortType.anime:
        return cards
          ..sort((a, b) => a.animeName.compareTo(b.animeName));
    }
  }

  int get _ownedCount {
    return _filteredCards.where((c) => _ownedCardIds.contains(c.baseCardId)).length;
  }

  int get _totalCount => _filteredCards.length;

  @override
  void dispose() {
    _fadeController.dispose();
    _bgAnimController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0A0A1A),
      body: Stack(
        children: [
          _buildAnimatedBackground(),
          _isLoading
              ? _buildLoadingState()
              : FadeTransition(
                  opacity: _fadeController,
                  child: CustomScrollView(
                    physics: const BouncingScrollPhysics(),
                    slivers: [
                      _buildAppBar(),
                      _buildStats(),
                      _buildFilters(),
                      _buildSortSection(),
                      _buildGalleryGrid(),
                    ],
                  ),
                ),
        ],
      ),
    );
  }

  Widget _buildAnimatedBackground() {
    return AnimatedBuilder(
      animation: _bgAnimController,
      builder: (context, child) {
        return Container(
          decoration: BoxDecoration(
            gradient: RadialGradient(
              center: Alignment(
                math.sin(_bgAnimController.value * 2 * math.pi) * 0.5,
                math.cos(_bgAnimController.value * 2 * math.pi) * 0.5,
              ),
              radius: 1.8,
              colors: const [
                Color(0xFF2A0A3A),
                Color(0xFF0A0A1A),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildLoadingState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          CircularProgressIndicator(
            valueColor: const AlwaysStoppedAnimation<Color>(Color(0xFFFF3366)),
            strokeWidth: 3,
          ),
          const SizedBox(height: 16),
          const Text(
            'Загрузка галереи...',
            style: TextStyle(
              color: Colors.white70,
              fontSize: 16,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAppBar() {
    return SliverAppBar(
      expandedHeight: 140,
      floating: false,
      pinned: true,
      backgroundColor: Colors.transparent,
      elevation: 0,
      leading: IconButton(
        icon: Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(0.1),
            borderRadius: const BorderRadius.all(Radius.circular(12)),
          ),
          child: const Icon(Icons.arrow_back_rounded, color: Colors.white, size: 20),
        ),
        onPressed: () => Navigator.pop(context),
      ),
      flexibleSpace: FlexibleSpaceBar(
        title: const Text(
          'Галерея карт',
          style: TextStyle(
            fontSize: 24,
            fontWeight: FontWeight.bold,
            color: Colors.white,
            shadows: [
              Shadow(
                color: Colors.black,
                blurRadius: 10,
              ),
            ],
          ),
        ),
        centerTitle: true,
        background: Container(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [
                Color(0x30FF3366),
                Colors.transparent,
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildStats() {
    return SliverToBoxAdapter(
      child: Container(
        margin: const EdgeInsets.fromLTRB(20, 10, 20, 16),
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              Color(0x1AFF3366),
              Color(0x142196F3),
            ],
          ),
          borderRadius: const BorderRadius.all(Radius.circular(20)),
          border: Border.all(
            color: Colors.white.withOpacity(0.15),
            width: 1.5,
          ),
          boxShadow: const [
            BoxShadow(
              color: Color(0x1AFF3366),
              blurRadius: 20,
              spreadRadius: 2,
            ),
          ],
        ),
        child: Row(
          children: [
            Container(
              width: 60,
              height: 60,
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  colors: [Color(0xFFFF3366), Color(0xFFFF6B6B)],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.all(Radius.circular(16)),
                boxShadow: [
                  BoxShadow(
                    color: Color(0x66FF3366),
                    blurRadius: 15,
                    spreadRadius: 2,
                  ),
                ],
              ),
              child: const Icon(Icons.collections_bookmark, color: Colors.white, size: 28),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Коллекция',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    'Получено карт: $_ownedCount/$_totalCount',
                    style: const TextStyle(
                      color: Colors.white70,
                      fontSize: 14,
                    ),
                  ),
                  const SizedBox(height: 8),
                  ClipRRect(
                    borderRadius: const BorderRadius.all(Radius.circular(6)),
                    child: LinearProgressIndicator(
                      value: _totalCount > 0 ? _ownedCount / _totalCount : 0,
                      backgroundColor: Colors.white.withOpacity(0.1),
                      color: const Color(0xFFFF3366),
                      minHeight: 6,
                    ),
                  ),
                ],
              ),
            ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  colors: [Color(0xFF4CAF50), Color(0xFF45A049)],
                ),
                borderRadius: BorderRadius.all(Radius.circular(12)),
                boxShadow: [
                  BoxShadow(
                    color: Color(0x664CAF50),
                    blurRadius: 12,
                    spreadRadius: 1,
                  ),
                ],
              ),
              child: Text(
                '${_totalCount > 0 ? ((_ownedCount / _totalCount) * 100).toStringAsFixed(1) : '0'}%',
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ],
        ),
      ).animate().fadeIn(duration: 500.ms).slideY(begin: -0.5, end: 0),
    );
  }

  Widget _buildFilters() {
    return SliverToBoxAdapter(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 0, 20, 16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Поисковая строка
            Container(
              decoration: BoxDecoration(
                borderRadius: const BorderRadius.all(Radius.circular(16)),
                gradient: const LinearGradient(
                  colors: [
                    Color(0x14FFFFFF),
                    Color(0x08FFFFFF),
                  ],
                ),
                border: Border.all(color: Colors.white.withOpacity(0.15)),
                boxShadow: const [
                  BoxShadow(
                    color: Color(0x33000000),
                    blurRadius: 10,
                    spreadRadius: 1,
                  ),
                ],
              ),
              child: TextField(
                style: const TextStyle(color: Colors.white, fontSize: 16),
                decoration: InputDecoration(
                  hintText: 'Поиск персонажа или аниме...',
                  hintStyle: TextStyle(
                    color: Colors.white.withOpacity(0.4),
                    fontSize: 14,
                  ),
                  prefixIcon: Icon(
                    Icons.search_rounded,
                    color: Colors.white.withOpacity(0.5),
                    size: 22,
                  ),
                  border: InputBorder.none,
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 20,
                    vertical: 16,
                  ),
                ),
                onChanged: (value) {
                  setState(() => _searchQuery = value);
                },
              ),
            ),
            const SizedBox(height: 16),
            
            // Фильтр по рарити
            const Padding(
              padding: EdgeInsets.only(left: 4, bottom: 8),
              child: Text(
                'Фильтр по редкости:',
                style: TextStyle(
                  color: Colors.white70,
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
            SizedBox(
              height: 50,
              child: ListView(
                scrollDirection: Axis.horizontal,
                children: [
                  const SizedBox(width: 4),
                  _buildRarityFilter(null, 'Все'),
                  ...CardRarity.values.map((r) => _buildRarityFilter(r, r.displayName)),
                  const SizedBox(width: 4),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildRarityFilter(CardRarity? rarity, String label) {
    final isSelected = _selectedRarity == rarity;
    final color = rarity?.borderColor ?? const Color(0xFFFF3366);
    
    return GestureDetector(
      onTap: () {
        HapticFeedback.lightImpact();
        setState(() => _selectedRarity = isSelected ? null : rarity);
      },
      child: AnimatedContainer(
        duration: 300.ms,
        margin: const EdgeInsets.only(right: 8),
        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
        decoration: BoxDecoration(
          borderRadius: const BorderRadius.all(Radius.circular(14)),
          gradient: isSelected
              ? LinearGradient(
                  colors: [color, Color.alphaBlend(const Color(0x66FFFFFF), color)],
                )
              : const LinearGradient(
                  colors: [
                    Color(0x14FFFFFF),
                    Color(0x08FFFFFF),
                  ],
                ),
          border: Border.all(
            color: isSelected
                ? Colors.white.withOpacity(0.3)
                : Colors.white.withOpacity(0.15),
            width: 1.5,
          ),
          boxShadow: isSelected
              ? [
                  BoxShadow(
                    color: color.withOpacity(0.3),
                    blurRadius: 15,
                    spreadRadius: 1,
                  ),
                ]
              : [],
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (rarity != null) ...[
              Icon(
                Icons.star,
                color: isSelected ? Colors.white : color,
                size: 16,
              ),
              const SizedBox(width: 6),
            ],
            Text(
              label,
              style: TextStyle(
                color: Colors.white,
                fontWeight: isSelected ? FontWeight.bold : FontWeight.w600,
                fontSize: 13,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSortSection() {
    return SliverToBoxAdapter(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 0, 20, 16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Padding(
              padding: EdgeInsets.only(left: 4, bottom: 8),
              child: Text(
                'Сортировка:',
                style: TextStyle(
                  color: Colors.white70,
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
            SizedBox(
              height: 50,
              child: ListView(
                scrollDirection: Axis.horizontal,
                children: [
                  const SizedBox(width: 4),
                  ...GallerySortType.values.map((sortType) => _buildSortButton(sortType)),
                  const SizedBox(width: 4),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSortButton(GallerySortType sortType) {
    final isSelected = _sortType == sortType;
    const selectedColor = Color(0xFF2196F3);
    
    return GestureDetector(
      onTap: () {
        HapticFeedback.lightImpact();
        setState(() => _sortType = sortType);
      },
      child: AnimatedContainer(
        duration: 300.ms,
        margin: const EdgeInsets.only(right: 8),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(
          borderRadius: const BorderRadius.all(Radius.circular(14)),
          gradient: isSelected
              ? const LinearGradient(
                  colors: [Color(0xFF2196F3), Color(0xFF1976D2)],
                )
              : const LinearGradient(
                  colors: [
                    Color(0x14FFFFFF),
                    Color(0x08FFFFFF),
                  ],
                ),
          border: Border.all(
            color: isSelected
                ? Colors.white.withOpacity(0.3)
                : Colors.white.withOpacity(0.15),
            width: 1.5,
          ),
          boxShadow: isSelected
              ? [
                  const BoxShadow(
                    color: Color(0x4D2196F3),
                    blurRadius: 15,
                    spreadRadius: 1,
                  ),
                ]
              : [],
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              _getSortIcon(sortType),
              color: isSelected ? Colors.white : selectedColor,
              size: 16,
            ),
            const SizedBox(width: 6),
            Text(
              _getSortLabel(sortType),
              style: TextStyle(
                color: Colors.white,
                fontWeight: isSelected ? FontWeight.bold : FontWeight.w600,
                fontSize: 13,
              ),
            ),
          ],
        ),
      ),
    );
  }

  IconData _getSortIcon(GallerySortType sortType) {
    switch (sortType) {
      case GallerySortType.recent:
        return Icons.access_time_rounded;
      case GallerySortType.rarity:
        return Icons.star_rounded;
      case GallerySortType.name:
        return Icons.sort_by_alpha_rounded;
      case GallerySortType.anime:
        return Icons.movie_rounded;
    }
  }

  String _getSortLabel(GallerySortType sortType) {
    switch (sortType) {
      case GallerySortType.recent:
        return 'Недавние';
      case GallerySortType.rarity:
        return 'Редкость';
      case GallerySortType.name:
        return 'Имя';
      case GallerySortType.anime:
        return 'Аниме';
    }
  }

  Widget _buildGalleryGrid() {
    final filteredCards = _filteredCards;
    
    if (filteredCards.isEmpty) {
      return SliverToBoxAdapter(
        child: Container(
          height: 300,
          margin: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            borderRadius: const BorderRadius.all(Radius.circular(20)),
            gradient: const LinearGradient(
              colors: [
                Color(0x0DFFFFFF),
                Color(0x05FFFFFF),
              ],
            ),
            border: Border.all(color: Colors.white.withOpacity(0.1)),
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                Icons.search_off_rounded,
                size: 64,
                color: Colors.white.withOpacity(0.3),
              ),
              const SizedBox(height: 16),
              Text(
                'Карты не найдены',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w600,
                  color: Colors.white.withOpacity(0.7),
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'Попробуйте изменить фильтры или поисковый запрос',
                style: TextStyle(
                  fontSize: 14,
                  color: Colors.white.withOpacity(0.5),
                ),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      );
    }

    return SliverPadding(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
      sliver: SliverGrid(
        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 2,
          childAspectRatio: 0.72,
          crossAxisSpacing: 12,
          mainAxisSpacing: 12,
        ),
        delegate: SliverChildBuilderDelegate(
          (context, index) {
            final card = filteredCards[index];
            final isOwned = _ownedCardIds.contains(card.baseCardId);
            
            return _GalleryCardItem(
              card: card,
              isOwned: isOwned,
              index: index,
              playerCollection: _playerCollection,
            );
          },
          childCount: filteredCards.length,
        ),
      ),
    );
  }
}

class _GalleryCardItem extends StatelessWidget {
  final AnimeCard card;
  final bool isOwned;
  final int index;
  final List<AnimeCard> playerCollection;

  const _GalleryCardItem({
    required this.card,
    required this.isOwned,
    required this.index,
    required this.playerCollection,
  });

  bool _isRecentlyObtained() {
    final oneWeekAgo = DateTime.now().subtract(const Duration(days: 7));
    final playerCard = playerCollection.firstWhere(
      (c) => c.baseCardId == card.baseCardId,
      orElse: () => card,
    );
    return playerCard.obtainedAt.isAfter(oneWeekAgo);
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () {
        if (isOwned) {
          _showCardDetails(context, card);
        }
      },
      child: Container(
        decoration: BoxDecoration(
          borderRadius: const BorderRadius.all(Radius.circular(18)),
          border: Border.all(
            color: isOwned
                ? card.rarity.borderColor.withOpacity(0.6)
                : Colors.white.withOpacity(0.15),
            width: isOwned ? 2 : 1.5,
          ),
          boxShadow: isOwned
              ? [
                  BoxShadow(
                    color: card.rarity.borderColor.withOpacity(0.3),
                    blurRadius: 15,
                    spreadRadius: 2,
                  ),
                ]
              : const [
                  BoxShadow(
                    color: Color(0x4D000000),
                    blurRadius: 10,
                    spreadRadius: 1,
                  ),
                ],
        ),
        child: ClipRRect(
          borderRadius: const BorderRadius.all(Radius.circular(16)),
          child: Stack(
            fit: StackFit.expand,
            children: [
              // Фон карты
              Container(
                decoration: BoxDecoration(
                  gradient: isOwned
                      ? LinearGradient(
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                          colors: [
                            card.rarity.borderColor.withOpacity(0.15),
                            card.rarity.borderColor.withOpacity(0.05),
                          ],
                        )
                      : const LinearGradient(
                          colors: [
                            Color(0x08FFFFFF),
                            Color(0x03FFFFFF),
                          ],
                        ),
                ),
              ),

              // Изображение карты
              CachedNetworkImage(
                imageUrl: card.imageUrl,
                fit: BoxFit.cover,
                placeholder: (context, url) => Container(
                  color: isOwned ? const Color(0x42000000) : const Color(0x61000000),
                  child: Center(
                    child: CircularProgressIndicator(
                      valueColor: AlwaysStoppedAnimation<Color>(
                        isOwned ? card.rarity.borderColor : Colors.white30,
                      ),
                      strokeWidth: 2,
                    ),
                  ),
                ),
                errorWidget: (context, url, error) => Container(
                  color: isOwned ? const Color(0x42000000) : const Color(0x61000000),
                  child: Center(
                    child: Icon(
                      Icons.person_rounded,
                      size: 40,
                      color: isOwned ? card.rarity.borderColor.withOpacity(0.5) : Colors.white30,
                    ),
                  ),
                ),
              ),

              // Оверлей для неполученных карт
              if (!isOwned)
                Container(
                  decoration: const BoxDecoration(
                    color: Color(0xB3000000),
                  ),
                  child: Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.lock_rounded,
                          color: Colors.white.withOpacity(0.6),
                          size: 32,
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'Не получено',
                          style: TextStyle(
                            color: Colors.white.withOpacity(0.8),
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),

              // Градиент для текста
              Positioned(
                bottom: 0,
                left: 0,
                right: 0,
                child: Container(
                  height: 80,
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [
                        Colors.transparent,
                        Colors.black.withOpacity(isOwned ? 0.9 : 0.95),
                      ],
                    ),
                  ),
                ),
              ),

              // Информация о карте
              Positioned(
                bottom: 0,
                left: 0,
                right: 0,
                child: Padding(
                  padding: const EdgeInsets.all(12),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        card.characterName,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 14,
                          fontWeight: FontWeight.bold,
                          shadows: [
                            Shadow(
                              color: Colors.black,
                              blurRadius: 8,
                            ),
                          ],
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 4),
                      Text(
                        card.animeName,
                        style: TextStyle(
                          color: Colors.white.withOpacity(0.8),
                          fontSize: 11,
                          fontWeight: FontWeight.w500,
                          shadows: const [
                            Shadow(
                              color: Colors.black,
                              blurRadius: 6,
                            ),
                          ],
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
              ),

              // Бейдж рарити
              Positioned(
                top: 8,
                right: 8,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [
                        card.rarity.borderColor.withOpacity(0.9),
                        card.rarity.borderColor.withOpacity(0.7),
                      ],
                    ),
                    borderRadius: const BorderRadius.all(Radius.circular(10)),
                    boxShadow: [
                      BoxShadow(
                        color: card.rarity.borderColor.withOpacity(0.4),
                        blurRadius: 8,
                        spreadRadius: 1,
                      ),
                    ],
                  ),
                  child: Text(
                    card.rarity.displayName,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 10,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ),

              // Индикатор "NEW" для недавно полученных
              if (isOwned && _isRecentlyObtained())
                Positioned(
                  top: 8,
                  left: 8,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: const BoxDecoration(
                      gradient: LinearGradient(
                        colors: [Color(0xFFFF3366), Color(0xFFFF6B6B)],
                      ),
                      borderRadius: BorderRadius.all(Radius.circular(8)),
                      boxShadow: [
                        BoxShadow(
                          color: Color(0x66FF3366),
                          blurRadius: 8,
                          spreadRadius: 1,
                        ),
                      ],
                    ),
                    child: const Text(
                      'NEW',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 9,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    ).animate(delay: (index * 50).ms)
        .fadeIn(duration: 400.ms)
        .slideY(begin: 0.2, end: 0, curve: Curves.easeOutCubic);
  }

  void _showCardDetails(BuildContext context, AnimeCard card) {
    showDialog(
      context: context,
      builder: (context) => Dialog(
        backgroundColor: Colors.transparent,
        insetPadding: const EdgeInsets.all(20),
        child: _CardDetailsDialog(card: card),
      ),
    );
  }
}

class _CardDetailsDialog extends StatelessWidget {
  final AnimeCard card;

  const _CardDetailsDialog({required this.card});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      constraints: const BoxConstraints(maxWidth: 400),
      decoration: BoxDecoration(
        borderRadius: const BorderRadius.all(Radius.circular(24)),
        gradient: const LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            Color(0xFF1A0A1A),
            Color(0xFF0A0A1A),
          ],
        ),
        border: Border.all(
          color: Colors.white.withOpacity(0.12),
          width: 2,
        ),
        boxShadow: [
          BoxShadow(
            color: card.rarity.borderColor.withOpacity(0.3),
            blurRadius: 40,
            spreadRadius: 10,
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Заголовок
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  card.rarity.borderColor.withOpacity(0.15),
                  card.rarity.borderColor.withOpacity(0.05),
                ],
              ),
              borderRadius: const BorderRadius.only(
                topLeft: Radius.circular(24),
                topRight: Radius.circular(24),
              ),
            ),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [
                        card.rarity.borderColor.withOpacity(0.8),
                        card.rarity.borderColor.withOpacity(0.6),
                      ],
                    ),
                    borderRadius: const BorderRadius.all(Radius.circular(16)),
                    boxShadow: [
                      BoxShadow(
                        color: card.rarity.borderColor.withOpacity(0.4),
                        blurRadius: 15,
                        spreadRadius: 2,
                      ),
                    ],
                  ),
                  child: const Icon(
                    Icons.auto_awesome_rounded,
                    color: Colors.white,
                    size: 24,
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        card.characterName,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      Text(
                        card.animeName,
                        style: TextStyle(
                          color: Colors.white.withOpacity(0.8),
                          fontSize: 14,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),

          // Изображение карты
          Container(
            height: 200,
            margin: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              borderRadius: const BorderRadius.all(Radius.circular(16)),
              image: DecorationImage(
                image: CachedNetworkImageProvider(card.imageUrl),
                fit: BoxFit.cover,
              ),
              boxShadow: [
                BoxShadow(
                  color: card.rarity.borderColor.withOpacity(0.3),
                  blurRadius: 20,
                  spreadRadius: 2,
                ),
              ],
            ),
          ),

          // Информация
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: Column(
              children: [
                _buildInfoRow('Редкость', card.rarity.displayName, card.rarity.borderColor),
                const SizedBox(height: 8),
                if ((card.quote ?? '').isNotEmpty) ...[
                  _buildQuoteSection(card.quote!),
                  const SizedBox(height: 12),
                ],
                if ((card.description ?? '').isNotEmpty) ...[
                  _buildDescriptionSection(card.description!),
                  const SizedBox(height: 12),
                ],
              ],
            ),
          ),

          // Кнопка закрытия
          Container(
            padding: const EdgeInsets.all(20),
            child: SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: () => Navigator.pop(context),
                style: ElevatedButton.styleFrom(
                  backgroundColor: card.rarity.borderColor,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: const RoundedRectangleBorder(
                    borderRadius: BorderRadius.all(Radius.circular(12)),
                  ),
                  elevation: 4,
                ),
                child: const Text(
                  'Закрыть',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildInfoRow(String label, String value, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [
            Color(0x0DFFFFFF),
            Color(0x05FFFFFF),
          ],
        ),
        borderRadius: const BorderRadius.all(Radius.circular(12)),
        border: Border.all(color: Colors.white.withOpacity(0.1)),
      ),
      child: Row(
        children: [
          Text(
            '$label:',
            style: TextStyle(
              color: Colors.white.withOpacity(0.7),
              fontSize: 14,
            ),
          ),
          const Spacer(),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              color: color.withOpacity(0.2),
              borderRadius: const BorderRadius.all(Radius.circular(8)),
              border: Border.all(color: color.withOpacity(0.3)),
            ),
            child: Text(
              value,
              style: TextStyle(
                color: color,
                fontSize: 14,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildQuoteSection(String quote) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [
            Color(0x0DFFFFFF),
            Color(0x05FFFFFF),
          ],
        ),
        borderRadius: const BorderRadius.all(Radius.circular(12)),
        border: Border.all(color: Colors.white.withOpacity(0.1)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                Icons.format_quote_rounded,
                color: Colors.white.withOpacity(0.5),
                size: 16,
              ),
              const SizedBox(width: 8),
              Text(
                'Цитата',
                style: TextStyle(
                  color: Colors.white.withOpacity(0.7),
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            quote,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 14,
              fontStyle: FontStyle.italic,
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  Widget _buildDescriptionSection(String description) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [
            Color(0x0DFFFFFF),
            Color(0x05FFFFFF),
          ],
        ),
        borderRadius: const BorderRadius.all(Radius.circular(12)),
        border: Border.all(color: Colors.white.withOpacity(0.1)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                Icons.description_rounded,
                color: Colors.white.withOpacity(0.5),
                size: 16,
              ),
              const SizedBox(width: 8),
              Text(
                'Описание',
                style: TextStyle(
                  color: Colors.white.withOpacity(0.7),
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            description,
            style: TextStyle(
              color: Colors.white.withOpacity(0.9),
              fontSize: 14,
            ),
          ),
        ],
      ),
    );
  }
}

enum GallerySortType {
  recent,
  rarity,
  name,
  anime,
}