import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:flutter_spinkit/flutter_spinkit.dart';
import 'dart:async';
import 'package:intl/intl.dart';
import 'package:percent_indicator/percent_indicator.dart';

import 'config.dart'; // To access the server message
import 'database.dart';
import 'fetcher.dart';
import 'attendance_page.dart'; // Corrected import
import 'schedule_page.dart';
import 'profile.dart';
import 'quick_check.dart';

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  // --- State Variables ---
  Future<Map<String, dynamic>?>? _dashboardDataFuture;
  bool _isLoading = false;
  bool _isMessageVisible = false;

  // --- UI Colors ---
  final Color backgroundColor = const Color(0xFF0F172A);
  final Color cardColor = const Color(0xFF1E293B);
  final Color textColor = Colors.white;
  final Color secondaryTextColor = const Color(0xFF94A3B8);
  final Color primaryColor = const Color(0xFF00A9FF);

  @override
  void initState() {
    super.initState();
    _dashboardDataFuture = _loadDashboardData();
    _isMessageVisible =
        AppConfig.showMessage && AppConfig.messageBody.isNotEmpty;
  }

  Future<Map<String, dynamic>?> _loadDashboardData() async {
    final attendance = await DatabaseHelper.instance.getAttendance();
    final schedule = await DatabaseHelper.instance.getSchedule();
    if (attendance != null && schedule != null) {
      return {'attendance': attendance, 'schedule': schedule};
    }
    return null;
  }

  Future<void> _fetchAllData() async {
    setState(() => _isLoading = true);
    try {
      // Also fetch the latest config on refresh
      await AppConfig.fetchAndSetup();

      final credentials = await DatabaseHelper.instance.getCredentials();
      if (credentials == null) throw Exception("No credentials saved.");

      // --- UPDATED: Using ApiClient instead of ApiFetcher ---
      final results = await Future.wait([
        ApiClient.fetchAttendance(
          username: credentials.username,
          password: credentials.password,
        ),
        ApiClient.fetchSchedule(
          username: credentials.username,
          password: credentials.password,
        ),
      ]);
      final newAttendance = results[0] as AttendanceData;
      final newSchedule = results[1] as ScheduleData;
      await DatabaseHelper.instance.saveAttendance(newAttendance);
      await DatabaseHelper.instance.saveSchedule(newSchedule);
      setState(() {
        _dashboardDataFuture = Future.value({
          'attendance': newAttendance,
          'schedule': newSchedule,
        });
        _isMessageVisible =
            AppConfig.showMessage && AppConfig.messageBody.isNotEmpty;
      });
    } catch (e) {
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
      body: Stack(
        children: [
          SafeArea(
            child: FutureBuilder<Map<String, dynamic>?>(
              future: _dashboardDataFuture,
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting &&
                    !_isLoading) {
                  return const Center(
                    child: SpinKitFadingCube(color: Colors.white, size: 50.0),
                  );
                }
                if (snapshot.hasError) {
                  return _buildErrorUI('An error occurred: ${snapshot.error}');
                }
                final dashboardData = snapshot.data;
                if (dashboardData == null) {
                  return _buildFetchInitialDataUI();
                }
                final AttendanceData attendance = dashboardData['attendance'];
                final ScheduleData schedule = dashboardData['schedule'];
                return _buildDashboard(attendance, schedule);
              },
            ),
          ),
          if (_isLoading)
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

  Widget _buildDashboard(AttendanceData attendance, ScheduleData schedule) {
    return RefreshIndicator(
      onRefresh: _fetchAllData,
      backgroundColor: cardColor,
      color: primaryColor,
      child: ListView(
        padding: const EdgeInsets.all(20.0),
        children: [
          _buildServerMessageCard(),
          _buildHeader(attendance.studentId),
          const SizedBox(height: 24),
          _buildQuickAttendanceCard(attendance),
          const SizedBox(height: 24),
          _buildCurrentClassCard(schedule),
          const SizedBox(height: 24),
          _buildNavigationGrid(),
        ],
      ),
    );
  }

  Widget _buildServerMessageCard() {
    return Visibility(
      visible: _isMessageVisible,
      child: Card(
        color: cardColor,
        margin: const EdgeInsets.only(bottom: 24),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 8, 16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: Padding(
                      padding: const EdgeInsets.only(top: 8.0),
                      child: Text(
                        AppConfig.messageTitle,
                        style: GoogleFonts.poppins(
                          color: textColor,
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ),
                  IconButton(
                    icon: Icon(Icons.close, color: secondaryTextColor),
                    onPressed: () {
                      setState(() {
                        _isMessageVisible = false;
                      });
                    },
                  ),
                ],
              ),
              if (AppConfig.messageBody.isNotEmpty) ...[
                const SizedBox(height: 8),
                Text(
                  AppConfig.messageBody,
                  style: GoogleFonts.poppins(
                    color: secondaryTextColor,
                    fontSize: 15,
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildHeader(String studentId) {
    final now = DateTime.now();
    final isSunday = now.weekday == DateTime.sunday;

    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Hello, $studentId',
              style: GoogleFonts.poppins(
                fontSize: 24,
                fontWeight: FontWeight.bold,
                color: textColor,
              ),
            ),
            Text(
              isSunday
                  ? 'Enjoy your Sunday! ☀️'
                  : DateFormat('EEEE, d MMMM').format(now),
              style: GoogleFonts.poppins(
                fontSize: 16,
                color: secondaryTextColor,
              ),
            ),
          ],
        ),
        Row(
          children: [
            IconButton(
              tooltip: 'Refresh Data',
              icon: Icon(Icons.refresh, color: secondaryTextColor, size: 30),
              onPressed: _isLoading ? null : _fetchAllData,
            ),
            IconButton(
              tooltip: 'Profile & Settings',
              icon: Icon(
                Icons.account_circle,
                color: secondaryTextColor,
                size: 30,
              ),
              onPressed: () => Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const ProfilePage()),
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildQuickAttendanceCard(AttendanceData attendance) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: cardColor,
        borderRadius: BorderRadius.circular(24),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Overall Progress',
            style: GoogleFonts.poppins(
              fontSize: 18,
              fontWeight: FontWeight.w600,
              color: textColor,
            ),
          ),
          const SizedBox(height: 16),
          LinearPercentIndicator(
            lineHeight: 12.0,
            percent: attendance.overallPercentage / 100,
            backgroundColor: backgroundColor,
            progressColor: _getPercentageColor(attendance.overallPercentage),
            barRadius: const Radius.circular(12),
            animation: true,
          ),
          const SizedBox(height: 12),
          Align(
            alignment: Alignment.centerRight,
            child: Text(
              '${attendance.overallPercentage.toStringAsFixed(2)}%',
              style: GoogleFonts.poppins(
                color: textColor,
                fontWeight: FontWeight.bold,
                fontSize: 16,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCurrentClassCard(ScheduleData schedule) {
    final currentClassInfo = _getCurrentClass(schedule);
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: cardColor,
        borderRadius: BorderRadius.circular(24),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            currentClassInfo['title'],
            style: GoogleFonts.poppins(
              fontSize: 18,
              fontWeight: FontWeight.w600,
              color: textColor,
            ),
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Icon(currentClassInfo['icon'], color: primaryColor, size: 40),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      currentClassInfo['subject'],
                      style: GoogleFonts.poppins(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                        color: textColor,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      currentClassInfo['time'],
                      style: GoogleFonts.poppins(color: secondaryTextColor),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildNavigationGrid() {
    return GridView.count(
      crossAxisCount: 2,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      crossAxisSpacing: 16,
      mainAxisSpacing: 16,
      childAspectRatio: 1.2,
      children: [
        _buildNavCard(
          icon: Icons.pie_chart_outline,
          label: 'My Attendance',
          onTap: () => Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => const AttendancePage()),
          ),
        ),
        _buildNavCard(
          icon: Icons.calendar_today_outlined,
          label: 'My Schedule',
          onTap: () => Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => const SchedulePage()),
          ),
        ),
        _buildNavCard(
          icon: Icons.people_outline,
          label: "Friend's Attendance",
          onTap: () => Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => const QuickCheckPage()),
          ),
        ),
        _buildNavCard(
          icon: Icons.settings_outlined,
          label: 'Settings',
          onTap: () => Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => const ProfilePage()),
          ),
        ),
      ],
    );
  }

  Widget _buildNavCard({
    required IconData icon,
    required String label,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(24),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: cardColor,
          borderRadius: BorderRadius.circular(24),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, size: 40, color: primaryColor),
            const SizedBox(height: 12),
            Text(
              label,
              textAlign: TextAlign.center,
              style: GoogleFonts.poppins(
                color: textColor,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFetchInitialDataUI() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.cloud_off, color: Colors.white54, size: 80),
          const SizedBox(height: 20),
          Text(
            'Welcome to TrackIT!',
            style: GoogleFonts.poppins(color: textColor, fontSize: 18),
          ),
          Text(
            'Fetch your data to get started.',
            style: GoogleFonts.poppins(color: secondaryTextColor),
          ),
          const SizedBox(height: 30),
          ElevatedButton.icon(
            onPressed: _fetchAllData,
            icon: const Icon(Icons.cloud_download),
            label: const Text('Fetch All Data'),
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
          const Icon(Icons.error_outline, color: Colors.redAccent, size: 80),
          const SizedBox(height: 20),
          Text(
            'Something Went Wrong',
            style: GoogleFonts.poppins(color: textColor, fontSize: 18),
          ),
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: Text(
              message,
              textAlign: TextAlign.center,
              style: GoogleFonts.poppins(color: secondaryTextColor),
            ),
          ),
          const SizedBox(height: 30),
          ElevatedButton.icon(
            onPressed: _fetchAllData,
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

  Color _getPercentageColor(double percentage) {
    if (percentage >= 85) return Colors.green.shade400;
    if (percentage >= 75) return Colors.amber.shade400;
    return Colors.red.shade400;
  }

  Map<String, dynamic> _getCurrentClass(ScheduleData scheduleData) {
    final now = DateTime.now();

    if (now.weekday == DateTime.sunday) {
      return {
        'title': 'Sunday',
        'icon': Icons.weekend_outlined,
        'subject': 'It\'s a holiday!',
        'time': 'Relax and recharge for the week.',
      };
    }

    final todayString = DateFormat('E').format(now);
    final todaySchedule = scheduleData.schedule.firstWhere(
      (day) => day['day'].toString().toLowerCase() == todayString.toLowerCase(),
      orElse: () => null,
    );
    if (todaySchedule == null) {
      return {
        'title': 'Today',
        'icon': Icons.weekend_outlined,
        'subject': 'No Classes Today',
        'time': 'Enjoy your day off!',
      };
    }
    final periods = (todaySchedule['periods'] as List)
        .where((p) => p['subject'].toString().isNotEmpty)
        .toList();
    for (var period in periods) {
      final timeSlot = period['time_slot'];
      try {
        final startTime = DateFormat('hh:mm a').parse(timeSlot['start_time']);
        final endTime = DateFormat('hh:mm a').parse(timeSlot['end_time']);
        final nowTime = DateTime(
          now.year,
          now.month,
          now.day,
          now.hour,
          now.minute,
        );
        final classStart = DateTime(
          now.year,
          now.month,
          now.day,
          startTime.hour,
          startTime.minute,
        );
        final classEnd = DateTime(
          now.year,
          now.month,
          now.day,
          endTime.hour,
          endTime.minute,
        );
        if (nowTime.isAfter(classStart) && nowTime.isBefore(classEnd)) {
          return {
            'title': 'Current Class',
            'icon': Icons.school_outlined,
            'subject': period['subject'],
            'time': '${timeSlot['start_time']} - ${timeSlot['end_time']}',
          };
        }
        if (nowTime.isBefore(classStart)) {
          return {
            'title': 'Next Class',
            'icon': Icons.update,
            'subject': period['subject'],
            'time': 'Starts at ${timeSlot['start_time']}',
          };
        }
      } catch (e) {
        print("Could not parse time: ${timeSlot['start_time']}");
      }
    }
    return {
      'title': 'Today',
      'icon': Icons.done_all,
      'subject': 'Classes are over!',
      'time': 'See you tomorrow.',
    };
  }
}
