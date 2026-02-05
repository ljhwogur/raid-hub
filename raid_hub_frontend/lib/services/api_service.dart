import 'dart:convert';
import 'package:http/http.dart' as http;
import '../models/raid_video.dart';

class ApiService {
  final String baseUrl = "http://localhost:8080/api/videos";

  Future<List<RaidVideo>> getVideos() async {
    try {
      final response = await http.get(Uri.parse(baseUrl));

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
    final response = await http.post(
      Uri.parse(baseUrl),
      headers: {"Content-Type": "application/json"},
      body: jsonEncode(video.toJson()),
    );

    if (response.statusCode == 200) {
       // UTF-8 디코딩 처리
      return RaidVideo.fromJson(jsonDecode(utf8.decode(response.bodyBytes)));
    } else {
      throw Exception('Failed to create video');
    }
  }
}
