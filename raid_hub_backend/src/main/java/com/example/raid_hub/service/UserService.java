package com.example.raid_hub.service;

import com.example.raid_hub.dto.UserRegistrationDto;
import com.example.raid_hub.dto.PasswordChangeDto;
import com.example.raid_hub.entity.User;
import com.example.raid_hub.repository.UserRepository;
import org.springframework.security.crypto.password.PasswordEncoder;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

@Service
@Transactional
public class UserService {

  private final UserRepository userRepository;
  private final PasswordEncoder passwordEncoder;

  public UserService(UserRepository userRepository, PasswordEncoder passwordEncoder) {
    this.userRepository = userRepository;
    this.passwordEncoder = passwordEncoder;
  }

  @Transactional
  public void changePassword(String username, PasswordChangeDto dto) {
    User user = userRepository.findByUsername(username)
        .orElseThrow(() -> new RuntimeException("사용자를 찾을 수 없습니다."));

    if (!passwordEncoder.matches(dto.getCurrentPassword(), user.getPassword())) {
      throw new RuntimeException("현재 비밀번호가 일치하지 않습니다.");
    }

    user.setPassword(passwordEncoder.encode(dto.getNewPassword()));
    userRepository.save(user);
  }

  public User registerUser(UserRegistrationDto dto) {
    if (userRepository.findByUsername(dto.getUsername()).isPresent()) {
      throw new IllegalArgumentException("이미 존재하는 사용자입니다. 사용자 이름: " + dto.getUsername());
    }

    User user =
        User.builder()
            .username(dto.getUsername())
            .password(passwordEncoder.encode(dto.getPassword()))
            .role("USER") // 항상 USER로 설정
            .enabled(false) // 신규 사용자는 비활성화 상태로 등록
            .build();

    return userRepository.save(user);
  }

  @Transactional(readOnly = true)
  public boolean existsByUsername(String username) {
    return userRepository.findByUsername(username).isPresent();
  }
}
