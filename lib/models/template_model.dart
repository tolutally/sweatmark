import 'package:cloud_firestore/cloud_firestore.dart';

/// Repeat frequency options for scheduled workouts
enum RepeatFrequency {
  daily,
  everyOtherDay,
  everyThreeDays,
  weekly,
  biweekly,
  monthly,
  custom;

  String get displayName {
    switch (this) {
      case RepeatFrequency.daily:
        return 'Daily';
      case RepeatFrequency.everyOtherDay:
        return 'Every 2 days';
      case RepeatFrequency.everyThreeDays:
        return 'Every 3 days';
      case RepeatFrequency.weekly:
        return 'Weekly';
      case RepeatFrequency.biweekly:
        return 'Every 2 weeks';
      case RepeatFrequency.monthly:
        return 'Monthly';
      case RepeatFrequency.custom:
        return 'Custom';
    }
  }

  int get intervalDays {
    switch (this) {
      case RepeatFrequency.daily:
        return 1;
      case RepeatFrequency.everyOtherDay:
        return 2;
      case RepeatFrequency.everyThreeDays:
        return 3;
      case RepeatFrequency.weekly:
        return 7;
      case RepeatFrequency.biweekly:
        return 14;
      case RepeatFrequency.monthly:
        return 30;
      case RepeatFrequency.custom:
        return 1; // Will use customIntervalDays instead
    }
  }
}

/// 10 preset icons for templates and collections
enum TemplateIcon {
  dumbbell,
  barbell,
  kettlebell,
  running,
  heart,
  fire,
  lightning,
  target,
  trophy,
  star;

  String get iconName {
    switch (this) {
      case TemplateIcon.dumbbell:
        return 'dumbbell';
      case TemplateIcon.barbell:
        return 'barbell';
      case TemplateIcon.kettlebell:
        return 'kettlebell';
      case TemplateIcon.running:
        return 'person-simple-run';
      case TemplateIcon.heart:
        return 'heart';
      case TemplateIcon.fire:
        return 'fire';
      case TemplateIcon.lightning:
        return 'lightning';
      case TemplateIcon.target:
        return 'target';
      case TemplateIcon.trophy:
        return 'trophy';
      case TemplateIcon.star:
        return 'star';
    }
  }

  String get displayName {
    switch (this) {
      case TemplateIcon.dumbbell:
        return 'Dumbbell';
      case TemplateIcon.barbell:
        return 'Barbell';
      case TemplateIcon.kettlebell:
        return 'Kettlebell';
      case TemplateIcon.running:
        return 'Running';
      case TemplateIcon.heart:
        return 'Heart';
      case TemplateIcon.fire:
        return 'Fire';
      case TemplateIcon.lightning:
        return 'Lightning';
      case TemplateIcon.target:
        return 'Target';
      case TemplateIcon.trophy:
        return 'Trophy';
      case TemplateIcon.star:
        return 'Star';
    }
  }
}

/// Schedule configuration for a workout template
class WorkoutSchedule {
  final RepeatFrequency frequency;
  final int? customIntervalDays; // Used when frequency is custom
  final List<int>? weekDays; // 1-7 for Mon-Sun, used for weekly schedules
  final DateTime? startDate;
  final DateTime? endDate;
  final bool hasReminder;
  final DateTime? reminderTime; // Time of day for reminder
  final bool isActive;

  WorkoutSchedule({
    required this.frequency,
    this.customIntervalDays,
    this.weekDays,
    this.startDate,
    this.endDate,
    this.hasReminder = false,
    this.reminderTime,
    this.isActive = true,
  });

  Map<String, dynamic> toMap() {
    return {
      'frequency': frequency.name,
      'customIntervalDays': customIntervalDays,
      'weekDays': weekDays,
      'startDate': startDate?.toIso8601String(),
      'endDate': endDate?.toIso8601String(),
      'hasReminder': hasReminder,
      'reminderTime': reminderTime?.toIso8601String(),
      'isActive': isActive,
    };
  }

  factory WorkoutSchedule.fromMap(Map<String, dynamic> map) {
    return WorkoutSchedule(
      frequency: RepeatFrequency.values.firstWhere(
        (e) => e.name == map['frequency'],
        orElse: () => RepeatFrequency.weekly,
      ),
      customIntervalDays: map['customIntervalDays'],
      weekDays: map['weekDays'] != null ? List<int>.from(map['weekDays']) : null,
      startDate: map['startDate'] != null ? DateTime.parse(map['startDate']) : null,
      endDate: map['endDate'] != null ? DateTime.parse(map['endDate']) : null,
      hasReminder: map['hasReminder'] ?? false,
      reminderTime: map['reminderTime'] != null ? DateTime.parse(map['reminderTime']) : null,
      isActive: map['isActive'] ?? true,
    );
  }

  WorkoutSchedule copyWith({
    RepeatFrequency? frequency,
    int? customIntervalDays,
    List<int>? weekDays,
    DateTime? startDate,
    DateTime? endDate,
    bool? hasReminder,
    DateTime? reminderTime,
    bool? isActive,
  }) {
    return WorkoutSchedule(
      frequency: frequency ?? this.frequency,
      customIntervalDays: customIntervalDays ?? this.customIntervalDays,
      weekDays: weekDays ?? this.weekDays,
      startDate: startDate ?? this.startDate,
      endDate: endDate ?? this.endDate,
      hasReminder: hasReminder ?? this.hasReminder,
      reminderTime: reminderTime ?? this.reminderTime,
      isActive: isActive ?? this.isActive,
    );
  }

  /// Get the next scheduled date from a given date
  DateTime? getNextScheduledDate(DateTime from) {
    if (!isActive) return null;
    if (endDate != null && from.isAfter(endDate!)) return null;

    DateTime next = from;
    
    if (startDate != null && from.isBefore(startDate!)) {
      next = startDate!;
    }

    switch (frequency) {
      case RepeatFrequency.daily:
      case RepeatFrequency.everyOtherDay:
      case RepeatFrequency.everyThreeDays:
      case RepeatFrequency.biweekly:
      case RepeatFrequency.monthly:
        next = next.add(Duration(days: frequency.intervalDays));
        break;
      case RepeatFrequency.weekly:
        if (weekDays != null && weekDays!.isNotEmpty) {
          // Find next weekday in the list
          int currentWeekday = next.weekday;
          int? nextWeekday;
          for (int day in weekDays!..sort()) {
            if (day > currentWeekday) {
              nextWeekday = day;
              break;
            }
          }
          if (nextWeekday != null) {
            next = next.add(Duration(days: nextWeekday - currentWeekday));
          } else {
            // Move to next week, first scheduled day
            next = next.add(Duration(days: 7 - currentWeekday + weekDays!.first));
          }
        } else {
          next = next.add(const Duration(days: 7));
        }
        break;
      case RepeatFrequency.custom:
        next = next.add(Duration(days: customIntervalDays ?? 1));
        break;
    }

    if (endDate != null && next.isAfter(endDate!)) return null;
    return next;
  }
}

/// Exercise within a template (simplified version without tracking data)
class TemplateExercise {
  final String id;
  final String name;
  final String? notes;
  final int targetSets;
  final int? targetReps;
  final double? targetWeight;
  final int? restSeconds;

  TemplateExercise({
    required this.id,
    required this.name,
    this.notes,
    this.targetSets = 3,
    this.targetReps,
    this.targetWeight,
    this.restSeconds,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'name': name,
      'notes': notes,
      'targetSets': targetSets,
      'targetReps': targetReps,
      'targetWeight': targetWeight,
      'restSeconds': restSeconds,
    };
  }

  factory TemplateExercise.fromMap(Map<String, dynamic> map) {
    return TemplateExercise(
      id: map['id'] ?? '',
      name: map['name'] ?? '',
      notes: map['notes'],
      targetSets: map['targetSets'] ?? 3,
      targetReps: map['targetReps'],
      targetWeight: map['targetWeight']?.toDouble(),
      restSeconds: map['restSeconds'],
    );
  }

  TemplateExercise copyWith({
    String? id,
    String? name,
    String? notes,
    int? targetSets,
    int? targetReps,
    double? targetWeight,
    int? restSeconds,
  }) {
    return TemplateExercise(
      id: id ?? this.id,
      name: name ?? this.name,
      notes: notes ?? this.notes,
      targetSets: targetSets ?? this.targetSets,
      targetReps: targetReps ?? this.targetReps,
      targetWeight: targetWeight ?? this.targetWeight,
      restSeconds: restSeconds ?? this.restSeconds,
    );
  }
}

/// Workout template that can be saved and reused
class WorkoutTemplate {
  final String id;
  final String userId;
  final String name;
  final String? description;
  final TemplateIcon icon;
  final List<TemplateExercise> exercises;
  final WorkoutSchedule? schedule;
  final String? collectionId; // Which collection this template belongs to
  final DateTime createdAt;
  final DateTime updatedAt;
  final int timesUsed;

  WorkoutTemplate({
    required this.id,
    required this.userId,
    required this.name,
    this.description,
    this.icon = TemplateIcon.dumbbell,
    this.exercises = const [],
    this.schedule,
    this.collectionId,
    DateTime? createdAt,
    DateTime? updatedAt,
    this.timesUsed = 0,
  })  : createdAt = createdAt ?? DateTime.now(),
        updatedAt = updatedAt ?? DateTime.now();

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'userId': userId,
      'name': name,
      'description': description,
      'icon': icon.name,
      'exercises': exercises.map((e) => e.toMap()).toList(),
      'schedule': schedule?.toMap(),
      'collectionId': collectionId,
      'createdAt': Timestamp.fromDate(createdAt),
      'updatedAt': Timestamp.fromDate(updatedAt),
      'timesUsed': timesUsed,
    };
  }

  factory WorkoutTemplate.fromMap(Map<String, dynamic> map) {
    return WorkoutTemplate(
      id: map['id'] ?? '',
      userId: map['userId'] ?? '',
      name: map['name'] ?? '',
      description: map['description'],
      icon: TemplateIcon.values.firstWhere(
        (e) => e.name == map['icon'],
        orElse: () => TemplateIcon.dumbbell,
      ),
      exercises: (map['exercises'] as List<dynamic>?)
              ?.map((e) => TemplateExercise.fromMap(e as Map<String, dynamic>))
              .toList() ??
          [],
      schedule: map['schedule'] != null
          ? WorkoutSchedule.fromMap(map['schedule'] as Map<String, dynamic>)
          : null,
      collectionId: map['collectionId'],
      createdAt: map['createdAt'] is Timestamp
          ? (map['createdAt'] as Timestamp).toDate()
          : DateTime.parse(map['createdAt'] ?? DateTime.now().toIso8601String()),
      updatedAt: map['updatedAt'] is Timestamp
          ? (map['updatedAt'] as Timestamp).toDate()
          : DateTime.parse(map['updatedAt'] ?? DateTime.now().toIso8601String()),
      timesUsed: map['timesUsed'] ?? 0,
    );
  }

  WorkoutTemplate copyWith({
    String? id,
    String? userId,
    String? name,
    String? description,
    TemplateIcon? icon,
    List<TemplateExercise>? exercises,
    WorkoutSchedule? schedule,
    String? collectionId,
    DateTime? createdAt,
    DateTime? updatedAt,
    int? timesUsed,
  }) {
    return WorkoutTemplate(
      id: id ?? this.id,
      userId: userId ?? this.userId,
      name: name ?? this.name,
      description: description ?? this.description,
      icon: icon ?? this.icon,
      exercises: exercises ?? this.exercises,
      schedule: schedule ?? this.schedule,
      collectionId: collectionId ?? this.collectionId,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? DateTime.now(),
      timesUsed: timesUsed ?? this.timesUsed,
    );
  }
}

/// Collection of workout templates (folder)
class TemplateCollection {
  final String id;
  final String userId;
  final String name;
  final String? description;
  final TemplateIcon icon;
  final DateTime createdAt;
  final DateTime updatedAt;
  final int templateCount;

  TemplateCollection({
    required this.id,
    required this.userId,
    required this.name,
    this.description,
    this.icon = TemplateIcon.dumbbell,
    DateTime? createdAt,
    DateTime? updatedAt,
    this.templateCount = 0,
  })  : createdAt = createdAt ?? DateTime.now(),
        updatedAt = updatedAt ?? DateTime.now();

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'userId': userId,
      'name': name,
      'description': description,
      'icon': icon.name,
      'createdAt': Timestamp.fromDate(createdAt),
      'updatedAt': Timestamp.fromDate(updatedAt),
      'templateCount': templateCount,
    };
  }

  factory TemplateCollection.fromMap(Map<String, dynamic> map) {
    return TemplateCollection(
      id: map['id'] ?? '',
      userId: map['userId'] ?? '',
      name: map['name'] ?? '',
      description: map['description'],
      icon: TemplateIcon.values.firstWhere(
        (e) => e.name == map['icon'],
        orElse: () => TemplateIcon.dumbbell,
      ),
      createdAt: map['createdAt'] is Timestamp
          ? (map['createdAt'] as Timestamp).toDate()
          : DateTime.parse(map['createdAt'] ?? DateTime.now().toIso8601String()),
      updatedAt: map['updatedAt'] is Timestamp
          ? (map['updatedAt'] as Timestamp).toDate()
          : DateTime.parse(map['updatedAt'] ?? DateTime.now().toIso8601String()),
      templateCount: map['templateCount'] ?? 0,
    );
  }

  TemplateCollection copyWith({
    String? id,
    String? userId,
    String? name,
    String? description,
    TemplateIcon? icon,
    DateTime? createdAt,
    DateTime? updatedAt,
    int? templateCount,
  }) {
    return TemplateCollection(
      id: id ?? this.id,
      userId: userId ?? this.userId,
      name: name ?? this.name,
      description: description ?? this.description,
      icon: icon ?? this.icon,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? DateTime.now(),
      templateCount: templateCount ?? this.templateCount,
    );
  }
}
