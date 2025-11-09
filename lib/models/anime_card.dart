// models/anime_card.dart
import 'package:flutter/material.dart';

/// Жанры аниме для боевой системы
enum AnimeGenre {
  action('Экшен', '⚡'),
  fantasy('Фэнтези', '🔮'), 
  romance('Романтика', '💖'),
  horror('Хоррор', '👻'),
  scifi('Sci-Fi', '🚀'),
  sliceOfLife('Повседневность', '🏠'),
  comedy('Комедия', '😂'),
  drama('Драма', '🎭');

  final String displayName;
  final String emoji;

  const AnimeGenre(this.displayName, this.emoji);
}

/// Архетипы персонажей
enum CharacterArchetype {
  hero('Герой', '🦸', 'Сбалансированный боец'),
  strategist('Стратег', '🧠', 'Сильные способности'),
  guardian('Защитник', '🛡️', 'Высокая стабильность'), 
  berserker('Берсерк', '⚔️', 'Мощные атаки'),
  supporter('Саппорт', '💫', 'Усиливает союзников'),
  wildcard('Дикая карта', '🃏', 'Непредсказуемые эффекты');

  final String displayName;
  final String emoji;
  final String description;

  const CharacterArchetype(this.displayName, this.emoji, this.description);
}

/// Типы способностей
enum AbilityType {
  impulse('⚡ Импульс', 'Срабатывает при размещении'),
  passive('🛡️ Пассив', 'Постоянный эффект'),
  reality('🌌 Реальность', 'Влияет на фазу'),
  ultimate('💥 Ультимат', 'Раз в матч');

  final String displayName;
  final String description;

  const AbilityType(this.displayName, this.description);
}

/// Редкость карты
enum CardRarity {
  common('Обычная', 0.50, 1.0, Color(0xFF757575)),
  rare('Редкая', 0.25, 1.3, Color(0xFF2196F3)),
  epic('Эпическая', 0.15, 1.7, Color(0xFF9C27B0)), 
  legendary('Легендарная', 0.08, 2.2, Color(0xFFFF9800)),
  mythic('Мифическая', 0.019, 3.0, Color(0xFFE91E63)),
  divine('Божественная', 0.001, 4.0, Color(0xFFFFD700));

  final String displayName;
  final double dropRate;
  final double powerMultiplier;
  final Color borderColor;

  const CardRarity(this.displayName, this.dropRate, this.powerMultiplier, this.borderColor);

  /// Градиент для премиального дизайна
  List<Color> get gradientColors {
    switch (this) {
      case CardRarity.common:
        return [Color(0xFF8C8C8C), Color(0xFFB8B8B8), Color(0xFFE0E0E0)];
      case CardRarity.rare:
        return [Color(0xFF4A90E2), Color(0xFF5DAAE0), Color(0xFF7BC8F6)];
      case CardRarity.epic:
        return [Color(0xFF9B59B6), Color(0xFFBB86FC), Color(0xFFD4A5FF)];
      case CardRarity.legendary:
        return [Color(0xFFFF9800), Color(0xFFFFB74D), Color(0xFFFFD54F)];
      case CardRarity.mythic:
        return [Color(0xFFE91E63), Color(0xFFFF4081), Color(0xFFFF79A8)];
      case CardRarity.divine:
        return [
          Color(0xFFFF6BCB), Color(0xFFFFB86C), Color(0xFFFFEB3B),
          Color(0xFF4FC3F7), Color(0xFFBA68C8), Color(0xFF4DB6AC),
        ];
    }
  }

  int get maxCopiesInDeck {
    switch (this) {
      case CardRarity.common: return 3;
      case CardRarity.rare: return 2;
      case CardRarity.epic: return 2;
      case CardRarity.legendary: return 1;
      case CardRarity.mythic: return 1;
      case CardRarity.divine: return 1;
    }
  }
}

/// Типы крафта - ОБНОВЛЕННАЯ СИСТЕМА
enum CraftType {
  common('Обычный крафт', 'Не используется', 0, 0, Icons.card_giftcard, Color(0xFF757575)), // Оставляем для совместимости
  rare('Редкий крафт', '5 обычных → 1 редкая', 0, 1, Icons.auto_awesome, Color(0xFF2196F3)),
  epic('Эпический крафт', '5 редких → 1 эпическая', 0, 1, Icons.diamond, Color(0xFF9C27B0)),
  legendary('Легендарный крафт', '5 эпических → 1 легендарная', 0, 1, Icons.workspace_premium, Color(0xFFFF9800)),
  mythic('Мифический крафт', '3 легендарных → 1 мифическая', 0, 1, Icons.stars, Color(0xFFE91E63));

  final String displayName;
  final String description;
  final int cost; // Теперь не используется, крафт через карты
  final int cardCount;
  final IconData icon;
  final Color color;

  const CraftType(
    this.displayName,
    this.description,
    this.cost,
    this.cardCount,
    this.icon,
    this.color,
  );

  /// Какие карты требуются для крафта
  CardRarity get requiredRarity {
    switch (this) {
      case CraftType.rare: return CardRarity.common;
      case CraftType.epic: return CardRarity.rare;
      case CraftType.legendary: return CardRarity.epic;
      case CraftType.mythic: return CardRarity.legendary;
      default: return CardRarity.common;
    }
  }

  /// Какая редкость получится
  CardRarity get resultRarity {
    switch (this) {
      case CraftType.rare: return CardRarity.rare;
      case CraftType.epic: return CardRarity.epic;
      case CraftType.legendary: return CardRarity.legendary;
      case CraftType.mythic: return CardRarity.mythic;
      default: return CardRarity.common;
    }
  }

  /// Сколько карт нужно для крафта
  int get requiredCardCount {
    switch (this) {
      case CraftType.mythic: return 3;
      default: return 5;
    }
  }
}

/// Статистика для битвы
class BattleStats {
  final int power;       // Базовая сила (20-120)
  final int resonance;   // Влияние на реальность (1-50)
  final int stability;   // Стабильность (защита от дебаффов)

  const BattleStats({
    required this.power,
    required this.resonance, 
    required this.stability,
  });

  int get totalPower => power + resonance;

  factory BattleStats.fromPower(int basePower) {
    return BattleStats(
      power: basePower,
      resonance: (basePower * 0.3).round(),
      stability: (basePower * 0.2).round(),
    );
  }

  // Метод для улучшения статистики
  BattleStats copyWithUpgrade(int level) {
    double multiplier = 1.0 + (level * 0.15);
    return BattleStats(
      power: (power * multiplier).round(),
      resonance: (resonance * multiplier).round(),
      stability: (stability * multiplier).round(),
    );
  }

  Map<String, dynamic> toJson() => {
    'power': power,
    'resonance': resonance,
    'stability': stability,
  };

  factory BattleStats.fromJson(Map<String, dynamic> json) {
    return BattleStats(
      power: json['power'] ?? 0,
      resonance: json['resonance'] ?? 0,
      stability: json['stability'] ?? 0,
    );
  }
}

/// Визуальные эффекты карты
class CardVisuals {
  final List<String> particleEffects;
  final String borderEffect;
  final String backgroundEffect;
  final List<String> levelEffects;
  final bool hasAnimation;
  final double glowIntensity;
  final bool isFoil;

  const CardVisuals({
    this.particleEffects = const [],
    this.borderEffect = 'none',
    this.backgroundEffect = 'none',
    this.levelEffects = const [],
    this.hasAnimation = false,
    this.glowIntensity = 0.0,
    this.isFoil = false,
  });

  CardVisuals copyWithUpgrade(int newLevel) {
    List<String> newParticleEffects = List.from(particleEffects);
    List<String> newLevelEffects = List.from(levelEffects);
    String newBorderEffect = borderEffect;
    String newBackgroundEffect = backgroundEffect;
    bool newHasAnimation = hasAnimation;
    double newGlowIntensity = glowIntensity;

    // Добавляем эффекты в зависимости от уровня
    if (newLevel >= 2 && !levelEffects.contains('level_2')) {
      newLevelEffects.add('level_2');
      newParticleEffects.add('sparkle_small');
    }
    if (newLevel >= 3 && !levelEffects.contains('level_3')) {
      newLevelEffects.add('level_3');
      newBorderEffect = 'glowing';
      newGlowIntensity = 0.3;
    }
    if (newLevel >= 4 && !levelEffects.contains('level_4')) {
      newLevelEffects.add('level_4');
      newBackgroundEffect = 'swirling';
      newParticleEffects.add('sparkle_medium');
      newGlowIntensity = 0.6;
    }
    if (newLevel >= 5 && !levelEffects.contains('level_5')) {
      newLevelEffects.add('level_5');
      newHasAnimation = true;
      newParticleEffects.add('sparkle_large');
      newGlowIntensity = 1.0;
    }

    return CardVisuals(
      particleEffects: newParticleEffects,
      borderEffect: newBorderEffect,
      backgroundEffect: newBackgroundEffect,
      levelEffects: newLevelEffects,
      hasAnimation: newHasAnimation,
      glowIntensity: newGlowIntensity,
      isFoil: isFoil,
    );
  }

  CardVisuals copyWithFoil() {
    return CardVisuals(
      particleEffects: List.from(particleEffects)..add('foil_shine'),
      borderEffect: borderEffect == 'none' ? 'foil' : borderEffect,
      backgroundEffect: 'foil',
      levelEffects: List.from(levelEffects),
      hasAnimation: true,
      glowIntensity: glowIntensity + 0.2,
      isFoil: true,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'particleEffects': particleEffects,
      'borderEffect': borderEffect,
      'backgroundEffect': backgroundEffect,
      'levelEffects': levelEffects,
      'hasAnimation': hasAnimation,
      'glowIntensity': glowIntensity,
      'isFoil': isFoil,
    };
  }

  factory CardVisuals.fromJson(Map<String, dynamic> json) {
    return CardVisuals(
      particleEffects: List<String>.from(json['particleEffects'] ?? []),
      borderEffect: json['borderEffect'] ?? 'none',
      backgroundEffect: json['backgroundEffect'] ?? 'none',
      levelEffects: List<String>.from(json['levelEffects'] ?? []),
      hasAnimation: json['hasAnimation'] ?? false,
      glowIntensity: (json['glowIntensity'] ?? 0.0).toDouble(),
      isFoil: json['isFoil'] ?? false,
    );
  }
}

/// Модель аниме-карты с поддержкой дубликатов
class AnimeCard {
  final String id;
  final String characterName;
  final String animeName;
  final String imageUrl;
  final CardRarity rarity;
  final String description;
  final int level;
  final DateTime createdAt; // Add this field
  final String skill;
  final String quote;
  final DateTime obtainedAt;

  // НОВЫЕ ПОЛЯ ДЛЯ БОЕВОЙ СИСТЕМЫ
  final AnimeGenre genre;
  final CharacterArchetype archetype;
  final AbilityType abilityType;
  final BattleStats stats;

  // Визуальные эффекты
  final CardVisuals visuals;

  // НОВОЕ: Количество дубликатов и базовая карта
  final int duplicateCount;
  final String baseCardId; // ID оригинальной карты для группировки

  AnimeCard({
    required this.id,
    required this.characterName,
    required this.animeName, 
    required this.imageUrl,
    required this.rarity,
    required this.description,
    required this.level,
    required this.skill,
    required this.quote,
    required this.obtainedAt,
    required this.genre,
    required this.archetype, 
    required this.abilityType,
    required this.stats,
    this.visuals = const CardVisuals(),
    this.duplicateCount = 1,
    required this.baseCardId,
    DateTime? createdAt, // Make it optional
  }) : createdAt = createdAt ?? DateTime.now(); // Default to current time

  /// Метод для копирования карты с измененными полями
  AnimeCard copyWith({
    String? id,
    String? characterName,
    String? animeName,
    String? imageUrl,
    CardRarity? rarity,
    String? description,
    int? level,
    String? skill,
    String? quote,
    DateTime? obtainedAt,
    AnimeGenre? genre,
    CharacterArchetype? archetype,
    AbilityType? abilityType,
    BattleStats? stats,
    CardVisuals? visuals,
    int? duplicateCount,
    String? baseCardId,
  }) {
    return AnimeCard(
      id: id ?? this.id,
      characterName: characterName ?? this.characterName,
      animeName: animeName ?? this.animeName,
      imageUrl: imageUrl ?? this.imageUrl,
      rarity: rarity ?? this.rarity,
      description: description ?? this.description,
      level: level ?? this.level,
      skill: skill ?? this.skill,
      quote: quote ?? this.quote,
      obtainedAt: obtainedAt ?? this.obtainedAt,
      genre: genre ?? this.genre,
      archetype: archetype ?? this.archetype,
      abilityType: abilityType ?? this.abilityType,
      stats: stats ?? this.stats,
      visuals: visuals ?? this.visuals,
      duplicateCount: duplicateCount ?? this.duplicateCount,
      baseCardId: baseCardId ?? this.baseCardId,
    );
  }

  /// Метод для улучшения карты (использует дубликаты)
  AnimeCard copyWithUpgrade() {
    return AnimeCard(
      id: id,
      characterName: characterName,
      animeName: animeName,
      imageUrl: imageUrl,
      rarity: rarity,
      description: description,
      level: level + 1,
      skill: skill,
      quote: quote,
      obtainedAt: obtainedAt,
      genre: genre,
      archetype: archetype,
      abilityType: abilityType,
      stats: stats.copyWithUpgrade(level + 1),
      visuals: visuals.copyWithUpgrade(level + 1),
      duplicateCount: duplicateCount - getRequiredDuplicatesForUpgrade(),
      baseCardId: baseCardId,
    );
  }

  /// Метод для создания фольгированной версии
  AnimeCard copyWithFoil() {
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
      obtainedAt: obtainedAt,
      genre: genre,
      archetype: archetype,
      abilityType: abilityType,
      stats: stats,
      visuals: visuals.copyWithFoil(),
      duplicateCount: duplicateCount,
      baseCardId: baseCardId,
    );
  }

  /// Количество дубликатов необходимое для улучшения
  int getRequiredDuplicatesForUpgrade() {
    switch (level) {
      case 1: return 2;
      case 2: return 3;
      case 3: return 5;
      case 4: return 8;
      default: return 0;
    }
  }

  /// Можно ли улучшить карту
  bool get canUpgrade => duplicateCount >= getRequiredDuplicatesForUpgrade() && level < 5;

  /// Стоимость улучшения в монетах
  int get upgradeCost => level * 50 * (rarity.index + 1);

  /// Создание карты из JSON
  factory AnimeCard.fromJson(Map<String, dynamic> json) {
    return AnimeCard(
      id: json['id'] ?? 'unknown',
      characterName: json['characterName'] ?? 'Unknown',
      animeName: json['animeName'] ?? 'Unknown Anime',
      imageUrl: json['imageUrl'] ?? '',
      rarity: _parseRarity(json['rarity']),
      description: json['description'] ?? 'Mysterious character',
      level: json['level'] ?? 1,
      skill: json['skill'] ?? 'Базовая атака',
      quote: json['quote'] ?? '...',
      obtainedAt: DateTime.parse(json['obtainedAt'] ?? DateTime.now().toIso8601String()),
      genre: _parseGenre(json['genre']),
      archetype: _parseArchetype(json['archetype']),
      abilityType: _parseAbilityType(json['abilityType']),
      stats: BattleStats.fromJson(Map<String, dynamic>.from(json['stats'] ?? {})),
      visuals: CardVisuals.fromJson(Map<String, dynamic>.from(json['visuals'] ?? {})),
      duplicateCount: json['duplicateCount'] ?? 1,
      baseCardId: json['baseCardId'] ?? json['id'] ?? 'unknown',
    );
  }

  /// Конвертация в JSON для сохранения
  Map<String, dynamic> toJson() => {
    'id': id,
    'characterName': characterName,
    'animeName': animeName,
    'imageUrl': imageUrl,
    'rarity': rarity.toString(),
    'description': description,
    'level': level,
    'skill': skill,
    'quote': quote,
    'obtainedAt': obtainedAt.toIso8601String(),
    'genre': genre.toString(),
    'archetype': archetype.toString(),
    'abilityType': abilityType.toString(),
    'stats': stats.toJson(),
    'visuals': visuals.toJson(),
    'duplicateCount': duplicateCount,
    'baseCardId': baseCardId,
  };

  /// Вспомогательные методы для парсинга
  static CardRarity _parseRarity(String rarityString) {
    for (final rarity in CardRarity.values) {
      if (rarity.toString() == rarityString) {
        return rarity;
      }
    }
    return CardRarity.common;
  }

  static AnimeGenre _parseGenre(String genreString) {
    for (final genre in AnimeGenre.values) {
      if (genre.toString() == genreString) {
        return genre;
      }
    }
    return AnimeGenre.action;
  }

  static CharacterArchetype _parseArchetype(String archetypeString) {
    for (final archetype in CharacterArchetype.values) {
      if (archetype.toString() == archetypeString) {
        return archetype;
      }
    }
    return CharacterArchetype.hero;
  }

  static AbilityType _parseAbilityType(String abilityTypeString) {
    for (final abilityType in AbilityType.values) {
      if (abilityType.toString() == abilityTypeString) {
        return abilityType;
      }
    }
    return AbilityType.passive;
  }

  /// Геттеры для удобства
  List<Color> get cardGradient => rarity.gradientColors;
  Color get glowEffect => rarity.borderColor.withOpacity(0.5);

  /// Стоимость продажи
  int get sellPrice => (stats.power * 10 * rarity.powerMultiplier).toInt();

  /// Опыт за карту
  int get experience => (level * 10 * rarity.powerMultiplier).toInt();

  /// Получить описание архетипа
  String get archetypeDescription => '${archetype.emoji} ${archetype.displayName} - ${archetype.description}';

  /// Получить описание способности  
  String get abilityDescription => '${abilityType.displayName} - ${abilityType.description}';

  /// Геттеры для совместимости
  int get power => stats.power;
  int get hp => stats.resonance;
  int get mp => stats.stability;
  int get attack => stats.power;
  int get defense => stats.stability;
  int get speed => stats.resonance;
  int get health => stats.power + stats.resonance;
}

/// Модель для группировки карт по базовому ID - ИСПРАВЛЕННАЯ ВЕРСИЯ
class CardGroup {
  final String baseCardId;
  final AnimeCard baseCard;
  final List<AnimeCard> duplicates;

  CardGroup({
    required this.baseCardId,
    required this.baseCard,
    required this.duplicates,
  });

  /// Общее количество карт (базовая + дубликаты)
  int get totalCount {
    int total = baseCard.duplicateCount;
    for (final duplicate in duplicates) {
      total += duplicate.duplicateCount;
    }
    return total;
  }

  /// Количество дубликатов доступных для улучшения
  int get availableForUpgrade {
    // Берем все дубликаты кроме одной базовой карты
    return (totalCount - 1).clamp(0, totalCount);
  }

  /// Можно ли улучшить базовую карту
  bool get canUpgrade {
    final required = baseCard.getRequiredDuplicatesForUpgrade();
    return availableForUpgrade >= required && baseCard.level < 5;
  }

  /// Получить все карты группы
  List<AnimeCard> get allCards {
    final all = [baseCard];
    all.addAll(duplicates);
    return all;
  }
}