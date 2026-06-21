# iOS 소셜 로그인 설정 가이드

이 브랜치(`ios`)는 `dev` + iOS 네이티브 소셜 로그인 설정을 담는다
(`android` 브랜치가 `dev` + 안드로이드 네이티브 설정을 담는 것과 동일 구조).

## 구현된 것
- **Apple 로그인**: `Runner.entitlements`(`com.apple.developer.applesignin`) + Xcode capability 등록.
  앱의 `social_login_screen.dart` 가 iOS 에서만 'Apple로 시작하기' 버튼을 노출하며,
  `SignInWithApple → idToken → POST /auth/login` 흐름은 이미 배선됨. 서버 Apple OAuth2 도 구현 완료.
- **카카오/네이버 로그인**: `Info.plist` 의 URL scheme · 조회 스킴 · 네이버 SDK 키.
  키는 빌드 설정 변수(`$(KAKAO_NATIVE_APP_KEY)` 등)로 두고 `Secrets.xcconfig` 에서 주입한다.

## 로컬(맥)에서 빌드하려면
1. `ios/Flutter/Secrets.example.xcconfig` 를 `ios/Flutter/Secrets.xcconfig` 로 복사하고 값 입력.
2. 프로젝트 루트 `.env` 작성(`.env.example` 참고).
3. `flutter build ios`.

## GitHub Actions(맥 없이 빌드)
`.github/workflows/ios-build.yml` 가 macOS 러너에서 `flutter build ios --no-codesign` 수행.
아래 **레포 Secrets** 를 등록하면 됨(Settings → Secrets and variables → Actions).

### 1단계 — 컴파일 검증(지금 바로 가능, Apple 계정 불필요)
| Secret | 설명 |
|---|---|
| `API_BASE_URL` | 예) `https://api.digda.kro.kr` |
| `KAKAO_NATIVE_APP_KEY` | 카카오 네이티브 앱 키 |
| `KAKAO_JAVASCRIPT_APP_KEY` | 카카오 JS 키 |
| `KAKAO_REST_API_KEY` | 카카오 REST 키(장소 검색) |
| `NAVER_CLIENT_ID` | 네이버 Client ID |
| `NAVER_CLIENT_SECRET` | 네이버 Client Secret |
| `NAVER_CLIENT_NAME` | 예) `디그팟` |
| `APPLE_SERVICE_ID` | Apple Service ID (웹/서버용, 선택) |
| `APPLE_REDIRECT_URI` | Apple redirect URI (선택) |
| `GOOGLE_SERVICE_INFO_PLIST_BASE64` | (선택) Firebase iOS plist를 base64 인코딩한 값 |

> 비워도 빌드는 통과한다(런타임에 해당 로그인만 비활성). 키를 채우면 실제 동작.

### 2단계 — 서명 + TestFlight(Apple 개발자 계정 발급 후)
워크플로 하단 `testflight` 잡 주석 해제 후 아래 Secrets 추가:
`APPSTORE_API_KEY_ID`, `APPSTORE_API_ISSUER_ID`, `APPSTORE_API_PRIVATE_KEY`,
`IOS_DIST_CERT_P12_BASE64`, `IOS_DIST_CERT_PASSWORD`,
`IOS_PROVISIONING_PROFILE_BASE64`, `IOS_TEAM_ID`.

## 서버(Digda-server) 쪽
Apple OAuth2 는 이미 구현되어 있고 코드 변경 불필요.
`prod.env` 의 Apple 자격값만 **새 Apple 개발자 계정 기준으로 갱신**하면 됨:
`APPLE_CLIENT_ID`, `APPLE_TEAM_ID`, `APPLE_KEY_ID`, `APPLE_PRIVATE_KEY`,
`APPLE_REDIRECT_URI`, `APPLE_PROFILE`.
