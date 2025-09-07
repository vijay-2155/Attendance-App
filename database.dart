import 'dart:convert'; // Required for jsonEncode and jsonDecode
import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';
import 'dart:async';

/*
  -----------------------------------------------------------------------------
  Hey! Before you run this, make sure to add the following to your
  `pubspec.yaml` file to use SQLite:

  dependencies:
    flutter:
      sdk: flutter
    sqflite: ^2.3.3+1 # Or the latest version
    path: ^1.9.0

  Then, run `flutter pub get` in your terminal.
  -----------------------------------------------------------------------------
*/

// --- Data Models ---

class UserCredentials {
  final int? id;
  final String username;
  final String password;

  UserCredentials({this.id, required this.username, required this.password});

  Map<String, dynamic> toMap() {
    return {'id': id, 'username': username, 'password': password};
  }
}

/// Model for the entire attendance JSON response.
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

  /// Creates an AttendanceData object from a Map (usually from JSON).
  factory AttendanceData.fromMap(Map<String, dynamic> map) {
    return AttendanceData(
      studentId: map['student_id'],
      totalPresent: map['total_present'],
      totalClasses: map['total_classes'],
      overallPercentage: (map['overall_percentage'] as num).toDouble(),
      todaysAttendance: List<String>.from(map['todays_attendance']),
      subjectAttendance: List<String>.from(map['subject_attendance']),
      skippableHours: map['skippable_hours'],
      requiredHours: map['required_hours'],
    );
  }

  /// Converts the AttendanceData object to a Map for database storage.
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

/// Model for the entire schedule JSON response.
class ScheduleData {
  final String studentId;
  final List<dynamic> schedule;
  final List<dynamic> subjects;

  ScheduleData({
    required this.studentId,
    required this.schedule,
    required this.subjects,
  });

  /// Creates a ScheduleData object from a Map.
  factory ScheduleData.fromMap(Map<String, dynamic> map) {
    return ScheduleData(
      studentId: map['student_id'],
      schedule: List<dynamic>.from(map['schedule']),
      subjects: List<dynamic>.from(map['subjects']),
    );
  }

  /// Converts the ScheduleData object to a Map.
  Map<String, dynamic> toMap() {
    return {
      'student_id': studentId,
      'schedule': schedule,
      'subjects': subjects,
    };
  }
}

// --- Database Helper ---

class DatabaseHelper {
  DatabaseHelper._privateConstructor();
  static final DatabaseHelper instance = DatabaseHelper._privateConstructor();
  static Database? _database;

  Future<Database> get database async {
    if (_database != null) return _database!;
    _database = await _initDatabase();
    return _database!;
  }

  _initDatabase() async {
    String path = join(await getDatabasesPath(), 'trackit_database.db');
    return await openDatabase(
      path,
      version: 2, // <--- IMPORTANT: Incremented version for the schema change
      onCreate: _onCreate,
      onUpgrade: _onUpgrade, // <--- IMPORTANT: Added upgrade logic
    );
  }

  // This runs ONLY the first time the database is created.
  Future _onCreate(Database db, int version) async {
    await _createTables(db);
  }

  // This runs when the database version is increased.
  Future _onUpgrade(Database db, int oldVersion, int newVersion) async {
    // In a real app, you'd migrate data. For here, we'll just recreate.
    await db.execute("DROP TABLE IF EXISTS credentials");
    await db.execute("DROP TABLE IF EXISTS attendance");
    await db.execute("DROP TABLE IF EXISTS schedule");
    await _createTables(db);
  }

  // Centralized method to create all tables.
  Future<void> _createTables(Database db) async {
    await db.execute('''
      CREATE TABLE credentials (
        id INTEGER PRIMARY KEY,
        username TEXT NOT NULL,
        password TEXT NOT NULL
      )
    ''');
    await db.execute('''
      CREATE TABLE attendance (
        id INTEGER PRIMARY KEY,
        data TEXT NOT NULL
      )
    ''');
    await db.execute('''
      CREATE TABLE schedule (
        id INTEGER PRIMARY KEY,
        data TEXT NOT NULL
      )
    ''');
  }

  // --- CRUD Operations ---

  // == Credentials ==
  Future<void> saveCredentials(UserCredentials credentials) async {
    final db = await instance.database;
    await db.delete('credentials');
    await db.insert(
      'credentials',
      credentials.toMap(),
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
    print('Credentials saved for user: ${credentials.username}');
  }

  Future<UserCredentials?> getCredentials() async {
    final db = await instance.database;
    final List<Map<String, dynamic>> maps = await db.query('credentials');
    if (maps.isNotEmpty) {
      return UserCredentials(
        id: maps.first['id'],
        username: maps.first['username'],
        password: maps.first['password'],
      );
    }
    return null;
  }

  Future<void> deleteCredentials() async {
    final db = await instance.database;
    await db.delete('credentials');
    print('All credentials deleted.');
  }

  // == Attendance ==
  Future<void> saveAttendance(AttendanceData attendance) async {
    final db = await instance.database;
    // We store the entire JSON object as a string.
    String data = jsonEncode(attendance.toMap());
    await db.delete('attendance'); // Clear old data
    await db.insert('attendance', {
      'data': data,
    }, conflictAlgorithm: ConflictAlgorithm.replace);
    print('Latest attendance data saved.');
  }

  Future<AttendanceData?> getAttendance() async {
    final db = await instance.database;
    final List<Map<String, dynamic>> maps = await db.query('attendance');
    if (maps.isNotEmpty) {
      // We retrieve the string and decode it back into a Map.
      Map<String, dynamic> dataMap = jsonDecode(maps.first['data']);
      return AttendanceData.fromMap(dataMap);
    }
    return null;
  }

  // == Schedule ==
  Future<void> saveSchedule(ScheduleData schedule) async {
    final db = await instance.database;
    String data = jsonEncode(schedule.toMap());
    await db.delete('schedule'); // Clear old data
    await db.insert('schedule', {
      'data': data,
    }, conflictAlgorithm: ConflictAlgorithm.replace);
    print('Latest schedule data saved.');
  }

  Future<ScheduleData?> getSchedule() async {
    final db = await instance.database;
    final List<Map<String, dynamic>> maps = await db.query('schedule');
    if (maps.isNotEmpty) {
      Map<String, dynamic> dataMap = jsonDecode(maps.first['data']);
      return ScheduleData.fromMap(dataMap);
    }
    return null;
  }
}
