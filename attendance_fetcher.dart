import 'package:html/parser.dart' as html_parser;
import 'package:http/http.dart' as http;
import 'package:intl/intl.dart';
import 'database.dart';
import 'auth_helper.dart';

/// Simplified attendance fetcher that matches the Go implementation
class AttendanceFetcher {
  static const String _attendanceUrl =
      "https://webprosindia.com/vignanit/Academics/studentacadamicregister.aspx?scrid=2";

  /// Calculate skippable hours
  static int _calculateSkippableHours(int present, int total) {
    if (total == 0 || (present / total) * 100 < 75.0) {
      return 0;
    }
    int skippable = 0;
    int tempPresent = present;
    int tempTotal = total;
    while (true) {
      tempTotal++;
      if ((tempPresent / tempTotal) * 100 >= 75.0) {
        skippable++;
      } else {
        break;
      }
    }
    return skippable;
  }

  /// Calculate required hours
  static int _calculateRequiredHours(int present, int total) {
    if (total == 0 || (present / total) * 100 >= 75.0) {
      return 0;
    }
    int required = 0;
    int tempPresent = present;
    int tempTotal = total;
    while (true) {
      tempPresent++;
      tempTotal++;
      required++;
      if ((tempPresent / tempTotal) * 100 >= 75.0) {
        break;
      }
    }
    return required;
  }

  static Future<AttendanceData> fetch({
    required String username,
    required String password,
  }) async {
    final client = await AuthHelper.authenticate(username, password);

    try {
      final response = await client.get(Uri.parse(_attendanceUrl));
      final document = html_parser.parse(response.body);

      final today = DateFormat('dd/MM').format(DateTime.now());
      int totalPresent = 0, totalClasses = 0;
      List<String> todaysAttendance = [];
      List<String> subjectAttendance = [];

      // Find today's column index (matches Go implementation)
      final headerRow = document.querySelector(
        "tr.reportHeading2WithBackground",
      );
      List<String> headers = [];
      if (headerRow != null) {
        headerRow.querySelectorAll("td").forEach((cell) {
          headers.add(cell.text.trim());
        });
      }

      int todayIndex = -1;
      for (int i = 0; i < headers.length; i++) {
        if (headers[i].contains(today)) {
          todayIndex = i;
          break;
        }
      }

      // Parse attendance data (matches Go implementation exactly)
      document.querySelectorAll("tr[title]").forEach((row) {
        final cells = row.querySelectorAll("td.cellBorder");
        if (cells.length < 2) return;

        final subject = cells[1].text.trim();
        final attendance = cells[cells.length - 2].text.trim();
        final percent = cells[cells.length - 1].text.trim();

        int present = 0, total = 0;
        if (attendance.contains('/')) {
          final parts = attendance.split('/');
          if (parts.length == 2) {
            present = int.tryParse(parts[0].trim()) ?? 0;
            total = int.tryParse(parts[1].trim()) ?? 0;
          }
        }
        totalPresent += present;
        totalClasses += total;

        // Extract today's attendance
        if (todayIndex != -1 && todayIndex < cells.length) {
          final todayText = cells[todayIndex].text.trim();
          List<String> statuses = [];
          todayText.split(' ').forEach((s) {
            if (s == 'P' || s == 'A') {
              statuses.add(s);
            }
          });
          if (statuses.isNotEmpty) {
            todaysAttendance.add('$subject: ${statuses.join(' ')}');
          }
        }

        // Format exactly like Go version
        subjectAttendance.add(
          '${subject.padRight(20)} ${attendance.padLeft(7)} $percent',
        );
      });

      double overallPercentage = totalClasses > 0
          ? (totalPresent / totalClasses) * 100
          : 0.0;

      int skippableHours = _calculateSkippableHours(totalPresent, totalClasses);
      int requiredHours = _calculateRequiredHours(totalPresent, totalClasses);

      return AttendanceData(
        studentId: username,
        totalPresent: totalPresent,
        totalClasses: totalClasses,
        overallPercentage: overallPercentage,
        todaysAttendance: todaysAttendance,
        subjectAttendance: subjectAttendance,
        skippableHours: skippableHours,
        requiredHours: requiredHours,
      );
    } finally {
      client.close();
    }
  }
}
