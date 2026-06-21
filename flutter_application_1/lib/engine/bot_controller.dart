import 'game_engine.dart';
import '../models/card_models.dart';

class BotController {
  static Future<void> runAI(GameEngine engine) async {
    // Artificial delay to simulate thinking time
    await Future.delayed(const Duration(milliseconds: 600));

    final bot = engine.playerB;

    // If the bot has already laid a card this phase, do nothing
    if (bot.activeCard != null) return;

    // Find all cards the bot can actually afford with its current influence pool
    List<GameCard> affordableCards = bot.hand.where((card) => card.inf <= bot.inf).toList();

    if (affordableCards.isNotEmpty) {
      // Sort by Combat Power (crb) descending so it prioritizes aggressive high stats
      affordableCards.sort((a, b) => b.crb.compareTo(a.crb));
      
      // Play the strongest card it can afford
      GameCard cardToPlay = affordableCards.first;
      engine.playCard(cardToPlay, PlayerType.playerB);
    } else {
      // Explicit fallback fallback: The bot only passes if it literally cannot afford anything
      print("Bot cannot afford any cards this round, forced to pass.");
    }
  }
}