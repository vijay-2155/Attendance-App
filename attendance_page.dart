import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:flutter_spinkit/flutter_spinkit.dart';
import 'dart:async';
import 'database.dart';
import 'fetcher.dart'; // Now uses the new ApiClient
import 'package:percent_indicator/percent_indicator.dart';

class AttendancePage extends StatefulWidget {
  final AttendanceData? initialData;

  const AttendancePage({super.key, this.initialData});

  @override
  State<AttendancePage> createState() => _AttendancePageState();
}

class _SubjectInfo {
  final String code;
  final String ratio;
  final double percentage;
  _SubjectInfo(this.code, this.ratio, this.percentage);
}

class _AttendancePageState extends State<AttendancePage>
    with TickerProviderStateMixin {
  Future<AttendanceData?>? _attendanceFuture;
  bool _isLoading = false;
  late AnimationController _fadeController;
  late Animation<double> _fadeAnimation;

  final Color backgroundColor = const Color(0xFF0F172A);
  final Color cardColor = const Color(0xFF1E293B);
  final Color textColor = Colors.white;
  final Color secondaryTextColor = const Color(0xFF94A3B8);
  final Color primaryColor = const Color(0xFF00A9FF);

  @override
  void initState() {
    super.initState();
    _fadeController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 600),
    );
    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _fadeController, curve: Curves.easeInOut),
    );

    if (widget.initialData != null) {
      _attendanceFuture = Future.value(widget.initialData);
    } else {
      _attendanceFuture = DatabaseHelper.instance.getAttendance();
    }
  }

  @override
  void dispose() {
    _fadeController.dispose();
    super.dispose();
  }

  Future<void> _fetchLatestData() async {
    setState(() {
      _isLoading = true;
      _attendanceFuture = null;
    });

    try {
      final credentials = await DatabaseHelper.instance.getCredentials();
      if (credentials == null) {
        throw Exception("No credentials saved. Please log in again.");
      }

      // --- UPDATED: Using ApiClient instead of ApiFetcher ---
      final newAttendance = await ApiClient.fetchAttendance(
        username: credentials.username,
        password: credentials.password,
      );

      await DatabaseHelper.instance.saveAttendance(newAttendance);

      setState(() {
        _attendanceFuture = Future.value(newAttendance);
      });
    } catch (e) {
      setState(() {
        _attendanceFuture = Future.error(e);
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
          'My Attendance',
          style: GoogleFonts.poppins(color: textColor),
        ),
        backgroundColor: backgroundColor,
        elevation: 0,
        actions: [
          IconButton(
            icon: Icon(Icons.refresh, color: textColor),
            onPressed: _isLoading ? null : _fetchLatestData,
          ),
        ],
      ),
      body: Stack(
        children: [
          FutureBuilder<AttendanceData?>(
            future: _attendanceFuture,
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting ||
                  _attendanceFuture == null) {
                return const Center(
                  child: SpinKitFadingCube(color: Colors.white, size: 50.0),
                );
              }
              if (snapshot.hasError) {
                return _buildErrorUI('An error occurred: ${snapshot.error}');
              }
              final attendanceData = snapshot.data;
              if (attendanceData == null) {
                return _buildFetchInitialDataUI();
              }
              _fadeController.forward();
              return FadeTransition(
                opacity: _fadeAnimation,
                child: _buildAttendanceDashboard(attendanceData),
              );
            },
          ),
          if (_isLoading && _attendanceFuture != null)
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

  Widget _buildAttendanceDashboard(AttendanceData data) {
    return ListView(
      padding: const EdgeInsets.all(16.0),
      children: [
        _buildOverallPercentage(data),
        const SizedBox(height: 24),
        _buildAttendanceAnalysis(data),
        const SizedBox(height: 24),
        _buildTodaysAttendance(data),
        const SizedBox(height: 24),
        _buildStatsGrid(data),
        const SizedBox(height: 24),
        Text(
          'Subject-wise Breakdown',
          style: GoogleFonts.poppins(
            color: textColor,
            fontSize: 20,
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: 16),
        ...data.subjectAttendance.map(
          (subjectString) => _buildSubjectTile(subjectString),
        ),
      ],
    );
  }

  Widget _buildOverallPercentage(AttendanceData data) {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: cardColor,
        borderRadius: BorderRadius.circular(24),
      ),
      child: Row(
        children: [
          CircularPercentIndicator(
            radius: 55.0,
            lineWidth: 10.0,
            animation: true,
            animationDuration: 1200,
            percent: data.overallPercentage / 100,
            center: Text(
              "${data.overallPercentage.toStringAsFixed(1)}%",
              style: GoogleFonts.poppins(
                fontWeight: FontWeight.bold,
                fontSize: 22.0,
                color: textColor,
              ),
            ),
            circularStrokeCap: CircularStrokeCap.round,
            progressColor: _getPercentageColor(data.overallPercentage),
            backgroundColor: backgroundColor,
          ),
          const SizedBox(width: 24),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Overall Attendance',
                  style: GoogleFonts.poppins(
                    fontSize: 18,
                    fontWeight: FontWeight.w600,
                    color: textColor,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'Student ID: ${data.studentId}',
                  style: GoogleFonts.poppins(
                    fontSize: 14,
                    color: secondaryTextColor,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAttendanceAnalysis(AttendanceData data) {
    final status = _getAttendanceStatus(data.overallPercentage);
    final classesTo75 = _calculateClassesToReach(
      data.totalPresent,
      data.totalClasses,
      75,
    );
    final subjectList = data.subjectAttendance
        .map(_parseSubjectString)
        .where((s) => s.ratio != '0/0')
        .toList();
    _SubjectInfo? lowestSubject, highestSubject;
    if (subjectList.isNotEmpty) {
      subjectList.sort((a, b) => a.percentage.compareTo(b.percentage));
      lowestSubject = subjectList.first;
      highestSubject = subjectList.last;
    }
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
            'Attendance Analysis',
            style: GoogleFonts.poppins(
              color: textColor,
              fontSize: 20,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 16),
          _buildAnalysisRow(
            Icons.traffic,
            'Status',
            status['text'] ?? 'N/A',
            status['color'] ?? Colors.grey,
          ),
          const Divider(color: Colors.white24, height: 24),
          _buildAnalysisRow(
            Icons.track_changes,
            'Classes for 75%',
            '$classesTo75 more',
            Colors.white,
          ),
          if (highestSubject != null) ...[
            const Divider(color: Colors.white24, height: 24),
            _buildAnalysisRow(
              Icons.arrow_upward,
              'Highest Subject',
              '${highestSubject.code} (${highestSubject.percentage.toStringAsFixed(1)}%)',
              Colors.green.shade400,
            ),
          ],
          if (lowestSubject != null) ...[
            const Divider(color: Colors.white24, height: 24),
            _buildAnalysisRow(
              Icons.arrow_downward,
              'Lowest Subject',
              '${lowestSubject.code} (${lowestSubject.percentage.toStringAsFixed(1)}%)',
              Colors.red.shade400,
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildAnalysisRow(
    IconData icon,
    String title,
    String value,
    Color valueColor,
  ) {
    return Row(
      children: [
        Icon(icon, color: secondaryTextColor, size: 20),
        const SizedBox(width: 12),
        Text(
          title,
          style: GoogleFonts.poppins(color: secondaryTextColor, fontSize: 15),
        ),
        const Spacer(),
        Text(
          value,
          style: GoogleFonts.poppins(
            color: valueColor,
            fontSize: 15,
            fontWeight: FontWeight.w600,
          ),
        ),
      ],
    );
  }

  Widget _buildTodaysAttendance(AttendanceData data) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: cardColor,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.today, color: Colors.amber, size: 28),
              const SizedBox(width: 12),
              Text(
                "Today's Status",
                style: GoogleFonts.poppins(
                  color: secondaryTextColor,
                  fontSize: 14,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          if (data.todaysAttendance.isNotEmpty)
            ...data.todaysAttendance.map(
              (status) => Padding(
                padding: const EdgeInsets.only(bottom: 4.0),
                child: Text(
                  status,
                  style: GoogleFonts.poppins(
                    color: textColor,
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            )
          else
            Text(
              'No classes today',
              style: GoogleFonts.poppins(
                color: textColor,
                fontSize: 16,
                fontWeight: FontWeight.w600,
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildStatsGrid(AttendanceData data) {
    return GridView.count(
      crossAxisCount: 2,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      crossAxisSpacing: 16,
      mainAxisSpacing: 16,
      childAspectRatio: 1.6,
      children: [
        _buildInfoCard(
          icon: Icons.class_,
          title: 'Total Classes',
          value: data.totalClasses.toString(),
          iconColor: Colors.blue,
        ),
        _buildInfoCard(
          icon: Icons.check_circle,
          title: 'Present',
          value: data.totalPresent.toString(),
          iconColor: Colors.green,
        ),
        _buildInfoCard(
          icon: Icons.directions_run,
          title: 'Can Skip',
          value: '${data.skippableHours} hrs',
          iconColor: Colors.orange,
        ),
        _buildInfoCard(
          icon: Icons.warning,
          title: 'Need',
          value: '${data.requiredHours} hrs',
          iconColor: Colors.red,
        ),
      ],
    );
  }

  Widget _buildSubjectTile(String subjectString) {
    final subjectInfo = _parseSubjectString(subjectString);
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: cardColor,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  subjectInfo.code,
                  style: GoogleFonts.poppins(
                    color: textColor,
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                Text(
                  subjectInfo.ratio,
                  style: GoogleFonts.poppins(
                    color: secondaryTextColor,
                    fontSize: 14,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 16),
          Text(
            '${subjectInfo.percentage.toStringAsFixed(1)}%',
            style: GoogleFonts.poppins(
              color: _getPercentageColor(subjectInfo.percentage),
              fontSize: 18,
              fontWeight: FontWeight.bold,
            ),
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
            'No attendance data found',
            style: GoogleFonts.poppins(color: textColor, fontSize: 18),
          ),
          Text(
            'Tap the button to fetch your latest records.',
            style: GoogleFonts.poppins(color: secondaryTextColor, fontSize: 14),
          ),
          const SizedBox(height: 30),
          ElevatedButton.icon(
            onPressed: _fetchLatestData,
            icon: const Icon(Icons.cloud_download),
            label: const Text('Fetch Latest Data'),
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
            onPressed: _fetchLatestData,
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

  Widget _buildInfoCard({
    required IconData icon,
    required String title,
    required String value,
    required Color iconColor,
  }) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: cardColor,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Icon(icon, color: iconColor, size: 28),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: GoogleFonts.poppins(
                  color: secondaryTextColor,
                  fontSize: 14,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                value,
                style: GoogleFonts.poppins(
                  color: textColor,
                  fontSize: 18,
                  fontWeight: FontWeight.w600,
                ),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
            ],
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

  Map<String, dynamic> _getAttendanceStatus(double percentage) {
    if (percentage >= 85)
      return {'text': 'Excellent!', 'color': Colors.green.shade400};
    if (percentage >= 75)
      return {'text': 'On Track', 'color': Colors.amber.shade400};
    return {'text': 'Danger Zone', 'color': Colors.red.shade400};
  }

  int _calculateClassesToReach(
    int currentPresent,
    int currentTotal,
    double targetPercentage,
  ) {
    if (currentTotal == 0) {
      if (targetPercentage > 0) return 1;
      return 0;
    }
    if ((currentPresent / currentTotal) * 100 >= targetPercentage) return 0;

    int classesNeeded = 0;
    double newPercentage = 0;
    int futurePresent = currentPresent;
    int futureTotal = currentTotal;
    while (newPercentage < targetPercentage) {
      classesNeeded++;
      futurePresent++;
      futureTotal++;
      newPercentage = (futurePresent / futureTotal) * 100;
    }
    return classesNeeded;
  }

  _SubjectInfo _parseSubjectString(String subjectString) {
    final parts = subjectString.trim().split(RegExp(r'\s+'));

    if (parts.length < 3) {
      return _SubjectInfo(subjectString, 'N/A', 0.0);
    }

    final percentage = double.tryParse(parts.last) ?? 0.0;
    final ratio = parts[parts.length - 2];
    final subjectCode = parts.sublist(0, parts.length - 2).join(' ');

    return _SubjectInfo(subjectCode, ratio, percentage);
  }
}
