import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:http/browser_client.dart';
import '../models/raid_video.dart';
import '../models/playlist_item.dart';
import 'package:raid_hub_frontend/services/auth_service.dart'; // Import AuthService

class ApiService {
  final String baseUrl = "http://localhost:8080/api/videos";
  final AuthService _authService = AuthService(); // Get the AuthService instance
  final http.Client _client = BrowserClient()..withCredentials = true;

  Future<List<RaidVideo>> getVideos() async {
    try {
      final response = await _client.get(
        Uri.parse(baseUrl),
        headers: _authService.getAuthHeaders(), // Include auth headers
      );

      if (response.statusCode == 200) {
        // UTF-8 디코딩 처리 (한글 깨짐 방지)
        List<dynamic> body = jsonDecode(utf8.decode(response.bodyBytes));
        return body.map((dynamic item) => RaidVideo.fromJson(item)).toList();
      } else {
        throw Exception('Failed to load videos');
      }
    } catch (e) {
      throw Exception('Error fetching videos: $e');
    }
  }

  Future<RaidVideo> createVideo(RaidVideo video) async {
    try {
      final response = await _client.post(
        Uri.parse(baseUrl),
        headers: _authService.getAuthHeaders(), // Include auth headers
        body: jsonEncode(video.toJson()),
      );

      if (response.statusCode == 200) {
         // UTF-8 디코딩 처리
        return RaidVideo.fromJson(jsonDecode(utf8.decode(response.bodyBytes)));
      } else {
        print('Video creation failed. Status: ${response.statusCode}');
        print('Response body: ${response.body}');
        throw Exception('Failed to create video: ${response.statusCode}');
      }
    } catch (e) {
      print('Error creating video: $e');
      throw e;
    }
  }

  Future<List<PlaylistItem>> getPlaylistItems(String playlistId) async {
    try {
      final response = await _client.get(
        Uri.parse('http://localhost:8080/api/youtube/playlist-items?playlistId=$playlistId&fetchAll=true'),
      );

      if (response.statusCode == 200) {
        // UTF-8 디코딩 처리 (한글 깨짐 방지)
        final jsonData = jsonDecode(utf8.decode(response.bodyBytes));
        final List<dynamic> items = jsonData['items'] ?? [];
        return items.map((dynamic item) => PlaylistItem.fromJson(item)).toList();
      } else {
        throw Exception('Failed to load playlist items');
      }
    } catch (e) {
      throw Exception('Error fetching playlist items: $e');
    }
  }
}
