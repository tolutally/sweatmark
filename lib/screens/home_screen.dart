import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';
import 'package:table_calendar/table_calendar.dart';
import '../services/firebase_service.dart';
import '../state/workout_notifier.dart';
import '../state/recovery_notifier.dart';
import '../state/template_notifier.dart';
import '../models/template_model.dart';
import '../theme/app_theme.dart';
import 'active_workout_screen.dart';
import 'library_screen.dart';
import 'workout_history_screen.dart';
import 'notifications_screen.dart';
import 'collection_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  DateTime _focusedDay = DateTime.now();
  DateTime _selectedDay = DateTime.now();
  CalendarFormat _calendarFormat = CalendarFormat.week;
  bool _initializedTemplates = false;
  Set<int> _scheduledWeekdays = {};
  String _reminderOption = 'None';
  bool _isLoadingSchedule = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_initializedTemplates) return;
    final auth = context.read<AuthNotifier>();
    final templateNotifier = context.read<TemplateNotifier>();
    final firebaseService = context.read<FirebaseService>();
    final userId = auth.user?.uid;
    if (userId != null) {
      templateNotifier.initialize(userId);
      _initializedTemplates = true;
      _loadScheduleFromCloud(firebaseService, userId);
    }
  }

  Future<void> _loadScheduleFromCloud(
    FirebaseService firebaseService,
    String userId,
  ) async {
    setState(() => _isLoadingSchedule = true);
    final data = await firebaseService.getUserSchedule(userId);
    if (data != null) {
      final weekdays = (data['weekdays'] as List?)
              ?.map((e) => int.tryParse('$e'))
              .whereType<int>()
              .toSet() ??
          {};
      final reminder = data['reminder'] as String? ?? 'None';
      setState(() {
        _scheduledWeekdays = weekdays;
        _reminderOption = reminder;
      });
    }
    setState(() => _isLoadingSchedule = false);
  }

  Future<void> _saveScheduleToCloud() async {
    final userId = context.read<AuthNotifier>().user?.uid;
    if (userId == null) return;
    final firebaseService = context.read<FirebaseService>();
    await firebaseService.setUserSchedule(userId, {
      'weekdays': _scheduledWeekdays.toList(),
      'reminder': _reminderOption,
      'updatedAt': Timestamp.now(),
    });
  }

  void _showScheduleModal() {
    final userId = context.read<AuthNotifier>().user?.uid;
    if (userId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please sign in to schedule workouts'),
          backgroundColor: AppColors.error,
        ),
      );
      return;
    }

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (sheetContext) {
        final tempWeekdays = Set<int>.from(_scheduledWeekdays);
        String tempReminder = _reminderOption;

        return StatefulBuilder(
          builder: (context, setSheetState) => SafeArea(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text(
                        'Schedule workouts',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      IconButton(
                        icon: const Icon(PhosphorIconsRegular.x),
                        onPressed: () => Navigator.pop(sheetContext),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  const Text(
                    'Pick your training days',
                    style: TextStyle(color: Colors.black54, fontSize: 13),
                  ),
                  const SizedBox(height: 12),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: List.generate(7, (index) {
                      final weekday = index + 1; // 1=Mon
                      const labels = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
                      final isSelected = tempWeekdays.contains(weekday);
                      return ChoiceChip(
                        label: Text(labels[index]),
                        selected: isSelected,
                        onSelected: (selected) {
                          setSheetState(() {
                            if (selected) {
                              tempWeekdays.add(weekday);
                            } else {
                              tempWeekdays.remove(weekday);
                            }
                          });
                        },
                        selectedColor: AppColors.brandCoral.withOpacity(0.2),
                        labelStyle: TextStyle(
                          color:
                              isSelected ? AppColors.brandCoral : AppColors.neutral900,
                          fontWeight: FontWeight.w600,
                        ),
                        backgroundColor: AppColors.neutral100,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10),
                          side: BorderSide(
                            color: isSelected
                                ? AppColors.brandCoral
                                : AppColors.neutral200,
                          ),
                        ),
                      );
                    }),
                  ),
                  const SizedBox(height: 16),
                  const Text(
                    'Reminder',
                    style: TextStyle(fontWeight: FontWeight.w600),
                  ),
                  const SizedBox(height: 8),
                  DropdownButtonFormField<String>(
                    value: tempReminder,
                    decoration: InputDecoration(
                      contentPadding:
                          const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(10),
                        borderSide: const BorderSide(color: AppColors.neutral200),
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(10),
                        borderSide: const BorderSide(color: AppColors.neutral200),
                      ),
                    ),
                    items: const [
                      DropdownMenuItem(value: 'None', child: Text('None')),
                      DropdownMenuItem(value: '1 day before', child: Text('1 day before')),
                      DropdownMenuItem(value: '12 hours before', child: Text('12 hours before')),
                      DropdownMenuItem(value: '6 hours before', child: Text('6 hours before')),
                      DropdownMenuItem(value: '1 hour before', child: Text('1 hour before')),
                    ],
                    onChanged: (value) {
                      if (value != null) {
                        setSheetState(() => tempReminder = value);
                      }
                    },
                  ),
                  const SizedBox(height: 20),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: () {
                        setState(() {
                          _scheduledWeekdays = tempWeekdays;
                          _reminderOption = tempReminder;
                        });
                        _saveScheduleToCloud();
                        Navigator.pop(sheetContext);
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.brandCoral,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      child: const Text('Save schedule'),
                    ),
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    'Reminders will respect your OS notification settings.',
                    style: TextStyle(color: Colors.black45, fontSize: 12),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final workoutNotifier = context.watch<WorkoutNotifier>();
    final recoveryNotifier = context.watch<RecoveryNotifier>();

    return Scaffold(
      backgroundColor: const Color(0xFFF5F5F5),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Header with date
                  Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'November 24',
                        style: TextStyle(
                          fontSize: 13,
                          color: Colors.black38,
                        ),
                      ),
                      SizedBox(height: 4),
                      Text(
                        'Today',
                        style: TextStyle(
                          fontSize: 34,
                          fontWeight: FontWeight.bold,
                          color: Colors.black,
                        ),
                      ),
                    ],
                  ),
                  Stack(
                    clipBehavior: Clip.none,
                    children: [
                      IconButton(
                        icon: const Icon(
                          PhosphorIconsRegular.bell,
                          color: AppColors.neutral800,
                        ),
                        onPressed: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) => const NotificationsScreen(),
                            ),
                          );
                        },
                      ),
                      Positioned(
                        right: 8,
                        top: 8,
                        child: Container(
                          width: 8,
                          height: 8,
                          decoration: const BoxDecoration(
                            color: AppColors.error,
                            shape: BoxShape.circle,
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),

              const SizedBox(height: 24),

              // Streak Cards
              const Row(
                children: [
                  Expanded(
                    child: _StreakCard(
                      count: '0',
                      label: 'Day Streak',
                      icon: PhosphorIconsBold.fire,
                    ),
                  ),
                  SizedBox(width: 12),
                  Expanded(
                    child: _StreakCard(
                      count: '1',
                      label: 'Flame',
                      icon: PhosphorIconsBold.flame,
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 24),

              // Calendar Week View
              Container(
                padding: const EdgeInsets.symmetric(vertical: 8),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(16),
                ),
                child: TableCalendar(
                  firstDay: DateTime.utc(2020, 1, 1),
                  lastDay: DateTime.utc(2030, 12, 31),
                  focusedDay: _focusedDay,
                  selectedDayPredicate: (day) => isSameDay(_selectedDay, day),
                  calendarFormat: _calendarFormat,
                  onDaySelected: (selectedDay, focusedDay) {
                    setState(() {
                      _selectedDay = selectedDay;
                      _focusedDay = focusedDay;
                    });
                  },
                  onFormatChanged: (format) {
                    setState(() {
                      _calendarFormat = format;
                    });
                  },
                  onPageChanged: (focusedDay) {
                    _focusedDay = focusedDay;
                  },
                  headerStyle: HeaderStyle(
                    formatButtonVisible: true,
                    titleCentered: false,
                    formatButtonShowsNext: false,
                    formatButtonDecoration: BoxDecoration(
                      color: const Color(0xFFF5F5F5),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    formatButtonTextStyle: const TextStyle(
                      color: Colors.black87,
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                    ),
                    titleTextStyle: const TextStyle(
                      color: Colors.black87,
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                    ),
                    leftChevronIcon: const Icon(
                      PhosphorIconsRegular.caretLeft,
                      color: Colors.black87,
                      size: 20,
                    ),
                    rightChevronIcon: const Icon(
                      PhosphorIconsRegular.caretRight,
                      color: Colors.black87,
                      size: 20,
                    ),
                  ),
                  calendarStyle: const CalendarStyle(
                    defaultTextStyle: TextStyle(color: Colors.black87),
                    weekendTextStyle: TextStyle(color: Colors.black87),
                    outsideDaysVisible: false,
                    selectedDecoration: BoxDecoration(
                      color: AppColors.brandCoral,
                      shape: BoxShape.circle,
                    ),
                    todayDecoration: BoxDecoration(
                      color: AppColors.brandCoralSoft,
                      shape: BoxShape.circle,
                    ),
                    selectedTextStyle: TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                    ),
                    todayTextStyle: TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                    ),
                    markersAlignment: Alignment.bottomCenter,
                  ),
                  daysOfWeekStyle: const DaysOfWeekStyle(
                    weekdayStyle: TextStyle(
                      color: Colors.black54,
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                    ),
                    weekendStyle: TextStyle(
                      color: Colors.black54,
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  eventLoader: (day) =>
                      _scheduledWeekdays.contains(day.weekday) ? ['scheduled'] : [],
                  calendarBuilders: CalendarBuilders(
                    defaultBuilder: (context, day, focusedDay) {
                      final isScheduled = _scheduledWeekdays.contains(day.weekday);
                      return Center(
                        child: Text(
                          '${day.day}',
                          style: TextStyle(
                            color: Colors.black87,
                            fontWeight:
                                isScheduled ? FontWeight.w700 : FontWeight.w400,
                          ),
                        ),
                      );
                    },
                    todayBuilder: (context, day, focusedDay) {
                      final isScheduled = _scheduledWeekdays.contains(day.weekday);
                      return Container(
                        decoration: const BoxDecoration(
                          color: AppColors.brandCoralSoft,
                          shape: BoxShape.circle,
                        ),
                        alignment: Alignment.center,
                        child: Text(
                          '${day.day}',
                          style: TextStyle(
                            color: Colors.white,
                            fontWeight:
                                isScheduled ? FontWeight.w800 : FontWeight.w700,
                          ),
                        ),
                      );
                    },
                    selectedBuilder: (context, day, focusedDay) {
                      final isScheduled = _scheduledWeekdays.contains(day.weekday);
                      return Container(
                        decoration: const BoxDecoration(
                          color: AppColors.brandCoral,
                          shape: BoxShape.circle,
                        ),
                        alignment: Alignment.center,
                        child: Text(
                          '${day.day}',
                          style: TextStyle(
                            color: Colors.white,
                            fontWeight:
                                isScheduled ? FontWeight.w800 : FontWeight.w700,
                          ),
                        ),
                      );
                    },
                    markerBuilder: (context, day, events) {
                      if (events.isEmpty) return const SizedBox.shrink();
                      return Positioned(
                        bottom: 6,
                        child: Container(
                          width: 6,
                          height: 6,
                          decoration: const BoxDecoration(
                            color: AppColors.brandCoral,
                            shape: BoxShape.circle,
                          ),
                        ),
                      );
                    },
                  ),
                ),
              ),

              const SizedBox(height: 12),
              SizedBox(
                width: double.infinity,
                child: OutlinedButton.icon(
                  onPressed: _showScheduleModal,
                  icon: const Icon(PhosphorIconsRegular.calendarPlus,
                      color: AppColors.brandCoral),
                  label: const Text(
                    'Schedule workouts',
                    style: TextStyle(color: AppColors.brandCoral),
                  ),
                  style: OutlinedButton.styleFrom(
                    side: const BorderSide(color: AppColors.brandCoral),
                    padding: const EdgeInsets.symmetric(vertical: 12),
                  ),
                ),
              ),

              const SizedBox(height: 24),

              // Search Bar
              GestureDetector(
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => const LibraryScreen(isPicker: false),
                    ),
                  );
                },
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Row(
                    children: [
                      Icon(PhosphorIconsRegular.magnifyingGlass, color: Colors.black38),
                      SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          'Search exercises, workouts...',
                          style: TextStyle(color: Colors.black38, fontSize: 15),
                        ),
                      ),
                    ],
                  ),
                ),
              ),

              const SizedBox(height: 24),

              // Resume Draft Workout Banner (if exists)
              FutureBuilder<bool>(
                future: workoutNotifier.hasDraftWorkout(),
                builder: (context, snapshot) {
                  if (snapshot.data == true) {
                    return Column(
                      children: [
                        GestureDetector(
                          onTap: () async {
                            await workoutNotifier.loadDraftWorkout();
                            if (!context.mounted) return;
                            Navigator.push(
                              context,
                              MaterialPageRoute(builder: (_) => const ActiveWorkoutScreen()),
                            );
                          },
                          child: Container(
                            padding: const EdgeInsets.all(20),
                            decoration: BoxDecoration(
                              color: const Color(0xFFFFF8E1),
                              borderRadius: BorderRadius.circular(16),
                              border: Border.all(
                                color: AppColors.warning.withValues(alpha: 0.3),
                                width: 2,
                              ),
                            ),
                            child: Row(
                              children: [
                                Container(
                                  width: 48,
                                  height: 48,
                                  decoration: BoxDecoration(
                                    color: AppColors.warning.withValues(alpha: 0.2),
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                  child: const Icon(
                                    PhosphorIconsBold.clockCounterClockwise,
                                    color: AppColors.warning,
                                    size: 24,
                                  ),
                                ),
                                const SizedBox(width: 16),
                                const Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        'Resume Workout',
                                        style: TextStyle(
                                          fontSize: 17,
                                          fontWeight: FontWeight.bold,
                                          color: Colors.black87,
                                        ),
                                      ),
                                      SizedBox(height: 4),
                                      Text(
                                        'Continue your saved workout',
                                        style: TextStyle(
                                          fontSize: 14,
                                          color: Colors.black54,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                const Icon(
                                  PhosphorIconsRegular.caretRight,
                                  color: AppColors.warning,
                                  size: 24,
                                ),
                              ],
                            ),
                          ),
                        ),
                        const SizedBox(height: 16),
                      ],
                    );
                  }
                  return const SizedBox.shrink();
                },
              ),

              // Start Workout Card
              GestureDetector(
                onTap: () {
                  workoutNotifier.startWorkout();
                  Navigator.push(
                    context,
                    MaterialPageRoute(builder: (_) => const ActiveWorkoutScreen()),
                  );
                },
                child: Container(
                  padding: const EdgeInsets.all(24),
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      colors: [AppColors.brandCoral, AppColors.info],
                    ),
                    borderRadius: BorderRadius.circular(20),
                    boxShadow: [
                      BoxShadow(
                        color: AppColors.brandCoral.withValues(alpha: 0.3),
                        blurRadius: 20,
                        offset: const Offset(0, 8),
                      ),
                    ],
                  ),
                  child: Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.2),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: const Icon(
                          PhosphorIconsBold.play,
                          color: Colors.white,
                          size: 32,
                        ),
                      ),
                      const SizedBox(width: 16),
                      const Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Start Workout',
                              style: TextStyle(
                                fontSize: 22,
                                fontWeight: FontWeight.bold,
                                color: Colors.white,
                              ),
                            ),
                            SizedBox(height: 4),
                            Text(
                              'Begin your training session',
                              style: TextStyle(
                                fontSize: 14,
                                color: Colors.white70,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const Icon(
                        PhosphorIconsRegular.arrowRight,
                        color: Colors.white,
                      ),
                    ],
                  ),
                ),
              ),

              const SizedBox(height: 16),

              // Build For Me Button
              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: AppColors.brandCoral.withValues(alpha: 0.3)),
                ),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: AppColors.brandCoral.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: const Icon(
                        PhosphorIconsBold.sparkle,
                        color: AppColors.brandCoral,
                        size: 24,
                      ),
                    ),
                    const SizedBox(width: 16),
                    const Expanded(
                      child: Text(
                        'Build For Me',
                        style: TextStyle(
                          fontSize: 17,
                          fontWeight: FontWeight.w600,
                          color: Colors.black,
                        ),
                      ),
                    ),
                    const Icon(
                      PhosphorIconsRegular.arrowRight,
                      color: Colors.black38,
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 24),

              // Recovery Status
              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [
                      AppColors.error.withValues(alpha: 0.1),
                      AppColors.warning.withValues(alpha: 0.1),
                    ],
                  ),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Row(
                      children: [
                        Icon(
                          PhosphorIconsBold.heartbeat,
                          color: AppColors.error,
                          size: 24,
                        ),
                        SizedBox(width: 8),
                        Text(
                          'Recovery Status',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            color: Colors.black,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    Text(
                      recoveryNotifier.muscleStatus.isEmpty
                          ? 'All muscles recovered'
                          : 'Some muscles recovering',
                      style: const TextStyle(
                        fontSize: 15,
                        color: Colors.black54,
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 24),

              // My Collection
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text(
                    'My Collections',
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                      color: Colors.black,
                    ),
                  ),
                  TextButton(
                    onPressed: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => const WorkoutHistoryScreen(),
                        ),
                      );
                    },
                    child: const Text(
                      'See All',
                      style: TextStyle(color: AppColors.brandCoral),
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 12),

              // Template Collections Grid
              Consumer<TemplateNotifier>(
                builder: (context, templateNotifier, _) {
                  final collections = templateNotifier.collections;
                  final uncategorizedTemplates = templateNotifier.uncategorizedTemplates;

                  if (collections.isEmpty && uncategorizedTemplates.isEmpty) {
                    return const Center(
                      child: Padding(
                        padding: EdgeInsets.all(32),
                        child: Column(
                          children: [
                            Icon(
                              PhosphorIconsRegular.folder,
                              size: 64,
                              color: Colors.black26,
                            ),
                            SizedBox(height: 16),
                            Text(
                              'No saved templates',
                              style: TextStyle(
                                fontSize: 16,
                                color: Colors.black38,
                              ),
                            ),
                            SizedBox(height: 8),
                            Text(
                              'Save workouts as templates to see them here',
                              style: TextStyle(
                                fontSize: 14,
                                color: Colors.black26,
                              ),
                              textAlign: TextAlign.center,
                            ),
                          ],
                        ),
                      ),
                    );
                  }

                  return GridView.builder(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                      crossAxisCount: 2,
                      mainAxisSpacing: 12,
                      crossAxisSpacing: 12,
                      childAspectRatio: 1.3,
                    ),
                    itemCount: collections.length + (uncategorizedTemplates.isNotEmpty ? 1 : 0),
                    itemBuilder: (context, index) {
                      // Uncategorized templates folder
                      if (index == 0 && uncategorizedTemplates.isNotEmpty) {
                        return _CollectionCard(
                          name: 'Uncategorized',
                          templateCount: uncategorizedTemplates.length,
                          icon: TemplateIcon.dumbbell,
                          onTap: () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (_) => const CollectionScreen(
                                  collectionId: null,
                                  collectionName: 'Uncategorized',
                                ),
                              ),
                            );
                          },
                        );
                      }

                      final adjustedIndex = uncategorizedTemplates.isNotEmpty ? index - 1 : index;
                      final collection = collections[adjustedIndex];

                      return _CollectionCard(
                        name: collection.name,
                        templateCount: collection.templateCount,
                        icon: collection.icon,
                        onTap: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) => CollectionScreen(
                                collectionId: collection.id,
                                collectionName: collection.name,
                              ),
                            ),
                          );
                        },
                      );
                    },
                  );
                },
              ),

              const SizedBox(height: 24),

              // Recent Workouts History
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text(
                    'Recent Workouts',
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                      color: Colors.black,
                    ),
                  ),
                  TextButton(
                    onPressed: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => const WorkoutHistoryScreen(),
                        ),
                      );
                    },
                    child: const Text(
                      'See All',
                      style: TextStyle(color: AppColors.brandCoral),
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 12),

              // Collection Items
              if (workoutNotifier.workoutHistory.isEmpty)
                const Center(
                  child: Padding(
                    padding: EdgeInsets.all(32),
                    child: Column(
                      children: [
                        Icon(
                          PhosphorIconsRegular.clockCounterClockwise,
                          size: 48,
                          color: Colors.black26,
                        ),
                        SizedBox(height: 12),
                        Text(
                          'No workout history yet',
                          style: TextStyle(
                            fontSize: 15,
                            color: Colors.black38,
                          ),
                        ),
                      ],
                    ),
                  ),
                )
              else
                ...workoutNotifier.workoutHistory.take(3).map<Widget>((workout) {
                  return Container(
                    margin: const EdgeInsets.only(bottom: 12),
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: const Color(0xFFF5F5F5),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: const Icon(
                            PhosphorIconsBold.barbell,
                            size: 24,
                            color: AppColors.brandCoral,
                          ),
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text(
                                'Workout',
                                style: TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.w600,
                                  color: Colors.black,
                                ),
                              ),
                              Text(
                                '${workout.exercises.length} exercises • ${workout.durationSeconds ~/ 60}m',
                                style: const TextStyle(
                                  fontSize: 14,
                                  color: Colors.black54,
                                ),
                              ),
                            ],
                          ),
                        ),
                        const Icon(
                          PhosphorIconsRegular.dotsThreeVertical,
                          color: Colors.black38,
                        ),
                      ],
                    ),
                  );
                }),
            ],
          ),
        ),
      ),
    );
  }
}

class _CollectionCard extends StatelessWidget {
  final String name;
  final int templateCount;
  final TemplateIcon icon;
  final VoidCallback onTap;

  const _CollectionCard({
    required this.name,
    required this.templateCount,
    required this.icon,
    required this.onTap,
  });

  IconData _getPhosphorIcon(TemplateIcon icon) {
    switch (icon) {
      case TemplateIcon.dumbbell:
        return PhosphorIcons.barbell(PhosphorIconsStyle.fill);
      case TemplateIcon.barbell:
        return PhosphorIcons.barbell(PhosphorIconsStyle.bold);
      case TemplateIcon.kettlebell:
        return PhosphorIcons.personSimpleRun(PhosphorIconsStyle.fill);
      case TemplateIcon.running:
        return PhosphorIcons.personSimpleRun(PhosphorIconsStyle.fill);
      case TemplateIcon.heart:
        return PhosphorIcons.heart(PhosphorIconsStyle.fill);
      case TemplateIcon.fire:
        return PhosphorIcons.fire(PhosphorIconsStyle.fill);
      case TemplateIcon.lightning:
        return PhosphorIcons.lightning(PhosphorIconsStyle.fill);
      case TemplateIcon.target:
        return PhosphorIcons.target(PhosphorIconsStyle.fill);
      case TemplateIcon.trophy:
        return PhosphorIcons.trophy(PhosphorIconsStyle.fill);
      case TemplateIcon.star:
        return PhosphorIcons.star(PhosphorIconsStyle.fill);
    }
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.05),
              blurRadius: 10,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: AppColors.brandCoral.withOpacity(0.1),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(
                _getPhosphorIcon(icon),
                color: AppColors.brandCoral,
                size: 22,
              ),
            ),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  name,
                  style: const TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                    color: Colors.black87,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 2),
                Text(
                  '$templateCount template${templateCount != 1 ? 's' : ''}',
                  style: const TextStyle(
                    fontSize: 12,
                    color: Colors.black45,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _StreakCard extends StatelessWidget {
  final String count;
  final String label;
  final IconData icon;

  const _StreakCard({
    required this.count,
    required this.label,
    required this.icon,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: AppColors.warning.withValues(alpha: 0.1),
              shape: BoxShape.circle,
            ),
            child: Icon(icon, color: AppColors.warning, size: 20),
          ),
          const SizedBox(width: 12),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                count,
                style: const TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                  color: Colors.black,
                ),
              ),
              Text(
                label,
                style: const TextStyle(
                  fontSize: 12,
                  color: Colors.black38,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
