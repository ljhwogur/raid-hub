# Reverse Engineering 완료 요약

**Project**: raid-hub
**Date**: 2026-03-23
**Status**: ✅ 완료

---

## 생성된 문서

| 문서 | 경로 | 설명 |
|------|--------|------|
| 도메인 리소스 | `specs/domain/resources.yaml` | 7개 엔티티, 관계 정의 |
| API 엔드포인트 | `specs/api/endpoints.yaml` | 26개 API 계약 |
| 홈 화면 명세 | `specs/screens/home.yaml` | 네비게이션, 필터링 |
| 로그인 화면 명세 | `specs/screens/login.yaml` | 로그인 폼 |
| 대시보드 명세 | `specs/screens/admin_dashboard.yaml` | 통계 표시 |
| 스캔 리포트 | `docs/planning/reverse-scan.md` | 프로젝트 구조 분석 |
| 갭 분석 | `docs/planning/reverse-gaps.md` | 개선점 식별 |

---

## 역추출 통계

| 카테고리 | 수량 |
|-----------|--------|
| 도메인 엔티티 | 7개 |
| API 엔드포인트 | 26개 |
| 화면 명세 | 4개 (주요 화면) |
| 추출된 리소스 | users, raid_videos, cheat_sheets, notices, admin_posts, blocked_videos, user_activities |

---

## 신뢰도 평가

| 문서 | 신뢰도 | 이유 |
|------|--------|------|
| 도메인 리소스 | 0.90 | 엔티티 코드 명확 |
| API 계약 | 0.85 | 컨트롤러 분석 완료 |
| 화면 명세 | 0.80 | 주요 화면만 분석 |
| **평균** | **0.85** | |

---

## 문서 사용 가이드

### 개발자
1. `specs/domain/resources.yaml` → 도메인 구조 이해
2. `specs/api/endpoints.yaml` → API 연동 개발
3. `specs/screens/*.yaml` → 프론트엔드 구현

### 기획자/리뷰어
1. `docs/planning/reverse-scan.md` → 전체 프로젝트 이해
2. `docs/planning/reverse-gaps.md` → 개선점 파악

---

## 간단 요약

**RaidHub**는 로아허브 공략 가이드 플랫폼입니다.

- **백엔드**: Spring Boot REST API
- **프론트엔드**: Flutter 다중 플랫폼 앱
- **주요 기능**:
  - 레이드 공략 영상 관리
  - 컨닝페이퍼 관리
  - 관리자 게시글
  - 사용자 활동 추적
  - YouTube 플레이리스트 연동

**역추출을 통해**: 도메인 리소스, API 계약, 화면 명세가 문서화되었습니다.
