import '../models/card_models.dart';

enum PlayerType { playerA, playerB }

enum GamePhase {
  botTurnSetup,      
  playerTurnInput,   
  botReaction,       
  vsClashScreen,     
  roundCleanup       
}

class PlayerState {
  final PlayerType type;
  int hp;
  int inf;
  List<GameCard> hand;
  List<GameCard> deck; 
  GameCard? activeCard; 

  PlayerState({
    required this.type,
    this.hp = 6,
    this.inf = 10, // CHANGED: Starts at 10 on Round 1
    required this.hand,
    required this.deck,
  });

  bool get isEmpty => activeCard == null;

  List<GameCard?> get lanes => [activeCard];
  void resolveCardToDiscard(GameCard card) {
    hand.removeWhere((c) => c.id == card.id);
  }
}

class GameEngine {
  late PlayerState playerA;
  late PlayerState playerB;
  int turnCount = 1; 
  static const int maxInf = 10;
  PlayerType currentTurn = PlayerType.playerA;
  GamePhase currentPhase = GamePhase.botTurnSetup;

  GameEngine get state => this; 

  GameEngine({required List<GameCard> deckA, required List<GameCard> deckB}) {
    playerA = PlayerState(
      type: PlayerType.playerA, 
      hand: List.from(deckA.take(5)),
      deck: List.from(deckA.skip(5)),
      hp: 6,
      inf: 10, // CHANGED: Initialized to 10
    );
    playerB = PlayerState(
      type: PlayerType.playerB, 
      hand: List.from(deckB.take(5)),
      deck: List.from(deckB.skip(5)),
      hp: 6,
      inf: 10, // CHANGED: Initialized to 10
    );
  }

void startNewRound() {
  if (playerA.deck.isNotEmpty) {
    playerA.hand.add(playerA.deck.removeAt(0));
  }
  if (playerB.deck.isNotEmpty) {
    playerB.hand.add(playerB.deck.removeAt(0));
  }

  turnCount += 1;
  addInfluenceForNewRound();

  // SAFE CLEAR (after round is fully resolved)
  playerA.activeCard = null;
  playerB.activeCard = null;
}

  // ====================================================================
  // CHANGED: Adds +2 on top of what you already have left over
  // ====================================================================
 void addInfluenceForNewRound() {
  playerA.inf = (playerA.inf + 2).clamp(0, maxInf);
  playerB.inf = (playerB.inf + 2).clamp(0, maxInf);
}

  bool playCard(GameCard card, PlayerType player) {
    final pState = (player == PlayerType.playerA) ? playerA : playerB;
    if (!pState.isEmpty) return false; 
    if (pState.inf < card.inf) return false;

    pState.inf -= card.inf;
    pState.hand.removeWhere((c) => c.id == card.id);
    pState.activeCard = card;
    return true;
  }

  bool get isGameOver => playerA.hp <= 0 || playerB.hp <= 0;

PlayerType? get winner {
  if (playerA.hp <= 0 && playerB.hp <= 0) return null;
  if (playerA.hp <= 0) return PlayerType.playerB;
  if (playerB.hp <= 0) return PlayerType.playerA;
  return null;
}
}