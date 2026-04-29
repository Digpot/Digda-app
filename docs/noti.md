# 소셜 로그인 SDK 셋업 가이드 (Flutter)

> 카카오 / 네이버 / Apple 3종 모두 **개발자 센터 등록 → 키 발급 → 네이티브(iOS/Android) 설정 → `.env` 주입** 순서로 진행한다.
> 키와 시크릿은 절대 git 에 올리지 않는다 (`.env` 는 `.gitignore` 에 포함됨).

본 문서는 [`API_SPECIFICATION.md` §1-1 소셜 로그인](../../digda-server/docs/API_SPECIFICATION.md) 의 클라이언트 측 보완 가이드다. 서버는 항상 `provider + accessToken (+ idToken)` 만 받고 자체 검증한다.

---

## 0. 공통 — 패키지 & 환경

```yaml
# pubspec.yaml
dependencies:
  kakao_flutter_sdk_user: ^1.9.7
  flutter_naver_login: ^2.1.1
  sign_in_with_apple: ^6.1.4
  flutter_dotenv: ^5.2.1
```

```dotenv
# .env (개발용 — 절대 커밋 금지)
KAKAO_NATIVE_APP_KEY=
KAKAO_JAVASCRIPT_APP_KEY=
NAVER_CLIENT_ID=
NAVER_CLIENT_SECRET=
NAVER_CLIENT_NAME=Digda
APPLE_SERVICE_ID=
APPLE_REDIRECT_URI=
```

`main.dart` 에서 `Env.load()` → `KakaoSdk.init(...)` → `Di.bootstrap()` 순서로 부팅한다 (이미 적용됨).

---

## 1. 카카오 로그인 (Kakao Developers)

### 1-1. Kakao Developers 콘솔 등록

1. https://developers.kakao.com 접속 → 로그인 → **내 애플리케이션 > 애플리케이션 추가**
2. 앱 이름 `Digda`, 사업자명 입력 (개인은 본인명)
3. **앱 키** 탭에서 발급된 4종 키 확인:
   - **네이티브 앱 키** → `KAKAO_NATIVE_APP_KEY` (Android/iOS 네이티브용)
   - **JavaScript 키** → `KAKAO_JAVASCRIPT_APP_KEY` (Flutter Web 사용 시)
   - REST API 키 → 서버 측 토큰 검증용 (서버 `.env` 로 따로 전달)
   - Admin 키 → 노출 금지, 사용 안 함
4. **플랫폼 등록**
   - Android: 패키지명 `com.digda.app` (= `android/app/build.gradle.kts` `applicationId`), 키 해시 등록
     - 디버그 키 해시 추출 (Windows):
       ```bash
       keytool -exportcert -alias androiddebugkey -keystore ~/.android/debug.keystore -storepass android -keypass android | openssl sha1 -binary | openssl base64
       ```
     - 릴리즈 키 해시는 실제 keystore 로 동일 명령
   - iOS: Bundle ID `com.digda.app` (= Xcode `Bundle Identifier`)
5. **카카오 로그인** 메뉴 → **활성화 ON**, 동의 항목에서 닉네임/프로필이미지/이메일 활성화
6. **고급 설정 > Custom Scheme** 에 `kakao{NATIVE_APP_KEY}` 등록 (iOS 리다이렉트용)

### 1-2. Android 설정

`android/app/src/main/AndroidManifest.xml` `<application>` 내부에 추가:

```xml
<activity android:name="com.kakao.sdk.flutter.AuthCodeCustomTabsActivity"
          android:exported="true">
    <intent-filter android:label="flutter_web_auth">
        <action android:name="android.intent.action.VIEW" />
        <category android:name="android.intent.category.DEFAULT" />
        <category android:name="android.intent.category.BROWSABLE" />
        <!-- "kakao{NATIVE_APP_KEY}" 그대로 (예: kakaoabcd1234) -->
        <data android:scheme="kakao{NATIVE_APP_KEY}" android:host="oauth"/>
    </intent-filter>
</activity>
```

### 1-3. iOS 설정

`ios/Runner/Info.plist` 에 추가:

```xml
<key>LSApplicationQueriesSchemes</key>
<array>
  <string>kakaokompassauth</string>
  <string>kakaolink</string>
</array>
<key>CFBundleURLTypes</key>
<array>
  <dict>
    <key>CFBundleTypeRole</key>
    <string>Editor</string>
    <key>CFBundleURLSchemes</key>
    <array>
      <!-- "kakao{NATIVE_APP_KEY}" -->
      <string>kakao{NATIVE_APP_KEY}</string>
    </array>
  </dict>
</array>
```

### 1-4. 코드 사용 — 이미 구현됨

`lib/features/auth/data/social_auth_service.dart` 의 `_signInKakao()`:
- `isKakaoTalkInstalled()` 가 true 면 `loginWithKakaoTalk` (앱 전환 로그인)
- false 또는 KakaoTalk 사용자가 취소했을 때 `loginWithKakaoAccount` (웹 fallback)
- 결과 `accessToken` 만 추출해 서버 `/auth/login` 에 전달.

---

## 2. 네이버 로그인 (Naver Developers)

### 2-1. Naver Developers 콘솔 등록

1. https://developers.naver.com 접속 → **Application > 애플리케이션 등록**
2. 애플리케이션 이름 `Digda`, 사용 API: **네이버 로그인** 선택
3. 제공 정보 선택: 회원이름, 이메일주소, 프로필사진(선택)
4. 환경: **Android, iOS** 모두 추가
   - Android: 다운로드 URL/패키지명 `com.digda.app`
   - iOS: URL Scheme 입력 (예: `digdanaver`), Bundle ID `com.digda.app`
5. 발급된 **Client ID / Client Secret** 을 `.env` 의 `NAVER_CLIENT_ID` / `NAVER_CLIENT_SECRET` 에 입력
6. `NAVER_CLIENT_NAME` 은 동의 화면에 표시되는 서비스명 (`Digda`)

### 2-2. Android 설정

`android/app/src/main/AndroidManifest.xml`:

```xml
<application
    ...
    android:largeHeap="true">
  <meta-data
      android:name="com.naver.sdk.clientId"
      android:value="@string/naver_client_id" />
  <meta-data
      android:name="com.naver.sdk.clientSecret"
      android:value="@string/naver_client_secret" />
  <meta-data
      android:name="com.naver.sdk.clientName"
      android:value="@string/naver_client_name" />
</application>
```

`android/app/src/main/res/values/strings.xml` (없으면 새로 만들기):

```xml
<resources>
    <string name="naver_client_id">YOUR_CLIENT_ID</string>
    <string name="naver_client_secret">YOUR_CLIENT_SECRET</string>
    <string name="naver_client_name">Digda</string>
</resources>
```

### 2-3. iOS 설정

`ios/Runner/Info.plist`:

```xml
<key>NaverConsumerKey</key>
<string>YOUR_CLIENT_ID</string>
<key>NaverConsumerSecret</key>
<string>YOUR_CLIENT_SECRET</string>
<key>NaverServiceAppName</key>
<string>Digda</string>
<key>NaverURLScheme</key>
<string>digdanaver</string>

<key>LSApplicationQueriesSchemes</key>
<array>
  <string>naversearchapp</string>
  <string>naversearchthirdlogin</string>
</array>
<key>CFBundleURLTypes</key>
<array>
  <dict>
    <key>CFBundleURLSchemes</key>
    <array>
      <string>digdanaver</string>
    </array>
  </dict>
</array>
```

### 2-4. 코드 사용 — 이미 구현됨

`SocialAuthService._signInNaver()`:
- `FlutterNaverLogin.logIn()` → 결과 status 확인
- `getCurrentAccessToken()` 으로 액세스 토큰 추출 → 서버 `/auth/login` 에 전달
- 로그아웃은 `logOutAndDeleteToken()` (토큰 폐기까지)

---

## 3. Apple 로그인 (Apple Developer)

### 3-1. Apple Developer 콘솔 등록

> **유료 프로그램 가입($99/년) 필수**. 무료 계정으로는 Sign in with Apple capability 가 활성화되지 않는다.

1. https://developer.apple.com → **Certificates, Identifiers & Profiles**
2. **Identifiers > App IDs** 에서 Bundle ID `com.digda.app` 의 App ID 등록
   - Capability 에서 **Sign In with Apple** 체크
3. (Android/Web 도 받을 거면) **Service IDs** 추가:
   - Identifier: `com.digda.app.signin` 같은 별도 ID → `APPLE_SERVICE_ID`
   - Sign In with Apple 활성화 → Configure
   - **Primary App ID**: 위 App ID 선택
   - **Domains**: 서버가 콜백 받을 도메인 (`api.digda.app`) — 도메인 인증(`.well-known/apple-developer-domain-association.txt` 업로드) 필요
   - **Return URLs**: 서버 콜백 URL → `APPLE_REDIRECT_URI` (예: `https://api.digda.app/v1/auth/apple/callback`)
4. **Keys** 에서 **Sign in with Apple** Key 생성, `.p8` 파일 다운로드 → 서버 측 환경변수로 전달 (Key ID + Team ID 와 함께)
   - 클라이언트는 이 Key 를 모름. 서버가 `identityToken` 검증·재서명할 때 사용한다.

### 3-2. Xcode (iOS)

1. Xcode 에서 `Runner` 타겟 선택 → **Signing & Capabilities** 탭
2. `+ Capability` → **Sign in with Apple** 추가
3. Bundle Identifier 가 위 App ID 와 일치하는지 확인
4. iOS 13+ 필요 (`ios/Podfile` 의 `platform :ios, '13.0'` 이상)

### 3-3. Android (선택 — Apple 로그인 지원하려면 웹 인증 흐름 사용)

Android 는 네이티브 SDK 가 없어 `sign_in_with_apple` 패키지가 Custom Tab 으로 웹 인증 → 서버 콜백 → 앱 딥링크로 돌아오는 흐름을 쓴다. Service ID + Return URL 을 서버에 미리 등록한 위 3-1.3 설정이 이 경우에 사용된다.

`android/app/src/main/AndroidManifest.xml` 에 콜백 인텐트 필터:

```xml
<intent-filter android:label="apple_signin_callback">
  <action android:name="android.intent.action.VIEW"/>
  <category android:name="android.intent.category.DEFAULT"/>
  <category android:name="android.intent.category.BROWSABLE"/>
  <!-- 서버 측에서 redirect 시 이 scheme 으로 앱 복귀시켜야 함 -->
  <data android:scheme="signinwithapple" android:path="callback"/>
</intent-filter>
```

### 3-4. 코드 사용 — 이미 구현됨

`SocialAuthService._signInApple()`:
- `getAppleIDCredential` 호출 → `identityToken` (JWT) + `authorizationCode` 수령
- 서버에는 `accessToken=authorizationCode` + `idToken=identityToken` 으로 전달
- 서버는 `idToken` 의 `aud` (서비스 ID) 와 서명을 Apple 공개키로 검증 → 사용자 매핑

---

## 4. 트러블슈팅 체크리스트

| 증상 | 의심 항목 |
|------|----------|
| 카카오 로그인 후 앱이 안 돌아옴 | `kakao{KEY}://oauth` Custom Scheme 미등록, AndroidManifest activity 누락 |
| 카카오 "앱이 등록되지 않음" | Native App Key 오타, 키 해시 미등록 (Android) / Bundle ID 미등록 (iOS) |
| 네이버 로그인 클릭 시 즉시 닫힘 | `NaverConsumerKey`/`NaverURLScheme` 미설정, `LSApplicationQueriesSchemes` 누락 |
| Apple 로그인 버튼이 비활성 | 무료 계정, App ID 의 Sign in with Apple capability 미활성, iOS 13 미만 시뮬레이터 |
| Apple 로그인 후 서버에서 invalid_token | Service ID 의 Domain 인증 미완료, Return URL 불일치, Key 가 만료됨 |
| 401 만 계속 받음 | 서버 측 `provider` enum 케이스 (`KAKAO`/`kakao`) 정합성, idToken 누락 (Apple) |

---

## 5. 서버 측 매핑 (참고)

```
POST /auth/login
Body: { provider, accessToken, idToken? }

서버는 provider 별로:
- kakao: GET https://kapi.kakao.com/v2/user/me  (Bearer accessToken)
- naver: GET https://openapi.naver.com/v1/nid/me (Bearer accessToken)
- apple: idToken 의 sub 필드 추출 (Apple 공개키로 JWT 검증)
```

서버는 `social_id + social_provider` 조합으로 유저를 찾고, 없으면 신규 생성 후 `isNewUser=true` 로 응답. 클라이언트는 그 플래그가 true 면 `/auth/terms` 화면으로 분기 (이미 적용됨).

---

## 6. 다음 단계 — 푸시 알림 (FCM)

소셜 로그인이 끝나고 알림 도메인 (12번 Notification + 11번 Device) 을 연동하려면 별도로 **Firebase Cloud Messaging** 셋업이 필요하다. 그건 12번 도메인 PR 시점에 본 문서에 §7 로 추가 예정.
