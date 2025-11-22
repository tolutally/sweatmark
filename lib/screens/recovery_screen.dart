import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../state/recovery_notifier.dart';
import '../widgets/body_map_svg.dart';
import '../models/workout_model.dart';

class RecoveryScreen extends StatefulWidget {
  const RecoveryScreen({super.key});

  @override
  State<RecoveryScreen> createState() => _RecoveryScreenState();
}

class _RecoveryScreenState extends State<RecoveryScreen> {
  bool _showFront = true;

  @override
  Widget build(BuildContext context) {
    final notifier = context.watch<RecoveryNotifier>();
    final statusMap = notifier.muscleStatus;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Muscle Recovery'),
        backgroundColor: Colors.transparent,
        centerTitle: true,
      ),
      body: Column(
        children: [
          // Toggle
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: SegmentedButton<bool>(
              segments: const [
                ButtonSegment(value: true, label: Text('Front')),
                ButtonSegment(value: false, label: Text('Back')),
              ],
              selected: {_showFront},
              onSelectionChanged: (Set<bool> newSelection) {
                setState(() {
                  _showFront = newSelection.first;
                });
              },
              style: ButtonStyle(
                backgroundColor: MaterialStateProperty.resolveWith<Color>(
                  (Set<MaterialState> states) {
                    if (states.contains(MaterialState.selected)) {
                      return Theme.of(context).colorScheme.primary;
                    }
                    return Theme.of(context).cardColor;
                  },
                ),
                foregroundColor: MaterialStateProperty.resolveWith<Color>(
                  (Set<MaterialState> states) {
                    if (states.contains(MaterialState.selected)) {
                      return Colors.black;
                    }
                    return Colors.white;
                  },
                ),
              ),
            ),
          ),

          // Body Map
          Expanded(
            flex: 3,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 32.0),
              child: BodyMapSvg(
                statusMap: statusMap,
                isFront: _showFront,
              ),
            ),
          ),

          // Status List
          Expanded(
            flex: 2,
            child: Container(
              decoration: BoxDecoration(
                color: Theme.of(context).cardColor,
                borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
              ),
              child: ListView.builder(
                padding: const EdgeInsets.all(16),
                itemCount: statusMap.length,
                itemBuilder: (context, index) {
                  final muscle = statusMap.keys.elementAt(index);
                  final status = statusMap[muscle]!;
                  return ListTile(
                    title: Text(muscle, style: const TextStyle(fontWeight: FontWeight.bold)),
                    subtitle: Text(_getStatusText(status)),
                    trailing: CircleAvatar(
                      radius: 6,
                      backgroundColor: _getStatusColor(status),
                    ),
                  );
                },
              ),
            ),
          ),
        ],
      ),
    );
  }

  String _getStatusText(MuscleStatus status) {
    switch (status) {
      case MuscleStatus.recovered:
        return 'Fully Recovered';
      case MuscleStatus.recovering:
        return 'Recovering';
      case MuscleStatus.fatigued:
        return 'Fatigued';
    }
  }

  Color _getStatusColor(MuscleStatus status) {
    switch (status) {
      case MuscleStatus.recovered:
        return const Color(0xFF3B82F6);
      case MuscleStatus.recovering:
        return const Color(0xFFEAB308);
      case MuscleStatus.fatigued:
        return const Color(0xFFEF4444);
    }
  }
}
