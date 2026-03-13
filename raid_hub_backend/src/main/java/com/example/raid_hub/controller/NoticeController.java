package com.example.raid_hub.controller;

import com.example.raid_hub.service.NoticeService;
import lombok.RequiredArgsConstructor;
import org.springframework.http.ResponseEntity;
import org.springframework.web.bind.annotation.*;

import java.util.Map;

@RestController
@RequestMapping("/api/notice")
@RequiredArgsConstructor
public class NoticeController {
    private final NoticeService noticeService;

    @GetMapping
    public ResponseEntity<Map<String, String>> getNotice() {
        return ResponseEntity.ok(Map.of("content", noticeService.getNoticeContent()));
    }

    @PutMapping
    public ResponseEntity<Void> updateNotice(@RequestBody Map<String, String> request) {
        noticeService.updateNotice(request.get("content"));
        return ResponseEntity.ok().build();
    }
}
