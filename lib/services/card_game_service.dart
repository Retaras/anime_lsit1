// services/card_game_service.dart
import 'dart:math';
import 'package:hive/hive.dart';
import '../models/anime_card.dart';

class CardGameService {
  static final Random _random = Random();

  // НОВЫЙ МЕТОД: Очистка всей коллекции
  static Future<void> clearAllCards() async {
    try {
      final box = await Hive.openBox('gameData');
      await box.clear();
      await box.put('coins', 100000);
      await box.put('playerLevel', 1);
      await box.put('playerExp', 0);
      await box.put('playerCollection', <Map<String, dynamic>>[]);
      await box.put('playerDeck', <String>[]);
    } catch (e) {
      print('Ошибка при очистке коллекции: $e');
      rethrow;
    }
  }

  // НОВЫЙ МЕТОД: Удаление карты по baseCardId
  static Future<bool> deleteCard(String baseCardId) async {
    try {
      final currentCollection = await getCollection();
      final updatedCollection = currentCollection.where(
        (card) => card.baseCardId != baseCardId
      ).toList();
      return await _saveCollection(updatedCollection);
    } catch (e) {
      print('Ошибка при удалении карты: $e');
      return false;
    }
  }

  // =========================================================================
  // --- СИСТЕМА КРАФТА С ВЫБОРОМ КОНКРЕТНЫХ КАРТ ---
  // =========================================================================

  /// Получает ВСЕ карты для крафта определенного типа
  static Future<List<AnimeCard>> getAllCardsForCraft(CraftType craftType) async {
    final collection = await getCollection();
    final requiredRarity = craftType.requiredRarity;
    
    // Создаем список, где каждая карта представлена столько раз, сколько у нее дубликатов
    final allCardsForCraft = <AnimeCard>[];
    
    for (final card in collection) {
      if (card.rarity == requiredRarity) {
        // Добавляем карту столько раз, сколько у нее дубликатов
        for (int i = 0; i < card.duplicateCount; i++) {
          allCardsForCraft.add(card);
        }
      }
    }
    
    return allCardsForCraft;
  }

  /// Выполняет крафт карт с использованием ВЫБРАННЫХ игроком карт
  static Future<AnimeCard> performCardCraft({
    required List<String> selectedCardIds,
    required CraftType craftType,
  }) async {
    try {
      final collection = await getCollection();
      final selectedCards = <AnimeCard>[];
      
      // Создаем карту для отслеживания использованных дубликатов
      final usedDuplicates = <String, int>{};
      
      // Обрабатываем выбранные карты
      for (final cardId in selectedCardIds) {
        // Находим оригинальную карту в коллекции
        final originalCard = collection.firstWhere(
          (c) => c.id == cardId,
          orElse: () => throw Exception('Карта с ID $cardId не найдена')
        );
        
        // Отмечаем использование дубликата
        usedDuplicates[originalCard.id] = (usedDuplicates[originalCard.id] ?? 0) + 1;
        selectedCards.add(originalCard);
      }

      // Проверяем редкость и количество
      final requiredRarity = craftType.requiredRarity;
      final requiredCount = craftType.requiredCardCount;
      
      for (final card in selectedCards) {
        if (card.rarity != requiredRarity) {
          throw Exception('Не все карты имеют нужную редкость ${requiredRarity.displayName}');
        }
      }

      if (selectedCards.length != requiredCount) {
        throw Exception('Нужно выбрать ровно $requiredCount карт для крафта');
      }

      // Обновляем коллекцию, уменьшая количество дубликатов
      final updatedCollection = <AnimeCard>[];
      for (final card in collection) {
        final usedCount = usedDuplicates[card.id] ?? 0;
        if (usedCount > 0) {
          // Если использовали все дубликаты - удаляем карту
          if (usedCount >= card.duplicateCount) {
            continue; // Пропускаем карту (удаляем её)
          } else {
            // Уменьшаем количество дубликатов
            updatedCollection.add(card.copyWith(
              duplicateCount: card.duplicateCount - usedCount,
            ));
          }
        } else {
          // Карта не использовалась - оставляем как есть
          updatedCollection.add(card);
        }
      }

      // Создаем новую карту
      final resultRarity = craftType.resultRarity;
      final craftedCard = _createCardFromSelectedCards(selectedCards, resultRarity);

      // Добавляем новую карту в коллекцию
      updatedCollection.add(craftedCard);

      // Сохраняем обновленную коллекцию
      await _saveCollection(updatedCollection);

      // Начисляем опыт за крафт
      await _addPlayerExp(50 * resultRarity.index);

      return craftedCard;
    } catch (e) {
      print('Ошибка при крафте карт: $e');
      rethrow;
    }
  }

  /// Автоматический крафт (случайный выбор карт)
  static Future<List<AnimeCard>> craftCards(CraftType type) async {
    try {
      final requiredRarity = type.requiredRarity;
      final availableCards = await getAllCardsForCraft(type);
      final requiredCount = type.requiredCardCount;
      
      if (availableCards.length < requiredCount) {
        throw Exception('Недостаточно карт ${requiredRarity.displayName} редкости');
      }

      final selectedCards = <AnimeCard>[];
      final shuffledCards = List<AnimeCard>.from(availableCards)..shuffle();
      
      for (int i = 0; i < requiredCount && i < shuffledCards.length; i++) {
        selectedCards.add(shuffledCards[i]);
      }

      final selectedCardIds = selectedCards.map((card) => card.id).toList();
      final resultCard = await performCardCraft(
        selectedCardIds: selectedCardIds,
        craftType: type,
      );

      return [resultCard];
    } catch (e) {
      print('Ошибка при автоматическом крафте: $e');
      rethrow;
    }
  }

  /// Создает карту на основе выбранных карт
  static AnimeCard _createCardFromSelectedCards(List<AnimeCard> selectedCards, CardRarity resultRarity) {
    // Вместо использования базовой карты из выбранных, создаем новую карту из соответствующего списка
    final availableCards = _getCardsByRarity(resultRarity);
    
    if (availableCards.isEmpty) {
      // Fallback: если нет карт нужной редкости, используем старую логику
      final baseCard = selectedCards[_random.nextInt(selectedCards.length)];
      final totalPower = selectedCards.fold(0, (sum, card) => sum + card.power);
      final averagePower = (totalPower / selectedCards.length).round();
      final bonusPower = (averagePower * resultRarity.powerMultiplier * 0.3).round();
      final finalPower = averagePower + bonusPower;

      return baseCard.copyWith(
        id: 'crafted_${DateTime.now().millisecondsSinceEpoch}_${_random.nextInt(10000)}',
        rarity: resultRarity,
        description: _generateCraftDescription(baseCard, selectedCards.length, resultRarity),
        level: 1,
        skill: _generateCraftSkill(baseCard, resultRarity),
        obtainedAt: DateTime.now(),
        stats: BattleStats.fromPower(finalPower),
        visuals: const CardVisuals(),
        duplicateCount: 1,
        baseCardId: 'crafted_${baseCard.baseCardId}',
      );
    }
    
    // Выбираем случайную карту из доступных карт нужной редкости
    final newCardTemplate = availableCards[_random.nextInt(availableCards.length)];
    
    // Рассчитываем улучшенную силу на основе выбранных карт
    final totalPower = selectedCards.fold(0, (sum, card) => sum + card.power);
    final averagePower = (totalPower / selectedCards.length).round();
    final bonusPower = (averagePower * resultRarity.powerMultiplier * 0.3).round();
    final finalPower = averagePower + bonusPower;
    
    // Создаем новую карту с уникальным ID
    return newCardTemplate.copyWith(
      id: 'crafted_${DateTime.now().millisecondsSinceEpoch}_${_random.nextInt(10000)}',
      description: _generateCraftDescription(newCardTemplate, selectedCards.length, resultRarity),
      skill: _generateCraftSkill(newCardTemplate, resultRarity),
      obtainedAt: DateTime.now(),
      stats: BattleStats.fromPower(finalPower),
      visuals: const CardVisuals(),
      duplicateCount: 1,
      baseCardId: 'crafted_${newCardTemplate.baseCardId}',
    );
  }

  static String _generateCraftDescription(AnimeCard baseCard, int cardsUsed, CardRarity resultRarity) {
    final rarityName = resultRarity.displayName.toLowerCase();
    return '${baseCard.characterName} в ${rarityName} форме. Создана из $cardsUsed карт с помощью древнего искусства крафта.';
  }

  static String _generateCraftSkill(AnimeCard baseCard, CardRarity resultRarity) {
    final baseSkill = baseCard.skill;
    switch (resultRarity) {
      case CardRarity.rare: return 'Улучшенный $baseSkill';
      case CardRarity.epic: return 'Мощный $baseSkill';
      case CardRarity.legendary: return 'Легендарный $baseSkill';
      case CardRarity.mythic: return 'Мифический $baseSkill';
      default: return baseSkill;
    }
  }

  // =========================================================================
  // --- СИСТЕМА УЛУЧШЕНИЯ С ДУБЛИКАТАМИ ---
  // =========================================================================

  static Future<void> upgradeCard(AnimeCard card) async {
    try {
      if (!card.canUpgrade) {
        throw Exception('Недостаточно дубликатов для улучшения');
      }

      final collection = await getCollection();
      final cardIndex = collection.indexWhere((c) => c.id == card.id);
      if (cardIndex == -1) {
        throw Exception('Карта не найдена в коллекции');
      }

      final upgradedCard = card.copyWithUpgrade();
      collection[cardIndex] = upgradedCard;
      await _saveCollection(collection);
      await _addPlayerExp(card.upgradeCost ~/ 5);
    } catch (e) {
      print('Ошибка при улучшении карты: $e');
      rethrow;
    }
  }

  static Future<List<CardGroup>> getCardGroups() async {
    final collection = await getCollection();
    final groups = <String, CardGroup>{};

    for (final card in collection) {
      final baseCardId = card.baseCardId;
      
      if (!groups.containsKey(baseCardId)) {
        groups[baseCardId] = CardGroup(
          baseCardId: baseCardId,
          baseCard: card,
          duplicates: [],
        );
      } else {
        final group = groups[baseCardId]!;
        if (card.level == group.baseCard.level) {
          groups[baseCardId] = CardGroup(
            baseCardId: group.baseCardId,
            baseCard: group.baseCard.copyWith(
              duplicateCount: group.baseCard.duplicateCount + 1,
            ),
            duplicates: group.duplicates,
          );
        } else {
          group.duplicates.add(card);
        }
      }
    }

    return groups.values.toList();
  }

  // =========================================================================
  // --- БАЗОВЫЕ КАРТЫ ДЛЯ КОЛЛЕКЦИИ ---
  // =========================================================================

  static AnimeCard _createCard({
    required String id,
    required String characterName,
    required String animeName,
    required String imageUrl,
    required CardRarity rarity,
    required int power,
    required String description,
    required int level,
    required int hp,
    required int mp,
    required String skill,
    required String quote,
  }) {
    final random = Random(id.hashCode);
    return AnimeCard(
      id: id,
      characterName: characterName,
      animeName: animeName,
      imageUrl: imageUrl,
      rarity: rarity,
      description: description,
      level: level,
      skill: skill,
      quote: quote,
      obtainedAt: DateTime.now(),
      genre: AnimeGenre.values[random.nextInt(AnimeGenre.values.length)],
      archetype: CharacterArchetype.values[random.nextInt(CharacterArchetype.values.length)],
      abilityType: AbilityType.values[random.nextInt(AbilityType.values.length)],
      stats: BattleStats.fromPower(power),
      duplicateCount: 1,
      baseCardId: id,
    );
  }

 // 🟢 Обычные карты (50% шанс выпадения)
static final List<AnimeCard> _commonCards = [
  _createCard(
    id: 'c_001', 
    characterName: 'Мадока Канаме', 
    animeName: 'Puella Magi Madoka Magica', 
    imageUrl: 'https://shikimori.one/uploads/poster/characters/37832/main-c5abcfdc6a354327274dc5ec14b676aa.webp', 
    rarity: CardRarity.common, 
    power: 35, 
    level: 1, 
    hp: 80, 
    mp: 50, 
    skill: 'Скрытый потенциал', 
    description: 'Обычная школьница с огромным магическим потенциалом.', 
    quote: 'Если кто-то скажет мне, что надеяться — ошибка, я отвечу, что он неправ.'
  ),
  _createCard(
    id: 'c_002', 
    characterName: 'Кофуку', 
    animeName: 'Noragami', 
    imageUrl: 'https://shikimori.one/uploads/poster/characters/92851/main-651215a7a4224d345f437b4664bd8e0c.webp', 
    rarity: CardRarity.common, 
    power: 38, 
    level: 1, 
    hp: 85, 
    mp: 45, 
    skill: 'Богиня нищеты', 
    description: 'Выглядит как весёлая девушка, но на самом деле является богиней, приносящей несчастья.', 
    quote: 'Такова уж моя природа — сеять хаос и разрушения!'
  ),
  _createCard(
    id: 'c_003', 
    characterName: 'Холо', 
    animeName: 'Spice and Wolf', 
    imageUrl: 'https://shikimori.one/uploads/poster/characters/7373/main-89991c87e75c604f654d2e4be932e21f.webp', 
    rarity: CardRarity.common, 
    power: 40, 
    level: 1, 
    hp: 90, 
    mp: 60, 
    skill: 'Мудрая волчица', 
    description: 'Богиня урожая в облике юной девушки с волчьими ушами и хвостом.', 
    quote: 'Одиночество — это болезнь, ведущая к смерти.'
  ),
  _createCard(
    id: 'c_004', 
    characterName: 'Сиро', 
    animeName: 'No Game No Life', 
    imageUrl: 'https://shikimori.one/uploads/poster/characters/82525/main-286b0cb25e4eb06aaac9c468a020c929.webp', 
    rarity: CardRarity.common, 
    power: 42, 
    level: 1, 
    hp: 85, 
    mp: 70, 
    skill: 'Гениальный интеллект', 
    description: 'Гениальная девочка-геймер, которая вместе с братом составляет непобедимую команду.', 
    quote: 'В шахматах, как и в жизни, нельзя отменить свой ход.'
  ),
  _createCard(
    id: 'c_005', 
    characterName: 'Таки Тачибана', 
    animeName: 'Your Name', 
    imageUrl: 'https://shikimori.one/uploads/poster/characters/136805/main-030bdd3986eeabcedb815f4ff1eb1ef4.webp', 
    rarity: CardRarity.common, 
    power: 34, 
    level: 1, 
    hp: 75, 
    mp: 50, 
    skill: 'Поиски связи', 
    description: 'Старшеклассник из Токио, чья жизнь таинственным образом переплетается с девушкой из провинции.', 
    quote: 'Я ищу тебя, кого совсем не знаю.'
  ),
  _createCard(
    id: 'c_006', 
    characterName: 'Каори Миядзоно', 
    animeName: 'Your Lie in April', 
    imageUrl: 'https://shikimori.one/uploads/poster/characters/69411/main-c8ce7dcb66045e686ef1fa9c6f43e9fb.webp', 
    rarity: CardRarity.common, 
    power: 36, 
    level: 1, 
    hp: 80, 
    mp: 55, 
    skill: 'Музыкальное вдохновение', 
    description: 'Талантливая и эксцентричная скрипачка, которая меняет жизнь главного героя.', 
    quote: 'Музыка — это свобода.'
  ),
  _createCard(
    id: 'c_007', 
    characterName: 'Тайга Айсака', 
    animeName: 'Toradora!', 
    imageUrl: 'https://shikimori.one/uploads/poster/characters/12064/main-23cb3baf7873e1571ad1cc97fa848ef7.webp', 
    rarity: CardRarity.common, 
    power: 39, 
    level: 1, 
    hp: 85, 
    mp: 50, 
    skill: 'Карманный тигр', 
    description: 'Маленькая, но очень вспыльчивая девушка, известная своей свирепостью.', 
    quote: 'Счастье можно обрести, только если оно для всех.'
  ),
  _createCard(
    id: 'c_008', 
    characterName: 'Хината Кавамото', 
    animeName: 'March Comes in Like a Lion', 
    imageUrl: 'https://shikimori.one/uploads/poster/characters/24312/main-888523d0e82645d5ece95de4e1ba3f19.webp', 
    rarity: CardRarity.common, 
    power: 33, 
    level: 1, 
    hp: 70, 
    mp: 45, 
    skill: 'Искреннее сострадание', 
    description: 'Добрая и отзывчивая школьница, которая поддерживает главного героя в трудные времена.', 
    quote: 'Я не хочу, чтобы о моих ошибках сожалел кто-то другой.'
  ),
  _createCard(
    id: 'c_009', 
    characterName: 'Чизуру Хиширо', 
    animeName: 'ReLIFE', 
    imageUrl: 'https://shikimori.one/uploads/poster/characters/127643/main-ac83860468391ac6fcca277ee686701d.webp', 
    rarity: CardRarity.common, 
    power: 35, 
    level: 1, 
    hp: 75, 
    mp: 50, 
    skill: 'Социальная адаптация', 
    description: 'Умная, но социально неловкая девушка, участвующая в эксперименте по "перепрохождению" школьной жизни.', 
    quote: 'Неужели так сложно просто улыбнуться?'
  ),
  _createCard(
    id: 'c_010', 
    characterName: 'Каё Хинадзуки', 
    animeName: 'Erased', 
    imageUrl: 'https://shikimori.one/uploads/poster/characters/126756/main-fc7562836023d6b2ea5449a444ef78a7.webp', 
    rarity: CardRarity.common, 
    power: 37, 
    level: 1, 
    hp: 80, 
    mp: 55, 
    skill: 'Одинокое сердце', 
    description: 'Одноклассница главного героя, чью трагическую судьбу он пытается предотвратить.', 
    quote: 'Ты не притворяешься, да? Спасибо.'
  ),
  _createCard(
    id: 'c_011', 
    characterName: 'Нао Томори', 
    animeName: 'Charlotte', 
    imageUrl: 'https://shikimori.one/uploads/poster/characters/122211/main-2a7a8dc98b588c75a80ff2c9a09f7e8d.webp', 
    rarity: CardRarity.common, 
    power: 36, 
    level: 1, 
    hp: 75, 
    mp: 60, 
    skill: 'Невидимость', 
    description: 'Президент студсовета и обладательница способности становиться невидимой для одного человека.', 
    quote: 'Счастье, которое мы испытываем, всегда омрачено чьей-то жертвой.'
  ),
  _createCard(
    id: 'c_012', 
    characterName: 'Тору Хонда', 
    animeName: 'Fruits Basket', 
    imageUrl: 'https://shikimori.one/uploads/poster/characters/207/main-2e2d59461860e601a6e461370e9ba7d7.webp', 
    rarity: CardRarity.common, 
    power: 34, 
    level: 1, 
    hp: 70, 
    mp: 50, 
    skill: 'Доброта и принятие', 
    description: 'Сирота, которая случайно узнаёт тайну проклятой семьи Сома и начинает жить с ними.', 
    quote: 'Даже когда небо затянуто тучами, за ними всегда есть солнце.'
  ),
  _createCard(
    id: 'c_013', 
    characterName: 'Мэйко Хомма (Мэнма)', 
    animeName: 'Anohana', 
    imageUrl: 'https://shikimori.one/uploads/poster/characters/40592/main-514e74340e812172b8b5df16acac20e2.webp', 
    rarity: CardRarity.common, 
    power: 35, 
    level: 1, 
    hp: 75, 
    mp: 55, 
    skill: 'Связь с прошлым', 
    description: 'Дух погибшей в детстве девочки, которая возвращается, чтобы исполнить своё желание.', 
    quote: 'Ты нашёл меня!'
  ),
  _createCard(
    id: 'c_014', 
    characterName: 'Нагиса Фурукава', 
    animeName: 'Clannad', 
    imageUrl: 'https://shikimori.one/uploads/poster/characters/4604/main-f477364bdd64083bf0065cfdf2261b27.webp', 
    rarity: CardRarity.common, 
    power: 33, 
    level: 1, 
    hp: 70, 
    mp: 45, 
    skill: 'Театральный кружок', 
    description: 'Робкая, но целеустремлённая девушка, мечтающая возродить школьный театральный кружок.', 
    quote: 'Никогда не сдавайся на пути к мечте.'
  ),
  _createCard(
    id: 'c_015', 
    characterName: 'Нана Осаки', 
    animeName: 'Nana', 
    imageUrl: 'https://shikimori.one/uploads/poster/characters/702/main-94ec4210e516f6879e1a4a556ef2a3c5.webp', 
    rarity: CardRarity.common, 
    power: 37, 
    level: 1, 
    hp: 80, 
    mp: 55, 
    skill: 'Панк-рок душа', 
    description: 'Вокалистка панк-группы "Black Stones", стремящаяся к славе в Токио.', 
    quote: 'Люди говорят "мечты сбываются", но на самом деле они их сами осуществляют.'
  ),
  _createCard(
    id: 'c_016', 
    characterName: 'Юи Хирасава', 
    animeName: 'K-On!', 
    imageUrl: 'https://shikimori.one/uploads/poster/characters/19565/main-199f58d04ab6f3be7d618fc8fed54a98.webp', 
    rarity: CardRarity.common, 
    power: 36, 
    level: 1, 
    hp: 75, 
    mp: 50, 
    skill: 'Гитарное вдохновение', 
    description: 'Беззаботная и весёлая гитаристка школьной музыкальной группы "Ho-kago Tea Time".', 
    quote: 'Весёлые вещи — это весело!'
  ),
  _createCard(
    id: 'c_017', 
    characterName: 'Томоя Окадзаки', 
    animeName: 'Clannad', 
    imageUrl: 'https://shikimori.one/uploads/poster/characters/4606/main-44c53d687b2788c5b748f5905fe2ce09.webp', 
    rarity: CardRarity.common, 
    power: 38, 
    level: 1, 
    hp: 85, 
    mp: 50, 
    skill: 'Преодоление себя', 
    description: 'Хулиган, который находит новый смысл жизни после встречи с Нагисой.', 
    quote: 'Если бы можно было повернуть время вспять...'
  ),
  _createCard(
    id: 'c_018', 
    characterName: 'Ятора Ягучи', 
    animeName: 'Blue Period', 
    imageUrl: 'https://shikimori.one/uploads/poster/characters/174463/main-180ed4897f1a7bcde80af1f6e7ce6fc5.webp', 
    rarity: CardRarity.common, 
    power: 39, 
    level: 1, 
    hp: 85, 
    mp: 55, 
    skill: 'Художественное выражение', 
    description: 'Прилежный ученик, который внезапно открывает для себя страсть к рисованию.', 
    quote: 'Мне нравится рисовать, потому что это единственный честный способ общения.'
  ),
  _createCard(
    id: 'c_019', 
    characterName: 'Кумико Омаэ', 
    animeName: 'Sound! Euphonium', 
    imageUrl: 'https://shikimori.one/uploads/poster/characters/120015/main-c63d76a1f1a932f11a39d78d90caa0a5.webp', 
    rarity: CardRarity.common, 
    power: 35, 
    level: 1, 
    hp: 75, 
    mp: 50, 
    skill: 'Музыкальная дисциплина', 
    description: 'Ученица, играющая на эуфониуме в школьном духовом оркестре.', 
    quote: 'Я хочу стать лучше!'
  ),
  _createCard(
    id: 'c_020', 
    characterName: 'Нару Котоиси', 
    animeName: 'Barakamon', 
    imageUrl: 'https://shikimori.one/uploads/poster/characters/31273/main-aef25dbd352cb1ce6e5ebe03c6aa49da.webp', 
    rarity: CardRarity.common, 
    power: 34, 
    level: 1, 
    hp: 70, 
    mp: 50, 
    skill: 'Детская непосредственность', 
    description: 'Энергичная деревенская девочка, которая помогает каллиграфу найти вдохновение.', 
    quote: 'Всё, что сделано с улыбкой, — хорошо!'
  ),
  _createCard(
    id: 'c_021',
    characterName: 'Косэй Арима',
    animeName: 'Your Lie in April',
    imageUrl: 'https://shikimori.one/uploads/poster/characters/69407/main-2ff4a4681519216e23a7c948132b89b0.webp',
    rarity: CardRarity.common,
    power: 65,
    level: 1,
    hp: 140,
    mp: 100,
    skill: 'Пианист',
    description: 'Талантливый пианист, потерявший способность слышать свою музыку после трагедии.',
    quote: 'Музыка... она перестала иметь цвет.'
),
_createCard(
    id: 'c_022',
    characterName: 'Цубаки Савабэ',
    animeName: 'Your Lie in April',
    imageUrl: 'https://shikimori.one/uploads/poster/characters/69409/main-156b664935f58a8d623a70a5079a5bb1.webp',
    rarity: CardRarity.common,
    power: 68,
    level: 1,
    hp: 145,
    mp: 95,
    skill: 'Скрипачка',
    description: 'Детская подруга Косэи, поддерживающая его на протяжении многих лет.',
    quote: 'Я всегда буду рядом, Косэй.'
),
_createCard(
    id: 'c_023',
    characterName: 'Рёта Ватари',
    animeName: 'Your Lie in April',
    imageUrl: 'https://shikimori.one/uploads/poster/characters/69405/main-be34b8c81985934f3de30a09e7a677c5.webp',
    rarity: CardRarity.common,
    power: 70,
    level: 1,
    hp: 150,
    mp: 90,
    skill: 'Бейсболист',
    description: 'Лучший друг Косэи, жизнерадостный и легкомысленный парень.',
    quote: 'Эй, давай повеселимся!'
),
_createCard(
    id: 'c_024',
    characterName: 'Маюри Сиина',
    animeName: 'Steins;Gate',
    imageUrl: 'https://shikimori.one/uploads/poster/characters/35253/main-8a2a31fe43eed1518b6a2a9fcda801ae.webp',
    rarity: CardRarity.common,
    power: 60,
    level: 1,
    hp: 130,
    mp: 95,
    skill: 'Туттуру!',
    description: 'Добрая и наивная девушка, "зарядка" для сердца Окарина.',
    quote: 'Туттуру рун!'
),
_createCard(
    id: 'c_025',
    characterName: 'Итару "Дару" Хасида',
    animeName: 'Steins;Gate',
    imageUrl: 'https://shikimori.one/uploads/poster/characters/35258/main-f7deb4788f8da2273763250ead8ca275.webp',
    rarity: CardRarity.common,
    power: 68,
    level: 1,
    hp: 145,
    mp: 105,
    skill: 'Супер-хакер',
    description: 'Гениальный хакер и лучший друг Окарина, отаку до мозга костей.',
    quote: 'Это было сработкой Джона Титтора!'
),
_createCard(
    id: 'c_026',
    characterName: 'Легоши',
    animeName: 'Beastars',
    imageUrl: 'https://shikimori.one/uploads/poster/characters/151138/main-d8a9045b25cec7f81aa5bf20ba40a11e.webp',
    rarity: CardRarity.common,
    power: 74,
    level: 1,
    hp: 155,
    mp: 90,
    skill: 'Волк',
    description: 'Старшеклассник-волк, пытающийся подавить свои хищные инстинкты.',
    quote: 'Я не хочу причинять вреда никому.'
),
_createCard(
    id: 'c_027',
    characterName: 'Луи',
    animeName: 'Beastars',
    imageUrl: 'https://shikimori.one/uploads/poster/characters/164219/main-7e7e40db91463f95a6fdb681579e84c7.webp',
    rarity: CardRarity.common,
    power: 71,
    level: 1,
    hp: 150,
    mp: 95,
    skill: 'Олень',
    description: 'Харизматичный лидер драмкружка, скрывающий свои истинные чувства.',
    quote: 'В этом мире есть правила, которые мы не можем нарушать.'
),
_createCard(
    id: 'c_029',
    characterName: 'Хару',
    animeName: 'Beastars',
    imageUrl: 'https://shikimori.one/uploads/poster/characters/165850/main-77ad0c9666f4a050d705d036773c767b.webp',
    rarity: CardRarity.common,
    power: 66,
    level: 1,
    hp: 140,
    mp: 95,
    skill: 'Кролик',
    description: 'Смелая и независимая девушка-кролик, ставшая центром многих событий.',
    quote: 'Я не боюсь тебя.'
),
_createCard(
    id: 'c_030',
    characterName: 'Усио Окадзаки',
    animeName: 'Clannad',
    imageUrl: 'https://shikimori.one/uploads/poster/characters/10342/main-9cab3ca88ba746a7ae3ca5e19f2c687c.webp',
    rarity: CardRarity.common,
    power: 64,
    level: 1,
    hp: 135,
    mp: 100,
    skill: 'Драматург',
    description: 'Мать Нагисы, чья история стала основой для пьесы.',
    quote: 'Я всегда буду любить тебя, Нагиса.'
),
_createCard(
    id: 'c_031',
    characterName: 'Кацухико Тэсигавара',
    animeName: 'Your Name',
    imageUrl: 'https://shikimori.one/uploads/poster/characters/141480/main-9d797ec1220f6bc628a73a395b2b5bbb.webp',
    rarity: CardRarity.common,
    power: 67,
    level: 1,
    hp: 140,
    mp: 95,
    skill: 'Старший друг',
    description: 'Старший друг Таки, помогающий ему в работе в ресторане.',
    quote: 'Таки, ты опять работаешь слишком много.'
),
_createCard(
    id: 'c_032',
    characterName: 'Саяка Натори',
    animeName: 'Your Name',
    imageUrl: 'https://shikimori.one/uploads/poster/characters/141481/main-503057cf3ff6485521cf0c0927d461c2.webp',
    rarity: CardRarity.common,
    power: 65,
    level: 1,
    hp: 135,
    mp: 100,
    skill: 'Подруга Мицухи',
    description: 'Лучшая подруга Мицухи, поддерживающая ее во всех начинаниях.',
    quote: 'Мицуха, ты сегодня такая красивая!'
),
_createCard(
    id: 'c_033',
    characterName: 'Тихиро Огино',
    animeName: 'Spirited Away',
    imageUrl: 'https://shikimori.one/uploads/poster/characters/384/main-4052f4bad050abc6c9465e9e10f4c7ae.webp',
    rarity: CardRarity.common,
    power: 62,
    level: 1,
    hp: 130,
    mp: 95,
    skill: 'Человеческая девочка',
    description: 'Девочка, попавшая в мир духов и вынужденная работать в бане, чтобы спасти родителей.',
    quote: 'Я не боюсь тебя!'
),
_createCard(
    id: 'c_034',
    characterName: 'Хаку',
    animeName: 'Spirited Away',
    imageUrl: 'https://shikimori.one/uploads/poster/characters/385/main-6e49001b9aa96eba5b3dc43682b46469.webp',
    rarity: CardRarity.common,
    power: 75,
    level: 1,
    hp: 150,
    mp: 100,
    skill: 'Дракон-река',
    description: 'Мальчик-дух, помогающий Тихиро выжить в мире духов.',
    quote: 'Я помогу тебе. Просто помни мое имя.'
),
_createCard(
    id: 'c_035',
    characterName: 'Лин',
    animeName: 'Spirited Away',
    imageUrl: 'https://shikimori.one/uploads/poster/characters/17906/main-85897bf100f81eedc6559c02a32cb4d9.webp',
    rarity: CardRarity.common,
    power: 70,
    level: 1,
    hp: 145,
    mp: 95,
    skill: 'Парень-крыса',
    description: 'Парень-дух, работающий вместе с Тихиро и ставший ее другом.',
    quote: 'Юбаба очень злая, но она не всегда такой была.'
),
_createCard(
    id: 'c_036',
    characterName: 'Каонаси',
    animeName: 'Spirited Away',
    imageUrl: 'https://shikimori.one/uploads/poster/characters/8298/main-fce78d1cbe0517e8f4e0f925440569b0.webp',
    rarity: CardRarity.common,
    power: 73,
    level: 1,
    hp: 155,
    mp: 90,
    skill: 'Безликий дух',
    description: 'Загадочный дух, поглощающий других и обретающий облик благодаря Тихиро.',
    quote: '*Глотает gold*'
),
_createCard(
    id: 'c_037',
    characterName: 'Сёя Исида',
    animeName: 'A Silent Voice',
    imageUrl: 'https://shikimori.one/uploads/poster/characters/80491/main-e76bce1876c8fee4bdd5e76942fadabe.webp',
    rarity: CardRarity.common,
    power: 66,
    level: 1,
    hp: 140,
    mp: 95,
    skill: 'Искупление',
    description: 'Юноша, пытающийся искупить вину за травлю глухой девочки в детстве.',
    quote: 'Я хочу снова поговорить с ней.'
),
_createCard(
    id: 'c_038',
    characterName: 'Сёко Нисимия',
    animeName: 'A Silent Voice',
    imageUrl: 'https://shikimori.one/uploads/poster/characters/80243/main-4eb10b0682a5437b273ac371646a86f3.webp',
    rarity: CardRarity.common,
    power: 63,
    level: 1,
    hp: 135,
    mp: 100,
    skill: 'Жесты',
    description: 'Добрая глухая девушка, научившаяся прощать.',
    quote: 'Я хотела бы подружиться со всеми.'
),
_createCard(
    id: 'c_039',
    characterName: 'Наока Уэно',
    animeName: 'A Silent Voice',
    imageUrl: 'https://shikimori.one/uploads/poster/characters/97583/main-0cf58e2f926ccf665e9e2e1f4a322011.webp',
    rarity: CardRarity.common,
    power: 67,
    level: 1,
    hp: 145,
    mp: 90,
    skill: 'Популярная',
    description: 'Девочка, участвовавшая в травле, но позже осознающая свою вину.',
    quote: 'Я... я не знаю, что мне делать.'
),
_createCard(
    id: 'c_040',
    characterName: 'Томохиро Нагацука',
    animeName: 'A Silent Voice',
    imageUrl: 'https://shikimori.one/uploads/poster/characters/95817/main-80b1763fa0faa1e0c3b133e76605ded8.webp',
    rarity: CardRarity.common,
    power: 69,
    level: 1,
    hp: 150,
    mp: 95,
    skill: 'Друг',
    description: 'Единственный друг Сёи, поддерживающий его в трудные времена.',
    quote: 'Давай создадим фильм вместе!'
),
_createCard(
    id: 'c_041',
    characterName: 'Сёко Коми',
    animeName: 'Komi Can\'t Communicate',
    imageUrl: 'https://shikimori.one/uploads/poster/characters/141790/main-ec17d99d1f9a8a6927b07f9165ad3020.webp',
    rarity: CardRarity.common,
    power: 61,
    level: 1,
    hp: 125,
    mp: 100,
    skill: 'Тревожность',
    description: 'Красивая и популярная девушка, страдающая от социофобии и мечтающая о 100 друзьях.',
    quote: '...'
),
_createCard(
    id: 'c_042',
    characterName: 'Тадано Хитохито',
    animeName: 'Komi Can\'t Communicate',
    imageUrl: 'https://shikimori.one/uploads/poster/characters/151722/main-82d2e9ff34b3b57abf5c3b35a35905d3.webp',
    rarity: CardRarity.common,
    power: 64,
    level: 1,
    hp: 135,
    mp: 95,
    skill: 'Средний',
    description: 'Парень, первым понявший проблему Коми и решивший помочь ей.',
    quote: 'Я просто обычный парень.'
),
_createCard(
    id: 'c_047',
    characterName: 'Хидэёши Нагачика',
    animeName: 'Tokyo Ghoul',
    imageUrl: 'https://shikimori.one/uploads/poster/characters/103415/main-51641e39e416291f39ac3d2f5b214e19.webp',
    rarity: CardRarity.common,
    power: 67,
    level: 1,
    hp: 140,
    mp: 95,
    skill: 'Лучший друг',
    description: 'Лучший друг Канеки, который всегда его поддерживал и искал.',
    quote: 'Канеки, где ты? Я найду тебя.'
),
];


  // 🔵 Редкие карты (25% шанс выпадения)
  static final List<AnimeCard> _rareCards = [
  _createCard(
    id: 'r_001', 
    characterName: 'Мицуха Миямидзу', 
    animeName: 'Your Name', 
    imageUrl: 'https://shikimori.one/uploads/poster/characters/137467/main-2c1a7b7d47924eca700d1001c172fea9.webp', 
    rarity: CardRarity.rare, 
    power: 60, 
    level: 2, 
    hp: 120, 
    mp: 80, 
    skill: 'Связь сквозь время', 
    description: 'Девушка из провинции, чья жизнь переплетается с парнем из Токио.', 
    quote: 'Утром, открывая глаза, я почему-то плачу.'
  ),
  _createCard(
    id: 'r_002', 
    characterName: 'Дзинта Ядоми', 
    animeName: 'Anohana', 
    imageUrl: 'https://shikimori.one/uploads/poster/characters/40591/main-9edecfc563ce1c630582b8fc3140259a.webp', 
    rarity: CardRarity.rare, 
    power: 58, 
    level: 2, 
    hp: 110, 
    mp: 75, 
    skill: 'Примирение с прошлым', 
    description: 'Бывший лидер детской компании друзей, который замкнулся в себе после смерти Мэнмы.', 
    quote: 'Я думал, что смогу всё исправить завтра. Но это "завтра" так и не наступило.'
  ),
  _createCard(
    id: 'r_003', 
    characterName: 'Кё Сома', 
    animeName: 'Fruits Basket', 
    imageUrl: 'https://shikimori.one/uploads/poster/characters/209/main-ffd52e743ee7ff3e26e07f792471d3e7.webp', 
    rarity: CardRarity.rare, 
    power: 55, 
    level: 2, 
    hp: 105, 
    mp: 70, 
    skill: 'Проклятие кота', 
    description: 'Член семьи Сома, проклятый духом кота из китайского зодиака.', 
    quote: 'Я хочу верить, что даже такому, как я, есть место в этом мире.'
  ),
  _createCard(
    id: 'r_004', 
    characterName: 'Арата Кайдзаки', 
    animeName: 'ReLIFE', 
    imageUrl: 'https://shikimori.one/uploads/poster/characters/123703/main-dbc79269843cbaae0a4ac668278cb969.webp', 
    rarity: CardRarity.rare, 
    power: 57, 
    level: 2, 
    hp: 110, 
    mp: 75, 
    skill: 'Второй шанс', 
    description: '27-летний безработный, который получает шанс пережить год старшей школы заново.', 
    quote: 'Жизнь нельзя начать сначала. Но можно изменить её хос.'
  ),
  _createCard(
    id: 'r_005', 
    characterName: 'Сакура Киномото', 
    animeName: 'Cardcaptor Sakura', 
    imageUrl: 'https://shikimori.one/uploads/poster/characters/2671/main-467491c2d9270928a5e5caa7c530d240.webp', 
    rarity: CardRarity.rare, 
    power: 59, 
    level: 2, 
    hp: 115, 
    mp: 80, 
    skill: 'Ловец карт', 
    description: 'Девочка, случайно освободившая магические карты и теперь должна их собрать.', 
    quote: 'Всё обязательно будет хорошо!'
  ),
  _createCard(
    id: 'r_006', 
    characterName: 'Тамако Китасиракава', 
    animeName: 'Tamako Market', 
    imageUrl: 'https://shikimori.one/uploads/poster/characters/74850/main-655c90a08a0e0b27637718dfc1fb1558.webp', 
    rarity: CardRarity.rare, 
    power: 54, 
    level: 2, 
    hp: 105, 
    mp: 70, 
    skill: 'Мастер моти', 
    description: 'Весёлая девочка, помогающая своей семье в магазине традиционных сладостей моти.', 
    quote: 'Каждый день — это маленькое приключение!'
  ),
  _createCard(
    id: 'r_007', 
    characterName: 'Манака Мукаидо', 
    animeName: 'Nagi no Asukara', 
    imageUrl: 'https://shikimori.one/uploads/poster/characters/73065/main-d446bb8f0017e7e3f04d7c587cf1fe98.webp', 
    rarity: CardRarity.rare, 
    power: 56, 
    level: 2, 
    hp: 110, 
    mp: 75, 
    skill: 'Морская гармония', 
    description: 'Неуклюжая, но добрая девочка из подводной деревни, которая вынуждена учиться на суше.', 
    quote: 'Мир огромен, и мы — часть его.'
  ),
  _createCard(
    id: 'r_008', 
    characterName: 'Кэйма Кацураги', 
    animeName: 'The World God Only Knows', 
    imageUrl: 'https://shikimori.one/uploads/poster/characters/13468/main-4f124bc3b1243dc9946d819b14948080.webp', 
    rarity: CardRarity.rare, 
    power: 57, 
    level: 2, 
    hp: 115, 
    mp: 80, 
    skill: 'Бог-геймер', 
    description: 'Мастер симуляторов свиданий, который должен применять свои навыки для захвата сбежавших душ.', 
    quote: 'Я уже вижу концовку.'
  ),
  _createCard(
    id: 'r_009', 
    characterName: 'Рюдзи Аюкава', 
    animeName: 'Blue Period', 
    imageUrl: 'https://shikimori.one/uploads/poster/characters/174462/main-a911fe1f51af92ab50df56b7b33973c7.webp', 
    rarity: CardRarity.rare, 
    power: 55, 
    level: 2, 
    hp: 110, 
    mp: 75, 
    skill: 'Самовыражение', 
    description: 'Талантливый художник, который одевается в женскую одежду и ищет свой путь в искусстве.', 
    quote: 'Искусство — это зеркало души.'
  ),
  _createCard(
    id: 'r_010', 
    characterName: 'Мио Акияма', 
    animeName: 'K-On!', 
    imageUrl: 'https://shikimori.one/uploads/poster/characters/19566/main-fa9365366553c7eb33be07f81c297ce4.webp', 
    rarity: CardRarity.rare, 
    power: 56, 
    level: 2, 
    hp: 115, 
    mp: 80, 
    skill: 'Бас-гитаристка', 
    description: 'Серьёзная и застенчивая бас-гитаристка группы "Ho-kago Tea Time".', 
    quote: 'Я не боюсь сцены! ...Очень боюсь!'
  ),
  _createCard(
    id: 'r_011', 
    characterName: 'Котоми Итиносэ', 
    animeName: 'Clannad', 
    imageUrl: 'https://shikimori.one/uploads/poster/characters/4602/main-b29a6a73e2598bbac7bcb553043306f2.webp', 
    rarity: CardRarity.rare, 
    power: 54, 
    level: 2, 
    hp: 105, 
    mp: 75, 
    skill: 'Гениальность и скрипка', 
    description: 'Гениальная, но замкнутая девушка, которая проводит всё время в библиотеке.', 
    quote: 'Мир полон прекрасных вещей, которые мы ещё не видели.'
  ),
  _createCard(
    id: 'r_012', 
    characterName: 'Рей Аянами', 
    animeName: 'Neon Genesis Evangelion', 
    imageUrl: 'https://shikimori.one/uploads/poster/characters/86/main-5ce18dbad76a447cd5716f92f648009f.webp', 
    rarity: CardRarity.rare, 
    power: 59, 
    level: 2, 
    hp: 120, 
    mp: 85, 
    skill: 'Пилот Евы-00', 
    description: 'Загадочная и молчаливая девушка, первый пилот Евангелиона.', 
    quote: 'Человек не может жить без других людей.'
  ),
  _createCard(
    id: 'r_013', 
    characterName: 'Рэй Кирияма', 
    animeName: 'March Comes in Like a Lion', 
    imageUrl: 'https://shikimori.one/uploads/poster/characters/21044/main-a7f16e831510847f326478b127732ed8.webp', 
    rarity: CardRarity.rare, 
    power: 58, 
    level: 2, 
    hp: 115, 
    mp: 80, 
    skill: 'Стратег сёги', 
    description: 'Юный профессиональный игрок в сёги, борющийся с одиночеством и депрессией.', 
    quote: 'Я должен продолжать идти вперёд, даже если не знаю куда.'
  ),
  _createCard(
    id: 'r_014', 
    characterName: 'Рин Тосака', 
    animeName: 'Fate/stay night', 
    imageUrl: 'https://shikimori.one/uploads/poster/characters/498/main-e669c104a93dc72a029d8183be953740.webp', 
    rarity: CardRarity.rare, 
    power: 60, 
    level: 2, 
    hp: 115, 
    mp: 85, 
    skill: 'Мастер-маг', 
    description: 'Решительная и талантливая волшебница из древнего рода, участвующая в Войне Святого Грааля.', 
    quote: 'Нет смысла в победе, если ты не можешь гордиться ей.'
  ),
  _createCard(
    id: 'r_015', 
    characterName: 'Рэйна Косака', 
    animeName: 'Sound! Euphonium', 
    imageUrl: 'https://shikimori.one/uploads/poster/characters/120017/main-8dd7724358f912a3469651c0c236056e.webp', 
    rarity: CardRarity.rare, 
    power: 56, 
    level: 2, 
    hp: 110, 
    mp: 75, 
    skill: 'Соло на трубе', 
    description: 'Талантливая трубачка, которая стремится стать особенной и лучшей.', 
    quote: 'Я хочу быть не просто хорошей, а особенной.'
  ),
  _createCard(
    id: 'r_016', 
    characterName: 'Ами Кавасима', 
    animeName: 'Toradora!', 
    imageUrl: 'https://shikimori.one/uploads/poster/characters/13725/main-f3b7d02c059b74adf8f827965ced1098.webp', 
    rarity: CardRarity.rare, 
    power: 57, 
    level: 2, 
    hp: 115, 
    mp: 80, 
    skill: 'Двойная личность', 
    description: 'Популярная модель, которая скрывает свой настоящий, довольно циничный характер.', 
    quote: 'Все видят только то, что я им показываю.'
  ),
  _createCard(
    id: 'r_017', 
    characterName: 'Кариу Рэна', 
    animeName: 'ReLIFE', 
    imageUrl: 'https://shikimori.one/uploads/poster/characters/127875/main-ba6d051004ef5345d6b948946414c977.webp', 
    rarity: CardRarity.rare, 
    power: 55, 
    level: 2, 
    hp: 110, 
    mp: 70, 
    skill: 'Соперничество', 
    description: 'Гордая и амбициозная волейболистка, которая не любит проигрывать.', 
    quote: 'Я не проиграю никому!'
  ),
  _createCard(
    id: 'r_019', 
    characterName: 'Ацуму Мацуюки', 
    animeName: 'Anohana', 
    imageUrl: 'https://shikimori.one/uploads/poster/characters/40594/main-19bb393635f3ef2f0f7c10a33d2e2537.webp', 
    rarity: CardRarity.rare, 
    power: 56, 
    level: 2, 
    hp: 110, 
    mp: 80, 
    skill: 'Чувство вины', 
    description: 'Друг детства, который до сих пор не может простить себе смерть Мэнмы.', 
    quote: 'Я тот, кто должен был быть с ней в тот день.'
  ),
  _createCard(
    id: 'r_020', 
    characterName: 'Читогэ Кирисаки', 
    animeName: 'Nisekoi', 
    imageUrl: 'https://shikimori.one/uploads/poster/characters/48391/main-96a1433d53bc29c35a9a4f1a198fa1b0.webp', 
    rarity: CardRarity.rare, 
    power: 57, 
    level: 2, 
    hp: 115, 
    mp: 75, 
    skill: 'Фальшивая любовь', 
    description: 'Девушка из семьи гангстеров, вынужденная изображать отношения с сыном главы клана-соперника.', 
    quote: 'Это самая ужасная фальшивая любовь в мире!'
  ),
  _createCard(
    id: 'r_021',
    characterName: 'Сузуха Аманэ',
    animeName: 'Steins;Gate',
    imageUrl: 'https://shikimori.one/uploads/poster/characters/35255/main-75569dd2af5a9ab57c60e737761f3719.webp',
    rarity: CardRarity.rare,
    power: 75,
    level: 1,
    hp: 150,
    mp: 100,
    skill: 'Путешественница во времени',
    description: 'Девочка-солдат из будущего, прибывшая в прошлое, чтобы предотвратить dystopia.',
    quote: 'Я вернусь. В тот самый момент.'
),
_createCard(
    id: 'r_022',
    characterName: 'Тэру Миками',
    animeName: 'Death Note',
    imageUrl: 'https://i.redd.it/yvnwa99nwe8b1.jpg',
    rarity: CardRarity.rare,
    power: 70,
    level: 1,
    hp: 140,
    mp: 110,
    skill: 'Глаза Шинигами',
    description: 'Верный слуга Кира, фанатик, готовый на всё ради "справедливости".',
    quote: 'Удалите! Удалите! Удалите!'
),
_createCard(
    id: 'r_023',
    characterName: 'Лиза Хокай',
    animeName: 'Fullmetal Alchemist: Brotherhood',
    imageUrl: 'https://shikimori.one/uploads/poster/characters/70/main-214983ea8c4b1bb0c35c416606ee83f2.webp',
    rarity: CardRarity.rare,
    power: 76,
    level: 1,
    hp: 155,
    mp: 95,
    skill: 'Снайпер',
    description: 'Лейтенант и правая рука Роя Мустанга, хранительница его огня.',
    quote: 'Если ты свернешь не с того пути, я сожгу твою спину.'
),
_createCard(
    id: 'r_024',
    characterName: 'Каллен Стадтфелд',
    animeName: 'Code Geass: Lelouch of the Rebellion',
    imageUrl: 'https://shikimori.one/uploads/poster/characters/558/main-deb2e4d63619adbd7e17e5fdd3c3e967.webp',
    rarity: CardRarity.rare,
    power: 74,
    level: 1,
    hp: 150,
    mp: 105,
    skill: 'Пилот Гурена',
    description: 'Британская аристократка, ставшая пилотом Knightmare Frame в Чёрных рыцарях.',
    quote: 'Я сражаюсь не за Британию, а за справедливость.'
),
_createCard(
    id: 'r_025',
    characterName: 'Нанналли ви Британия',
    animeName: 'Code Geass: Lelouch of the Rebellion',
    imageUrl: 'https://shikimori.one/uploads/poster/characters/1110/main-9a3905269c25fd02a32b0acc452d365b.webp',
    rarity: CardRarity.rare,
    power: 65,
    level: 1,
    hp: 130,
    mp: 110,
    skill: 'Светлое будущее',
    description: 'Младшая сестра Лелуша, ради которой он начал свою войну.',
    quote: 'Брат, создай для меня мир, в котором мы сможем быть вместе.'
),
_createCard(
    id: 'r_026',
    characterName: 'Аска Лэнгли Сикинами',
    animeName: 'Rebuild of Evangelion',
    imageUrl: 'https://shikimori.one/uploads/poster/characters/94/main-88f0bf1c8fc5901794d3d811ec6bc167.webp',
    rarity: CardRarity.rare,
    power: 77,
    level: 1,
    hp: 155,
    mp: 100,
    skill: 'Пилот Евы-02',
    description: 'Гордая и вспыльчивая пилот Евангилиона, стремящаяся быть лучшей.',
    quote: 'Анти-А.Т. Поле! Полное развертывание!'
),
_createCard(
    id: 'r_027',
    characterName: 'Кавору Нагиса',
    animeName: 'Neon Genesis Evangelion',
    imageUrl: 'https://shikimori.one/uploads/poster/characters/1261/main-8d85f8c243325d74de2b503b1ba6f36f.webp',
    rarity: CardRarity.rare,
    power: 72,
    level: 1,
    hp: 145,
    mp: 105,
    skill: 'Пилот Евы-13',
    description: 'Загадочный и добрый пилот, проявляющий странный интерес к Синджи.',
    quote: 'Песня смерти — это песня, приносящая счастье.'
),
_createCard(
    id: 'r_028',
    characterName: 'Мисато Кацураги',
    animeName: 'Neon Genesis Evangelion',
    imageUrl: 'https://shikimori.one/uploads/poster/characters/1259/main-8784e8001edae276f6bdd8acf4a78308.webp',
    rarity: CardRarity.rare,
    power: 71,
    level: 1,
    hp: 150,
    mp: 100,
    skill: 'Командир NERV',
    description: 'Начальница оперативного штаба NERV, совмещающая работу с жизнью хаотичной бакуши.',
    quote: 'Взлетаем! Всем занять свои места!'
),
_createCard(
    id: 'r_029',
    characterName: 'Рико',
    animeName: 'Made in Abyss',
    imageUrl: 'https://shikimori.one/uploads/poster/characters/137239/main-bbf4e6cd5a54b7879bcceb48afce073c.webp',
    rarity: CardRarity.rare,
    power: 68,
    level: 1,
    hp: 135,
    mp: 105,
    skill: 'Красная свистулька',
    description: 'Юная искательница, спускающаяся в Бездну в поисках своей матери.',
    quote: 'Я хочу увидеть дно Бездны!'
),
_createCard(
    id: 'r_030',
    characterName: 'Рэг',
    animeName: 'Made in Abyss',
    imageUrl: 'https://shikimori.one/uploads/poster/characters/140046/main-c20c17785d27cc94bcdd94208c8d10e8.webp',
    rarity: CardRarity.rare,
    power: 80,
    level: 1,
    hp: 160,
    mp: 90,
    skill: 'Печь',
    description: 'Механический мальчик без памяти, обладающий невероятной силой.',
    quote: 'Я должен защищать Рико.'
),
_createCard(
    id: 'r_031',
    characterName: 'Нанати',
    animeName: 'Made in Abyss',
    imageUrl: 'https://shikimori.one/uploads/poster/characters/140060/main-15a5837d22540befb2edabbfbe6c9273.webp',
    rarity: CardRarity.rare,
    power: 73,
    level: 1,
    hp: 145,
    mp: 110,
    skill: 'Мимик',
    description: 'Девушка-зверек, выжившая в проклятом пятом слое Бездны.',
    quote: 'Мии... ты пахнешь так вкусно.'
),
_createCard(
    id: 'r_032',
    characterName: 'Бондрюд',
    animeName: 'Made in Abyss',
    imageUrl: 'https://shikimori.one/uploads/poster/characters/151195/main-fea99b94e3e9cbb710cef7411a91c030.webp',
    rarity: CardRarity.rare,
    power: 85,
    level: 1,
    hp: 165,
    mp: 95,
    skill: 'Белый свисток',
    description: 'Легендарный искатель, известный как "Господин Рассвета".',
    quote: 'Бездна забирает всё, но она же и дает.'
),
_createCard(
    id: 'r_033',
    characterName: 'Хитори Гото',
    animeName: 'Bocchi the Rock!',
    imageUrl: 'https://shikimori.one/uploads/poster/characters/206276/main-49fc3d3b24a4c318935f9b1a0c2e3d43.webp',
    rarity: CardRarity.rare,
    power: 69,
    level: 1,
    hp: 140,
    mp: 100,
    skill: 'Социальная тревожность',
    description: 'Неуклюжая гитаристка, становящаяся звездой группы, несмотря на страх перед людьми.',
    quote: 'Я хочу умереть...'
),
_createCard(
    id: 'r_034',
    characterName: 'Рё Ямада',
    animeName: 'Bocchi the Rock!',
    imageUrl: 'https://shikimori.one/uploads/poster/characters/206278/main-03aa3a55fd9cd09fa302565e82098267.webp',
    rarity: CardRarity.rare,
    power: 71,
    level: 1,
    hp: 145,
    mp: 95,
    skill: 'Харизма',
    description: 'Вокалистка и харизматичный лидер группы "Кессоку Бэнд".',
    quote: 'Давайте зажжем это место!'
),
_createCard(
    id: 'r_035',
    characterName: 'Нидзика Иджити',
    animeName: 'Bocchi the Rock!',
    imageUrl: 'https://shikimori.one/uploads/poster/characters/206277/main-38375adb545420fecc066556c9312c1a.webp',
    rarity: CardRarity.rare,
    power: 70,
    level: 1,
    hp: 140,
    mp: 100,
    skill: 'Барабанщица',
    description: 'Веселая и энергичная барабанщица, "солнце" группы.',
    quote: 'Ботти-тян, ты гений!'
),
_createCard(
    id: 'r_037',
    characterName: 'Ребекка',
    animeName: 'Cyberpunk: Edgerunners',
    imageUrl: 'https://shikimori.one/uploads/poster/characters/215035/main-8237541059618c1a1007be233f39b6e9.webp',
    rarity: CardRarity.rare,
    power: 71,
    level: 1,
    hp: 145,
    mp: 100,
    skill: 'Нетраннер',
    description: 'Мечтательница, ставшая популярной стримеркой в Найт-Сити.',
    quote: 'Я покажу им всем, на что я способна!'
),
_createCard(
    id: 'r_038',
    characterName: 'Мэйн',
    animeName: 'Cyberpunk: Edgerunners',
    imageUrl: 'https://shikimori.one/uploads/poster/characters/215031/main-91f1cb9058fd5630a5d3f65e6adf2b63.webp',
    rarity: CardRarity.rare,
    power: 78,
    level: 1,
    hp: 160,
    mp: 90,
    skill: 'Боевой имплант',
    description: 'Гигант и танк команды Дэвида, преданный ему до конца.',
    quote: 'Скорость — твоя фишка, помнишь? Так что не останавливайся.'
),
_createCard(
    id: 'r_039',
    characterName: 'Фарадей',
    animeName: 'Cyberpunk: Edgerunners',
    imageUrl: 'https://shikimori.one/uploads/poster/characters/215036/main-ed08e03be66a69f025b0a374a02d378e.webp',
    rarity: CardRarity.rare,
    power: 74,
    level: 1,
    hp: 150,
    mp: 105,
    skill: 'Нетраннер',
    description: 'Хакер и мозг команды, помогающий в самых сложных операциях.',
    quote: 'Я взломаю их систему за пару минут.'
),
_createCard(
    id: 'r_041',
    characterName: 'Хёкимару',
    animeName: 'Dororo',
    imageUrl: 'https://shikimori.one/uploads/poster/characters/14864/main-12be2f03345b58225d2290b866063566.webp',
    rarity: CardRarity.rare,
    power: 81,
    level: 1,
    hp: 160,
    mp: 100,
    skill: 'Проклятые части тела',
    description: 'Самурай, чей отец обменял его органы на демонов в обмен на власть.',
    quote: 'Я верну свое тело.'
),
_createCard(
    id: 'r_042',
    characterName: 'Дороро',
    animeName: 'Dororo',
    imageUrl: 'https://shikimori.one/uploads/poster/characters/18130/main-199e726f22bc84cc64d2b662b8d3a84c.webp',
    rarity: CardRarity.rare,
    power: 65,
    level: 1,
    hp: 130,
    mp: 95,
    skill: 'Воровка',
    description: 'Маленькая девочка-сирота, путешествующая вместе с Хёкимару.',
    quote: 'Не сдавайся, Хёкимару!'
),
_createCard(
    id: 'r_043',
    characterName: 'Тахомару',
    animeName: 'Dororo',
    imageUrl: 'https://shikimori.one/uploads/poster/characters/167075/main-420ff9dde6ede0321ed7395cb09b9d0f.webp',
    rarity: CardRarity.rare,
    power: 76,
    level: 1,
    hp: 155,
    mp: 100,
    skill: 'Наследный принц',
    description: 'Младший брат Хёкимару, живущий в тени его проклятия.',
    quote: 'Я должен защитить свой дом.'
),
_createCard(
    id: 'r_045',
    characterName: 'Сино Асада',
    animeName: 'Sword Art Online',
    imageUrl: 'https://shikimori.one/uploads/poster/characters/55147/main-5d53b4c8f7817f66b1a120be559186e2.webp',
    rarity: CardRarity.rare,
    power: 75,
    level: 1,
    hp: 145,
    mp: 105,
    skill: 'Снайпер',
    description: 'Игрок в GGO, страдающая от травмы прошлого, но ставшая лучшим стрелком.',
    quote: 'Пуля — это моя воля.'
),
_createCard(
    id: 'r_047',
    characterName: 'Миса Аманэ',
    animeName: 'Death Note',
    imageUrl: 'https://static.wikia.nocookie.net/deathnote/images/7/74/260624untitled_3_large1.png/revision/latest/scale-to-width-down/268?cb=20130903190907&path-prefix=ru',
    rarity: CardRarity.rare,
    power: 60,
    level: 1,
    hp: 125,
    mp: 105,
    skill: 'Глаза Шинигами',
    description: 'Популярная идол и преданная поклонница Киры, готовая на всё ради него.',
    quote: 'Я помогу тебе, Кира-сама!'
),
_createCard(
    id: 'r_048',
    characterName: 'Михаэль Кэль',
    animeName: 'Death Note',
    imageUrl: 'https://static.wikia.nocookie.net/deathnote/images/5/5e/Q9M9ybDwkeo.jpg/revision/latest/scale-to-width-down/267?cb=20160405172904&path-prefix=ru',
    rarity: CardRarity.rare,
    power: 72,
    level: 1,
    hp: 145,
    mp: 100,
    skill: 'Мафия',
    description: 'Гениальный детектив, второй преемник L, действующий радикальными методами.',
    quote: 'Я поймаю Кира, даже если для этого придется нарушать закон.'
),
_createCard(
    id: 'r_049',
    characterName: 'Ниа',
    animeName: 'Death Note',
    imageUrl: 'https://static.wikia.nocookie.net/deathnote/images/b/b6/%D0%9D%D0%B8%D0%B0.png/revision/latest?cb=20201230193945&path-prefix=ru',
    rarity: CardRarity.rare,
    power: 71,
    level: 1,
    hp: 140,
    mp: 105,
    skill: 'Детектив',
    description: 'Третий преемник L, спокойный и аналитичный детектив.',
    quote: 'Истина одна, но пути к ней могут быть разными.'
),
_createCard(
    id: 'r_050',
    characterName: 'Бонд Форджер',
    animeName: 'Spy x Family',
    imageUrl: 'https://shikimori.one/uploads/poster/characters/203871/main-3611423e4be4917e0e7354c0d0219155.webp',
    rarity: CardRarity.rare,
    power: 62,
    level: 1,
    hp: 130,
    mp: 95,
    skill: 'Умная собака',
    description: 'Пси-собака с способностью к предсказанию будущего, ставшая частью семьи.',
    quote: 'Гав!'
),
_createCard(
    id: 'r_051',
    characterName: 'Юрий Брайар',
    animeName: 'Spy x Family',
    imageUrl: 'https://shikimori.one/uploads/poster/characters/177507/main-856723f0de929724f668217265bc705a.webp',
    rarity: CardRarity.rare,
    power: 74,
    level: 1,
    hp: 150,
    mp: 100,
    skill: 'Старший брат',
    description: 'Старший брат Йор, охранник государственной службы, заботящийся о сестре.',
    quote: 'Я всегда буду защищать сестру.'
),
_createCard(
    id: 'r_052',
    characterName: 'Дамиан Дезмонд',
    animeName: 'Spy x Family',
    imageUrl: 'https://shikimori.one/uploads/poster/characters/177509/main-3ca7c4a8653c8f65f82c21ca9039e82d.webp',
    rarity: CardRarity.rare,
    power: 66,
    level: 1,
    hp: 135,
    mp: 95,
    skill: 'Сын врага',
    description: 'Сын цели Ллойда, в которого Аня влюбилась, усложняя миссию.',
    quote: 'Аня, я не буду с тобой разговаривать!'
),
_createCard(
    id: 'r_053',
    characterName: 'Джет Блэк',
    animeName: 'Cowboy Bebop',
    imageUrl: 'https://shikimori.one/uploads/poster/characters/3/main-09f74ffbd89edcc7b1c5affdd5fb5f00.webp',
    rarity: CardRarity.rare,
    power: 77,
    level: 1,
    hp: 160,
    mp: 90,
    skill: 'Бывший коп',
    description: 'Бывший полицейский, ставший капитаном корабля "Бибоп" и наставником Спайка.',
    quote: 'Я должен был уйти, когда ушла Джулия.'
),
_createCard(
    id: 'r_054',
    characterName: 'Фэй Валентайн',
    animeName: 'Cowboy Bebop',
    imageUrl: 'https://shikimori.one/uploads/poster/characters/2/main-9dcac5074f915a017361f1da1e473773.webp',
    rarity: CardRarity.rare,
    power: 70,
    level: 1,
    hp: 145,
    mp: 100,
    skill: 'Карманница',
    description: 'Загадочная и харизматичная мошенница, присоединившаяся к команде "Бибоп".',
    quote: 'Я не верю в судьбу. Я сама создаю свою дорогу.'
),
_createCard(
    id: 'r_055',
    characterName: 'Эдвард Вон Хау',
    animeName: 'Cowboy Bebop',
    imageUrl: 'https://shikimori.one/uploads/poster/characters/16/main-19a60bf2437655433cfe8d3173d49629.webp',
    rarity: CardRarity.rare,
    power: 68,
    level: 1,
    hp: 140,
    mp: 110,
    skill: 'Хакер-гений',
    description: 'Гениальный хакер и механик, присоединившаяся к команде в поисках отца.',
    quote: 'Fufufufu!'
),
_createCard(
    id: 'r_056',
    characterName: 'Вишез',
    animeName: 'Cowboy Bebop',
    imageUrl: 'https://shikimori.one/uploads/poster/characters/2734/main-ebea3dc8a13d1ff4be40d380e7821960.webp',
    rarity: CardRarity.rare,
    power: 75,
    level: 1,
    hp: 155,
    mp: 95,
    skill: 'Пемброк Уэльш Корги',
    description: 'Собака-генетический эксперимент, ставшая талисманом команды "Бибоп".',
    quote: 'Вуф!'
),
_createCard(
    id: 'r_059',
    characterName: 'Ай Хаясака',
    animeName: 'Kaguya-sama: Love is War',
    imageUrl: 'https://shikimori.one/uploads/poster/characters/143196/main-5b9d96650043679201e04c5006633d49.webp',
    rarity: CardRarity.rare,
    power: 69,
    level: 1,
    hp: 140,
    mp: 100,
    skill: 'Личная ассистентка',
    description: 'Верная ассистентка Кагуи, помогающая ей в "войне любви".',
    quote: 'Президент, вы опять делаете что-то странное.'
),
_createCard(
    id: 'r_060',
    characterName: 'Ю Ишигами',
    animeName: 'Kaguya-sama: Love is War',
    imageUrl: 'https://static.wikia.nocookie.net/kaguyasama-wa-kokurasetai/images/9/9b/%D0%AE_%D0%98%D1%81%D0%B8%D0%B3%D0%B0%D0%BC%D0%B8_%28%D0%B0%D0%BD%D0%B8%D0%BC%D1%8D%29.png/revision/latest/scale-to-width-down/270?cb=20200420210755&path-prefix=ru',
    rarity: CardRarity.rare,
    power: 70,
    level: 1,
    hp: 145,
    mp: 95,
    skill: 'Казначей',
    description: 'Член студсовета, живущий в мире своих фантазий и отговорок.',
    quote: 'Это не потому, что я ленивый! Это потому, что я стратег!'
),
_createCard(
    id: 'r_061',
    characterName: 'Клаудия Ходжинс',
    animeName: 'Violet Evergarden',
    imageUrl: 'https://shikimori.one/uploads/poster/characters/152270/main-b632b4d05bc778b623304642c07fb10c.webp',
    rarity: CardRarity.rare,
    power: 68,
    level: 1,
    hp: 140,
    mp: 100,
    skill: 'Почтовая голубка',
    description: 'Президент почтовой компании "CH", взявшая Вайолет под свою опеку.',
    quote: 'Ты — не оружие. Ты — человек.'
),
_createCard(
    id: 'r_062',
    characterName: 'Гилберт Бугенвиллея',
    animeName: 'Violet Evergarden',
    imageUrl: 'https://shikimori.one/uploads/poster/characters/152271/main-9b6ea5f17adb7f809caa837c1d0611ce.webp',
    rarity: CardRarity.rare,
    power: 71,
    level: 1,
    hp: 145,
    mp: 105,
    skill: 'Майор',
    description: 'Офицер, который нашел Вайолет на поле боя и дал ей имя.',
    quote: 'Я люблю тебя, Вайолет.'
),
];

  // 🟣 Эпические карты (15% шанс выпадения)
  static final List<AnimeCard> _epicCards = [
    _createCard(
      id: 'e_001', 
      characterName: 'Кирито', 
      animeName: 'Sword Art Online', 
      imageUrl: 'https://shikimori.one/uploads/poster/characters/36765/main-1ad74a0e6f22d1a55b0cea86d26d6daf.webp', 
      rarity: CardRarity.epic, 
      power: 85, 
      level: 3, 
      hp: 150, 
      mp: 100, 
      skill: 'Стиль двух мечей', 
      description: 'Игрок, застрявший в смертельной VRMMORPG и сражающийся за выживание.', 
      quote: 'В этом мире настоящая сила — это воля к жизни.'
    ),
    _createCard(
      id: 'e_002', 
      characterName: 'Асуна Юки', 
      animeName: 'Sword Art Online', 
      imageUrl: 'https://shikimori.one/uploads/poster/characters/36828/main-302f7b8ad5ef6a8cd80c3886686a139c.webp', 
      rarity: CardRarity.epic, 
      power: 82, 
      level: 3, 
      hp: 145, 
      mp: 95, 
      skill: 'Молниеносная рапира', 
      description: 'Быстрая и умелая воительница, одна из сильнейших игроков в SAO.', 
      quote: 'Иногда важнее знать, куда ты идёшь, чем как быстро.'
    ),
    _createCard(
    id: 'e_003', 
    characterName: 'Сора', 
    animeName: 'No Game No Life', 
    imageUrl: 'https://shikimori.one/uploads/poster/characters/82523/main-f8d533f6acb7151c61a194b66a74dc4c.webp', 
    rarity: CardRarity.epic, 
    power: 88, 
    level: 3, 
    hp: 140, 
    mp: 130, 
    skill: 'Абсолютная стратегия', 
    description: 'Гениальный стратег и геймер, который вместе с сестрой никогда не проигрывает.', 
    quote: 'Мы, 『Пустые』, никогда не проигрываем!'
  ),
  _createCard(
    id: 'e_004', 
    characterName: 'Микаса Аккерман', 
    animeName: 'Attack on Titan', 
    imageUrl: 'https://shikimori.one/uploads/poster/characters/40881/main-b16391bf4c3734ac277d9fd6f7a7a4f5.webp', 
    rarity: CardRarity.epic, 
    power: 90, 
    level: 3, 
    hp: 160, 
    mp: 90, 
    skill: 'Мастер УПМ', 
    description: 'Одна из сильнейших солдат человечества, способная в одиночку уничтожать титанов.', 
    quote: 'Этот мир жесток. Но в то же время... он так прекрасен.'
  ),
  _createCard(
    id: 'e_005', 
    characterName: 'Нагиса Сиота', 
    animeName: 'Assassination Classroom', 
    imageUrl: 'https://shikimori.one/uploads/poster/characters/65645/main-c4abeaf2d97abb78448525363255d8db.webp', 
    rarity: CardRarity.epic, 
    power: 78, 
    level: 3, 
    hp: 130, 
    mp: 85, 
    skill: 'Прирождённый убийца', 
    description: 'На вид хрупкий ученик с врождённым талантом к убийству, лучший в классе.', 
    quote: 'У каждого есть талант, и мой — убивать.'
  ),
  _createCard(
    id: 'e_007', 
    characterName: 'Нана Комацу (Хати)', 
    animeName: 'Nana', 
    imageUrl: 'https://shikimori.one/uploads/poster/characters/701/main-06eaa61ec1a04ee71cfee58f847fb00a.webp', 
    rarity: CardRarity.epic, 
    power: 82, 
    level: 3, 
    hp: 140, 
    mp: 95, 
    skill: 'Поиски любви', 
    description: 'Наивная и мечтательная девушка, которая ищет своё счастье в Токио.', 
    quote: 'Эй, Нана, знаешь, даже сейчас я продолжаю звать твоё имя.'
  ),
  _createCard(
    id: 'e_008', 
    characterName: 'Кагуя Синомия', 
    animeName: 'Kaguya-sama: Love is War', 
    imageUrl: 'https://shikimori.one/uploads/poster/characters/136359/main-b44ed4b55e1500302e3b6eea302b485b.webp', 
    rarity: CardRarity.epic, 
    power: 84, 
    level: 3, 
    hp: 145, 
    mp: 100, 
    skill: 'Гений-стратег', 
    description: 'Вице-президент студсовета, ведущая интеллектуальную войну, чтобы заставить президента признаться в любви.', 
    quote: 'В любви проигрывает тот, кто признаётся первым.'
  ),
  _createCard(
    id: 'e_009', 
    characterName: 'Сёто Тодороки', 
    animeName: 'My Hero Academia', 
    imageUrl: 'https://shikimori.one/uploads/poster/characters/118489/main-da1b273c670c27e7d9def3c80107e873.webp', 
    rarity: CardRarity.epic, 
    power: 87, 
    level: 3, 
    hp: 150, 
    mp: 90, 
    skill: 'Огонь и лёд', 
    description: 'Один из сильнейших учеников академии Юэй, владеющий двумя мощными причудами.', 
    quote: 'Я стану героем, каким хочу быть, и докажу это своей силой.'
  ),
  _createCard(
    id: 'e_010', 
    characterName: 'Сэйбер (Артория)', 
    animeName: 'Fate/stay night', 
    imageUrl: 'https://shikimori.one/uploads/poster/characters/497/main-95d4da75ca2ffe01c1c2133036c557de.webp', 
    rarity: CardRarity.epic, 
    power: 89, 
    level: 3, 
    hp: 155, 
    mp: 110, 
    skill: 'Экскалибур', 
    description: 'Легендарный Король Артур, призванный в качестве слуги класса Сэйбер.', 
    quote: 'Клинок — моя душа, моя честь, мой путь.'
  ),
  _createCard(
    id: 'e_011', 
    characterName: 'L', 
    animeName: 'Death Note', 
    imageUrl: 'https://grizly.club/uploads/posts/2023-08/1693273143_grizly-club-p-kartinki-l-tetrad-smerti-bez-fona-2.png', 
    rarity: CardRarity.epic, 
    power: 88, 
    level: 3, 
    hp: 140, 
    mp: 125, 
    skill: 'Величайший детектив', 
    description: 'Гениальный детектив, который бросает вызов Кире в интеллектуальной дуэли.', 
    quote: 'Рискнуть жизнью и сделать что-то, что может её оборвать — две разные вещи.'
  ),
  _createCard(
    id: 'e_012', 
    characterName: 'Юскэ Урамэси', 
    animeName: 'Yu Yu Hakusho', 
    imageUrl: 'https://shikimori.one/uploads/poster/characters/729/main-9442222cc9e7eadc6cbfdcd7c3a2135a.webp', 
    rarity: CardRarity.epic, 
    power: 86, 
    level: 3, 
    hp: 160, 
    mp: 100, 
    skill: 'Духовная пушка (Рэйган)', 
    description: 'Подросток-хулиган, который становится духовным детективом после своей смерти.', 
    quote: 'Возможно, я и умер, но я всё ещё могу надрать задницу!'
  ),
  _createCard(
    id: 'e_013', 
    characterName: 'Хисока Морроу', 
    animeName: 'Hunter x Hunter', 
    imageUrl: 'https://shikimori.one/uploads/poster/characters/31/main-96fc733ae71319a5199d7c7e79c2d76b.webp', 
    rarity: CardRarity.epic, 
    power: 87, 
    level: 3, 
    hp: 150, 
    mp: 115, 
    skill: 'Эластичная любовь', 
    description: 'Эксцентричный и непредсказуемый фокусник, чья сила заключается в его ауре Нэн.', 
    quote: 'Резина обладает свойствами как жвачки, так и каучука.'
  ),
  _createCard(
    id: 'e_014', 
    characterName: 'Эмилия', 
    animeName: 'Re:Zero', 
    imageUrl: 'https://shikimori.one/uploads/poster/characters/118737/main-1bbac237433dd8463eeee8c92e880a82.webp', 
    rarity: CardRarity.epic, 
    power: 86, 
    level: 3, 
    hp: 150, 
    mp: 100, 
    skill: 'Магия духов', 
    description: 'Полуэльфийка и кандидат на трон, способная использовать магию огня и льда.', 
    quote: 'Моё имя — Эмилия. Просто Эмилия.'
  ),
  _createCard(
    id: 'e_015', 
    characterName: 'Харухи Судзумия', 
    animeName: 'The Melancholy of Haruhi Suzumiya', 
    imageUrl: 'https://shikimori.one/uploads/poster/characters/251/main-7e7112b7abdbf8ffac04463ea1eccaf0.webp', 
    rarity: CardRarity.epic, 
    power: 90, 
    level: 3, 
    hp: 160, 
    mp: 120, 
    skill: 'Изменение реальности', 
    description: 'Эксцентричная школьница, неосознанно обладающая силой изменять реальность.', 
    quote: 'Меня не интересуют обычные люди. Если среди вас есть инопланетяне, путешественники во времени или экстрасенсы — найдите меня!'
  ),
  _createCard(
    id: 'e_016', 
    characterName: 'Рем', 
    animeName: 'Re:Zero', 
    imageUrl: 'https://shikimori.one/uploads/poster/characters/118763/main-7f728ce5cce2cb69522bdfcbe0e98e1a.webp', 
    rarity: CardRarity.epic, 
    power: 87, 
    level: 3, 
    hp: 150, 
    mp: 95, 
    skill: 'Демоническая сила', 
    description: 'Одна из горничных-демонов, безгранично преданная Субару.', 
    quote: 'Мой герой — самый лучший в мире!'
  ),
  _createCard(
    id: 'e_017', 
    characterName: 'Айнз Оал Гоун', 
    animeName: 'Overlord', 
    imageUrl: 'https://shikimori.one/uploads/poster/characters/116281/main-b2bd98a621d98508a77f9c2a2ab91a7b.webp', 
    rarity: CardRarity.epic, 
    power: 92, 
    level: 3, 
    hp: 160, 
    mp: 130, 
    skill: 'Магия смерти', 
    description: 'Игрок, ставший своим аватаром-личом в мире, который стал реальностью.', 
    quote: 'Аплодируйте моей высшей силе!'
  ),
  _createCard(
    id: 'e_018', 
    characterName: 'Гатс', 
    animeName: 'Berserk', 
    imageUrl: 'https://shikimori.one/uploads/poster/characters/422/main-bd83e77b7761eeb46d667d82d5d2b3e2.webp', 
    rarity: CardRarity.epic, 
    power: 91, 
    level: 3, 
    hp: 180, 
    mp: 80, 
    skill: 'Чёрный мечник', 
    description: 'Наёмник, владеющий огромным мечом "Убийца Драконов" и ищущий мести.', 
    quote: 'Даже если надежды нет, я буду продолжать бороться.'
  ),
  _createCard(
    id: 'e_019', 
    characterName: 'Леви Аккерман', 
    animeName: 'Attack on Titan', 
    imageUrl: 'https://shikimori.one/uploads/poster/characters/45627/main-19f627c89d6b5c08f0fc0b801e62ecf1.webp', 
    rarity: CardRarity.epic, 
    power: 93, 
    level: 3, 
    hp: 160, 
    mp: 85, 
    skill: 'Сильнейший воин', 
    description: 'Капитан Разведотряда, известный как "сильнейший воин человечества".', 
    quote: 'Выбирай сам. Верь в себя или верь в товарищей. Я не знаю, что правильно.'
  ),
  _createCard(
    id: 'e_020', 
    characterName: 'Эрен Йегер', 
    animeName: 'Attack on Titan', 
    imageUrl: 'https://shikimori.one/uploads/poster/characters/40882/main-cad65917dd59b2b117f04d2c36472842.webp', 
    rarity: CardRarity.epic, 
    power: 90, 
    level: 3, 
    hp: 170, 
    mp: 100, 
    skill: 'Атакующий титан', 
    description: 'Главный герой, который поклялся уничтожить всех титанов.', 
    quote: 'Я буду двигаться вперёд, пока не уничтожу всех своих врагов.'
  ),
  _createCard(
    id: 'e_021',
    characterName: 'Алфонс Элрик',
    animeName: 'Fullmetal Alchemist: Brotherhood',
    imageUrl: 'https://shikimori.one/uploads/poster/characters/12/main-9df74ce1ef48ff14003c492816a0c821.webp',
    rarity: CardRarity.epic,
    power: 78,
    level: 2,
    hp: 180,
    mp: 100,
    skill: 'Стальной доспех',
    description: 'Младший брат Эдварда, чья душа была заключена в огромный доспех.',
    quote: 'Брат, ты снова стал маленьким!'
),
_createCard(
    id: 'e_022',
    characterName: 'Дзэнъицу Агацума',
    animeName: 'Demon Slayer',
    imageUrl: 'https://shikimori.one/uploads/poster/characters/146158/main-03e2198c4f6f02afd292736c034ffcde.webp',
    rarity: CardRarity.epic,
    power: 80,
    level: 2,
    hp: 160,
    mp: 110,
    skill: 'Дыхание грома',
    description: 'Страхливый, но невероятно быстрый убийца демонов, влюбленный в Нэдзуко.',
    quote: 'Я не хочу сражаться! Я хочу спать!'
),
_createCard(
    id: 'e_023',
    characterName: 'Иносукэ Хасибира',
    animeName: 'Demon Slayer',
    imageUrl: 'https://shikimori.one/uploads/poster/characters/146159/main-484f6a347f994f835e3ba1a8b8b209c6.webp',
    rarity: CardRarity.epic,
    power: 82,
    level: 2,
    hp: 170,
    mp: 90,
    skill: 'Дыхание зверя',
    description: 'Дикий и вспыльчивый воин, выросший в горах и носящий голову кабана.',
    quote: 'Кто сильнее? Давай выясним!'
),
_createCard(
    id: 'e_024',
    characterName: 'Нобара Кугисаки',
    animeName: 'Jujutsu Kaisen',
    imageUrl: 'https://shikimori.one/uploads/poster/characters/164472/main-6d60e91c9235f74a3ef51a8d2bb24924.webp',
    rarity: CardRarity.epic,
    power: 79,
    level: 2,
    hp: 155,
    mp: 115,
    skill: 'Резьба по кукле',
    description: 'Уверенная в себе и прямолинейная волшебница, не терпящая несправедливости.',
    quote: 'Я — Нобара Кугисаки! Не забывай это имя!'
),
_createCard(
    id: 'e_025',
    characterName: 'Фрирен',
    animeName: 'Frieren: Beyond Journey\'s End',
    imageUrl: 'https://shikimori.one/uploads/poster/characters/184947/main-8457aa2a7a97cacacaa2e70d473db9e0.webp',
    rarity: CardRarity.epic,
    power: 85,
    level: 2,
    hp: 150,
    mp: 130,
    skill: 'Древняя магия',
    description: 'Эльфийка-маг, пережившая своих товарищей по приключениям и пытающаяся понять людей.',
    quote: 'Время для людей течет совсем по-другому.'
),
_createCard(
    id: 'e_026',
    characterName: 'Химмель',
    animeName: 'Frieren: Beyond Journey\'s End',
    imageUrl: 'https://shikimori.one/uploads/poster/characters/186854/main-254d311c9135c5b2acfbd2d40b939b29.webp',
    rarity: CardRarity.epic,
    power: 83,
    level: 2,
    hp: 160,
    mp: 105,
    skill: 'Герой',
    description: 'Великий герой прошлого, чья память вдохновляет Фрирен на протяжении десятилетий.',
    quote: 'Я всегда буду защищать тебя, Фрирен.'
),
_createCard(
    id: 'e_027',
    characterName: 'Аки Хаякава',
    animeName: 'Chainsaw Man',
    imageUrl: 'https://shikimori.one/uploads/poster/characters/170735/main-00a1d6c104abcd49b70e04980afc10a8.webp',
    rarity: CardRarity.epic,
    power: 81,
    level: 2,
    hp: 165,
    mp: 110,
    skill: 'Контракт с лисом',
    description: 'Серьезный охотник на дьяволов, ставший для Дэндзи старшим братом.',
    quote: 'Я убью Дьявола-пилу.'
),
_createCard(
    id: 'e_028',
    characterName: 'Рэзэ',
    animeName: 'Chainsaw Man',
    imageUrl: 'https://shikimori.one/uploads/poster/characters/174751/main-05383c1b76ee6446585b4f700ad8bf7a.webp',
    rarity: CardRarity.epic,
    power: 80,
    level: 2,
    hp: 160,
    mp: 100,
    skill: 'Бомба-человек',
    description: 'Сибирская хаски, являющаяся гибридом бомбы и шпионкой вражеской организации.',
    quote: 'Прости, Дэндзи.'
),
_createCard(
    id: 'e_029',
    characterName: 'Тока Киришима',
    animeName: 'Tokyo Ghoul',
    imageUrl: 'https://shikimori.one/uploads/poster/characters/87277/main-6af2caba7c55130036fd42b091f3f787.webp',
    rarity: CardRarity.epic,
    power: 82,
    level: 2,
    hp: 155,
    mp: 115,
    skill: 'Укукаку',
    description: 'Бывший лидер анти-агхульской организации, ставший верным другом Канеки.',
    quote: 'Я — гуль. И я горжусь этим.'
),
_createCard(
    id: 'e_030',
    characterName: 'Котаро Амон',
    animeName: 'Tokyo Ghoul',
    imageUrl: 'https://shikimori.one/uploads/poster/characters/99671/main-df7f070450a51b3fe1ab205f5048587c.webp',
    rarity: CardRarity.epic,
    power: 81,
    level: 2,
    hp: 170,
    mp: 95,
    skill: 'Доку',
    description: 'Следователь из отдела по борьбе с гулями, обладающий сильным чувством справедливости.',
    quote: 'Я не понимаю. Почему гули должны страдать?'
),
_createCard(
    id: 'e_031',
    characterName: 'Йошимура',
    animeName: 'Tokyo Ghoul',
    imageUrl: 'https://shikimori.one/uploads/poster/characters/103413/main-1b2db201a64332fb574f8691170928da.webp',
    rarity: CardRarity.epic,
    power: 79,
    level: 2,
    hp: 150,
    mp: 120,
    skill: 'Кагунэ',
    description: 'Спокойный и мудрый гуль, владелец кофейни "Антейку".',
    quote: 'В этом мире есть вещи, которые нельзя изменить.'
),
_createCard(
    id: 'e_032',
    characterName: 'Джузо Судзуя',
    animeName: 'Tokyo Ghoul',
    imageUrl: 'https://shikimori.one/uploads/poster/characters/104437/main-952c82b264deaaafa088d26af8aab0e4.webp',
    rarity: CardRarity.epic,
    power: 84,
    level: 2,
    hp: 165,
    mp: 100,
    skill: 'Джейсон',
    description: 'Безумный и непредсказуемый следователь, сражающийся двумя огромными ножами.',
    quote: 'Я просто хочу сделать тебе больно.'
),
_createCard(
    id: 'e_033',
    characterName: 'Ута',
    animeName: 'Tokyo Ghoul',
    imageUrl: 'https://shikimori.one/uploads/poster/characters/93343/main-f6b1be976d40978153e16271f7c91370.webp',
    rarity: CardRarity.epic,
    power: 83,
    level: 2,
    hp: 160,
    mp: 105,
    skill: 'Маска',
    description: 'Знаменитый дизайнер масок для гулей, старый друг Ренджи и Юмо.',
    quote: 'Мои маски — это искусство.'
),
_createCard(
    id: 'e_034',
    characterName: 'Сигэо "Моб" Кагэяма',
    animeName: 'Mob Psycho 100',
    imageUrl: 'https://shikimori.one/uploads/poster/characters/109929/main-42c3bdaf2b018b3870407eeec7f4d08e.webp',
    rarity: CardRarity.epic,
    power: 88,
    level: 2,
    hp: 150,
    mp: 125,
    skill: '???%',
    description: 'Мальчик с невероятными экстрасенсорными способностями, старающийся жить обычной жизнью.',
    quote: 'Я не хочу использовать свои силы, чтобы причинять вред другим.'
),
_createCard(
    id: 'e_036',
    characterName: 'Мумэн Райдер',
    animeName: 'One-Punch Man',
    imageUrl: 'https://shikimori.one/uploads/poster/characters/81935/main-75e36fb25cc1dd006c42d8f22cb593f6.webp',
    rarity: CardRarity.epic,
    power: 72,
    level: 2,
    hp: 165,
    mp: 90,
    skill: 'Велосипедный удар',
    description: 'Герой класса C, чья несокрушимая воля и доброта делают его настоящим героем.',
    quote: 'Я не могу сдаться! Я — герой!'
),
_createCard(
    id: 'e_037',
    characterName: 'Отяко Урарака',
    animeName: 'My Hero Academia',
    imageUrl: 'https://shikimori.one/uploads/poster/characters/117917/main-cdc44c5d234b31927e771cdbfb88f869.webp',
    rarity: CardRarity.epic,
    power: 74,
    level: 2,
    hp: 145,
    mp: 115,
    skill: 'Нулевая гравитация',
    description: 'Веселая и дружелюбная героиня, чья цель — заработать деньги для родителей.',
    quote: 'Я сделаю тебя невесомым!'
),
_createCard(
    id: 'e_038',
    characterName: 'Сёта Айдзава',
    animeName: 'My Hero Academia',
    imageUrl: 'https://shikimori.one/uploads/poster/characters/117915/main-893e8d0b62138f3f3114fea370a805ea.webp',
    rarity: CardRarity.epic,
    power: 80,
    level: 2,
    hp: 155,
    mp: 110,
    skill: 'Стирание',
    description: 'Профессор УА и герой "Стирающий Глаз", способный аннулировать чужие квирки.',
    quote: 'Это так утомительно.'
),
_createCard(
    id: 'e_040',
    characterName: 'Жан Кирштайн',
    animeName: 'Attack on Titan',
    imageUrl: 'https://shikimori.one/uploads/poster/characters/46498/main-4cc35031aa65b2db52e854e71a5b1c2a.webp',
    rarity: CardRarity.epic,
    power: 77,
    level: 2,
    hp: 160,
    mp: 100,
    skill: 'Стрелок',
    description: 'Самопровозглашенный "корейский босс", выросший в надежного солдата.',
    quote: 'Я умру, но не позволю им пройти!'
),
_createCard(
    id: 'e_041',
    characterName: 'Саша Браус',
    animeName: 'Attack on Titan',
    imageUrl: 'https://static.wikia.nocookie.net/shingekinokyojin/images/c/ca/Sasha_Braus_%28Anime%29_character_image_%28850%29.png/revision/latest/scale-to-width-down/300?cb=20210114072118&path-prefix=ru',
    rarity: CardRarity.epic,
    power: 75,
    level: 2,
    hp: 155,
    mp: 95,
    skill: 'Охотница',
    description: 'Эксцентричная девушка с невероятным чутьем на еду и выживание.',
    quote: 'Мясо! Мясо!'
),
_createCard(
    id: 'e_042',
    characterName: 'Рам',
    animeName: 'Re:Zero - Starting Life in Another World',
    imageUrl: 'https://shikimori.one/uploads/poster/characters/118765/main-c9437d4de3c97d548b754f587db35f96.webp',
    rarity: CardRarity.epic,
    power: 78,
    level: 2,
    hp: 150,
    mp: 110,
    skill: 'Магия ветра',
    description: 'Домашняя дух-девушка Розваль, холодная к Субару, но преданная своей сестре.',
    quote: 'Бараку. Я убью тебя.'
),
_createCard(
    id: 'e_043',
    characterName: 'Беатрис',
    animeName: 'Re:Zero - Starting Life in Another World',
    imageUrl: 'https://shikimori.one/uploads/poster/characters/118767/main-9d06009cf5b99fe05087143506be5e2e.webp',
    rarity: CardRarity.epic,
    power: 76,
    level: 2,
    hp: 145,
    mp: 120,
    skill: 'Библиотекарь',
    description: 'Дух-хранитель библиотеки, веками ждущая своего "спасителя".',
    quote: 'На самом деле, Бетти думает, что ты полный идиот.'
),
_createCard(
    id: 'e_045',
    characterName: 'Рокси Мигурдия',
    animeName: 'Mushoku Tensei: Jobless Reincarnation',
    imageUrl: 'https://shikimori.one/uploads/poster/characters/111341/main-7d074527db2bb79332bcb9d3862f55a3.webp',
    rarity: CardRarity.epic,
    power: 82,
    level: 2,
    hp: 150,
    mp: 120,
    skill: 'Великий учитель',
    description: 'Великий учитель магии, ставшая для Рудэуса первым наставником и объектом любви.',
    quote: 'Даже если ты ничего не знаешь, я научу тебя всему.'
),
_createCard(
    id: 'e_046',
    characterName: 'Эрис Борес Грейрат',
    animeName: 'Mushoku Tensei: Jobless Reincarnation',
    imageUrl: 'https://shikimori.one/uploads/poster/characters/111335/main-e89287e4cf34b9f8755d0840a8225270.webp',
    rarity: CardRarity.epic,
    power: 79,
    level: 2,
    hp: 155,
    mp: 115,
    skill: 'Принцесса-рыцарь',
    description: 'Вспыльчивая, но добрая дворянка, ставшая одной из главных спутниц Рудэуса.',
    quote: 'Я не проиграю никому, особенно тебе!'
),
_createCard(
    id: 'e_047',
    characterName: 'Сильфиэтта',
    animeName: 'Mushoku Tensei: Jobless Reincarnation',
    imageUrl: 'https://shikimori.one/uploads/poster/characters/111337/main-2ed643690645d3352d9595a95d681839.webp',
    rarity: CardRarity.epic,
    power: 77,
    level: 2,
    hp: 145,
    mp: 125,
    skill: 'Молчаливая магия',
    description: 'Лучший друг Рудэуса, преданная ему с самого детства.',
    quote: 'Руди, я всегда буду рядом с тобой.'
),
_createCard(
    id: 'e_048',
    characterName: 'Сёё Хината',
    animeName: 'Haikyuu!!',
    imageUrl: 'https://shikimori.one/uploads/poster/characters/64769/main-993ad3d848642b35850d14919e1357c3.webp',
    rarity: CardRarity.epic,
    power: 76,
    level: 2,
    hp: 140,
    mp: 110,
    skill: 'Быстрый удар',
    description: 'Низкорослый волейболист с невероятным прыжком и несгибаемой волей.',
    quote: 'Я могу прыгать!'
),
_createCard(
    id: 'e_049',
    characterName: 'Тобио Кагеяма',
    animeName: 'Haikyuu!!',
    imageUrl: 'https://shikimori.one/uploads/poster/characters/64771/main-8a028c004b1f87d0635335764627b0bd.webp',
    rarity: CardRarity.epic,
    power: 77,
    level: 2,
    hp: 145,
    mp: 105,
    skill: 'Король двора',
    description: 'Гениальный связующий, стремящийся стать лучшим в своей позиции.',
    quote: 'Подавай мне мяч.'
),
_createCard(
    id: 'e_050',
    characterName: 'Аста',
    animeName: 'Black Clover',
    imageUrl: 'https://shikimori.one/uploads/poster/characters/124731/main-0664ee746a45587fc14f6bffcbb6b00d.webp',
    rarity: CardRarity.epic,
    power: 83,
    level: 2,
    hp: 160,
    mp: 100,
    skill: 'Анти-магия',
    description: 'Мальчик без магии, получивший гримуар, способный аннулировать заклинания.',
    quote: 'Я стану Волшебным Императором!'
),
_createCard(
    id: 'e_051',
    characterName: 'Юно',
    animeName: 'Black Clover',
    imageUrl: 'https://shikimori.one/uploads/poster/characters/124732/main-6c645568cff89eca3d59deb0c6114fd5.webp',
    rarity: CardRarity.epic,
    power: 82,
    level: 2,
    hp: 155,
    mp: 115,
    skill: 'Ветряная магия',
    description: 'Приемный брат и соперник Асты, гений с невероятным магическим талантом.',
    quote: 'Я всегда буду на шаг впереди тебя, Аста.'
),
_createCard(
    id: 'e_052',
    characterName: 'Маки Дзэнин',
    animeName: 'Jujutsu Kaisen 0',
    imageUrl: 'https://shikimori.one/uploads/poster/characters/164482/main-cdd233161da4bf70e1f3d9518582204a.webp',
    rarity: CardRarity.epic,
    power: 81,
    level: 2,
    hp: 165,
    mp: 95,
    skill: 'Инструменты',
    description: 'Маг, лишенная проклятой энергии, но компенсирующая это мастерством владения оружием.',
    quote: 'Я докажу, что могу быть сильной без всякой там энергии.'
),
_createCard(
    id: 'e_053',
    characterName: 'Тогэ Инумаки',
    animeName: 'Jujutsu Kaisen 0',
    imageUrl: 'https://shikimori.one/uploads/poster/characters/164478/main-89d061b506c13dfb1c1bf9ea064eb9e7.webp',
    rarity: CardRarity.epic,
    power: 78,
    level: 2,
    hp: 150,
    mp: 110,
    skill: 'Проклятая речь',
    description: 'Маг, общающийся только с помощью слов, написанных на рукаве его одежды.',
    quote: 'Тунец. (Означает "Да" или "Хорошо")'
),
_createCard(
    id: 'e_054',
    characterName: 'Бруно Буччеллати',
    animeName: "JoJo's Bizarre Adventure: Golden Wind",
    imageUrl: 'https://shikimori.one/uploads/poster/characters/13045/main-d1efadbeb88e7e505bfd71e1c09cffe0.webp',
    rarity: CardRarity.epic,
    power: 84,
    level: 2,
    hp: 170,
    mp: 105,
    skill: 'Липкие пальцы',
    description: 'Лидер банды "Пассионе", верный своему долгу и команде.',
    quote: 'ARRIVEDERCI!'
),
_createCard(
    id: 'e_055',
    characterName: 'Торкелль',
    animeName: 'Vinland Saga',
    imageUrl: 'https://shikimori.one/uploads/poster/characters/17440/main-f3373718ba9ac884615adee266eb6284.webp',
    rarity: CardRarity.epic,
    power: 85,
    level: 2,
    hp: 175,
    mp: 90,
    skill: 'Йомсвикинг',
    description: 'Великан и верный воин, сражающийся ради чести и своих товарищей.',
    quote: 'Я не бью детей. Но я сделаю исключение.'
),
_createCard(
    id: 'e_056',
    characterName: 'Кнуд',
    animeName: 'Vinland Saga',
    imageUrl: 'https://shikimori.one/uploads/poster/characters/17438/main-0e772bf25bcadc36607962bbf11b5263.webp',
    rarity: CardRarity.epic,
    power: 80,
    level: 2,
    hp: 160,
    mp: 105,
    skill: 'Пророк',
    description: 'Молодой лидер, верящий в свое пророчество и стремящийся создать мир без насилия.',
    quote: 'Я не хочу больше никого убивать.'
),
_createCard(
    id: 'e_057',
    characterName: 'Эйнар',
    animeName: 'Vinland Saga',
    imageUrl: 'https://shikimori.one/uploads/poster/characters/28030/main-10f2f2402da737efcc001594da20fa4d.webp',
    rarity: CardRarity.epic,
    power: 78,
    level: 2,
    hp: 155,
    mp: 100,
    skill: 'Фермер',
    description: 'Бывший раб, ставший другом Торфинна и нашедший смысл в мирной жизни.',
    quote: 'Мы должны построить дом. Своими руками.'
),
_createCard(
    id: 'e_058',
    characterName: 'Эмма',
    animeName: 'The Promised Neverland',
    imageUrl: 'https://shikimori.one/uploads/poster/characters/144337/main-6b3f98bc659ed50d60e095a14ef60563.webp',
    rarity: CardRarity.epic,
    power: 76,
    level: 2,
    hp: 150,
    mp: 110,
    skill: 'Оптимизм',
    description: 'Энергичная и добрая лидер детей, чья вера в спасение не знала границ.',
    quote: 'Мы не просто сбежим. Мы спасем всех!'
),
_createCard(
    id: 'e_059',
    characterName: 'Саичи Сугимото',
    animeName: 'Golden Kamuy',
    imageUrl: 'https://shikimori.one/uploads/poster/characters/138553/main-381e7a74b0d4d7819e7524d147ba924e.webp',
    rarity: CardRarity.epic,
    power: 82,
    level: 2,
    hp: 170,
    mp: 95,
    skill: 'Безумный Сугимото',
    description: 'Ветеран русско-японской войны, ищущий золото, чтобы исполнить обещание.',
    quote: 'Тот, кто выживет, будет прав!'
),
_createCard(
    id: 'e_060',
    characterName: 'Асирпа',
    animeName: 'Golden Kamuy',
    imageUrl: 'https://shikimori.one/uploads/poster/characters/138552/main-cb8038242bb5551080c887c8d1c44e17.webp',
    rarity: CardRarity.epic,
    power: 79,
    level: 2,
    hp: 150,
    mp: 105,
    skill: 'Охотница айнов',
    description: 'Девушка из народа айнов, помогающая Сугимото в его поисках.',
    quote: 'Мы не должны растрачивать дар жизни.'
),
_createCard(
    id: 'e_061',
    characterName: 'Ёситакэ Сираиси',
    animeName: 'Golden Kamuy',
    imageUrl: 'https://shikimori.one/uploads/poster/characters/138554/main-50326b9bf541da937484bece9d15cfa1.webp',
    rarity: CardRarity.epic,
    power: 75,
    level: 2,
    hp: 145,
    mp: 100,
    skill: 'Повар',
    description: 'Бывший солдат, ставший поваром и мастером выживания.',
    quote: 'Если ты хочешь выжить, ты должен есть всё.'
),
_createCard(
    id: 'e_062',
    characterName: 'Тосидзо Хидзиката',
    animeName: 'Golden Kamuy',
    imageUrl: 'https://shikimori.one/uploads/poster/characters/138492/main-a007e7ad3c31cf3aa574f2a01a6baafb.webp',
    rarity: CardRarity.epic,
    power: 83,
    level: 2,
    hp: 165,
    mp: 100,
    skill: 'Заместитель начальника',
    description: 'Заместитель начальника Синсэнгуми, одержимый майонезом и своим долгом.',
    quote: 'Майонез — это не просто соус, это образ жизни.'
),
_createCard(
    id: 'e_063',
    characterName: 'Вайолет Эвергарден',
    animeName: 'Violet Evergarden',
    imageUrl: 'https://shikimori.one/uploads/poster/characters/141354/main-253fd5d4beb3245037a0e70757e9932f.webp',
    rarity: CardRarity.epic,
    power: 78,
    level: 2,
    hp: 155,
    mp: 110,
    skill: 'Кукла-автомат',
    description: 'Бывший солдат, ставший "куклой-автоматом", чтобы понять значение слов "люблю тебя".',
    quote: 'Я хочу знать, что значит "люблю тебя".'
),
];

// 🟠 Легендарные карты (8% шанс выпадения)
static final List<AnimeCard> _legendaryCards = [
  _createCard(
    id: 'l_001', 
    characterName: 'Ичиго Куросаки', 
    animeName: 'Bleach', 
    imageUrl: 'https://shikimori.one/uploads/poster/characters/5/main-358025bb5e010cc5d91178e71af7fd89.webp', 
    rarity: CardRarity.legendary, 
    power: 100, 
    level: 5, 
    hp: 200, 
    mp: 120, 
    skill: 'Гэцуга Тэнсё', 
    description: 'Старшеклассник, ставший синигами для защиты людей от злых духов.', 
    quote: 'Если я защищу всех, то стану ли я сильнее?'
  ),
  _createCard(
    id: 'l_002', 
    characterName: 'Канаде Татибана', 
    animeName: 'Angel Beats!', 
    imageUrl: 'https://shikimori.one/uploads/poster/characters/22369/main-ab3a2c8046c4f290ae93af90397fbab8.webp', 
    rarity: CardRarity.legendary, 
    power: 98, 
    level: 5, 
    hp: 190, 
    mp: 115, 
    skill: 'Рука-клинок', 
    description: 'Загадочная девушка, известная как "Ангел", обладающая сверхъестественными способностями.', 
    quote: 'Спасибо, что подарил мне жизнь.'
  ),
  _createCard(
    id: 'l_003', 
    characterName: 'Курису Макисэ', 
    animeName: 'Steins;Gate', 
    imageUrl: 'https://shikimori.one/uploads/poster/characters/34470/main-4dca34b2c9c95acdf4b8f0d01031c3b0.webp', 
    rarity: CardRarity.legendary, 
    power: 97, 
    level: 5, 
    hp: 185, 
    mp: 120, 
    skill: 'Гений нейробиологии', 
    description: 'Талантливая исследовательница, которая помогает создать машину времени.', 
    quote: 'Время — это река, но иногда она меняет своё русло.'
  ),
  _createCard(
    id: 'l_004', 
    characterName: 'Кэн Канэки', 
    animeName: 'Tokyo Ghoul', 
    imageUrl: 'https://shikimori.one/uploads/poster/characters/87275/main-d674316a487edca0b8ae336560355b95.webp', 
    rarity: CardRarity.legendary, 
    power: 99, 
    level: 5, 
    hp: 200, 
    mp: 110, 
    skill: 'Одноглазый гуль', 
    description: 'Студент, ставший полугулем после трагического инцидента.', 
    quote: 'Что не так со мной, а не с этим миром?'
  ),
  _createCard(
    id: 'l_005', 
    characterName: 'Сайтама', 
    animeName: 'One-Punch Man', 
    imageUrl: 'https://shikimori.one/uploads/poster/characters/73935/main-2ded9d7e330eedb453947116ee5c53c8.webp', 
    rarity: CardRarity.legendary, 
    power: 105, 
    level: 5, 
    hp: 250, 
    mp: 100, 
    skill: 'Обычный удар', 
    description: 'Герой, который может победить любого врага одним ударом, из-за чего страдает от скуки.', 
    quote: 'Я просто герой по приколу.'
  ),
  _createCard(
    id: 'l_006', 
    characterName: 'Гон Фрикс', 
    animeName: 'Hunter x Hunter', 
    imageUrl: 'https://shikimori.one/uploads/poster/characters/30/main-7bc83b3786ded5a2bfa5dfd2866fb448.webp', 
    rarity: CardRarity.legendary, 
    power: 96, 
    level: 5, 
    hp: 195, 
    mp: 105, 
    skill: 'Камень-ножницы-бумага', 
    description: 'Мальчик, который становится Охотником, чтобы найти своего отца.', 
    quote: 'Я не хочу ничего отнимать, но и своё не отдам!'
  ),
  _createCard(
    id: 'l_007', 
    characterName: 'Наруто Узумаки', 
    animeName: 'Naruto', 
    imageUrl: 'https://shikimori.one/uploads/poster/characters/17/main-387459bc8fea5fb07c9dd344cc449ef3.webp', 
    rarity: CardRarity.legendary, 
    power: 102, 
    level: 5, 
    hp: 220, 
    mp: 150, 
    skill: 'Режим Мудреца Шести Путей', 
    description: 'Ниндзя, который прошёл путь от изгоя до героя, спасшего мир.', 
    quote: 'Я никогда не отказываюсь от своих слов! Это мой путь ниндзя!'
  ),
  _createCard(
    id: 'l_008', 
    characterName: 'Миюки Сироганэ', 
    animeName: 'Kaguya-sama: Love is War', 
    imageUrl: 'https://shikimori.one/uploads/poster/characters/136685/main-f92c35c7f62ab97094e63eaa86193674.webp', 
    rarity: CardRarity.legendary, 
    power: 98, 
    level: 5, 
    hp: 190, 
    mp: 115, 
    skill: 'Гений-трудоголик', 
    description: 'Президент студсовета, который благодаря упорному труду стал лучшим учеником.', 
    quote: 'Даже в хаосе есть своя логика.'
  ),
  _createCard(
    id: 'l_010', 
    characterName: 'Гильгамеш', 
    animeName: 'Fate/Zero', 
    imageUrl: 'https://shikimori.one/uploads/poster/characters/2514/main-d2e4a4657e0b6d8ca0ab06023b0e9218.webp', 
    rarity: CardRarity.legendary, 
    power: 101, 
    level: 5, 
    hp: 210, 
    mp: 140, 
    skill: 'Врата Вавилона', 
    description: 'Древнейший король и герой, владеющий всеми сокровищами мира.', 
    quote: 'Все сокровища этого мира принадлежат мне.'
  ),
  _createCard(
    id: 'l_011', 
    characterName: 'Лелуш Ламперуж', 
    animeName: 'Code Geass', 
    imageUrl: 'https://shikimori.one/uploads/poster/characters/417/main-891953585a4a87b2e3771003571aad85.webp', 
    rarity: CardRarity.legendary, 
    power: 104, 
    level: 5, 
    hp: 190, 
    mp: 160, 
    skill: 'Гиасс', 
    description: 'Изгнанный принц, получивший силу абсолютного подчинения и начавший войну против империи.', 
    quote: 'Чтобы победить зло, я сам стану ещё большим злом.'
  ),
  _createCard(
    id: 'l_012', 
    characterName: 'Сигэо Кагэяма (Моб)', 
    animeName: 'Mob Psycho 100', 
    imageUrl: 'https://shikimori.one/uploads/poster/characters/109929/main-42c3bdaf2b018b3870407eeec7f4d08e.webp', 
    rarity: CardRarity.legendary, 
    power: 99, 
    level: 5, 
    hp: 200, 
    mp: 130, 
    skill: 'Психическая сила 100%', 
    description: 'Скромный школьник с невероятными экстрасенсорными способности.', 
    quote: 'Я — главный герой своей собственной жизни.'
  ),
  _createCard(
    id: 'l_013', 
    characterName: 'Алукард', 
    animeName: 'Hellsing Ultimate', 
    imageUrl: 'https://shikimori.one/uploads/poster/characters/601/main-3c14b48c67494d7875c68e873427ab2a.webp', 
    rarity: CardRarity.legendary, 
    power: 105, 
    level: 5, 
    hp: 240, 
    mp: 120, 
    skill: 'Древний вампир', 
    description: 'Могущественный вампир на службе организации "Хеллсинг", сражающийся с нечистью.', 
    quote: 'Быть монстром — значит быть свободным.'
  ),
  _createCard(
    id: 'l_014', 
    characterName: 'Эсканор', 
    animeName: 'The Seven Deadly Sins', 
    imageUrl: 'https://shikimori.one/uploads/poster/characters/95985/main-91918300bdbdb40f8cb25e047a084e87.webp', 
    rarity: CardRarity.legendary, 
    power: 103, 
    level: 5, 
    hp: 220, 
    mp: 110, 
    skill: 'Солнце', 
    description: 'Член Семи Смертных Грехов, чья сила достигает пика в полдень.', 
    quote: 'Кто это решил?'
  ),
  _createCard(
    id: 'l_015', 
    characterName: 'Сатору Годзё', 
    animeName: 'Jujutsu Kaisen', 
    imageUrl: 'https://shikimori.one/uploads/poster/characters/164471/main-ff03336e8f1bda13d3dae5a252478768.webp', 
    rarity: CardRarity.legendary, 
    power: 104, 
    level: 5, 
    hp: 210, 
    mp: 150, 
    skill: 'Безграничность', 
    description: 'Сильнейший маг современности, обладающий уникальными техниками.', 
    quote: 'Всё будет в порядке. Ведь я — сильнейший.'
  ),
  _createCard(
    id: 'l_016', 
    characterName: 'Джозеф Джостар', 
    animeName: 'JoJo\'s Bizarre Adventure', 
    imageUrl: 'https://shikimori.one/uploads/poster/characters/6356/main-0c50b9fdb298d47cd9cf0ea872fd114c.webp', 
    rarity: CardRarity.legendary, 
    power: 98, 
    level: 5, 
    hp: 195, 
    mp: 115, 
    skill: 'Хамон и хитрость', 
    description: 'Эксцентричный и хитрый боец, который может предсказать слова противника.', 
    quote: 'Твоя следующая фраза будет...'
  ),
  _createCard(
    id: 'l_017', 
    characterName: 'Спайк Шпигель', 
    animeName: 'Cowboy Bebop', 
    imageUrl: 'https://shikimori.one/uploads/poster/characters/1/main-a65e1eb84efdb3231215a33d3230d276.webp', 
    rarity: CardRarity.legendary, 
    power: 97, 
    level: 5, 
    hp: 190, 
    mp: 100, 
    skill: 'Охотник за головами', 
    description: '"Космический ковбой" с тёмным прошлым, скрывающийся от него.', 
    quote: 'Увидишься — увидимся, космический ковбой...'
  ),
  _createCard(
    id: 'l_018', 
    characterName: 'Вэш Ураган', 
    animeName: 'Trigun', 
    imageUrl: 'https://shikimori.one/uploads/poster/characters/162/main-7b0587842ca4fe6f36c54f7d188fbd33.webp', 
    rarity: CardRarity.legendary, 
    power: 99, 
    level: 5, 
    hp: 200, 
    mp: 120, 
    skill: 'Гуманоидный Тайфун', 
    description: 'Легендарный стрелок с наградой в \$\$60 миллиардов за его голову, который при этом пацифист.', 
    quote: 'Этот мир создан из любви и мира!'
  ),
  _createCard(
    id: 'l_020', 
    characterName: 'Обезьяна Д. Луффи', 
    animeName: 'One Piece', 
    imageUrl: 'https://shikimori.one/uploads/poster/characters/40/main-9f10a841558a8df79499a0f7d3362224.webp', 
    rarity: CardRarity.legendary, 
    power: 102, 
    level: 5, 
    hp: 230, 
    mp: 110, 
    skill: 'Резиновый фрукт', 
    description: 'Капитан пиратов Соломенной Шляпы, мечтающий стать Королём Пиратов.', 
    quote: 'Я стану Королём Пиратов!'
  ),
  _createCard(
    id: 'l_021',
    characterName: 'Нэдзуко Камадо',
    animeName: 'Demon Slayer',
    imageUrl: 'https://shikimori.one/uploads/poster/characters/146157/main-f131ce77d807f5eec4bfd263ebe254e7.webp',
    rarity: CardRarity.legendary,
    power: 82,
    level: 3,
    hp: 160,
    mp: 110,
    skill: 'Кровавая магия',
    description: 'Девушка, обращенная в демона, но сохранившая человечность и любовь к брату.',
    quote: '*Мурчит*'
),
_createCard(
    id: 'l_022',
    characterName: 'Гию Томиока',
    animeName: 'Demon Slayer',
    imageUrl: 'https://shikimori.one/uploads/poster/characters/146735/main-c1fd1cba0a9b977415336b8efd0878a4.webp',
    rarity: CardRarity.legendary,
    power: 85,
    level: 3,
    hp: 170,
    mp: 115,
    skill: 'Дыхание воды',
    description: 'Столп воды, первым встретивший Танджиро и давший ему надежду.',
    quote: 'Не сдавайся.'
),
_createCard(
    id: 'l_023',
    characterName: 'Кёдзюро Рэнгоку',
    animeName: 'Demon Slayer',
    imageUrl: 'https://shikimori.one/uploads/poster/characters/151143/main-b2038338e3f050995e56c08f08568941.webp',
    rarity: CardRarity.legendary,
    power: 86,
    level: 3,
    hp: 175,
    mp: 110,
    skill: 'Пламенное дыхание',
    description: 'Столп пламени, чья несокрушимая воля и доброта вдохновляют других.',
    quote: 'Огре, гори ярче! Пусть твои пламенные страсти станут твоей силой!'
),
_createCard(
    id: 'l_024',
    characterName: 'Пауэр',
    animeName: 'Chainsaw Man',
    imageUrl: 'https://shikimori.one/uploads/poster/characters/170733/main-da6de56b1e640722723a484e5eb6b145.webp',
    rarity: CardRarity.legendary,
    power: 84,
    level: 3,
    hp: 165,
    mp: 105,
    skill: 'Бой на крови',
    description: 'Дьявол-свинка, обожающая деньги, насилие и своего верного спутника Дэндзи.',
    quote: 'Я победила! Теперь дай мне деньги!'
),
_createCard(
    id: 'l_025',
    characterName: 'Рика Оримото',
    animeName: 'Jujutsu Kaisen 0',
    imageUrl: 'https://shikimori.one/uploads/poster/characters/189234/main-7f74c4a5ac4d7ab132bfade53179d6a5.webp',
    rarity: CardRarity.legendary,
    power: 90,
    level: 3,
    hp: 180,
    mp: 100,
    skill: 'Проклятая любовь',
    description: 'Особый проклятый дух, рожденный из всепоглощающей любви к Юте.',
    quote: 'Ты мой, Юта.'
),
_createCard(
    id: 'l_026',
    characterName: 'Юта Оккоцу',
    animeName: 'Jujutsu Kaisen 0',
    imageUrl: 'https://shikimori.one/uploads/poster/characters/168067/main-6a5926ea4923000351aaa65376ec1743.webp',
    rarity: CardRarity.legendary,
    power: 87,
    level: 3,
    hp: 170,
    mp: 125,
    skill: 'Проклятая речь',
    description: 'Сильнейший маг своего времени, проклятый своим духом-возлюбленной.',
    quote: 'Я сломаю тебе каждую косточку.'
),
_createCard(
    id: 'l_027',
    characterName: 'Эндзи Тодороки',
    animeName: 'My Hero Academia',
    imageUrl: 'https://shikimori.one/uploads/poster/characters/141624/main-bb187033a57c6314adcc769a51318856.webp',
    rarity: CardRarity.legendary,
    power: 91,
    level: 3,
    hp: 185,
    mp: 110,
    skill: 'Адское пламя',
    description: 'Нынешущий номер один герой, стремящийся искупить свои прошлые ошибки.',
    quote: 'Пламя, которое сжигает всё... моё пламя!'
),
_createCard(
    id: 'l_028',
    characterName: 'Генос',
    animeName: 'One-Punch Man',
    imageUrl: 'https://shikimori.one/uploads/poster/characters/73979/main-70ae39ec07a74b4d5cddec99aae959fe.webp',
    rarity: CardRarity.legendary,
    power: 88,
    level: 3,
    hp: 175,
    mp: 120,
    skill: 'Пожиратель машин',
    description: 'Цифровой киборг, ставший учеником Сайтамы в поисках абсолютной силы.',
    quote: 'Сенсей!'
),
_createCard(
    id: 'l_029',
    characterName: 'Банг',
    animeName: 'One-Punch Man',
    imageUrl: 'https://shikimori.one/uploads/poster/characters/81141/main-918f6a2b8248964d1bb4f7f38bb8d6af.webp',
    rarity: CardRarity.legendary,
    power: 86,
    level: 3,
    hp: 180,
    mp: 100,
    skill: 'Переплавка потока',
    description: 'Мастер боевых искусств, один из сильнейших героев S-класса.',
    quote: 'Хорошо, я покажу тебе... мою силу.'
),
_createCard(
    id: 'l_030',
    characterName: 'Король',
    animeName: 'One-Punch Man',
    imageUrl: 'https://shikimori.one/uploads/poster/characters/94239/main-66dee51e4373e65ff5c9370a48edcc9e.webp',
    rarity: CardRarity.legendary,
    power: 85,
    level: 3,
    hp: 170,
    mp: 110,
    skill: 'Корольский движ',
    description: 'Герой S-класса, чья репутация сильнейшего держится на невероятной удаче.',
    quote: 'Моя машина... она сломалась.'
),
_createCard(
    id: 'l_031',
    characterName: 'Ханджи Зое',
    animeName: 'Attack on Titan',
    imageUrl: 'https://shikimori.one/uploads/poster/characters/71121/main-04a3e4c7f721ed489a778d1906cf513b.webp',
    rarity: CardRarity.legendary,
    power: 84,
    level: 3,
    hp: 165,
    mp: 130,
    skill: 'Наука о титанах',
    description: '14-й командир Разведкорпуса, одержимая изучением титанов.',
    quote: 'Титаны это невероятно!'
),
_createCard(
    id: 'l_032',
    characterName: 'Армин Арлерт',
    animeName: 'Attack on Titan',
    imageUrl: 'https://shikimori.one/uploads/poster/characters/46494/main-7ebe23aa562e4c364d372a41b16cfe30.webp',
    rarity: CardRarity.legendary,
    power: 78,
    level: 3,
    hp: 150,
    mp: 135,
    skill: 'Стратегический гений',
    description: 'Блестящий тактик, чей интеллект спасает отряд в самых безвыходных ситуациях.',
    quote: 'Это не стена... это титан!'
),
_createCard(
    id: 'l_033',
    characterName: 'Рой Мустанг',
    animeName: 'Fullmetal Alchemist: Brotherhood',
    imageUrl: 'https://shikimori.one/uploads/poster/characters/68/main-09785420ba993f553e9b275638f25abb.webp',
    rarity: CardRarity.legendary,
    power: 85,
    level: 3,
    hp: 170,
    mp: 125,
    skill: 'Пламя',
    description: 'Амбициозный государственный алхимик, известный как "Пламенный алхимик".',
    quote: 'Идет дождь... Плачь, солдат!'
),
_createCard(
    id: 'l_034',
    characterName: 'Ван Хоэнхайм',
    animeName: 'Fullmetal Alchemist: Brotherhood',
    imageUrl: 'https://shikimori.one/uploads/poster/characters/9792/main-05d167756ea0a98bfab0c67fe8b7563e.webp',
    rarity: CardRarity.legendary,
    power: 89,
    level: 3,
    hp: 180,
    mp: 120,
    skill: 'Философский камень',
    description: 'Отец Эдварда и Алфонса, живущий уже несколько веков и несущий в себе душу Ксерксеса.',
    quote: 'Я — философский камень.'
),
_createCard(
    id: 'l_035',
    characterName: 'C.C.',
    animeName: 'Code Geass: Lelouch of the Rebellion',
    imageUrl: 'https://shikimori.one/uploads/poster/characters/1111/main-3ad68c204fa87ab2740188bce15673f2.webp',
    rarity: CardRarity.legendary,
    power: 80,
    level: 3,
    hp: 160,
    mp: 140,
    skill: 'Код Геасс',
    description: 'Бессмертная ведьма, давшая Лелушу силу Геасса и ставшая его союзником.',
    quote: 'Правильно, Лелуш. Геасс — это как желание.'
),
_createCard(
    id: 'l_036',
    characterName: 'Сузаку Куруруги',
    animeName: 'Code Geass: Lelouch of the Rebellion',
    imageUrl: 'https://shikimori.one/uploads/poster/characters/559/main-bcde987d57cc0d842df7945ef972292a.webp',
    rarity: CardRarity.legendary,
    power: 86,
    level: 3,
    hp: 175,
    mp: 105,
    skill: 'Живое гео',
    description: 'Лучший пилот Британии, друг Лелуша, выбравший путь изменения системы изнутри.',
    quote: 'Я изменю этот мир изнутри!'
),
_createCard(
    id: 'l_037',
    characterName: 'Нацуки Субару',
    animeName: 'Re:Zero - Starting Life in Another World',
    imageUrl: 'https://shikimori.one/uploads/poster/characters/118735/main-b5f3ac7708c437b6e6422b02c6c3eab8.webp',
    rarity: CardRarity.legendary,
    power: 79,
    level: 3,
    hp: 155,
    mp: 130,
    skill: 'Возвращение из ниоткуда',
    description: 'Юноша, перенесенный в другой мир, с силой возрождаться после смерти.',
    quote: 'Я считаю, что отчаиваться — это признак слабости.'
),
_createCard(
    id: 'l_038',
    characterName: 'Рудэус Грейрат',
    animeName: 'Mushoku Tensei: Jobless Reincarnation',
    imageUrl: 'https://shikimori.one/uploads/poster/characters/111245/main-4067a0a1c118898f9180f30f11f28856.webp',
    rarity: CardRarity.legendary,
    power: 84,
    level: 3,
    hp: 165,
    mp: 125,
    skill: 'Безграничная магия',
    description: 'Безработный, переродившийся в мире магии и решивший прожить эту жизнь без сожалений.',
    quote: 'В прошлой жизни я был никем. В этой я постараюсь стать кем-то.'
),
_createCard(
    id: 'l_039',
    characterName: 'Ферн',
    animeName: 'Frieren: Beyond Journey\'s End',
    imageUrl: 'https://shikimori.one/uploads/poster/characters/188176/main-e7a8ba54453cf71ef60ec1586fc1b5ea.webp',
    rarity: CardRarity.legendary,
    power: 85,
    level: 3,
    hp: 160,
    mp: 135,
    skill: 'Магия обороны',
    description: 'Ученица Фрирен, невероятно талантливый и серьезный маг-воин.',
    quote: 'Фрирен-сама, вы опять отвлеклись.'
),
_createCard(
    id: 'l_040',
    characterName: 'Штарк',
    animeName: 'Frieren: Beyond Journey\'s End',
    imageUrl: 'https://shikimori.one/uploads/poster/characters/188177/main-6a486aff06aa67aeb422a1ecd8a50301.webp',
    rarity: CardRarity.legendary,
    power: 83,
    level: 3,
    hp: 170,
    mp: 115,
    skill: 'Призыв',
    description: 'Спутник Фрирен, душа дракона, ставший человеком и прекрасным воином.',
    quote: 'Я всегда буду рядом.'
),
_createCard(
    id: 'l_041',
    characterName: 'Торфинн Карлсэфни',
    animeName: 'Vinland Saga',
    imageUrl: 'https://shikimori.one/uploads/poster/characters/10138/main-41093eaf51dcd922d34e61fe36e716ac.webp',
    rarity: CardRarity.legendary,
    power: 86,
    level: 3,
    hp: 175,
    mp: 100,
    skill: 'Путь воина',
    description: 'Бывший наемник, ищущий путь к миру и земле обетованной — Винланду.',
    quote: 'У меня нет врагов. Я больше не буду никого убивать.'
),
_createCard(
    id: 'l_042',
    characterName: 'Аскеладд',
    animeName: 'Vinland Saga',
    imageUrl: 'https://shikimori.one/uploads/poster/characters/13020/main-26a905da5654df9f4a988f4c72097f67.webp',
    rarity: CardRarity.legendary,
    power: 87,
    level: 3,
    hp: 180,
    mp: 110,
    skill: 'Мудрость викинга',
    description: 'Мудрый и хитрый викинг, наставник Торфинна, видевший многое в своей жизни.',
    quote: 'Настоящий воин не нуждается в мече.'
),
_createCard(
    id: 'l_043',
    characterName: 'Норман',
    animeName: 'The Promised Neverland',
    imageUrl: 'https://shikimori.one/uploads/poster/characters/144916/main-b01a5607bbf627371b10a6f2fb1bf077.webp',
    rarity: CardRarity.legendary,
    power: 82,
    level: 3,
    hp: 155,
    mp: 130,
    skill: 'Стратегия',
    description: 'Гениальный ребенок, создавший план побега из сиротского дома и ставший лидером сопротивления.',
    quote: 'Мы сбежим отсюда. Все мы.'
),
_createCard(
    id: 'l_044',
    characterName: 'Рэй',
    animeName: 'The Promised Neverland',
    imageUrl: 'https://shikimori.one/uploads/poster/characters/144919/main-0a1b474133a861cf9d5c1d6b9beca841.webp',
    rarity: CardRarity.legendary,
    power: 80,
    level: 3,
    hp: 160,
    mp: 125,
    skill: 'Тактика',
    description: 'Спокойная и рассудительная девочка, мастер планирования и поддержки.',
    quote: 'Эмма — это солнце. Я всегда буду следовать за ней.'
),
_createCard(
    id: 'l_045',
    characterName: 'Изабелла',
    animeName: 'The Promised Neverland',
    imageUrl: 'https://shikimori.one/uploads/poster/characters/144999/main-328994a0470e037657c05d9d09060e94.webp',
    rarity: CardRarity.legendary,
    power: 81,
    level: 3,
    hp: 165,
    mp: 120,
    skill: 'Материнская любовь',
    description: 'Мамаша приюта "Грейс Филд", чья истинная суть гораздо страшнее, чем кажется.',
    quote: 'Пойте, мои дети. Пойте.'
),
_createCard(
    id: 'l_046',
    characterName: 'Такэмитти Ханагаки',
    animeName: 'Tokyo Revengers',
    imageUrl: 'https://shikimori.one/uploads/poster/characters/171969/main-8d0d6c4ea04d160849f3927609fc2520.webp',
    rarity: CardRarity.legendary,
    power: 77,
    level: 3,
    hp: 150,
    mp: 135,
    skill: 'Прыжок во времени',
    description: 'Неудачник, получивший возможность путешествовать в прошлое, чтобы спасти свою девушку.',
    quote: 'Я всё исправлю!'
),
_createCard(
    id: 'l_047',
    characterName: 'Мандзиро "Майки" Сано',
    animeName: 'Tokyo Revengers',
    imageUrl: 'https://shikimori.one/uploads/poster/characters/175294/main-ad796cb433f0cf547d2654aebb44ea05.webp',
    rarity: CardRarity.legendary,
    power: 84,
    level: 3,
    hp: 170,
    mp: 105,
    skill: 'Беспредельный президент',
    description: 'Харизматичный лидер банды "Томан", обладающий невероятной харизмой.',
    quote: 'Если ты трус, ты можешь бежать, когда захочешь.'
),
_createCard(
    id: 'l_048',
    characterName: 'Кэн "Дракон" Рюгудзи',
    animeName: 'Tokyo Revengers',
    imageUrl: 'https://i.pinimg.com/736x/14/0b/72/140b72c23c1afc51703c5ab22bf0807b.jpg',
    rarity: CardRarity.legendary,
    power: 85,
    level: 3,
    hp: 175,
    mp: 100,
    skill: 'Сила Дракона',
    description: 'Лучший друг Майки и танк банды "Томан", обладающий огромной физической силой.',
    quote: 'Кто посмеет обидеть моих друзей, умрет.'
),
_createCard(
    id: 'l_049',
    characterName: 'Курапика',
    animeName: 'Hunter x Hunter',
    imageUrl: 'https://shikimori.one/uploads/poster/characters/28/main-4fce0e4e732ed2e6248a01ddb7eee22a.webp',
    rarity: CardRarity.legendary,
    power: 86,
    level: 3,
    hp: 165,
    mp: 120,
    skill: 'Алые глаза',
    description: 'Последний представитель клана Курта, ищущий мести и отомщенный за своих близких.',
    quote: 'Я не буду щадить тебя. Я не буду прощать тебя.'
),
_createCard(
    id: 'l_050',
    characterName: 'Леорио Паладиннайт',
    animeName: 'Hunter x Hunter',
    imageUrl: 'https://shikimori.one/uploads/poster/characters/29/main-0587b974d7424ee2f0f2ff4ed700691a.webp',
    rarity: CardRarity.legendary,
    power: 78,
    level: 3,
    hp: 160,
    mp: 110,
    skill: 'Доктор',
    description: 'Друг Гона и Киллуа, стремящийся стать врачом, чтобы лечить людей бесплатно.',
    quote: 'Деньги не приносят счастья... но они могут купить лекарства!'
),
_createCard(
    id: 'l_051',
    characterName: 'Гохан',
    animeName: 'Dragon Ball Z',
    imageUrl: 'https://shikimori.one/uploads/poster/characters/2093/main-532ffe679da674daa6f678d2a6f95ae2.webp',
    rarity: CardRarity.legendary,
    power: 89,
    level: 3,
    hp: 180,
    mp: 115,
    skill: 'Потенциал',
    description: 'Старший сын Гоку, обладающий огромным скрытым потенциалом.',
    quote: 'Вы причинили боль моим друзьям... и моей маме!'
),
_createCard(
    id: 'l_052',
    characterName: 'Пикколо',
    animeName: 'Dragon Ball Z',
    imageUrl: 'https://shikimori.one/uploads/poster/characters/914/main-4674710b7bb5cd5999ec201ef806797b.webp',
    rarity: CardRarity.legendary,
    power: 86,
    level: 3,
    hp: 175,
    mp: 120,
    skill: 'Маканкосаппо',
    description: 'Бывший враг Гоку, ставший его верным союзником и наставником Гохана.',
    quote: 'Я Namek... нет, я — Namek... и я — Дэмон Пикколо!'
),
_createCard(
    id: 'l_053',
    characterName: 'Транкс',
    animeName: 'Dragon Ball Z',
    imageUrl: 'https://shikimori.one/uploads/poster/characters/2707/main-cc47bd991bd545658052c8992c6cda5e.webp',
    rarity: CardRarity.legendary,
    power: 87,
    level: 3,
    hp: 170,
    mp: 110,
    skill: 'Бросок меча',
    description: 'Путешественник из будущего, пришедший предупредить о катастрофе.',
    quote: 'Я не позволю тебе уничтожить мое будущее!'
),
_createCard(
    id: 'l_054',
    characterName: 'Селл',
    animeName: 'Dragon Ball Z',
    imageUrl: 'https://shikimori.one/uploads/poster/characters/3908/main-2af0d75412fc55f30feec5bfeb45c2e9.webp',
    rarity: CardRarity.legendary,
    power: 90,
    level: 3,
    hp: 185,
    mp: 105,
    skill: 'Идеальный организм',
    description: 'Биоандроид, считающий себя совершенным созданием, созданным для поглощения.',
    quote: 'Я совершенство! Я — Селл!'
),
_createCard(
    id: 'l_055',
    characterName: 'Броли',
    animeName: 'Dragon Ball Super: Broly',
    imageUrl: 'https://shikimori.one/uploads/poster/characters/4945/main-8617d253a58ae22429f4437524db0c76.webp',
    rarity: CardRarity.legendary,
    power: 95,
    level: 3,
    hp: 190,
    mp: 90,
    skill: 'Легендарный Супер-Сайян',
    description: 'Легендарный Супер-Сайян с невероятной силой, которую не может контролировать.',
    quote: 'АААААРРРГГГХ!'
),
_createCard(
    id: 'l_056',
    characterName: 'Нами',
    animeName: 'One Piece',
    imageUrl: 'https://shikimori.one/uploads/poster/characters/723/main-4c872ccc219486c0503107721814c750.webp',
    rarity: CardRarity.legendary,
    power: 70,
    level: 3,
    hp: 140,
    mp: 130,
    skill: 'Климат-такт',
    description: 'Навигатор команды Соломона, мечтающая нарисовать карту всего мира.',
    quote: 'Деньги и женщины! Я хочу их все!'
),
_createCard(
    id: 'l_057',
    characterName: 'Тони Тони Чоппер',
    animeName: 'One Piece',
    imageUrl: 'https://shikimori.one/uploads/poster/characters/309/main-2cd84113e0958e4e9612fc2f3d9fa687.webp',
    rarity: CardRarity.legendary,
    power: 75,
    level: 3,
    hp: 150,
    mp: 125,
    skill: 'Точка усиления',
    description: 'Доктор команды Соломона, олень-человек, съевший плод человека.',
    quote: 'Не называй меня оленем!'
),
_createCard(
    id: 'l_058',
    characterName: 'Рукия Кучики',
    animeName: 'Bleach',
    imageUrl: 'https://shikimori.one/uploads/poster/characters/6/main-d8b464c5e9267296234822c76f530555.webp',
    rarity: CardRarity.legendary,
    power: 82,
    level: 3,
    hp: 160,
    mp: 120,
    skill: 'Сомэномэ',
    description: 'Шинигами, передавшая свои силы Ичиго и изменившая его судьбу.',
    quote: 'Я буду защищать тебя, Ичиго.'
),
_createCard(
    id: 'l_059',
    characterName: 'Бьякуя Кучики',
    animeName: 'Bleach',
    imageUrl: 'https://shikimori.one/uploads/poster/characters/907/main-3ece9549b00404773e4f3c4d7f057515.webp',
    rarity: CardRarity.legendary,
    power: 86,
    level: 3,
    hp: 170,
    mp: 115,
    skill: 'Сэньбонзакура',
    description: 'Величественный капитан 6-го отряда, мастер высокоскоростных атак.',
    quote: 'Прощай, Рукия.'
),
_createCard(
    id: 'l_060',
    characterName: 'Вэш Ураган',
    animeName: 'Trigun',
    imageUrl: 'https://shikimori.one/uploads/poster/characters/162/main-7b0587842ca4fe6f36c54f7d188fbd33.webp',
    rarity: CardRarity.legendary,
    power: 88,
    level: 3,
    hp: 175,
    mp: 110,
    skill: 'Ангельская рука',
    description: 'Легендарный разрушитель планет, клянущийся не убивать никого.',
    quote: 'Любовь и мир!'
),
_createCard(
    id: 'l_061',
    characterName: 'Дэвид Мартинес',
    animeName: 'Cyberpunk: Edgerunners',
    imageUrl: 'https://shikimori.one/uploads/poster/characters/213390/main-38c7000b1180153f71d2892268e5e706.webp',
    rarity: CardRarity.legendary,
    power: 84,
    level: 3,
    hp: 165,
    mp: 105,
    skill: 'Сандевистан',
    description: 'Уличный паук из Найт-Сити, вставший на путь бунта ради выживания.',
    quote: 'Давай устроим им ад!'
),
_createCard(
    id: 'l_062',
    characterName: 'Люсина Кусинада',
    animeName: 'Cyberpunk: Edgerunners',
    imageUrl: 'https://shikimori.one/uploads/poster/characters/213159/main-f33b3c8b73e211dbd349f73208779bad.webp',
    rarity: CardRarity.legendary,
    power: 78,
    level: 3,
    hp: 150,
    mp: 120,
    skill: 'Нетраннер',
    description: 'Мечтательница, сбежавшая от корпораций и ставшая наставницей Дэвида.',
    quote: 'В Найт-Сити у тебя нет будущего.'
),
_createCard(
    id: 'l_063',
    characterName: 'Иллиясфиль фон Айнцберн',
    animeName: 'Fate/stay night: Unlimited Blade Works',
    imageUrl: 'https://shikimori.one/uploads/poster/characters/503/main-38eaf8d7ba06c850adf4a9ce801ce99f.webp',
    rarity: CardRarity.legendary,
    power: 81,
    level: 3,
    hp: 155,
    mp: 135,
    skill: 'Магия ювелира',
    description: 'Юная госпожа, участвующая в Войне за Грааль с невероятной силой.',
    quote: 'Это мой приказ, как твоего мастера!'
),
];

// 🟡 Мифические карты (~1.9% шанс выпадения)
static final List<AnimeCard> _mythicCards = [
  _createCard(
    id: 'm_001', 
    characterName: 'Сон Гоку (Ультра Инстинкт)', 
    animeName: 'Dragon Ball Super', 
    imageUrl: 'https://shikimori.one/uploads/poster/characters/246/main-db64a47a77e5cf93ac52e6622e239092.webp', 
    rarity: CardRarity.mythic, 
    power: 115, 
    level: 6, 
    hp: 280, 
    mp: 180, 
    skill: 'Автономный Ультра Инстинкт', 
    description: 'Состояние, позволяющее телу двигаться и сражаться независимо от мыслей и эмоций.', 
    quote: 'Пределов нет! Я могу стать ещё сильнее!'
  ),
  _createCard(
    id: 'm_002', 
    characterName: 'Мадока Канаме (Богиня)', 
    animeName: 'Puella Magi Madoka Magica', 
    imageUrl: 'https://static.wikia.nocookie.net/anime-characters-fight/images/e/ef/Ultidoka1.png/revision/latest?cb=20160214173140&path-prefix=ru', 
    rarity: CardRarity.mythic, 
    power: 112, 
    level: 6, 
    hp: 270, 
    mp: 190, 
    skill: 'Закон Цикла', 
    description: 'Стала божественной сущностью, чтобы спасти всех волшебниц от отчаяния.', 
    quote: 'Я хочу стереть всех ведьм до их рождения. Всех до единой, во всех вселенных.'
  ),
  _createCard(
    id: 'm_003', 
    characterName: 'Минако Айно (Вечная)', 
    animeName: 'Sailor Moon', 
    imageUrl: 'https://shikimori.one/uploads/poster/characters/2826/main-e34c5882bca36de21de1cdca1e730322.webp', 
    rarity: CardRarity.mythic, 
    power: 110, 
    level: 6, 
    hp: 275, 
    mp: 185, 
    skill: 'Серебряный Лунный Кристалл', 
    description: 'Высшая форма воительницы в матроске, обладающая силой звёзд.', 
    quote: 'Во имя Луны я несу возмездие!'
  ),
  _createCard(
    id: 'm_004', 
    characterName: 'Анти-Спиральщик', 
    animeName: 'Gurren Lagann', 
    imageUrl: 'https://shikimori.one/uploads/poster/characters/5115/main-0a42990e1e9fd70018659ea9c01853cd.webp', 
    rarity: CardRarity.mythic, 
    power: 118, 
    level: 6, 
    hp: 290, 
    mp: 200, 
    skill: 'Анти-Спиральная энергия', 
    description: 'Коллективное сознание расы, отказавшейся от эволюции ради стабильности вселенной.', 
    quote: 'Спиральная энергия — это путь к разрушению. Мы должны остановить её.'
  ),
  _createCard(
    id: 'm_005', 
    characterName: 'Тэцуо Сима', 
    animeName: 'Akira', 
    imageUrl: 'https://shikimori.one/uploads/poster/characters/2589/main-fc3c734986a9c412c6e415f2fb6427b1.webp', 
    rarity: CardRarity.mythic, 
    power: 113, 
    level: 6, 
    hp: 260, 
    mp: 185, 
    skill: 'Психическая сверхсила', 
    description: 'Подросток, получивший богоподобные психокинетические способности.', 
    quote: 'Я... Тэцуо.'
  ),
  _createCard(
    id: 'm_006', 
    characterName: 'Отец', 
    animeName: 'Fullmetal Alchemist', 
    imageUrl: 'https://shikimori.one/uploads/poster/characters/15542/main-1b0396c52b2fc6dc849aec0a134032df.webp', 
    rarity: CardRarity.mythic, 
    power: 116, 
    level: 6, 
    hp: 285, 
    mp: 195, 
    skill: 'Поглощение Бога', 
    description: 'Гомункул, стремившийся поглотить сущность Бога и стать совершенным существом.', 
    quote: 'Я — тот, кто стоит над всем сущим.'
  ),
  _createCard(
    id: 'm_007', 
    characterName: 'Лайт Ягами (Кира)', 
    animeName: 'Death Note', 
    imageUrl: 'https://static.wikia.nocookie.net/deathnote/images/5/54/Light_YagamiHD.jpg/revision/latest/scale-to-width-down/268?cb=20210131141716&path-prefix=ru', 
    rarity: CardRarity.mythic, 
    power: 112, 
    level: 6, 
    hp: 265, 
    mp: 190, 
    skill: 'Тетрадь Смерти', 
    description: 'Старшеклассник, решивший стать "богом нового мира" с помощью тетради, убивающей людей.', 
    quote: 'Я — справедливость!'
  ),
  _createCard(
    id: 'm_008', 
    characterName: 'Джорно Джованна (GER)', 
    animeName: 'JoJo\'s Bizarre Adventure', 
    imageUrl: 'https://shikimori.one/uploads/poster/characters/10529/main-d18610a7226fca8ceec75e4180045cbe.webp', 
    rarity: CardRarity.mythic, 
    power: 117, 
    level: 6, 
    hp: 280, 
    mp: 200, 
    skill: 'Gold Experience Requiem', 
    description: 'Обладатель стенда, способного обнулять любые действия и атаки.', 
    quote: 'Ты никогда не достигнешь правды.'
  ),
  _createCard(
    id: 'm_009', 
    characterName: 'Рё Асука (Сатана)', 
    animeName: 'Devilman Crybaby', 
    imageUrl: 'https://shikimori.one/uploads/poster/characters/4092/main-09432cce9aff8c6847083d318f2f830a.webp', 
    rarity: CardRarity.mythic, 
    power: 115, 
    level: 6, 
    hp: 270, 
    mp: 180, 
    skill: 'Падший ангел', 
    description: 'Лучший друг главного героя, оказавшийся воплощением Сатаны.', 
    quote: 'Любовь не существует. Сострадания нет. Есть только я.'
  ),
  _createCard(
    id: 'm_010', 
    characterName: 'Зено-сама', 
    animeName: 'Dragon Ball Super', 
    imageUrl: 'https://shikimori.one/uploads/poster/characters/67753/main-cb1a2192bb5fcd822fb1bf7b4c235f84.webp', 
    rarity: CardRarity.mythic, 
    power: 120, 
    level: 6, 
    hp: 300, 
    mp: 210, 
    skill: 'Уничтожение', 
    description: 'Король Всего, способный стереть любую вселенную по своему желанию.', 
    quote: 'Хочу поиграть!'
  ),
  _createCard(
    id: 'm_011',
    characterName: 'Тандзиро Камадо',
    animeName: 'Demon Slayer',
    imageUrl: 'https://shikimori.one/uploads/poster/characters/146156/main-c1eb6f65eaf83178a41607926b685d5e.webp',
    rarity: CardRarity.mythic,
    power: 88,
    level: 4,
    hp: 175,
    mp: 120,
    skill: 'Дыхание воды',
    description: 'Добрый юноша, ставший убийцей демонов, чтобы спасти свою младшую сестру.',
    quote: 'Дыми, дыхание воды! Первый стиль: удар поверхности воды!'
),
_createCard(
    id: 'm_012',
    characterName: 'Дэндзи',
    animeName: 'Chainsaw Man',
    imageUrl: 'https://shikimori.one/uploads/poster/characters/170732/main-907c0d148c57a222e6bb81e61a4fc9b4.webp',
    rarity: CardRarity.mythic,
    power: 90,
    level: 4,
    hp: 180,
    mp: 100,
    skill: 'Пилот-дьявол',
    description: 'Юноша, слившийся с дьяволом-псой Поччи, мечтающий о простой жизни.',
    quote: 'Начну с груди.'
),
_createCard(
    id: 'm_013',
    characterName: 'Изуку Мидория',
    animeName: 'My Hero Academia',
    imageUrl: 'https://shikimori.one/uploads/poster/characters/117909/main-bc080898cd4fa421833a565d13f45c11.webp',
    rarity: CardRarity.mythic,
    power: 85,
    level: 4,
    hp: 170,
    mp: 130,
    skill: 'Один за всех',
    description: 'Родившийся без силы, он унаследовал квирк величайшего героя и стал символом надежды.',
    quote: 'Плюс Ультра!'
),
_createCard(
    id: 'm_014',
    characterName: 'Юдзи Итадори',
    animeName: 'Jujutsu Kaisen',
    imageUrl: 'https://shikimori.one/uploads/poster/characters/163847/main-13a2f63ac61d71ace8999698ea62c24f.webp',
    rarity: CardRarity.mythic,
    power: 89,
    level: 4,
    hp: 185,
    mp: 110,
    skill: 'Тюрьма Сукуны',
    description: 'Спортсмен, ставший сосудом для могущественнейшего проклятия и вступивший в мир магов.',
    quote: 'Я возьму на себя грехи. Я спасу всех, кого смогу.'
),
_createCard(
    id: 'm_015',
    characterName: 'Ллойд Форджер',
    animeName: 'Spy x Family',
    imageUrl: 'https://shikimori.one/uploads/poster/characters/170258/main-3d42f6b73ea386b814714ece993708a8.webp',
    rarity: CardRarity.mythic,
    power: 92,
    level: 4,
    hp: 190,
    mp: 115,
    skill: 'Мастер шпионажа',
    description: 'Лучший шпион Весталиса, создавший семью для выполнения своей важнейшей миссии.',
    quote: 'Мир — это очень хрупкое место.'
),
_createCard(
    id: 'm_016',
    characterName: 'Йор Форджер',
    animeName: 'Spy x Family',
    imageUrl: 'https://shikimori.one/uploads/poster/characters/170329/main-d61d04c084e76d30bede44ff613257bc.webp',
    rarity: CardRarity.mythic,
    power: 91,
    level: 4,
    hp: 185,
    mp: 105,
    skill: 'Убийца "Шпилька"',
    description: 'Элитная наемница по прозвищу "Шпилька", ведущая двойную жизнь как любящая мать и жена.',
    quote: 'Если я не буду убивать, моя семья умрёт. Если я буду убивать, моя семья будет в опасности.'
),
_createCard(
    id: 'm_017',
    characterName: 'Аня Форджер',
    animeName: 'Spy x Family',
    imageUrl: 'https://shikimori.one/uploads/poster/characters/170256/main-1bf79fa62170d19d705a5669f1e17820.webp',
    rarity: CardRarity.mythic,
    power: 75,
    level: 4,
    hp: 140,
    mp: 125,
    skill: 'Чтение мыслей',
    description: 'Девочка-телепат, ставшая ключевым звеном в шпионской операции "Стратегия".',
    quote: 'Хехх.'
),
_createCard(
    id: 'm_018',
    characterName: 'Кацуки Бакуго',
    animeName: 'My Hero Academia',
    imageUrl: 'https://shikimori.one/uploads/poster/characters/117911/main-e9405efdf0fde9d1568696ec4d5a1ee8.webp',
    rarity: CardRarity.mythic,
    power: 90,
    level: 4,
    hp: 175,
    mp: 120,
    skill: 'Взрыв',
    description: 'Гениальный и вспыльчивый герой, чья цель — превзойти всех и стать номером один.',
    quote: 'Умри!'
),
_createCard(
    id: 'm_019',
    characterName: 'Санджи',
    animeName: 'One Piece',
    imageUrl: 'https://shikimori.one/uploads/poster/characters/305/main-98a5137695dd55134f7406cccbeaa3cd.webp',
    rarity: CardRarity.mythic,
    power: 89,
    level: 4,
    hp: 180,
    mp: 110,
    skill: 'Дьямбль Джамбо',
    description: 'Кок команды Соломона, мастер боевых искусств ног и джентльмен до мозга костей.',
    quote: 'Никогда не оскорбляй еду, особенно ту, что приготовил я!'
),
_createCard(
    id: 'm_020',
    characterName: 'Мэгуми Фусигуро',
    animeName: 'Jujutsu Kaisen',
    imageUrl: 'https://shikimori.one/uploads/poster/characters/164470/main-84f2153e1a78ca52615fbc1d743172b6.webp',
    rarity: CardRarity.mythic,
    power: 86,
    level: 4,
    hp: 165,
    mp: 135,
    skill: 'Техника десяти теней',
    description: 'Маг, призывающий духов-шикигами для борьбы с проклятиями, обладающий огромным потенциалом.',
    quote: 'Я не спасаю всех. Я спасаю тех, кого считаю достойным спасения.'
),
_createCard(
    id: 'm_021',
    characterName: 'Сугуру Гето',
    animeName: 'Jujutsu Kaisen',
    imageUrl: 'https://shikimori.one/uploads/poster/characters/175542/main-d75df348fb8c9705cfaf2be467e816aa.webp',
    rarity: CardRarity.mythic,
    power: 91,
    level: 4,
    hp: 170,
    mp: 140,
    skill: 'Поглощение проклятий',
    description: 'Бывший друг Годжо, решивший истребить не-магов ради создания лучшего мира.',
    quote: 'Право решать судьбу мира должно принадлежать магам.'
),
_createCard(
    id: 'm_022',
    characterName: 'Кэнто Нанами',
    animeName: 'Jujutsu Kaisen',
    imageUrl: 'https://shikimori.one/uploads/poster/characters/164473/main-aa84d226635df5643383fb54657487c3.webp',
    rarity: CardRarity.mythic,
    power: 87,
    level: 4,
    hp: 180,
    mp: 115,
    skill: 'Соотношение 7:3',
    description: 'Бывший бизнесмен, ставший магом, ценящий логику, порядок и отдых после работы.',
    quote: 'Вы должны быть взрослыми. Если вы не можете взять на себя ответственность за свои слова, умрите.'
),
_createCard(
    id: 'm_023',
    characterName: 'Гароу',
    animeName: 'One-Punch Man',
    imageUrl: 'https://shikimori.one/uploads/poster/characters/112889/main-0fad0fa88bbf028488451052de0c56ce.webp',
    rarity: CardRarity.mythic,
    power: 93,
    level: 4,
    hp: 190,
    mp: 100,
    skill: 'Монстр-Калибр',
    description: 'Охотник на героев, стремящийся стать абсолютным злом и справедливостью в одном лице.',
    quote: 'Я — абсолютное зло!'
),
_createCard(
    id: 'm_024',
    characterName: 'Татсумаки',
    animeName: 'One-Punch Man',
    imageUrl: 'https://static.wikia.nocookie.net/onepunchman/images/b/b2/%D0%A2%D0%B0%D1%86%D1%83%D0%BC%D0%B0%D0%BA%D0%B8%2C_%D0%B0%D0%BD%D0%B8%D0%BC%D0%B5.png/revision/latest/scale-to-width-down/268?cb=20210404160633&path-prefix=ru',
    rarity: CardRarity.mythic,
    power: 92,
    level: 4,
    hp: 160,
    mp: 140,
    skill: 'Психокинез',
    description: 'Самая сильная героиня Ассоциации Героев, "Торнадо Ужаса".',
    quote: 'Не трогай мою сестру.'
),
_createCard(
    id: 'm_026',
    characterName: 'Арчер (ЭМИЯ)',
    animeName: 'Fate/stay night: Unlimited Blade Works',
    imageUrl: 'https://shikimori.one/uploads/poster/characters/2087/main-c43ee2c07c8436c1a3072ceb128d488c.webp',
    rarity: CardRarity.mythic,
    power: 88,
    level: 4,
    hp: 175,
    mp: 145,
    skill: 'Безграничный мир лезвий',
    description: 'Слуга, циничный герой, разочаровавшийся в своих идеалах спасения.',
    quote: 'Я — сталь для своего тела. Я — огонь для своей крови.'
),
_createCard(
    id: 'm_027',
    characterName: 'Райнер Браун',
    animeName: 'Attack on Titan',
    imageUrl: 'https://shikimori.one/uploads/poster/characters/46484/main-3194842e7f3deb49f40a87b22e89583e.webp',
    rarity: CardRarity.mythic,
    power: 90,
    level: 4,
    hp: 195,
    mp: 105,
    skill: 'Бронированный титан',
    description: 'Солдат, носящий на плечах тяжелейшее бремя своей миссии и личности.',
    quote: 'Кто же... враг?'
),
_createCard(
    id: 'm_028',
    characterName: 'Зик Йегер',
    animeName: 'Attack on Titan',
    imageUrl: 'https://shikimori.one/uploads/poster/characters/142314/main-a68f87a737191a0eec088cd4cf9036ae.webp',
    rarity: CardRarity.mythic,
    power: 89,
    level: 4,
    hp: 180,
    mp: 125,
    skill: 'Крик зверя',
    description: 'Владыка зверя, преследующий радикальную цель эвтаназии своего народа.',
    quote: 'Я не хотел ничего, кроме как спасти Элдию.'
),
_createCard(
    id: 'm_029',
    characterName: 'Джирайя',
    animeName: 'Naruto',
    imageUrl: 'https://shikimori.one/uploads/poster/characters/2423/main-291f8b2e73f166b2ee9dff63b0194235.webp',
    rarity: CardRarity.mythic,
    power: 91,
    level: 4,
    hp: 185,
    mp: 135,
    skill: 'Призыв жаб',
    description: 'Легендарный санин и наставник Наруто, "Жаба-отшельник".',
    quote: 'Когда люди отказываются от своих чаяний, они называют это зрелостью.'
),
_createCard(
    id: 'm_030',
    characterName: 'Гаара',
    animeName: 'Naruto',
    imageUrl: 'https://shikimori.one/uploads/poster/characters/1662/main-5099b208ec53df1bb78e5d4bad2e650b.webp',
    rarity: CardRarity.mythic,
    power: 88,
    level: 4,
    hp: 180,
    mp: 130,
    skill: 'Защита песком',
    description: 'Бывший джинчурики, ставший Казекаге и защитником своей деревни.',
    quote: 'Я защищу свою деревню любой ценой.'
),
_createCard(
    id: 'm_031',
    characterName: 'Айзек Нетеро',
    animeName: 'Hunter x Hunter',
    imageUrl: 'https://shikimori.one/uploads/poster/characters/14489/main-82e67eb38976c5380daa7a0d427f1971.webp',
    rarity: CardRarity.mythic,
    power: 95,
    level: 4,
    hp: 190,
    mp: 120,
    skill: 'Сто типов гнева',
    description: 'Председатель Ассоциации Охотников, сильнейший нэн-пользователь своего времени.',
    quote: 'Спасибо тебе... за игру.'
),
_createCard(
    id: 'm_032',
    characterName: 'Хролло Люцильфер',
    animeName: 'Hunter x Hunter',
    imageUrl: 'https://shikimori.one/uploads/poster/characters/58/main-e9bcc344e531d89a3270530a7fe17b5f.webp',
    rarity: CardRarity.mythic,
    power: 90,
    level: 4,
    hp: 175,
    mp: 140,
    skill: 'Бандитская тайна',
    description: 'Харизматичный и загадочный лидер "Пауков", воров с небывалыми способностями.',
    quote: 'Печаль — это тоже привилегия.'
),
];

// 🟣 Божественные карты (~0.1% шанс выпадения)
static final List<AnimeCard> _divineCards = [
  _createCard(
    id: 'd_001', 
    characterName: 'Сон Гоку (Совершенный Ультра Инстинкт)', 
    animeName: 'Dragon Ball Super', 
    imageUrl: 'https://static.wikia.nocookie.net/character-power/images/c/c9/5755577575.png/revision/latest/scale-to-width-down/340?cb=20200604190329&path-prefix=ru', 
    rarity: CardRarity.divine, 
    power: 130, 
    level: 7, 
    hp: 320, 
    mp: 220, 
    skill: 'Божественный инстинкт', 
    description: 'Полное овладение силой богов, позволяющее превосходить любые пределы.', 
    quote: 'Это... и есть сила богов.'
  ),
  _createCard(
    id: 'd_002', 
    characterName: 'Богиня Мадока', 
    animeName: 'Puella Magi Madoka Magica', 
    imageUrl: 'https://i.pinimg.com/736x/68/32/43/683243e741a854a382021a61de1c4cf7.jpg', 
    rarity: CardRarity.divine, 
    power: 128, 
    level: 7, 
    hp: 310, 
    mp: 230, 
    skill: 'Концепция надежды', 
    description: 'Стала абстрактной концепцией, существующей вне времени и пространства.', 
    quote: 'Если кто-то скажет, что надеяться — глупо, я докажу, что он неправ.'
  ),
  _createCard(
    id: 'd_003', 
    characterName: 'Харухи Судзумия (Полная сила)', 
    animeName: 'The Melancholy of Haruhi Suzumiya', 
    imageUrl: 'https://static.wikia.nocookie.net/anime-characters-fight/images/1/17/HaruhiMain.png/revision/latest/scale-to-width-down/700?cb=20230731183245&path-prefix=ru', 
    rarity: CardRarity.divine, 
    power: 125, 
    level: 7, 
    hp: 315, 
    mp: 225, 
    skill: 'Создание миров', 
    description: 'Неосознанная богиня, способная создавать и уничтожать вселенные силой мысли.', 
    quote: 'Если мира, который мне нравится, не существует, я просто создам его!'
  ),
  _createCard(
    id: 'd_004', 
    characterName: 'Супер Тэнгэн Топпа Гуррен-Лаганн', 
    animeName: 'Gurren Lagann', 
    imageUrl: 'https://static.wikia.nocookie.net/anime-characters-fight/images/2/2e/CTTGL.png/revision/latest/scale-to-width-down/680?cb=20140902111843&path-prefix=ru', 
    rarity: CardRarity.divine, 
    power: 135, 
    level: 7, 
    hp: 400, 
    mp: 250, 
    skill: 'Спиральная сверхсила', 
    description: 'Галактических размеров робот, олицетворяющий бесконечную эволюцию и волю.', 
    quote: 'Пронзи небеса своим буром!'
  ),
  _createCard(
    id: 'd_005', 
    characterName: 'Лэйн Ивакура', 
    animeName: 'Serial Experiments Lain', 
    imageUrl: 'https://shikimori.one/uploads/poster/characters/2219/main-49ef1e89d42f10251f93e6227666d1cf.webp', 
    rarity: CardRarity.divine, 
    power: 130, 
    level: 7, 
    hp: 300, 
    mp: 230, 
    skill: 'Богиня Сети', 
    description: 'Девочка, ставшая всеведущим и вездесущим божеством проводного мира (интернета).', 
    quote: 'Где бы ты ни был, все мы связаны.'
  ),
  _createCard(
    id: 'd_006', 
    characterName: 'Истина', 
    animeName: 'Fullmetal Alchemist', 
    imageUrl: 'https://shikimori.one/uploads/poster/characters/33816/main-cc596ef6e4e19998828bedf3877932cb.webp', 
    rarity: CardRarity.divine, 
    power: 140, 
    level: 7, 
    hp: 350, 
    mp: 250, 
    skill: 'Всё и ничто', 
    description: 'Метафизическая сущность, олицетворяющая вселенную, Бога и самого себя.', 
    quote: 'Я — то, что вы называете миром, или, быть может, вселенной, или, быть может, Богом, или, быть может, Истиной, или, быть может, Всем, или, быть может, Одним. А ещё я — это ты.'
  ),
  _createCard(
    id: 'd_008', 
    characterName: 'Фезарин Август Аврора', 
    animeName: 'Umineko no Naku Koro ni', 
    imageUrl: 'https://shikimori.one/uploads/poster/characters/36061/main-8dad0f53868970a40d9816ea6b2f0ce7.webp', 
    rarity: CardRarity.divine, 
    power: 145, 
    level: 7, 
    hp: 450, 
    mp: 280, 
    skill: 'Ведьма Театра', 
    description: 'Высшее существо, способное переписывать истории и реальности как автор.', 
    quote: 'История не будет двигаться, если в ней нет сердца.'
  ),
  _createCard(
    id: 'd_009', 
    characterName: 'Абсолютный Бог Зено', 
    animeName: 'Dragon Ball Super', 
    imageUrl: 'https://static.wikia.nocookie.net/anime-characters-fight/images/6/64/Zen%27%C5%8D.png/revision/latest/scale-to-width-down/270?cb=20200315083753&path-prefix=ru', 
    rarity: CardRarity.divine, 
    power: 148, 
    level: 7, 
    hp: 480, 
    mp: 290, 
    skill: 'Абсолютное стирание', 
    description: 'Существо, стоящее над всеми 12 вселенными, чья сила абсолютна и непостижима.', 
    quote: 'Всё исчезнет.'
  ),
  _createCard(
    id: 'd_010', 
    characterName: 'Аянами Рей (Конец Евангелиона)', 
    animeName: 'The End of Evangelion', 
    imageUrl: 'https://i.pinimg.com/736x/35/41/56/3541561d816e55a49a56b4d949adf4ce.jpg', 
    rarity: CardRarity.divine, 
    power: 138, 
    level: 7, 
    hp: 345, 
    mp: 250, 
    skill: 'Проект комплементации', 
    description: 'Сущность, объединившая в себе Лилит и Адама для слияния всего человечества.', 
    quote: 'Человек не может жить в одиночестве. Но люди всегда одиноки.'
  ),
  _createCard(
    id: 'd_011',
    characterName: 'Саскэ Учиха',
    animeName: 'Naruto',
    imageUrl: 'https://shikimori.one/uploads/poster/characters/13/main-4affd071ae01ce2a0113bf1aee1fce90.webp',
    rarity: CardRarity.divine,
    power: 99,
    level: 5,
    hp: 200,
    mp: 130,
    skill: 'Проклятие ненависти',
    description: 'Последний представитель клана Утиха, идущий по пути мести ради обретения силы.',
    quote: 'Я просто разорвал все свои связи для того, чтобы получить эту силу!'
),
_createCard(
    id: 'd_012',
    characterName: 'Итачи Учиха',
    animeName: 'Naruto',
    imageUrl: 'https://shikimori.one/uploads/poster/characters/14/main-d451628682551f0b8f41d960ea64b71e.webp',
    rarity: CardRarity.divine,
    power: 97,
    level: 5,
    hp: 180,
    mp: 150,
    skill: 'Цукуёми',
    description: 'Легендарный ниндзя, пожертвовавший всем ради мира в своей деревне.',
    quote: 'Люди не могут судить друг друга. Этим занимаются боги.'
),
_createCard(
    id: 'd_013',
    characterName: 'Сосукэ Айдзэн',
    animeName: 'Bleach',
    imageUrl: 'https://shikimori.one/uploads/poster/characters/1086/main-12a4b231306c09430d796c7369ea5bcb.webp',
    rarity: CardRarity.divine,
    power: 98,
    level: 5,
    hp: 190,
    mp: 145,
    skill: 'Полная гипноз',
    description: 'Бывший капитан Готэй 13, стремящийся свергнуть правителя небес.',
    quote: 'Это был мой кёка суигецу.'
),
_createCard(
    id: 'd_014',
    characterName: 'Рюк',
    animeName: 'Death Note',
    imageUrl: 'https://upload.wikimedia.org/wikipedia/ru/thumb/5/5f/Death_Note_shinigami_Ryuk.JPG/250px-Death_Note_shinigami_Ryuk.JPG',
    rarity: CardRarity.divine,
    power: 95,
    level: 5,
    hp: 220,
    mp: 120,
    skill: 'Смертная тетрадь',
    description: 'Бог смерти, уронивший тетрадь в мир людей ради собственного развлечения.',
    quote: 'Человечество интересно... в самом прямом смысле этого слова.'
),
_createCard(
    id: 'd_015',
    characterName: 'Сукуна Рёмэн',
    animeName: 'Jujutsu Kaisen',
    imageUrl: 'https://shikimori.one/uploads/poster/characters/175198/main-f9d0fcf9239e014b2e6e500349043f1e.webp',
    rarity: CardRarity.divine,
    power: 100,
    level: 5,
    hp: 210,
    mp: 140,
    skill: 'Рассечение',
    description: 'Король проклятий, чья сила и жестокость не знают границ.',
    quote: 'Не будь скучным.'
),
_createCard(
    id: 'd_016',
    characterName: 'Веджета',
    animeName: 'Dragon Ball Z',
    imageUrl: 'https://shikimori.one/uploads/poster/characters/913/main-e9d57280c42aff67ab95114736bdd5b7.webp',
    rarity: CardRarity.divine,
    power: 98,
    level: 5,
    hp: 205,
    mp: 110,
    skill: 'Галлик пушка',
    description: 'Принц всех сайянов, вечный соперник Гоку, стремящийся к превосходству.',
    quote: 'Как посмел ты... САЙЯН!!!'
),
_createCard(
    id: 'd_017',
    characterName: 'Алл Майт',
    animeName: 'Всемогущий',
    imageUrl: 'https://shikimori.one/uploads/poster/characters/117921/main-dcaa5ffc8cd6fa6f9b632a6a39ca79c7.webp',
    rarity: CardRarity.divine,
    power: 96,
    level: 5,
    hp: 215,
    mp: 100,
    skill: 'Техас смэш',
    description: 'Символ Мира, чья улыбка и несокрушимая воля спасают всех.',
    quote: 'Все уже в порядке. Почему? Потому что я здесь!'
),
_createCard(
    id: 'd_018',
    characterName: 'Кэмпати Дзараки',
    animeName: 'Bleach',
    imageUrl: 'https://shikimori.one/uploads/poster/characters/909/main-1ebae3639e73c0415824f847abf716b1.webp',
    rarity: CardRarity.divine,
    power: 100,
    level: 5,
    hp: 220,
    mp: 50,
    skill: 'Норра',
    description: 'Безумный капитан 11-го отряда, живущий ради азарта битвы.',
    quote: 'Я просто хочу сражаться. Сражаться с тобой.'
),
_createCard(
    id: 'd_019',
    characterName: 'Какаши Хатакэ',
    animeName: 'Naruto',
    imageUrl: 'https://shikimori.one/uploads/poster/characters/85/main-0c498dcce161c699d19f3f938057300f.webp',
    rarity: CardRarity.divine,
    power: 92,
    level: 5,
    hp: 185,
    mp: 140,
    skill: 'Тысяча лет смерти',
    description: '"Копирующий ниндзя", наставник Команды 7 и один из сильнейших синоби.',
    quote: 'В мире ниндзя, тех, кто нарушает правила, считают дрянью. Но... те, кто бросает своих друзей, хуже дряни.'
),
_createCard(
    id: 'd_020',
    characterName: 'Джотаро Куджо',
    animeName: "JoJo's Bizarre Adventure",
    imageUrl: 'https://shikimori.one/uploads/poster/characters/4003/main-abe8e4b0e133cbae3f59012503c8b3f5.webp',
    rarity: CardRarity.divine,
    power: 95,
    level: 5,
    hp: 195,
    mp: 120,
    skill: 'Плоть духа',
    description: 'Хладнокровный бунтарь, призвавший могущественного Стэнда для борьбы со злом.',
    quote: 'Yare yare daze... (Ну уж всё).'
),
_createCard(
    id: 'd_021',
    characterName: 'Дио Брандо',
    animeName: "JoJo's Bizarre Adventure",
    imageUrl: 'https://shikimori.one/uploads/poster/characters/4004/main-c0f833063fd56863af1d87ff2cc0bd0f.webp',
    rarity: CardRarity.divine,
    power: 96,
    level: 5,
    hp: 200,
    mp: 125,
    skill: 'Мир',
    description: 'Безжалостный вампир и пользователь Стэнда, жаждущий абсолютной власти.',
    quote: 'Мудрё! Мудрё! Мудрё!'
),
_createCard(
    id: 'd_022',
    characterName: 'Меруэм',
    animeName: 'Hunter x Hunter',
    imageUrl: 'https://shikimori.one/uploads/poster/characters/23277/main-c59ab2e75433c2be5a1f358039b1c138.webp',
    rarity: CardRarity.divine,
    power: 97,
    level: 5,
    hp: 210,
    mp: 115,
    skill: 'Аура отчаяния',
    description: 'Король Муравьев-химер, чей эволюционный путь привел его к человечности.',
    quote: 'Комуги... я хочу... быть с тобой.'
),
_createCard(
    id: 'd_023',
    characterName: 'Эдвард Элрик',
    animeName: 'Fullmetal Alchemist: Brotherhood',
    imageUrl: 'https://shikimori.one/uploads/poster/characters/11/main-fbea0a62568463497a231a4e88d5c425.webp',
    rarity: CardRarity.divine,
    power: 90,
    level: 5,
    hp: 170,
    mp: 150,
    skill: 'Алхимия без круга',
    description: '"Стальной алхимик", ищущий Философский камень, чтобы искупить свою ошибку.',
    quote: 'Не называй меня маленьким!'
),
_createCard(
    id: 'd_024',
    characterName: 'Коро-сэнсэй',
    animeName: 'Assassination Classroom',
    imageUrl: 'https://shikimori.one/uploads/poster/characters/65643/main-d813fd0e4207409946a9a2127c202584.webp',
    rarity: CardRarity.divine,
    power: 94,
    level: 5,
    hp: 190,
    mp: 135,
    skill: 'Скорость Маха 20',
    description: 'Загадочный учитель и существо, способное уничтожить Луну, а затем и Землю.',
    quote: 'Я убью вас, но сначала помогу сдать выпускные.'
),
_createCard(
    id: 'd_025',
    characterName: 'Синджи Икари',
    animeName: 'Neon Genesis Evangelion',
    imageUrl: 'https://shikimori.one/uploads/poster/characters/89/main-04b6e142b21294c4b76806bb07910822.webp',
    rarity: CardRarity.divine,
    power: 85,
    level: 5,
    hp: 160,
    mp: 145,
    skill: 'Синхронизация',
    description: 'Пилот Евангилиона, борющийся со своей тревогой и грузом чужих ожиданий.',
    quote: 'Я не должен бежать.'
),
_createCard(
    id: 'd_026',
    characterName: 'Макима',
    animeName: 'Chainsaw Man',
    imageUrl: 'https://shikimori.one/uploads/poster/characters/170734/main-4e52de298c9027800121713f39039561.webp',
    rarity: CardRarity.divine,
    power: 95,
    level: 5,
    hp: 180,
    mp: 150,
    skill: 'Дьявольский контракт',
    description: 'Лидер Отдела общественной безопасности, управляющая людьми и дьяволами.',
    quote: 'Хочешь обнять меня, Дэндзи?'
),
_createCard(
    id: 'd_027',
    characterName: 'Киллуа Золдик',
    animeName: 'Hunter x Hunter',
    imageUrl: 'https://shikimori.one/uploads/poster/characters/27/main-3abb3434afd32211db6cf7b8449f14a9.webp',
    rarity: CardRarity.divine,
    power: 93,
    level: 5,
    hp: 180,
    mp: 130,
    skill: 'Разрядка молнии',
    description: 'Юный наследник семьи убийц, нашедший в друзьях смысл своей жизни.',
    quote: 'Я вернусь. Я обещаю.'
),
_createCard(
    id: 'd_028',
    characterName: 'Ринтаро Окабэ',
    animeName: 'Steins;Gate',
    imageUrl: 'https://shikimori.one/uploads/poster/characters/35252/main-6ba2886ed13f56e93d5efd382eaa4547.webp',
    rarity: CardRarity.divine,
    power: 88,
    level: 5,
    hp: 150,
    mp: 150,
    skill: 'Чтение Штейнера',
    description: '"Безумный учёный", способный менять прошлое через текстовые сообщения.',
    quote: 'Эли... Псоу! (El Psy Kongroo).'
),
_createCard(
    id: 'd_029',
    characterName: 'Сэйбер',
    animeName: 'Fate/stay night',
    imageUrl: 'https://shikimori.one/uploads/poster/characters/497/main-95d4da75ca2ffe01c1c2133036c557de.webp',
    rarity: CardRarity.divine,
    power: 96,
    level: 5,
    hp: 195,
    mp: 125,
    skill: 'Экскалибур',
    description: 'Король рыцарей, призванный в качестве Слуги для участия в Войне за Святой Грааль.',
    quote: 'Я спрашиваю тебя: ты мой мастер?'
),
_createCard(
    id: 'd_030',
    characterName: 'Эрвин Смит',
    animeName: 'Attack on Titan',
    imageUrl: 'https://shikimori.one/uploads/poster/characters/46496/main-e445b76e0f4bd0ce3edad5cdf5069d82.webp',
    rarity: CardRarity.divine,
    power: 91,
    level: 5,
    hp: 175,
    mp: 140,
    skill: 'Возложи свои сердца',
    description: 'Харизматичный командир Разведкорпуса, ведущий человечество к надежде.',
    quote: 'Возложите свои сердца!'
),
_createCard(
    id: 'd_031',
    characterName: 'Пэйн (Нагато)',
    animeName: 'Naruto',
    imageUrl: 'https://shikimori.one/uploads/poster/characters/3180/main-9c04a30f10a86a8de01cfdc763381996.webp',
    rarity: CardRarity.divine,
    power: 94,
    level: 5,
    hp: 185,
    mp: 145,
    skill: 'Шесть путей Пэйна',
    description: 'Лидер Акацуки, стремящийся принести миру мир через страдание.',
    quote: 'Мир поймет истинную боль... через мой гендзюцу.'
),
_createCard(
    id: 'd_032',
    characterName: 'Ророноа Зоро',
    animeName: 'One Piece',
    imageUrl: 'https://shikimori.one/uploads/poster/characters/62/main-cfd09eb37c1bb7592fa38665a9961eba.webp',
    rarity: CardRarity.divine,
    power: 97,
    level: 5,
    hp: 205,
    mp: 80,
    skill: 'Три меча: Асура',
    description: 'Первый мечник команды Соломона, давший клятву стать сильнейшим.',
    quote: 'Я стану сильнейшим мечником мира!'
),
];

  // =========================================================================
  // --- БАЗОВЫЕ МЕТОДЫ РАБОТЫ С ДАННЫМИ ---
  // =========================================================================

  static List<AnimeCard> _getInitialCollection() {
    return [
    ];
  }

  static Future<Map<CardRarity, int>> getCollectionStats() async {
    final collection = await getCollection();
    final stats = <CardRarity, int>{};
    for (final rarity in CardRarity.values) {
      stats[rarity] = collection.where((c) => c.rarity == rarity).length;
    }
    return stats;
  }

  static Future<bool> _addToCollectionWithDuplicates(List<AnimeCard> newCards) async {
    try {
      final currentCollection = await getCollection();
      final updatedCollection = List<AnimeCard>.from(currentCollection);

      for (final newCard in newCards) {
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

      return await _saveCollection(updatedCollection);
    } catch (e) {
      print('Ошибка при добавлении карт с дубликатами: $e');
      return false;
    }
  }

  static Future<bool> _deleteCardById(String cardId) async {
    try {
      final collection = await getCollection();
      final updatedCollection = collection.where((card) => card.id != cardId).toList();
      return await _saveCollection(updatedCollection);
    } catch (e) {
      print('Ошибка при удалении карты по ID: $e');
      return false;
    }
  }

  static Future<List<AnimeCard>> _getAllCards() async {
    return await getCollection();
  }

  static List<AnimeCard> _getCardsByRarity(CardRarity rarity) {
    switch (rarity) {
      case CardRarity.common: return _commonCards;
      case CardRarity.rare: return _rareCards;
      case CardRarity.epic: return _epicCards;
      case CardRarity.legendary: return _legendaryCards;
      case CardRarity.mythic: return _mythicCards;
      case CardRarity.divine: return _divineCards;
    }
  }

  // =========================================================================
  // --- HIVE МЕТОДЫ ---
  // =========================================================================

  static Future<int> _getCoins() async {
    try {
      final box = await Hive.openBox('gameData');
      return box.get('coins', defaultValue: 1000) as int;
    } catch (e) {
      print('Ошибка при получении монет: $e');
      return 1000;
    }
  }

  static Future<bool> _spendCoins(int amount) async {
    try {
      final box = await Hive.openBox('gameData');
      final currentCoins = await _getCoins();
      if (currentCoins < amount) return false;
      final newCoins = currentCoins - amount;
      await box.put('coins', newCoins);
      return true;
    } catch (e) {
      print('Ошибка при трате монет: $e');
      return false;
    }
  }

  static Future<void> _addPlayerExp(int amount) async {
    try {
      final box = await Hive.openBox('gameData');
      final currentExp = await getPlayerExp();
      final currentLevel = await getPlayerLevel();
      
      int newExp = currentExp + amount;
      int newLevel = currentLevel;
      
      final expNeeded = currentLevel * 100;
      if (newExp >= expNeeded) {
        newLevel++;
        newExp = newExp - expNeeded;
        await addCoins(100 * newLevel);
      }
      
      await box.put('playerExp', newExp);
      await box.put('playerLevel', newLevel);
    } catch (e) {
      print('Ошибка при добавлении опыта: $e');
    }
  }

  static Future<bool> _saveCollection(List<AnimeCard> collection) async {
    try {
      final box = await Hive.openBox('gameData');
      final collectionData = collection.map((card) => card.toJson()).toList();
      await box.put('playerCollection', collectionData);
      return true;
    } catch (e) {
      print('Ошибка при сохранении коллекции: $e');
      return false;
    }
  }

  static Future<List<AnimeCard>> getCollection() async {
    try {
      final box = await Hive.openBox('gameData');
      final collectionData = box.get('playerCollection', defaultValue: <Map<String, dynamic>>[]) as List<dynamic>;
      
      if (collectionData.isEmpty) {
        return _getInitialCollection();
      }
      
      final collection = <AnimeCard>[];
      for (final data in collectionData) {
        try {
          final card = AnimeCard.fromJson(Map<String, dynamic>.from(data));
          collection.add(card);
        } catch (e) {
          print('Ошибка при парсинге карты: $e');
        }
      }
      
      return collection;
    } catch (e) {
      print('Ошибка при загрузке коллекции: $e');
      return _getInitialCollection();
    }
  }

  static Future<int> getCoins() async {
    return await _getCoins();
  }

  static Future<int> getPlayerLevel() async {
    try {
      final box = await Hive.openBox('gameData');
      return box.get('playerLevel', defaultValue: 1) as int;
    } catch (e) {
      print('Ошибка при получении уровня: $e');
      return 1;
    }
  }

  static Future<int> getPlayerExp() async {
    try {
      final box = await Hive.openBox('gameData');
      return box.get('playerExp', defaultValue: 0) as int;
    } catch (e) {
      print('Ошибка при получении опыта: $e');
      return 0;
    }
  }

  static Future<bool> addCoins(int amount) async {
    try {
      final box = await Hive.openBox('gameData');
      final currentCoins = await _getCoins();
      final newCoins = currentCoins + amount;
      await box.put('coins', newCoins);
      return true;
    } catch (e) {
      print('Ошибка при добавлении монет: $e');
      return false;
    }
  }

  static Future<bool> spendCoins(int amount) async {
    return await _spendCoins(amount);
  }

  static Future<bool> saveDeck(List<AnimeCard> deck) async {
    try {
      final box = await Hive.openBox('gameData');
      final deckData = deck.map((card) => card.id).toList();
      await box.put('playerDeck', deckData);
      return true;
    } catch (e) {
      print('Ошибка при сохранении колоды: $e');
      return false;
    }
  }

  static Future<List<AnimeCard>> loadDeck() async {
    try {
      final box = await Hive.openBox('gameData');
      final collection = await getCollection();
      final deckIds = box.get('playerDeck', defaultValue: <String>[]) as List<String>;
      
      final deck = <AnimeCard>[];
      for (final id in deckIds) {
        final card = collection.firstWhere((c) => c.id == id, orElse: () => collection.first);
        deck.add(card);
      }
      
      return deck;
    } catch (e) {
      print('Ошибка при загрузке колоды: $e');
      return getDefaultDeck();
    }
  }

  static Future<List<AnimeCard>> getDefaultDeck() async {
    final collection = await getCollection();
    return collection.take(10).toList();
  }

  static Future<List<AnimeCard>> getUserCards() async {
    return await getCollection();
  }

  static List<AnimeCard> getCardsByRarity(CardRarity rarity) {
    return _getCardsByRarity(rarity);
  }

  static Future<bool> addCardsToCollection(List<AnimeCard> cards) async {
    return await _addToCollectionWithDuplicates(cards);
  }
}