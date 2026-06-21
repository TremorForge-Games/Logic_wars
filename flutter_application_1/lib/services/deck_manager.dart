// lib/services/deck_manager.dart

import 'dart:convert';
import 'package:flutter/services.dart';
import '../models/card_models.dart';

class DeckManager {
  /// Loads raw recipes from your decks_presets.json asset
  static Future<List<String>> loadRecipeFromJSON(String deckId) async {
    try {
      final String response = await rootBundle.loadString('assets/Data/decks_presets.json');
      final data = await json.decode(response);
      
      var presets = data['presets'] as List? ?? [];
      final targetPreset = presets.firstWhere(
        (p) => p['id'] == deckId,
        orElse: () => throw Exception("Preset Deck ID '$deckId' not found in JSON!"),
      );

      // Extract the array of card string IDs
      List<String> cardIds = List<String>.from(targetPreset['cards']);
      return cardIds;
    } catch (e) {
      print("Error reading deck presets: $e");
      return [];
    }
  }

  /// Takes a list of card string IDs and builds real GameCards from your master cards library catalog
  static List<GameCard> buildDeckFromRecipe(List<String> recipe, List<GameCard> masterLibrary) {
    List<GameCard> builtDeck = [];
    
    for (String id in recipe) {
      final masterCard = masterLibrary.firstWhere(
        (card) => card.id == id,
        orElse: () => throw Exception("Card ID $id from deck recipe missing from master library!"),
      );
      builtDeck.add(masterCard.copy());
    }
    
    return builtDeck;
  }

  /// Rule Validator: Ensures a deck follows your school project's structural limits
  static bool validateDeckRules(List<GameCard> deck) {
    // Rule 1: Must be exactly 20 cards
    if (deck.length != 20) {
      print("Validation Fail: Deck size must be exactly 20. Contains: ${deck.length}");
      return false;
    }

    // Rule 2: Max 4 copies of any single card ID
    Map<String, int> counts = {};
    for (var card in deck) {
      counts[card.id] = (counts[card.id] ?? 0) + 1;
      if (counts[card.id]! > 4) {
        print("Validation Fail: '${card.name}' exceeded maximum allowance limit (Max 4 copies).");
        return false;
      }
    }

    return true;
  }
}