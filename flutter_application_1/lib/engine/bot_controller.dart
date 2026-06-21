import 'dart:math';
import '../models/game_state.dart';
import '../models/card_models.dart';
import 'game_engine.dart';

class BotController {
  static final Random _random = Random();

  static Future<void> runAI(GameEngine engine) async {
    final state = engine.state;
    if (state.isGameOver || state.currentTurn != Player.playerB) return;

    switch (state.phase) {
      case GamePhase.buildPhase:
        await _handleBuildPhase(engine);
        break;
      case GamePhase.attackPhase:
        await _handleAttackPhase(engine);
        break;
      case GamePhase.reactionPhase:
        await _handleReactionPhase(engine);
        break;
      default:
        break;
    }
  }

  static Future<void> _handleBuildPhase(GameEngine engine) async {
    final bot = engine.state.playerB;
    List<int> emptyLanes = [];
    for (int i = 0; i < bot.lanes.length; i++) {
      if (bot.lanes[i].isEmpty) emptyLanes.add(i);
    }
    emptyLanes.shuffle(_random);

    for (int laneIndex in emptyLanes) {
      List<GameCard> playableCards =
          bot.hand.where((card) => card.inf <= bot.inf).toList();
      if (playableCards.isEmpty) break;

      final selected = playableCards[_random.nextInt(playableCards.length)];
      engine.playCardInBuild(selected, laneIndex);
      engine.state.lastActionLog =
          'Bot plays ${selected.name} in Lane $laneIndex';
      engine.state.lastActionLog; // trigger UI rebuild
      await Future.delayed(const Duration(milliseconds: 700));
    }

    engine.endBuildPhase();
    await Future.delayed(const Duration(milliseconds: 700));
  }

  static Future<void> _handleAttackPhase(GameEngine engine) async {
    final bot = engine.state.playerB;

    for (int i = 0; i < bot.lanes.length; i++) {
      if (!bot.lanes[i].isEmpty) {
        final targetLane = _random.nextInt(3);
        engine.declareAttack(i, targetLane);
        engine.state.lastActionLog =
            'Bot declares attack from Lane $i to Lane $targetLane';
        await Future.delayed(const Duration(milliseconds: 700));
      }
    }

    engine.finalizeAttacks();
    await Future.delayed(const Duration(milliseconds: 700));
  }

  static Future<void> _handleReactionPhase(GameEngine engine) async {
    final reactingPlayer = engine.state.reactingPlayer;

    if (!reactingPlayer.isBot) {
      // Human player will react via UI, do NOT auto-resolve
      return;
    }

    // Bot reaction lane processing
    for (int i = 0; i < 3; i++) {
      final isUnderAttack =
          engine.state.pendingAttacks.any((a) => a.toLane == i);

      // If no attacks target this lane, cleanly skip it
      if (!isUnderAttack) continue;

      final lane = reactingPlayer.lanes[i];

      // Strict Rule Implementation: Bot can ONLY play cards in an empty lane!
      if (lane.isEmpty) {
        final affordable =
            reactingPlayer.hand.where((c) => c.inf <= reactingPlayer.inf).toList();
        
        if (affordable.isNotEmpty) {
          // Sort to choose its highest CRB card to try and secure a tie/win
          affordable.sort((a, b) => b.crb.compareTo(a.crb));
          final selectedBlocker = affordable.first;

          engine.playReactionCard(selectedBlocker, i);
          engine.state.lastActionLog = 'Bot plays defensive blocker ${selectedBlocker.name} in Lane $i';
          await Future.delayed(const Duration(milliseconds: 700));
        } else {
          // No resources available, bot must pass this lane
          engine.passReactionOnLane(i);
        }
      } else {
        // A card is already here! Enforce 1-card maximum restriction by forcing a pass
        engine.passReactionOnLane(i);
      }
    }

    engine.completeReactionPhase();
  }
}