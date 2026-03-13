package com.example.raid_hub.controller;

import com.example.raid_hub.entity.UserActivity;
import com.example.raid_hub.service.UserActivityService;
import lombok.RequiredArgsConstructor;
import org.springframework.http.ResponseEntity;
import org.springframework.web.bind.annotation.*;
import java.util.Map;

@RestController
@RequestMapping("/api/stats")
@RequiredArgsConstructor
public class AdminStatsController {
    private final UserActivityService service;

    // 활동 로그 기록 (Public)
    @PostMapping("/log")
    public ResponseEntity<Void> logActivity(@RequestBody UserActivity activity) {
        service.logActivity(activity);
        return ResponseEntity.ok().build();
    }

    // 대시보드 데이터 조회 (Admin Only)
    @GetMapping("/dashboard")
    public ResponseEntity<Map<String, Object>> getDashboardStats() {
        return ResponseEntity.ok(service.getDashboardStats());
    }
}
