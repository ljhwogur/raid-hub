package com.example.raid_hub.service;

import com.example.raid_hub.entity.RaidVideo;
import com.example.raid_hub.repository.RaidVideoRepository;
import java.util.List;
import java.util.Set;
import lombok.RequiredArgsConstructor;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

@Service
@RequiredArgsConstructor
public class RaidVideoService {

  private final RaidVideoRepository raidVideoRepository;

  @Transactional
  public RaidVideo createVideo(RaidVideo video) {
    validateDifficultyForRaid(video.getRaidName(), video.getDifficulty());
    return raidVideoRepository.save(video);
  }

  private void validateDifficultyForRaid(String raidName, String difficulty) {
    Set<String> allowedDifficulties;

    // 군단장 레이드
    if (Set.of("발탄", "비아키스", "아브렐슈드", "일리아칸", "카멘").contains(raidName)) {
      allowedDifficulties = Set.of("싱글", "노말", "하드");
    } else if ("쿠크세이튼".equals(raidName)) {
      allowedDifficulties = Set.of("싱글", "노말");
    }
    // 카제로스 레이드
    else if (Set.of("(서막)에키드나", "(1막)에기르", "(2막)아브렐슈드", "(3막)모르둠").contains(raidName)) {
      allowedDifficulties = Set.of("싱글", "노말", "하드");
    } else if (Set.of("(4막)아르모체", "(종막)카제로스").contains(raidName)) {
      allowedDifficulties = Set.of("노말", "하드");
    }
    // 그림자 레이드
    else if ("세르카".equals(raidName)) {
      allowedDifficulties = Set.of("노말", "하드", "나이트메어");
    }
    // Unknown raidName, allow any difficulty or throw an exception, let's allow any for now for
    // flexibility
    else {
      return; // No specific validation for this raidName
    }

    if (!allowedDifficulties.contains(difficulty)) {
      throw new IllegalArgumentException(
          String.format(
              "레이드 '%s'의 난이도 '%s'는 유효하지 않습니다. 허용되는 난이도: %s",
              raidName, difficulty, String.join(", ", allowedDifficulties)));
    }
  }

  @Transactional(readOnly = true)
  public List<RaidVideo> getAllVideos() {
    return raidVideoRepository.findAll();
  }
}
