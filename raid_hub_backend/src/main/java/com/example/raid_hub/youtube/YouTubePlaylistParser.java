package com.example.raid_hub.youtube;

import com.fasterxml.jackson.databind.JsonNode;
import java.util.ArrayList;
import java.util.List;
import org.springframework.stereotype.Component;

@Component
public class YouTubePlaylistParser {

  public YouTubePlaylistItemsResponse parse(JsonNode root, String playlistId) {
    String nextPageToken = getText(root, "nextPageToken").orElse(null);
    Integer totalResults = getInt(root.path("pageInfo"), "totalResults");

    List<YouTubePlaylistItem> items = new ArrayList<>();
    JsonNode itemsNode = root.path("items");
    if (itemsNode.isArray()) {
      for (JsonNode itemNode : itemsNode) {
        JsonNode snippet = itemNode.path("snippet");
        JsonNode contentDetails = itemNode.path("contentDetails");

        String videoId =
            getText(contentDetails, "videoId")
                .orElseGet(() -> getText(snippet.path("resourceId"), "videoId").orElse(null));

        String title = getText(snippet, "title").orElse(null);
        String channelTitle = getText(snippet, "channelTitle").orElse(null);
        Integer position = getInt(snippet, "position");
        String publishedAt = getText(snippet, "publishedAt").orElse(null);
        String thumbnailUrl =
            getText(snippet.path("thumbnails").path("high"), "url")
                .orElseGet(
                    () ->
                        getText(snippet.path("thumbnails").path("medium"), "url")
                            .orElseGet(
                                () ->
                                    getText(snippet.path("thumbnails").path("default"), "url")
                                        .orElse(null)));

        items.add(
            new YouTubePlaylistItem(
                videoId, title, channelTitle, thumbnailUrl, position, publishedAt));
      }
    }

    return new YouTubePlaylistItemsResponse(playlistId, nextPageToken, totalResults, items);
  }

  private java.util.Optional<String> getText(JsonNode node, String field) {
    if (node == null || node.isMissingNode() || node.isNull()) {
      return java.util.Optional.empty();
    }
    JsonNode valueNode = node.get(field);
    if (valueNode == null || valueNode.isNull()) {
      return java.util.Optional.empty();
    }
    String value = valueNode.asText();
    return value == null || value.isBlank()
        ? java.util.Optional.empty()
        : java.util.Optional.of(value);
  }

  private Integer getInt(JsonNode node, String field) {
    if (node == null || node.isMissingNode() || node.isNull()) {
      return null;
    }
    JsonNode valueNode = node.get(field);
    if (valueNode == null || valueNode.isNull()) {
      return null;
    }
    return valueNode.isInt() ? valueNode.asInt() : null;
  }
}
