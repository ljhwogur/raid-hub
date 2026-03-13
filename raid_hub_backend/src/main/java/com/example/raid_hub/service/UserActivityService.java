package com.example.raid_hub.service;

import com.example.raid_hub.entity.UserActivity;
import com.example.raid_hub.repository.UserActivityRepository;
import lombok.RequiredArgsConstructor;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;
import java.util.HashMap;
import java.util.List;
import java.util.Map;

@Service
@RequiredArgsConstructor
public class UserActivityService {
    private final UserActivityRepository repository;

    @Transactional
    public void logActivity(UserActivity activity) {
        repository.save(activity);
    }

    @Transactional(readOnly = true)
    public Map<String, Object> getDashboardStats() {
        Map<String, Object> stats = new HashMap<>();
        
        stats.put("deviceStats", repository.countByDeviceType());
        stats.put("topVideos", repository.findTopTargetsByType("VIDEO_CLICK"));
        stats.put("topCheatSheets", repository.findTopTargetsByType("CHEATSHEET_CLICK"));
        stats.put("topSearches", repository.findTopSearchQueries());
        stats.put("totalActivities", repository.count());

        return stats;
    }
}
