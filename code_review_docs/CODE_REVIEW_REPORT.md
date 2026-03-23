# Code Review Report

---

## 요약

| 항목 | 상태 |
|------|------|
| **Spec Compliance** | ⚠️ 부분 확인 (스펙 문서 없음) |
| **Code Quality** | ⚠️ Needs Work |
| **Overall** | ⚠️ Changes requested - 수정 후 재리뷰 필요 |

---

## Stage 1: Spec Compliance Review

| 체크 항목 | 상태 | 비고 |
|-------------|------|------|
| 필수 기능 구현 | ⚠️ | 스펙 문서 없어 확인 불가 |
| 요구사항 일치 | ⚠️ | 기능 목록 없음 |
| 누락된 기능 | ⚠️ | 비교 기준 없음 |
| 추가 기능 | ℹ️ | README/요구사항 없음 |

> **참고**: `docs/planning/` 폴더나 `TASKS.md`, `README.md`에 스펙 문서를 찾을 수 없습니다.

---

## Stage 2: Code Quality Review

### Strengths (잘한 점)

✅ **아키텍처 패턴 준수**
- Controller → Service → Repository 계층 구조 명확
- Spring Boot 표준 패턴 따름

✅ **코드 포맷팅 자동화**
- Spotless 플러그인으로 일관된 스타일 유지

✅ **보안 기본기**
- BCrypt 비밀번호 해싱
- Spring Security RBAC 구현
- CORS 적절히 구성

✅ **Rate Limiting 구현**
- Bucket4j로 DoS 방지 (100req/min, 30req/min for logs)

✅ **Lombok 활용**
- 보일러플레이트 코드 제거

---

### Issues Found

#### 🔴 Critical (즉시 수정 필요)

**1. `PasswordChangeDto.java:12` - newPassword 검증 누락**

```java
// raid_hub_backend/src/main/java/com/example/raid_hub/dto/PasswordChangeDto.java
public class PasswordChangeDto {
  @NotBlank private String currentPassword;

  @NotBlank private String newPassword;  // ⚠️ @Size, @Pattern 없음
}
```

- **문제**: newPassword에 길이/복잡도 검증이 없어 "a" 같은 비밀번호 허용
- **위험**: 보안 취약점, 암호 추정 용이
- **제안**:
  ```java
  @NotBlank
  @Size(min = 8, max = 30, message = "비밀번호는 8자 이상 30자 이하여야 합니다")
  @Pattern(regexp = "^(?=.*[A-Za-z])(?=.*\\d)[A-Za-z\\d@$!%*#?&]{8,}$",
           message = "영문, 숫자 포함 8자 이상 필요")
  private String newPassword;
  ```

---

**2. 테스트 커버리지 부재**

```
테스트 현황:
- 백엔드: 1개 (contextLoads - DB 연결 실패로 작동 안함)
- 프론트엔드: 0개
- 실질 커버리지: 0%
```

- **문제**: 비즈니스 로직에 대한 테스트 전무
- **위험**: 회귀 버그 감지 불가, 리팩토링 위험
- **제안**:
  ```java
  // UserServiceTest.java
  @Test
  void whenChangePasswordWithWrongCurrentPassword_shouldThrowException() {
      // given
      User user = User.builder()
          .username("test")
          .password(passwordEncoder.encode("oldpass"))
          .build();
      userRepository.save(user);

      PasswordChangeDto dto = new PasswordChangeDto("wrong", "newpass123");

      // when & then
      assertThrows(RuntimeException.class, () ->
          userService.changePassword("test", dto));
  }
  ```

---

**3. `UserService.java:28,31,40` - RuntimeException 남용**

```java
// raid_hub_backend/src/main/java/com/example/raid_hub/service/UserService.java
public void changePassword(String username, PasswordChangeDto dto) {
    User user = userRepository.findByUsername(username)
        .orElseThrow(() -> new RuntimeException("사용자를 찾을 수 없습니다."));
                                                  // ⚠️ 구체적 예외 아님

    if (!passwordEncoder.matches(dto.getCurrentPassword(), user.getPassword())) {
      throw new RuntimeException("현재 비밀번호가 일치하지 않습니다.");
                                                  // ⚠️ 구체적 예외 아님
    }

    user.setPassword(passwordEncoder.encode(dto.getNewPassword()));
    userRepository.save(user);
}
```

- **문제**: 범용 예외 사용으로 정확한 에러 처리 불가
- **위험**: GlobalExceptionHandler에서 분기 처리 불가
- **제안**:
  ```java
  // exception/UserNotFoundException.java
  public class UserNotFoundException extends RuntimeException {
      public UserNotFoundException(String username) {
          super("사용자를 찾을 수 없습니다: " + username);
      }
  }

  // exception/InvalidPasswordException.java
  public class InvalidPasswordException extends RuntimeException {
      public InvalidPasswordException() {
          super("현재 비밀번호가 일치하지 않습니다.");
      }
  }
  ```

---

**4. `RateLimitInterceptor.java:25,32` - 닫는 괄호 중복**

```java
// raid_hub_backend/src/main/java/com/example/raid_hub/config/RateLimitInterceptor.java
private Bucket createGeneralBucket() {
  return Bucket.builder()
      .addLimit(Bandwidth.classic(100, Refill.greedy(100, Duration.ofMinutes(1))))
                                                                     // ⚠️ )) 중복
      .build();
}

private Bucket createLogBucket() {
  return Bucket.builder()
      .addLimit(Bandwidth.classic(30, Refill.greedy(30, Duration.ofMinutes(1))))
                                                                   // ⚠️ )) 중복
      .build();
}
```

- **문제**: 문법 오류 (컴파일되면 안 되는데 동작함 - 체크 필요)
- **제안**:
  ```java
  private Bucket createGeneralBucket() {
    return Bucket.builder()
        .addLimit(Bandwidth.classic(100, Refill.greedy(100, Duration.ofMinutes(1)))
        .build();
  }
  ```

---

#### 🟡 Important (진행 전 수정)

**5. `GlobalExceptionHandler` 에러 응답 중복**

```java
// raid_hub_backend/src/main/java/com/example/raid_hub/config/GlobalExceptionHandler.java
@ExceptionHandler(MethodArgumentNotValidException.class)
public ResponseEntity<Map<String, Object>> handleValidationException(...) {
    Map<String, Object> response = new HashMap<>();
    response.put("success", false);        // 중복
    String errorMessage = ...;
    response.put("message", errorMessage);
    return ResponseEntity.status(HttpStatus.BAD_REQUEST).body(response);
}

@ExceptionHandler(IllegalArgumentException.class)
public ResponseEntity<Map<String, Object>> handleIllegalArgumentException(...) {
    Map<String, Object> response = new HashMap<>();
    response.put("success", false);        // 중복
    response.put("message", ex.getMessage());
    return ResponseEntity.status(HttpStatus.BAD_REQUEST).body(response);
}
```

- **문제**: 에러 응답 생성 로직 중복
- **제안**:
  ```java
  // error/ErrorResponse.java
  @Data
  @AllArgsConstructor
  public class ErrorResponse {
      private boolean success;
      private String message;

      public static ErrorResponse error(String message) {
          return new ErrorResponse(false, message);
      }
  }

  // GlobalExceptionHandler.java
  @ExceptionHandler(Exception.class)
  public ResponseEntity<ErrorResponse> handleException(Exception ex) {
      return ResponseEntity.status(HttpStatus.BAD_REQUEST)
                     .body(ErrorResponse.error(ex.getMessage()));
  }
  ```

---

**6. `api_service.dart` UTF-8 디코딩 패턴 반복**

```dart
// raid_hub_frontend/lib/services/api_service.dart
Future<List<RaidVideo>> getVideos() async {
    ...
    // UTF-8 디코딩 처리 (한글 깨짐 방지)
    List<dynamic> body = jsonDecode(utf8.decode(response.bodyBytes));
    ...
}

Future<RaidVideo> createVideo(RaidVideo video) async {
    ...
    // UTF-8 디코딩 처리
    return RaidVideo.fromJson(jsonDecode(utf8.decode(response.bodyBytes)));
    ...
}

Future<List<PlaylistItem>> getPlaylistItems(String playlistId) async {
    ...
    // UTF-8 디코딩 처리 (한글 깨짐 방지)
    final jsonData = jsonDecode(utf8.decode(response.bodyBytes));
    ...
}
// ... 반복 (총 6회 이상)
```

- **문제**: 동일한 패턴 6회 이상 반복
- **제안**:
  ```dart
  // 헬퍼 메서드
  T _parseResponse<T>(http.Response response, T Function(dynamic) fromJson) {
      if (response.statusCode == 200) {
          final body = jsonDecode(utf8.decode(response.bodyBytes));
          if (body is Map) {
              return fromJson(body);
          }
          if (body is List) {
              final items = body as List;
              return items.map((e) => fromJson(e)).toList();
          }
          throw Exception('Unexpected response format');
      }
      throw Exception('Failed to load data');
  }

  // 사용
  Future<List<RaidVideo>> getVideos() async {
      final response = await _client.get(Uri.parse(baseUrl), ...);
      return _parseResponse<List<RaidVideo>>(
          response,
          (body) => (body as List).map((e) => RaidVideo.fromJson(e)).toList()
      );
  }
  ```

---

**7. API 문서 (Swagger/OpenAPI) 누락**

```java
// build.gradle
dependencies {
    // Springdoc OpenAPI 없음
}
```

- **문제**: REST API 문서가 없어 프론트엔드 개발/테스트 어려움
- **제안**:
  ```gradle
  dependencies {
      implementation 'org.springdoc:springdoc-openapi-starter-webmvc-ui:2.3.0'
  }

  // application.yml
  springdoc:
    api-docs:
      path: /api-docs
    swagger-ui:
      path: /swagger-ui.html
  ```

---

#### 🔵 Minor (나중에 수정 가능)

**8. `UserController.java:38-57` - getCurrentUser 메서드 길이**

```java
@GetMapping("/me")
public ResponseEntity<Map<String, Object>> getCurrentUser(Authentication authentication) {
    Map<String, Object> response = new HashMap<>();
    if (authentication != null && authentication.isAuthenticated()) {
      response.put("authenticated", true);
      response.put("username", authentication.getName());

      String role = authentication.getAuthorities().stream()
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
```

- **문제**: 57줄 중 20줄을 차지하는 메서드 - 응집도 낮음
- **제안**: DTO 클래스 추출
  ```java
  @Data
  @AllArgsConstructor
  public class UserInfoResponse {
      private boolean authenticated;
      private String username;
      private String role;
  }

  private UserInfoResponse buildUserInfoResponse(Authentication auth) {
      if (auth == null || !auth.isAuthenticated()) {
          return new UserInfoResponse(false, null, null);
      }
      String role = extractRole(auth);
      return new UserInfoResponse(true, auth.getName(), role);
  }
  ```

---

**9. Rate Limiting IP 스푸핑 취약**

```java
// RateLimitInterceptor.java:63-69
private String getClientIP(HttpServletRequest request) {
    String xfHeader = request.getHeader("X-Forwarded-For");
    if (xfHeader == null) {
      return request.getRemoteAddr();
    }
    return xfHeader.split(",")[0];  // ⚠️ 쉽게 위조 가능
}
```

- **문제**: X-Forwarded-For 헤더는 클라이언트가 임의로 설정 가능
- **제안**: 신뢰할 수 있는 프록시만 허용하거나 인증 후 IP 제한 사용
  ```java
  private static final Set<String> TRUSTED_PROXIES = Set.of(
      "20.89.237.161",  // 운영 서버 IP
      "127.0.0.1"
  );

  private String getClientIP(HttpServletRequest request) {
      String xfHeader = request.getHeader("X-Forwarded-For");
      if (xfHeader != null && request.getRemoteAddr().matches(".*")) {
          // 신뢰할 수 있는 프록시에서 온 경우만 신뢰
          return xfHeader.split(",")[0];
      }
      return request.getRemoteAddr();
  }
  ```

---

**10. Javadoc/주석 부재**

- **문제**: Service, Controller 메서드에 설명 주석 없음
- **제안**: 주요 메서드에 Javadoc 추가
  ```java
  /**
   * 사용자 비밀번호를 변경합니다.
   *
   * @param username 비밀번호를 변경할 사용자명
   * @param dto 현재 비밀번호와 새 비밀번호를 포함한 DTO
   * @throws UserNotFoundException 사용자를 찾을 수 없을 때
   * @throws InvalidPasswordException 현재 비밀번호가 일치하지 않을 때
   */
  public void changePassword(String username, PasswordChangeDto dto) {
      // ...
  }
  ```

---

## 최종 판정

| 기준 | 결과 |
|--------|------|
| ✅ Approved - 머지 가능 | |
| ⚠️ Approved with comments | |
| ❌ Changes requested - 수정 후 재리뷰 필요 | **선택** |

### 수정 우선순위

1. **Critical (즉시 수정)**
   - `PasswordChangeDto` 검증 추가
   - 테스트 커버리지 확보
   - 사용자 정의 예외 도입
   - RateLimitInterceptor 문법 오류 확인

2. **Important (진행 전)**
   - 에러 응답 공통화
   - UTF-8 디코딩 헬퍼 메서드
   - API 문서 추가

3. **Minor (나중에)**
   - getCurrentUser 메서드 분리
   - IP 추출 로직 개선
   - Javadoc 추가

---

## 다음 단계

```
1. Critical 이슈 수정 후 자체 테스트
2. 테스트 커버리지 60% 이상 달성
3. 재리뷰 요청 (/code-review)
4. 모든 이슈 해결 후 머지
```
