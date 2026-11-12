import 'dart:async';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/cardio_machine.dart';
import '../models/exercise_model.dart';
import '../models/user_settings.dart';
import '../models/workout_model.dart';
import '../state/settings_notifier.dart';
import '../state/workout_notifier.dart';
import '../theme/app_theme.dart';
import 'cardio_details_button.dart';
import 'duration_editor.dart';
import 'keyboard_done_bar.dart';

/// One cardio session (treadmill, bike, rower…) instead of strength sets:
/// a stopwatch, then the numbers the machine shows at the end. Pace, speed
/// or split is worked out, never typed.
class CardioSessionCard extends StatefulWidget {
  final Exercise exercise;
  final WorkoutExerciseLog log;
  final int exerciseIndex;
  const CardioSessionCard(
      {super.key,
      required this.exercise,
      required this.log,
      required this.exerciseIndex});

  @override
  State<CardioSessionCard> createState() => _CardioSessionCardState();
}

class _CardioSessionCardState extends State<CardioSessionCard> {
  Timer? _tick;
  final Map<CardioField, TextEditingController> _controllers = {};
  final Map<CardioField, FocusNode> _focus = {};

  CardioMachine get _machine => CardioMachineInfo.of(widget.exercise.name);
  String get _id => widget.log.exerciseId;
  WorkoutSet get _set =>
      widget.log.sets.isEmpty ? WorkoutSet() : widget.log.sets.first;

  bool get _miles {
    final saved = _set.distanceUnit;
    if (saved != null && (_set.distance ?? 0) > 0) return saved == 'mi';
    return context.read<SettingsNotifier>().userSettings.distanceUnit ==
        DistanceUnit.miles;
  }

  @override
  void initState() {
    super.initState();
    for (final field in CardioField.values) {
      _controllers[field] = TextEditingController();
      _focus[field] = FocusNode()
        ..addListener(() {
          final node = _focus[field]!;
          if (!node.hasFocus) return;
          WidgetsBinding.instance.addPostFrameCallback((_) {
            final c = _controllers[field]!;
            if (node.hasFocus) {
              c.selection =
                  TextSelection(baseOffset: 0, extentOffset: c.text.length);
            }
          });
        });
    }
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _syncText();
    });
  }

  @override
  void didUpdateWidget(covariant CardioSessionCard oldWidget) {
    super.didUpdateWidget(oldWidget);
    _syncText();
  }

  @override
  void dispose() {
    _tick?.cancel();
    for (final c in _controllers.values) {
      c.dispose();
    }
    for (final f in _focus.values) {
      f.dispose();
    }
    super.dispose();
  }

  String _number(num? value, {int decimals = 2}) {
    if (value == null || value == 0) return '';
    final text = value.toStringAsFixed(decimals);
    return text.contains('.') ? text.replaceFirst(RegExp(r'\.?0+$'), '') : text;
  }

  String _textFor(CardioField field) {
    final set = _set;
    switch (field) {
      case CardioField.distance:
        final d = set.distance;
        if (d == null) return '';
        if (_machine.usesMetres) {
          final km = set.distanceUnit == 'mi' ? d * 1.609344 : d;
          return _number((km * 1000).round());
        }
        return _number(d);
      case CardioField.incline:
        return _number(set.incline, decimals: 1);
      case CardioField.level:
        return _number(set.resistance);
      case CardioField.calories:
        return _number(set.calories);
    }
  }

  /// Fills fields from the saved session, except one being typed in.
  void _syncText() {
    for (final field in CardioField.values) {
      if (_focus[field]!.hasFocus) continue;
      final text = _textFor(field);
      if (_controllers[field]!.text != text) _controllers[field]!.text = text;
    }
  }

  void _keepTicking(bool running) {
    if (running && _tick == null) {
      _tick = Timer.periodic(const Duration(seconds: 1), (_) {
        if (mounted) setState(() {});
      });
    } else if (!running) {
      _tick?.cancel();
      _tick = null;
    }
  }

  void _changed(CardioField field, String value, WorkoutNotifier notifier) {
    final miles = _miles;
    notifier.updateCardio(_id, (set) {
      switch (field) {
        case CardioField.distance:
          final v = double.tryParse(value);
          if (v == null || v <= 0) {
            set.distance = null;
            set.distanceUnit = null;
          } else if (_machine.usesMetres) {
            set.distance = v / 1000;
            set.distanceUnit = 'km';
          } else {
            set.distance = v;
            set.distanceUnit = miles ? 'mi' : 'km';
          }
        case CardioField.incline:
          set.incline = double.tryParse(value);
        case CardioField.level:
          set.resistance = int.tryParse(value);
        case CardioField.calories:
          set.calories = int.tryParse(value);
      }
      set.speed = CardioPace.speed(set.durationSeconds, _km(set),
          miles: set.distanceUnit == 'mi');
    });
  }

  double? _km(WorkoutSet set) {
    final d = set.distance;
    if (d == null) return null;
    return set.distanceUnit == 'mi' ? d * 1.609344 : d;
  }

  Future<void> _editTime(WorkoutNotifier notifier) async {
    hideKeyboard();
    if (notifier.isCardioRunning(_id)) notifier.stopCardio(_id);
    final seconds = await showDurationEditor(
        context, notifier.cardioSeconds(_id),
        title: '${widget.exercise.name} time',
        message: 'Enter the time from the machine, or fix the stopwatch.',
        withSeconds: true);
    if (seconds == null || !mounted) return;
    notifier.updateCardio(_id, (set) {
      set.durationSeconds = seconds;
      set.speed =
          CardioPace.speed(seconds, _km(set), miles: set.distanceUnit == 'mi');
    });
  }

  static IconData _icon(CardioMachine machine) => switch (machine) {
        CardioMachine.treadmill => Icons.directions_run_rounded,
        CardioMachine.bike => Icons.pedal_bike_rounded,
        CardioMachine.rower => Icons.rowing_rounded,
        CardioMachine.stairs => Icons.stairs_rounded,
        CardioMachine.elliptical => Icons.directions_walk_rounded,
        CardioMachine.other => Icons.favorite_rounded,
      };

  ({String label, String unit, bool decimal}) _fieldInfo(CardioField field) =>
      switch (field) {
        CardioField.distance => _machine.usesMetres
            ? (label: 'Distance', unit: 'm', decimal: false)
            : (label: 'Distance', unit: _miles ? 'mi' : 'km', decimal: true),
        CardioField.incline => (label: 'Incline', unit: '%', decimal: true),
        CardioField.level => (label: 'Level', unit: '', decimal: false),
        CardioField.calories => (
            label: 'Calories',
            unit: 'kcal',
            decimal: false
          ),
      };

  Widget _fieldCell(CardioField field, WorkoutNotifier notifier) {
    final info = _fieldInfo(field);
    final colors = Theme.of(context).colorScheme;
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: () => _focus[field]!.requestFocus(),
      child: Container(
        padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
        decoration: BoxDecoration(
            color: colors.surfaceContainerLow,
            borderRadius: BorderRadius.circular(16)),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(info.label,
              style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w500,
                  color: colors.onSurfaceVariant)),
          const SizedBox(height: 2),
          Row(
              crossAxisAlignment: CrossAxisAlignment.baseline,
              textBaseline: TextBaseline.alphabetic,
              children: [
                Expanded(
                  child: TextField(
                    key: ValueKey('cardio-${field.name}'),
                    controller: _controllers[field],
                    focusNode: _focus[field],
                    keyboardType:
                        TextInputType.numberWithOptions(decimal: info.decimal),
                    style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.w600,
                        color: colors.onSurface),
                    decoration: InputDecoration(
                      isDense: true,
                      filled: false,
                      border: InputBorder.none,
                      enabledBorder: InputBorder.none,
                      focusedBorder: InputBorder.none,
                      contentPadding: EdgeInsets.zero,
                      hintText: '—',
                      hintStyle: TextStyle(
                          fontSize: 20, color: colors.onSurfaceVariant),
                    ),
                    onChanged: (value) => _changed(field, value, notifier),
                  ),
                ),
                if (info.unit.isNotEmpty)
                  Text(info.unit,
                      style: TextStyle(
                          fontSize: 13, color: colors.onSurfaceVariant)),
              ]),
        ]),
      ),
    );
  }

  void _menu(WorkoutNotifier notifier) {
    showModalBottomSheet<void>(
      context: context,
      builder: (sheet) => SafeArea(
        child: ListTile(
          leading: const Icon(Icons.delete_outline_rounded),
          title: const Text('Remove exercise'),
          onTap: () {
            Navigator.pop(sheet);
            notifier.removeExercise(widget.exerciseIndex);
          },
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final notifier = context.watch<WorkoutNotifier>();
    final colors = Theme.of(context).colorScheme;
    final running = notifier.isCardioRunning(_id);
    _keepTicking(running);
    final seconds = notifier.cardioSeconds(_id);
    final set = _set;
    final pace = CardioPace.summary(
        machine: _machine,
        seconds: seconds,
        distanceKm: _km(set),
        miles:
            set.distanceUnit == 'mi' || (set.distanceUnit == null && _miles));
    final logged = set.isCompleted;
    final fields = _machine.fields;

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.fromLTRB(16, 14, 12, 14),
      decoration: BoxDecoration(
          color: colors.surface, borderRadius: BorderRadius.circular(24)),
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        Row(children: [
          Container(
            width: 44,
            height: 44,
            decoration: const BoxDecoration(
                color: AppColors.coral, shape: BoxShape.circle),
            child: Icon(_icon(_machine), color: Colors.white, size: 22),
          ),
          const SizedBox(width: 12),
          Expanded(
            child:
                Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(widget.exercise.name,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                      fontSize: 16, fontWeight: FontWeight.w600)),
              const SizedBox(height: 2),
              Text(logged ? 'Cardio · logged' : 'Cardio session',
                  style: TextStyle(
                      fontSize: 12.5, color: colors.onSurfaceVariant)),
            ]),
          ),
          if (logged)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(
                  color: AppColors.lime,
                  borderRadius: BorderRadius.circular(99)),
              child: const Text('Logged',
                  style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: AppColors.ink)),
            ),
          IconButton(
            tooltip: 'Exercise options',
            onPressed: () => _menu(notifier),
            icon: const Icon(Icons.more_horiz_rounded),
          ),
        ]),
        const SizedBox(height: 14),
        // Time: a stopwatch, or tap to type what the machine shows.
        Container(
          padding: const EdgeInsets.fromLTRB(16, 14, 14, 14),
          decoration: BoxDecoration(
              color: colors.surfaceContainerLow,
              borderRadius: BorderRadius.circular(20)),
          child: Row(children: [
            Expanded(
              child: InkWell(
                key: const ValueKey('cardio-time'),
                onTap: () => _editTime(notifier),
                borderRadius: BorderRadius.circular(12),
                child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(children: [
                        Text('Time',
                            style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w500,
                                color: colors.onSurfaceVariant)),
                        const SizedBox(width: 4),
                        Icon(Icons.edit_outlined,
                            size: 13,
                            color: colors.onSurfaceVariant,
                            semanticLabel: 'Edit time'),
                      ]),
                      Text(CardioPace.clock(seconds),
                          style: const TextStyle(
                              fontSize: 36,
                              height: 1.1,
                              fontWeight: FontWeight.w600,
                              letterSpacing: -1,
                              fontFeatures: [FontFeature.tabularFigures()])),
                    ]),
              ),
            ),
            FilledButton.icon(
              key: const ValueKey('cardio-start-stop'),
              onPressed: () {
                hideKeyboard();
                running ? notifier.stopCardio(_id) : notifier.startCardio(_id);
              },
              style: FilledButton.styleFrom(
                  backgroundColor:
                      running ? AppColors.coral : AppColors.lavender,
                  foregroundColor: running ? Colors.white : AppColors.ink,
                  minimumSize: const Size(0, 48),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14))),
              icon: Icon(
                  running ? Icons.stop_rounded : Icons.play_arrow_rounded,
                  size: 22),
              label: Text(running
                  ? 'Stop'
                  : seconds > 0
                      ? 'Resume'
                      : 'Start'),
            ),
          ]),
        ),
        const SizedBox(height: 10),
        Row(children: [
          for (var i = 0; i < fields.length; i++) ...[
            if (i > 0) const SizedBox(width: 8),
            Expanded(child: _fieldCell(fields[i], notifier)),
          ],
        ]),
        if (pace != null) ...[
          const SizedBox(height: 10),
          Row(children: [
            Icon(Icons.speed_rounded, size: 16, color: colors.onSurfaceVariant),
            const SizedBox(width: 6),
            Expanded(
              child: Text(pace,
                  key: const ValueKey('cardio-pace'),
                  style: const TextStyle(
                      fontSize: 13.5, fontWeight: FontWeight.w600)),
            ),
          ]),
        ],
        const SizedBox(height: 4),
        CardioDetailsButton(exercise: widget.log),
      ]),
    );
  }
}
