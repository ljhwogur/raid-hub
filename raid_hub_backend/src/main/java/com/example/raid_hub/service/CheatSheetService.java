package com.example.raid_hub.service;

import com.example.raid_hub.entity.CheatSheet;
import com.example.raid_hub.repository.CheatSheetRepository;
import java.io.IOException;
import java.nio.file.Files;
import java.nio.file.Path;
import java.nio.file.Paths;
import java.nio.file.StandardCopyOption;
import java.util.Arrays;
import java.util.List;
import java.util.UUID;
import org.springframework.beans.factory.annotation.Value;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;
import org.springframework.web.multipart.MultipartFile;

@Service
public class CheatSheetService {

  private final CheatSheetRepository cheatSheetRepository;
  private final String uploadDir;

  public CheatSheetService(
      CheatSheetRepository cheatSheetRepository, @Value("${file.upload-dir}") String uploadDir) {
    this.cheatSheetRepository = cheatSheetRepository;
    this.uploadDir = uploadDir;

    // 업로드 폴더가 없으면 생성
    try {
      Files.createDirectories(Paths.get(uploadDir));
    } catch (IOException e) {
      throw new RuntimeException("Could not create upload directory", e);
    }
  }

  @Transactional
  public CheatSheet uploadCheatSheet(
      String title, String raidName, String gate, String uploaderName, MultipartFile file)
      throws IOException {

    // 0. 파일 유효성 검사 (확장자 및 MIME 타입)
    String originalFilename = file.getOriginalFilename();
    if (originalFilename == null || !originalFilename.contains(".")) {
      throw new IllegalArgumentException("유효하지 않은 파일 이름입니다.");
    }

    String extension = originalFilename.substring(originalFilename.lastIndexOf(".")).toLowerCase();
    List<String> allowedExtensions = Arrays.asList(".jpg", ".jpeg", ".png", ".gif", ".webp");

    if (!allowedExtensions.contains(extension)) {
      throw new IllegalArgumentException("허용되지 않는 파일 확장자입니다. (jpg, jpeg, png, gif, webp만 가능)");
    }

    // String contentType = file.getContentType();
    // if (contentType == null || !contentType.startsWith("image/")) {
    //   throw new IllegalArgumentException("이미지 파일만 업로드할 수 있습니다.");
    // }

    // 1. 파일 이름 생성 (중복 방지)
    String newFilename = UUID.randomUUID().toString() + extension;

    // 2. 파일 저장 경로 설정 및 저장
    Path path = Paths.get(uploadDir).resolve(newFilename);
    Files.copy(file.getInputStream(), path, StandardCopyOption.REPLACE_EXISTING);

    // 3. DB 저장 (imageUrl은 프론트에서 접근 가능한 URL 경로)
    CheatSheet cheatSheet =
        CheatSheet.builder()
            .title(title)
            .raidName(raidName)
            .gate(gate)
            .uploaderName(uploaderName)
            .imageUrl("/uploads/cheatsheets/" + newFilename)
            .build();

    return cheatSheetRepository.save(cheatSheet);
  }

  @Transactional(readOnly = true)
  public List<CheatSheet> getAllCheatSheets() {
    return cheatSheetRepository.findAll();
  }

  @Transactional
  public void deleteCheatSheet(Long id) {
    cheatSheetRepository.deleteById(id);
  }
}
