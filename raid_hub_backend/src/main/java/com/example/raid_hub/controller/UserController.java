package com.example.raid_hub.controller;

import com.example.raid_hub.dto.UserRegistrationDto;
import com.example.raid_hub.entity.User;
import com.example.raid_hub.service.UserService;
import jakarta.validation.Valid;
import java.util.HashMap;
import java.util.Map;
import lombok.RequiredArgsConstructor;
import org.springframework.http.HttpStatus;
import org.springframework.http.ResponseEntity;
import org.springframework.web.bind.annotation.*;

@RestController
@RequestMapping("/api/users")
@RequiredArgsConstructor
@CrossOrigin(origins = "*") // 플러터(웹)에서 접근 허용 (CORS)
public class UserController {

  private final UserService userService;

  @PostMapping("/register")
  public ResponseEntity<Map<String, Object>> registerUser(
      @Valid @RequestBody UserRegistrationDto dto) {
    User user = userService.registerUser(dto);
    Map<String, Object> response = new HashMap<>();
    response.put("success", true);
    response.put("message", "사용자가 성공적으로 등록되었습니다.");
    response.put("username", user.getUsername());
    return ResponseEntity.status(HttpStatus.CREATED).body(response);
  }

  @GetMapping("/check-username/{username}")
  public ResponseEntity<Map<String, Object>> checkUsername(@PathVariable String username) {
    Map<String, Object> response = new HashMap<>();
    boolean exists = userService.existsByUsername(username);
    response.put("username", username);
    response.put("exists", exists);
    return ResponseEntity.ok(response);
  }
}
