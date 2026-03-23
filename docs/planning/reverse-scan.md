# Reverse Scan Report

**Project**: raid-hub
**Scan Date**: 2026-03-23

---

## 프로젝트 개요

| 항목 | 내용 |
|------|------|
| **이름** | raid-hub (로아허브 공략 가이드) |
| **유형** | 하이브리드 플랫폼 |
| **백엔드** | Spring Boot 3.5.9 + Java 17 |
| **프론트엔드** | Flutter + Dart (다중 플랫폼) |
| **데이터베이스** | PostgreSQL |
| **규모** | 중형 (~5,000 LOC) |

---

## 기술 스택

### 백엔드

| 레이어 | 기술 | 버전 | 목적 |
|--------|------|------|------|
| 웹 프레임워크 | Spring Boot | 3.5.9 | REST API |
| 언어 | Java | 17 | 비즈니스 로직 |
| ORM | Spring Data JPA | Jakarta Persistence | DB 액세스 |
| 보안 | Spring Security | - | 인증/인가 |
| 캐시 | Spring Cache + Redis | - | 캐싱 |
| Rate Limiting | Bucket4j | 7.6.0 | DoS 방지 |
| 데이터베이스 | PostgreSQL | - | 데이터 저장 |
| 코드 포맷팅 | Spotless | 6.25.0 | 자동 포맷팅 |

### 프론트엔드

| 레이어 | 기술 | 버전 | 목적 |
|--------|------|------|------|
| 프레임워크 | Flutter | 3.8.1+ | 다중 플랫폼 앱 |
| 언어 | Dart | - | 비즈니스 로직 |
| 상태 관리 | Provider | 6.0.0 | 상태 관리 |
| HTTP 클라이언트 | http | 1.6.0 | API 호출 |
| 비디오 재생 | youtube_player_iframe | 5.2.0 | YouTube 임베드 |
| 환경 변수 | flutter_dotenv | 6.0.0 | .env 관리 |

---

## 구조 분석

### 백엔드 구조

```
raid_hub_backend/src/main/java/com/example/raid_hub/
├── config/               # 설정 (4개 파일)
│   ├── GlobalExceptionHandler.java
│   ├── RateLimitInterceptor.java
│   ├── RedisCacheConfig.java
│   └── WebConfig.java
│
├── controller/            # 컨트롤러 (9개 파일, 26개 엔드포인트)
│   ├── UserController.java          # 사용자 (4개)
│   ├── RaidVideoController.java      # 비디오 (3개)
│   ├── CheatSheetController.java     # 컨닝페이퍼 (3개)
│   ├── NoticeController.java         # 공지사항 (2개)
│   ├── AdminPostController.java       # 관리자 게시글 (5개)
│   ├── AdminStatsController.java      # 통계
│   ├── BlockedVideoController.java    # 차단 비디오
│   ├── YouTubePlaylistController.java # YouTube
│   └── UserActivityService.java     # 활동 로그
│
├── dto/                  # 데이터 전송 객체 (2개)
│   ├── PasswordChangeDto.java
│   └── UserRegistrationDto.java
│
├── entity/                # 엔티티 (7개)
│   ├── User.java
│   ├── RaidVideo.java
│   ├── CheatSheet.java
│   ├── Notice.java
│   ├── AdminPost.java
│   ├── BlockedVideo.java
│   └── UserActivity.java
│
├── repository/            # 레포지토리 (7개)
│   ├── UserRepository.java
│   ├── RaidVideoRepository.java
│   ├── CheatSheetRepository.java
│   ├── NoticeRepository.java
│   ├── AdminPostRepository.java
│   ├── BlockedVideoRepository.java
│   └── UserActivityRepository.java
│
├── service/               # 비즈니스 로직 (8개)
│   ├── UserService.java
│   ├── RaidVideoService.java
│   ├── CheatSheetService.java
│   ├── NoticeService.java
│   ├── AdminPostService.java
│   ├── UserActivityService.java
│   └── YouTubePlaylistService.java
│
├── security/              # 보안 설정 (2개)
│   ├── SecurityConfig.java
│   └── CustomUserDetailsService.java
│
└── youtube/               # YouTube 관련 (3개)
    ├── YouTubePlaylistItem.java
    ├── YouTubePlaylistItemsResponse.java
    └── YouTubePlaylistParser.java
```

### 프론트엔드 구조

```
raid_hub_frontend/lib/
├── main.dart                     # 앱 진입점
│
├── models/                       # 데이터 모델 (6개)
│   ├── raid_video.dart
│   ├── playlist_item.dart
│   ├── cheat_sheet.dart
│   ├── admin_post.dart
│
├── services/                     # API 서비스 (2개)
│   ├── api_service.dart             # REST API 호출 (402줄)
│   └── auth_service.dart           # 인증 서비스
│
├── providers/                    # 상태 관리 (1개)
│   └── theme_provider.dart         # 테마 관리
│
├── screens/                      # 화면 (8개)
│   ├── landing_screen.dart
│   ├── splash_screen.dart
│   ├── login_screen.dart
│   ├── signup_screen.dart
│   ├── home_screen.dart           # 메인 화면
│   ├── admin_dashboard_screen.dart # 관리자 대시보드
│   ├── video_player_screen.dart     # 비디오 재생
│   └── admin_post_screen.dart     # 관리자 게시글
│
├── widgets/                      # 위젯 (4개)
│   ├── cheat_sheet_card.dart
│   ├── video_cards.dart
│   ├── skeleton_ui.dart
│   └── upload_dialogs.dart
│
└── utils/                        # 유틸리티 (1개)
    └── constants.dart
```

---

## 역추출 대상

| 대상 | 상태 | 파일 생성 |
|------|------|-----------|
| 도메인 리소스 | ✅ 완료 | specs/domain/resources.yaml |
| API 계약 | ✅ 완료 | specs/api/endpoints.yaml |
| 화면 명세 | ✅ 완료 | specs/screens/*.yaml (4개) |

### 추출된 화면

| 화면명 | 파일 | 컨텐츠 수 |
|--------|------|-----------|
| 홈 화면 | home.yaml | 10개 |
| 로그인 화면 | login.yaml | 3개 |
| 관리자 대시보드 | admin_dashboard.yaml | 6개 |

---

## 신뢰도 평가

| 항목 | 점수 | 설명 |
|------|------|------|
| 도메인 리소스 | 0.90 | 엔티티 명확, 관계 파악 가능 |
| API 계약 | 0.85 | 컨트롤러/서비스 분석 완료 |
| 화면 명세 | 0.80 | 주요 화면 분석 완료 |

**평균 신뢰도**: **0.85**

---