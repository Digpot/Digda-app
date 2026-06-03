# 기여 가이드 · 협업 컨벤션 (디그팟)

태리팟 디그팟 프로젝트(`Digda-app` · `Digda-server` · `digda-admin`)의 공통 협업 규칙입니다.

## 🔄 작업 흐름

```
이슈 생성(템플릿) → 작업 브랜치 생성 → 개발 → PR(dev) → 리뷰 → 머지 → 이슈 Close
```

- **통합 브랜치**: `dev` (배포 기준). 모든 PR 의 base 는 `dev`.
- **작업 브랜치**: `feat/*`, `fix/*`, `refactor/*`, `docs/*`, `chore/*`
- `main` 직접 머지/승격 금지(운영 배포는 `dev` 기준, admin 등 예외는 별도 합의).

## 🏷️ 라벨 체계

라벨은 **4개 축**으로 구성합니다. 이슈/PR 생성 시 최소 **Type 1개**는 필수, 가능하면 Priority·Domain 도 함께 지정합니다.

### 1) Type — 작업 성격
`✨ Feature` · `🐛 Bug` · `♻️ Refactor` · `🔧 Chore` · `📝 Docs` · `🚑 Hotfix` · `🧪 Test` · `🎨 UI/UX`

### 2) Priority — 우선순위
| 라벨 | 의미 |
|---|---|
| `🔴 P0: Critical` | 즉시 대응 (운영 장애·보안) |
| `🟠 P1: High` | 이번 스프린트 내 처리 |
| `🟡 P2: Medium` | 다음 스프린트까지 |
| `🟢 P3: Low` | 여유 있을 때 |

### 3) Status — 진행 상태
`🚧 In Progress` · `👀 Review` · `🚫 Blocked`

### 4) Domain — 도메인(영역)
앱: `🔐 Auth` · `🏠 GroupRoom` · `📅 Schedule` · `📔 Diary` · `👥 Membership` · `🔗 Invite` · `🔔 Notification` · `👤 User` 등
서버도 동일 도메인 축을 사용합니다.

## 📋 이슈 / PR 템플릿

- 이슈: **✨ 기능 / 🐛 버그 / ♻️ 리팩토링** 템플릿 제공 (`.github/ISSUE_TEMPLATE/`)
- PR: `.github/PULL_REQUEST_TEMPLATE.md` — 연관 이슈·작업 내용·체크리스트 작성
- PR 본문에 `Closes #이슈번호` 를 넣어 머지 시 이슈가 자동 종료되게 합니다.

## 🎯 마일스톤 운영 정책

- **버전 단위**로 마일스톤을 운영합니다. (예: `v1.0 정식 출시`, `v1.1`, `Backlog`)
- 기간이 정해진 마일스톤은 **due date** 를 설정하고, 해당 기간에 처리할 이슈를 묶습니다.
- 우선순위가 낮거나 일정 미정인 항목은 `Backlog` 마일스톤에 모읍니다.
- 마일스톤 종료 시 미완료 이슈는 다음 마일스톤으로 이관합니다.

## 👤 담당자(Assignee) 정책

- 모든 이슈 템플릿은 기본 담당자로 **@chltmdgh522** 가 지정됩니다.
- PR 은 `CODEOWNERS` 에 따라 **@chltmdgh522** 가 기본 리뷰어로 요청됩니다.
- 협업자가 늘어나면 도메인별 오너를 `CODEOWNERS` 에 추가합니다. (예: `lib/screens/schedule/ @담당자`)

## ✍️ 커밋 컨벤션

```
type(scope): 한 줄 요약

본문(선택) — 무엇을/왜 바꿨는지
```
`type`: feat · fix · refactor · chore · docs · test · perf
예) `feat(schedule): 주간 캘린더 뷰 추가`, `fix(diary): 첫 진입 썸네일 미표시 복구`
