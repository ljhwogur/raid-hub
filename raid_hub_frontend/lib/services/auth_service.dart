import 'package:flutter/material.dart'; // Import for ChangeNotifier
import 'package:http/http.dart' as http;

class AuthService extends ChangeNotifier { // Extend ChangeNotifier
  static final AuthService _instance = AuthService._internal();
  factory AuthService() => _instance;
  AuthService._internal();

  String? _sessionCookie;
  String? _username;
  String? _role; // To store the user's role if available

  final String _baseUrl = 'http://localhost:8080';

  bool get isAuthenticated => _sessionCookie != null;
  String? get username => _username;
  bool get isAdmin => _role == 'ADMIN'; // Simple role check

  Future<bool> login(String username, String password) async {
    final Uri loginUri = Uri.parse('$_baseUrl/login');

    try {
      final response = await http.post(
        loginUri,
        headers: <String, String>{
          'Content-Type': 'application/x-www-form-urlencoded',
        },
        body: {
          'username': username,
          'password': password,
        },
      );

      if (response.statusCode == 200) {
        // Login successful
        String? rawCookie = response.headers['set-cookie'];
        if (rawCookie != null) {
          int index = rawCookie.indexOf(';');
          _sessionCookie = (index == -1) ? rawCookie : rawCookie.substring(0, index);
          _username = username;
          if (username == 'admin') {
            _role = 'ADMIN';
          } else {
            _role = 'USER';
          }
          print('Login successful. Session Cookie: $_sessionCookie, Role: $_role');
          notifyListeners(); // Notify listeners of state change
          return true;
        }
        return false; // No cookie received
      } else {
        print('Login failed: ${response.statusCode} - ${response.body}');
        _sessionCookie = null;
        _username = null;
        _role = null;
        notifyListeners(); // Notify listeners of state change
        return false;
      }
    } catch (e) {
      print('Error during login: $e');
      _sessionCookie = null;
      _username = null;
      _role = null;
      notifyListeners(); // Notify listeners of state change
      return false;
    }
  }

  void logout() {
    _sessionCookie = null;
    _username = null;
    _role = null;
    print('Logged out.');
    notifyListeners(); // Notify listeners of state change
    // TODO: Optionally send a logout request to the backend if needed
  }

  // Helper method to get headers with session cookie for authenticated requests
  Map<String, String> getAuthHeaders() {
    if (_sessionCookie != null) {
      return {
        'Cookie': _sessionCookie!,
        'Content-Type': 'application/json',
      };
    }
    return {
      'Content-Type': 'application/json',
    };
  }
}
