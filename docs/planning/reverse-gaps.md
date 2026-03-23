# Gap Analysis Report

**Project**: raid-hub
**Analysis Date**: 2026-03-23
**Based on**: Reverse Engineering Scan

---

## 갭(Gaps) 요약

| 카테고리 | 심각도 | 갭 수 | 우선순위 |
|-----------|--------|--------|----------|
| 테스트 | Critical | 1 | High |
| 보안 검증 | High | 3 | High |
| API 문서화 | Important | 1 | High |
| 에러 처리 | Medium | 2 | Medium |
| 코드 중복 | Minor | 2 | Low |

---

## Critical 갭

### 1. 테스트 커버리지 부재

**현재 상태**:
- 백엔드: 1개 테스트 (contextLoads 실패)
- 프론트엔드: 0개 테스트
- 실질 커버리지: 0%

**영향**:
- 비즈니스 로직 검증 불가
- 회귀 버그 감지 불가
- 리팩토링 시 기능 파악 위험

**권장 해결**:
```java
// 1. UserService 단위 테스트 (최소 4개)
@Test
void whenChangePasswordWithValidCredentials_shouldUpdatePassword() { ... }

@Test
void whenChangePasswordWithInvalidCurrentPassword_shouldThrowException() { ... }

@Test
void whenRegisterWithExistingUsername_shouldThrowException() { ... }

@Test
void whenRegisterWithInvalidPattern_shouldThrowException() { ... }

// 2. Controller 통합 테스트
@WebMvcTest
void whenGetMeWithoutAuth_shouldReturn401() { ... }

// 3. 프론트엔드 위젯 테스트
testWidgets('CheatSheetCard displays correctly', (tester) { ... });
```

---

## High 갭

### 2. 비밀번호 검증 누락

**위치**: `PasswordChangeDto.java:12`

**문제**:
```java
@NotBlank private String newPassword;  // @Size, @Pattern 부재
```

**해결 방법**:
```java
@NotBlank
@Size(min = 8, max = 30, message = "비밀번호는 8자 이상 30자 이하여야 합니다")
@Pattern(regexp = "^(?=.*[A-Za-z])(?=.*\\d)[A-Za-z\\d@$!%*#?&]{8,}$",
         message = "비밀번호는 영문, 숫자를 포함해야 합니다")
private String newPassword;
```

---

### 3. Rate Limiting IP 스푸핑 취약

**위치**: `RateLimitInterceptor.java:63-69`

**문제**:
```java
String xfHeader = request.getHeader("X-Forwarded-For");
if (xfHeader == null) {
    return request.getRemoteAddr();
}
return xfHeader.split(",")[0];  // 클라이언트가 임의 설정 가능
```

**해결 방법**:
```java
// 신뢰할 수 있는 프록시만 허용
private static final Set<String> TRUSTED_PROXIES = Set.of(
    "20.89.237.161",  // 운영 서버 IP
    "127.0.0.1"
);

private String getClientIP(HttpServletRequest request) {
    String remoteAddr = request.getRemoteAddr();
    String xfHeader = request.getHeader("X-Forwarded-For");

    if (xfHeader != null && TRUSTED_PROXIES.contains(remoteAddr)) {
        return xfHeader.split(",")[0].trim();
    }
    return remoteAddr;
}
```

---

### 4. API 문서화 미흡

**현재 상태**:
- Springdoc OpenAPI 의존성 없음
- Swagger UI 없음
- 프론트엔드 개발자는 백엔드 코드만 참조

**해결 방법**:
```gradle
dependencies {
    implementation 'org.springdoc:springdoc-openapi-starter-webmvc-ui:2.3.0'
}
```

```yaml
# application.yml
springdoc:
  api-docs:
    path: /api-docs
  swagger-ui:
    path: /swagger-ui.html
```

```java
// Controller에 문서 추가
@Tag(name = "User", description = "사용자 관리 API")
@Operation(summary = "비밀번호 변경", description = "현재 로그인한 사용자의 비밀번호를 변경합니다.")
@PutMapping("/change-password")
public ResponseEntity<Map<String, String>> changePassword(...) { ... }
```

---

## Medium 갭

### 5. 범용 예외 사용

**위치**: 전체 Service 레이어

**문제**:
```java
throw new RuntimeException("사용자를 찾을 수 없습니다.");
```

**해결 방법**: 사용자 정의 예외 클래스 도입

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

// exception/VideoNotFoundException.java
public class VideoNotFoundException extends RuntimeException {
    public VideoNotFoundException(Long id) {
        super("비디오를 찾을 수 없습니다: " + id);
    }
}
```

---

### 6. UTF-8 디코딩 코드 중복

**위치**: `api_service.dart`

**문제**: 6회 이상 반복되는 동일 패턴

```dart
// 반복되는 패턴 (각 API 응답마다)
List<dynamic> body = jsonDecode(utf8.decode(response.bodyBytes));
```

**해결 방법**: 공통 헬퍼 메서드 도입

```dart
T _parseResponse<T>(http.Response response, T Function(dynamic) fromJson) {
    if (response.statusCode == 200 || response.statusCode == 201) {
        final body = jsonDecode(utf8.decode(response.bodyBytes));
        return fromJson(body);
    }
    throw Exception('요청 실패: ${response.statusCode}');
}
```

---

## Minor 갭

### 7. UserController.getCurrentUser 메서드 분리

**위치**: `UserController.java:38-57` (20줄)

**해결 방법**: UserInfoResponse DTO 추출

---

### 8. Javadoc 부재

**해결 방법**: 주요 Service/Controller 메서드에 주석 추가

```java
/**
 * 레이드 공략 영상을 생성합니다.
 *
 * @param video 생성할 비디오 정보
 * @return 저장된 비디오
 * @throws IllegalArgumentException 제목이 비어있을 때
 */
RaidVideo createVideo(RaidVideo video);
```

---

## 기술 부채 분석

| 항목 | 상태 | 노트 |
|------|------|------|
| 불일치 | 감지 안음 | 추출 기반으로 일치하는지 확인 불가 |
| 기술 부채 | 낮음 | TODO/FIXME 없음 |
| 유지보수성 | 중간 | Spring Boot 표준 패턴 준수 |

---

## 보안 검토

| 항목 | 상태 | 권장 |
|------|------|------|
| 비밀번호 해싱 | ✅ 양호 | BCrypt 사용 |
| 세션 관리 | ✅ 양호 | Spring Security |
| CSRF 보호 | ⚠️ 확인 필요 | REST API라면 괜찮음 |
| Rate Limiting | ⚠️ 개선 필요 | 인증 기반 제한 권장 |
| CORS 설정 | ✅ 양호 | 도메인 명시 |
| 입력 검증 | ⚠️ 일부 누락 | newPassword 검증 필요 |

---

## 다음 단계

### Week 1: Critical 해결
1. [ ] PasswordChangeDto 검증 추가
2. [ ] 테스트 커버리지 30% 달성
3. [ ] 사용자 정의 예외 도입

### Week 2: High 해결
1. [ ] API 문서화 (Swagger)
2. [ ] Rate Limiting 개선
3. [ ] 테스트 커버리지 60% 달성

### Week 3: Medium 해결
1. [ ] UTF-8 디코딩 헬퍼 추가
2. [ ] 에러 응답 공통화
3. [ ] 메서드 분리

### Week 4: 문서화
1. [ ] Javadoc 추가
2. [ ] README 업데이트
3. [ ] 배포 가이드 작성
