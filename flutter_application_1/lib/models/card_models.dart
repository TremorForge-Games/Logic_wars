class GameCard {
  final String id;
  final String name;
  final String category;
  int crb;
  final int inf;
  final List<CardEffect> effects;
  final String image;

  // Runtime state fields (not from JSON)
  bool persists = false;
  bool silenced = false;
  bool survivesOnceUsed = false;
  int accumulatedCrb = 0;

  GameCard({
    required this.id,
    required this.name,
    required this.category,
    required this.crb,
    required this.inf,
    required this.effects,
    required this.image,
  });

  // ADDED: Simple fallback factory constructor for placeholder logging
  factory GameCard.empty() {
    return GameCard(
      id: 'empty',
      name: 'No Card',
      category: '',
      crb: 0,
      inf: 0,
      effects: [],
      image: '',
    );
  }

  factory GameCard.fromJson(Map<String, dynamic> json) {
    var list = json['effects'] as List? ?? [];
    List<CardEffect> effectList =
        list.map((i) => CardEffect.fromJson(i)).toList();

    return GameCard(
      id: json['id'] ?? '',
      name: json['name'] ?? '',
      category: json['category'] ?? '',
      crb: json['crb'] ?? 0,
      inf: json['inf'] ?? 0,
      effects: effectList,
      image: json['image'] ?? '',
    );
  }

  // Copy resets all runtime state so each instance in play is independent
  GameCard copy() {
    return GameCard(
      id: id,
      name: name,
      category: category,
      crb: crb,
      inf: inf,
      effects: effects.map((e) => e.copy()).toList(),
      image: image,
    );
  }

  // Reset runtime state between combats
  void resetRuntimeState() {
    persists = false;
    silenced = false;
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
      trigger: json['trigger'] ?? 0,
      target: json['target'] ?? 0,
      effectId: json['effect_id'] ?? 0,
      params: json['params'] ?? {},
      condition: json['condition'],
    );
  }

  CardEffect copy() {
    return CardEffect(
      trigger: trigger,
      target: target,
      effectId: effectId,
      params: Map<String, dynamic>.from(params),
      condition: condition != null
          ? Map<String, dynamic>.from(condition!)
          : null,
    );
  }
}