import 'dart:convert';
import 'package:http/http.dart' as http;
import 'dart:async'; // Import for TimeoutException

class AppConfig {
  AppConfig._();

  // --- THIS IS YOUR OFFICIAL APP VERSION ---
  // Manually update this constant before each new release build.
  static const String currentAppVersion = "1.1.0";

  // --- Configuration URL ---
  static const String _configUrl =
      'https://raw.githubusercontent.com/vijayjee10000-cloud/server/main/server.json';

  // --- REMOVED: Default API URL is no longer hardcoded ---

  // --- Static fields to hold the configuration ---
  static String apiUrl = ""; // Initialize as empty
  static String minimumRequiredVersion = "1.0.0";
  static bool isInMaintenance = false;
  static String latestVersion = "1.0.0";
  static String updateUrl = "";
  static bool showMessage = false;
  static String messageTitle = '';
  static String messageBody = '';

  /// Fetches the JSON from GitHub and sets up the configuration.
  static Future<void> fetchAndSetup() async {
    print('Fetching remote app configuration...');
    try {
      final uri = Uri.parse(
        '$_configUrl?cacheBust=${DateTime.now().millisecondsSinceEpoch}',
      );

      final response = await http.get(uri).timeout(const Duration(seconds: 5));

      if (response.statusCode == 200) {
        final configData = jsonDecode(response.body) as Map<String, dynamic>;

        // The app will now exclusively use the URL from the server.
        apiUrl = configData['api_base_url'] ?? '';
        minimumRequiredVersion =
            configData['minimum_required_version'] ?? '1.0.0';
        isInMaintenance = configData['maintenance_mode'] ?? false;
        latestVersion = configData['latest_version'] ?? '1.0.0';
        updateUrl = configData['update_url'] ?? '';
        showMessage = configData['show_message'] ?? false;
        messageTitle = configData['message_title'] ?? 'Notice';
        messageBody = configData['message_body'] ?? '';

        print('Remote config fetched successfully!');
      } else {
        print(
          'Failed to fetch remote config. Status code: ${response.statusCode}.',
        );
        apiUrl = ""; // Ensure API URL is empty on failure
      }
    } on TimeoutException {
      print('Error fetching remote config: The request timed out.');
      apiUrl = ""; // Ensure API URL is empty on failure
    } catch (e) {
      print('Error fetching remote config: $e.');
      apiUrl = ""; // Ensure API URL is empty on failure
    }
  }
}
