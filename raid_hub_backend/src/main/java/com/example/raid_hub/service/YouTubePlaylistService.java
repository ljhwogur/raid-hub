package com.example.raid_hub.service;

import com.example.raid_hub.youtube.YouTubePlaylistItem;
import com.example.raid_hub.youtube.YouTubePlaylistItemsResponse;
import com.example.raid_hub.youtube.YouTubePlaylistParser;
import com.fasterxml.jackson.databind.JsonNode;
import com.fasterxml.jackson.databind.ObjectMapper;
import java.io.IOException;
import java.net.URI;
import java.net.URLEncoder;
import java.net.http.HttpClient;
import java.net.http.HttpRequest;
import java.net.http.HttpResponse;
import java.nio.charset.StandardCharsets;
import java.util.ArrayList;
import java.util.List;
import lombok.RequiredArgsConstructor;
import org.springframework.beans.factory.annotation.Value;
import org.springframework.http.HttpStatus;
import org.springframework.stereotype.Service;
import org.springframework.web.server.ResponseStatusException;

@Service
@RequiredArgsConstructor
public class YouTubePlaylistService {

  private final ObjectMapper objectMapper;
  private final YouTubePlaylistParser parser;
  private final HttpClient httpClient = HttpClient.newHttpClient();

  @Value("${youtube.api.key:}")
  private String apiKey;

  public YouTubePlaylistItemsResponse fetchPlaylistItems(
      String playlistId, Integer maxResults, String pageToken) {
    validateInputs(playlistId);

    int limit = normalizeMaxResults(maxResults);
    JsonNode root = requestPage(playlistId, limit, pageToken);
    return parser.parse(root, playlistId);
  }

  public YouTubePlaylistItemsResponse fetchAllPlaylistItems(String playlistId, Integer maxResults) {
    validateInputs(playlistId);

    int limit = normalizeMaxResults(maxResults);
    List<YouTubePlaylistItem> allItems = new ArrayList<>();
    Integer totalResults = null;
    String pageToken = null;

    do {
      JsonNode root = requestPage(playlistId, limit, pageToken);
      YouTubePlaylistItemsResponse page = parser.parse(root, playlistId);
      if (totalResults == null) {
        totalResults = page.totalResults();
      }
      allItems.addAll(page.items());
      pageToken = page.nextPageToken();
    } while (pageToken != null && !pageToken.isBlank());

    return new YouTubePlaylistItemsResponse(playlistId, null, totalResults, allItems);
  }

  private void validateInputs(String playlistId) {
    if (playlistId == null || playlistId.isBlank()) {
      throw new ResponseStatusException(HttpStatus.BAD_REQUEST, "playlistId is required");
    }
    if (apiKey == null || apiKey.isBlank()) {
      throw new ResponseStatusException(HttpStatus.BAD_REQUEST, "youtube.api.key is not set");
    }
  }

  private JsonNode requestPage(String playlistId, int maxResults, String pageToken) {
    StringBuilder urlBuilder =
        new StringBuilder("https://www.googleapis.com/youtube/v3/playlistItems");
    urlBuilder.append("?part=snippet,contentDetails");
    urlBuilder.append("&playlistId=").append(encode(playlistId));
    urlBuilder.append("&maxResults=").append(maxResults);
    urlBuilder.append("&key=").append(encode(apiKey));
    if (pageToken != null && !pageToken.isBlank()) {
      urlBuilder.append("&pageToken=").append(encode(pageToken));
    }

    HttpRequest request = HttpRequest.newBuilder(URI.create(urlBuilder.toString())).GET().build();

    try {
      HttpResponse<String> response =
          httpClient.send(request, HttpResponse.BodyHandlers.ofString());
      if (response.statusCode() != 200) {
        throw new ResponseStatusException(
            HttpStatus.BAD_GATEWAY, "YouTube API error: HTTP " + response.statusCode());
      }

      return objectMapper.readTree(response.body());
    } catch (InterruptedException ex) {
      Thread.currentThread().interrupt();
      throw new ResponseStatusException(HttpStatus.BAD_GATEWAY, "YouTube API request failed", ex);
    } catch (IOException ex) {
      throw new ResponseStatusException(HttpStatus.BAD_GATEWAY, "YouTube API request failed", ex);
    }
  }

  private int normalizeMaxResults(Integer maxResults) {
    if (maxResults == null) {
      return 50;
    }
    if (maxResults < 1) {
      return 1;
    }
    return Math.min(maxResults, 50);
  }

  private String encode(String value) {
    return URLEncoder.encode(value, StandardCharsets.UTF_8);
  }
}
