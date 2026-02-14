package com.example.raid_hub.controller;

import com.example.raid_hub.service.YouTubePlaylistService;
import com.example.raid_hub.youtube.YouTubePlaylistItemsResponse;
import lombok.RequiredArgsConstructor;
import org.springframework.web.bind.annotation.*;

@RestController
@RequestMapping("/api/youtube")
@RequiredArgsConstructor
@CrossOrigin(origins = "*") // 플러터(웹)에서 접근 허용 (CORS)
public class YouTubePlaylistController {

  private final YouTubePlaylistService service;

  @GetMapping("/playlist-items")
  public YouTubePlaylistItemsResponse getPlaylistItems(
      @RequestParam String playlistId,
      @RequestParam(required = false) Integer maxResults,
      @RequestParam(required = false) String pageToken,
      @RequestParam(defaultValue = "false") boolean fetchAll) {
    if (fetchAll) {
      return service.fetchAllPlaylistItems(playlistId, maxResults);
    }
    return service.fetchPlaylistItems(playlistId, maxResults, pageToken);
  }
}
