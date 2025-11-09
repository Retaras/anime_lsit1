// ui/upgrade_screen.dart
import 'package:flutter/material.dart';
import '../models/anime_card.dart';
import '../services/card_game_service.dart';

class UpgradeScreen extends StatefulWidget {
  @override
  _UpgradeScreenState createState() => _UpgradeScreenState();
}

class _UpgradeScreenState extends State<UpgradeScreen> {
  List<CardGroup> _cardGroups = [];
  bool _isLoading = true;
  int _playerCoins = 0;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    setState(() {
      _isLoading = true;
    });

    try {
      final groups = await CardGameService.getCardGroups();
      final coins = await CardGameService.getCoins();
      
      setState(() {
        _cardGroups = groups;
        _playerCoins = coins;
      });
    } catch (e) {
      print('Ошибка загрузки данных: $e');
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  Future<void> _upgradeCard(CardGroup group) async {
    if (!group.canUpgrade) return;

    try {
      await CardGameService.upgradeCard(group.baseCard);
      await _loadData(); // Перезагружаем данные
      
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Карта улучшена до уровня ${group.baseCard.level + 1}!'),
          backgroundColor: Colors.green,
        ),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Ошибка улучшения: ${e.toString()}'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  void _showCardDetails(CardGroup group) {
    showDialog(
      context: context,
      builder: (context) => CardUpgradeDialog(
        cardGroup: group,
        playerCoins: _playerCoins,
        onUpgrade: () => _upgradeCard(group),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[900],
      appBar: AppBar(
        title: Text('Улучшение Карт'),
        backgroundColor: Colors.grey[900],
        elevation: 0,
        actions: [
          Padding(
            padding: EdgeInsets.only(right: 16),
            child: Row(
              children: [
                Icon(Icons.monetization_on, color: Colors.yellow[600]),
                SizedBox(width: 8),
                Text(
                  '$_playerCoins',
                  style: TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
      body: _isLoading
          ? Center(child: CircularProgressIndicator())
          : _buildCardGrid(),
    );
  }

  Widget _buildCardGrid() {
    if (_cardGroups.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.collections, size: 64, color: Colors.grey[600]),
            SizedBox(height: 16),
            Text(
              'Коллекция пуста',
              style: TextStyle(
                color: Colors.grey[400],
                fontSize: 18,
              ),
            ),
          ],
        ),
      );
    }

    return GridView.builder(
      padding: EdgeInsets.all(16),
      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        crossAxisSpacing: 16,
        mainAxisSpacing: 16,
        childAspectRatio: 0.7,
      ),
      itemCount: _cardGroups.length,
      itemBuilder: (context, index) => _buildCardItem(_cardGroups[index]),
    );
  }

  Widget _buildCardItem(CardGroup group) {
    final card = group.baseCard;
    final canUpgrade = group.canUpgrade;
    final requiredDupes = card.getRequiredDuplicatesForUpgrade();
    final availableDupes = group.availableForUpgrade;

    return GestureDetector(
      onTap: () => _showCardDetails(group),
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: card.rarity.borderColor.withOpacity(0.3),
              blurRadius: 8,
              spreadRadius: 2,
            ),
          ],
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(16),
          child: Stack(
            children: [
              // Основная карта
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
                    // Изображение персонажа
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
                                Colors.black.withOpacity(0.8),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ),
                    
                    // Информация о карте
                    Expanded(
                      flex: 2,
                      child: Container(
                        padding: EdgeInsets.all(12),
                        color: Colors.black.withOpacity(0.8),
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
                            
                            // Уровень и дубликаты
                            Row(
                              children: [
                                Container(
                                  padding: EdgeInsets.symmetric(
                                    horizontal: 8, vertical: 2),
                                  decoration: BoxDecoration(
                                    color: Colors.blue[700],
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  child: Text(
                                    'Ур. ${card.level}',
                                    style: TextStyle(
                                      color: Colors.white,
                                      fontSize: 10,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ),
                                Spacer(),
                                Container(
                                  padding: EdgeInsets.symmetric(
                                    horizontal: 6, vertical: 2),
                                  decoration: BoxDecoration(
                                    color: Colors.green[700],
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  child: Text(
                                    '$availableDupes/$requiredDupes',
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
              
              // Индикатор улучшения
              if (canUpgrade)
                Positioned(
                  top: 8,
                  right: 8,
                  child: Container(
                    padding: EdgeInsets.all(6),
                    decoration: BoxDecoration(
                      color: Colors.green,
                      shape: BoxShape.circle,
                    ),
                    child: Icon(
                      Icons.arrow_upward,
                      color: Colors.white,
                      size: 16,
                    ),
                  ),
                ),
              
              // Бейдж дубликатов
              Positioned(
                top: 8,
                left: 8,
                child: Container(
                  padding: EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(
                    color: Colors.orange[700],
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    '${group.totalCount}',
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
    );
  }
}

class CardUpgradeDialog extends StatelessWidget {
  final CardGroup cardGroup;
  final int playerCoins;
  final VoidCallback onUpgrade;

  const CardUpgradeDialog({
    required this.cardGroup,
    required this.playerCoins,
    required this.onUpgrade,
  });

  @override
  Widget build(BuildContext context) {
    final card = cardGroup.baseCard;
    final canUpgrade = cardGroup.canUpgrade;
    final requiredDupes = card.getRequiredDuplicatesForUpgrade();
    final availableDupes = cardGroup.availableForUpgrade;
    final upgradeCost = card.upgradeCost;
    final canAfford = playerCoins >= upgradeCost;

    return Dialog(
      backgroundColor: Colors.transparent,
      child: Container(
        width: double.maxFinite,
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [
              Colors.grey[900]!,
              Colors.grey[800]!,
            ],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          borderRadius: BorderRadius.circular(20),
        ),
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Заголовок
              Container(
                padding: EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.black.withOpacity(0.5),
                  borderRadius: BorderRadius.only(
                    topLeft: Radius.circular(20),
                    topRight: Radius.circular(20),
                  ),
                ),
                child: Row(
                  children: [
                    Icon(Icons.auto_awesome, color: Colors.yellow[600]),
                    SizedBox(width: 12),
                    Text(
                      'Улучшение карты',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    Spacer(),
                    IconButton(
                      icon: Icon(Icons.close, color: Colors.white),
                      onPressed: () => Navigator.of(context).pop(),
                    ),
                  ],
                ),
              ),
              
              // Информация о карте
              Padding(
                padding: EdgeInsets.all(16),
                child: Column(
                  children: [
                    // Изображение и основная информация
                    _buildCardHeader(card),
                    SizedBox(height: 20),
                    
                    // Текущая статистика
                    _buildCurrentStats(card),
                    SizedBox(height: 20),
                    
                    // Улучшение статистики
                    if (canUpgrade) _buildUpgradeStats(card),
                    SizedBox(height: 20),
                    
                    // Требования для улучшения
                    _buildUpgradeRequirements(
                      requiredDupes, 
                      availableDupes, 
                      upgradeCost, 
                      canAfford
                    ),
                    SizedBox(height: 20),
                    
                    // Кнопка улучшения
                    _buildUpgradeButton(
                      canUpgrade && canAfford, 
                      upgradeCost
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

  Widget _buildCardHeader(AnimeCard card) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Изображение карты
        Container(
          width: 100,
          height: 140,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(12),
            image: DecorationImage(
              image: NetworkImage(card.imageUrl),
              fit: BoxFit.cover,
            ),
            boxShadow: [
              BoxShadow(
                color: card.rarity.borderColor.withOpacity(0.5),
                blurRadius: 10,
              ),
            ],
          ),
        ),
        SizedBox(width: 16),
        
        // Информация
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                card.characterName,
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
              SizedBox(height: 4),
              Text(
                card.animeName,
                style: TextStyle(
                  color: Colors.grey[300],
                  fontSize: 14,
                ),
              ),
              SizedBox(height: 8),
              Container(
                padding: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: card.rarity.borderColor.withOpacity(0.3),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(
                    color: card.rarity.borderColor,
                  ),
                ),
                child: Text(
                  '${card.rarity.displayName} • Ур. ${card.level}',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              SizedBox(height: 8),
              Row(
                children: [
                  Container(
                    padding: EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                    decoration: BoxDecoration(
                      color: Colors.blue[700],
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Text(
                      card.genre.emoji,
                      style: TextStyle(fontSize: 12),
                    ),
                  ),
                  SizedBox(width: 8),
                  Container(
                    padding: EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                    decoration: BoxDecoration(
                      color: Colors.purple[700],
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Text(
                      card.archetype.emoji,
                      style: TextStyle(fontSize: 12),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildCurrentStats(AnimeCard card) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Текущая статистика',
          style: TextStyle(
            color: Colors.white,
            fontSize: 16,
            fontWeight: FontWeight.bold,
          ),
        ),
        SizedBox(height: 12),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceAround,
          children: [
            _buildStatItem('⚡ Сила', '${card.power}', Colors.yellow[600]!),
            _buildStatItem('❤️ Здоровье', '${card.hp}', Colors.red),
            _buildStatItem('🛡️ Защита', '${card.defense}', Colors.blue[300]!),
          ],
        ),
      ],
    );
  }

  Widget _buildUpgradeStats(AnimeCard card) {
    final upgradedStats = card.stats.copyWithUpgrade(card.level + 1);
    
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'После улучшения',
          style: TextStyle(
            color: Colors.green[400],
            fontSize: 16,
            fontWeight: FontWeight.bold,
          ),
        ),
        SizedBox(height: 12),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceAround,
          children: [
            _buildUpgradeStatItem(
              '⚡ Сила', 
              '${card.power}', 
              '${upgradedStats.power}',
              Colors.yellow[600]!
            ),
            _buildUpgradeStatItem(
              '❤️ Здоровье', 
              '${card.hp}', 
              '${upgradedStats.resonance}',
              Colors.red
            ),
            _buildUpgradeStatItem(
              '🛡️ Защита', 
              '${card.defense}', 
              '${upgradedStats.stability}',
              Colors.blue[300]!
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildStatItem(String label, String value, Color color) {
    return Column(
      children: [
        Text(
          label,
          style: TextStyle(
            color: Colors.grey[400],
            fontSize: 12,
          ),
        ),
        SizedBox(height: 4),
        Text(
          value,
          style: TextStyle(
            color: color,
            fontSize: 16,
            fontWeight: FontWeight.bold,
          ),
        ),
      ],
    );
  }

  Widget _buildUpgradeStatItem(
    String label, 
    String current, 
    String upgraded, 
    Color color
  ) {
    return Column(
      children: [
        Text(
          label,
          style: TextStyle(
            color: Colors.grey[400],
            fontSize: 12,
          ),
        ),
        SizedBox(height: 4),
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              current,
              style: TextStyle(
                color: Colors.grey[500],
                fontSize: 14,
                decoration: TextDecoration.lineThrough,
              ),
            ),
            SizedBox(width: 4),
            Icon(Icons.arrow_forward, color: Colors.green, size: 14),
            SizedBox(width: 4),
            Text(
              upgraded,
              style: TextStyle(
                color: color,
                fontSize: 16,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildUpgradeRequirements(
    int requiredDupes, 
    int availableDupes, 
    int cost, 
    bool canAfford
  ) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Требования для улучшения',
          style: TextStyle(
            color: Colors.white,
            fontSize: 16,
            fontWeight: FontWeight.bold,
          ),
        ),
        SizedBox(height: 12),
        _buildRequirementItem(
          'Дубликаты',
          '$availableDupes/$requiredDupes',
          availableDupes >= requiredDupes,
          Icons.content_copy,
        ),
        SizedBox(height: 8),
        _buildRequirementItem(
          'Монеты',
          '$cost',
          canAfford,
          Icons.monetization_on,
        ),
      ],
    );
  }

  Widget _buildRequirementItem(
    String label, 
    String value, 
    bool met, 
    IconData icon
  ) {
    return Container(
      padding: EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.grey[800],
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        children: [
          Icon(
            icon,
            color: met ? Colors.green : Colors.red,
          ),
          SizedBox(width: 12),
          Text(
            label,
            style: TextStyle(
              color: Colors.grey[300],
              fontSize: 14,
            ),
          ),
          Spacer(),
          Text(
            value,
            style: TextStyle(
              color: met ? Colors.green : Colors.red,
              fontSize: 14,
              fontWeight: FontWeight.bold,
            ),
          ),
          SizedBox(width: 8),
          Icon(
            met ? Icons.check_circle : Icons.error,
            color: met ? Colors.green : Colors.red,
            size: 16,
          ),
        ],
      ),
    );
  }

  Widget _buildUpgradeButton(bool canUpgrade, int cost) {
    return SizedBox(
      width: double.infinity,
      child: ElevatedButton(
        onPressed: canUpgrade ? onUpgrade : null,
        style: ElevatedButton.styleFrom(
          backgroundColor: canUpgrade ? Colors.green : Colors.grey[600],
          padding: EdgeInsets.symmetric(vertical: 16),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.auto_awesome,
              color: Colors.white,
            ),
            SizedBox(width: 8),
            Text(
              canUpgrade 
                ? 'Улучшить за $cost монет'
                : 'Недостаточно ресурсов',
              style: TextStyle(
                color: Colors.white,
                fontSize: 16,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
      ),
    );
  }
}