# 🎯 Claude Code 작업 프롬프트 — DigDa App UI 업데이트

## 프로젝트 개요

- **프로젝트**: DigDa App (Flutter)
- **목적**: 피그마 와이어프레임 디자인을 기반으로 기존 Flutter 화면을 UI 업데이트
- **작업 방식**: 한 화면씩 순차적으로 작업, 각 화면마다 별도 브랜치

---

## 📁 프로젝트 구조

```
lib/
├── navigation/
├── screens/
│   ├── auth/          # 소셜 로그인, 약관 동의 등
│   ├── diary/
│   ├── game/
│   ├── group/
│   ├── mypage/
│   ├── notification/
│   ├── notifications/
│   ├── onboarding/
│   ├── quiz/
│   ├── schedule/
│   ├── splash/        # 스플래시 화면
│   └── todo/
├── theme/
└── widgets/
```

```
design/wireframes/
├── images/            # 피그마 와이어프레임 캡처 (PNG) — 구현 참고용
└── svg/               # 피그마에서 추출한 SVG — 아이콘/에셋 활용
```

---

## 🔀 Git 브랜치 & 커밋 규칙

### 브랜치 전략

```
dev (기본 브랜치)
 └── feat/{화면명}  (예: feat/S1-splash, feat/S2-1-social-login)
```

### 작업 플로우 (화면 하나당)

```bash
# 1. dev에서 최신 pull
git checkout dev
git pull origin dev

# 2. 작업 브랜치 생성
git checkout -b ui/{화면명}

# 3. 작업 중 세세하게 커밋
git add .
git commit -m "feat({화면명}): 기본 레이아웃 구성"

# 4. 작업 중간중간 push
git push origin ui/{화면명}

# 5. 작업 완료 후 dev에 merge
git checkout dev
git merge ui/{화면명}
git push origin dev

# ⚠️ 브랜치 절대 삭제하지 말 것!
```

### 커밋 메시지 컨벤션

```
feat({화면명}): {작업 내용}
```

---

## ⚙️ 작업 규칙 (필독)

### 1. Flutter 파일 자동 탐색 (중요!)

- **나는 Flutter 프로젝트 경로를 직접 지정하지 않는다.**
- 내가 제공하는 것은 **와이어프레임 PNG 파일명**과 **SVG 파일명**뿐이다.
- AI는 파일명에서 화면 키워드(splash, login, terms 등)를 파악하고, **`lib/screens/` 하위를 직접 탐색하여 해당하는 기존 Flutter 파일을 찾아라.**
- 찾는 방법:
    1. `lib/screens/` 전체 디렉토리 구조를 먼저 확인
    2. 파일명/폴더명/클래스명에서 해당 화면과 매칭되는 파일을 찾기
    3. 찾은 파일을 열어서 기존 코드 확인 후 UI만 수정
- **해당 화면 파일이 이미 존재하면 절대 새 파일을 만들지 말 것**
- 만약 매칭되는 파일을 못 찾겠으면, 작업 전에 나에게 먼저 물어볼 것

### 2. 기존 파일 수정 원칙

- 기존 파일을 찾아서 수정 (diff 형태로 작업)
- 파일 구조와 기존 로직은 최대한 유지한 채 **UI만 업데이트**
- 기존에 연결된 라우팅, 네비게이션, 상태 로직을 건드리지 않기

### 3. 디자인 참고 방법

```
1) design/wireframes/images/{PNG파일명} 을 열어서 UI 레이아웃 확인
2) design/wireframes/svg/{SVG파일명} 에서 필요한 에셋 확인
3) PNG를 보고 레이아웃/컬러/간격/폰트 크기 등을 최대한 동일하게 구현
```

### 4. SVG 에셋 활용

- SVG 파일이 있으면 `flutter_svg` 패키지 사용
- SVG 에셋은 `assets/svg/` 디렉토리에 복사해서 사용
- `pubspec.yaml`에 에셋 경로 등록 필수

### 5. 스타일 & 테마

- `lib/theme/` 에 정의된 기존 테마가 있으면 그걸 우선 사용
- 새로운 컬러/폰트가 필요하면 theme 파일에 추가하고 사용
- 하드코딩된 컬러값 최소화, 테마 참조 우선

### 6. 위젯 분리

- 재사용 가능한 위젯은 `lib/widgets/`에 분리
- 화면 전용 위젯은 해당 `screens/{화면}/widgets/`에 분리 가능

### 7. 코드 품질

- 불필요한 `import` 제거
- `const` 생성자 적극 사용
- 매직 넘버 지양 (상수로 분리)
- `flutter analyze` 경고 없도록 유지
- 
### 8. 화면별 이동(네비게이션) 규칙

#### 📌 S5 - 일정(Schedule) 플로우

- 푸터 2번째 버튼 클릭 → `S5-Schedule_Calendar` 화면으로 이동
- 날짜 클릭 → `S5-1-Schedule_Detail` 화면으로 이동
  - 해당 날짜에 일정이 있으면 목록 표시
  - 일정이 없으면 "다른 일정이 없어요" Empty UI 표시 (제공된 PNG/SVG 기반)

- `S5-1-Schedule_Detail` 화면:
  - 우측 상단 점 3개 버튼 클릭 → 편집 / 삭제 기능 표시
  - 하단 `+` 버튼 클릭 → `S5-2-Add_Schedule` 화면으로 이동
  - 참가자 영역 클릭 → `S5-2-Participant_Popup` 팝업 표시
    - 확인 버튼 클릭 시 이전 화면으로 복귀
  - 댓글 작성 기능 존재

- `S5-Schedule_Calendar` 화면에서도
  - `+` 버튼 클릭 시 → `S5-2-Add_Schedule` 화면으로 이동

- 편집 버튼 클릭 시 → `S5-2-Add_Schedule` 화면 재사용 (수정 모드)


---

#### 📌 S6 - 다이어리(Diary) 플로우

- 푸터 3번째 버튼 클릭 → `S6-Diary_Calendar` 화면으로 이동
- 날짜 클릭 → `S6-1-Diary_Detail` 화면으로 이동

- `S6-1-Diary_Detail` 화면:
  - 우측 상단 점 3개 버튼 클릭 → 편집 / 삭제 기능 표시
  - 편집 클릭 시 → `S6-3-Edit_Diary` 화면으로 이동

- `S6-Diary_Calendar` 화면:
  - `+` 버튼 클릭 시 → `S6-2-Write_Diary` 화면으로 이동


---

#### 📌 마이페이지 이동

- 헤더 우측:
  - 알림 아이콘 옆 톱니바퀴 아이콘 클릭 시 → `S8-My_Page` 화면으로 이동

---


## ✅ 여러 화면 일괄 작업

```
## 작업 대상 (순서대로 하나씩)
1. PNG: S5-1-Day_Detail_Bottom_Sheet.png / SVG: S5-1-Day_Detail_Bottom_Sheet.svg
2. PNG: S5-1-Schedule_Detail.png / SVG: S5-1-Schedule_Detail.svg
3. PNG: S5-2-Add_Schedule.png / SVG: S5-2-Add_Schedule.svg
4. PNG: S5-2-Participant_Popup.png / SVG: S5-2-Participant_Popup.svg
5. PNG: S5-Schedule_Calendar.png / SVG: S5-Schedule_Calendar.svg

6. PNG: S6-1-Diary_Detail.png / SVG: S6-1-Diary_Detail.svg
7. PNG: S6-2-Write_Diary.png / SVG: S6-2-Write_Diary.svg
8. PNG: S6-3-Edit_Diary.png / SVG: S6-3-Edit_Diary.svg
9. PNG: S6-Diary_Calendar.png / SVG: S6-Diary_Calendar.svg

10. PNG: S8-1-Edit_Profile.png / SVG: S8-1-Edit_Profile.svg
11. PNG: S8-2-Notification_Settings.png / SVG: S8-2-Notification_Settings.svg
12. PNG: S8-3-Privacy_Settings.png / SVG: S8-3-Privacy_Settings.svg
13. PNG: S8-My_Page.png / SVG: S8-My_Page.svg

14. PNG: S9-Notifications.png / SVG: S9-Notifications.svg

## 작업 방식
위 순서대로 한 화면씩 작업해줘.
각 화면마다:
1. lib/screens/ 탐색하여 해당 화면 파일 찾기
2. dev에서 새 브랜치 생성
3. PNG 참고해서 UI 업데이트
4. 작업 단계마다 커밋 + push
5. 완료 후 dev에 merge + push
6. 다음 화면으로 이동

## 필수 규칙
- 기존 파일 수정만 (해당 화면 파일이 없을 때만 생성)
- 매칭 파일 못 찾으면 나에게 먼저 물어볼 것
- 라우팅/네비게이션/비즈니스 로직 변경 금지
- UI만 업데이트 (레이아웃, 색상, 폰트, 간격)
- lib/theme/ 기존 테마 우선 사용
- SVG 필요 시 assets/svg/ 복사 + pubspec.yaml 등록
- ⚠️ 브랜치 절대 삭제 금지
```

---

## ❌ 절대 하지 말 것

- 기존 파일이 있는데 새 파일을 만드는 것
- 라우팅, 네비게이션 구조를 변경하는 것
- 비즈니스 로직(API 호출, 상태 관리 등)을 수정하는 것
- 작업 완료된 브랜치를 삭제하는 것
- 와이어프레임 없이 추측으로 디자인하는 것
- dev 브랜치에서 직접 작업하는 것 (반드시 분기 후 작업)
- 매칭 파일을 못 찾았는데 임의로 새 파일을 만드는 것 (반드시 물어볼 것)