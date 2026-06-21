import 'package:flutter/material.dart';
import '../models/game_state.dart';
import '../models/card_models.dart';
import '../engine/game_engine.dart';
import '../engine/bot_controller.dart';
import '../services/card_loader.dart';
import '../services/deck_manager.dart';
import '../models/combat_log.dart';
import 'combat_results_screen.dart';

class GameScreen extends StatefulWidget {
  const GameScreen({Key? key}) : super(key: key);

  @override
  _GameScreenState createState() => _GameScreenState();
}

class _GameScreenState extends State<GameScreen> {
  GameEngine? _engine;
  bool _loading = true;
  int? _selectedAttackFromLane;

  @override
  void initState() {
    super.initState();
    _initializeGame();
  }

  Future<void> _initializeGame() async {
    List<GameCard> library = await CardLoader.loadCardsLibrary();

    if (library.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Error: cards_library.json loaded empty!'),
        ),
      );
      return;
    }

    List<String> recipeA = await DeckManager.loadRecipeFromJSON('3');
    List<String> recipeB = await DeckManager.loadRecipeFromJSON('2');

    List<GameCard> deckA = DeckManager.buildDeckFromRecipe(recipeA, library);
    List<GameCard> deckB = DeckManager.buildDeckFromRecipe(recipeB, library);

    DeckManager.validateDeckRules(deckA);
    DeckManager.validateDeckRules(deckB);

    deckA.shuffle();
    deckB.shuffle();

    final playerA = PlayerState(
      player: Player.playerA,
      deck: deckA,
      hp: 6,
      inf: 10,
    );
    final playerB = PlayerState(
      player: Player.playerB,
      deck: deckB,
      hp: 6,
      inf: 10,
      isBot: true,
    );

    playerA.drawCards(5);
    playerB.drawCards(5);

    setState(() {
      final state = GameState(playerA: playerA, playerB: playerB);
      _engine = GameEngine(state);
      _loading = false;
    });
  }

  void _afterUpdate() {
    final state = _engine!.state;
    if (state.currentTurn == Player.playerB && !state.isGameOver) {
      _runBotTurn();
    }
  }

  Future<void> _runBotTurn() async {
    if (!mounted) return;

    final state = _engine!.state;

    if (state.isGameOver) {
      setState(() {});
      return;
    }

    if (state.phase == GamePhase.reactionPhase && !state.reactingPlayer.isBot) {
      setState(() {});
      return;
    }

    if (state.currentTurn == Player.playerB) {
      await BotController.runAI(_engine!);
      setState(() {});

      if (mounted && state.currentTurn == Player.playerB) {
        await Future.delayed(const Duration(milliseconds: 400));
        await _runBotTurn();
      }
    } else {
      setState(() {});
    }
  }

  void _triggerUpdate() {
    setState(() {});
    _afterUpdate();
  }

  void _showCombatResultsIfNeeded() {
    final log = _engine?.state.lastCombatLog;
    if (log == null) return;

    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => CombatResultsScreen(
          log: log,
          viewingAs: Player.playerA,
          onContinue: () {
            Navigator.pop(context);
          },
        ),
      ),
    ).then((_) {
      setState(() {
        _engine!.state.lastCombatLog = null;
      });
    });
  }

  @override
  Widget build(BuildContext context) {
    if (_loading || _engine == null) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    final state = _engine!.state;

    if (state.isGameOver) {
      return _buildGameOverScreen(state);
    }

    return Scaffold(
      backgroundColor: Colors.grey[900],
      appBar: AppBar(
        title: Text('Debate Arena - ${state.phase.name.toUpperCase()}'),
        backgroundColor: Colors.black87,
      ),
      // SAFETY PADDING AT THE BASE OF SCENE: 
      body: SafeArea(
        bottom: true,
        child: Column(
          children: [
            _buildOpponentPanel(state),
            const Spacer(),
            // Constrain lane system row to compressed space context
            SizedBox(
              height: 240, // Keeps the vertical profile significantly shorter
              child: _buildLanes(state),
            ),
            const Spacer(),
            if (state.lastActionLog != null) _buildActionLog(state),
            _buildPlayerPanel(state),
            _buildPlayerHand(state),
            // Clean empty layout anchor buffer matching navigation zones
            SizedBox(height: MediaQuery.of(context).padding.bottom > 0 ? 4 : 12),
          ],
        ),
      ),
    );
  }

  // ====== Game Over ======

  Widget _buildGameOverScreen(GameState state) {
    final winner = state.winner;
    final message = winner == null
        ? 'Draw!'
        : winner == Player.playerA
        ? 'You Win!'
        : 'Bot Wins!';

    return Scaffold(
      backgroundColor: Colors.grey[900],
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              message,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 32,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 24),
            ElevatedButton(
              onPressed: () {
                setState(() {
                  _loading = true;
                  _engine = null;
                });
                _initializeGame();
              },
              child: const Text('Play Again'),
            ),
          ],
        ),
      ),
    );
  }

  // ====== Panels ======

  Widget _buildOpponentPanel(GameState state) {
    return Container(
      padding: const EdgeInsets.all(8),
      color: Colors.black54,
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: [
          Text(
            'BOT HP: ${state.playerB.hp}',
            style: const TextStyle(color: Colors.redAccent, fontSize: 16),
          ),
          Text(
            'BOT INF: ${state.playerB.inf}',
            style: const TextStyle(color: Colors.amber, fontSize: 16),
          ),
          Text(
            'Hand: ${state.playerB.hand.length} | Deck: ${state.playerB.deck.length}',
            style: const TextStyle(color: Colors.white54, fontSize: 14),
          ),
        ],
      ),
    );
  }

  Widget _buildPlayerPanel(GameState state) {
    final canFinalize = state.currentTurn == Player.playerA || 
        (state.phase == GamePhase.reactionPhase && state.reactingPlayer.player == Player.playerA);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      color: Colors.black38,
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'YOUR HP: ${state.playerA.hp}',
                style: const TextStyle(
                  color: Colors.redAccent,
                  fontSize: 15,
                  fontWeight: FontWeight.bold,
                ),
              ),
              Text(
                'INF: ${state.playerA.inf} | Deck: ${state.playerA.deck.length}',
                style: const TextStyle(color: Colors.amber, fontSize: 14),
              ),
            ],
          ),
          Row(
            children: [
              if (state.phase == GamePhase.attackPhase && _selectedAttackFromLane != null) ...[
                ElevatedButton(
                  style: ElevatedButton.styleFrom(backgroundColor: Colors.grey[700]),
                  onPressed: () {
                    setState(() {
                      _selectedAttackFromLane = null;
                    });
                  },
                  child: const Text(
                    'CANCEL SELECTION',
                    style: TextStyle(color: Colors.white),
                  ),
                ),
                const SizedBox(width: 8),
              ],
              ElevatedButton(
                style: ElevatedButton.styleFrom(backgroundColor: Colors.blueAccent),
                onPressed: canFinalize
                    ? () {
                        if (state.phase == GamePhase.buildPhase) {
                          _engine!.endBuildPhase();
                        } else if (state.phase == GamePhase.attackPhase) {
                          _engine!.finalizeAttacks();
                        } else if (state.phase == GamePhase.reactionPhase) {
                          _engine!.completeReactionPhase();
                          if (_engine!.state.lastCombatLog != null) {
                            WidgetsBinding.instance.addPostFrameCallback((_) {
                              if (mounted) _showCombatResultsIfNeeded();
                            });
                          }
                        }
                        _selectedAttackFromLane = null;
                        _triggerUpdate();
                      }
                    : null,
                child: const Text(
                  'FINALIZE PHASE',
                  style: TextStyle(color: Colors.white),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildActionLog(GameState state) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4, horizontal: 8),
      child: Text(
        state.lastActionLog!,
        textAlign: TextAlign.center,
        style: const TextStyle(
          color: Colors.lightGreenAccent,
          fontStyle: FontStyle.italic,
          fontSize: 13,
        ),
      ),
    );
  }

  // ====== Lanes with Drag Targets ======

  Widget _buildLanes(GameState state) {
    return Row(
      children: List.generate(3, (index) {
        final laneA = state.playerA.lanes[index];
        final laneB = state.playerB.lanes[index];
        final isTargeted = state.pendingAttacks.any((a) => a.toLane == index);

        // Turn lane slots into responsive drag targets
        return Expanded(
          child: DragTarget<GameCard>(
            onWillAcceptWithDetails: (details) {
              final card = details.data;
              final phase = state.phase;
              final isPlayerTurn = state.currentTurn == Player.playerA;
              final isReactionPhase = phase == GamePhase.reactionPhase && state.reactingPlayer.player == Player.playerA;

              // Allow card deployment drop only during Build/Reaction setups into an empty slot
              if (!(phase == GamePhase.buildPhase && isPlayerTurn) && !isReactionPhase) {
                return false;
              }
              return laneA.isEmpty && card.inf <= state.playerA.inf;
            },
            onAcceptWithDetails: (details) {
              final card = details.data;
              final played = _engine!.playCardInBuild(card, index);
              if (played) {
                _triggerUpdate();
              }
            },
            builder: (context, candidateData, rejectedData) {
              final isHovering = candidateData.isNotEmpty;

              return Container(
                margin: const EdgeInsets.all(4),
                decoration: BoxDecoration(
                  color: isHovering 
                      ? Colors.greenAccent.withOpacity(0.15)
                      : (isTargeted ? Colors.red.withOpacity(0.15) : Colors.white10),
                  border: Border.all(
                    color: isHovering
                        ? Colors.greenAccent
                        : (isTargeted ? Colors.redAccent : Colors.white24),
                    width: isHovering ? 2.0 : 1.0,
                  ),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: [
                    Text(
                      'Lane ${index + 1}',
                      style: const TextStyle(
                        color: Colors.grey,
                        fontWeight: FontWeight.bold,
                        fontSize: 12,
                      ),
                    ),
                    _buildLaneCardSlot(laneB.activeCard, isOpponent: true),
                    const Divider(
                      color: Colors.white24,
                      thickness: 1,
                      indent: 12,
                      endIndent: 12,
                    ),
                    _buildLaneActionButton(index),
                    _buildLaneCardSlot(laneA.activeCard, isOpponent: false),
                  ],
                ),
              );
            },
          ),
        );
      }),
    );
  }

  Widget _buildLaneCardSlot(GameCard? card, {required bool isOpponent}) {
    if (card == null) {
      return Container(
        height: 55, // Shortened height profile
        width: 70,
        decoration: BoxDecoration(
          border: Border.all(color: Colors.white12),
          borderRadius: BorderRadius.circular(6),
        ),
        child: const Center(
          child: Text(
            '[ Empty ]',
            style: TextStyle(color: Colors.white24, fontSize: 10),
          ),
        ),
      );
    }

    return Container(
      height: 55, // Shortened height profile
      width: 70,
      decoration: BoxDecoration(
        color: isOpponent ? Colors.red[900] : Colors.blue[900],
        borderRadius: BorderRadius.circular(6),
        border: Border.all(
          color: isOpponent ? Colors.redAccent : Colors.blueAccent,
        ),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 2),
            child: Text(
              card.name,
              textAlign: TextAlign.center,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 9,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
          Text(
            'CRB: ${card.crb}',
            style: const TextStyle(
              color: Colors.greenAccent,
              fontSize: 10,
              fontWeight: FontWeight.bold,
            ),
          ),
          if (card.silenced)
            const Text(
              'SILENCED',
              style: TextStyle(color: Colors.orangeAccent, fontSize: 8),
            ),
        ],
      ),
    );
  }

  // ====== Lane Action Button (Strictly handles Battle Directives now) ======

  Widget _buildLaneActionButton(int laneIndex) {
    final state = _engine!.state;

    final canPlayerAct = state.currentTurn == Player.playerA ||
        (state.phase == GamePhase.reactionPhase && state.reactingPlayer.player == Player.playerA);

    if (!canPlayerAct) {
      return const SizedBox(height: 28);
    }

    // Hide contextual lane buttons entirely during card deployment loops (handled via drops)
    if (state.phase == GamePhase.buildPhase || state.phase == GamePhase.reactionPhase) {
      return const SizedBox(height: 28);
    }

    // ====== ATTACK PHASE CONTROLS ======
    if (state.phase == GamePhase.attackPhase && !state.isPlayerAPeacefulTurn) {
      final laneA = state.playerA.lanes[laneIndex];
      final existingAttack = state.pendingAttacks.any((a) => a.fromLane == laneIndex);

      if (_selectedAttackFromLane == null) {
        if (laneA.isEmpty) return const SizedBox(height: 28);

        return SizedBox(
          height: 28,
          child: ElevatedButton(
            style: ElevatedButton.styleFrom(
              visualDensity: VisualDensity.compact,
              padding: const EdgeInsets.symmetric(horizontal: 6),
              backgroundColor: existingAttack ? Colors.orange[700] : Colors.red[700],
            ),
            onPressed: () {
              setState(() {
                _selectedAttackFromLane = laneIndex;
              });
            },
            child: Text(
              existingAttack ? 'RETARGET' : 'ATTACK',
              style: const TextStyle(fontSize: 10, color: Colors.white),
            ),
          ),
        );
      }

      return SizedBox(
        height: 28,
        child: ElevatedButton(
          style: ElevatedButton.styleFrom(
            visualDensity: VisualDensity.compact,
            padding: const EdgeInsets.symmetric(horizontal: 6),
            backgroundColor: (_selectedAttackFromLane == laneIndex) ? Colors.blue[700] : Colors.amber[700],
          ),
          onPressed: () {
            _engine!.declareAttack(_selectedAttackFromLane!, laneIndex);
            setState(() {
              _selectedAttackFromLane = null;
            });
            _triggerUpdate();
          },
          child: Text(
            (_selectedAttackFromLane == laneIndex) ? 'STRAIGHT' : 'TARGET',
            style: TextStyle(
              fontSize: 10, 
              color: (_selectedAttackFromLane == laneIndex) ? Colors.white : Colors.black,
            ),
          ),
        ),
      );
    }

    return const SizedBox(height: 28);
  }

  // ====== Player Hand supporting Draggable gestures ======

  Widget _buildPlayerHand(GameState state) {
    final canInteract = state.currentTurn == Player.playerA ||
        (state.phase == GamePhase.reactionPhase && state.reactingPlayer.player == Player.playerA);

    return Container(
      height: 105,
      padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 4),
      color: Colors.black54,
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        itemCount: state.playerA.hand.length,
        itemBuilder: (context, idx) {
          final card = state.playerA.hand[idx];
          
          Widget cardView = Container(
            width: 90,
            margin: const EdgeInsets.symmetric(horizontal: 4),
            decoration: BoxDecoration(
              color: Colors.blueGrey[800],
              borderRadius: BorderRadius.circular(6),
              border: Border.all(color: Colors.white30),
            ),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  card.name,
                  textAlign: TextAlign.center,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 10,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  'CRB: ${card.crb}',
                  style: const TextStyle(color: Colors.cyanAccent, fontSize: 10),
                ),
                Text(
                  'Cost: ${card.inf}',
                  style: const TextStyle(color: Colors.amber, fontSize: 10),
                ),
              ],
            ),
          );

          if (!canInteract) return cardView;

          // Wrap element structure inside explicit drag controller systems
          return Draggable<GameCard>(
            data: card,
            feedback: Material(
              color: Colors.transparent,
              child: Opacity(
                opacity: 0.75,
                child: Transform.scale(
                  scale: 1.05,
                  child: cardView,
                ),
              ),
            ),
            childWhenDragging: Opacity(
              opacity: 0.3,
              child: cardView,
            ),
            child: cardView,
          );
        },
      ),
    );
  }
}