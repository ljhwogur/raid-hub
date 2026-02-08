package com.example.raid_hub;

import jakarta.persistence.*;
import jakarta.validation.constraints.NotBlank;
import jakarta.validation.constraints.Pattern;
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
  @Size(max = 30, message = "제목은 30자 이하여야 합니다")
  @Column(nullable = false, length = 30)
  private String title;

  @NotBlank(message = "YouTube URL은 필수입니다")
  @Size(max = 255, message = "YouTube URL은 255자 이하여야 합니다")
  @Pattern(
      regexp = "^(https?://)?(www\\.)?(youtube\\.com|youtu\\.be)(?:[/:?].*)?$",
      message = "올바른 YouTube URL 형식이 아닙니다")
  @Column(nullable = false, length = 255)
  private String youtubeUrl;

  @NotBlank(message = "업로더 이름은 필수입니다")
  @Size(max = 20, message = "업로더 이름은 20자 이하여야 합니다")
  @Column(nullable = false, length = 20)
  private String uploaderName;

  @NotBlank(message = "레이드 이름은 필수입니다")
  @Size(max = 10, message = "레이드 이름은 10자 이하여야 합니다")
  @Column(nullable = false, length = 10)
  private String raidName; // 카멘, 에키드나 등

  @NotBlank(message = "난이도는 필수입니다")
  @Size(max = 5, message = "난이도는 5자 이하여야 합니다")
  @Pattern(regexp = "^(노말|하드|헬)$", message = "난이도는 '노말', '하드', '헬' 중 하나여야 합니다")
  @Column(nullable = false, length = 5)
  private String difficulty; // 노말, 하드, 헬

  @NotBlank(message = "관문은 필수입니다")
  @Size(max = 5, message = "관문은 5자 이하여야 합니다")
  @Pattern(
      regexp = "^(?:[1-4]관문|전체)$",
      message = "관문은 '전체' 또는 '1관문', '2관문', '3관문', '4관문' 중 하나여야 합니다")
  @Column(nullable = false, length = 5)
  private String gate; // 전체, 1관문, 2관문...
}
