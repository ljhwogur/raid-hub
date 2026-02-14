package com.example.raid_hub.repository;

import com.example.raid_hub.entity.RaidVideo;
import java.util.List;
import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.stereotype.Repository;

@Repository
public interface RaidVideoRepository extends JpaRepository<RaidVideo, Long> {
  // 필요 시 조건 검색 메소드 추가 가능
  // 예: 레이드 이름으로 찾기
  List<RaidVideo> findByRaidName(String raidName);
}
