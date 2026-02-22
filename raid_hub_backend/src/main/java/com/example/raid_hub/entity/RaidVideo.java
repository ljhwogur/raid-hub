package com.example.raid_hub.entity;

import jakarta.persistence.*;
import jakarta.validation.constraints.NotBlank;
import jakarta.validation.constraints.Size;
import lombok.AllArgsConstructor;
import lombok.Builder;
import lombok.Getter;
import lombok.NoArgsConstructor;
import lombok.Setter;

@Entity
@Getter
@Setter
@NoArgsConstructor
@AllArgsConstructor
@Builder
@Table(name = "raid_videos")
public class RaidVideo {

  @Id
  @GeneratedValue(strategy = GenerationType.IDENTITY)
  private Long id;

  @NotBlank(message = "제목은 필수입니다")
  @Size(max = 100, message = "제목은 100자 이하여야 합니다")
  @Column(nullable = false, length = 100)
  private String title;

  @NotBlank(message = "YouTube URL은 필수입니다")
  @Size(max = 255, message = "YouTube URL은 255자 이하여야 합니다")
  // 정규식 검증 완화 (URL 형식은 다양할 수 있음)
  @Column(nullable = false, length = 255)
  private String youtubeUrl;

  @NotBlank(message = "업로더 이름은 필수입니다")
  @Size(max = 50, message = "업로더 이름은 50자 이하여야 합니다")
  @Column(nullable = false, length = 50)
  private String uploaderName;

  @NotBlank(message = "레이드 이름은 필수입니다")
  @Size(max = 20, message = "레이드 이름은 20자 이하여야 합니다")
  @Column(nullable = false, length = 20)
  private String raidName; // 카멘, 에키드나 등

  // 난이도 제약 조건 완화
  @Size(max = 20, message = "난이도는 20자 이하여야 합니다")
  @Column(nullable = false, length = 20)
  private String difficulty; // 노말, 하드, 헬, 나이트메어 등 자유 입력

  // 관문 제약 조건 완화
  @Size(max = 20, message = "관문은 20자 이하여야 합니다")
  @Column(nullable = false, length = 20)
  private String gate; // 전체, 1관문, 2관문... 자유 입력
}
