package com.example.raid_hub.entity;

import jakarta.persistence.*;
import lombok.*;
import java.time.LocalDateTime;

@Entity
@Table(name = "user_activities")
@Getter
@Setter
@NoArgsConstructor
@AllArgsConstructor
@Builder
public class UserActivity {
    @Id
    @GeneratedValue(strategy = GenerationType.IDENTITY)
    private Long id;

    // 활동 유형: VIDEO_CLICK, CHEATSHEET_CLICK, SEARCH, PAGE_VIEW
    @Column(nullable = false)
    private String activityType;

    // 대상 식별자 (영상 제목, 레이드명 등)
    private String targetTitle;

    // 기기 유형: MOBILE, PC
    private String deviceType;

    // 검색어 (activityType이 SEARCH인 경우)
    private String searchQuery;

    private LocalDateTime createdAt;

    @PrePersist
    public void prePersist() {
        this.createdAt = LocalDateTime.now();
    }
}
