import '../models/game_state.dart';
import '../models/card_models.dart';
import 'effect_engine.dart';
import '../models/combat_log.dart';
import 'bot_controller.dart'; 

class GameEngine {
  GameState state;

  GameEngine(this.state);

  // ====== Build Phase & Reaction Phase Card Deployment ======

  bool playCardInBuild(GameCard card, int laneIndex) {
    // 1. Guard check: Only allow playing cards in Build or Reaction phases
    if (state.phase != GamePhase.buildPhase && state.phase != GamePhase.reactionPhase) {
      return false;
    }

    // 2. Explicitly determine who is playing the card using concrete states
    final Player actingPlayerEnum = (state.phase == GamePhase.reactionPhase)
        ? _reactingPlayer
        : state.currentTurn;

    final actingPlayerState = (actingPlayerEnum == Player.playerA) 
        ? state.playerA 
        : state.playerB;

    // 3. Forward the play action to that player's state
    final success = actingPlayerState.playCard(card, laneIndex);
    if (success) {
      state.log(
          '${_playerName(actingPlayerEnum)} played ${card.name} in Lane ${laneIndex + 1} during ${state.phase.name.toUpperCase()}.');
    }
    return success;
  }

  void endBuildPhase() {
    if (state.phase != GamePhase.buildPhase) return;
    
    // Round 1 Player A is peaceful - skip attack phase
    if (state.isPlayerAPeacefulTurn) {
      state.log('Round 1: Player A skips attack phase.');
      state.phase = GamePhase.endPhase;
      _executeEndPhase();
    } else {
      state.phase = GamePhase.attackPhase;
      state.log('Build phase complete. Entering attack phase.');
    }
  }

  // ====== Attack Phase ======

  void declareAttack(int fromLane, int toLane) {
    if (state.phase != GamePhase.attackPhase) return;

    // Ensure the player attacking is the actual turn owner
    final attackerState = (state.currentTurn == Player.playerA) ? state.playerA : state.playerB;
    final lane = attackerState.lanes[fromLane];
    if (lane.isEmpty) return;

    // Replace existing declaration for this lane if any
    state.pendingAttacks.removeWhere((a) => a.fromLane == fromLane);
    state.pendingAttacks.add(PendingAttack(fromLane: fromLane, toLane: toLane));
    state.log('Lane ${fromLane + 1} targeting opponent Lane ${toLane + 1}.');
  }

  void cancelAttack(int fromLane) {
    state.pendingAttacks.removeWhere((a) => a.fromLane == fromLane);
  }

  void finalizeAttacks() {
    if (state.phase != GamePhase.attackPhase) return;

    // Count how many attackers are targeting each lane
    final Map<int, int> targetCounts = {};
    for (var attack in state.pendingAttacks) {
      targetCounts[attack.toLane] = (targetCounts[attack.toLane] ?? 0) + 1;
    }

    // Flag multi-lane attacks and apply INF penalty to defender once per stacked lane
    final Set<int> penalizedLanes = {};
    final defenderState = (_reactingPlayer == Player.playerA) ? state.playerA : state.playerB;

    for (int i = 0; i < state.pendingAttacks.length; i++) {
      final attack = state.pendingAttacks[i];
      if ((targetCounts[attack.toLane] ?? 0) > 1) {
        state.pendingAttacks[i] = PendingAttack(
          fromLane: attack.fromLane,
          toLane: attack.toLane,
          multiLane: true,
        );
        if (!penalizedLanes.contains(attack.toLane)) {
          defenderState.gainInf(1);
          penalizedLanes.add(attack.toLane);
          state.log(
              'Multi-lane attack on Lane ${attack.toLane + 1}. Defending player gains 1 INF.');
        }
      }
    }

    // 1. Progress the state phase to reaction phase
    state.phase = GamePhase.reactionPhase;
    state.log('Attacks locked in. ${_playerName(_reactingPlayer)} must react.');

    // 2. TRIGGER BOT REACTION SAFELY IN THE ASYNC PIPELINE:
    if (_reactingPlayer == Player.playerB) {
      BotController.runAI(this).then((_) {
        // Triggers UI re-renders if your framework uses a notification pattern here
      });
    }
  }

  void passAttackPhase() {
    if (state.phase != GamePhase.attackPhase) return;
    state.pendingAttacks.clear();
    state.phase = GamePhase.reactionPhase;
    state.log('${_playerName(state.currentTurn)} passed attack phase.');
  }

  // ====== Reaction Phase ======

  bool playReactionCard(GameCard card, int laneIndex) {
    return playCardInBuild(card, laneIndex);
  }

  void passReactionOnLane(int laneIndex) {
    if (state.phase != GamePhase.reactionPhase) return;

    final defenderState = (_reactingPlayer == Player.playerA) ? state.playerA : state.playerB;
    final lane = defenderState.lanes[laneIndex];
    if (!lane.isEmpty) return; 

    final isUnderAttack = state.pendingAttacks.any((a) => a.toLane == laneIndex);
    if (!isUnderAttack) return;

    defenderState.hp -= 1;
    defenderState.gainInf(5);
    state.log(
        '${_playerName(_reactingPlayer)} takes 1 damage on empty Lane ${laneIndex + 1} and gains 5 INF.');

    state.pendingAttacks.removeWhere((a) => a.toLane == laneIndex);
  }

  void completeReactionPhase() {
    if (state.phase != GamePhase.reactionPhase) return;
    state.phase = GamePhase.resolvePhase;
    _executeCombatResolution();
  }

  // ====== Resolve Phase ======

  void _executeCombatResolution() {
    final combatLog = CombatLog(
      lanes: [],
      attacker: state.currentTurn,
    );

    final attackerState = (state.currentTurn == Player.playerA) ? state.playerA : state.playerB;
    final defenderState = (_reactingPlayer == Player.playerA) ? state.playerA : state.playerB;

    // 1. Group all incoming attacks by the DEFENDING lane index
    final Map<int, List<PendingAttack>> attacksByTargetLane = {0: [], 1: [], 2: []};
    for (var attack in state.pendingAttacks) {
      attacksByTargetLane[attack.toLane]?.add(attack);
    }

    // 2. Resolve combat lane by lane
    for (int targetLane = 0; targetLane < 3; targetLane++) {
      final incomingAttacks = attacksByTargetLane[targetLane]!;
      if (incomingAttacks.isEmpty) continue; 

      final defenderCard = defenderState.lanes[targetLane].activeCard;

      if (defenderCard != null) {
        int totalAttackerCrb = 0;
        List<GameCard> validAttackers = [];
        List<int> attackingLanesToDiscard = [];
        
        for (var attack in incomingAttacks) {
          final attackerCard = attackerState.lanes[attack.fromLane].activeCard;
          if (attackerCard != null) {
            totalAttackerCrb += attackerCard.crb;
            validAttackers.add(attackerCard);
            attackingLanesToDiscard.add(attack.fromLane);
          }
        }

        if (validAttackers.isEmpty) continue;

        if (totalAttackerCrb == defenderCard.crb) {
          // TIE: Both sides wipe each other out
          combatLog.lanes.add(LaneCombatLog(
            fromLanes: List.from(attackingLanesToDiscard),
            attackingCards: List.from(validAttackers),
            toLane: targetLane,
            defendingCard: defenderCard,
            attackerCrb: totalAttackerCrb,
            defenderCrb: defenderCard.crb,
            result: CombatResult.tie,
            effectsTriggered: const [],
          ));

          for (int laneIdx in attackingLanesToDiscard) {
            attackerState.resolveCardToDiscard(laneIdx);
          }
          defenderState.resolveCardToDiscard(targetLane);

        } else if (totalAttackerCrb > defenderCard.crb) {
          // ATTACKERS WIN: Defender is crushed. 
          combatLog.lanes.add(LaneCombatLog(
            fromLanes: List.from(attackingLanesToDiscard),
            attackingCards: List.from(validAttackers),
            toLane: targetLane,
            defendingCard: defenderCard,
            attackerCrb: totalAttackerCrb,
            defenderCrb: defenderCard.crb,
            result: CombatResult.attackerWins,
            effectsTriggered: const [],
          ));

          // Defender card is destroyed
          defenderState.resolveCardToDiscard(targetLane);

          // Note: Attacking cards remain on the field because their discard step is skipped.

        } else {
          // DEFENDER WINS: Attacking cards fail to break through and are destroyed
          combatLog.lanes.add(LaneCombatLog(
            fromLanes: List.from(attackingLanesToDiscard),
            attackingCards: List.from(validAttackers),
            toLane: targetLane,
            defendingCard: defenderCard,
            attackerCrb: totalAttackerCrb,
            defenderCrb: defenderCard.crb,
            result: CombatResult.defenderWins,
            effectsTriggered: const [],
          ));

          // Attacking cards are destroyed because they lost the engagement
          for (int laneIdx in attackingLanesToDiscard) {
            attackerState.resolveCardToDiscard(laneIdx);
          }
          // Defender card safely survives!
        }

      } else {
        // EMPTY LANE HIT: Exactly 1 direct structural face damage total
        List<int> attackingLanes = [];
        List<GameCard> validAttackers = [];

        for (var attack in incomingAttacks) {
          final attackerCard = attackerState.lanes[attack.fromLane].activeCard;
          if (attackerCard != null) {
            // FIXED: Removed the auto-discard call so winning face-attackers survive!
            attackingLanes.add(attack.fromLane);
            validAttackers.add(attackerCard);
          }
        }

        // Apply damage and resource gains EXACTLY ONCE per contested lane
        if (validAttackers.isNotEmpty) {
          defenderState.hp -= 1; 
          defenderState.gainInf(5); 

          combatLog.lanes.add(LaneCombatLog(
            fromLanes: attackingLanes,
            attackingCards: validAttackers,
            toLane: targetLane,
            defendingCard: null,
            attackerCrb: 0,
            defenderCrb: 0,
            result: CombatResult.emptyLaneHit,
            effectsTriggered: const [],
            damageDealt: 1, 
          ));
        }
      }
    }

    state.lastCombatLog = combatLog; 
    state.pendingAttacks.clear();
    state.phase = GamePhase.endPhase;
    _executeEndPhase();
  }

  // ====== End Phase ======

  void _executeEndPhase() {
    state.log('End phase. Preparing next turn.');

    state.playerA.gainInf(2);
    state.playerB.gainInf(2);

    state.playerA.drawCards(1);
    state.playerB.drawCards(1);

    if (state.isGameOver) {
      final winner = state.winner;
      state.log(winner != null
          ? 'Game over! ${_playerName(winner)} wins!'
          : 'Game over! It is a draw!');
      return;
    }

    state.switchTurn();
    state.log('${_playerName(state.currentTurn)}\'s turn begins.');
  }

  // ====== Helpers ======

  Player get _reactingPlayer =>
      state.currentTurn == Player.playerA ? Player.playerB : Player.playerA;

  String _playerName(Player player) =>
      player == Player.playerA ? 'Player A' : 'Player B';
}