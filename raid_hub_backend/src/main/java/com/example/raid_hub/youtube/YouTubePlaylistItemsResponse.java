package com.example.raid_hub.youtube;

import java.util.List;

public record YouTubePlaylistItemsResponse(
    String playlistId,
    String nextPageToken,
    Integer totalResults,
    List<YouTubePlaylistItem> items) {}
