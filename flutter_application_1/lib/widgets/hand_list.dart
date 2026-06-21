import 'package:flutter/material.dart';
import '../models/card_models.dart';

class HandList extends StatelessWidget {
  final List<GameCard> hand;
  final bool canInteract;
  final Function(GameCard) onCardTap; // Added this parameter line

  const HandList({
    Key? key,
    required this.hand,
    required this.canInteract,
    required this.onCardTap, // Added this constructor line
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return ListView.builder(
      scrollDirection: Axis.horizontal,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      itemCount: hand.length,
      itemBuilder: (context, index) {
        final card = hand[index];
        
        return Padding(
          padding: const EdgeInsets.only(right: 12.0),
          child: GestureDetector(
            onTap: () => onCardTap(card), // Forwards the tap to your magnifier frame logic
            child: Opacity(
              opacity: canInteract ? 1.0 : 0.5,
              child: Draggable<GameCard>(
                data: card,
                feedback: _buildSimpleCardPreview(card),
                childWhenDragging: Opacity(
                  opacity: 0.2,
                  child: _buildSimpleCardPreview(card),
                ),
                ignoringFeedbackSemantics: false,
                maxSimultaneousDrags: canInteract ? 1 : 0,
                child: _buildSimpleCardPreview(card),
              ),
            ),
          ),
        );
      },
    );
  }

  // Consistent aspect ratio containment loop matching your visual alignment constraints
  Widget _buildSimpleCardPreview(GameCard card) {
    return Hero(
      tag: 'magnify_${card.id}',
      child: SizedBox(
        width: 90,
        height: 130,
        child: ClipRRect(
          borderRadius: BorderRadius.circular(8),
          child: Image.asset(
            card.image,
            fit: BoxFit.contain,
            errorBuilder: (context, error, stackTrace) {
              return Container(
                color: Colors.grey[900],
                alignment: Alignment.center,
                padding: const EdgeInsets.all(4),
                child: Text(
                  card.name,
                  textAlign: TextAlign.center,
                  style: const TextStyle(color: Colors.white54, fontSize: 10, decoration: TextDecoration.none),
                ),
              );
            },
          ),
        ),
      ),
    );
  }
}