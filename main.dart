import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import 'config.dart'; // For fetching remote configuration
import 'database.dart'; // For checking saved credentials
import 'home.dart'; // The main dashboard page
import 'start.dart'; // The initial start/welcome page

void main() async {
  // --- Step 1: Ensure Flutter is ready ---
  // This is required before you can use async/await in main.
  WidgetsFlutterBinding.ensureInitialized();

  // --- Step 2: Fetch remote configuration ---
  // This gets your API URL and other settings from your GitHub file.
  await AppConfig.fetchAndSetup();

  // --- Step 3: Check if user credentials exist ---
  // This determines which page to show first.
  final credentials = await DatabaseHelper.instance.getCredentials();

  // --- Step 4: Run the app ---
  // Pass the result of the credential check to MyApp.
  runApp(MyApp(isLoggedIn: credentials != null));
}

class MyApp extends StatelessWidget {
  final bool isLoggedIn;

  const MyApp({super.key, required this.isLoggedIn});

  @override
  Widget build(BuildContext context) {
    // Define the core theme for the entire application
    final ThemeData theme = ThemeData(
      brightness: Brightness.dark,
      scaffoldBackgroundColor: const Color(0xFF0F172A),
      primaryColor: const Color(0xFF00A9FF),
      textTheme: GoogleFonts.poppinsTextTheme(ThemeData.dark().textTheme),
      appBarTheme: const AppBarTheme(
        elevation: 0,
        backgroundColor: Color(0xFF0F172A),
      ),
    );

    return MaterialApp(
      title: 'Track It',
      theme: theme,
      debugShowCheckedModeBanner: false,
      // --- Step 5: Set the initial page ---
      // If isLoggedIn is true, go to HomePage. Otherwise, go to StartPage.
      home: isLoggedIn ? const HomePage() : const StartPage(),
    );
  }
}
