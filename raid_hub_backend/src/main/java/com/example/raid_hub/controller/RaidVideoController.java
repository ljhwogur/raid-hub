package com.example.raid_hub.controller;

import com.example.raid_hub.entity.RaidVideo;
import com.example.raid_hub.service.RaidVideoService;
import java.util.List;
import lombok.RequiredArgsConstructor;
import org.springframework.http.ResponseEntity;
import org.springframework.web.bind.annotation.*;

@RestController
@RequestMapping("/api/videos")
@RequiredArgsConstructor
@CrossOrigin(origins = "*") // 플러터(웹)에서 접근 허용 (CORS)
public class RaidVideoController {

  private final RaidVideoService raidVideoService;

  @PostMapping
  public ResponseEntity<RaidVideo> createVideo(@RequestBody RaidVideo video) {
    RaidVideo savedVideo = raidVideoService.createVideo(video);
    return ResponseEntity.ok(savedVideo);
  }

  @GetMapping
  public ResponseEntity<List<RaidVideo>> getAllVideos() {
    return ResponseEntity.ok(raidVideoService.getAllVideos());
  }

  @DeleteMapping("/{id}")
  public ResponseEntity<Void> deleteVideo(@PathVariable Long id) {
    raidVideoService.deleteVideo(id);
    return ResponseEntity.noContent().build();
  }
}
