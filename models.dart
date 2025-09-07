// This file contains the data models for your app.
// It has no Flutter dependencies, so it can be used in pure Dart scripts.

class AttendanceData {
  final String studentId;
  final int totalPresent;
  final int totalClasses;
  final double overallPercentage;
  final List<String> todaysAttendance;
  final List<String> subjectAttendance;
  final int skippableHours;
  final int requiredHours;

  AttendanceData({
    required this.studentId,
    required this.totalPresent,
    required this.totalClasses,
    required this.overallPercentage,
    required this.todaysAttendance,
    required this.subjectAttendance,
    required this.skippableHours,
    required this.requiredHours,
  });

  factory AttendanceData.fromMap(Map<String, dynamic> map) {
    return AttendanceData(
      studentId: map['student_id'] ?? '',
      totalPresent: map['total_present'] ?? 0,
      totalClasses: map['total_classes'] ?? 0,
      overallPercentage: (map['overall_percentage'] as num?)?.toDouble() ?? 0.0,
      todaysAttendance: List<String>.from(map['todays_attendance'] ?? []),
      subjectAttendance: List<String>.from(map['subject_attendance'] ?? []),
      skippableHours: map['skippable_hours'] ?? 0,
      requiredHours: map['required_hours'] ?? 0,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'student_id': studentId,
      'total_present': totalPresent,
      'total_classes': totalClasses,
      'overall_percentage': overallPercentage,
      'todays_attendance': todaysAttendance,
      'subject_attendance': subjectAttendance,
      'skippable_hours': skippableHours,
      'required_hours': requiredHours,
    };
  }
}

class ScheduleData {
  final String studentId;
  final List<dynamic> schedule;
  final List<dynamic> subjects;

  ScheduleData({
    required this.studentId,
    required this.schedule,
    required this.subjects,
  });

  factory ScheduleData.fromMap(Map<String, dynamic> map) {
    return ScheduleData(
      studentId: map['student_id'] ?? '',
      schedule: List<dynamic>.from(map['schedule'] ?? []),
      subjects: List<dynamic>.from(map['subjects'] ?? []),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'student_id': studentId,
      'schedule': schedule,
      'subjects': subjects,
    };
  }
}
