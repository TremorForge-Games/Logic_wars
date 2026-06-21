import 'card_models.dart';
import 'combat_log.dart';

// ====== Enums ======

enum GamePhase {
  botTurnSetup,      // Bot decides to place a card or pass first
  playerTurnInput,   // Player can drag a card or pass (Revert button active if card placed)
  botReaction,       // Bot responds to your placement or pass
  vsClashScreen,     // Cards go to VS screen, effects trigger, results show
  roundCleanup       // Processing card deaths/ties before starting next round
}

enum Player {
  playerA,
  playerB,
}

// ====== Lane ======

class Lane {
  final int index;
  GameCard? activeCard;
  GameCard? queuedCard;

  Lane({required this.index, this.activeCard, this.queuedCard});

  bool get isEmpty => activeCard == null;
  bool get hasQueued => queuedCard != null;
}

// ====== Pending Attack ======

class PendingAttack {
  final int fromLane;
  final int toLane;
  final bool multiLane;

  PendingAttack({
    required this.fromLane,
    required this.toLane,
    this.multiLane = false,
  });
}

// ====== Player State ======

class PlayerState {
  final Player player;
  int hp;
  int inf;
  List<GameCard> hand;
  List<GameCard> deck;
  List<GameCard> discard;
  List<Lane> lanes;
  bool isBot;

  // Pending modifier states applied when next card is played
  int pendingNextCardCrbBuff = 0;
  int pendingNextCardCostChange = 0;
  bool nextCardSilenced = false;

  PlayerState({
    required this.player,
    this.hp = 6,
    this.inf = 0,
    List<GameCard>? hand,
    List<GameCard>? deck,
    List<GameCard>? discard,
    List<Lane>? lanes,
    this.isBot = false,
  })  : hand = hand ?? [],
        deck = deck ?? [],
        discard = discard ?? [],
        lanes = lanes ?? List.generate(3, (i) => Lane(index: i));

  bool get isAlive => hp > 0;
  bool get hasDeck => deck.isNotEmpty;

  void drawCards(int amount) {
    for (int i = 0; i < amount; i++) {
      if (deck.isNotEmpty) {
        hand.add(deck.removeAt(0));
      }
    }
  }

  bool playCard(GameCard card, int laneIndex) {
    if (!hand.contains(card)) return false;
    
    final effectiveCost = (card.inf + pendingNextCardCostChange).clamp(0, 999);
    if (inf < effectiveCost) return false;
    
    final lane = lanes[laneIndex];
    if (lane.activeCard != null) return false;
    
    hand.remove(card);
    inf -= effectiveCost;
    lane.activeCard = card;
    
    // Apply temporary/pending modifications safely if mutable on model
    if (pendingNextCardCrbBuff != 0) {
      // Note: If card.crb is final in your model, apply this inside your engine or make crb var
      // card.crb += pendingNextCardCrbBuff; 
      pendingNextCardCrbBuff = 0;
    }
    
    if (nextCardSilenced) {
      // card.silenced = true; // Safe check if using custom status tags
      nextCardSilenced = false;
    }
    
    pendingNextCardCostChange = 0;
    return true;
  }

  void gainInf(int amount, {int cap = 10}) {
    inf = (inf + amount).clamp(0, cap);
  }

  void loseInf(int amount) {
    inf = (inf - amount).clamp(0, 999);
  }

  bool discardFromHand(GameCard card) {
    if (!hand.contains(card)) return false;
    hand.remove(card);
    discard.add(card);
    return true;
  }

  void resolveCardToDiscard(int laneIndex) {
    final lane = lanes[laneIndex];
    if (lane.activeCard != null) {
      discard.add(lane.activeCard!);
      lane.activeCard = lane.queuedCard;
      lane.queuedCard = null;
    }
  }
}

// ====== Game State ======

class GameState {
  Player currentTurn;
  GamePhase phase;
  PlayerState playerA;
  PlayerState playerB;
  List<PendingAttack> pendingAttacks;
  int roundNumber;
  String? lastActionLog;
  CombatLog? lastCombatLog;

  GameState({
    this.currentTurn = Player.playerA,
    this.phase = GamePhase.botTurnSetup,
    required this.playerA,
    required this.playerB,
    List<PendingAttack>? pendingAttacks,
    this.roundNumber = 1,
    this.lastActionLog,
  }) : pendingAttacks = pendingAttacks ?? [];

  PlayerState get activePlayer =>
      currentTurn == Player.playerA ? playerA : playerB;

  PlayerState get inactivePlayer =>
      currentTurn == Player.playerA ? playerB : playerA;

  PlayerState get reactingPlayer =>
      currentTurn == Player.playerA ? playerB : playerA;

  bool get isGameOver =>
      !playerA.isAlive ||
      !playerB.isAlive ||
      (!playerA.hasDeck && playerA.hand.isEmpty) ||
      (!playerB.hasDeck && playerB.hand.isEmpty);

  Player? get winner {
    if (!isGameOver) return null;
    if (!playerA.isAlive) return Player.playerB;
    if (!playerB.isAlive) return Player.playerA;
    if (!playerA.hasDeck && playerA.hand.isEmpty) return Player.playerB;
    if (!playerB.hasDeck && playerB.hand.isEmpty) return Player.playerA;
    return null;
  }

  void log(String message) {
    lastActionLog = message;
  }

  /// Manages chronological transitions across your custom state machine loops
  void advancePhase() {
    switch (phase) {
      case GamePhase.botTurnSetup:
        phase = GamePhase.playerTurnInput;
        currentTurn = Player.playerA;
        break;
      case GamePhase.playerTurnInput:
        phase = GamePhase.botReaction;
        currentTurn = Player.playerB;
        break;
      case GamePhase.botReaction:
        phase = GamePhase.vsClashScreen;
        break;
      case GamePhase.vsClashScreen:
        phase = GamePhase.roundCleanup;
        break;
      case GamePhase.roundCleanup:
        // Reset state loops back to starting positions, increment round count
        roundNumber++;
        phase = GamePhase.botTurnSetup;
        currentTurn = Player.playerB; // Bot goes first on next turn loop setup
        break;
    }
  }
}

// Extension to add peaceful turn check
extension GameStateExtension on GameState {
  bool get isPlayerAPeacefulTurn =>
      roundNumber == 1 && currentTurn == Player.playerA;
}