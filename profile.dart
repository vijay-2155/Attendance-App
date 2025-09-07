import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
// REMOVED: package_info_plus is no longer needed
import 'package:url_launcher/url_launcher.dart'; // For opening the update URL
import 'config.dart';
import 'database.dart';
import 'start.dart';

class ProfilePage extends StatefulWidget {
  const ProfilePage({super.key});

  @override
  State<ProfilePage> createState() => _ProfilePageState();
}

class _ProfilePageState extends State<ProfilePage> {
  final _usernameController = TextEditingController();
  final _passwordController = TextEditingController();
  final _formKey = GlobalKey<FormState>();
  bool _isPasswordVisible = false;

  // --- REFACTORED: Using simple boolean flags for state management ---
  bool _isUpdateAvailable = false;
  // --- UPDATED: Get the current version directly from AppConfig ---
  final String _currentVersion = AppConfig.currentAppVersion;
  String _latestVersion = '';
  bool _isCheckingForUpdate = true;
  String _updateError = '';

  final Color backgroundColor = const Color(0xFF0F172A);
  final Color cardColor = const Color(0xFF1E293B);
  final Color textColor = Colors.white;
  final Color secondaryTextColor = const Color(0xFF94A3B8);
  final Color primaryColor = const Color(0xFF00A9FF);

  @override
  void initState() {
    super.initState();
    _loadCredentials();
    _checkForUpdate();
  }

  /// --- UPDATED: This function no longer uses the package_info_plus package ---
  Future<void> _checkForUpdate() async {
    setState(() {
      _isCheckingForUpdate = true;
      _updateError = '';
    });

    try {
      await AppConfig.fetchAndSetup();

      if (mounted) {
        setState(() {
          _latestVersion = AppConfig.latestVersion;
          _isUpdateAvailable = _latestVersion.compareTo(_currentVersion) > 0;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _updateError = 'Failed to check for updates.';
        });
      }
    } finally {
      if (mounted) {
        setState(() {
          _isCheckingForUpdate = false;
        });
      }
    }
  }

  Future<void> _loadCredentials() async {
    final credentials = await DatabaseHelper.instance.getCredentials();
    if (credentials != null) {
      _usernameController.text = credentials.username;
      _passwordController.text = credentials.password;
    }
  }

  Future<void> _handleUpdateCredentials() async {
    if (_formKey.currentState!.validate()) {
      final newCredentials = UserCredentials(
        username: _usernameController.text,
        password: _passwordController.text,
      );
      await DatabaseHelper.instance.saveCredentials(newCredentials);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          backgroundColor: Colors.green,
          content: Text(
            'Credentials Updated Successfully!',
            style: GoogleFonts.poppins(),
          ),
        ),
      );
      Navigator.of(context).pop();
    }
  }

  Future<void> _handleLogout() async {
    final bool? shouldLogout = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: cardColor,
        title: Text(
          'Confirm Logout',
          style: GoogleFonts.poppins(color: textColor),
        ),
        content: Text(
          'Are you sure you want to log out?',
          style: GoogleFonts.poppins(color: secondaryTextColor),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: Text(
              'Cancel',
              style: GoogleFonts.poppins(color: secondaryTextColor),
            ),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: Text(
              'Logout',
              style: GoogleFonts.poppins(color: Colors.redAccent),
            ),
          ),
        ],
      ),
    );

    if (shouldLogout == true) {
      await DatabaseHelper.instance.deleteCredentials();
      Navigator.of(context).pushAndRemoveUntil(
        MaterialPageRoute(builder: (context) => const StartPage()),
        (Route<dynamic> route) => false,
      );
    }
  }

  Future<void> _launchUpdateURL() async {
    final Uri url = Uri.parse(AppConfig.updateUrl);
    if (!await launchUrl(url, mode: LaunchMode.externalApplication)) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          backgroundColor: Colors.redAccent,
          content: Text(
            'Could not launch update URL',
            style: GoogleFonts.poppins(),
          ),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: backgroundColor,
      appBar: AppBar(
        title: Text(
          'Profile & Settings',
          style: GoogleFonts.poppins(color: textColor),
        ),
        backgroundColor: backgroundColor,
        elevation: 0,
        actions: [
          IconButton(
            tooltip: 'Check for update',
            icon: Icon(Icons.cloud_sync_outlined, color: secondaryTextColor),
            onPressed: _isCheckingForUpdate ? null : _checkForUpdate,
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              'App Version',
              style: GoogleFonts.poppins(
                fontSize: 20,
                fontWeight: FontWeight.w600,
                color: textColor,
              ),
            ),
            const SizedBox(height: 8),

            _buildUpdateSection(),

            const Divider(color: Colors.white24, height: 60),

            Text(
              'Update Saved Credentials',
              style: GoogleFonts.poppins(
                fontSize: 20,
                fontWeight: FontWeight.w600,
                color: textColor,
              ),
            ),
            const SizedBox(height: 24),
            Form(
              key: _formKey,
              child: Column(
                children: [
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
                ],
              ),
            ),
            const SizedBox(height: 32),
            SizedBox(
              width: double.infinity,
              height: 56,
              child: ElevatedButton.icon(
                onPressed: _handleUpdateCredentials,
                icon: const Icon(Icons.save_alt_outlined),
                label: const Text('Update Credentials'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: primaryColor,
                  foregroundColor: Colors.white,
                  textStyle: GoogleFonts.poppins(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                ),
              ),
            ),
            const Divider(color: Colors.white24, height: 60),
            SizedBox(
              width: double.infinity,
              height: 56,
              child: ElevatedButton.icon(
                onPressed: _handleLogout,
                icon: const Icon(Icons.logout),
                label: const Text('Log Out & Clear Data'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.red.shade400.withOpacity(0.2),
                  foregroundColor: Colors.red.shade300,
                  textStyle: GoogleFonts.poppins(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                  elevation: 0,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildUpdateSection() {
    if (_isCheckingForUpdate) {
      return const Center(
        child: Padding(
          padding: EdgeInsets.all(8.0),
          child: CircularProgressIndicator(),
        ),
      );
    }

    if (_updateError.isNotEmpty) {
      return Text(
        _updateError,
        style: GoogleFonts.poppins(color: Colors.redAccent),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'You are running version $_currentVersion. Latest is $_latestVersion.',
          style: GoogleFonts.poppins(color: secondaryTextColor),
        ),
        const SizedBox(height: 16),
        if (_isUpdateAvailable)
          SizedBox(
            width: double.infinity,
            height: 56,
            child: ElevatedButton.icon(
              onPressed: _launchUpdateURL,
              icon: const Icon(Icons.system_update),
              label: Text('Update to v$_latestVersion'),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.green.shade400,
                foregroundColor: Colors.white,
                textStyle: GoogleFonts.poppins(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                ),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
              ),
            ),
          )
        else
          Text(
            'You have the latest version.',
            style: GoogleFonts.poppins(color: Colors.green.shade300),
          ),
      ],
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
      fillColor: cardColor,
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(16),
        borderSide: BorderSide.none,
      ),
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
