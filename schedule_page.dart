import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:flutter_spinkit/flutter_spinkit.dart';
import 'dart:async';
import 'database.dart';
import 'fetcher.dart';

class SchedulePage extends StatefulWidget {
  const SchedulePage({super.key});

  @override
  State<SchedulePage> createState() => _SchedulePageState();
}

class _SchedulePageState extends State<SchedulePage>
    with TickerProviderStateMixin {
  // --- State Variables ---
  Future<ScheduleData?>? _scheduleFuture;
  bool _isLoading = false;
  TabController? _tabController;

  // --- UI Colors ---
  final Color backgroundColor = const Color(0xFF0F172A);
  final Color cardColor = const Color(0xFF1E293B);
  final Color textColor = Colors.white;
  final Color secondaryTextColor = const Color(0xFF94A3B8);
  final Color primaryColor = const Color(0xFF00A9FF);

  @override
  void initState() {
    super.initState();
    // Load the schedule from the database first.
    _scheduleFuture = DatabaseHelper.instance.getSchedule().then((
      scheduleData,
    ) {
      if (scheduleData != null) {
        // If data exists, initialize the TabController.
        _setupTabController(scheduleData);
      }
      return scheduleData;
    });
  }

  /// Sets up the TabController based on the days available in the schedule.
  void _setupTabController(ScheduleData data) {
    // Get the current day of the week (1=Mon, 7=Sun)
    int today = DateTime.now().weekday;
    // Find the index of today's tab, default to 0 if not found or weekend.
    int initialIndex = data.schedule.indexWhere(
      (day) =>
          day['day'].toString().toLowerCase() ==
          _getTodayString(today).toLowerCase(),
    );
    if (initialIndex == -1) initialIndex = 0;

    // Dispose the old controller if it exists before creating a new one
    _tabController?.dispose();

    _tabController = TabController(
      length: data.schedule.length,
      vsync: this,
      initialIndex: initialIndex,
    );
  }

  String _getTodayString(int weekday) {
    switch (weekday) {
      case 1:
        return 'Mon';
      case 2:
        return 'Tue';
      case 3:
        return 'Wed';
      case 4:
        return 'Thu';
      case 5:
        return 'Fri';
      case 6:
        return 'Sat';
      case 7:
        return 'Sun';
      default:
        return 'Mon';
    }
  }

  @override
  void dispose() {
    _tabController?.dispose();
    super.dispose();
  }

  /// --- FIXED: Made the refresh logic more robust ---
  Future<void> _fetchLatestSchedule() async {
    setState(() {
      _isLoading = true;
      // Set the future to null to force the FutureBuilder to show a loading indicator
      _scheduleFuture = null;
    });

    try {
      final credentials = await DatabaseHelper.instance.getCredentials();
      if (credentials == null) {
        throw Exception("No credentials saved. Please log in again.");
      }

      // --- UPDATED: Using ApiClient instead of ApiFetcher ---
      final newSchedule = await ApiClient.fetchSchedule(
        username: credentials.username,
        password: credentials.password,
      );

      await DatabaseHelper.instance.saveSchedule(newSchedule);

      // Re-initialize the tab controller with the new data
      _setupTabController(newSchedule);

      // Update the UI by assigning the new future
      setState(() {
        _scheduleFuture = Future.value(newSchedule);
      });
    } catch (e) {
      // If there's an error, set the future to an error state
      setState(() {
        _scheduleFuture = Future.error(e);
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          backgroundColor: Colors.redAccent,
          content: Text('Error: ${e.toString()}', style: GoogleFonts.poppins()),
        ),
      );
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: backgroundColor,
      appBar: AppBar(
        title: Text(
          'Weekly Schedule',
          style: GoogleFonts.poppins(color: textColor),
        ),
        backgroundColor: backgroundColor,
        elevation: 0,
        actions: [
          IconButton(
            icon: Icon(Icons.refresh, color: textColor),
            onPressed: _isLoading ? null : _fetchLatestSchedule,
          ),
        ],
      ),
      body: Stack(
        children: [
          FutureBuilder<ScheduleData?>(
            future: _scheduleFuture,
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting ||
                  _scheduleFuture == null) {
                return const Center(
                  child: SpinKitFadingCube(color: Colors.white, size: 50.0),
                );
              }

              if (snapshot.hasError) {
                return _buildErrorUI('An error occurred: ${snapshot.error}');
              }

              final scheduleData = snapshot.data;

              if (scheduleData == null || _tabController == null) {
                return _buildFetchInitialDataUI();
              }

              return _buildScheduleDashboard(scheduleData);
            },
          ),
          if (_isLoading && _scheduleFuture != null)
            Container(
              color: backgroundColor.withOpacity(0.8),
              child: const Center(
                child: SpinKitChasingDots(color: Colors.white, size: 50.0),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildScheduleDashboard(ScheduleData data) {
    return Column(
      children: [
        TabBar(
          controller: _tabController,
          isScrollable: true,
          labelColor: primaryColor,
          unselectedLabelColor: secondaryTextColor,
          indicatorColor: primaryColor,
          indicatorWeight: 3.0,
          labelStyle: GoogleFonts.poppins(
            fontWeight: FontWeight.w600,
            fontSize: 16,
          ),
          unselectedLabelStyle: GoogleFonts.poppins(
            fontWeight: FontWeight.w500,
            fontSize: 16,
          ),
          tabs: data.schedule.map((day) => Tab(text: day['day'])).toList(),
        ),
        Expanded(
          child: TabBarView(
            controller: _tabController,
            children: data.schedule.map<Widget>((dayData) {
              final periods = (dayData['periods'] as List)
                  .where((p) => p['subject'].toString().isNotEmpty)
                  .toList();
              if (periods.isEmpty) {
                return _buildNoClassesUI();
              }
              return ListView.builder(
                padding: const EdgeInsets.all(16),
                itemCount: periods.length,
                itemBuilder: (context, index) {
                  return _buildPeriodCard(periods[index], index + 1);
                },
              );
            }).toList(),
          ),
        ),
      ],
    );
  }

  Widget _buildPeriodCard(Map<String, dynamic> period, int periodNumber) {
    final timeSlot = period['time_slot'];
    final startTime = timeSlot['start_time'];
    final endTime = timeSlot['end_time'];
    final subject = period['subject'];
    final faculty = period['faculty'];

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: cardColor,
        borderRadius: BorderRadius.circular(16),
        border: Border(
          left: BorderSide(color: _getPeriodColor(periodNumber), width: 5),
        ),
      ),
      child: Row(
        children: [
          Column(
            children: [
              Text(
                startTime,
                style: GoogleFonts.poppins(
                  color: textColor,
                  fontWeight: FontWeight.w600,
                  fontSize: 16,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                'to',
                style: GoogleFonts.poppins(
                  color: secondaryTextColor,
                  fontSize: 12,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                endTime,
                style: GoogleFonts.poppins(
                  color: textColor,
                  fontWeight: FontWeight.w600,
                  fontSize: 16,
                ),
              ),
            ],
          ),
          const SizedBox(width: 16),
          Container(width: 1, height: 60, color: Colors.white24),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  subject,
                  style: GoogleFonts.poppins(
                    color: primaryColor,
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Icon(
                      Icons.person_outline,
                      color: secondaryTextColor,
                      size: 16,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        faculty,
                        style: GoogleFonts.poppins(
                          color: secondaryTextColor,
                          fontSize: 14,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildNoClassesUI() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.beach_access, size: 70, color: secondaryTextColor),
          const SizedBox(height: 16),
          Text(
            "It's a free day!",
            style: GoogleFonts.poppins(fontSize: 18, color: textColor),
          ),
          Text(
            "No classes scheduled.",
            style: GoogleFonts.poppins(fontSize: 14, color: secondaryTextColor),
          ),
        ],
      ),
    );
  }

  Widget _buildFetchInitialDataUI() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.cloud_off, color: secondaryTextColor, size: 80),
          const SizedBox(height: 20),
          Text(
            'No schedule data found',
            style: GoogleFonts.poppins(color: textColor, fontSize: 18),
          ),
          Text(
            'Tap the button to fetch your latest schedule.',
            style: GoogleFonts.poppins(color: secondaryTextColor, fontSize: 14),
          ),
          const SizedBox(height: 30),
          ElevatedButton.icon(
            onPressed: _fetchLatestSchedule,
            icon: const Icon(Icons.cloud_download),
            label: const Text('Fetch Latest Schedule'),
            style: ElevatedButton.styleFrom(
              backgroundColor: primaryColor,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 30, vertical: 15),
              textStyle: GoogleFonts.poppins(
                fontSize: 16,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildErrorUI(String message) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.error_outline, color: Colors.redAccent, size: 80),
          const SizedBox(height: 20),
          Text(
            'Something Went Wrong',
            textAlign: TextAlign.center,
            style: GoogleFonts.poppins(color: textColor, fontSize: 18),
          ),
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: Text(
              message,
              textAlign: TextAlign.center,
              style: GoogleFonts.poppins(
                color: secondaryTextColor,
                fontSize: 14,
              ),
            ),
          ),
          const SizedBox(height: 30),
          ElevatedButton.icon(
            onPressed: _fetchLatestSchedule,
            icon: const Icon(Icons.refresh),
            label: const Text('Try Again'),
            style: ElevatedButton.styleFrom(
              backgroundColor: primaryColor,
              foregroundColor: Colors.white,
            ),
          ),
        ],
      ),
    );
  }

  Color _getPeriodColor(int periodNumber) {
    final colors = [
      Colors.blue.shade400,
      Colors.purple.shade400,
      Colors.orange.shade400,
      Colors.teal.shade400,
      Colors.pink.shade300,
      Colors.lightGreen.shade500,
      Colors.indigo.shade400,
      Colors.red.shade400,
    ];
    return colors[periodNumber % colors.length];
  }
}
