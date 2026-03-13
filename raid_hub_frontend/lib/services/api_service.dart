import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:http/browser_client.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart'; // Import dotenv
import '../models/raid_video.dart';
import '../models/playlist_item.dart';
import '../models/cheat_sheet.dart'; // Import CheatSheet model
import '../models/admin_post.dart'; // Import AdminPost model
import 'package:raid_hub_frontend/services/auth_service.dart'; // Import AuthService

class ApiService {
  final String baseUrl =
      "${dotenv.env['API_BASE_URL'] ?? 'http://localhost:8080'}/api/videos";
  final String _apiBaseUrl =
      "${dotenv.env['API_BASE_URL'] ?? 'http://localhost:8080'}/api"; // Added base API URL
  final AuthService _authService =
      AuthService(); // Get the AuthService instance
  final http.Client _client = BrowserClient()..withCredentials = true;

  // Cheat Sheet 관련 API 추가
  Future<List<CheatSheet>> getCheatSheets() async {
    try {
      final response = await _client.get(Uri.parse('$_apiBaseUrl/cheatsheets'));

      if (response.statusCode == 200) {
        List<dynamic> body = jsonDecode(utf8.decode(response.bodyBytes));
        return body.map((dynamic item) => CheatSheet.fromJson(item)).toList();
      } else {
        throw Exception('Failed to load cheat sheets');
      }
    } catch (e) {
      debugPrint('Error fetching cheat sheets: $e');
      return [];
    }
  }

  Future<void> deleteCheatSheet(int id) async {
    try {
      final response = await _client.delete(
        Uri.parse('$_apiBaseUrl/cheatsheets/$id'),
        headers: _authService.getAuthHeaders(),
      );

      if (response.statusCode != 204) {
        throw Exception('Failed to delete cheat sheet: ${response.statusCode}');
      }
    } catch (e) {
      debugPrint('Error deleting cheat sheet: $e');
      throw e;
    }
  }

  // 이미지 업로드를 위한 MultipartRequest 처리 (브라우저용)
  Future<void> uploadCheatSheet({
    required String title,
    required String raidName,
    required String gate,
    required String uploaderName, // Added
    required List<int> fileBytes,
    required String fileName,
  }) async {
    try {
      var request = http.MultipartRequest(
        'POST',
        Uri.parse('$_apiBaseUrl/cheatsheets'),
      );
      request.fields['title'] = title;
      request.fields['raidName'] = raidName;
      request.fields['gate'] = gate;
      request.fields['uploaderName'] = uploaderName; // Added

      // 파일 추가
      var multipartFile = http.MultipartFile.fromBytes(
        'file',
        fileBytes,
        filename: fileName,
      );
      request.files.add(multipartFile);

      // 브라우저 클라이언트 설정 (쿠키/자격증명 전송을 위함)
      if (_client is BrowserClient) {
        (_client as BrowserClient).withCredentials = true;
      }

      // AuthService의 헤더를 가져옴 (쿠키 등은 BrowserClient가 처리함)
      // request.headers.addAll(_authService.getAuthHeaders());

      final response = await _client.send(request);
      final responseBody = await response.stream.bytesToString();

      if (response.statusCode != 200) {
        debugPrint('Upload failed: $responseBody');
        throw Exception('Upload failed: ${response.statusCode}');
      }
    } catch (e) {
      debugPrint('Error uploading cheat sheet: $e');
      throw e;
    }
  }

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
        debugPrint('Video creation failed. Status: ${response.statusCode}');
        debugPrint('Response body: ${response.body}');
        throw Exception('Failed to create video: ${response.statusCode}');
      }
    } catch (e) {
      debugPrint('Error creating video: $e');
      throw e;
    }
  }

  Future<void> deleteVideo(int id) async {
    try {
      final response = await _client.delete(
        Uri.parse('$baseUrl/$id'),
        headers: _authService.getAuthHeaders(), // Include auth headers
      );

      if (response.statusCode != 204) {
        throw Exception('Failed to delete video: ${response.statusCode}');
      }
    } catch (e) {
      debugPrint('Error deleting video: $e');
      throw e;
    }
  }

  Future<void> blockVideo(String videoId, String reason) async {
    try {
      final response = await _client.post(
        Uri.parse('$_apiBaseUrl/blocked-videos'),
        headers: _authService.getAuthHeaders(),
        body: jsonEncode({'videoId': videoId, 'reason': reason}),
      );

      if (response.statusCode == 200) {
        return;
      } else {
        throw Exception('Failed to block video: ${response.statusCode}');
      }
    } catch (e) {
      debugPrint('Error blocking video: $e');
      throw e;
    }
  }

  Future<void> unblockVideo(String videoId) async {
    try {
      final response = await _client.delete(
        Uri.parse('$_apiBaseUrl/blocked-videos/$videoId'),
        headers: _authService.getAuthHeaders(), // Include auth headers
      );

      if (response.statusCode == 204) {
        return;
      } else {
        throw Exception('Failed to unblock video: ${response.statusCode}');
      }
    } catch (e) {
      debugPrint('Error unblocking video: $e');
      throw e;
    }
  }

  Future<List<String>> getBlockedVideoIds() async {
    try {
      final response = await _client.get(
        Uri.parse('$_apiBaseUrl/blocked-videos'),
        headers: _authService.getAuthHeaders(),
      );

      if (response.statusCode == 200) {
        final List<dynamic> body = jsonDecode(response.body);
        return body.cast<String>();
      } else {
        throw Exception('Failed to load blocked video IDs');
      }
    } catch (e) {
      debugPrint('Error fetching blocked video IDs: $e');
      return [];
    }
  }

  Future<List<PlaylistItem>> getPlaylistItems(String playlistId) async {
    try {
      final response = await _client.get(
        Uri.parse(
          '$_apiBaseUrl/youtube/playlist-items?playlistId=$playlistId&fetchAll=true',
        ),
      );

      if (response.statusCode == 200) {
        // UTF-8 디코딩 처리 (한글 깨짐 방지)
        final jsonData = jsonDecode(utf8.decode(response.bodyBytes));
        final List<dynamic> items = jsonData['items'] ?? [];
        return items
            .map((dynamic item) => PlaylistItem.fromJson(item))
            .toList();
      } else {
        throw Exception('Failed to load playlist items');
      }
    } catch (e) {
      throw Exception('Error fetching playlist items: $e');
    }
  }

  // --- Notice APIs ---
  Future<String> getNotice() async {
    try {
      final response = await _client.get(Uri.parse('$_apiBaseUrl/notice'));
      if (response.statusCode == 200) {
        final data = json.decode(utf8.decode(response.bodyBytes));
        return data['content'] ?? '';
      }
      return '';
    } catch (e) {
      debugPrint('Error fetching notice: $e');
      return '';
    }
  }

  Future<void> updateNotice(String content) async {
    try {
      final response = await _client.put(
        Uri.parse('$_apiBaseUrl/notice'),
        headers: {
          'Content-Type': 'application/json',
          ..._authService.getAuthHeaders()
        },
        body: json.encode({'content': content}),
      );
      if (response.statusCode != 200) {
        throw Exception('Failed to update notice');
      }
    } catch (e) {
      throw Exception('Error updating notice: $e');
    }
  }

  // --- Admin Post APIs ---
  Future<List<AdminPost>> getAdminPosts() async {
    try {
      final response = await _client.get(Uri.parse('$_apiBaseUrl/admin-posts'));
      if (response.statusCode == 200) {
        List<dynamic> body = jsonDecode(utf8.decode(response.bodyBytes));
        return body.map((dynamic item) => AdminPost.fromJson(item)).toList();
      }
      return [];
    } catch (e) {
      debugPrint('Error fetching admin posts: $e');
      return [];
    }
  }

  Future<void> createAdminPost(AdminPost post) async {
    try {
      final response = await _client.post(
        Uri.parse('$_apiBaseUrl/admin-posts'),
        headers: {
          'Content-Type': 'application/json',
          ..._authService.getAuthHeaders()
        },
        body: jsonEncode(post.toJson()),
      );
      if (response.statusCode != 200) throw Exception('Failed to create post');
    } catch (e) {
      throw Exception('Error creating post: $e');
    }
  }

  Future<void> updateAdminPost(int id, AdminPost post) async {
    try {
      final response = await _client.put(
        Uri.parse('$_apiBaseUrl/admin-posts/$id'),
        headers: {
          'Content-Type': 'application/json',
          ..._authService.getAuthHeaders()
        },
        body: jsonEncode(post.toJson()),
      );
      if (response.statusCode != 200) throw Exception('Failed to update post');
    } catch (e) {
      throw Exception('Error updating post: $e');
    }
  }

  Future<void> deleteAdminPost(int id) async {
    try {
      final response = await _client.delete(
        Uri.parse('$_apiBaseUrl/admin-posts/$id'),
        headers: _authService.getAuthHeaders(),
      );
      if (response.statusCode != 200) throw Exception('Failed to delete post');
    } catch (e) {
      throw Exception('Error deleting post: $e');
    }
  }

  Future<void> changePassword(String currentPassword, String newPassword) async {
    try {
      final response = await _client.put(
        Uri.parse('$_apiBaseUrl/users/change-password'),
        headers: {
          'Content-Type': 'application/json',
          ..._authService.getAuthHeaders()
        },
        body: jsonEncode({
          'currentPassword': currentPassword,
          'newPassword': newPassword,
        }),
      );
      if (response.statusCode != 200) {
        final error = jsonDecode(utf8.decode(response.bodyBytes));
        throw Exception(error['message'] ?? '비밀번호 변경 실패');
      }
    } catch (e) {
      throw Exception('비밀번호 변경 중 오류 발생: $e');
    }
  }

  // --- Statistics & Insights APIs ---
  Future<void> logActivity({
    required String activityType,
    String? targetTitle,
    String? searchQuery,
  }) async {
    try {
      // 기기 유형 판별 (기본적으로 PC, 모바일 플랫폼이면 MOBILE)
      String deviceType = 'PC';
      
      if (!kIsWeb) {
        deviceType = 'MOBILE';
      } else {
        // 웹 환경에서 모바일 기기인지 체크
        if (defaultTargetPlatform == TargetPlatform.iOS || 
            defaultTargetPlatform == TargetPlatform.android) {
          deviceType = 'MOBILE';
        }
      }

      await _client.post(
        Uri.parse('$_apiBaseUrl/stats/log'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'activityType': activityType,
          'targetTitle': targetTitle,
          'searchQuery': searchQuery,
          'deviceType': deviceType,
        }),
      );
    } catch (e) {
      debugPrint('Silent log error: $e');
    }
  }

  Future<Map<String, dynamic>> getDashboardStats() async {
    try {
      final response = await _client.get(
        Uri.parse('$_apiBaseUrl/stats/dashboard'),
        headers: _authService.getAuthHeaders(),
      );
      if (response.statusCode == 200) {
        return jsonDecode(utf8.decode(response.bodyBytes));
      }
      throw Exception('Failed to fetch stats');
    } catch (e) {
      debugPrint('Error fetching stats: $e');
      return {};
    }
  }
}
