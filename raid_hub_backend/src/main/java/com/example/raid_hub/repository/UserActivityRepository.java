package com.example.raid_hub.repository;

import com.example.raid_hub.entity.UserActivity;
import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.data.jpa.repository.Query;
import org.springframework.stereotype.Repository;
import java.util.List;
import java.util.Map;

@Repository
public interface UserActivityRepository extends JpaRepository<UserActivity, Long> {

    // 기기별 통계
    @Query("SELECT a.deviceType as device, COUNT(a) as count FROM UserActivity a GROUP BY a.deviceType")
    List<Map<String, Object>> countByDeviceType();

    // 인기 영상/컨닝페이퍼 Top 10 (활동 유형별)
    @Query("SELECT a.targetTitle as title, COUNT(a) as count FROM UserActivity a WHERE a.activityType = :type GROUP BY a.targetTitle ORDER BY COUNT(a) DESC")
    List<Map<String, Object>> findTopTargetsByType(String type);

    // 인기 검색어 Top 10
    @Query("SELECT a.searchQuery as query, COUNT(a) as count FROM UserActivity a WHERE a.activityType = 'SEARCH' AND a.searchQuery IS NOT NULL GROUP BY a.searchQuery ORDER BY COUNT(a) DESC")
    List<Map<String, Object>> findTopSearchQueries();
}
