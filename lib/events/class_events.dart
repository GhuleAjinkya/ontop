import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'dart:ui';
import 'package:mongo_dart/mongo_dart.dart' show ObjectId;
import '../shared/mongodb.dart';
import '../shared/user_session.dart';
import 'event.dart';

class Events extends StatefulWidget {
  const Events({super.key});

  @override
  State<Events> createState() => _EventsState();
}

class _EventsState extends State<Events> {
  List<Event> allEvents = [];
  List<Event> filteredEvents = [];
  List<Event> upcomingEvents = [];
  List<Event> concludedEvents = [];
  String selectedFilter = 'All Events';
  String selectedTab = 'Upcoming'; // Add tab state
  bool isLoading = true;
  bool searching = false;
  String searchQuery = '';
  bool eventsInitialized = false;
  final TextEditingController searchController = TextEditingController();

  // Database helper methods
  Future<List<Event>> _getAllEvents() async {
    try {
      final userId = UserSession().userId;
      if (userId == null) return [];

      final List<Map<String, dynamic>> results =
          await MongoDatabase.getContacts(userId: userId, type: 'event');

      return results.map((eventDoc) => Event.fromMap(eventDoc)).toList();
    } catch (e) {
      print('Error fetching events: $e');
      return [];
    }
  }

  Future<bool> _createEvent(Event event) async {
    try {
      final userId = UserSession().userId;
      if (userId == null) return false;

      final eventData = event.toMap();
      return await MongoDatabase.insertData(
        eventData,
        userId: userId,
        type: 'event',
      );
    } catch (e) {
      print('Error creating event: $e');
      return false;
    }
  }

  Future<bool> _updateEvent(Event event) async {
    try {
      final userId = UserSession().userId;
      if (userId == null) return false;

      final eventData = event.toMap();
      return await MongoDatabase.updateData(
        eventData,
        userId: userId,
        type: 'event',
      );
    } catch (e) {
      print('Error updating event: $e');
      return false;
    }
  }

  Future<bool> _deleteEvent(ObjectId eventId) async {
    try {
      final userId = UserSession().userId;
      if (userId == null) return false;
      return await MongoDatabase.deleteData(eventId, userId: userId);
    } catch (e) {
      print('Error deleting event: $e');
      return false;
    }
  }

  Future<List<Event>> _getUpcomingEvents() async {
    try {
      final allEvents = await _getAllEvents();
      final now = DateTime.now();
      return allEvents.where((event) => event.dateTime.isAfter(now)).toList()
        ..sort((a, b) => a.dateTime.compareTo(b.dateTime));
    } catch (e) {
      print('Error fetching upcoming events: $e');
      return [];
    }
  }

  Future<List<Event>> _getConcludedEvents() async {
    try {
      final allEvents = await _getAllEvents();
      final now = DateTime.now();
      return allEvents.where((event) => event.dateTime.isBefore(now)).toList()
        ..sort((a, b) => b.dateTime.compareTo(a.dateTime));
    } catch (e) {
      print('Error fetching concluded events: $e');
      return [];
    }
  }

  List<Event> _getEventsThisMonth() {
    try {
      final now = DateTime.now();
      final startOfMonth = DateTime(now.year, now.month, 1);
      final endOfMonth = DateTime(now.year, now.month + 1, 0, 23, 59, 59);

      return allEvents
          .where(
            (event) =>
                event.dateTime.isAfter(
                  startOfMonth.subtract(Duration(seconds: 1)),
                ) &&
                event.dateTime.isBefore(endOfMonth.add(Duration(seconds: 1))),
          )
          .toList()
        ..sort((a, b) => a.dateTime.compareTo(b.dateTime));
    } catch (e) {
      print('Error filtering events this month: $e');
      return [];
    }
  }

  List<Event> _getEventsThisWeek() {
    try {
      final now = DateTime.now();
      final startOfWeek = DateTime(
        now.year,
        now.month,
        now.day - (now.weekday - 1),
      );
      final endOfWeek = DateTime(
        now.year,
        now.month,
        now.day - (now.weekday - 1) + 6,
        23,
        59,
        59,
      );

      return allEvents
          .where(
            (event) =>
                event.dateTime.isAfter(
                  startOfWeek.subtract(Duration(seconds: 1)),
                ) &&
                event.dateTime.isBefore(endOfWeek.add(Duration(seconds: 1))),
          )
          .toList()
        ..sort((a, b) => a.dateTime.compareTo(b.dateTime));
    } catch (e) {
      print('Error filtering events this week: $e');
      return [];
    }
  }

  @override
  void initState() {
    super.initState();
    _loadEvents();
    eventsInitialized = true;
  }

  Future<void> _loadEvents() async {
    setState(() => isLoading = true);
    print("load events called");
    try {
      final events = await _getAllEvents();
      final upcoming = await _getUpcomingEvents();
      final concluded = await _getConcludedEvents();

      setState(() {
        allEvents = events;
        upcomingEvents = upcoming;
        concludedEvents = concluded;
        // Initialize filteredEvents with all events by default
        filteredEvents = events;
        isLoading = false;
      });

      // Apply the current filter after loading events
      _applyFilter();
    } catch (e) {
      setState(() => isLoading = false);
      print('Error loading events: $e');
    }
  }

  void _applyFilter() {
    setState(() {
      List<Event> baseEvents;
      switch (selectedFilter) {
        case 'All Events':
          baseEvents = allEvents;
          break;
        case 'This Month':
          baseEvents = _getEventsThisMonth();
          break;
        case 'This Week':
          baseEvents = _getEventsThisWeek();
          break;
        default:
          baseEvents = allEvents;
          break;
      }

      // Apply search filter if searching
      if (searching && searchQuery.isNotEmpty) {
        filteredEvents =
            baseEvents.where((event) {
              final titleMatch = event.title.toLowerCase().contains(
                searchQuery.toLowerCase(),
              );
              final descriptionMatch = event.description.toLowerCase().contains(
                searchQuery.toLowerCase(),
              );
              return titleMatch || descriptionMatch;
            }).toList();
      } else {
        filteredEvents = baseEvents;
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      extendBodyBehindAppBar: false,
      backgroundColor: Theme.of(context).colorScheme.primary,
      body: SafeArea(
        child: Container(
          color: Theme.of(context).colorScheme.primary,
          child: Stack(
            children: [
              // ✨ COSMIC CONSTELLATION BLOBS ✨
              // Large mystical blob - top left like a moon
              Positioned(
                top: -40,
                left: -30,
                child: Container(
                  width: 180,
                  height: 220,
                  decoration: BoxDecoration(
                    color: Theme.of(
                      context,
                    ).colorScheme.secondary.withValues(alpha: 0.4),
                    borderRadius: BorderRadius.circular(110),
                  ),
                  child: BackdropFilter(
                    filter: ImageFilter.blur(sigmaX: 70, sigmaY: 80),
                    child: Container(color: Colors.transparent),
                  ),
                ),
              ),
              // Medium star blob - top right
              Positioned(
                top: 60,
                right: -20,
                child: Container(
                  width: 120,
                  height: 120,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: Theme.of(
                      context,
                    ).colorScheme.secondary.withValues(alpha: 0.5),
                  ),
                  child: BackdropFilter(
                    filter: ImageFilter.blur(sigmaX: 60, sigmaY: 60),
                    child: Container(color: Colors.transparent),
                  ),
                ),
              ),
              // Small twinkling blob - middle left
              Positioned(
                top: MediaQuery.of(context).size.height * 0.35,
                left: -15,
                child: Container(
                  width: 80,
                  height: 100,
                  decoration: BoxDecoration(
                    color: Theme.of(
                      context,
                    ).colorScheme.secondary.withValues(alpha: 0.6),
                    borderRadius: BorderRadius.circular(50),
                  ),
                  child: BackdropFilter(
                    filter: ImageFilter.blur(sigmaX: 45, sigmaY: 55),
                    child: Container(color: Colors.transparent),
                  ),
                ),
              ),
              // Dreamy medium blob - center right
              Positioned(
                top: MediaQuery.of(context).size.height * 0.5,
                right: -40,
                child: Container(
                  width: 160,
                  height: 140,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: Theme.of(
                      context,
                    ).colorScheme.secondary.withValues(alpha: 0.3),
                  ),
                  child: BackdropFilter(
                    filter: ImageFilter.blur(sigmaX: 85, sigmaY: 75),
                    child: Container(color: Colors.transparent),
                  ),
                ),
              ),
              // Floating bubble - bottom center
              Positioned(
                bottom: -50,
                left: MediaQuery.of(context).size.width * 0.3,
                child: Container(
                  width: 140,
                  height: 120,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: Theme.of(
                      context,
                    ).colorScheme.secondary.withValues(alpha: 0.45),
                  ),
                  child: BackdropFilter(
                    filter: ImageFilter.blur(sigmaX: 65, sigmaY: 65),
                    child: Container(color: Colors.transparent),
                  ),
                ),
              ),
              // Main content
              Column(
                children: [
                  _buildHeader(),
                  _buildFilterChips(),
                  _buildTabSelector(), // Add tab selector here
                  Expanded(
                    child: Builder(
                      builder: (context) {
                        if (isLoading && allEvents.isEmpty) {
                          print("loading anim triggered");
                          return Center(
                            child: CircularProgressIndicator(
                              color: Theme.of(context).colorScheme.tertiary,
                            ),
                          );
                        } else {
                          return _buildEventsList();
                        }
                      },
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Container(
      color: Theme.of(context).colorScheme.primary,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 8),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            if (!searching) ...[
              Container(
                margin: EdgeInsets.only(left: 40),
                child: Text(
                  'Events',
                  style: TextStyle(
                    fontSize: 28,
                    color: Theme.of(context).colorScheme.onPrimary,
                    fontWeight: FontWeight.w600,
                    fontFamily: 'Poppins',
                  ),
                ),
              ),
            ] else ...[
              Expanded(
                child: Container(
                  margin: const EdgeInsets.only(
                    left: 40,
                    top: 8,
                    bottom: 8,
                    right: 20,
                  ),
                  height: 45,
                  decoration: BoxDecoration(
                    color: Theme.of(
                      context,
                    ).colorScheme.onPrimary.withValues(alpha: 0.08),
                    borderRadius: BorderRadius.circular(25),
                    border: Border.all(
                      color: Theme.of(
                        context,
                      ).colorScheme.onPrimary.withValues(alpha: 0.15),
                      width: 1,
                    ),
                  ),
                  child: Row(
                    children: [
                      Padding(
                        padding: const EdgeInsets.only(left: 16, right: 12),
                        child: Icon(
                          Icons.search,
                          color: Theme.of(
                            context,
                          ).colorScheme.onPrimary.withValues(alpha: 0.6),
                          size: 20,
                        ),
                      ),
                      Expanded(
                        child: TextField(
                          controller: searchController,
                          style: TextStyle(
                            color: Theme.of(context).colorScheme.onPrimary,
                            fontFamily: 'Poppins',
                            fontSize: 15,
                            fontWeight: FontWeight.w400,
                          ),
                          cursorColor: Theme.of(context).colorScheme.tertiary,
                          decoration: InputDecoration(
                            hintText: 'Search events...',
                            hintStyle: TextStyle(
                              color: Theme.of(
                                context,
                              ).colorScheme.onPrimary.withValues(alpha: 0.5),
                              fontFamily: 'Poppins',
                              fontSize: 15,
                              fontWeight: FontWeight.w400,
                            ),
                            border: InputBorder.none,
                            contentPadding: EdgeInsets.symmetric(vertical: 12),
                          ),
                          onChanged: (value) {
                            setState(() {
                              searchQuery = value.trim().toLowerCase();
                            });
                            _applyFilter();
                          },
                        ),
                      ),
                      Padding(
                        padding: const EdgeInsets.only(right: 16),
                        child: GestureDetector(
                          onTap: () {
                            setState(() {
                              searchController.clear();
                              searchQuery = '';
                              searching = false;
                            });
                            _applyFilter();
                          },
                          child: Container(
                            width: 20,
                            height: 20,
                            decoration: BoxDecoration(
                              color: Theme.of(
                                context,
                              ).colorScheme.onPrimary.withValues(alpha: 0.2),
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: Icon(
                              Icons.close,
                              color: Theme.of(
                                context,
                              ).colorScheme.onPrimary.withValues(alpha: 0.7),
                              size: 14,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
            Container(
              margin: EdgeInsets.only(right: 20),
              child: Row(
                children: [
                  if (!searching) ...[
                    IconButton(
                      icon: Icon(
                        Icons.search,
                        color: Theme.of(context).colorScheme.onPrimary,
                        size: 30,
                      ),
                      onPressed: () {
                        setState(() {
                          searching = true;
                        });
                        _applyFilter();
                      },
                    ),
                    IconButton(
                      onPressed: () => _showEventDialog(),
                      icon: Icon(
                        Icons.add,
                        color: Theme.of(context).colorScheme.onPrimary,
                        size: 26,
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFilterChips() {
    final filters = ['All Events', 'This Month', 'This Week'];
    return SizedBox(
      height: 50,
      child: Center(
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          mainAxisSize: MainAxisSize.min,
          children:
              filters.map((filter) {
                final isSelected = selectedFilter == filter;
                final index = filters.indexOf(filter);

                return Padding(
                  padding: EdgeInsets.only(
                    right: index < filters.length - 1 ? 20 : 0,
                    top: 8,
                    bottom: 8,
                  ),
                  child: GestureDetector(
                    onTap: () {
                      setState(() {
                        selectedFilter = filter;
                      });
                      _applyFilter();
                    },
                    child: Text(
                      filter,
                      style: TextStyle(
                        color:
                            isSelected
                                ? Theme.of(context).colorScheme.secondary
                                : Theme.of(context).colorScheme.tertiary,
                        fontWeight:
                            isSelected ? FontWeight.w600 : FontWeight.w500,
                        fontFamily: 'Poppins',
                        fontSize: 14,
                      ),
                    ),
                  ),
                );
              }).toList(),
        ),
      ),
    );
  }

  Widget _buildTabSelector() {
    return Container(
      margin: EdgeInsets.symmetric(horizontal: 20, vertical: 10),
      child: Row(
        children: [
          Expanded(
            child: _buildTabChip(
              label: "Upcoming",
              isSelected: selectedTab == 'Upcoming',
              onTap: () {
                setState(() {
                  selectedTab = 'Upcoming';
                });
              },
            ),
          ),
          SizedBox(width: 12),
          Expanded(
            child: _buildTabChip(
              label: "Concluded",
              isSelected: selectedTab == 'Concluded',
              onTap: () {
                setState(() {
                  selectedTab = 'Concluded';
                });
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTabChip({
    required String label,
    required bool isSelected,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: EdgeInsets.symmetric(vertical: 12),
        decoration: BoxDecoration(
          color:
              isSelected
                  ? Colors.grey[700]
                  : Theme.of(context).colorScheme.primary,
          borderRadius: BorderRadius.circular(25),
          border: Border.all(
            color:
                isSelected
                    ? Colors.grey[700]!
                    : Theme.of(
                      context,
                    ).colorScheme.tertiary.withValues(alpha: 0.3),
            width: 1,
          ),
        ),
        child: Center(
          child: Text(
            label,
            style: TextStyle(
              color:
                  isSelected
                      ? Colors.white
                      : Theme.of(context).colorScheme.tertiary,
              fontWeight: FontWeight.w500,
              fontFamily: 'Poppins',
              fontSize: 14,
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildEventsList() {
    // Separate filtered events into upcoming and concluded
    final now = DateTime.now();
    final filteredUpcoming =
        filteredEvents.where((event) => event.dateTime.isAfter(now)).toList()
          ..sort((a, b) => a.dateTime.compareTo(b.dateTime));
    final filteredConcluded =
        filteredEvents.where((event) => event.dateTime.isBefore(now)).toList()
          ..sort((a, b) => b.dateTime.compareTo(a.dateTime));

    // Get events for the selected tab
    final eventsToShow =
        selectedTab == 'Upcoming' ? filteredUpcoming : filteredConcluded;
    final isCompleted = selectedTab == 'Concluded';

    if (eventsToShow.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.event_outlined,
              size: 80,
              color: Theme.of(context).colorScheme.tertiary,
            ),
            SizedBox(height: 16),
            Text(
              selectedTab == 'Upcoming'
                  ? "No upcoming events"
                  : "No concluded events",
              style: TextStyle(
                fontSize: 18,
                color: Theme.of(context).colorScheme.tertiary,
                fontFamily: 'Poppins',
                fontWeight: FontWeight.w500,
              ),
              textAlign: TextAlign.center,
            ),
            SizedBox(height: 8),
            Text(
              "Tap the + button to add your first event",
              style: TextStyle(
                fontSize: 14,
                color: Theme.of(
                  context,
                ).colorScheme.tertiary.withValues(alpha: 0.7),
                fontFamily: 'Poppins',
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      );
    }

    return SingleChildScrollView(
      physics: const BouncingScrollPhysics(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          ..._buildEventsWithMonthDividers(
            eventsToShow,
            isCompleted: isCompleted,
          ),
          SizedBox(height: 100), // Space for floating button
        ],
      ),
    );
  }

  Widget _buildEventCard(Event event, {bool isCompleted = false}) {
    return Container(
      margin: EdgeInsets.symmetric(horizontal: 20, vertical: 8),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(15),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
          child: Container(
            decoration: BoxDecoration(
              color: Theme.of(
                context,
              ).colorScheme.onPrimary.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(15),
              border: Border.all(
                color: Theme.of(
                  context,
                ).colorScheme.onPrimary.withValues(alpha: 0.2),
                width: 1,
              ),
            ),
            child: ListTile(
              contentPadding: EdgeInsets.all(16),
              leading: Container(
                width: 60,
                height: 60,
                decoration: BoxDecoration(
                  color:
                      isCompleted
                          ? Theme.of(
                            context,
                          ).colorScheme.tertiary.withValues(alpha: 0.3)
                          : Theme.of(
                            context,
                          ).colorScheme.secondary.withValues(alpha: 0.3),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      DateFormat('MMM').format(event.dateTime),
                      style: TextStyle(
                        fontSize: 12,
                        color: Theme.of(context).colorScheme.onPrimary,
                        fontWeight: FontWeight.w500,
                        fontFamily: 'Poppins',
                      ),
                    ),
                    Text(
                      DateFormat('dd').format(event.dateTime),
                      style: TextStyle(
                        fontSize: 16,
                        color: Theme.of(context).colorScheme.onPrimary,
                        fontWeight: FontWeight.w700,
                        fontFamily: 'Poppins',
                      ),
                    ),
                  ],
                ),
              ),
              title: Text(
                event.title,
                style: TextStyle(
                  fontSize: 16,
                  color: Theme.of(context).colorScheme.onPrimary,
                  fontWeight: FontWeight.w600,
                  fontFamily: 'Poppins',
                ),
              ),
              subtitle: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  SizedBox(height: 4),
                  Text(
                    DateFormat('MMM dd, yyyy - hh:mm a').format(event.dateTime),
                    style: TextStyle(
                      fontSize: 12,
                      color: Theme.of(context).colorScheme.tertiary,
                      fontFamily: 'Poppins',
                    ),
                  ),
                  if (event.description.isNotEmpty) ...[
                    SizedBox(height: 4),
                    Text(
                      event.description,
                      style: TextStyle(
                        fontSize: 14,
                        color: Theme.of(
                          context,
                        ).colorScheme.onPrimary.withValues(alpha: 0.8),
                        fontFamily: 'Poppins',
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ],
              ),
              trailing: PopupMenuButton<String>(
                icon: Icon(
                  Icons.more_vert,
                  color: Theme.of(context).colorScheme.onPrimary,
                ),
                onSelected: (value) {
                  if (value == 'edit') {
                    _showEventDialog(event: event);
                  } else if (value == 'delete') {
                    _showDeleteConfirmation(event);
                  }
                },
                itemBuilder:
                    (context) => [
                      PopupMenuItem(value: 'edit', child: Text('Edit Event')),
                      PopupMenuItem(
                        value: 'delete',
                        child: Text('Delete Event'),
                      ),
                    ],
              ),
              onTap: () => _showEventDialog(event: event),
            ),
          ),
        ),
      ),
    );
  }

  void _showEventDialog({Event? event}) {
    final isEditing = event != null;
    final titleController = TextEditingController(text: event?.title ?? '');
    final descriptionController = TextEditingController(
      text: event?.description ?? '',
    );
    DateTime selectedDate = event?.dateTime ?? DateTime.now();
    TimeOfDay selectedTime = TimeOfDay.fromDateTime(
      event?.dateTime ?? DateTime.now(),
    );
    showDialog(
      context: context,
      builder:
          (context) => StatefulBuilder(
            builder:
                (context, setDialogState) => AlertDialog(
                  backgroundColor: Theme.of(context).colorScheme.primary,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                    side: BorderSide(
                      color: Theme.of(
                        context,
                      ).colorScheme.onPrimary.withValues(alpha: 0.3),
                      width: 1,
                    ),
                  ),
                  title: Text(
                    isEditing ? 'Edit Event' : 'Add New Event',
                    style: TextStyle(
                      color: Theme.of(context).colorScheme.onPrimary,
                      fontFamily: 'Poppins',
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  content: SizedBox(
                    width: MediaQuery.of(context).size.width * 0.85,
                    child: SingleChildScrollView(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          _buildDialogTextField(
                            controller: titleController,
                            label: 'Event Title',
                            hint: 'Enter event title',
                          ),
                          SizedBox(height: 16),
                          _buildDialogTextField(
                            controller: descriptionController,
                            label: 'Description',
                            hint: 'Enter event description',
                            maxLines: 3,
                          ),
                          SizedBox(height: 16),
                          _buildDateTimeSelector(
                            selectedDate: selectedDate,
                            selectedTime: selectedTime,
                            onDateChanged: (date) {
                              setDialogState(() => selectedDate = date);
                            },
                            onTimeChanged: (time) {
                              setDialogState(() => selectedTime = time);
                            },
                          ),
                        ],
                      ),
                    ),
                  ),
                  actions: [
                    TextButton(
                      onPressed: () => Navigator.pop(context),
                      child: Text(
                        'Cancel',
                        style: TextStyle(
                          color: Theme.of(context).colorScheme.tertiary,
                          fontFamily: 'Poppins',
                        ),
                      ),
                    ),
                    ElevatedButton(
                      onPressed:
                          () => _saveEvent(
                            event: event,
                            title: titleController.text,
                            description: descriptionController.text,
                            dateTime: DateTime(
                              selectedDate.year,
                              selectedDate.month,
                              selectedDate.day,
                              selectedTime.hour,
                              selectedTime.minute,
                            ),
                          ),
                      style: ElevatedButton.styleFrom(
                        backgroundColor:
                            Theme.of(context).colorScheme.secondary,
                        foregroundColor:
                            Theme.of(context).colorScheme.onPrimary,
                      ),
                      child: Text(
                        isEditing ? 'Update' : 'Add',
                        style: TextStyle(fontFamily: 'Poppins'),
                      ),
                    ),
                  ],
                ),
          ),
    );
  }

  Widget _buildDialogTextField({
    required TextEditingController controller,
    required String label,
    required String hint,
    int maxLines = 1,
  }) {
    return TextField(
      controller: controller,
      maxLines: maxLines,
      style: TextStyle(
        color: Theme.of(context).colorScheme.onPrimary,
        fontFamily: 'Poppins',
      ),
      decoration: InputDecoration(
        labelText: label,
        hintText: hint,
        labelStyle: TextStyle(
          color: Theme.of(context).colorScheme.tertiary,
          fontFamily: 'Poppins',
        ),
        hintStyle: TextStyle(
          color: Theme.of(context).colorScheme.tertiary.withValues(alpha: 0.7),
          fontFamily: 'Poppins',
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(
            color: Theme.of(
              context,
            ).colorScheme.tertiary.withValues(alpha: 0.3),
          ),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(
            color: Theme.of(context).colorScheme.secondary,
            width: 2,
          ),
        ),
      ),
    );
  }

  Widget _buildDateTimeSelector({
    required DateTime selectedDate,
    required TimeOfDay selectedTime,
    required Function(DateTime) onDateChanged,
    required Function(TimeOfDay) onTimeChanged,
  }) {
    return Column(
      children: [
        Row(
          children: [
            Expanded(
              child: OutlinedButton.icon(
                onPressed: () async {
                  final date = await showDatePicker(
                    context: context,

                    //initialDate: selectedDate,
                    initialDate: DateTime.now().add(const Duration(days: 7)),
                    firstDate: DateTime.now(),
                    lastDate: DateTime.now().add(Duration(days: 365)),
                  );
                  if (date != null) onDateChanged(date);
                },
                icon: Icon(Icons.calendar_today, size: 18),
                label: Text(
                  DateFormat('MMM dd, yyyy').format(selectedDate),
                  style: TextStyle(fontFamily: 'Poppins'),
                ),
                style: OutlinedButton.styleFrom(
                  foregroundColor: Theme.of(context).colorScheme.onPrimary,
                  side: BorderSide(
                    color: Theme.of(
                      context,
                    ).colorScheme.tertiary.withValues(alpha: 0.3),
                  ),
                ),
              ),
            ),
            SizedBox(width: 12),
            Expanded(
              child: OutlinedButton.icon(
                onPressed: () async {
                  final time = await showTimePicker(
                    context: context,
                    initialTime: selectedTime,
                  );
                  if (time != null) onTimeChanged(time);
                },
                icon: Icon(Icons.access_time, size: 18),
                label: Text(
                  selectedTime.format(context),
                  style: TextStyle(fontFamily: 'Poppins'),
                ),
                style: OutlinedButton.styleFrom(
                  foregroundColor: Theme.of(context).colorScheme.onPrimary,
                  side: BorderSide(
                    color: Theme.of(
                      context,
                    ).colorScheme.tertiary.withValues(alpha: 0.3),
                  ),
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }

  void _saveEvent({
    // localled
    Event? event,
    required String title,
    required String description,
    required DateTime dateTime,
  }) async {
    if (title.trim().isEmpty) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Please enter an event title')));
      return;
    }

    Navigator.pop(context);

    final newEvent = Event(
      id: event?.id,
      title: title.trim(),
      description: description.trim(),
      dateTime: dateTime,
      userId: userSession.currentUser?['_id'],
      createdAt: DateTime.now(),
    );
    bool success;
    if (event != null) {
      setState(() {
        // Remove the old event from all lists
        allEvents.removeWhere((e) => e.id == event.id);
        upcomingEvents.removeWhere((e) => e.id == event.id);
        concludedEvents.removeWhere((e) => e.id == event.id);

        // Add the updated event to allEvents
        allEvents.add(newEvent);

        // Add to the correct list based on new date
        if (newEvent.dateTime.isAfter(DateTime.now())) {
          upcomingEvents.add(newEvent);
        } else {
          concludedEvents.add(newEvent);
        }
        _applyFilter(); // Update filteredEvents if filtering/searching
      });

      success = await _updateEvent(newEvent);
    } else {
      setState(() {
        allEvents.add(newEvent);
        if (newEvent.dateTime.isAfter(DateTime.now())) {
          upcomingEvents.add(newEvent);
        } else {
          concludedEvents.add(newEvent);
        }
      });
      success = await _createEvent(newEvent);
    }
    if (!mounted) return;

    if (success) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            event != null
                ? 'Event updated successfully'
                : 'Event added successfully',
          ),
        ),
      );
      _loadEvents();
    } else {
      if (event != null) {
        setState(() {
          allEvents.removeWhere((e) => e.id == newEvent.id);
          upcomingEvents.removeWhere((e) => e.id == newEvent.id);
          concludedEvents.removeWhere((e) => e.id == newEvent.id);

          // Add the old event back to allEvents
          allEvents.add(event);

          // Add back to the correct list based on its original date
          if (event.dateTime.isAfter(DateTime.now())) {
            upcomingEvents.add(event);
          } else {
            concludedEvents.add(event);
          }

          _applyFilter();
        });
      } else {
        setState(() {
          allEvents.remove(newEvent);
          if (newEvent.dateTime.isAfter(DateTime.now())) {
            upcomingEvents.remove(newEvent);
          } else {
            concludedEvents.remove(newEvent);
          }
        });
      }
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Failed to save event')));
    }
  }

  void _showDeleteConfirmation(Event event) {
    showDialog(
      context: context,
      builder:
          (context) => AlertDialog(
            backgroundColor: Theme.of(context).colorScheme.primary,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
              side: BorderSide(
                color: Theme.of(
                  context,
                ).colorScheme.onPrimary.withValues(alpha: 0.3),
                width: 1,
              ),
            ),
            title: Text(
              'Delete Event',
              style: TextStyle(
                color: Theme.of(context).colorScheme.onPrimary,
                fontFamily: 'Poppins',
                fontWeight: FontWeight.w600,
              ),
            ),
            content: Text(
              'Are you sure you want to delete "${event.title}"?',
              style: TextStyle(
                color: Theme.of(context).colorScheme.onPrimary,
                fontFamily: 'Poppins',
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: Text(
                  'Cancel',
                  style: TextStyle(
                    color: Theme.of(context).colorScheme.tertiary,
                    fontFamily: 'Poppins',
                  ),
                ),
              ),
              ElevatedButton(
                onPressed: () => _deleteEventById(event),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.red,
                  foregroundColor: Colors.white,
                ),
                child: Text('Delete', style: TextStyle(fontFamily: 'Poppins')),
              ),
            ],
          ),
    );
  }

  void _deleteEventById(Event event) async {
    // localled
    Navigator.pop(context);

    if (event.id != null) {
      setState(() {
        allEvents.remove(event);
        if (event.dateTime.isAfter(DateTime.now())) {
          upcomingEvents.remove(event);
        } else {
          concludedEvents.remove(event);
        }
      });

      final success = await _deleteEvent(event.id!);

      if (!mounted) return;

      if (success) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Event deleted successfully')));
        _loadEvents();
      } else {
        setState(() {
          allEvents.add(event);
          if (event.dateTime.isAfter(DateTime.now())) {
            upcomingEvents.add(event);
          } else {
            concludedEvents.add(event);
          }
        });
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Failed to delete event')));
      }
    }
  }

  List<Widget> _buildEventsWithMonthDividers(
    List<Event> events, {
    bool isCompleted = false,
  }) {
    if (events.isEmpty) return [];

    List<Widget> widgets = [];
    String? currentMonth;

    for (int i = 0; i < events.length; i++) {
      final event = events[i];
      final monthYear = DateFormat('MMMM yyyy').format(event.dateTime);

      // Add month divider if this is a new month
      if (currentMonth != monthYear) {
        widgets.add(_buildMonthDivider(monthYear));
        currentMonth = monthYear;
      }

      widgets.add(_buildEventCard(event, isCompleted: isCompleted));
    }

    return widgets;
  }

  Widget _buildMonthDivider(String monthYear) {
    return Container(
      margin: EdgeInsets.only(left: 20, right: 20, top: 16, bottom: 8),
      child: Row(
        children: [
          Text(
            monthYear,
            style: TextStyle(
              color: Theme.of(context).colorScheme.onPrimary,
              fontWeight: FontWeight.w600,
              fontFamily: 'Poppins',
              fontSize: 16,
            ),
          ),
          SizedBox(width: 16),
          Expanded(
            child: Container(
              height: 1,
              color: Theme.of(
                context,
              ).colorScheme.onPrimary.withValues(alpha: 0.3),
            ),
          ),
        ],
      ),
    );
  }
}
