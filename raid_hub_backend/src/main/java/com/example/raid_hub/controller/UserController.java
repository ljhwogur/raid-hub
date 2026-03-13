package com.example.raid_hub.controller;

import com.example.raid_hub.dto.UserRegistrationDto;
import com.example.raid_hub.dto.PasswordChangeDto;
import com.example.raid_hub.entity.User;
import com.example.raid_hub.service.UserService;
import jakarta.validation.Valid;
import java.security.Principal;
import java.util.HashMap;
import java.util.Map;
import lombok.RequiredArgsConstructor;
import org.springframework.http.HttpStatus;
import org.springframework.http.ResponseEntity;
import org.springframework.security.access.prepost.PreAuthorize;
import org.springframework.security.core.Authentication;
import org.springframework.security.core.GrantedAuthority;
import org.springframework.web.bind.annotation.*;

@RestController
@RequestMapping("/api/users")
@RequiredArgsConstructor
public class UserController {

  private final UserService userService;

  @PutMapping("/change-password")
  @PreAuthorize("hasRole('ADMIN')")
  public ResponseEntity<Map<String, String>> changePassword(
      Principal principal, 
      @Valid @RequestBody PasswordChangeDto dto) {
    
    userService.changePassword(principal.getName(), dto);
    Map<String, String> response = new HashMap<>();
    response.put("message", "비밀번호가 성공적으로 변경되었습니다.");
    return ResponseEntity.ok(response);
  }

  @GetMapping("/me")
  public ResponseEntity<Map<String, Object>> getCurrentUser(Authentication authentication) {
    Map<String, Object> response = new HashMap<>();
    if (authentication != null && authentication.isAuthenticated()) {
      response.put("authenticated", true);
      response.put("username", authentication.getName());

      String role =
          authentication.getAuthorities().stream()
              .map(GrantedAuthority::getAuthority)
              .findFirst()
              .orElse("ROLE_USER")
              .replace("ROLE_", "");

      response.put("role", role);
      return ResponseEntity.ok(response);
    }

    response.put("authenticated", false);
    return ResponseEntity.status(HttpStatus.UNAUTHORIZED).body(response);
  }

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
