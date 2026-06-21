import 'package:flutter/material.dart';
import '../models/card_models.dart';

class CardView extends StatelessWidget {
  final GameCard card;
  final double width;
  final double height;
  final bool isOpponent;
  final bool enableInspect;

  const CardView({
    Key? key,
    required this.card,
    this.width = 90,
    this.height = 110,
    this.isOpponent = false,
    this.enableInspect = true,
  }) : super(key: key);

  void _inspectEnlarged(BuildContext context) {
    if (!enableInspect) return;
    showDialog(
      context: context,
      builder: (context) => GestureDetector(
        onTap: () => Navigator.pop(context),
        child: Center(
          child: Container(
            width: 240,
            height: 330,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(16),
              image: DecorationImage(image: AssetImage(card.image), fit: BoxFit.cover),
              border: Border.all(color: Colors.amber, width: 3),
            ),
            child: Container(
              padding: const EdgeInsets.all(16),
              color: Colors.black.withOpacity(0.5),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.end,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(card.name, style: const TextStyle(color: Colors.white, fontSize: 22, fontWeight: FontWeight.bold)),
                  Text('CRB: ${card.crb} | Cost: ${card.inf}', style: const TextStyle(color: Colors.greenAccent, fontSize: 16)),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () => _inspectEnlarged(context),
      child: Container(
        width: width,
        height: height,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: isOpponent ? Colors.red : Colors.blue),
          image: DecorationImage(image: AssetImage(card.image), fit: BoxFit.cover),
        ),
        child: Container(
          color: Colors.black38,
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(card.name, style: const TextStyle(color: Colors.white, fontSize: 10), maxLines: 1),
              Text('C: ${card.crb}', style: const TextStyle(color: Colors.greenAccent, fontSize: 11, fontWeight: FontWeight.bold)),
            ],
          ),
        ),
      ),
    );
  }
}