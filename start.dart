import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

// --- ADDED: Imports for the pages we need to navigate to ---
import 'quick_check.dart';
import 'save_credentials.dart';

/*
  -----------------------------------------------------------------------------
  Hey! Before you run this, make sure to add the following to your
  `pubspec.yaml` file to include the custom font and the logo image:

  dependencies:
    flutter:
      sdk: flutter
    google_fonts: ^6.2.1 # Or the latest version

  flutter:
    uses-material-design: true
    assets:
      - static/images/ # Make sure your logo is here

  Then, run `flutter pub get` in your terminal.
  The logo path is set to 'static/images/image.png' as you requested.
  -----------------------------------------------------------------------------
*/

class StartPage extends StatelessWidget {
  const StartPage({super.key});

  @override
  Widget build(BuildContext context) {
    // Define our color scheme for a modern look
    const Color primaryColor = Color(0xFF00A9FF);
    const Color backgroundColor = Color(0xFF0F172A); // A deep, cool blue
    const Color textColor = Colors.white;
    const Color secondaryTextColor = Color(
      0xFF94A3B8,
    ); // A softer white for subtitles

    return Scaffold(
      backgroundColor: backgroundColor,
      body: SafeArea(
        child: SingleChildScrollView(
          child: ConstrainedBox(
            constraints: BoxConstraints(
              // Ensures the content takes at least the full height of the screen
              minHeight:
                  MediaQuery.of(context).size.height -
                  MediaQuery.of(context).padding.top -
                  MediaQuery.of(context).padding.bottom,
            ),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24.0),
              // --- FIXED: Replaced Spacer widgets with a more robust layout ---
              // Using MainAxisAlignment.spaceBetween is more reliable inside a scroll view.
              child: Column(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // --- Top Content Group ---
                  Column(
                    children: [
                      const SizedBox(height: 60), // Top padding
                      Image.asset('static/images/image.png', height: 120),
                      const SizedBox(height: 24),
                      Text(
                        'Track It',
                        textAlign: TextAlign.center,
                        style: GoogleFonts.poppins(
                          color: textColor,
                          fontSize: 36,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(height: 12),
                      Text(
                        'Quickly check your attendance or set up your account.',
                        textAlign: TextAlign.center,
                        style: GoogleFonts.poppins(
                          color: secondaryTextColor,
                          fontSize: 16,
                          fontWeight: FontWeight.w400,
                        ),
                      ),
                    ],
                  ),

                  // --- Bottom Content Group ---
                  Column(
                    children: [
                      _buildStyledButton(
                        text: 'Quick Check',
                        icon: Icons.flash_on,
                        onPressed: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) => const QuickCheckPage(),
                            ),
                          );
                        },
                        backgroundColor: primaryColor,
                        textColor: Colors.white,
                      ),
                      const SizedBox(height: 16),
                      _buildStyledButton(
                        text: 'Setup Account',
                        icon: Icons.settings,
                        onPressed: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) => const SaveCredentialsPage(),
                            ),
                          );
                        },
                        backgroundColor: Colors.transparent,
                        textColor: primaryColor,
                        isOutlined: true,
                      ),
                      const SizedBox(height: 60), // Bottom padding
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  /// A helper method to build our consistently styled buttons.
  Widget _buildStyledButton({
    required String text,
    required IconData icon,
    required VoidCallback onPressed,
    required Color backgroundColor,
    required Color textColor,
    bool isOutlined = false,
  }) {
    return SizedBox(
      height: 56, // A modern, tappable height
      child: ElevatedButton(
        onPressed: onPressed,
        style: ElevatedButton.styleFrom(
          backgroundColor: backgroundColor,
          elevation: 0,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16), // More rounded corners
            side: isOutlined
                ? const BorderSide(color: Color(0xFF00A9FF), width: 2)
                : BorderSide.none,
          ),
          padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 20),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, color: textColor, size: 22),
            const SizedBox(width: 12),
            Text(
              text,
              style: GoogleFonts.poppins(
                color: textColor,
                fontSize: 16,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
