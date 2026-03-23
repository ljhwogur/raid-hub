# Code Review 가이드

---

## 📊 요약

| 항목 | 현재 상태 | 목표 | 격차 |
|------|-----------|------|------|
| 테스트 커버리지 | ~0% | 70%+ | -70% |
| 보안 검증 | 70% | 95% | -25% |
| 코드 중복 | 중 | 낮음 | - |
| API 문서화 | 0% | 100% | -100% |
| Javadoc | 5% | 80% | -75% |

**Overall Score**: **66/100** (Needs Work)

---

## 🔴 Critical Issues (즉시 수정 필요)

> Critical 이슈는 **보안 취약점** 또는 **기능 장애**를 유발할 수 있는 문제입니다.
> 이슈 해결 전에 새 기능 개발 중단 권장.

### 1. 비밀번호 검증 누락 - 보안 취약점 🔐

**위치**: `raid_hub_backend/src/main/java/com/example/raid_hub/dto/PasswordChangeDto.java`

**문제**:
```java
@NotBlank private String newPassword;  // ⚠️ 길이/복잡도 검증 없음
```

사용자가 "a", "1", "!" 같은 1자 비밀번호로 변경 가능합니다.

**영향**:
- 보안 취약점: 암호 추정 용이
- 사용자 데이터 보호 실패

**해결 방법**:
```java
package com.example.raid_hub.dto;

import jakarta.validation.constraints.NotBlank;
import jakarta.validation.constraints.Pattern;
import jakarta.validation.constraints.Size;
import lombok.Getter;
import lombok.Setter;

@Getter
@Setter
public class PasswordChangeDto {

  @NotBlank(message = "현재 비밀번호는 필수입니다")
  private String currentPassword;

  @NotBlank(message = "새 비밀번호는 필수입니다")
  @Size(min = 8, max = 30, message = "비밀번호는 8자 이상 30자 이하여야 합니다")
  @Pattern(regexp = "^(?=.*[A-Za-z])(?=.*\\d)[A-Za-z\\d@$!%*#?&]{8,}$",
           message = "비밀번호는 영문, 숫자를 포함한 8자 이상이어야 합니다")
  private String newPassword;
}
```

---

### 2. 테스트 커버리지 부재 - 회귀 위험 ⚠️

**위치**: `raid_hub_backend/src/test/`, `raid_hub_frontend/test/`

**문제**:
```
백엔드 테스트:
├── RaidHubApplicationTests.java  (1개 테스트, DB 연결 실패)
└── 단위 테스트: 0개

프론트엔드 테스트:
└── 테스트: 0개
```

**영향**:
- 버그 수정 후 회귀(Regression) 발견 불가
- 리팩토링 시 기능 파악 위험
- CI/CD에서 코드 품질 보장 불가

**해결 방법 - 백엔드 단위 테스트**:

```java
// src/test/java/com/example/raid_hub/service/UserServiceTest.java
package com.example.raid_hub.service;

import com.example.raid_hub.dto.PasswordChangeDto;
import com.example.raid_hub.dto.UserRegistrationDto;
import com.example.raid_hub.entity.User;
import com.example.raid_hub.exception.InvalidPasswordException;
import com.example.raid_hub.exception.UserNotFoundException;
import com.example.raid_hub.repository.UserRepository;
import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.DisplayName;
import org.junit.jupiter.api.Test;
import org.junit.jupiter.api.extension.ExtendWith;
import org.mockito.Mock;
import org.mockito.junit.jupiter.MockitoExtension;
import org.springframework.security.crypto.password.PasswordEncoder;

import java.util.Optional;

import static org.junit.jupiter.api.Assertions.*;
import static org.mockito.ArgumentMatchers.any;
import static org.mockito.Mockito.*;

@ExtendWith(MockitoExtension.class)
@DisplayName("UserService 단위 테스트")
class UserServiceTest {

    @Mock
    private UserRepository userRepository;

    @Mock
    private PasswordEncoder passwordEncoder;

    private UserService userService;

    @BeforeEach
    void setUp() {
        userService = new UserService(userRepository, passwordEncoder);
    }

    @Test
    @DisplayName("존재하지 않는 사용자로 비밀번호 변경 시 예외 발생")
    void whenChangePasswordWithNonExistentUser_shouldThrowException() {
        // given
        String username = "nonexistent";
        PasswordChangeDto dto = new PasswordChangeDto();
        dto.setCurrentPassword("oldpass");
        dto.setNewPassword("newpass123");

        when(userRepository.findByUsername(username)).thenReturn(Optional.empty());

        // when & then
        assertThrows(RuntimeException.class,
            () -> userService.changePassword(username, dto));
    }

    @Test
    @DisplayName("잘못된 현재 비밀번호로 변경 시 예외 발생")
    void whenChangePasswordWithWrongCurrentPassword_shouldThrowException() {
        // given
        String username = "testuser";
        User user = User.builder()
            .username(username)
            .password("encoded_oldpass")
            .build();
        PasswordChangeDto dto = new PasswordChangeDto();
        dto.setCurrentPassword("wrongpass");
        dto.setNewPassword("newpass123");

        when(userRepository.findByUsername(username)).thenReturn(Optional.of(user));
        when(passwordEncoder.matches("wrongpass", "encoded_oldpass")).thenReturn(false);

        // when & then
        assertThrows(RuntimeException.class,
            () -> userService.changePassword(username, dto));
    }

    @Test
    @DisplayName("올바른 비밀번호로 변경 성공")
    void whenChangePasswordWithValidCredentials_shouldUpdatePassword() {
        // given
        String username = "testuser";
        User user = User.builder()
            .username(username)
            .password("encoded_oldpass")
            .build();
        PasswordChangeDto dto = new PasswordChangeDto();
        dto.setCurrentPassword("oldpass");
        dto.setNewPassword("newpass123");

        when(userRepository.findByUsername(username)).thenReturn(Optional.of(user));
        when(passwordEncoder.matches("oldpass", "encoded_oldpass")).thenReturn(true);
        when(passwordEncoder.encode("newpass123")).thenReturn("encoded_newpass123");

        // when
        userService.changePassword(username, dto);

        // then
        verify(passwordEncoder).encode("newpass123");
        verify(userRepository).save(any(User.class));
        assertEquals("encoded_newpass123", user.getPassword());
    }

    @Test
    @DisplayName("이미 존재하는 사용자명으로 회원가입 시 예외 발생")
    void whenRegisterWithExistingUsername_shouldThrowException() {
        // given
        String username = "existinguser";
        User existingUser = User.builder().username(username).build();
        UserRegistrationDto dto = new UserRegistrationDto();
        dto.setUsername(username);
        dto.setPassword("password123");

        when(userRepository.findByUsername(username)).thenReturn(Optional.of(existingUser));

        // when & then
        assertThrows(IllegalArgumentException.class,
            () -> userService.registerUser(dto));
        verify(userRepository, never()).save(any(User.class));
    }
}
```

**해결 방법 - 프론트엔드 위젯 테스트**:

```dart
// test/widgets/cheat_sheet_card_test.dart
import 'package:flutter_test/flutter_test.dart';
import 'package:raid_hub_frontend/widgets/cheat_sheet_card.dart';
import 'package:raid_hub_frontend/models/cheat_sheet.dart';

void main() {
  group('CheatSheetCard Widget', () {
    testWidgets('기본 정보를 올바르게 표시', (WidgetTester tester) async {
      // given
      final cheatSheet = CheatSheet(
        id: 1,
        title: '발탄 1게이트',
        raidName: '발탄',
        gate: '1게이트',
        imageUrl: 'https://example.com/image.jpg',
        uploaderName: 'admin',
        createdAt: DateTime.now(),
      );

      // when
      await tester.pumpWidget(
        CheatSheetCard(cheatSheet: cheatSheetSheet),
      );

      // then
      expect(find.text('발탄 1게이트'), findsOneWidget);
      expect(find.text('발탄'), findsOneWidget);
      expect(find.text('1게이트'), findsOneWidget);
    });

    testWidgets('null 이미지일 때 플레이스홀더 표시', (WidgetTester tester) async {
      // given
      final cheatSheet = CheatSheet(
        id: 1,
        title: '발탄 1게이트',
        raidName: '발탄',
        gate: '1게이트',
        imageUrl: null,
        uploaderName: 'admin',
        createdAt: DateTime.now(),
      );

      // when
      await tester.pumpWidget(
        CheatSheetCard(cheatSheet: cheatSheet),
      );

      // then
      expect(find.byType(Placeholder), findsOneWidget);
    });
  });
}
```

---

### 3. 범용 예외 사용 - 정확한 에러 처리 불가 🔄

**위치**: `raid_hub_backend/src/main/java/com/example/raid_hub/service/UserService.java`

**문제**:
```java
.orElseThrow(() -> new RuntimeException("사용자를 찾을 수 없습니다."));
throw new RuntimeException("현재 비밀번호가 일치하지 않습니다.");
```

모든 예외가 `RuntimeException`이라면 GlobalExceptionHandler에서 구체적 처리 불가.

**영향**:
- 에러 타입별 분기 처리 불가
- HTTP 상태 코드 세분화 어려움
- 로깅/모니터링 세밀하게 불가

**해결 방법**:

```java
// src/main/java/com/example/raid_hub/exception/UserNotFoundException.java
package com.example.raid_hub.exception;

public class UserNotFoundException extends RuntimeException {

    public UserNotFoundException(String username) {
        super("사용자를 찾을 수 없습니다: " + username);
    }
}
```

```java
// src/main/java/com/example/raid_hub/exception/InvalidPasswordException.java
package com.example.raid_hub.exception;

public class InvalidPasswordException extends RuntimeException {

    public InvalidPasswordException() {
        super("현재 비밀번호가 일치하지 않습니다.");
    }
}
```

```java
// src/main/java/com/example/raid_hub/exception/VideoNotFoundException.java
package com.example.raid_hub.exception;

public class VideoNotFoundException extends RuntimeException {

    public VideoNotFoundException(Long id) {
        super("비디오를 찾을 수 없습니다: " + id);
    }
}
```

```java
// src/main/java/com/example/raid_hub/config/GlobalExceptionHandler.java (수정)
package com.example.raid_hub.config;

import com.example.raid_hub.exception.InvalidPasswordException;
import com.example.raid_hub.exception.UserNotFoundException;
import com.example.raid_hub.exception.VideoNotFoundException;
import java.util.HashMap;
import java.util.Map;
import org.springframework.http.HttpStatus;
import org.springframework.http.ResponseEntity;
import org.springframework.web.bind.MethodArgumentNotValidException;
import org.springframework.web.bind.annotation.ExceptionHandler;
import org.springframework.web.bind.annotation.RestControllerAdvice;

@RestControllerAdvice
public class GlobalExceptionHandler {

  @ExceptionHandler(UserNotFoundException.class)
  public ResponseEntity<Map<String, Object>> handleUserNotFoundException(
      UserNotFoundException ex) {
    return ResponseEntity.status(HttpStatus.NOT_FOUND)
        .body(createErrorResponse(ex.getMessage()));
  }

  @ExceptionHandler(InvalidPasswordException.class)
  public ResponseEntity<Map<String, Object>> handleInvalidPasswordException(
      InvalidPasswordException ex) {
    return ResponseEntity.status(HttpStatus.UNAUTHORIZED)
        .body(createErrorResponse(ex.getMessage()));
  }

  @ExceptionHandler(MethodArgumentNotValidException.class)
  public ResponseEntity<Map<String, Object>> handleValidationException(
      MethodArgumentNotValidException ex) {
    String errorMessage = ex.getBindingResult().getFieldErrors().stream()
        .findFirst()
        .map(error -> error.getDefaultMessage())
        .orElse("검증 오류가 발생했습니다.");

    return ResponseEntity.status(HttpStatus.BAD_REQUEST)
        .body(createErrorResponse(errorMessage));
  }

  @ExceptionHandler(Exception.class)
  public ResponseEntity<Map<String, Object>> handleGeneralException(Exception ex) {
    return ResponseEntity.status(HttpStatus.INTERNAL_SERVER_ERROR)
        .body(createErrorResponse("서버 오류가 발생했습니다."));
  }

  private Map<String, Object> createErrorResponse(String message) {
    Map<String, Object> response = new HashMap<>();
    response.put("success", false);
    response.put("message", message);
    return response;
  }
}
```

---

### 4. RateLimitInterceptor 문법 오류 확인 필요 ⚠️

**위치**: `raid_hub_backend/src/main/java/com/example/raid_hub/config/RateLimitInterceptor.java:25,32`

**문제**:
```java
.addLimit(Bandwidth.classic(100, Refill.greedy(100, Duration.ofMinutes(1))))
                                                                    // ⚠️ )) 중복?
```

**조치 필요**:
```bash
cd raid_hub_backend
./gradlew spotlessCheck
```

중복 괄호가 실제로 존재한다면 Spotless가 수정할 것입니다.

---

## 🟡 Important Issues (개발 전 수정)

### 5. 에러 응답 코드 중복 제거 🔄

**위치**: `raid_hub_backend/src/main/java/com/example/raid_hub/config/GlobalExceptionHandler.java`

**해결 방법**:

```java
// error/ErrorResponse.java (새 파일)
package com.example.raid_hub.error;

import com.fasterxml.jackson.annotation.JsonInclude;
import lombok.AllArgsConstructor;
import lombok.Builder;
import lombok.Data;

@Data
@Builder
@AllArgsConstructor
@JsonInclude(JsonInclude.Include.NON_NULL)
public class ErrorResponse {

    private boolean success;
    private String message;
    private String code;
    private Object details;

    public static ErrorResponse of(String message) {
        return ErrorResponse.builder()
            .success(false)
            .message(message)
            .build();
    }

    public static ErrorResponse of(String code, String message) {
        return ErrorResponse.builder()
            .success(false)
            .code(code)
            .message(message)
            .build();
    }
}
```

**수정된 GlobalExceptionHandler**:

```java
package com.example.raid_hub.config;

import com.example.raid_hub.error.ErrorResponse;
import com.example.raid_hub.exception.InvalidPasswordException;
import com.example.raid_hub.exception.UserNotFoundException;
import jakarta.validation.ConstraintViolation;
import org.springframework.http.HttpStatus;
import org.springframework.http.ResponseEntity;
import org.springframework.web.bind.MethodArgumentNotValidException;
import org.springframework.web.bind.annotation.ExceptionHandler;
import org.springframework.web.bind.annotation.RestControllerAdvice;

@RestControllerAdvice
public class GlobalExceptionHandler {

  @ExceptionHandler(UserNotFoundException.class)
  public ResponseEntity<ErrorResponse> handleUserNotFoundException(UserNotFoundException ex) {
    return ResponseEntity.status(HttpStatus.NOT_FOUND)
        .body(ErrorResponse.of("USER_NOT_FOUND", ex.getMessage()));
  }

  @ExceptionHandler(InvalidPasswordException.class)
  public ResponseEntity<ErrorResponse> handleInvalidPasswordException(
      InvalidPasswordException ex) {
    return ResponseEntity.status(HttpStatus.UNAUTHORIZED)
        .body(ErrorResponse.of("INVALID_PASSWORD", ex.getMessage()));
  }

  @ExceptionHandler(MethodArgumentNotValidException.class)
  public ResponseEntity<ErrorResponse> handleValidationException(
      MethodArgumentNotValidException ex) {
    String errorMessage = ex.getBindingResult().getFieldErrors().stream()
        .findFirst()
        .map(error -> error.getDefaultMessage())
        .orElse("검증 오류가 발생했습니다.");

    return ResponseEntity.status(HttpStatus.BAD_REQUEST)
        .body(ErrorResponse.of("VALIDATION_ERROR", errorMessage));
  }

  @ExceptionHandler(Exception.class)
  public ResponseEntity<ErrorResponse> handleGeneralException(Exception ex) {
    return ResponseEntity.status(HttpStatus.INTERNAL_SERVER_ERROR)
        .body(ErrorResponse.of("INTERNAL_ERROR", "서버 오류가 발생했습니다."));
  }
}
```

---

### 6. API 문서 추가 (Swagger/OpenAPI) 📚

**build.gradle 수정**:

```gradle
dependencies {
    implementation 'org.springdoc:springdoc-openapi-starter-webmvc-ui:2.3.0'
    // ... 기존 의존성
}
```

**application.yml 추가**:

```yaml
springdoc:
  api-docs:
    path: /api-docs
  swagger-ui:
    path: /swagger-ui.html
    tags-sorter: alpha
    operations-sorter: alpha
  default-consumes-media-type: application/json
  default-produces-media-type: application/json
```

**Controller에 API 문서 추가**:

```java
import io.swagger.v3.oas.annotations.Operation;
import io.swagger.v3.oas.annotations.tags.Tag;

@Tag(name = "User", description = "사용자 관리 API")
@RestController
@RequestMapping("/api/users")
@RequiredArgsConstructor
public class UserController {

    private final UserService userService;

    @Operation(summary = "현재 사용자 정보 조회", description = "인증된 사용자의 정보를 반환합니다.")
    @GetMapping("/me")
    public ResponseEntity<Map<String, Object>> getCurrentUser(Authentication authentication) {
        // ...
    }

    @Operation(summary = "비밀번호 변경", description = "현재 로그인한 사용자의 비밀번호를 변경합니다.")
    @PutMapping("/change-password")
    public ResponseEntity<Map<String, String>> changePassword(
        Principal principal, @Valid @RequestBody PasswordChangeDto dto) {
        // ...
    }
}
```

---

### 7. UTF-8 디코딩 헬퍼 메서드 📝

**위치**: `raid_hub_frontend/lib/services/api_service.dart`

**해결 방법**:

```dart
// lib/services/api_service.dart (수정)

import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:http/browser_client.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';

class ApiService {
  // ... 기존 필드들

  /// 공통 응답 파싱 메서드 (UTF-8 디코딩 처리)
  T _parseResponse<T>(http.Response response, T Function(dynamic) fromJson) {
    if (response.statusCode == 200 || response.statusCode == 201) {
      try {
        final body = jsonDecode(utf8.decode(response.bodyBytes));
        return fromJson(body);
      } catch (e) {
        debugPrint('Response parsing error: $e');
        throw Exception('응답 파싱 오류');
      }
    }
    throw Exception('요청 실패: ${response.statusCode}');
  }

  /// 공통 리스트 응답 파싱 메서드
  List<T> _parseListResponse<T>(http.Response response, T Function(dynamic) fromJson) {
    if (response.statusCode == 200) {
      try {
        final body = jsonDecode(utf8.decode(response.bodyBytes));
        if (body is List) {
          return body.map((e) => fromJson(e)).toList();
        }
        throw Exception('잘못된 응답 형식');
      } catch (e) {
        debugPrint('Response parsing error: $e');
        throw Exception('응답 파싱 오류');
      }
    }
    throw Exception('요청 실패: ${response.statusCode}');
  }

  Future<List<RaidVideo>> getVideos() async {
    try {
      final response = await _client.get(
        Uri.parse(baseUrl),
        headers: _authService.getAuthHeaders(),
      );
      return _parseListResponse<RaidVideo>(
        response,
        (body) => RaidVideo.fromJson(body),
      );
    } catch (e) {
      throw Exception('Error fetching videos: $e');
    }
  }

  Future<RaidVideo> createVideo(RaidVideo video) async {
    try {
      final response = await _client.post(
        Uri.parse(baseUrl),
        headers: _authService.getAuthHeaders(),
        body: jsonEncode(video.toJson()),
      );
      return _parseResponse<RaidVideo>(
        response,
        (body) => RaidVideo.fromJson(body),
      );
    } catch (e) {
      debugPrint('Error creating video: $e');
      throw e;
    }
  }

  Future<List<PlaylistItem>> getPlaylistItems(String playlistId) async {
    try {
      final response = await _client.get(
        Uri.parse('$_apiBaseUrl/youtube/playlist-items?playlistId=$playlistId&fetchAll=true'),
      );
      final jsonData = _parseResponse<Map<String, dynamic>>(
        response,
        (body) => body,
      );
      final List<dynamic> items = jsonData['items'] ?? [];
      return items.map((e) => PlaylistItem.fromJson(e)).toList();
    } catch (e) {
      throw Exception('Error fetching playlist items: $e');
    }
  }
}
```

---

## 🔵 Minor Issues (개선 제안)

### 8. UserController.getCurrentUser 메서드 분리 🔧

**해결 방법**:

```java
// dto/UserInfoResponse.java (새 파일)
package com.example.raid_hub.dto;

import lombok.AllArgsConstructor;
import lombok.Builder;
import lombok.Data;

@Data
@Builder
@AllArgsConstructor
public class UserInfoResponse {

    private boolean authenticated;
    private String username;
    private String role;
}
```

```java
// UserController.java (수정)
@RestController
@RequestMapping("/api/users")
@RequiredArgsConstructor
public class UserController {

    private final UserService userService;

    @GetMapping("/me")
    public ResponseEntity<UserInfoResponse> getCurrentUser(Authentication authentication) {
        return ResponseEntity.ok(buildUserInfoResponse(authentication));
    }

    private UserInfoResponse buildUserInfoResponse(Authentication authentication) {
        if (authentication == null || !authentication.isAuthenticated()) {
            return UserInfoResponse.builder()
                .authenticated(false)
                .build();
        }

        String role = authentication.getAuthorities().stream()
            .map(GrantedAuthority::getAuthority)
            .findFirst()
            .orElse("ROLE_USER")
            .replace("ROLE_", "");

        return UserInfoResponse.builder()
            .authenticated(true)
            .username(authentication.getName())
            .role(role)
            .build();
    }
}
```

---

### 9. Rate Limiting 개선 (인증 기반) 🚦

**해결 방법**:

```java
// config/RateLimitInterceptor.java (개선)
@Component
public class RateLimitInterceptor implements HandlerInterceptor {

    private final Map<String, Bucket> generalBuckets = new ConcurrentHashMap<>();
    private final Map<String, Bucket> logBuckets = new ConcurrentHashMap<>();

    // 인증된 사용자의 경우 더 높은 제한
    private static final int AUTHENTICATED_LIMIT = 500;  // 인증된 사용자: 500/분
    private static final int ANONYMOUS_LIMIT = 100;     // 익명 사용자: 100/분

    @Override
    public boolean preHandle(HttpServletRequest request, HttpServletResponse response, Object handler)
        throws Exception {

        String ip = getClientIP(request);
        String path = request.getRequestURI();

        // 인증 여부 확인
        String authHeader = request.getHeader("Authorization");
        int limit = (authHeader != null && authHeader.startsWith("Bearer"))
            ? AUTHENTICATED_LIMIT : ANONYMOUS_LIMIT;

        // 로그 수집 API 전용 제한
        if (path.startsWith("/api/stats/log")) {
            Bucket logBucket = logBuckets.computeIfAbsent(ip, k -> createLogBucket());
            if (!logBucket.tryConsume(1)) {
                response.setStatus(HttpStatus.TOO_MANY_REQUESTS.value());
                response.getWriter().write("로그 요청이 너무 많습니다. 잠시 후 다시 시도해주세요.");
                return false;
            }
        }

        // 사용자별 제한
        Bucket bucket = generalBuckets.computeIfAbsent(
            ip + ":" + limit,  // 인증 여부별로 분리
            k -> createBucket(limit)
        );

        if (!bucket.tryConsume(1)) {
            response.setStatus(HttpStatus.TOO_MANY_REQUESTS.value());
            response.getWriter().write("요청이 너무 많습니다. 잠시 후 다시 시도해주세요.");
            return false;
        }

        return true;
    }

    private Bucket createBucket(int limit) {
        return Bucket.builder()
            .addLimit(Bandwidth.classic(limit, Refill.greedy(limit, Duration.ofMinutes(1))))
            .build();
    }
}
```

---

### 10. Javadoc 추가 📝

```java
/**
 * 사용자 관리 Service.
 * <p>
 * 사용자 등록, 비밀번호 변경 등 사용자 관련 비즈니스 로직을 담당합니다.
 * </p>
 */
@Service
@Transactional
public class UserService {

    /**
     * 사용자 비밀번호를 변경합니다.
     *
     * @param username 비밀번호를 변경할 사용자명
     * @param dto 현재 비밀번호와 새 비밀번호를 포함한 DTO
     * @throws UserNotFoundException 사용자를 찾을 수 없을 때
     * @throws InvalidPasswordException 현재 비밀번호가 일치하지 않을 때
     */
    @Transactional
    public void changePassword(String username, PasswordChangeDto dto) {
        // ...
    }
}
```

---

## ✅ 체크리스트 (이슈 해결 후)

### 보안 (Security)
- [ ] PasswordChangeDto에 newPassword 검증 추가
- [ ] UserRegistrationDto 복잡도 검증 강화
- [ ] IP 추출 로직 개선 (신뢰할 프록시만 허용)
- [ ] 민감 정보 로깅 방지 확인

### 테스트 (Testing)
- [ ] UserService 단위 테스트 작성
- [ ] RaidVideoService 단위 테스트 작성
- [ ] UserController 통합 테스트 작성
- [ ] 프론트엔드 위젯 테스트 작성
- [ ] 테스트 커버리지 60% 이상 달성

### 코드 품질 (Code Quality)
- [ ] 사용자 정의 예외 도입 완료
- [ ] ErrorResponse 공통 클래스 추가
- [ ] UTF-8 디코딩 헬퍼 메서드 추가
- [ ] RateLimitInterceptor 문법 오류 확인/수정
- [ ] GlobalExceptionHandler 중복 제거

### 문서화 (Documentation)
- [ ] Springdoc OpenAPI 의존성 추가
- [ ] Swagger UI 접속 확인
- [ ] Controller에 @Operation, @Tag 추가
- [ ] Javadoc 추가

---

## 📈 다음 단계 (Action Items)

### Week 1: Critical 이슈 해결
1. [ ] PasswordChangeDto 검증 추가
2. [ ] 사용자 정의 예외 클래스 생성 (3개)
3. [ ] GlobalExceptionHandler 수정
4. [ ] UserService 단위 테스트 작성 (최소 4개)

### Week 2: 테스트 커버리지 확보
1. [ ] RaidVideoService 단위 테스트
2. [ ] UserController 통합 테스트
3. [ ] 프론트엔드 위젯 테스트 (최소 2개)
4. [ ] 테스트 커버리지 60% 달성 확인

### Week 3: 문서화 및 개선
1. [ ] Swagger/OpenAPI 추가
2. [ ] UTF-8 헬퍼 메서드 추가
3. [ ] Javadoc 추가
4. [ ] Rate Limiting 개선

### Week 4: 최종 검토
1. [ ] 전체 코드 리뷰 (/code-review 재실행)
2. [ ] Trinity Score 재측정
3. [ ] 목표 점수 80점 이상 달성 확인

---

## 🛠️ 유용한 명령어

```bash
# 백엔드
cd raid_hub_backend

# 컴파일 확인
./gradlew compileJava

# 테스트 실행
./gradlew test

# 테스트 커버리지 확인 (JaCoCo 추가 후)
./gradlew jacocoTestReport

# 코드 포맷팅 체크
./gradlew spotlessCheck

# 코드 포맷팅 적용
./gradlew spotlessApply

# 의존성 취약점 확인
./gradlew dependencyCheckAnalyze
```

```bash
# 프론트엔드
cd raid_hub_frontend

# 분석 실행
flutter analyze

# 테스트 실행
flutter test

# 테스트 커버리지
flutter test --coverage

# 포맷팅 체크
dart format --set-exit-if-changed .

# 포맷팅 적용
dart format .
```

---

## 📚 참고 자료

- [Spring Security Best Practices](https://docs.spring.io/spring-security/reference/servlet/configuration/java.html)
- [Spring Validation](https://docs.spring.io/spring-framework/reference/core/validation/overview.html)
- [Bucket4j Documentation](https://bucket4j.com/)
- [Flutter Testing](https://docs.flutter.dev/cookbook/testing)
- [JUnit 5 User Guide](https://junit.org/junit5/docs/current/user-guide/)
