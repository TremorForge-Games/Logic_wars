import 'dart:convert';
import 'package:flutter/services.dart';
import '../models/card_models.dart';

class CardLoader {
  /// Loads the master card database from cards_library.json
  static Future<List<GameCard>> loadCardsLibrary() async {
    try {
      final String response = await rootBundle.loadString('assets/Data/cards_library.json');
      final data = await json.decode(response);
      
      var list = data['cards'] as List? ?? [];
      return list.map((jsonItem) => GameCard.fromJson(jsonItem)).toList();
    } catch (e) {
      print("Error loading card library JSON: $e");
      return [];
    }
  }
}