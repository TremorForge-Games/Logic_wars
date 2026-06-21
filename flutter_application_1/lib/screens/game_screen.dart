import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show rootBundle;
import '../services/deck_manager.dart';
import '../engine/game_engine.dart' hide GamePhase;
import '../engine/game_engine.dart';
import '../engine/bot_controller.dart';
import '../models/card_models.dart';
import '../widgets/hand_list.dart';

class GameScreen extends StatefulWidget {
  const GameScreen({Key? key}) : super(key: key);

  @override
  State<GameScreen> createState() => _GameScreenState();
}

class _GameScreenState extends State<GameScreen>
    with SingleTickerProviderStateMixin {
  GameEngine? _engine;
  bool _loading = true;
  GameCard? _lastPlacedCard;

  String _clashStatusText = "Battle begins";
  bool _runAttackRotationAnimation = false;
  List<String> _finalBotPenaltiesText = [];

  @override
  void initState() {
    super.initState();
    _bootGameSystem();
  }

  Future<void> _bootGameSystem() async {
    try {
      final String jsonString = await rootBundle.loadString(
        'assets/Data/cards_library.json',
      );
      final Map<String, dynamic> rawJsonMap = json.decode(jsonString);
      final List<dynamic> jsonList = rawJsonMap['cards'] as List<dynamic>;

      final List<GameCard> loadedDeck = jsonList.map((item) {
        final List<dynamic> rawEffects =
            item['effects'] as List<dynamic>? ?? [];
        final List<CardEffect> typedEffects = rawEffects.map((eff) {
          return CardEffect(
            trigger: eff['trigger'] as int,
            target: eff['target'] as int,
            effectId: eff['effect_id'] as int,
            params: eff['params'] as Map<String, dynamic>? ?? {},
          );
        }).toList();

        return GameCard(
          id: item['id'] as String,
          name: item['name'] as String,
          category: item['category'] as String,
          crb: item['crb'] as int,
          inf: item['inf'] as int,
          effects: typedEffects,
          image: item['image'] as String,
        );
      }).toList();

      final recipeA = await DeckManager.loadRecipeFromJSON("2");
      final recipeB = await DeckManager.loadRecipeFromJSON("1");

      final deckA = DeckManager.buildDeckFromRecipe(recipeA, loadedDeck);
      final deckB = DeckManager.buildDeckFromRecipe(recipeB, loadedDeck);

      _engine = GameEngine(deckA: deckA, deckB: deckB);
      loadedDeck.clear();
      jsonList.clear();

      setState(() {
        _loading = false;
      });

      _executePhaseSequence();
    } catch (e) {
      debugPrint("Error loading structural JSON schema: $e");
    }
  }

  void _executePhaseSequence() async {
    if (_engine == null) return;
    if (_engine!.currentPhase == GamePhase.botTurnSetup) {
      setState(() {});
      await BotController.runAI(_engine!);
      setState(() => _engine!.currentPhase = GamePhase.playerTurnInput);
    }
  }

  void _handlePlayerCardDrop(GameCard card) {
    if (_engine!.currentPhase != GamePhase.playerTurnInput) return;
    final success = _engine!.playCard(card, PlayerType.playerA);
    if (success) {
      setState(() => _lastPlacedCard = card);
    }
  }

  void _revertLastMove() {
    if (_lastPlacedCard == null) return;
    setState(() {
      _engine!.playerA.inf += _lastPlacedCard!.inf;
      _engine!.playerA.hand.add(_lastPlacedCard!);
      _engine!.playerA.activeCard = null;
      _lastPlacedCard = null;
    });
  }

  void _commitAndContinue() async {
    if (_engine!.currentPhase != GamePhase.playerTurnInput) return;

    setState(() {
      _lastPlacedCard = null;
      _engine!.currentPhase = GamePhase.botReaction;
    });

    await BotController.runAI(_engine!);

    setState(() => _engine!.currentPhase = GamePhase.vsClashScreen);
    _executeVisualClashSequence();
  }

  void _executeVisualClashSequence() async {
    // LOCK STATE IMMEDIATELY (CRITICAL FIX)
    final GameCard? lockedPlayerCard = _engine!.playerA.activeCard;
    final GameCard? lockedBotCard = _engine!.playerB.activeCard;

    setState(() => _clashStatusText = "Clashing...");
    await Future.delayed(const Duration(milliseconds: 1000));

    setState(() => _runAttackRotationAnimation = true);
    await Future.delayed(const Duration(milliseconds: 600));

    setState(() {
      _runAttackRotationAnimation = false;

      final GameCard? pCard = lockedPlayerCard;
      final GameCard? bCard = lockedBotCard;

      final int playerPower = pCard != null ? pCard.crb : 0;
      final int botPower = bCard != null ? bCard.crb : 0;

      if (pCard == null && bCard != null) {
        _clashStatusText = "BOT WINS!";
        _finalBotPenaltiesText = [
          "• You passed and left your lane open!",
          "• Bot punished your pass with ${bCard.name} ($botPower CRB)",
          "• You lost 1 HP",
        ];
        if (_engine!.playerA.hp > 0) _engine!.playerA.hp -= 1;
      } else if (pCard != null && bCard == null) {
        _clashStatusText = "YOU WIN!";
        _finalBotPenaltiesText = [
          "• Bot passed its phase!",
          "• Your ${pCard.name} hits for $playerPower CRB",
          "• Bot lost 1 HP",
        ];
        if (_engine!.playerB.hp > 0) _engine!.playerB.hp -= 1;
      } else {
        if (playerPower > botPower) {
          _engine!.playerA.inf = (_engine!.playerA.inf + 1).clamp(
            0,
            GameEngine.maxInf,
          );

          _clashStatusText = "YOU WIN!";
          _finalBotPenaltiesText = [
            "• Outpowered opponent ($playerPower vs $botPower)",
            "• Opponent lost 1 HP",
            "• You gain 1 INF as consolation",
          ];
          if (_engine!.playerB.hp > 0) _engine!.playerB.hp -= 1;
        } else if (botPower > playerPower) {
          _engine!.playerB.inf = (_engine!.playerB.inf + 1).clamp(
            0,
            GameEngine.maxInf,
          );

          _clashStatusText = "BOT WINS!";
          _finalBotPenaltiesText = [
            "• Bot outpowered you ($botPower vs $playerPower)",
            "• You lost 1 HP",
            "• Bot gained 1 INF as consolation",
          ];
          if (_engine!.playerA.hp > 0) _engine!.playerA.hp -= 1;
        } else {
          _clashStatusText = "TIE CLASH!";
          _finalBotPenaltiesText = [
            playerPower == 0
                ? "• Both players passed this round"
                : "• Clash tied at $playerPower CRB",
            "• No damage taken",
          ];
        }
      }
    });

    await Future.delayed(const Duration(milliseconds: 2000));

    // FINAL UI DECISION (NO RACE CONDITIONS)
    if (!mounted) return;

    if (_engine!.playerA.hp <= 0 || _engine!.playerB.hp <= 0) {
      _showGameOverScreen();
      return;
    }

    _showSummaryOverlayPanel();
  }

  void _showGameOverScreen() {
    final winner = _engine!.playerA.hp <= 0
        ? "BOT WINS"
        : _engine!.playerB.hp <= 0
        ? "YOU WIN"
        : "DRAW";

    showGeneralDialog(
      context: context,
      barrierDismissible: false,
      pageBuilder: (context, _, __) {
        return Scaffold(
          backgroundColor: Colors.black,
          body: Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  winner,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 34,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 30),

                ElevatedButton(
                  onPressed: () {
                    Navigator.pop(context);
                    Navigator.pushReplacement(
                      context,
                      MaterialPageRoute(builder: (_) => const GameScreen()),
                    );
                  },
                  child: const Text("Play Again"),
                ),

                const SizedBox(height: 10),

                TextButton(
                  onPressed: () {
                    Navigator.popUntil(context, (route) => route.isFirst);
                  },
                  child: const Text(
                    "Return to Main Menu",
                    style: TextStyle(color: Colors.white70),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  void _showSummaryOverlayPanel() {
    showGeneralDialog(
      context: context,
      barrierDismissible: false,
      pageBuilder: (context, __, ___) {
        return Scaffold(
          backgroundColor: Colors.black.withOpacity(0.95),
          body: Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  _clashStatusText == "YOU WIN!"
                      ? 'ROUND WON'
                      : (_clashStatusText == "BOT WINS!"
                            ? 'ROUND LOST'
                            : 'ROUND TIED'),
                  style: TextStyle(
                    color: _clashStatusText == "YOU WIN!"
                        ? Colors.greenAccent
                        : (_clashStatusText == "BOT WINS!"
                              ? Colors.redAccent
                              : Colors.amber),
                    fontSize: 32,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 20),
                const Text(
                  'BOT COMBAT REMINDERS:',
                  style: TextStyle(color: Colors.white60, fontSize: 13),
                ),
                const SizedBox(height: 8),
                if (_finalBotPenaltiesText.isEmpty)
                  const Text(
                    'No Penalties Taken',
                    style: TextStyle(color: Colors.white70, fontSize: 16),
                  ),
                ..._finalBotPenaltiesText.map(
                  (text) => Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16.0,
                      vertical: 2.0,
                    ),
                    child: Text(
                      text,
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        color: Colors.amberAccent,
                        fontSize: 15,
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 32),
                ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.blueAccent,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 36,
                      vertical: 12,
                    ),
                  ),
                  onPressed: () {
                    Navigator.pop(context);
                    setState(() {
                      _finalBotPenaltiesText.clear();

                      // 1. Advance the engine turn counters and reset pools
                      _engine!.startNewRound();

                      // 2. CRITICAL CRACK: Tell the state machine it is your turn to play!
                      _engine!.currentPhase = GamePhase.playerTurnInput;

                      // 3. Reset your visual text banner
                      _clashStatusText = "YOUR TURN — PLAY A CARD";
                    });

                    // 4. Trigger bot setups if any background rules apply
                    _executePhaseSequence();
                  },
                  child: const Text(
                    'CONTINUE',
                    style: TextStyle(fontSize: 16, color: Colors.white),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  void _showHelpSystemDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF1E1E1E),
        title: const Text(
          "HOW TO PLAY",
          style: TextStyle(
            color: Colors.blueAccent,
            fontWeight: FontWeight.bold,
          ),
        ),
        content: const Text(
          "1. The Bot takes its turn automatically and picks it's highest CRB card available.\n\n"
          "2. Drag any valid card from your Hand collection at the bottom right into the Lane Construction Drop Zone.\n\n"
          "3. The Current game does not use card effects. ONly CRB is used to determine card strength.\n\n"
          "4. Press 'Lock Card & Clash' to evaluate stats across the dynamic processing engines.\n\n"
          "5. Influence pool regenerates cleanly at the beginning of each game loop round sequence.",
          style: TextStyle(color: Colors.white70, fontSize: 13, height: 1.4),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text(
              "CLOSE",
              style: TextStyle(
                color: Colors.amber,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _openLargeCardMagnifierPreview(GameCard card) {
    showDialog(
      context: context,
      builder: (context) => GestureDetector(
        onTap: () => Navigator.pop(context),
        child: Container(
          color: Colors.black87,
          padding: const EdgeInsets.all(24.0),
          child: Center(
            child: Hero(
              tag: 'magnify_${card.id}',
              child: ClipRRect(
                borderRadius: BorderRadius.circular(12),
                child: Image.asset(
                  card.image,
                  fit: BoxFit.contain,
                  errorBuilder: (context, _, __) => Container(
                    color: Colors.grey[900],
                    padding: const EdgeInsets.all(20),
                    child: Text(
                      card.name,
                      style: const TextStyle(color: Colors.white, fontSize: 20),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_loading)
      return const Scaffold(
        backgroundColor: Color(0xFF141414),
        body: Center(child: CircularProgressIndicator()),
      );

    final pA = _engine!.playerA;
    final pB = _engine!.playerB;
    final isClashPhase = _engine!.currentPhase == GamePhase.vsClashScreen;

    return Scaffold(
      backgroundColor: const Color(0xFF141414),
      body: SafeArea(
        child: Column(
          children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 2),
              color: Colors.black,
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  IconButton(
                    icon: const Icon(Icons.arrow_back, color: Colors.white70),
                    tooltip: "Return to Menu",
                    onPressed: () => Navigator.of(
                      context,
                    ).popUntil((route) => route.isFirst),
                  ),
                  Text(
                    "ROUND ${_engine!.turnCount}",
                    style: const TextStyle(
                      color: Colors.white60,
                      fontWeight: FontWeight.bold,
                      fontSize: 13,
                    ),
                  ),
                  IconButton(
                    icon: const Icon(
                      Icons.help_outline,
                      color: Colors.blueAccent,
                    ),
                    tooltip: "Game Instructions",
                    onPressed: _showHelpSystemDialog,
                  ),
                ],
              ),
            ),

            _buildPlayerBanner(pB, "BOT", Colors.redAccent),
            _buildTurnStateHeaderIndicator(),

            Expanded(
              child: LayoutBuilder(
                builder: (context, constraints) {
                  return Center(
                    child: SingleChildScrollView(
                      child: Padding(
                        padding: const EdgeInsets.symmetric(vertical: 4.0),
                        child: isClashPhase
                            ? _buildClashArenaLayout(pA, pB)
                            : _buildDragDropConstructionZone(pA, pB),
                      ),
                    ),
                  );
                },
              ),
            ),

            _buildActionControlPanel(),
            _buildPlayerBanner(pA, "YOU", Colors.greenAccent),

            SizedBox(
              height: 135,
              child: HandList(
                hand: pA.hand,
                canInteract: _engine!.currentPhase == GamePhase.playerTurnInput,
                onCardTap: _openLargeCardMagnifierPreview,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTurnStateHeaderIndicator() {
    if (_engine == null) return const SizedBox.shrink();
    final isPlayerTurn = _engine!.currentPhase == GamePhase.playerTurnInput;
    final isClash = _engine!.currentPhase == GamePhase.vsClashScreen;

    String headerText = "PROCESSING ROUND...";
    Color headerColor = Colors.amber;

    if (isPlayerTurn) {
      headerText = "YOUR TURN — PLAY A CARD";
      headerColor = Colors.greenAccent;
    } else if (_engine!.currentPhase == GamePhase.botTurnSetup ||
        _engine!.currentPhase == GamePhase.botReaction) {
      headerText = "BOT IS CHOOSING...";
      headerColor = Colors.redAccent;
    } else if (isClash) {
      headerText = "CLASH ARENA RESOLUTION";
      headerColor = Colors.blueAccent;
    }

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(vertical: 4),
      color: Colors.black38,
      child: Text(
        headerText,
        textAlign: TextAlign.center,
        style: TextStyle(
          color: headerColor,
          fontSize: 10,
          fontWeight: FontWeight.bold,
          letterSpacing: 1.2,
        ),
      ),
    );
  }

  Widget _buildDragDropConstructionZone(PlayerState pA, PlayerState pB) {
    return DragTarget<GameCard>(
      onWillAcceptWithDetails: (_) => pA.isEmpty,
      onAcceptWithDetails: (details) => _handlePlayerCardDrop(details.data),
      builder: (context, candidate, _) {
        return Container(
          width: 200,
          height: 290,
          decoration: BoxDecoration(
            border: Border.all(
              color: candidate.isNotEmpty
                  ? Colors.greenAccent
                  : Colors.grey[900]!,
              width: 2,
            ),
            borderRadius: BorderRadius.circular(12),
            color: Colors.black38,
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              pB.activeCard != null
                  ? _buildImageOnlyCard(pB.activeCard!)
                  : const Text(
                      'Empty Row',
                      style: TextStyle(color: Colors.white12, fontSize: 12),
                    ),
              const Divider(
                color: Colors.white10,
                thickness: 1,
                indent: 24,
                endIndent: 24,
              ),
              pA.activeCard != null
                  ? _buildImageOnlyCard(pA.activeCard!)
                  : const Text(
                      'Empty Lane\n\nDrag card here',
                      textAlign: TextAlign.center,
                      style: TextStyle(color: Colors.white24, fontSize: 12),
                    ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildClashArenaLayout(PlayerState pA, PlayerState pB) {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        const Text(
          'BOT POOL',
          style: TextStyle(
            color: Colors.redAccent,
            letterSpacing: 1.2,
            fontSize: 11,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 8),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
          children: [
            pB.activeCard != null
                ? _buildImageOnlyCard(pB.activeCard!)
                : const SizedBox(width: 80, height: 115),
            AnimatedRotation(
              turns: _runAttackRotationAnimation ? -0.06 : 0,
              duration: const Duration(milliseconds: 350),
              child: pA.activeCard != null
                  ? _buildImageOnlyCard(pA.activeCard!)
                  : const SizedBox(width: 80, height: 115),
            ),
          ],
        ),
        const SizedBox(height: 16),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 6),
          decoration: BoxDecoration(
            color: Colors.black45,
            borderRadius: BorderRadius.circular(16),
          ),
          child: Text(
            _clashStatusText,
            style: TextStyle(
              color: _clashStatusText.contains("YOU")
                  ? Colors.greenAccent
                  : (_clashStatusText.contains("BOT")
                        ? Colors.redAccent
                        : Colors.white),
              fontSize: 16,
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
        const SizedBox(height: 8),
        const Text(
          'YOUR POOL',
          style: TextStyle(
            color: Colors.greenAccent,
            letterSpacing: 1.2,
            fontSize: 11,
            fontWeight: FontWeight.bold,
          ),
        ),
      ],
    );
  }

  Widget _buildImageOnlyCard(GameCard card) {
    return GestureDetector(
      onTap: () => _openLargeCardMagnifierPreview(card),
      child: Hero(
        tag: 'magnify_${card.id}',
        child: SizedBox(
          width: 80,
          height: 115,
          child: Stack(
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(6),
                child: Image.asset(
                  card.image,
                  fit: BoxFit.contain,
                  errorBuilder: (context, error, stackTrace) {
                    return Container(
                      color: Colors.grey[900],
                      child: Center(
                        child: Padding(
                          padding: const EdgeInsets.all(4.0),
                          child: Text(
                            card.name,
                            textAlign: TextAlign.center,
                            style: const TextStyle(
                              color: Colors.white54,
                              fontSize: 9,
                            ),
                          ),
                        ),
                      ),
                    );
                  },
                ),
              ),
              if (card.name.contains("Special Pleading") || card.id == "LW_F15")
                Positioned(
                  top: 2,
                  right: 2,
                  child: Container(
                    padding: const EdgeInsets.all(3),
                    decoration: const BoxDecoration(
                      color: Colors.orange,
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(
                      Icons.shield_outlined,
                      size: 10,
                      color: Colors.white,
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildActionControlPanel() {
    if (_engine!.currentPhase == GamePhase.vsClashScreen)
      return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2, horizontal: 24),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          TextButton(
            onPressed: _lastPlacedCard != null ? _revertLastMove : null,
            child: Text(
              'Revert Move',
              style: TextStyle(
                color: _lastPlacedCard != null ? Colors.orange : Colors.white24,
                fontSize: 12,
              ),
            ),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.blueAccent,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            ),
            onPressed: _commitAndContinue,
            child: Text(
              _lastPlacedCard != null ? 'Lock Card & Clash' : 'Pass Phase',
              style: const TextStyle(color: Colors.white, fontSize: 12),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPlayerBanner(PlayerState p, String tag, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 4, horizontal: 20),
      color: const Color(0xFF1E1E1E),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            '$tag DECK (HP: ${p.hp} | Left: ${p.deck.length})',
            style: TextStyle(
              color: color,
              fontWeight: FontWeight.bold,
              fontSize: 11,
              letterSpacing: 1.0,
            ),
          ),
          Text(
            'INF Pool: ${p.inf}',
            style: const TextStyle(
              color: Colors.amber,
              fontSize: 11,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }
}
