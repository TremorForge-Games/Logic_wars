import 'package:flutter/material.dart';
import '../models/combat_log.dart';
import '../models/game_state.dart';

class CombatResultsScreen extends StatelessWidget {
  final CombatLog log;
  final Player viewingAs;
  final VoidCallback onContinue;

  const CombatResultsScreen({
    Key? key,
    required this.log,
    required this.viewingAs,
    required this.onContinue,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final isAttacker = log.attacker == viewingAs;
    final attackerLabel = isAttacker ? 'You' : 'Bot';
    final defenderLabel = isAttacker ? 'Bot' : 'You';

    return Scaffold(
      backgroundColor: Colors.grey[900],
      appBar: AppBar(
        backgroundColor: Colors.black87,
        automaticallyImplyLeading: false,
        title: const Text(
          'Combat Results',
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
        ),
      ),
      body: Column(
        children: [
          // Header
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 16),
            color: Colors.black54,
            child: Text(
              '$attackerLabel attacked $defenderLabel',
              textAlign: TextAlign.center,
              style: const TextStyle(color: Colors.white70, fontSize: 14),
            ),
          ),

          // Lane results
          Expanded(
            child: ListView.builder(
              padding: const EdgeInsets.all(12),
              itemCount: log.lanes.length,
              itemBuilder: (context, index) {
                final lane = log.lanes[index];
                return _buildLaneResult(lane, attackerLabel, defenderLabel);
              },
            ),
          ),

          // Summary
          _buildSummary(log),

          // Continue button
          Padding(
            padding: const EdgeInsets.all(16),
            child: SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.blueAccent,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                ),
                onPressed: onContinue,
                child: const Text(
                  'CONTINUE',
                  style: TextStyle(
                      color: Colors.white,
                      fontSize: 16,
                      fontWeight: FontWeight.bold),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLaneResult(
      LaneCombatLog lane, String attackerLabel, String defenderLabel) {
    final resultColor = _resultColor(lane.result);

    // Dynamic Title String Generation: Map over all attacking lanes -> "Lane 1 & Lane 2"
    final attackingLanesText = lane.fromLanes.map((idx) => 'Lane ${idx + 1}').join(' & ');
    final titleText = '$attackingLanesText → Lane ${lane.toLane + 1}';

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: Colors.white10,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: resultColor.withOpacity(0.5)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Dynamic Header
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              color: resultColor.withOpacity(0.2),
              borderRadius:
                  const BorderRadius.vertical(top: Radius.circular(8)),
            ),
            child: Text(
              titleText,
              style: TextStyle(
                  color: resultColor,
                  fontWeight: FontWeight.bold,
                  fontSize: 13),
            ),
          ),

          Padding(
            padding: const EdgeInsets.all(12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Card Matchup Container
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    // LEFT SIDE: All attacking cards stacked vertically
                    Expanded(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: lane.attackingCards.map((card) => Padding(
                          padding: const EdgeInsets.only(bottom: 4),
                          child: _buildCardChip(card.name, card.crb, Colors.blue),
                        )).toList(),
                      ),
                    ),

                    const Padding(
                      padding: EdgeInsets.symmetric(horizontal: 12),
                      child: Text('vs',
                          style: TextStyle(color: Colors.white54, fontSize: 12, fontWeight: FontWeight.bold)),
                    ),

                    // RIGHT SIDE: Defending card or empty block
                    Expanded(
                      child: lane.defendingCard != null
                          ? _buildCardChip(lane.defendingCard!.name,
                              lane.defenderCrb, Colors.red)
                          : Container(
                              alignment: Alignment.center,
                              padding: const EdgeInsets.symmetric(vertical: 12),
                              child: const Text('[ Empty Lane ]',
                                  textAlign: TextAlign.center,
                                  style: TextStyle(
                                      color: Colors.white38, fontSize: 12, fontStyle: FontStyle.italic)),
                            ),
                    ),
                  ],
                ),

                const SizedBox(height: 12),

                // Total CRB VS Math Line
                if (lane.result != CombatResult.emptyLaneHit) ...[
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text('Total Attack CRB: ${lane.attackerCrb}',
                          style: const TextStyle(color: Colors.blueAccent, fontSize: 11, fontWeight: FontWeight.bold)),
                      Text('Target Def CRB: ${lane.defenderCrb}',
                          style: const TextStyle(color: Colors.redAccent, fontSize: 11, fontWeight: FontWeight.bold)),
                    ],
                  ),
                  const SizedBox(height: 8),
                ],

                // Effects triggered
                if (lane.effectsTriggered.isNotEmpty) ...[
                  const Text('Effects:',
                      style: TextStyle(
                          color: Colors.amber,
                          fontSize: 12,
                          fontWeight: FontWeight.bold)),
                  const SizedBox(height: 4),
                  ...lane.effectsTriggered.map((e) => Padding(
                        padding: const EdgeInsets.only(bottom: 2),
                        child: Text(e,
                            style: const TextStyle(
                                color: Colors.white70, fontSize: 11)),
                      )),
                  const SizedBox(height: 8),
                ],

                // Result Text Banner
                Container(
                  width: double.infinity,
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                  decoration: BoxDecoration(
                    color: resultColor.withOpacity(0.15),
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Text(
                    lane.resultText,
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: resultColor,
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCardChip(String name, int crb, Color color) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 6),
      decoration: BoxDecoration(
        color: color.withOpacity(0.2),
        borderRadius: BorderRadius.circular(4),
        border: Border.all(color: color.withOpacity(0.5)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            name,
            textAlign: TextAlign.center,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
                color: color, fontSize: 11, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 2),
          Text('CRB: $crb',
              style: const TextStyle(color: Colors.white, fontSize: 10)),
        ],
      ),
    );
  }

  Widget _buildSummary(CombatLog log) {
    final destroyed = log.destroyedCards;
    final damage = log.totalDamageDealt;

    return Container(
      width: double.infinity,
      margin: const EdgeInsets.symmetric(horizontal: 12),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.black45,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.white24),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Summary',
              style: TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                  fontSize: 14)),
          const SizedBox(height: 8),
          if (destroyed.isNotEmpty)
            Text('Destroyed: ${destroyed.join(', ')}',
                style: const TextStyle(color: Colors.redAccent, fontSize: 12)),
          if (damage > 0)
            Text('Direct damage dealt: $damage',
                style:
                    const TextStyle(color: Colors.orangeAccent, fontSize: 12)),
          if (destroyed.isEmpty && damage == 0)
            const Text('No cards destroyed, no damage dealt.',
                style: TextStyle(color: Colors.white54, fontSize: 12)),
        ],
      ),
    );
  }

  Color _resultColor(CombatResult result) {
    switch (result) {
      case CombatResult.attackerWins:
        return Colors.greenAccent;
      case CombatResult.defenderWins:
        return Colors.redAccent;
      case CombatResult.tie:
        return Colors.orangeAccent;
      case CombatResult.emptyLaneHit:
        return Colors.purpleAccent;
    }
  }
}