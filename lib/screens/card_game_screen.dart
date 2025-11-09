// screens/card_game_screen.dart
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:hive/hive.dart';
import 'dart:math' as math;
import '../models/anime_card.dart';
import '../services/card_game_service.dart';
import 'card_collection_screen.dart';
import 'card_shop_screen.dart';

class CardGameScreen extends StatefulWidget {
  const CardGameScreen({super.key});

  @override
  State<CardGameScreen> createState() => _CardGameScreenState();
}

class _CardGameScreenState extends State<CardGameScreen>
    with TickerProviderStateMixin {
  int _coins = 1000;
  int _playerLevel = 1;
  int _playerExp = 0;
  bool _isOpening = false;
  List<CardPack> _availablePacks = [];
  late AnimationController _bgAnimController;
  late AnimationController _particleController;

  @override
  void initState() {
    super.initState();
    _bgAnimController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 8),
    )..repeat();
    
    _particleController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 20),
    )..repeat();
    
    _loadPlayerData();
    _loadAvailablePacks();
  }

  @override
  void dispose() {
    _bgAnimController.dispose();
    _particleController.dispose();
    super.dispose();
  }

  Future<void> _loadPlayerData() async {
    try {
      final results = await Future.wait([
        CardGameService.getCoins(),
        CardGameService.getPlayerLevel(),
        CardGameService.getPlayerExp(),
      ]);
      
      if (mounted) {
        setState(() {
          _coins = results[0] as int;
          _playerLevel = results[1] as int;
          _playerExp = results[2] as int;
        });
      }
    } catch (e) {
      debugPrint('Error loading player data: $e');
    }
  }

  Future<void> _loadAvailablePacks() async {
    final packs = [
      CardPack(
        id: 'small_pack',
        title: 'Маленький пак',
        description: '3 случайные карты для начала',
        cost: 100,
        cardsCount: 3,
        color: const Color(0xFF2196F3),
        icon: Icons.auto_awesome,
        expReward: 50,
        rarityWeights: {
          CardRarity.common: 70,
          CardRarity.rare: 22,
          CardRarity.epic: 6,
          CardRarity.legendary: 2,
          CardRarity.mythic: 0,
          CardRarity.divine: 0,
        },
      ),
      CardPack(
        id: 'medium_pack',
        title: 'Средний пак',
        description: '5 карт с улучшенными шансами',
        cost: 150,
        cardsCount: 5,
        color: const Color(0xFF9C27B0),
        icon: Icons.star,
        expReward: 100,
        rarityWeights: {
          CardRarity.common: 60,
          CardRarity.rare: 25,
          CardRarity.epic: 10,
          CardRarity.legendary: 4,
          CardRarity.mythic: 1,
          CardRarity.divine: 0,
        },
      ),
      CardPack(
        id: 'large_pack',
        title: 'Большой пак',
        description: '10 карт для настоящих коллекционеров',
        cost: 250,
        cardsCount: 10,
        color: const Color(0xFFFFB300),
        icon: Icons.dashboard,
        expReward: 250,
        rarityWeights: {
          CardRarity.common: 50,
          CardRarity.rare: 28,
          CardRarity.epic: 12,
          CardRarity.legendary: 7,
          CardRarity.mythic: 2,
          CardRarity.divine: 1,
        },
      ),
      CardPack(
        id: 'premium_pack',
        title: 'Премиум пак',
        description: '8 слитных карт высокого качества',
        cost: 500,
        cardsCount: 8,
        color: const Color(0xFFFF5722),
        icon: Icons.diamond,
        expReward: 400,
        rarityWeights: {
          CardRarity.common: 30,
          CardRarity.rare: 35,
          CardRarity.epic: 20,
          CardRarity.legendary: 10,
          CardRarity.mythic: 4,
          CardRarity.divine: 1,
        },
      ),
    ];

    if (mounted) {
      setState(() {
        _availablePacks = packs;
      });
    }
  }

  Future<void> _openPack(CardPack pack) async {
    if (_isOpening) return;

    if (_coins < pack.cost) {
      _showInsufficientCoinsDialog();
      return;
    }

    setState(() => _isOpening = true);
    
    try {
      final currentCoins = await CardGameService.getCoins();
      if (currentCoins < pack.cost) {
        if (mounted) {
          setState(() => _isOpening = false);
          _showInsufficientCoinsDialog();
        }
        return;
      }

      final spendSuccess = await CardGameService.spendCoins(pack.cost);
      if (!spendSuccess) {
        if (mounted) {
          setState(() => _isOpening = false);
          _showInsufficientCoinsDialog();
        }
        return;
      }

      await _loadPlayerData();
      
      final cards = await _generatePackCards(pack);
      
      if (cards.isEmpty) {
        throw Exception('Не удалось создать карты');
      }
      
      cards.sort((a, b) => a.rarity.index.compareTo(b.rarity.index));

      if (mounted) {
        final dialogShown = await showDialog<bool>(
          context: context,
          barrierDismissible: false,
          builder: (context) => _PackOpeningDialog(
            pack: pack,
            cards: cards,
          ),
        );
        
        if (mounted && dialogShown == true) {
          _showPackSummary(cards);
        }
      }
    } catch (e) {
      debugPrint('Ошибка открытия пака: $e');
      if (mounted) {
        _showErrorDialog();
        await CardGameService.addCoins(pack.cost);
        await _loadPlayerData();
      }
    } finally {
      if (mounted) {
        setState(() => _isOpening = false);
      }
    }
  }

  Future<List<AnimeCard>> _generatePackCards(CardPack pack) async {
    final List<AnimeCard> generatedCards = [];
    final random = math.Random();
    final allCards = await _getAllBaseCards();
    
    for (int i = 0; i < pack.cardsCount; i++) {
      final rarity = _selectRarityByWeight(pack.rarityWeights, random);
      final cardsOfRarity = allCards.where((card) => card.rarity == rarity).toList();
      
      if (cardsOfRarity.isNotEmpty) {
        final baseCard = cardsOfRarity[random.nextInt(cardsOfRarity.length)];
        final newCard = _createCardFromBase(baseCard);
        generatedCards.add(newCard);
      } else {
        final commonCards = allCards.where((card) => card.rarity == CardRarity.common).toList();
        if (commonCards.isNotEmpty) {
          final baseCard = commonCards[random.nextInt(commonCards.length)];
          final newCard = _createCardFromBase(baseCard);
          generatedCards.add(newCard);
        }
      }
    }

    if (generatedCards.isNotEmpty) {
      await _addCardsToPlayerCollection(generatedCards);
    }

    return generatedCards;
  }

  Future<List<AnimeCard>> _getAllBaseCards() async {
    final allCards = <AnimeCard>[];
    for (final rarity in CardRarity.values) {
      final cards = CardGameService.getCardsByRarity(rarity);
      allCards.addAll(cards);
    }
    return allCards;
  }

  Future<bool> _addCardsToPlayerCollection(List<AnimeCard> cards) async {
    try {
      final currentCollection = await CardGameService.getCollection();
      final updatedCollection = List<AnimeCard>.from(currentCollection ?? []);

      for (final newCard in cards) {
        final existingIndex = updatedCollection.indexWhere(
          (c) => c.baseCardId == newCard.baseCardId && c.level == newCard.level
        );
        if (existingIndex != -1) {
          final existingCard = updatedCollection[existingIndex];
          updatedCollection[existingIndex] = existingCard.copyWith(
            duplicateCount: existingCard.duplicateCount + 1,
          );
        } else {
          updatedCollection.add(newCard);
        }
      }

      final box = await Hive.openBox('gameData');
      final collectionData = updatedCollection.map((card) => card.toJson()).toList();
      await box.put('playerCollection', collectionData);
      
      return true;
    } catch (e) {
      debugPrint('Ошибка при добавлении карт в коллекцию: $e');
      return false;
    }
  }

  CardRarity _selectRarityByWeight(Map<CardRarity, int> weights, math.Random random) {
    final totalWeight = weights.values.reduce((a, b) => a + b);
    final randomValue = random.nextInt(totalWeight);
    
    int currentWeight = 0;
    for (final entry in weights.entries) {
      currentWeight += entry.value;
      if (randomValue < currentWeight) {
        return entry.key;
      }
    }
    
    return CardRarity.common;
  }

  AnimeCard _createCardFromBase(AnimeCard baseCard) {
    return AnimeCard(
      id: 'pack_${baseCard.id}_${DateTime.now().millisecondsSinceEpoch}_${math.Random().nextInt(10000)}',
      characterName: baseCard.characterName ?? 'Unknown',
      animeName: baseCard.animeName ?? 'Unknown Anime',
      imageUrl: baseCard.imageUrl ?? '',
      rarity: baseCard.rarity,
      description: baseCard.description ?? '',
      level: 1,
      skill: baseCard.skill ?? '',
      quote: baseCard.quote ?? '',
      obtainedAt: DateTime.now(),
      genre: baseCard.genre,
      archetype: baseCard.archetype,
      abilityType: baseCard.abilityType,
      stats: baseCard.stats,
      visuals: const CardVisuals(),
      duplicateCount: 1,
      baseCardId: baseCard.baseCardId ?? '',
    );
  }

  void _showPackSummary(List<AnimeCard> cards) {
    showDialog(
      context: context,
      builder: (context) => _PackSummaryDialog(cards: cards),
    );
  }

  void _showInsufficientCoinsDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: Colors.grey[900]?.withOpacity(0.95) ?? Colors.grey,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Row(
          children: [
            Icon(Icons.warning_amber, color: Colors.amber),
            SizedBox(width: 12),
            Text('Недостаточно монет', style: TextStyle(color: Colors.white)),
          ],
        ),
        content: const Text(
          'У вас недостаточно монет для покупки этого пака. Заработайте больше монет в городе или получите ежедневный бонус!',
          style: TextStyle(color: Colors.white70),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            style: TextButton.styleFrom(foregroundColor: Colors.white),
            child: const Text('Понятно'),
          ),
        ],
      ),
    );
  }

  void _showErrorDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: Colors.grey[900]?.withOpacity(0.95) ?? Colors.grey,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Row(
          children: [
            Icon(Icons.error_outline, color: Colors.red),
            SizedBox(width: 12),
            Text('Ошибка', style: TextStyle(color: Colors.white)),
          ],
        ),
        content: const Text(
          'Не удалось открыть пак. Пожалуйста, проверьте подключение и попробуйте позже.',
          style: TextStyle(color: Colors.white70),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            style: TextButton.styleFrom(foregroundColor: Colors.white),
            child: const Text('OK'),
          ),
        ],
      ),
    );
  }

  void _claimDailyBonus() async {
    final success = await CardGameService.addCoins(100);
    if (success && mounted) {
      await _loadPlayerData();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Row(
            children: [
              Icon(Icons.celebration, color: Colors.white),
              SizedBox(width: 8),
              Text('+100 монет! Ежедневный бонус получен.'),
            ],
          ),
          backgroundColor: Colors.green,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        ),
      );
    }
  }

  void _openShop() async {
    await Navigator.push(
      context,
      PageRouteBuilder(
        pageBuilder: (context, animation, secondaryAnimation) => const CardShopScreen(),
        transitionsBuilder: (context, animation, secondaryAnimation, child) {
          return FadeTransition(opacity: animation, child: child);
        },
      ),
    );
    await _loadPlayerData();
  }

  void _openCollection() async {
    await Navigator.push(
      context,
      PageRouteBuilder(
        pageBuilder: (context, animation, secondaryAnimation) => const CardCollectionScreen(),
        transitionsBuilder: (context, animation, secondaryAnimation, child) {
          return FadeTransition(opacity: animation, child: child);
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0A0A1A),
      body: Stack(
        children: [
          _buildAnimatedBackground(),
          _buildParticles(),
          SafeArea(
            child: SingleChildScrollView(
              physics: const BouncingScrollPhysics(),
              padding: const EdgeInsets.all(16),
              child: Column(
                children: [
                  _buildHeaderSection(),
                  const SizedBox(height: 24),
                  _buildActionGrid(),
                  const SizedBox(height: 24),
                  _buildPacksSection(),
                  const SizedBox(height: 24),
                  _buildDailyBonusSection(),
                  const SizedBox(height: 32),
                ],
              ),
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
              colors: [
                const Color(0xFF2A0A3A).withOpacity(0.6),
                const Color(0xFF0A0A1A),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildParticles() {
    return AnimatedBuilder(
      animation: _particleController,
      builder: (context, child) {
        return CustomPaint(
          painter: ParticlePainter(_particleController.value),
          size: Size.infinite,
        );
      },
    );
  }

  Widget _buildHeaderSection() {
    int expNeeded = _playerLevel * 100;
    double expProgress = _playerExp / expNeeded;
    
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            const Color(0xFFFF3366).withOpacity(0.1),
            const Color(0xFF2196F3).withOpacity(0.08),
          ],
        ),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(
          color: Colors.white.withOpacity(0.15),
          width: 1.5,
        ),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFFFF3366).withOpacity(0.1),
            blurRadius: 20,
            spreadRadius: 2,
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            width: 70,
            height: 70,
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [Color(0xFFFF3366), Color(0xFFFF6B6B)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(18),
              boxShadow: [
                BoxShadow(
                  color: const Color(0xFFFF3366).withOpacity(0.4),
                  blurRadius: 15,
                  spreadRadius: 2,
                ),
              ],
            ),
            child: Stack(
              children: [
                const Center(
                  child: Icon(Icons.person, color: Colors.white, size: 32),
                ),
                Positioned(
                  bottom: -4,
                  right: -4,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(
                        colors: [Color(0xFFFFD700), Color(0xFFFFA500)],
                      ),
                      borderRadius: BorderRadius.circular(10),
                      boxShadow: [
                        BoxShadow(
                          color: const Color(0xFFFFD700).withOpacity(0.5),
                          blurRadius: 8,
                          spreadRadius: 1,
                        ),
                      ],
                    ),
                    child: Text(
                      '$_playerLevel',
                      style: const TextStyle(
                        color: Colors.black,
                        fontSize: 13,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Коллекционер',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  'Опыт: $_playerExp/$expNeeded',
                  style: const TextStyle(
                    color: Colors.white70,
                    fontSize: 13,
                  ),
                ),
                const SizedBox(height: 10),
                ClipRRect(
                  borderRadius: BorderRadius.circular(8),
                  child: LinearProgressIndicator(
                    value: expProgress,
                    backgroundColor: Colors.white.withOpacity(0.1),
                    color: const Color(0xFFFF3366),
                    minHeight: 6,
                  ),
                ),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [Color(0xFFFFD700), Color(0xFFFFA500)],
              ),
              borderRadius: BorderRadius.circular(12),
              boxShadow: [
                BoxShadow(
                  color: const Color(0xFFFFD700).withOpacity(0.4),
                  blurRadius: 12,
                  spreadRadius: 1,
                ),
              ],
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.monetization_on, color: Colors.white, size: 18),
                const SizedBox(width: 6),
                Text(
                  '$_coins',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    ).animate().fadeIn(duration: 500.ms).slideY(begin: -0.5, end: 0);
  }

  Widget _buildActionGrid() {
    return GridView.count(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      crossAxisCount: 2,
      crossAxisSpacing: 12,
      mainAxisSpacing: 12,
      childAspectRatio: 1.2,
      children: [
        _ActionCard(
          title: 'Магазин',
          subtitle: 'Специальные предложения',
          icon: Icons.store,
          color: const Color(0xFFFF9800),
          onTap: _openShop,
        ),
        _ActionCard(
          title: 'Коллекция',
          subtitle: 'Ваши карты',
          icon: Icons.collections,
          color: const Color(0xFF2196F3),
          onTap: _openCollection,
        ),
        _ActionCard(
          title: 'Битвы',
          subtitle: 'Скоро...',
          icon: Icons.casino,
          color: const Color(0xFF9C27B0),
          onTap: () {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('Система битв в разработке!'),
                backgroundColor: Colors.blue,
              ),
            );
          },
        ),
      ],
    );
  }

  Widget _buildPacksSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Padding(
          padding: EdgeInsets.only(left: 8, bottom: 16),
          child: Text(
            'Доступные паки',
            style: TextStyle(
              color: Colors.white,
              fontSize: 22,
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
        ..._availablePacks.asMap().entries.map((e) => 
          _PackCard(
            pack: e.value,
            onTap: () => _openPack(e.value),
            isOpening: _isOpening,
            canAfford: _coins >= e.value.cost,
          ).animate(delay: (e.key * 100).ms).fadeIn(duration: 300.ms).slideX(begin: 0.5, end: 0)
        ),
      ],
    );
  }

  Widget _buildDailyBonusSection() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            const Color(0xFFFFD700).withOpacity(0.15),
            const Color(0xFFFFA500).withOpacity(0.1),
          ],
        ),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: const Color(0xFFFFD700).withOpacity(0.3),
          width: 1.5,
        ),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFFFFD700).withOpacity(0.1),
            blurRadius: 15,
            spreadRadius: 1,
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [Color(0xFFFFD700), Color(0xFFFFA500)],
              ),
              borderRadius: BorderRadius.circular(14),
              boxShadow: [
                BoxShadow(
                  color: const Color(0xFFFFD700).withOpacity(0.4),
                  blurRadius: 12,
                  spreadRadius: 1,
                ),
              ],
            ),
            child: const Icon(Icons.card_giftcard, color: Colors.white, size: 24),
          ),
          const SizedBox(width: 16),
          const Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Ежедневный бонус',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                SizedBox(height: 4),
                Text(
                  'Получайте 100 монет каждый день!',
                  style: TextStyle(
                    color: Colors.white70,
                    fontSize: 14,
                  ),
                ),
              ],
            ),
          ),
          ElevatedButton(
            onPressed: _claimDailyBonus,
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFFFFD700),
              foregroundColor: Colors.black,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
              elevation: 4,
            ),
            child: const Text(
              'Забрать',
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
          ),
        ],
      ),
    ).animate().fadeIn(duration: 500.ms).slideY(begin: 0.5, end: 0);
  }
}

// Остальные классы остаются прежними (оригинальная версия)
class CardPack {
  final String id;
  final String title;
  final String description;
  final int cost;
  final int cardsCount;
  final Color color;
  final IconData icon;
  final int expReward;
  final Map<CardRarity, int> rarityWeights;

  const CardPack({
    required this.id,
    required this.title,
    required this.description,
    required this.cost,
    required this.cardsCount,
    required this.color,
    required this.icon,
    required this.expReward,
    required this.rarityWeights,
  });
}

class _ActionCard extends StatelessWidget {
  final String title;
  final String subtitle;
  final IconData icon;
  final Color color;
  final VoidCallback onTap;

  const _ActionCard({
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              color.withOpacity(0.15),
              color.withOpacity(0.05),
            ],
          ),
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: color.withOpacity(0.25), width: 1.5),
          boxShadow: [
            BoxShadow(
              color: color.withOpacity(0.15),
              blurRadius: 15,
              spreadRadius: 1,
            ),
          ],
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: color.withOpacity(0.2),
                borderRadius: BorderRadius.circular(14),
              ),
              child: Icon(icon, color: color, size: 26),
            ),
            const SizedBox(height: 12),
            Text(
              title,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 14,
                fontWeight: FontWeight.bold,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 6),
            Text(
              subtitle,
              style: const TextStyle(
                color: Colors.white70,
                fontSize: 11,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}

class _PackCard extends StatefulWidget {
  final CardPack pack;
  final VoidCallback onTap;
  final bool isOpening;
  final bool canAfford;

  const _PackCard({
    required this.pack,
    required this.onTap,
    required this.isOpening,
    required this.canAfford,
  });

  @override
  State<_PackCard> createState() => _PackCardState();
}

class _PackCardState extends State<_PackCard> with SingleTickerProviderStateMixin {
  late AnimationController _hoverController;

  @override
  void initState() {
    super.initState();
    _hoverController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 300),
    );
  }

  @override
  void dispose() {
    _hoverController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      onEnter: (_) => _hoverController.forward(),
      onExit: (_) => _hoverController.reverse(),
      child: GestureDetector(
        onTap: widget.isOpening ? null : widget.onTap,
        child: AnimatedBuilder(
          animation: _hoverController,
          builder: (context, child) {
            final scale = 1.0 + (_hoverController.value * 0.02);
            return Transform.scale(
              scale: scale,
              child: Container(
                margin: const EdgeInsets.only(bottom: 12),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [
                      widget.pack.color.withOpacity(0.12),
                      widget.pack.color.withOpacity(0.03),
                    ],
                  ),
                  borderRadius: BorderRadius.circular(18),
                  border: Border.all(
                    color: widget.canAfford 
                        ? widget.pack.color.withOpacity(0.35 + _hoverController.value * 0.2)
                        : Colors.grey.withOpacity(0.2),
                    width: 1.5,
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: widget.pack.color.withOpacity(0.15 + _hoverController.value * 0.2),
                      blurRadius: 16 + _hoverController.value * 8,
                      spreadRadius: 1,
                    ),
                  ],
                ),
                child: Stack(
                  children: [
                    Padding(
                      padding: const EdgeInsets.all(16),
                      child: Row(
                        children: [
                          Container(
                            width: 64,
                            height: 64,
                            decoration: BoxDecoration(
                              gradient: LinearGradient(
                                begin: Alignment.topLeft,
                                end: Alignment.bottomRight,
                                colors: [
                                  widget.pack.color.withOpacity(0.3),
                                  widget.pack.color.withOpacity(0.1),
                                ],
                              ),
                              borderRadius: BorderRadius.circular(14),
                              border: Border.all(
                                color: widget.pack.color.withOpacity(0.3),
                                width: 1,
                              ),
                            ),
                            child: Icon(widget.pack.icon, color: widget.pack.color, size: 32),
                          ),
                          const SizedBox(width: 16),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  widget.pack.title,
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 16,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  widget.pack.description,
                                  style: const TextStyle(
                                    color: Colors.white70,
                                    fontSize: 12,
                                  ),
                                ),
                                const SizedBox(height: 10),
                                _buildRarityBadges(),
                              ],
                            ),
                          ),
                          Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 12,
                                  vertical: 8,
                                ),
                                decoration: BoxDecoration(
                                  gradient: LinearGradient(
                                    begin: Alignment.topLeft,
                                    end: Alignment.bottomRight,
                                    colors: [
                                      widget.pack.color.withOpacity(0.9),
                                      widget.pack.color.withOpacity(0.7),
                                    ],
                                  ),
                                  borderRadius: BorderRadius.circular(12),
                                  boxShadow: [
                                    BoxShadow(
                                      color: widget.pack.color.withOpacity(0.4),
                                      blurRadius: 8,
                                      spreadRadius: 1,
                                    ),
                                  ],
                                ),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    const Icon(
                                      Icons.monetization_on,
                                      color: Colors.white,
                                      size: 16,
                                    ),
                                    const SizedBox(width: 4),
                                    Text(
                                      '${widget.pack.cost}',
                                      style: const TextStyle(
                                        color: Colors.white,
                                        fontSize: 14,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              const SizedBox(height: 6),
                              Text(
                                '${widget.pack.cardsCount} карт',
                                style: const TextStyle(
                                  color: Colors.white70,
                                  fontSize: 11,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                    if (widget.isOpening)
                      Positioned.fill(
                        child: Container(
                          decoration: BoxDecoration(
                            color: Colors.black.withOpacity(0.6),
                            borderRadius: BorderRadius.circular(18),
                          ),
                          child: const Center(
                            child: CircularProgressIndicator(
                              color: Color(0xFFFF6B6B),
                              strokeWidth: 3,
                            ),
                          ),
                        ),
                      ),
                    if (!widget.canAfford && !widget.isOpening)
                      Positioned.fill(
                        child: Container(
                          decoration: BoxDecoration(
                            color: Colors.black.withOpacity(0.5),
                            borderRadius: BorderRadius.circular(18),
                          ),
                          child: Center(
                            child: Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 12,
                                vertical: 6,
                              ),
                              decoration: BoxDecoration(
                                color: Colors.red.withOpacity(0.85),
                                borderRadius: BorderRadius.circular(8),
                                boxShadow: [
                                  BoxShadow(
                                    color: Colors.red.withOpacity(0.4),
                                    blurRadius: 8,
                                    spreadRadius: 1,
                                  ),
                                ],
                              ),
                              child: const Text(
                                'Недостаточно монет',
                                style: TextStyle(
                                  color: Colors.white,
                                  fontSize: 12,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                          ),
                        ),
                      ),
                  ],
                ),
              ),
            );
          },
        ),
      ),
    );
  }

  Widget _buildRarityBadges() {
    final validRarities = widget.pack.rarityWeights.entries
        .where((entry) => entry.value > 0)
        .toList()
      ..sort((a, b) => b.key.index.compareTo(a.key.index));

    return Wrap(
      spacing: 6,
      runSpacing: 3,
      children: validRarities.take(3).map((entry) {
        return Container(
          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
          decoration: BoxDecoration(
            color: entry.key.borderColor.withOpacity(0.2),
            borderRadius: BorderRadius.circular(6),
            border: Border.all(
              color: entry.key.borderColor.withOpacity(0.4),
              width: 0.5,
            ),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.star, color: entry.key.borderColor, size: 9),
              const SizedBox(width: 2),
              Text(
                '${entry.value}%',
                style: TextStyle(
                  color: entry.key.borderColor,
                  fontSize: 10,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
        );
      }).toList(),
    );
  }
}

class _PackOpeningDialog extends StatefulWidget {
  final CardPack pack;
  final List<AnimeCard> cards;

  const _PackOpeningDialog({
    required this.pack,
    required this.cards,
  });

  @override
  State<_PackOpeningDialog> createState() => _PackOpeningDialogState();
}

class _PackOpeningDialogState extends State<_PackOpeningDialog>
    with TickerProviderStateMixin {
  late PageController _pageController;
  late AnimationController _cardController;
  late AnimationController _particleController;
  late AnimationController _packAnimController;
  late AnimationController _lightRayController;
  int _currentIndex = 0;
  bool _showCard = false;
  bool _packOpened = false;

  @override
  void initState() {
    super.initState();
    _pageController = PageController();
    _cardController = AnimationController(
      duration: const Duration(milliseconds: 2200),
      vsync: this,
    );
    _particleController = AnimationController(
      duration: const Duration(milliseconds: 2400),
      vsync: this,
    );
    _packAnimController = AnimationController(
      duration: const Duration(milliseconds: 1600),
      vsync: this,
    );
    _lightRayController = AnimationController(
      duration: const Duration(milliseconds: 3000),
      vsync: this,
    )..repeat();
    _startPackAnimation();
  }

  void _startPackAnimation() {
    _packAnimController.reset();
    Future.delayed(const Duration(milliseconds: 600), () {
      if (mounted) {
        _packAnimController.forward().then((_) {
          if (mounted) {
            setState(() => _packOpened = true);
            _startCardAnimation();
          }
        });
      }
    });
  }

  void _startCardAnimation() {
    setState(() => _showCard = false);
    _cardController.reset();
    _particleController.reset();
    Future.delayed(const Duration(milliseconds: 500), () {
      if (mounted) {
        setState(() => _showCard = true);
        _cardController.forward();
        _particleController.forward();
      }
    });
  }

  @override
  void dispose() {
    _pageController.dispose();
    _cardController.dispose();
    _particleController.dispose();
    _packAnimController.dispose();
    _lightRayController.dispose();
    super.dispose();
  }

  void _onPageChanged(int index) {
    setState(() => _currentIndex = index);
    _startCardAnimation();
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: const EdgeInsets.all(20),
      child: Container(
        height: MediaQuery.of(context).size.height * 0.85,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(24),
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              const Color(0xFF1A0A1A).withOpacity(0.98),
              const Color(0xFF0A0A1A).withOpacity(0.99),
            ],
          ),
          border: Border.all(
            color: Colors.white.withOpacity(0.12),
            width: 2,
          ),
          boxShadow: [
            BoxShadow(
              color: widget.pack.color.withOpacity(0.3),
              blurRadius: 40,
              spreadRadius: 10,
            ),
          ],
        ),
        child: Stack(
          children: [
            if (_packOpened)
              AnimatedBuilder(
                animation: _lightRayController,
                builder: (context, child) {
                  return CustomPaint(
                    painter: LightRayPainter(
                      _lightRayController.value,
                      widget.pack.color,
                    ),
                    size: Size.infinite,
                  );
                },
              ),
            Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Padding(
                  padding: const EdgeInsets.all(20),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text(
                        'Открытие пака',
                        style: TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                        ),
                      ),
                      GestureDetector(
                        onTap: () => Navigator.pop(context, false),
                        child: Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: Colors.white.withOpacity(0.1),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Icon(
                            Icons.close,
                            color: Colors.white70,
                            size: 20,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                if (!_packOpened)
                  Expanded(
                    child: Center(
                      child: _buildPackAnimation(),
                    ),
                  )
                else
                  Expanded(
                    child: Stack(
                      children: [
                        PageView.builder(
                          controller: _pageController,
                          onPageChanged: _onPageChanged,
                          itemCount: widget.cards.length,
                          itemBuilder: (context, index) {
                            final card = widget.cards[index];
                            return _CardRevealWidget(
                              card: card,
                              showCard: _showCard && _currentIndex == index,
                              animationController: _cardController,
                              particleController: _particleController,
                            );
                          },
                        ),
                        Positioned(
                          bottom: 20,
                          left: 0,
                          right: 0,
                          child: _buildPageIndicator(),
                        ),
                      ],
                    ),
                  ),
                Padding(
                  padding: const EdgeInsets.all(20),
                  child: SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: () => Navigator.pop(context, true),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.white,
                        foregroundColor: Colors.black,
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        elevation: 4,
                      ),
                      child: const Text(
                        'Продолжить',
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
          ],
        ),
      ),
    );
  }

  Widget _buildPackAnimation() {
    return AnimatedBuilder(
      animation: _packAnimController,
      builder: (context, child) {
        final progress = _packAnimController.value;
        final openProgress = Curves.easeInOutCubic.transform(progress);
        final glowProgress = Curves.easeOut.transform(progress);
        final shineProgress = Curves.easeInOut.transform(progress);

        return Stack(
          alignment: Alignment.center,
          children: [
            if (glowProgress > 0.1)
              Container(
                width: 300 + (glowProgress * 50),
                height: 300 + (glowProgress * 50),
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: RadialGradient(
                    colors: [
                      widget.pack.color.withOpacity(math.max(0, (glowProgress - 0.2) * 0.5)),
                      Colors.transparent,
                    ],
                  ),
                ),
              ),
            Transform.translate(
              offset: Offset(-80 * openProgress, 0),
              child: Transform.rotate(
                angle: -openProgress * 0.8,
                child: Transform(
                  alignment: Alignment.centerRight,
                  transform: Matrix4.identity()
                    ..setEntry(3, 2, 0.001)
                    ..rotateY(openProgress * 0.3),
                  child: Container(
                    width: 90,
                    height: 140,
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                        colors: [
                          widget.pack.color.withOpacity(0.95),
                          widget.pack.color.withOpacity(0.65),
                        ],
                      ),
                      borderRadius: const BorderRadius.only(
                        topLeft: Radius.circular(14),
                        bottomLeft: Radius.circular(14),
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: widget.pack.color.withOpacity(0.6),
                          blurRadius: 25,
                          spreadRadius: 5,
                        ),
                      ],
                    ),
                    child: Center(
                      child: Opacity(
                        opacity: 1 - (openProgress * 0.7),
                        child: Icon(
                          widget.pack.icon,
                          color: Colors.white.withOpacity(0.4),
                          size: 48,
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
            Transform.translate(
              offset: Offset(80 * openProgress, 0),
              child: Transform.rotate(
                angle: openProgress * 0.8,
                child: Transform(
                  alignment: Alignment.centerLeft,
                  transform: Matrix4.identity()
                    ..setEntry(3, 2, 0.001)
                    ..rotateY(-openProgress * 0.3),
                  child: Container(
                    width: 90,
                    height: 140,
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topRight,
                        end: Alignment.bottomLeft,
                        colors: [
                          widget.pack.color.withOpacity(0.85),
                          widget.pack.color.withOpacity(0.55),
                        ],
                      ),
                      borderRadius: const BorderRadius.only(
                        topRight: Radius.circular(14),
                        bottomRight: Radius.circular(14),
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: widget.pack.color.withOpacity(0.6),
                          blurRadius: 25,
                          spreadRadius: 5,
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
            if (openProgress > 0.25)
              Opacity(
                opacity: math.min(1.0, (openProgress - 0.25) / 0.75),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Stack(
                      alignment: Alignment.center,
                      children: [
                        Container(
                          width: 120 + (shineProgress * 40),
                          height: 120 + (shineProgress * 40),
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            gradient: RadialGradient(
                              colors: [
                                widget.pack.color.withOpacity(0.3),
                                Colors.transparent,
                              ],
                            ),
                          ),
                        ),
                        Container(
                          width: 90,
                          height: 90,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            gradient: LinearGradient(
                              begin: Alignment.topLeft,
                              end: Alignment.bottomRight,
                              colors: [
                                Colors.white.withOpacity(0.4),
                                widget.pack.color.withOpacity(0.25),
                              ],
                            ),
                            boxShadow: [
                              BoxShadow(
                                color: widget.pack.color.withOpacity(0.8),
                                blurRadius: 40,
                                spreadRadius: 15,
                              ),
                            ],
                          ),
                          child: Icon(
                            widget.pack.icon,
                            color: Colors.white.withOpacity(0.95),
                            size: 50,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 20),
                    ScaleTransition(
                      scale: Tween<double>(begin: 0.5, end: 1.0).animate(
                        CurvedAnimation(parent: _packAnimController, curve: const Interval(0.4, 1.0)),
                      ),
                      child: Text(
                        'Готово!',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 24,
                          fontWeight: FontWeight.bold,
                          shadows: [
                            Shadow(
                              color: widget.pack.color.withOpacity(0.8),
                              blurRadius: 16,
                            ),
                            Shadow(
                              color: Colors.black,
                              blurRadius: 8,
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
          ],
        );
      },
    );
  }

  Widget _buildPageIndicator() {
    return Center(
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          for (int i = 0; i < widget.cards.length; i++)
            GestureDetector(
              onTap: () => _pageController.animateToPage(
                i,
                duration: const Duration(milliseconds: 400),
                curve: Curves.easeInOut,
              ),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 300),
                width: _currentIndex == i ? 28 : 8,
                height: 8,
                margin: const EdgeInsets.symmetric(horizontal: 4),
                decoration: BoxDecoration(
                  color: _currentIndex == i
                      ? Colors.white
                      : Colors.white.withOpacity(0.4),
                  borderRadius: BorderRadius.circular(4),
                  boxShadow: _currentIndex == i
                      ? [
                          BoxShadow(
                            color: Colors.white.withOpacity(0.5),
                            blurRadius: 8,
                            spreadRadius: 1,
                          ),
                        ]
                      : [],
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _CardRevealWidget extends StatelessWidget {
  final AnimeCard card;
  final bool showCard;
  final AnimationController animationController;
  final AnimationController particleController;

  const _CardRevealWidget({
    required this.card,
    required this.showCard,
    required this.animationController,
    required this.particleController,
  });

  @override
  Widget build(BuildContext context) {
    return AnimatedOpacity(
      duration: const Duration(milliseconds: 600),
      opacity: showCard ? 1.0 : 0.0,
      child: AnimatedBuilder(
        animation: Listenable.merge([animationController, particleController]),
        builder: (context, child) {
          final fallAnimation = CurvedAnimation(
            parent: animationController,
            curve: const Interval(0.0, 0.5, curve: Curves.elasticOut),
          );

          final glowAnimation = CurvedAnimation(
            parent: animationController,
            curve: const Interval(0.2, 1.0, curve: Curves.easeInOut),
          );

          final scaleAnimation = CurvedAnimation(
            parent: animationController,
            curve: const Interval(0.0, 0.5, curve: Curves.easeOut),
          );

          final rotateAnimation = CurvedAnimation(
            parent: animationController,
            curve: const Interval(0.0, 0.6, curve: Curves.easeOut),
          );

          return Stack(
            alignment: Alignment.center,
            children: [
              if (showCard)
                CustomPaint(
                  painter: CardParticlePainter(particleController.value, card.rarity.borderColor),
                  size: Size.infinite,
                ),
              Transform.translate(
                offset: Offset(0, (1 - fallAnimation.value) * -200),
                child: Transform.scale(
                  scale: 0.6 + 0.4 * scaleAnimation.value,
                  child: Transform.rotate(
                    angle: rotateAnimation.value * 0.15,
                    child: _PrestigousCardDisplay(
                      card: card,
                      glowAnimation: glowAnimation,
                    ),
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}

class _PrestigousCardDisplay extends StatelessWidget {
  final AnimeCard card;
  final Animation<double> glowAnimation;

  const _PrestigousCardDisplay({
    required this.card,
    required this.glowAnimation,
  });

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: glowAnimation,
      builder: (context, child) {
        return Container(
          margin: const EdgeInsets.all(20),
          width: 300,
          height: 420,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(24),
            gradient: LinearGradient(
              colors: card.rarity.gradientColors,
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            boxShadow: [
              BoxShadow(
                color: card.rarity.gradientColors.isNotEmpty
                    ? card.rarity.gradientColors[0].withOpacity(glowAnimation.value * 0.9)
                    : Colors.white.withOpacity(0.5),
                blurRadius: 50 + glowAnimation.value * 40,
                spreadRadius: 12 + glowAnimation.value * 16,
              ),
              BoxShadow(
                color: Colors.black.withOpacity(0.5),
                blurRadius: 20,
                spreadRadius: 4,
              ),
            ],
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(24),
            child: Stack(
              children: [
                Container(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [
                        Colors.white.withOpacity(0.1),
                        Colors.black.withOpacity(0.5),
                      ],
                    ),
                  ),
                ),
                Positioned.fill(
                  child: CachedNetworkImage(
                    imageUrl: card.imageUrl,
                    fit: BoxFit.cover,
                    placeholder: (context, url) => Container(
                      color: Colors.black26,
                      child: Center(
                        child: CircularProgressIndicator(
                          valueColor: AlwaysStoppedAnimation<Color>(
                            card.rarity.borderColor,
                          ),
                        ),
                      ),
                    ),
                    errorWidget: (context, url, error) => Container(
                      color: Colors.black26,
                      child: Icon(
                        Icons.person,
                        color: card.rarity.borderColor,
                        size: 80,
                      ),
                    ),
                  ),
                ),
                if (card.rarity.index >= CardRarity.epic.index)
                  Positioned.fill(
                    child: Container(
                      decoration: BoxDecoration(
                        gradient: RadialGradient(
                          center: Alignment.center,
                          radius: 0.9,
                          colors: [
                            card.rarity.borderColor.withOpacity(0.4),
                            Colors.transparent,
                          ],
                        ),
                      ),
                    ),
                  ),
                Positioned(
                  top: 16,
                  left: 16,
                  right: 16,
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      ScaleTransition(
                        scale: Tween<double>(begin: 0.3, end: 1.0).animate(
                          CurvedAnimation(parent: glowAnimation, curve: const Interval(0.0, 0.6)),
                        ),
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 6,
                          ),
                          decoration: BoxDecoration(
                            color: Colors.black.withOpacity(0.8),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(
                              color: Colors.amber,
                              width: 1.5,
                            ),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.amber.withOpacity(0.4),
                                blurRadius: 12,
                                spreadRadius: 2,
                              ),
                            ],
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Icon(
                                Icons.star,
                                color: Colors.amber,
                                size: 16,
                              ),
                              const SizedBox(width: 6),
                              Text(
                                'Lv.${card.level}',
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 14,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                      ScaleTransition(
                        scale: Tween<double>(begin: 0.3, end: 1.0).animate(
                          CurvedAnimation(parent: glowAnimation, curve: const Interval(0.1, 0.7)),
                        ),
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 6,
                          ),
                          decoration: BoxDecoration(
                            color: card.rarity.borderColor.withOpacity(0.95),
                            borderRadius: BorderRadius.circular(12),
                            boxShadow: [
                              BoxShadow(
                                color: card.rarity.borderColor.withOpacity(0.7),
                                blurRadius: 16,
                                spreadRadius: 3,
                              ),
                            ],
                          ),
                          child: Text(
                            card.rarity.displayName,
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 14,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                Positioned(
                  bottom: 0,
                  left: 0,
                  right: 0,
                  child: Container(
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: [
                          Colors.transparent,
                          Colors.black.withOpacity(0.98),
                        ],
                      ),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          card.characterName ?? 'Unknown',
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                            shadows: [
                              Shadow(
                                color: Colors.black,
                                blurRadius: 10,
                              ),
                            ],
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: 4),
                        Text(
                          card.animeName ?? 'Unknown Anime',
                          style: TextStyle(
                            color: Colors.white.withOpacity(0.85),
                            fontSize: 14,
                            fontWeight: FontWeight.w500,
                            shadows: const [
                              Shadow(
                                color: Colors.black,
                                blurRadius: 8,
                              ),
                            ],
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        if ((card.quote ?? '').isNotEmpty) ...[
                          const SizedBox(height: 8),
                          Container(
                            padding: const EdgeInsets.all(8),
                            decoration: BoxDecoration(
                              color: Colors.black.withOpacity(0.7),
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(
                                color: card.rarity.borderColor.withOpacity(0.4),
                                width: 1,
                              ),
                            ),
                            child: Row(
                              children: [
                                Icon(
                                  Icons.format_quote,
                                  color: card.rarity.borderColor.withOpacity(0.7),
                                  size: 12,
                                ),
                                const SizedBox(width: 6),
                                Expanded(
                                  child: Text(
                                    card.quote ?? '',
                                    style: const TextStyle(
                                      color: Colors.white,
                                      fontSize: 10,
                                      fontStyle: FontStyle.italic,
                                    ),
                                    maxLines: 2,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

class _PackSummaryDialog extends StatelessWidget {
  final List<AnimeCard> cards;

  const _PackSummaryDialog({required this.cards});

  @override
  Widget build(BuildContext context) {
    final rarityCount = <CardRarity, int>{};
    for (var card in cards) {
      rarityCount[card.rarity] = (rarityCount[card.rarity] ?? 0) + 1;
    }

    final sortedRarities = rarityCount.entries.toList()
      ..sort((a, b) => a.key.index.compareTo(b.key.index));

    final highestRarity = sortedRarities.isNotEmpty 
        ? sortedRarities.last.key 
        : CardRarity.common;
    final accentColor = highestRarity.borderColor;

    return Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: const EdgeInsets.all(20),
      child: Container(
        height: MediaQuery.of(context).size.height * 0.7,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(24),
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              const Color(0xFF1A0A1A).withOpacity(0.98),
              const Color(0xFF0A0A1A).withOpacity(0.99),
            ],
          ),
          border: Border.all(
            color: Colors.white.withOpacity(0.12),
            width: 2,
          ),
          boxShadow: [
            BoxShadow(
              color: accentColor.withOpacity(0.3),
              blurRadius: 40,
              spreadRadius: 10,
            ),
          ],
        ),
        child: Stack(
          children: [
            Positioned.fill(
              child: Container(
                decoration: BoxDecoration(
                  gradient: RadialGradient(
                    center: Alignment.topLeft,
                    radius: 1.5,
                    colors: [
                      accentColor.withOpacity(0.1),
                      Colors.transparent,
                    ],
                  ),
                ),
              ),
            ),
            
            Column(
              children: [
                Container(
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: [
                        accentColor.withOpacity(0.15),
                        accentColor.withOpacity(0.05),
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
                              accentColor.withOpacity(0.8),
                              accentColor.withOpacity(0.6),
                            ],
                          ),
                          borderRadius: BorderRadius.circular(16),
                          boxShadow: [
                            BoxShadow(
                              color: accentColor.withOpacity(0.4),
                              blurRadius: 15,
                              spreadRadius: 2,
                            ),
                          ],
                        ),
                        child: const Icon(
                          Icons.celebration,
                          color: Colors.white,
                          size: 28,
                        ),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Успешное открытие!',
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 20,
                                fontWeight: FontWeight.bold,
                                shadows: [
                                  Shadow(
                                    color: accentColor.withOpacity(0.5),
                                    blurRadius: 10,
                                  ),
                                ],
                              ),
                            ),
                            Text(
                              'Получено ${cards.length} карт',
                              style: TextStyle(
                                color: Colors.white70,
                                fontSize: 14,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),

                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.all(20),
                    child: Column(
                      children: [
                        Text(
                          'Статистика по редкостям',
                          style: TextStyle(
                            color: Colors.white.withOpacity(0.9),
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 16),

                        if (sortedRarities.isEmpty)
                          Expanded(
                            child: Center(
                              child: Text(
                                'Нет карт для отображения',
                                style: TextStyle(
                                  color: Colors.white.withOpacity(0.6),
                                  fontSize: 16,
                                ),
                              ),
                            ),
                          )
                        else
                          Expanded(
                            child: ListView(
                              children: sortedRarities.map((entry) {
                                final rarity = entry.key;
                                final count = entry.value;
                                final color = rarity.borderColor;
                                
                                return Container(
                                  margin: const EdgeInsets.only(bottom: 12),
                                  decoration: BoxDecoration(
                                    gradient: LinearGradient(
                                      begin: Alignment.centerLeft,
                                      end: Alignment.centerRight,
                                      colors: [
                                        color.withOpacity(0.1),
                                        color.withOpacity(0.05),
                                      ],
                                    ),
                                    borderRadius: BorderRadius.circular(16),
                                    border: Border.all(
                                      color: color.withOpacity(0.3),
                                      width: 1.5,
                                    ),
                                    boxShadow: [
                                      BoxShadow(
                                        color: color.withOpacity(0.15),
                                        blurRadius: 10,
                                        spreadRadius: 1,
                                      ),
                                    ],
                                  ),
                                  child: ListTile(
                                    leading: Container(
                                      width: 44,
                                      height: 44,
                                      decoration: BoxDecoration(
                                        shape: BoxShape.circle,
                                        gradient: LinearGradient(
                                          colors: [
                                            color.withOpacity(0.8),
                                            color.withOpacity(0.4),
                                          ],
                                        ),
                                        boxShadow: [
                                          BoxShadow(
                                            color: color.withOpacity(0.3),
                                            blurRadius: 8,
                                            spreadRadius: 1,
                                          ),
                                        ],
                                      ),
                                      child: Icon(
                                        Icons.star,
                                        color: Colors.white,
                                        size: 20,
                                      ),
                                    ),
                                    title: Text(
                                      rarity.displayName,
                                      style: TextStyle(
                                        color: color,
                                        fontSize: 16,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                    subtitle: Text(
                                      '${_getRarityDescription(rarity)}',
                                      style: TextStyle(
                                        color: Colors.white.withOpacity(0.7),
                                        fontSize: 12,
                                      ),
                                    ),
                                    trailing: Container(
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 16,
                                        vertical: 8,
                                      ),
                                      decoration: BoxDecoration(
                                        gradient: LinearGradient(
                                          colors: [
                                            color.withOpacity(0.9),
                                            color.withOpacity(0.7),
                                          ],
                                        ),
                                        borderRadius: BorderRadius.circular(12),
                                        boxShadow: [
                                          BoxShadow(
                                            color: color.withOpacity(0.4),
                                            blurRadius: 8,
                                            spreadRadius: 1,
                                          ),
                                        ],
                                      ),
                                      child: Text(
                                        '×$count',
                                        style: const TextStyle(
                                          color: Colors.white,
                                          fontSize: 16,
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                    ),
                                  ),
                                );
                              }).toList(),
                            ),
                          ),

                        const SizedBox(height: 20),

                        if (sortedRarities.isNotEmpty)
                          Container(
                            padding: const EdgeInsets.all(16),
                            decoration: BoxDecoration(
                              gradient: LinearGradient(
                                begin: Alignment.topLeft,
                                end: Alignment.bottomRight,
                                colors: [
                                  accentColor.withOpacity(0.15),
                                  accentColor.withOpacity(0.05),
                                ],
                              ),
                              borderRadius: BorderRadius.circular(16),
                              border: Border.all(
                                color: accentColor.withOpacity(0.3),
                                width: 1.5,
                              ),
                            ),
                            child: Row(
                              children: [
                                Icon(
                                  Icons.auto_awesome,
                                  color: accentColor,
                                  size: 24,
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Text(
                                    'Самая редкая: ${highestRarity.displayName}',
                                    style: TextStyle(
                                      color: Colors.white,
                                      fontSize: 14,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                      ],
                    ),
                  ),
                ),

                Container(
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [
                        Colors.transparent,
                        Colors.black.withOpacity(0.8),
                      ],
                    ),
                    borderRadius: const BorderRadius.only(
                      bottomLeft: Radius.circular(24),
                      bottomRight: Radius.circular(24),
                    ),
                  ),
                  child: SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: () => Navigator.pop(context),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: accentColor,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16),
                        ),
                        elevation: 8,
                        shadowColor: accentColor.withOpacity(0.5),
                      ),
                      child: const Text(
                        'Продолжить',
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
          ],
        ),
      ),
    );
  }

  String _getRarityDescription(CardRarity rarity) {
    switch (rarity) {
      case CardRarity.common:
        return 'Базовая редкость';
      case CardRarity.rare:
        return 'Улучшенная редкость';
      case CardRarity.epic:
        return 'Эпическая редкость';
      case CardRarity.legendary:
        return 'Легендарная редкость';
      case CardRarity.mythic:
        return 'Мифическая редкость';
      case CardRarity.divine:
        return 'Божественная редкость';
    }
  }
}

class ParticlePainter extends CustomPainter {
  final double progress;

  ParticlePainter(this.progress);

  @override
  void paint(Canvas canvas, Size size) {
    final random = math.Random(42);
    
    for (int i = 0; i < 25; i++) {
      final x = random.nextDouble() * size.width;
      final y = random.nextDouble() * size.height;
      final opacity = (math.sin(progress * 2 * math.pi + i) + 1) / 2 * 0.4;
      final radius = 1.5 + math.sin(progress * math.pi + i) * 0.8;
      
      canvas.drawCircle(
        Offset(x, y),
        radius,
        Paint()..color = Colors.white.withOpacity(opacity),
      );
    }
  }

  @override
  bool shouldRepaint(ParticlePainter oldDelegate) => true;
}

class CardParticlePainter extends CustomPainter {
  final double progress;
  final Color color;

  CardParticlePainter(this.progress, this.color);

  @override
  void paint(Canvas canvas, Size size) {
    final random = math.Random(42);
    final center = Offset(size.width / 2, size.height / 2);
    
    for (int i = 0; i < 40; i++) {
      final angle = (i / 40) * 2 * math.pi + progress * 6 * math.pi;
      final distance = 180 * math.sin(progress * math.pi);
      final x = center.dx + math.cos(angle) * distance;
      final y = center.dy + math.sin(angle) * distance;
      final opacity = (1 - progress) * 0.7;
      final radius = 2 + 3 * progress;
      
      canvas.drawCircle(
        Offset(x, y),
        radius,
        Paint()..color = color.withOpacity(opacity * 0.8),
      );
      
      canvas.drawCircle(
        Offset(x, y),
        radius * 0.4,
        Paint()..color = Colors.white.withOpacity(opacity),
      );
    }
  }

  @override
  bool shouldRepaint(CardParticlePainter oldDelegate) => 
      oldDelegate.progress != progress || oldDelegate.color != color;
}

class LightRayPainter extends CustomPainter {
  final double progress;
  final Color color;

  LightRayPainter(this.progress, this.color);

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final rayCount = 8;
    
    for (int i = 0; i < rayCount; i++) {
      final angle = (i / rayCount) * 2 * math.pi + progress * math.pi;
      final startRadius = 100.0;
      final endRadius = 400.0;
      
      final startX = center.dx + math.cos(angle) * startRadius;
      final startY = center.dy + math.sin(angle) * startRadius;
      final endX = center.dx + math.cos(angle) * endRadius;
      final endY = center.dy + math.sin(angle) * endRadius;
      
      final opacity = (math.sin(progress * 4 * math.pi + i) + 1) / 2 * 0.15;
      
      canvas.drawLine(
        Offset(startX, startY),
        Offset(endX, endY),
        Paint()
          ..color = color.withOpacity(opacity)
          ..strokeWidth = 4
          ..strokeCap = StrokeCap.round,
      );
    }
  }

  @override
  bool shouldRepaint(LightRayPainter oldDelegate) =>
      oldDelegate.progress != progress || oldDelegate.color != color;
}