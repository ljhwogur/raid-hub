package com.example.raid_hub;

import jakarta.persistence.*;
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

  @Column(nullable = false)
  private String title;

  @Column(nullable = false)
  private String youtubeUrl;

  @Column(nullable = false)
  private String uploaderName;

  @Column(nullable = false)
  private String raidName; // 카멘, 에키드나 등

  @Column(nullable = false)
  private String difficulty; // 노말, 하드, 헬

  @Column(nullable = false)
  private String gate; // 1관문, 2관문...
}
