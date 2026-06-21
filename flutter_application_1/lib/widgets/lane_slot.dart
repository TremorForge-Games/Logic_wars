import 'package:flutter/material.dart';
import '../models/card_models.dart';
import 'card_view.dart';

class LaneSlot extends StatelessWidget {
  final int laneIndex;
  final GameCard? playerCard;
  final GameCard? botCard;
  final String? combatOutcome;
  final bool Function(GameCard) isValidDrop;
  final Function(GameCard) onCardDropped;

  const LaneSlot({
    Key? key,
    required this.laneIndex,
    required this.playerCard,
    required this.botCard,
    required this.combatOutcome,
    required this.isValidDrop,
    required this.onCardDropped,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return DragTarget<GameCard>(
      onWillAcceptWithDetails: (details) => isValidDrop(details.data),
      onAcceptWithDetails: (details) => onCardDropped(details.data),
      builder: (context, candidateData, _) {
        return Container(
          margin: const EdgeInsets.all(4),
          decoration: BoxDecoration(
            color: candidateData.isNotEmpty ? Colors.white12 : Colors.black,
            border: Border.all(color: Colors.white24),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              Text('Lane ${laneIndex + 1}', style: const TextStyle(color: Colors.white38, fontSize: 12)),
              botCard != null ? CardView(card: botCard!, isOpponent: true, width: 75, height: 60) : _emptyBox(),
              _buildCenterLabel(),
              playerCard != null ? CardView(card: playerCard!, isOpponent: false, width: 75, height: 60) : _emptyBox(),
            ],
          ),
        );
      },
    );
  }

  Widget _emptyBox() {
    return Container(
      height: 60,
      width: 75,
      decoration: BoxDecoration(border: Border.all(color: Colors.white12), borderRadius: BorderRadius.circular(6)),
      child: const Center(child: Text('[ Empty ]', style: TextStyle(color: Colors.white12, fontSize: 10))),
    );
  }

  Widget _buildCenterLabel() {
    if (combatOutcome == null) return const Divider(color: Colors.white10, height: 10, indent: 10, endIndent: 10);
    
    Color color = Colors.amberAccent;
    if (combatOutcome == 'WIN') color = Colors.greenAccent;
    if (combatOutcome == 'LOSE') color = Colors.redAccent;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(color: color.withOpacity(0.15), borderRadius: BorderRadius.circular(4)),
      child: Text(combatOutcome!, style: TextStyle(color: color, fontSize: 11, fontWeight: FontWeight.bold)),
    );
  }
}