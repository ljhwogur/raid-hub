package com.example.raid_hub.youtube;

public record YouTubePlaylistItem(
    String videoId,
    String title,
    String channelTitle,
    String thumbnailUrl,
    Integer position,
    String publishedAt) {}
