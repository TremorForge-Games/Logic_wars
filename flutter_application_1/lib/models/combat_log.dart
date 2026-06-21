import 'card_models.dart';
import 'game_state.dart';

// ====== Single lane combat result ======

enum CombatResult { attackerWins, defenderWins, tie, emptyLaneHit }

class LaneCombatLog {
  // CHANGED: Support multiple attacking lanes and cards
  final List<int> fromLanes;          
  final List<GameCard> attackingCards; 
  final int toLane;
  final GameCard? defendingCard;
  final int attackerCrb;
  final int defenderCrb;
  final CombatResult result;
  final List<String> effectsTriggered;
  final int damageDealt;

  LaneCombatLog({
    required this.fromLanes,
    required this.attackingCards,
    required this.toLane,
    this.defendingCard,
    required this.attackerCrb,
    required this.defenderCrb,
    required this.result,
    required this.effectsTriggered,
    this.damageDealt = 0,
  });

  // Helper getters to keep legacy UI code from breaking if it calls single items
  int get fromLane => fromLanes.isNotEmpty ? fromLanes.first : 0;
  GameCard get attackingCard => attackingCards.isNotEmpty ? attackingCards.first : GameCard.empty(); // fallback object

  String get resultText {
    final attackersNames = attackingCards.map((c) => c.name).join(' & ');
    
    switch (result) {
      case CombatResult.attackerWins:
        return '$attackersNames win! ${defendingCard?.name ?? ''} destroyed.';
      case CombatResult.defenderWins:
        return '${defendingCard?.name ?? ''} wins! $attackersNames destroyed.';
      case CombatResult.tie:
        return 'Tie! All cards destroyed.';
      case CombatResult.emptyLaneHit:
        return '$attackersNames hit empty lane for $damageDealt damage!';
    }
  }
}

// ====== Full round combat log ======

class CombatLog {
  final List<LaneCombatLog> lanes;
  final Player attacker;
  final List<String> pendingEffectLog;

  CombatLog({
    required this.lanes,
    required this.attacker,
    List<String>? pendingEffectLog,
  }) : pendingEffectLog = pendingEffectLog ?? [];

  int get totalDamageDealt =>
      lanes.fold(0, (sum, l) => sum + l.damageDealt);

  List<String> get destroyedCards {
    final List<String> destroyed = [];
    for (var lane in lanes) {
      if (lane.result == CombatResult.attackerWins) {
        // Defender died
        if (lane.defendingCard != null) destroyed.add(lane.defendingCard!.name);
        // Under your rules, attacking cards die even on a win if it was a mutual group battle
        if (lane.attackingCards.length > 1) {
          destroyed.addAll(lane.attackingCards.map((c) => c.name));
        }
      } else if (lane.result == CombatResult.defenderWins) {
        // Attackers died
        destroyed.addAll(lane.attackingCards.map((c) => c.name));
      } else if (lane.result == CombatResult.tie) {
        // Everything died
        destroyed.addAll(lane.attackingCards.map((c) => c.name));
        if (lane.defendingCard != null) destroyed.add(lane.defendingCard!.name);
      }
    }
    return destroyed;
  }
}