// ui/craft_screen.dart
import 'package:flutter/material.dart';
import '../models/anime_card.dart';
import '../services/card_game_service.dart';

class CraftScreen extends StatefulWidget {
  @override
  _CraftScreenState createState() => _CraftScreenState();
}

class _CraftScreenState extends State<CraftScreen> {
  int _playerCoins = 0;
  bool _isCrafting = false;
  List<AnimeCard>? _lastCraftedCards;
  List<CardGroup> _cardGroups = [];

  @override
  void initState() {
    super.initState();
    _loadPlayerData();
    _loadCollection();
  }

  Future<void> _loadPlayerData() async {
    final coins = await CardGameService.getCoins();
    setState(() {
      _playerCoins = coins;
    });
  }

  Future<void> _loadCollection() async {
    try {
      final groups = await CardGameService.getCardGroups();
      setState(() {
        _cardGroups = groups;
      });
    } catch (e) {
      print('Ошибка загрузки коллекции: $e');
    }
  }

  Future<void> _performCraft(CraftType craftType) async {
    if (_isCrafting) return;

    setState(() {
      _isCrafting = true;
      _lastCraftedCards = null;
    });

    try {
      final craftedCards = await CardGameService.craftCards(craftType);
      
      setState(() {
        _lastCraftedCards = craftedCards;
      });

      // Обновляем данные игрока и коллекцию
      await _loadPlayerData();
      await _loadCollection();

      // Показываем результат
      _showCraftResult(craftedCards, craftType);
    } catch (e) {
      _showErrorDialog(e.toString());
    } finally {
      setState(() {
        _isCrafting = false;
      });
    }
  }

  void _showCraftResult(List<AnimeCard> cards, CraftType craftType) {
    showDialog(
      context: context,
      builder: (context) => CraftResultDialog(
        cards: cards,
        craftType: craftType,
        onClose: () {
          Navigator.of(context).pop();
          setState(() {
            _lastCraftedCards = null;
          });
        },
      ),
    );
  }

  void _showErrorDialog(String message) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Ошибка крафта'),
        content: Text(message),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: Text('OK'),
          ),
        ],
      ),
    );
  }

  bool _checkIfHasCardsForCraft(CraftType craftType) {
    // Проверяем есть ли достаточно карт нужной редкости для крафта
    final requiredRarity = craftType.requiredRarity;
    final requiredCount = craftType.requiredCardCount;
    
    final availableCards = _cardGroups
        .where((group) => group.baseCard.rarity == requiredRarity)
        .fold(0, (sum, group) => sum + group.totalCount);
    
    return availableCards >= requiredCount;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[900],
      body: CustomScrollView(
        slivers: [
          SliverAppBar(
            expandedHeight: 200,
            flexibleSpace: FlexibleSpaceBar(
              title: Text('Мастерская Крафта'),
              background: Container(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [Colors.blue[800]!, Colors.purple[800]!],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                ),
                child: Opacity(
                  opacity: 0.3,
                  child: Image.asset(
                    'assets/images/craft_background.png',
                    fit: BoxFit.cover,
                  ),
                ),
              ),
            ),
          ),
          SliverToBoxAdapter(
            child: Padding(
              padding: EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Статистика игрока
                  _buildPlayerStats(),
                  SizedBox(height: 24),
                  
                  // Доступные крафты
                  Text(
                    'Доступные Крафты',
                    style: TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),
                  SizedBox(height: 16),
                ],
              ),
            ),
          ),
          SliverList(
            delegate: SliverChildListDelegate([
              ...CraftType.values.where((type) => type != CraftType.common).map((craftType) => 
                _buildCraftOption(craftType)
              ),
            ]),
          ),
          
          // Последние созданные карты
          if (_lastCraftedCards != null && _lastCraftedCards!.isNotEmpty)
            SliverToBoxAdapter(
              child: Padding(
                padding: EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Последние создания',
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                    ),
                    SizedBox(height: 16),
                    SizedBox(
                      height: 200,
                      child: ListView.builder(
                        scrollDirection: Axis.horizontal,
                        itemCount: _lastCraftedCards!.length,
                        itemBuilder: (context, index) => 
                          _buildCraftedCardPreview(_lastCraftedCards![index]),
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

  Widget _buildPlayerStats() {
    return Card(
      color: Colors.grey[800],
      child: Padding(
        padding: EdgeInsets.all(16),
        child: Row(
          children: [
            Icon(Icons.monetization_on, color: Colors.yellow[600], size: 32),
            SizedBox(width: 12),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Монеты',
                  style: TextStyle(color: Colors.grey[300], fontSize: 14),
                ),
                Text(
                  '$_playerCoins',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
            Spacer(),
            FutureBuilder<int>(
              future: CardGameService.getPlayerLevel(),
              builder: (context, snapshot) {
                final level = snapshot.data ?? 1;
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(
                      'Уровень',
                      style: TextStyle(color: Colors.grey[300], fontSize: 14),
                    ),
                    Text(
                      '$level',
                      style: TextStyle(
                        color: Colors.blue[300],
                        fontSize: 24,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                );
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCraftOption(CraftType craftType) {
    final hasRequiredCards = _checkIfHasCardsForCraft(craftType);
    
    return Padding(
      padding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Card(
        color: Colors.grey[800],
        elevation: 4,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
        ),
        child: InkWell(
          onTap: hasRequiredCards && !_isCrafting 
              ? () => _performCraft(craftType)
              : null,
          borderRadius: BorderRadius.circular(16),
          child: Container(
            padding: EdgeInsets.all(16),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(16),
              gradient: LinearGradient(
                colors: [
                  craftType.color.withOpacity(0.3),
                  craftType.color.withOpacity(0.1),
                ],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
            ),
            child: Row(
              children: [
                // Иконка крафта
                Container(
                  width: 60,
                  height: 60,
                  decoration: BoxDecoration(
                    color: craftType.color.withOpacity(0.2),
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: craftType.color,
                      width: 2,
                    ),
                  ),
                  child: Icon(
                    craftType.icon,
                    color: craftType.color,
                    size: 30,
                  ),
                ),
                SizedBox(width: 16),
                
                // Информация о крафте
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        craftType.displayName,
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      SizedBox(height: 4),
                      Text(
                        craftType.description,
                        style: TextStyle(
                          color: Colors.grey[300],
                          fontSize: 14,
                        ),
                      ),
                      SizedBox(height: 8),
                      Row(
                        children: [
                          Icon(Icons.card_giftcard, 
                              color: hasRequiredCards ? Colors.green : Colors.red, 
                              size: 16),
                          SizedBox(width: 4),
                          Text(
                            '${craftType.requiredCardCount} карт',
                            style: TextStyle(
                              color: hasRequiredCards ? Colors.green : Colors.red,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          SizedBox(width: 16),
                          Container(
                            padding: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                            decoration: BoxDecoration(
                              color: craftType.requiredRarity.borderColor.withOpacity(0.3),
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(
                                color: craftType.requiredRarity.borderColor,
                              ),
                            ),
                            child: Text(
                              craftType.requiredRarity.displayName,
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 12,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                
                // Кнопка крафта
                Container(
                  width: 48,
                  height: 48,
                  decoration: BoxDecoration(
                    color: hasRequiredCards ? craftType.color : Colors.grey[600],
                    shape: BoxShape.circle,
                  ),
                  child: _isCrafting
                      ? CircularProgressIndicator(
                          valueColor: AlwaysStoppedAnimation(Colors.white),
                          strokeWidth: 3,
                        )
                      : Icon(
                          Icons.auto_awesome,
                          color: Colors.white,
                        ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildCraftedCardPreview(AnimeCard card) {
    return Container(
      width: 150,
      margin: EdgeInsets.only(right: 12),
      child: Card(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Изображение карты
              Expanded(
                flex: 3,
                child: Container(
                  decoration: BoxDecoration(
                    image: DecorationImage(
                      image: NetworkImage(card.imageUrl),
                      fit: BoxFit.cover,
                    ),
                  ),
                  child: Container(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: [
                          Colors.transparent,
                          Colors.black.withOpacity(0.7),
                        ],
                      ),
                    ),
                    child: Stack(
                      children: [
                        // Редкость
                        Positioned(
                          top: 8,
                          left: 8,
                          child: Container(
                            padding: EdgeInsets.symmetric(
                              horizontal: 6, vertical: 2),
                            decoration: BoxDecoration(
                              color: card.rarity.borderColor,
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Text(
                              card.rarity.displayName,
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 10,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              
              // Информация
              Expanded(
                flex: 2,
                child: Container(
                  padding: EdgeInsets.all(8),
                  color: Colors.grey[900],
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        card.characterName,
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      SizedBox(height: 2),
                      Text(
                        card.animeName,
                        style: TextStyle(
                          color: Colors.grey[400],
                          fontSize: 10,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      Spacer(),
                      Row(
                        children: [
                          Icon(Icons.bolt, 
                              color: Colors.yellow[600], size: 12),
                          SizedBox(width: 4),
                          Text(
                            '${card.power}',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 10,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          Spacer(),
                          Container(
                            padding: EdgeInsets.symmetric(
                              horizontal: 4, vertical: 1),
                            decoration: BoxDecoration(
                              color: card.genre.emoji == '⚡' ? Colors.orange 
                                    : card.genre.emoji == '🔮' ? Colors.purple
                                    : card.genre.emoji == '💖' ? Colors.pink
                                    : Colors.grey,
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: Text(
                              card.genre.emoji,
                              style: TextStyle(fontSize: 10),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class CraftResultDialog extends StatelessWidget {
  final List<AnimeCard> cards;
  final CraftType craftType;
  final VoidCallback onClose;

  const CraftResultDialog({
    required this.cards,
    required this.craftType,
    required this.onClose,
  });

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: Colors.transparent,
      child: Container(
        width: double.maxFinite,
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [
              Colors.blue[900]!,
              Colors.purple[900]!,
            ],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          borderRadius: BorderRadius.circular(20),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Заголовок
            Container(
              padding: EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.black.withOpacity(0.3),
                borderRadius: BorderRadius.only(
                  topLeft: Radius.circular(20),
                  topRight: Radius.circular(20),
                ),
              ),
              child: Row(
                children: [
                  Icon(craftType.icon, color: Colors.white, size: 24),
                  SizedBox(width: 12),
                  Text(
                    'Успешный крафт!',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  Spacer(),
                  IconButton(
                    icon: Icon(Icons.close, color: Colors.white),
                    onPressed: onClose,
                  ),
                ],
              ),
            ),
            
            // Карты
            Padding(
              padding: EdgeInsets.all(16),
              child: GridView.builder(
                shrinkWrap: true,
                physics: NeverScrollableScrollPhysics(),
                gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 2,
                  crossAxisSpacing: 12,
                  mainAxisSpacing: 12,
                  childAspectRatio: 0.7,
                ),
                itemCount: cards.length,
                itemBuilder: (context, index) => _buildResultCard(cards[index]),
              ),
            ),
            
            // Кнопка закрытия
            Container(
              padding: EdgeInsets.all(16),
              child: ElevatedButton(
                onPressed: onClose,
                style: ElevatedButton.styleFrom(
                  backgroundColor: craftType.color,
                  padding: EdgeInsets.symmetric(horizontal: 32, vertical: 12),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                child: Text(
                  'Продолжить',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildResultCard(AnimeCard card) {
    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: card.rarity.borderColor.withOpacity(0.5),
            blurRadius: 10,
            spreadRadius: 2,
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(12),
        child: Stack(
          children: [
            // Фон карты
            Container(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: card.cardGradient,
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // Изображение
                  Expanded(
                    flex: 3,
                    child: Container(
                      decoration: BoxDecoration(
                        image: DecorationImage(
                          image: NetworkImage(card.imageUrl),
                          fit: BoxFit.cover,
                        ),
                      ),
                    ),
                  ),
                  
                  // Информация
                  Expanded(
                    flex: 2,
                    child: Container(
                      padding: EdgeInsets.all(8),
                      color: Colors.black.withOpacity(0.7),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            card.characterName,
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 14,
                              fontWeight: FontWeight.bold,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          SizedBox(height: 2),
                          Text(
                            card.animeName,
                            style: TextStyle(
                              color: Colors.grey[300],
                              fontSize: 10,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          Spacer(),
                          Row(
                            children: [
                              Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    children: [
                                      Icon(Icons.bolt, 
                                          color: Colors.yellow[600], size: 12),
                                      SizedBox(width: 4),
                                      Text(
                                        '${card.power}',
                                        style: TextStyle(
                                          color: Colors.white,
                                          fontSize: 12,
                                        ),
                                      ),
                                    ],
                                  ),
                                  SizedBox(height: 2),
                                  Row(
                                    children: [
                                      Icon(Icons.favorite, 
                                          color: Colors.red, size: 12),
                                      SizedBox(width: 4),
                                      Text(
                                        '${card.hp}',
                                        style: TextStyle(
                                          color: Colors.white,
                                          fontSize: 12,
                                        ),
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                              Spacer(),
                              Container(
                                padding: EdgeInsets.symmetric(
                                  horizontal: 6, vertical: 2),
                                decoration: BoxDecoration(
                                  color: card.rarity.borderColor,
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: Text(
                                  card.rarity.displayName,
                                  style: TextStyle(
                                    color: Colors.white,
                                    fontSize: 10,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
            
            // Эффекты новой карты
            Positioned(
              top: 8,
              right: 8,
              child: Container(
                padding: EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: Colors.green,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  'НОВАЯ!',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 10,
                    fontWeight: FontWeight.bold,
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