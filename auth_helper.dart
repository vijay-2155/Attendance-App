import 'package:encrypt/encrypt.dart' as encrypt;
import 'package:html/parser.dart' as html_parser;
import 'package:http/http.dart' as http;

/// Simplified auth helper that matches the working Go implementation
class AuthHelper {
  static const String _loginUrl =
      "https://webprosindia.com/vignanit/Default.aspx";

  static const Duration _requestTimeout = Duration(seconds: 30);

  /// Encrypts the password using AES with PKCS7 padding.
  static String _encryptPassword(String plainText) {
    final key = encrypt.Key.fromUtf8('8701661282118308');
    final iv = encrypt.IV.fromUtf8('8701661282118308');
    final encrypter = encrypt.Encrypter(
      encrypt.AES(key, mode: encrypt.AESMode.cbc),
    );
    final encrypted = encrypter.encrypt(plainText, iv: iv);
    return encrypted.base64;
  }

  /// Extracts hidden form fields required for ASP.NET postback
  static Map<String, String> _extractHiddenFields(String html) {
    final document = html_parser.parse(html);

    final viewState = document
        .querySelector('input[name="__VIEWSTATE"]')
        ?.attributes['value'];
    final eventValidation = document
        .querySelector('input[name="__EVENTVALIDATION"]')
        ?.attributes['value'];

    if (viewState == null || eventValidation == null) {
      throw Exception('Could not find hidden fields for login.');
    }

    return {'__VIEWSTATE': viewState, '__EVENTVALIDATION': eventValidation};
  }

  /// Authenticates the user and returns an http.Client with active session cookies.
  /// This matches the Go implementation exactly.
  static Future<http.Client> authenticate(
    String username,
    String password,
  ) async {
    final client = http.Client();

    try {
      // Step 1: Get login page
      final response = await client.get(Uri.parse(_loginUrl));
      if (response.statusCode != 200) {
        throw Exception('Failed to load login page.');
      }

      // Step 2: Extract hidden fields
      final hiddenFields = _extractHiddenFields(response.body);

      // Step 3: Encrypt password
      final encryptedPassword = _encryptPassword(password);

      // Step 4: Prepare login data (exactly like Go version)
      final loginData = {
        ...hiddenFields,
        'txtId2': username,
        'hdnpwd2': encryptedPassword,
        'imgBtn2.x': '25',
        'imgBtn2.y': '10',
      };

      // Step 5: Submit login form
      final loginResponse = await client.post(
        Uri.parse(_loginUrl),
        headers: {
          'Content-Type': 'application/x-www-form-urlencoded',
          'User-Agent': 'Mozilla/5.0',
        },
        body: loginData.entries
            .map(
              (e) =>
                  '${Uri.encodeComponent(e.key)}=${Uri.encodeComponent(e.value)}',
            )
            .join('&'),
      );

      // Step 6: Check for login errors (exactly like Go version)
      if (loginResponse.body.contains("Invalid Username")) {
        throw Exception('Invalid username or password.');
      }

      // Step 7: Return the authenticated client
      return client;
    } catch (e) {
      client.close();
      rethrow;
    }
  }
}
