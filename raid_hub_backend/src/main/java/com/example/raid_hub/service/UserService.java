package com.example.raid_hub.service;

import com.example.raid_hub.dto.UserRegistrationDto;
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
