import '../models/game_state.dart';
import '../models/card_models.dart';

class EffectEngine {
  static void triggerEffects({
    required int triggerId,
    required GameCard card,
    required GameState state,
    required int fromLane,
    required int toLane,
    required bool isAttacker,
  }) {
    if (card.silenced) return;

    final owner = isAttacker ? state.activePlayer : state.reactingPlayer;
    final opponent = isAttacker ? state.reactingPlayer : state.activePlayer;
    final ownLane = isAttacker ? fromLane : toLane;
    final oppLane = isAttacker ? toLane : fromLane;

    for (var effect in card.effects) {
      if (effect.trigger != triggerId) continue;
      if (!_evaluateCondition(effect, card, owner, opponent, ownLane, oppLane)) continue;

      _executeEffect(
        effect: effect,
        card: card,
        owner: owner,
        opponent: opponent,
        ownLane: ownLane,
        oppLane: oppLane,
        state: state,
      );
    }
  }

  // ====== Condition Evaluation ======

  static bool _evaluateCondition(
    CardEffect effect,
    GameCard self,
    PlayerState owner,
    PlayerState opponent,
    int ownLane,
    int oppLane,
  ) {
    if (effect.condition == null) return true;
    final cond = effect.condition!;

    if (cond.containsKey('opponent_crb')) {
      final rule = cond['opponent_crb'] as Map<String, dynamic>;
      final oppCard = opponent.lanes[oppLane].activeCard;
      if (rule.containsKey('less_than')) {
        final threshold = rule['less_than'];
        final compareVal = threshold == 'self_crb' ? self.crb : threshold as int;
        if (oppCard == null || oppCard.crb >= compareVal) return false;
      }
    }

    if (cond.containsKey('owner_inf')) {
      final rule = cond['owner_inf'] as Map<String, dynamic>;
      if (rule.containsKey('min')) {
        if (owner.inf < (rule['min'] as int)) return false;
      }
    }

    if (cond.containsKey('opponent_inf')) {
      final rule = cond['opponent_inf'] as Map<String, dynamic>;
      if (rule.containsKey('less_than_or_equal')) {
        final threshold = rule['less_than_or_equal'];
        final compareVal = threshold == 'owner_inf' ? owner.inf : threshold as int;
        if (opponent.inf > compareVal) return false;
      }
    }

    if (cond.containsKey('once')) {
      if (self.survivesOnceUsed) return false;
    }

    return true;
  }

  // ====== Effect Execution ======

  static void _executeEffect({
    required CardEffect effect,
    required GameCard card,
    required PlayerState owner,
    required PlayerState opponent,
    required int ownLane,
    required int oppLane,
    required GameState state,
  }) {
    final ownCard = owner.lanes[ownLane].activeCard;
    final oppCard = opponent.lanes[oppLane].activeCard;
    final params = effect.params;
    final target = effect.target;

    switch (effect.effectId) {

      // 101: Discard
      case 101:
        final amount = params['amount'] as int? ?? 1;
        final targetPlayer = target == 1 ? owner : opponent;
        // TODO: player choice - currently discards first card in hand
        for (int i = 0; i < amount; i++) {
          if (targetPlayer.hand.isNotEmpty) {
            targetPlayer.discardFromHand(targetPlayer.hand.first);
            state.log('${_name(targetPlayer)} discarded a card.');
          }
        }
        break;

      // 102: Equalize
      case 102:
        if (ownCard != null && oppCard != null) {
          oppCard.crb = ownCard.crb;
          state.log('${oppCard.name} CRB equalized to ${ownCard.crb}.');
        }
        break;

      // 103: CRB Change
      case 103:
        final amount = params['amount'] as int? ?? 0;
        final accumulate = params['accumulate'] == true;
        if (target == 3 && ownCard != null) {
          ownCard.crb += amount;
          if (accumulate) {
            ownCard.accumulatedCrb += amount;
          }
          state.log('${ownCard.name} CRB changed by $amount.');
        } else if (target == 4 && oppCard != null) {
          oppCard.crb += amount;
          state.log('${oppCard.name} CRB changed by $amount.');
        } else if (target == 5) {
          // OwnerNextCard: store pending buff on player state
          owner.pendingNextCardCrbBuff += amount;
          state.log('Next card played by ${_name(owner)} will get +$amount CRB.');
        }
        break;

      // 104: Swap CRB
      case 104:
        if (ownCard != null && oppCard != null) {
          final temp = ownCard.crb;
          ownCard.crb = oppCard.crb;
          oppCard.crb = temp;
          state.log('${ownCard.name} and ${oppCard.name} swapped CRB.');
        }
        break;

      // 105: MultiHit
      case 105:
        // TODO: MultiHit requires re-triggering combat resolution
        // Stubbed for now
        state.log('${ownCard?.name} MultiHit triggered (stubbed).');
        break;

      // 106: Negate
      case 106:
        if (oppCard != null) {
          oppCard.silenced = true;
          state.log('${oppCard.name} ability negated.');
        }
        break;

      // 107: Destroy
      case 107:
        if (oppCard != null) {
          EffectEngine.triggerEffects(
            triggerId: 7,
            card: oppCard,
            state: state,
            fromLane: ownLane,
            toLane: oppLane,
            isAttacker: false,
          );
          opponent.resolveCardToDiscard(oppLane);
          state.log('${oppCard.name} destroyed by effect.');
        }
        break;

      // 108: Force Reaction Constraint
      case 108:
        // TODO: player choice - currently no enforcement, stubbed
        final type = params['type'] as String? ?? '';
        state.log('Force reaction constraint ($type) triggered (stubbed).');
        break;

      // 201: INF Change
      case 201:
        final rawAmount = params['amount'];
        int amount;
        if (rawAmount == 'accumulated_crb') {
          final negate = params['negate'] == true;
          amount = negate ? -(ownCard?.accumulatedCrb ?? 0) : (ownCard?.accumulatedCrb ?? 0);
        } else {
          amount = rawAmount as int? ?? 0;
        }
        if (target == 1) {
          owner.gainInf(amount);
          state.log('${_name(owner)} INF changed by $amount.');
        } else if (target == 2) {
          if (amount < 0) {
            opponent.loseInf(amount.abs());
            state.log('${_name(opponent)} lost ${amount.abs()} INF.');
          } else {
            opponent.gainInf(amount);
            state.log('${_name(opponent)} gained $amount INF.');
          }
        }
        break;

      // 202: Draw
      case 202:
        final amount = params['amount'] as int? ?? 1;
        owner.drawCards(amount);
        state.log('${_name(owner)} drew $amount card(s).');
        break;

      // 203: Cost Change
      case 203:
        final amount = params['amount'] as int? ?? 0;
        // Stored as pending on the player, applied when next card is played
        if (target == 5) {
          owner.pendingNextCardCostChange += amount;
          state.log('Next card played by ${_name(owner)} costs $amount more/less.');
        } else if (target == 6) {
          opponent.pendingNextCardCostChange += amount;
          state.log('Next card played by ${_name(opponent)} costs $amount more/less.');
        }
        break;

      // 204: Hand Swap
      case 204:
        // TODO: player choice - currently swaps with first card in hand
        if (ownCard != null && owner.hand.isNotEmpty) {
          final swapCard = owner.hand.first;
          owner.lanes[ownLane].activeCard = swapCard;
          owner.hand.remove(swapCard);
          owner.hand.add(ownCard);
          state.log('${ownCard.name} swapped with ${swapCard.name} from hand.');
        }
        break;

      // 205: Loaded Choice
      case 205:
        // TODO: player choice - currently always picks option A (index 0)
        final choices = params['choice'] as List<dynamic>?;
        if (choices != null && choices.isNotEmpty) {
          final choiceA = Map<String, dynamic>.from(choices[0]);
          final choiceEffect = CardEffect(
            trigger: effect.trigger,
            target: effect.target,
            effectId: choiceA['effect_id'] as int,
            params: {'amount': choiceA['amount']},
          );
          _executeEffect(
            effect: choiceEffect,
            card: card,
            owner: owner,
            opponent: opponent,
            ownLane: ownLane,
            oppLane: oppLane,
            state: state,
          );
        }
        break;

      // 301: Persist
      case 301:
        if (ownCard != null) {
          ownCard.persists = true;
          state.log('${ownCard.name} will persist after combat.');
        }
        break;

      // 302: Return to Hand
      case 302:
        if (ownCard != null) {
          owner.hand.add(ownCard);
          owner.lanes[ownLane].activeCard = owner.lanes[ownLane].queuedCard;
          owner.lanes[ownLane].queuedCard = null;
          state.log('${ownCard.name} returned to hand.');
        }
        break;

      // 303: Survive At
      case 303:
        if (ownCard != null && !ownCard.survivesOnceUsed) {
          final targetCrb = params['crb'] as int? ?? 1;
          ownCard.crb = targetCrb;
          ownCard.persists = true;
          ownCard.survivesOnceUsed = true;
          state.log('${ownCard.name} survives at CRB $targetCrb.');
        }
        break;

      // 304: Silence
      case 304:
        if (target == 2 || target == 4) {
          // Silence opponent or opponent card
          if (oppCard != null) {
            oppCard.silenced = true;
            state.log('${oppCard.name} silenced.');
          }
        } else if (target == 6) {
          // Silence opponent next card
          opponent.nextCardSilenced = true;
          state.log('${_name(opponent)}\'s next card will be silenced.');
        }
        break;

      // 305: Direct Damage
      case 305:
        final amount = params['amount'] as int? ?? 1;
        if (target == 7) {
          opponent.hp -= amount;
          opponent.gainInf(5);
          state.log('${_name(opponent)} takes $amount direct damage and gains 5 INF.');
        }
        break;

      default:
        state.log('Effect ${effect.effectId} not implemented.');
    }
  }

  static String _name(PlayerState player) =>
      player.player == Player.playerA ? 'Player A' : 'Player B';
}