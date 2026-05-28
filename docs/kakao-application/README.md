# 카카오 로컬(검색) API 신청 자료

디그팟 앱이 카카오 로컬 검색 API 를 활용하기 위한 비즈/일반 신청 자료.

## 신청 시 입력해야 하는 항목

| 카카오 입력란 | 이 폴더의 파일 |
| --- | --- |
| 신청 사유 및 활용 시나리오 | [application_form.md](./application_form.md) — 본문을 그대로 복붙 |
| 서비스 적용 화면 (1장 / JPG·JPEG·PNG·PDF / 20MB 이내, 개인정보 마스킹) | [screenshot_guide.md](./screenshot_guide.md) — 디바이스에서 직접 캡처해야 함 |
| 참고용 와이어프레임 | [rence_diary_form.png](./reference_diary_form.png) — 작성 화면 와이어프레임 (개념 전달용) |

## 진행 순서

1. **앱 빌드 + 실행** — 로컬 `.env` 에 `KAKAO_REST_API_KEY=55a0a503...` 채운 상태로 fully restart.
2. **테스트 일기 작성 + 장소 검색** — 그림일기 작성 화면 → "장소 추가하기" → "성수동 카페" 등 검색 → 결과에서 선택.
3. **디바이스 캡처** — [screenshot_guide.md](./screenshot_guide.md) 의 절차로 한 장 캡처.
4. **마스킹** — 그룹명/사용자명/프로필 이미지를 모자이크/검은 박스로 가리기.
5. **신청서 제출** — Kakao Developers > 비즈 앱 신청 또는 활용 사례 등록 페이지에 [application_form.md](./application_form.md) 본문 복붙 + 마스킹된 캡처 첨부.

## 참고
- 카카오 로컬 API는 `Authorization: KakaoAK <REST_API_KEY>` 헤더만으로 동작하며, 플랫폼 등록(웹/안드로이드)이나 카카오맵 SDK 임베드는 우리 구현에서 필요 없음.
- 일일 쿼터(기본 약 10만 건)를 초과하거나 상용 배포를 안정화하려면 비즈 앱 전환 또는 활용 사례 신청을 통해 한도 상향.

## 카카오맵 API 심사 반려 대응 (2026-05-28)
- 반려 사유: 카카오 가이드 ([devtalk 146633](https://devtalk.kakao.com/t/api/146633)) 의 "1앱-1서비스 정책 + 신청 양식" 미준수 안내
- [kakao_map_review_response.html](./kakao_map_review_response.html) — 응답서 원본 (A4 인쇄 친화)
- [kakao_map_review_response.pdf](./kakao_map_review_response.pdf) — 재신청 시 첨부할 PDF
  - 운영 앱 1개(디그팟)임을 명시 + Package Name/Bundle ID + 호출 시나리오 포함
  - **재제출 전 확인 필요**: iOS Bundle ID 실제 정식 출시값(`com.digda.app` 가정) 검증, 다른 카카오 앱 동시 운영 여부 등은 반드시 본인 확인 후 제출
