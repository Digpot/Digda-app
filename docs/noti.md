# SDK / FCM 개발자 센터 설정 체크리스트

---

## 1. 카카오 로그인

**[developers.kakao.com](https://developers.kakao.com) → 내 애플리케이션 추가**

- [ ] 앱 생성 → **네이티브 앱 키** 발급 → `.env` `KAKAO_NATIVE_APP_KEY` 입력
- [ ] 플랫폼 등록
  - Android: 패키지명 `com.digda.app`, 디버그 키 해시 등록
    ```bash
    keytool -exportcert -alias androiddebugkey -keystore ~/.android/debug.keystore -storepass android | openssl sha1 -binary | openssl base64
    ```
  - iOS: Bundle ID `com.digda.app`
- [ ] 카카오 로그인 활성화 ON → 동의항목: 닉네임, 프로필이미지, 이메일 체크
- [ ] REST API 키 → 서버 `.env` `KAKAO_REST_API_KEY` 입력

---

## 2. 네이버 로그인

**[developers.naver.com](https://developers.naver.com) → Application 등록**

- [ ] 사용 API: **네이버 로그인** 선택, 제공 정보: 이름·이메일·프로필사진
- [ ] 환경 추가: Android(`com.digda.app`), iOS(`com.digda.app`)
- [ ] **Client ID / Client Secret** 발급 → `.env` `NAVER_CLIENT_ID` / `NAVER_CLIENT_SECRET` 입력

---

## 3. Apple 로그인

**[developer.apple.com](https://developer.apple.com) → Certificates, Identifiers & Profiles**

> 유료 개발자 계정($99/년) 필요

- [ ] **Identifiers > App IDs** → `com.digda.app` 등록, Capability: **Sign In with Apple** 체크
- [ ] **Keys** → Sign in with Apple Key 생성, `.p8` 다운로드 (Key ID + Team ID 메모) → 서버에 전달
- [ ] Xcode: `Runner` → Signing & Capabilities → **Sign in with Apple** 추가, iOS 13+ 확인
- [ ] (Android 지원 시) **Service IDs** → `com.digda.app.signin` 등록, Return URL 서버 도메인 인증

---

## 4. FCM (Firebase Cloud Messaging)

**[console.firebase.google.com](https://console.firebase.google.com) → 프로젝트 생성**

### 앱 (Flutter)
- [ ] **Android 앱 추가** → 패키지명 `com.digda.app` → `google-services.json` 다운로드 → `android/app/` 에 배치
- [ ] **iOS 앱 추가** → Bundle ID `com.digda.app` → `GoogleService-Info.plist` 다운로드 → Xcode `Runner/` 에 추가
- [ ] `pubspec.yaml` 에 추가:
  ```yaml
  firebase_core: ^3.x.x
  firebase_messaging: ^15.x.x
  ```
- [ ] `android/build.gradle` → `classpath 'com.google.gms:google-services:...'`, `android/app/build.gradle` → `apply plugin: 'com.google.gms.google-services'`
- [ ] iOS: `ios/Podfile` 에서 `platform :ios, '13.0'`

### 서버
- [ ] Firebase 콘솔 → **프로젝트 설정 > 서비스 계정** → **새 비공개 키 생성** → JSON 다운로드
- [ ] JSON 파일 서버 `src/main/resources/firebase/` 에 배치 (git 제외 처리)
- [ ] `application.yml` 에 경로 설정:
  ```yaml
  fcm:
    credentials-path: classpath:firebase/서비스계정파일명.json
  ```
