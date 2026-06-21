import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show rootBundle;

// ====== Models ======

class TriggerDefinition {
  final int id;
  final String name;
  final String desc;

  TriggerDefinition({required this.id, required this.name, required this.desc});

  factory TriggerDefinition.fromJson(Map<String, dynamic> json) {
    return TriggerDefinition(
      id: json['id'],
      name: json['name'],
      desc: json['desc'],
    );
  }
}

class TargetDefinition {
  final int id;
  final String name;
  final String desc;

  TargetDefinition({required this.id, required this.name, required this.desc});

  factory TargetDefinition.fromJson(Map<String, dynamic> json) {
    return TargetDefinition(
      id: json['id'],
      name: json['name'],
      desc: json['desc'],
    );
  }
}

class EffectDefinition {
  final int id;
  final String name;
  final String desc;

  EffectDefinition({required this.id, required this.name, required this.desc});

  factory EffectDefinition.fromJson(Map<String, dynamic> json) {
    return EffectDefinition(
      id: json['id'],
      name: json['name'],
      desc: json['desc'],
    );
  }
}

class CardEffect {
  final int trigger;
  final int target;
  final int effectId;
  final Map<String, dynamic> params;
  final Map<String, dynamic>? condition;

  CardEffect({
    required this.trigger,
    required this.target,
    required this.effectId,
    required this.params,
    this.condition,
  });

  factory CardEffect.fromJson(Map<String, dynamic> json) {
    return CardEffect(
      trigger: json['trigger'],
      target: json['target'],
      effectId: json['effect_id'],
      params: Map<String, dynamic>.from(json['params'] ?? {}),
      condition: json['condition'] != null
          ? Map<String, dynamic>.from(json['condition'])
          : null,
    );
  }

  String resolve(
    Map<int, EffectDefinition> effectDefs,
    Map<int, TriggerDefinition> triggerDefs,
    Map<int, TargetDefinition> targetDefs,
  ) {
    final effectDef = effectDefs[effectId];
    final triggerDef = triggerDefs[trigger];
    final targetDef = targetDefs[target];

    final effectName = effectDef?.name ?? 'Unknown Effect';
    final triggerName = triggerDef?.name ?? 'Unknown Trigger';
    final targetName = targetDef?.name ?? 'Unknown Target';

    final paramsText = _resolveParams(params, effectDefs);
    final conditionText = condition != null ? _resolveCondition(condition!) : '';

    return '$effectName$paramsText on $targetName'
        '${conditionText.isNotEmpty ? ' ($conditionText)' : ''}'
        ' [Trigger: $triggerName]';
  }

  String _resolveParams(
      Map<String, dynamic> p, Map<int, EffectDefinition> effectDefs) {
    if (p.isEmpty) return '';

    final parts = <String>[];

    if (p.containsKey('amount')) {
      final amount = p['amount'];
      if (amount is int) {
        parts.add(amount < 0 ? '${amount.abs()}' : '+$amount');
      } else if (amount is String) {
        parts.add('($amount)');
      }
    }

    if (p.containsKey('crb')) {
      parts.add('CRB ${p['crb']}');
    }

    if (p.containsKey('type')) {
      parts.add('(${p['type']})');
    }

    if (p.containsKey('accumulate') && p['accumulate'] == true) {
      parts.add('accumulating');
    }

    if (p.containsKey('negate') && p['negate'] == true) {
      parts.add('negating');
    }

    if (p.containsKey('once') && p['once'] == true) {
      parts.add('once only');
    }

    if (p.containsKey('choice')) {
      final choices = p['choice'] as List<dynamic>;
      final choiceTexts = choices.map((c) {
        final cMap = Map<String, dynamic>.from(c);
        final cEffectDef = effectDefs[cMap['effect_id']];
        final cEffectName = cEffectDef?.name ?? 'Unknown';
        final cAmount = cMap.containsKey('amount') ? ' ${cMap['amount']}' : '';
        return '$cEffectName$cAmount';
      }).toList();
      parts.add('choose: ${choiceTexts.join(' OR ')}');
    }

    return parts.isNotEmpty ? ': ${parts.join(', ')}' : '';
  }

  String _resolveCondition(Map<String, dynamic> c) {
    final parts = <String>[];

    if (c.containsKey('owner_inf')) {
      final inf = c['owner_inf'] as Map<String, dynamic>;
      if (inf.containsKey('min')) parts.add('owner INF > ${inf['min']}');
    }

    if (c.containsKey('opponent_crb')) {
      final crb = c['opponent_crb'] as Map<String, dynamic>;
      if (crb.containsKey('less_than')) {
        parts.add('opponent CRB < ${crb['less_than']}');
      }
    }

    if (c.containsKey('opponent_inf')) {
      final inf = c['opponent_inf'] as Map<String, dynamic>;
      if (inf.containsKey('less_than_or_equal')) {
        parts.add('opponent INF <= ${inf['less_than_or_equal']}');
      }
    }

    if (c.containsKey('once') && c['once'] == true) {
      parts.add('once only');
    }

    return parts.join(', ');
  }
}

class GameCard {
  final String id;
  final String name;
  final String category;
  final int crb;
  final int inf;
  final String image;
  final List<CardEffect> effects;

  GameCard({
    required this.id,
    required this.name,
    required this.category,
    required this.crb,
    required this.inf,
    required this.image,
    required this.effects,
  });

  factory GameCard.fromJson(Map<String, dynamic> json) {
    return GameCard(
      id: json['id'],
      name: json['name'],
      category: json['category'],
      crb: json['crb'],
      inf: json['inf'],
      image: json['image'],
      effects: (json['effects'] as List)
          .map((e) => CardEffect.fromJson(e))
          .toList(),
    );
  }
}

// ====== Screen ======

class CardGridScreen extends StatefulWidget {
  const CardGridScreen({super.key});

  @override
  State<CardGridScreen> createState() => _CardGridScreenState();
}

class _CardGridScreenState extends State<CardGridScreen> {
  List<GameCard> cards = [];
  Map<int, EffectDefinition> effectDefs = {};
  Map<int, TriggerDefinition> triggerDefs = {};
  Map<int, TargetDefinition> targetDefs = {};

  @override
  void initState() {
    super.initState();
    loadAllData();
  }

  Future<void> loadAllData() async {
    final effectsJson = json.decode(
        await rootBundle.loadString('assets/Data/effects_library.json'));
    final triggersJson = json.decode(
        await rootBundle.loadString('assets/Data/trigger_libraries.json'));
    final targetsJson = json.decode(
        await rootBundle.loadString('assets/Data/target_library.json'));
    final cardsJson = json.decode(
        await rootBundle.loadString('assets/Data/cards_library.json'));

    effectDefs = {
      for (var e in effectsJson['effects_library'])
        e['id']: EffectDefinition.fromJson(e)
    };

    triggerDefs = {
      for (var t in triggersJson['trigger_library'])
        t['id']: TriggerDefinition.fromJson(t)
    };

    targetDefs = {
      for (var t in targetsJson['target_library'])
        t['id']: TargetDefinition.fromJson(t)
    };

    final List<GameCard> loadedCards = (cardsJson['cards'] as List)
        .map((c) => GameCard.fromJson(c))
        .toList();

    if (mounted) {
      setState(() {
        cards = loadedCards;
      });
    }
  }

  void showCardDetails(GameCard card) {
  showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.black,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
    ),
    builder: (context) {
      return DraggableScrollableSheet(
        expand: false,
        initialChildSize: 0.9,
        minChildSize: 0.6,
        maxChildSize: 0.95,
        builder: (context, scrollController) {
          return Container(
            padding: const EdgeInsets.all(16),
            child: ListView(
              controller: scrollController,
              children: [
                // IMAGE (FIXED: NO CROPPING)
                AspectRatio(
                  aspectRatio: 3 / 4,
                  child: Image.asset(
                    card.image,
                    fit: BoxFit.contain,
                    errorBuilder: (context, error, stackTrace) {
                      return Container(
                        color: Colors.grey,
                        child: const Center(
                          child: Text(
                            "Image not found",
                            style: TextStyle(color: Colors.white),
                          ),
                        ),
                      );
                    },
                  ),
                ),

                const SizedBox(height: 12),

                Text(
                  card.name,
                  style: const TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),

                const SizedBox(height: 6),

                Text(
                  'Category: ${card.category}',
                  style: const TextStyle(color: Colors.white70),
                ),

                Text(
                  'CRB: ${card.crb}  |  Cost: ${card.inf} INF',
                  style: const TextStyle(color: Colors.white70),
                ),

                const SizedBox(height: 14),

                const Text(
                  'Effects (inactive in this version):',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),

                const SizedBox(height: 4),

                const Text(
                  'Effects are displayed for reference only and are not active in current gameplay.',
                  style: TextStyle(fontSize: 12, color: Colors.white54),
                ),

                const SizedBox(height: 10),

                ...card.effects.map(
                  (e) => Padding(
                    padding: const EdgeInsets.only(bottom: 6),
                    child: Text(
                      e.resolve(effectDefs, triggerDefs, targetDefs),
                      style: const TextStyle(
                        fontSize: 13,
                        color: Colors.white70,
                      ),
                    ),
                  ),
                ),

                const SizedBox(height: 20),
              ],
            ),
          );
        },
      );
    },
  );
}

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Card Gallery')),
      body: cards.isEmpty
          ? const Center(child: CircularProgressIndicator())
          : Column(
              children: [
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(vertical: 8),
                  color: Colors.grey.shade100,
                  child: const Text(
                    'Tap a card to view more information',
                    textAlign: TextAlign.center,
                    style: TextStyle(color: Colors.grey),
                  ),
                ),
                Expanded(
                  child: LayoutBuilder(
                    builder: (context, constraints) {
                      final double columnWidth =
                          (constraints.maxWidth - 24) / 2;

                      return SingleChildScrollView(
                        padding: const EdgeInsets.all(8),
                        child: Wrap(
                          spacing: 8,
                          runSpacing: 8,
                          children: cards.map((card) {
                            return GestureDetector(
                              onTap: () => showCardDetails(card),
                              child: SizedBox(
                                width: columnWidth,
                                child: ClipRRect(
                                  borderRadius: BorderRadius.circular(8),
                                  child: Image.asset(
                                    card.image,
                                    width: columnWidth,
                                    fit: BoxFit.fitWidth,
                                  ),
                                ),
                              ),
                            );
                          }).toList(),
                        ),
                      );
                    },
                  ),
                ),
              ],
            ),
    );
  }
}