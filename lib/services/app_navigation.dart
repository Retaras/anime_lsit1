// services/app_navigation.dart
import 'package:flutter/material.dart';
import '../screens/card_collection_screen.dart';
import '../screens/deck_building_screen.dart';
import '../screens/reality_battle_screen.dart';
import '../services/card_game_service.dart';

class AppNavigation {
  static void toCollection(BuildContext context) {
    Navigator.push(context, MaterialPageRoute(builder: (_) => const CardCollectionScreen()));
  }

  static void toDeckBuilder(BuildContext context) {
    Navigator.push(context, MaterialPageRoute(builder: (_) => const DeckBuildingScreen()));
  }

  static Future<void> toBattle(BuildContext context) async {
    final deck = await CardGameService.loadDeck();
    if (context.mounted) {
      Navigator.push(context, MaterialPageRoute(
        builder: (_) => RealityBattleScreen(playerDeck: deck),
      ));
    }
  }

  static void showErrorSnackBar(BuildContext context, String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.red,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  static void showSuccessSnackBar(BuildContext context, String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.green,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }
}