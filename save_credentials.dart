import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:flutter_spinkit/flutter_spinkit.dart';
import 'dart:async';
import 'database.dart'; // For saving credentials and data
import 'fetcher.dart'; // For fetching data from the API
import 'home.dart'; // For navigation after setup

class SaveCredentialsPage extends StatefulWidget {
  const SaveCredentialsPage({super.key});

  @override
  State<SaveCredentialsPage> createState() => _SaveCredentialsPageState();
}

class _SaveCredentialsPageState extends State<SaveCredentialsPage> {
  // Controllers and form key
  final _usernameController = TextEditingController();
  final _passwordController = TextEditingController();
  final _formKey = GlobalKey<FormState>();

  // State variables
  bool _isPasswordVisible = false;
  bool _isLoading = false;

  // --- UI Colors ---
  final Color primaryColor = const Color(0xFF00A9FF);
  final Color backgroundColor = const Color(0xFF0F172A);
  final Color textColor = Colors.white;
  final Color secondaryTextColor = const Color(0xFF94A3B8);
  final Color fieldBackgroundColor = const Color(0xFF1E293B);
  final Color errorColor = const Color(0xFFF87171);

  @override
  void dispose() {
    _usernameController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  /// --- Enhanced Save & Fetch Logic ---
  /// Saves credentials, fetches initial data, and then navigates.
  void _handleSaveAndSetup() async {
    if (!_formKey.currentState!.validate()) {
      return; // If form is invalid, do nothing.
    }

    setState(() => _isLoading = true);

    try {
      final username = _usernameController.text;
      final password = _passwordController.text;

      // 1. Save the credentials to the database
      final credentials = UserCredentials(
        username: username,
        password: password,
      );
      await DatabaseHelper.instance.saveCredentials(credentials);
      print('Credentials saved.');

      // 2. Fetch initial attendance and schedule data from the API
      print('Fetching initial data...');
      // --- UPDATED: Using ApiClient instead of ApiFetcher ---
      final results = await Future.wait([
        ApiClient.fetchAttendance(username: username, password: password),
        ApiClient.fetchSchedule(username: username, password: password),
      ]);

      final attendanceData = results[0] as AttendanceData;
      final scheduleData = results[1] as ScheduleData;

      // 3. Save the fetched data to the database
      await DatabaseHelper.instance.saveAttendance(attendanceData);
      await DatabaseHelper.instance.saveSchedule(scheduleData);
      print('Initial data saved to database.');

      // 4. Show success and navigate to the home page
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          backgroundColor: Colors.green,
          content: Text('Setup Complete!', style: GoogleFonts.poppins()),
        ),
      );

      Navigator.of(context).pushAndRemoveUntil(
        MaterialPageRoute(builder: (context) => const HomePage()),
        (Route<dynamic> route) => false,
      );
    } catch (e) {
      // Handle any errors during the process (e.g., wrong credentials, network issue)
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          backgroundColor: errorColor,
          content: Text(
            'Setup Failed: ${e.toString()}',
            style: GoogleFonts.poppins(),
          ),
        ),
      );
    } finally {
      // Ensure the loading indicator is turned off
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
          'Account Setup',
          style: GoogleFonts.poppins(
            color: textColor,
            fontWeight: FontWeight.w500,
          ),
        ),
        backgroundColor: backgroundColor,
        elevation: 0,
        leading: IconButton(
          icon: Icon(Icons.arrow_back_ios_new, color: textColor),
          onPressed: () => Navigator.of(context).pop(),
        ),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 24.0),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const SizedBox(height: 40),
                Container(
                  padding: const EdgeInsets.all(24),
                  decoration: BoxDecoration(
                    color: const Color(0xFF1E3A5F),
                    borderRadius: BorderRadius.circular(24),
                  ),
                  // --- FIXED: Removed the color property to fix the white box issue ---
                  child: Image.asset('static/images/image.png', height: 80),
                ),
                const SizedBox(height: 50),
                Text(
                  'Enter your credentials',
                  textAlign: TextAlign.center,
                  style: GoogleFonts.poppins(
                    color: textColor,
                    fontSize: 22,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 30),
                TextFormField(
                  controller: _usernameController,
                  style: GoogleFonts.poppins(color: textColor),
                  decoration: _buildInputDecoration('Username'),
                  validator: (value) =>
                      value!.isEmpty ? 'Please enter a username' : null,
                ),
                const SizedBox(height: 20),
                TextFormField(
                  controller: _passwordController,
                  obscureText: !_isPasswordVisible,
                  style: GoogleFonts.poppins(color: textColor),
                  decoration: _buildInputDecoration(
                    'Password',
                    isPassword: true,
                  ),
                  validator: (value) =>
                      value!.isEmpty ? 'Please enter a password' : null,
                ),
                const SizedBox(height: 50),
                SizedBox(
                  height: 56,
                  child: ElevatedButton(
                    onPressed: _isLoading ? null : _handleSaveAndSetup,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: primaryColor,
                      disabledBackgroundColor: primaryColor.withOpacity(0.5),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                      ),
                      elevation: 0,
                    ),
                    child: _isLoading
                        ? const SpinKitThreeBounce(
                            color: Colors.white,
                            size: 25.0,
                          )
                        : Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              const Icon(
                                Icons.login,
                                color: Colors.white,
                                size: 22,
                              ),
                              const SizedBox(width: 12),
                              Text(
                                'Save & Continue',
                                style: GoogleFonts.poppins(
                                  color: Colors.white,
                                  fontSize: 16,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ],
                          ),
                  ),
                ),
                const SizedBox(height: 20),
              ],
            ),
          ),
        ),
      ),
    );
  }

  InputDecoration _buildInputDecoration(
    String label, {
    bool isPassword = false,
  }) {
    return InputDecoration(
      labelText: label,
      labelStyle: GoogleFonts.poppins(color: secondaryTextColor),
      filled: true,
      fillColor: fieldBackgroundColor,
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(16),
        borderSide: BorderSide.none,
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(16),
        borderSide: BorderSide.none,
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(16),
        borderSide: BorderSide(color: primaryColor, width: 2),
      ),
      errorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(16),
        borderSide: BorderSide(color: errorColor, width: 1.5),
      ),
      focusedErrorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(16),
        borderSide: BorderSide(color: errorColor, width: 2),
      ),
      errorStyle: GoogleFonts.poppins(color: errorColor),
      suffixIcon: isPassword
          ? IconButton(
              icon: Icon(
                _isPasswordVisible ? Icons.visibility_off : Icons.visibility,
                color: secondaryTextColor,
              ),
              onPressed: () =>
                  setState(() => _isPasswordVisible = !_isPasswordVisible),
            )
          : null,
    );
  }
}
