// screens/card_shop_screen.dart
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'dart:async';
import 'dart:math' as math;
import 'dart:ui';
import '../models/anime_card.dart';
import '../services/card_game_service.dart';

class CardShopScreen extends StatefulWidget {
  const CardShopScreen({super.key});

  @override
  State<CardShopScreen> createState() => _CardShopScreenState();
}

class _CardShopScreenState extends State<CardShopScreen> with TickerProviderStateMixin {
  int _coins = 0;
  List<ShopPack> _limitedPacks = [];
  List<ShopCard> _randomCards = [];
  DateTime? _nextRotation;
  Timer? _rotationTimer;
  Timer? _countdownTimer;
  Duration _timeUntilRotation = Duration.zero;
  bool _isLoading = true;
  bool _isOpening = false;

  late AnimationController _bgAnimController;
  late AnimationController _particleController;
  late AnimationController _fadeController;

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

    _fadeController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 800),
    );

    _fadeController.forward();
    _loadShopData();
    _startCountdownTimer();
  }

  void _startCountdownTimer() {
    _countdownTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (_nextRotation != null) {
        setState(() {
          _timeUntilRotation = _nextRotation!.difference(DateTime.now());
          if (_timeUntilRotation.isNegative) {
            _timeUntilRotation = Duration.zero;
            _rotateShop();
          }
        });
      }
    });
  }

  Future<void> _loadShopData() async {
    setState(() => _isLoading = true);
    
    try {
      final coins = await CardGameService.getCoins();
      final rotation = _getNextRotationTime();
      final packs = _generateLimitedPacks();
      final cards = await _generateRandomCards();
      
      if (mounted) {
        setState(() {
          _coins = coins;
          _nextRotation = rotation;
          _limitedPacks = packs;
          _randomCards = cards;
          _timeUntilRotation = _nextRotation!.difference(DateTime.now());
          _isLoading = false;
        });
      }
    } catch (e) {
      debugPrint('Ошибка загрузки магазина: $e');
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  DateTime _getNextRotationTime() {
    final now = DateTime.now();
    final hour = now.hour;
    final nextRotationHour = ((hour ~/ 2) + 1) * 2;
    
    if (nextRotationHour >= 24) {
      return DateTime(now.year, now.month, now.day + 1, nextRotationHour - 24, 0, 0);
    }
    return DateTime(now.year, now.month, now.day, nextRotationHour, 0, 0);
  }

  List<ShopPack> _generateLimitedPacks() {
    final random = math.Random(DateTime.now().hour ~/ 2);
    final allPackTemplates = _getAllPackTemplates();
    
    allPackTemplates.shuffle(random);
    return allPackTemplates.take(6).toList();
  }

  List<ShopPack> _getAllPackTemplates() {
    return [
      ShopPack(
        id: 'starter_pack',
        title: 'Стартовый набор',
        description: '5 обычных карт\nИдеально для новичков',
        cost: 200,
        cardsCount: 5,
        color: const Color(0xFF2196F3),
        icon: Icons.star_outline_rounded,
        guaranteedRarity: CardRarity.common,
        bonusCards: 0,
        rarityWeights: {
          CardRarity.common: 80,
          CardRarity.rare: 18,
          CardRarity.epic: 2,
          CardRarity.legendary: 0,
          CardRarity.mythic: 0,
          CardRarity.divine: 0,
        },
      ),
      ShopPack(
        id: 'lucky_pack',
        title: 'Пак удачи',
        description: '3 карты\n+1 гарант. редкая',
        cost: 350,
        cardsCount: 3,
        color: const Color(0xFF9C27B0),
        icon: Icons.casino_rounded,
        guaranteedRarity: CardRarity.rare,
        bonusCards: 1,
        rarityWeights: {
          CardRarity.common: 60,
          CardRarity.rare: 32,
          CardRarity.epic: 6,
          CardRarity.legendary: 2,
          CardRarity.mythic: 0,
          CardRarity.divine: 0,
        },
      ),
      ShopPack(
        id: 'hero_pack',
        title: 'Пак героев',
        description: '5 карт\nВысокий шанс эпика',
        cost: 600,
        cardsCount: 5,
        color: const Color(0xFFFF9800),
        icon: Icons.shield_rounded,
        guaranteedRarity: CardRarity.epic,
        bonusCards: 0,
        rarityWeights: {
          CardRarity.common: 50,
          CardRarity.rare: 30,
          CardRarity.epic: 15,
          CardRarity.legendary: 4,
          CardRarity.mythic: 1,
          CardRarity.divine: 0,
        },
      ),
      ShopPack(
        id: 'legend_pack',
        title: 'Легендарный пак',
        description: '4 карты\n+1 гарант. легенда',
        cost: 1200,
        cardsCount: 4,
        color: const Color(0xFFFFD700),
        icon: Icons.military_tech_rounded,
        guaranteedRarity: CardRarity.legendary,
        bonusCards: 1,
        rarityWeights: {
          CardRarity.common: 40,
          CardRarity.rare: 35,
          CardRarity.epic: 15,
          CardRarity.legendary: 8,
          CardRarity.mythic: 2,
          CardRarity.divine: 0,
        },
      ),
      ShopPack(
        id: 'mega_pack',
        title: 'Мега пак',
        description: '10 карт\n+2 бонусные',
        cost: 1500,
        cardsCount: 10,
        color: const Color(0xFFFF3366),
        icon: Icons.card_giftcard_rounded,
        guaranteedRarity: CardRarity.epic,
        bonusCards: 2,
        rarityWeights: {
          CardRarity.common: 45,
          CardRarity.rare: 30,
          CardRarity.epic: 15,
          CardRarity.legendary: 7,
          CardRarity.mythic: 2,
          CardRarity.divine: 1,
        },
      ),
      ShopPack(
        id: 'divine_pack',
        title: 'Божественный пак',
        description: '3 карты\nМаксимальный шанс',
        cost: 2500,
        cardsCount: 3,
        color: const Color(0xFFE1BEE7),
        icon: Icons.spa_rounded,
        guaranteedRarity: CardRarity.mythic,
        bonusCards: 0,
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
  }

  Future<List<ShopCard>> _generateRandomCards() async {
    final random = math.Random(DateTime.now().hour ~/ 2);
    final List<ShopCard> cards = [];
    
    for (int i = 0; i < 8; i++) {
      final rarity = _getRandomRarity(random);
      final availableCards = CardGameService.getCardsByRarity(rarity);
      
      if (availableCards.isNotEmpty) {
        final card = availableCards[random.nextInt(availableCards.length)];
        final basePrice = _getBasePriceForRarity(rarity);
        final priceVariation = random.nextInt(basePrice ~/ 2) - (basePrice ~/ 4);
        final price = basePrice + priceVariation;
        
        cards.add(ShopCard(
          card: card,
          price: price.clamp(50, 100000),
          discount: random.nextDouble() < 0.3 ? random.nextInt(20) + 10 : 0,
        ));
      }
    }
    
    return cards;
  }

  CardRarity _getRandomRarity(math.Random random) {
    final value = random.nextInt(100);
    
    if (value < 35) return CardRarity.common;
    if (value < 60) return CardRarity.rare;
    if (value < 80) return CardRarity.epic;
    if (value < 95) return CardRarity.legendary;
    if (value < 99) return CardRarity.mythic;
    return CardRarity.divine;
  }

  int _getBasePriceForRarity(CardRarity rarity) {
    switch (rarity) {
      case CardRarity.common:
        return 150;
      case CardRarity.rare:
        return 400;
      case CardRarity.epic:
        return 1000;
      case CardRarity.legendary:
        return 2500;
      case CardRarity.mythic:
        return 6000;
      case CardRarity.divine:
        return 15000;
    }
  }

  Future<void> _rotateShop() async {
    setState(() => _isLoading = true);
    await Future.delayed(const Duration(milliseconds: 500));
    await _loadShopData();
  }

  Future<void> _buyPack(ShopPack pack) async {
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

      await _loadShopData();
      
      final cards = await _generateCardsForPack(pack);
      
      if (cards.isEmpty) {
        throw Exception('Не удалось создать карты');
      }
      
      cards.sort((a, b) => a.rarity.index.compareTo(b.rarity.index));

      if (mounted) {
        final dialogShown = await showDialog<bool>(
          context: context,
          barrierDismissible: false,
          builder: (context) => _PackOpeningDialog(
            pack: _convertToCardPack(pack),
            cards: cards,
          ),
        );
        
        if (mounted && dialogShown == true) {
          _showPackSummary(cards);
        }
      }
    } catch (e) {
      debugPrint('Ошибка покупки пака: $e');
      if (mounted) {
        _showErrorDialog();
        await CardGameService.addCoins(pack.cost);
        await _loadShopData();
      }
    } finally {
      if (mounted) {
        setState(() => _isOpening = false);
      }
    }
  }

  CardPack _convertToCardPack(ShopPack shopPack) {
    return CardPack(
      id: shopPack.id,
      title: shopPack.title,
      description: shopPack.description,
      cost: shopPack.cost,
      cardsCount: shopPack.cardsCount,
      color: shopPack.color,
      icon: shopPack.icon,
      expReward: 0,
      rarityWeights: shopPack.rarityWeights,
    );
  }

  Future<List<AnimeCard>> _generateCardsForPack(ShopPack pack) async {
    final List<AnimeCard> cards = [];
    final random = math.Random();
    final allCards = await _getAllBaseCards();
    
    for (int i = 0; i < pack.cardsCount; i++) {
      final rarity = _selectRarityByWeight(pack.rarityWeights, random);
      final cardsOfRarity = allCards.where((card) => card.rarity == rarity).toList();
      
      if (cardsOfRarity.isNotEmpty) {
        final baseCard = cardsOfRarity[random.nextInt(cardsOfRarity.length)];
        final newCard = _createCardFromBase(baseCard);
        cards.add(newCard);
      } else {
        final commonCards = allCards.where((card) => card.rarity == CardRarity.common).toList();
        if (commonCards.isNotEmpty) {
          final baseCard = commonCards[random.nextInt(commonCards.length)];
          final newCard = _createCardFromBase(baseCard);
          cards.add(newCard);
        }
      }
    }

    if (pack.bonusCards > 0) {
      for (int i = 0; i < pack.bonusCards; i++) {
        final guaranteedCards = allCards.where((card) => card.rarity == pack.guaranteedRarity).toList();
        if (guaranteedCards.isNotEmpty) {
          final baseCard = guaranteedCards[random.nextInt(guaranteedCards.length)];
          final newCard = _createCardFromBase(baseCard);
          cards.add(newCard);
        }
      }
    }

    if (cards.isNotEmpty) {
      await _addCardsToPlayerCollection(cards);
    }

    return cards;
  }

  Future<List<AnimeCard>> _getAllBaseCards() async {
    final allCards = <AnimeCard>[];
    for (final rarity in CardRarity.values) {
      final cards = CardGameService.getCardsByRarity(rarity);
      allCards.addAll(cards);
    }
    return allCards;
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
      id: 'shop_${baseCard.id}_${DateTime.now().millisecondsSinceEpoch}_${math.Random().nextInt(10000)}',
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

  Future<bool> _addCardsToPlayerCollection(List<AnimeCard> cards) async {
    try {
      await CardGameService.addCardsToCollection(cards);
      return true;
    } catch (e) {
      debugPrint('Ошибка при добавлении карт в коллекцию: $e');
      return false;
    }
  }

  Future<void> _buyCard(ShopCard shopCard) async {
    final finalPrice = shopCard.discount > 0 
        ? (shopCard.price * (100 - shopCard.discount) / 100).round()
        : shopCard.price;
    
    final confirmed = await _showBuyCardConfirmation(shopCard, finalPrice);
    if (!confirmed) return;
    
    if (_coins < finalPrice) {
      _showInsufficientCoinsDialog();
      return;
    }

    final success = await CardGameService.spendCoins(finalPrice);
    if (!success) {
      _showInsufficientCoinsDialog();
      return;
    }

    final card = _createCardFromBase(shopCard.card);
    
    if (mounted) {
      await CardGameService.addCardsToCollection([card]);
      _coins = await CardGameService.getCoins();
      setState(() {});
      
      await _showCardDetailAnimation(card);
    }
  }

  Future<bool> _showBuyCardConfirmation(ShopCard shopCard, int finalPrice) async {
    final result = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: Colors.grey[900]?.withOpacity(0.95) ?? Colors.grey,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Row(
          children: [
            const Icon(Icons.shopping_cart, color: Colors.blue),
            const SizedBox(width: 12),
            Text(
              'Покупка карты',
              style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
            ),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: double.infinity,
              height: 200,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: shopCard.card.rarity.borderColor,
                  width: 2,
                ),
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(10),
                child: CachedNetworkImage(
                  imageUrl: shopCard.card.imageUrl,
                  fit: BoxFit.cover,
                ),
              ),
            ),
            const SizedBox(height: 16),
            Text(
              shopCard.card.characterName,
              style: const TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: Colors.white,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              shopCard.card.animeName,
              style: TextStyle(
                fontSize: 14,
                color: Colors.white.withOpacity(0.7),
              ),
            ),
            const SizedBox(height: 16),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.monetization_on_rounded, color: Color(0xFFFFD700), size: 24),
                const SizedBox(width: 8),
                Text(
                  '$finalPrice',
                  style: const TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFFFFD700),
                  ),
                ),
              ],
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            style: TextButton.styleFrom(foregroundColor: Colors.white),
            child: const Text('Отмена'),
          ),
          ElevatedButton(
            onPressed: () {
              HapticFeedback.mediumImpact();
              Navigator.pop(context, true);
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF4CAF50),
              foregroundColor: Colors.white,
            ),
            child: const Text('Купить'),
          ),
        ],
      ),
    );
    
    return result ?? false;
  }

  Future<void> _showCardDetailAnimation(AnimeCard card) async {
    await showDialog(
      context: context,
      barrierDismissible: true,
      builder: (context) => _SingleCardDetailDialog(card: card),
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
          'У вас недостаточно монет для покупки. Заработайте больше монет в городе или получите ежедневный бонус!',
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
          'Не удалось совершить покупку. Пожалуйста, проверьте подключение и попробуйте позже.',
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

  @override
  void dispose() {
    _rotationTimer?.cancel();
    _countdownTimer?.cancel();
    _bgAnimController.dispose();
    _particleController.dispose();
    _fadeController.dispose();
    super.dispose();
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
            child: FadeTransition(
              opacity: _fadeController,
              child: Column(
                children: [
                  _buildHeader(),
                  Expanded(
                    child: _isLoading
                        ? const Center(child: CircularProgressIndicator(color: Color(0xFFFF3366)))
                        : RefreshIndicator(
                            onRefresh: _loadShopData,
                            color: const Color(0xFFFF3366),
                            child: CustomScrollView(
                              physics: const BouncingScrollPhysics(
                                parent: AlwaysScrollableScrollPhysics(),
                              ),
                              slivers: [
                                SliverToBoxAdapter(child: _buildTimerSection()),
                                SliverToBoxAdapter(child: _buildLimitedPacksSection()),
                                SliverToBoxAdapter(child: _buildRandomCardsSection()),
                                const SliverToBoxAdapter(child: SizedBox(height: 20)),
                              ],
                            ),
                          ),
                  ),
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

  Widget _buildHeader() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            const Color(0xFFFF3366).withOpacity(0.1),
            const Color(0xFF2196F3).withOpacity(0.08),
          ],
        ),
        borderRadius: const BorderRadius.only(
          bottomLeft: Radius.circular(24),
          bottomRight: Radius.circular(24),
        ),
      ),
      child: Row(
        children: [
          IconButton(
            icon: const Icon(Icons.arrow_back_rounded, color: Colors.white),
            onPressed: () {
              HapticFeedback.lightImpact();
              Navigator.pop(context);
            },
          ),
          const Expanded(
            child: Text(
              'Магазин карт',
              style: TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.w700,
                color: Colors.white,
              ),
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
                const Icon(Icons.monetization_on_rounded, color: Colors.white, size: 18),
                const SizedBox(width: 6),
                Text(
                  '$_coins',
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    ).animate().fadeIn(duration: 400.ms);
  }

  Widget _buildTimerSection() {
    final hours = _timeUntilRotation.inHours;
    final minutes = _timeUntilRotation.inMinutes % 60;
    final seconds = _timeUntilRotation.inSeconds % 60;

    return Container(
      margin: const EdgeInsets.all(16),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            const Color(0xFFFF3366).withOpacity(0.3),
            const Color(0xFF8B0000).withOpacity(0.3),
          ],
        ),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: const Color(0xFFFF3366).withOpacity(0.5),
          width: 1,
        ),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(Icons.timer_rounded, color: Colors.white70, size: 18),
                  const SizedBox(width: 8),
                  const Text(
                    'Обновление магазина',
                    style: TextStyle(
                      fontSize: 14,
                      color: Colors.white70,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Text(
                '${hours.toString().padLeft(2, '0')}:${minutes.toString().padLeft(2, '0')}:${seconds.toString().padLeft(2, '0')}',
                style: const TextStyle(
                  fontSize: 28,
                  fontWeight: FontWeight.w900,
                  color: Color(0xFFFF3366),
                  letterSpacing: 2,
                ),
              ),
            ],
          ),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.1),
              shape: BoxShape.circle,
            ),
            child: IconButton(
              icon: const Icon(Icons.refresh_rounded, color: Colors.white),
              onPressed: () {
                HapticFeedback.mediumImpact();
                _loadShopData();
              },
            ),
          ),
        ],
      ),
    ).animate().fadeIn(delay: 100.ms).slideY(begin: 0.1, end: 0);
  }

  Widget _buildLimitedPacksSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Padding(
          padding: EdgeInsets.fromLTRB(20, 0, 20, 16),
          child: Text(
            'Лимитированные паки',
            style: TextStyle(
              color: Colors.white,
              fontSize: 22,
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
        ..._limitedPacks.asMap().entries.map((e) => 
          _ShopPackCard(
            pack: e.value,
            onTap: () => _buyPack(e.value),
            isOpening: _isOpening,
            canAfford: _coins >= e.value.cost,
          ).animate(delay: (e.key * 100).ms).fadeIn(duration: 300.ms).slideX(begin: 0.5, end: 0)
        ),
      ],
    );
  }

  Widget _buildRandomCardsSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Padding(
          padding: EdgeInsets.fromLTRB(20, 32, 20, 16),
          child: Text(
            'Случайные карты',
            style: TextStyle(
              color: Colors.white,
              fontSize: 22,
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
        GridView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          padding: const EdgeInsets.symmetric(horizontal: 20),
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 2,
            childAspectRatio: 0.65,
            crossAxisSpacing: 16,
            mainAxisSpacing: 16,
          ),
          itemCount: _randomCards.length,
          itemBuilder: (context, index) {
            final shopCard = _randomCards[index];
            return _ShopCardTile(
              shopCard: shopCard,
              canAfford: _coins >= (shopCard.discount > 0 
                  ? (shopCard.price * (100 - shopCard.discount) / 100).round()
                  : shopCard.price),
              onTap: () => _buyCard(shopCard),
            ).animate(delay: (index * 30).ms)
              .fadeIn(duration: 400.ms)
              .scale(begin: const Offset(0.8, 0.8));
          },
        ),
      ],
    );
  }
}

// КЛАССЫ ДЛЯ МАГАЗИНА

class ShopPack {
  final String id;
  final String title;
  final String description;
  final int cost;
  final int cardsCount;
  final Color color;
  final IconData icon;
  final CardRarity guaranteedRarity;
  final int bonusCards;
  final Map<CardRarity, int> rarityWeights;

  const ShopPack({
    required this.id,
    required this.title,
    required this.description,
    required this.cost,
    required this.cardsCount,
    required this.color,
    required this.icon,
    required this.guaranteedRarity,
    required this.bonusCards,
    required this.rarityWeights,
  });
}

class ShopCard {
  final AnimeCard card;
  final int price;
  final int discount;

  const ShopCard({
    required this.card,
    required this.price,
    required this.discount,
  });
}

class _ShopPackCard extends StatefulWidget {
  final ShopPack pack;
  final VoidCallback onTap;
  final bool isOpening;
  final bool canAfford;

  const _ShopPackCard({
    required this.pack,
    required this.onTap,
    required this.isOpening,
    required this.canAfford,
  });

  @override
  State<_ShopPackCard> createState() => _ShopPackCardState();
}

class _ShopPackCardState extends State<_ShopPackCard> with SingleTickerProviderStateMixin {
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
                margin: const EdgeInsets.only(bottom: 12, left: 16, right: 16),
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
                    if (widget.pack.bonusCards > 0)
                      Positioned(
                        top: 12,
                        right: 12,
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                          decoration: BoxDecoration(
                            gradient: const LinearGradient(
                              colors: [Color(0xFFFF3366), Color(0xFFFF1744)],
                            ),
                            borderRadius: BorderRadius.circular(8),
                            boxShadow: [
                              BoxShadow(
                                color: const Color(0xFFFF3366).withOpacity(0.5),
                                blurRadius: 8,
                              ),
                            ],
                          ),
                          child: Text(
                            '+${widget.pack.bonusCards}',
                            style: const TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w900,
                              color: Colors.white,
                            ),
                          ),
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

class _ShopCardTile extends StatelessWidget {
  final ShopCard shopCard;
  final bool canAfford;
  final VoidCallback onTap;

  const _ShopCardTile({
    required this.shopCard,
    required this.canAfford,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final card = shopCard.card;
    final finalPrice = shopCard.discount > 0 
        ? (shopCard.price * (100 - shopCard.discount) / 100).round()
        : shopCard.price;

    return GestureDetector(
      onTap: () {
        HapticFeedback.mediumImpact();
        onTap();
      },
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: card.rarity.borderColor,
            width: 2,
          ),
          boxShadow: [
            BoxShadow(
              color: card.rarity.borderColor.withOpacity(0.4),
              blurRadius: 15,
              offset: const Offset(0, 5),
            ),
          ],
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(14),
          child: Stack(
            fit: StackFit.expand,
            children: [
              CachedNetworkImage(
                imageUrl: card.imageUrl,
                fit: BoxFit.cover,
                memCacheWidth: 400,
                memCacheHeight: 600,
                placeholder: (context, url) => Container(
                  color: Colors.grey.shade900,
                  child: Center(
                    child: CircularProgressIndicator(
                      color: card.rarity.borderColor,
                      strokeWidth: 2,
                    ),
                  ),
                ),
                errorWidget: (context, url, error) => Container(
                  color: Colors.grey.shade900,
                  child: Icon(Icons.error, color: card.rarity.borderColor),
                ),
              ),
              
              Container(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [
                      Colors.transparent,
                      Colors.black.withOpacity(0.9),
                    ],
                  ),
                ),
              ),
              
              Padding(
                padding: const EdgeInsets.all(12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: card.rarity.borderColor.withOpacity(0.9),
                        borderRadius: BorderRadius.circular(8),
                        boxShadow: [
                          BoxShadow(
                            color: card.rarity.borderColor.withOpacity(0.6),
                            blurRadius: 8,
                          ),
                        ],
                      ),
                      child: Text(
                        card.rarity.displayName,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 10,
                          fontWeight: FontWeight.w900,
                          letterSpacing: 0.5,
                        ),
                      ),
                    ),
                    
                    const Spacer(),
                    
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: Colors.black.withOpacity(0.7),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            card.characterName,
                            style: const TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w900,
                              color: Colors.white,
                              height: 1.1,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          const SizedBox(height: 2),
                          Text(
                            card.animeName,
                            style: TextStyle(
                              fontSize: 10,
                              color: Colors.white.withOpacity(0.8),
                              fontWeight: FontWeight.w600,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ],
                      ),
                    ),
                    
                    const SizedBox(height: 8),
                    
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        if (shopCard.discount > 0) ...[
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
                            decoration: BoxDecoration(
                              color: const Color(0xFFFF3366),
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Text(
                              '-${shopCard.discount}%',
                              style: const TextStyle(
                                fontSize: 10,
                                fontWeight: FontWeight.w900,
                                color: Colors.white,
                              ),
                            ),
                          ),
                          const Spacer(),
                          Text(
                            '${shopCard.price}',
                            style: TextStyle(
                              fontSize: 11,
                              decoration: TextDecoration.lineThrough,
                              color: Colors.white.withOpacity(0.5),
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              colors: canAfford 
                                  ? [Color(0xFFFFD700), Color(0xFFFFA500)]
                                  : [Colors.grey.shade700, Colors.grey.shade800],
                            ),
                            borderRadius: BorderRadius.circular(8),
                            boxShadow: [
                              BoxShadow(
                                color: canAfford 
                                    ? Color(0xFFFFD700).withOpacity(0.4)
                                    : Colors.transparent,
                                blurRadius: 8,
                              ),
                            ],
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Icon(
                                Icons.monetization_on_rounded,
                                color: Colors.white,
                                size: 14,
                              ),
                              const SizedBox(width: 4),
                              Text(
                                '$finalPrice',
                                style: const TextStyle(
                                  fontSize: 14,
                                  fontWeight: FontWeight.w900,
                                  color: Colors.white,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// СКОПИРОВАННЫЕ КЛАССЫ ИЗ CARD_GAME_SCREEN ДЛЯ АНИМАЦИЙ

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
                          child: const Icon(
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
                              style: const TextStyle(
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
                        const Text(
                          'Статистика по редкостям',
                          style: TextStyle(
                            color: Colors.white,
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
                                      child: const Icon(
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
                                      _getRarityDescription(rarity),
                                      style: const TextStyle(
                                        color: Colors.white70,
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
                                    style: const TextStyle(
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

class _SingleCardDetailDialog extends StatefulWidget {
  final AnimeCard card;

  const _SingleCardDetailDialog({required this.card});

  @override
  State<_SingleCardDetailDialog> createState() => _SingleCardDetailDialogState();
}

class _SingleCardDetailDialogState extends State<_SingleCardDetailDialog> with SingleTickerProviderStateMixin {
  late AnimationController _animationController;

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      duration: const Duration(milliseconds: 1500),
      vsync: this,
    );
    _animationController.forward();
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () => Navigator.pop(context),
      child: Container(
        color: Colors.transparent,
        child: Center(
          child: GestureDetector(
            onTap: () {},
            child: AnimatedBuilder(
              animation: _animationController,
              builder: (context, child) {
                final fallAnimation = CurvedAnimation(
                  parent: _animationController,
                  curve: const Interval(0.0, 0.6, curve: Curves.bounceOut),
                );

                final glowAnimation = CurvedAnimation(
                  parent: _animationController,
                  curve: const Interval(0.4, 1.0, curve: Curves.easeInOut),
                );

                return Transform.translate(
                  offset: Offset(0, (1 - fallAnimation.value) * -100),
                  child: Transform.scale(
                    scale: 0.9 + 0.1 * fallAnimation.value,
                    child: _PrestigousCardDisplay(
                      card: widget.card,
                      glowAnimation: glowAnimation,
                    ),
                  ),
                );
              },
            ),
          ),
        ),
      ),
    );
  }
}