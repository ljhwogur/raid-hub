import 'package:flutter/material.dart'; // Import for ChangeNotifier
import 'package:http/http.dart' as http;
import 'package:http/browser_client.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';

class AuthService extends ChangeNotifier { // Extend ChangeNotifier
  static final AuthService _instance = AuthService._internal();
  factory AuthService() => _instance;
  AuthService._internal();

  String? _sessionCookie;
  String? _username;
  String? _role; // To store the user's role if available
  String? _loginErrorMessage; // To store login error message
  final http.Client _client = BrowserClient()..withCredentials = true;

  static const String _sessionIdKey = 'session_id';
  static const String _usernameKey = 'username';

  final String _baseUrl = 'http://localhost:8080';

  bool get isAuthenticated => _sessionCookie != null;
  String? get username => _username;
  bool get isAdmin => _role == 'ADMIN'; // Simple role check
  String? get loginErrorMessage => _loginErrorMessage;

  Future<void> initialize() async {
    final prefs = await SharedPreferences.getInstance();
    final String? sessionId = prefs.getString(_sessionIdKey);
    final String? storedUsername = prefs.getString(_usernameKey);

    if (sessionId != null && storedUsername != null) {
      _sessionCookie = 'JSESSIONID=$sessionId';
      _username = storedUsername;
      _role = storedUsername == 'admin' ? 'ADMIN' : 'USER';
      notifyListeners();
    }
  }

  Future<bool> checkUsernameAvailability(String username) async {
    final Uri checkUri = Uri.parse('$_baseUrl/api/users/check-username/$username');

    try {
      final response = await _client.get(
        checkUri,
        headers: <String, String>{
          'Content-Type': 'application/json',
        },
      );

      if (response.statusCode == 200) {
        final Map<String, dynamic> responseBody = jsonDecode(response.body);
        bool exists = responseBody['exists'] ?? false;
        return !exists;
      } else {
        print('Check username failed: ${response.statusCode} - ${response.body}');
        return false;
      }
    } catch (e) {
      print('Error checking username availability: $e');
      return false;
    }
  }

  Future<bool> register(String username, String password) async {
    final Uri registerUri = Uri.parse('$_baseUrl/api/users/register');

    try {
      final response = await _client.post(
        registerUri,
        headers: <String, String>{
          'Content-Type': 'application/json',
        },
        body: jsonEncode({
          'username': username,
          'password': password,
        }),
      );

      if (response.statusCode == 201 || response.statusCode == 200) {
        print('Registration successful');
        return true;
      } else {
        print('Registration failed: ${response.statusCode} - ${response.body}');
        return false;
      }
    } catch (e) {
      print('Error during registration: $e');
      return false;
    }
  }

  Future<bool> login(String username, String password) async {
    final Uri loginUri = Uri.parse('$_baseUrl/login');

    try {
      final response = await _client.post(
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
        final Map<String, dynamic> responseBody = jsonDecode(response.body);
        final String? sessionId = responseBody['sessionId'];

        if (sessionId != null) {
          _sessionCookie = 'JSESSIONID=$sessionId';
          _username = username;
          if (username == 'admin') {
            _role = 'ADMIN';
          } else {
            _role = 'USER';
          }
          await _persistSession(sessionId, username);
          _loginErrorMessage = null;
          print('Login successful. Session ID: $sessionId, Role: $_role');
          notifyListeners(); // Notify listeners of state change
          return true;
        }
        _loginErrorMessage = '다시 시도해주세요';
        return false; // No session ID received
      } else {
        // Try to parse error message from response
        try {
          final Map<String, dynamic> errorBody = jsonDecode(response.body);
          _loginErrorMessage = errorBody['message'] ?? '아이디 또는 비밀번호를 확인하세요.';
        } catch (e) {
          _loginErrorMessage = '아이디 또는 비밀번호를 확인하세요.';
        }
        print('Login failed: ${response.statusCode} - ${response.body}');
        _sessionCookie = null;
        _username = null;
        _role = null;
        await _clearSession();
        notifyListeners(); // Notify listeners of state change
        return false;
      }
    } catch (e) {
      print('Error during login: $e');
      _loginErrorMessage = '로그인 실패: $e';
      _sessionCookie = null;
      _username = null;
      _role = null;
      await _clearSession();
      notifyListeners(); // Notify listeners of state change
      return false;
    }
  }

  void logout() {
    _sessionCookie = null;
    _username = null;
    _role = null;
    print('Logged out.');
    _clearSession();
    notifyListeners(); // Notify listeners of state change
    // TODO: Optionally send a logout request to the backend if needed
  }

  // Helper method to get headers with session cookie for authenticated requests
  Map<String, String> getAuthHeaders() {
    return {
      'Content-Type': 'application/json',
    };
  }

  Future<void> _persistSession(String sessionId, String username) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_sessionIdKey, sessionId);
    await prefs.setString(_usernameKey, username);
  }

  Future<void> _clearSession() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_sessionIdKey);
    await prefs.remove(_usernameKey);
  }
}
