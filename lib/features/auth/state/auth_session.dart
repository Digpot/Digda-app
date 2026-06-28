import 'dart:io';

import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

import '../../../core/auth/token_storage.dart';
import '../../../core/network/api_client.dart';
import '../../../features/device/data/device_repository.dart';
import '../models/auth_models.dart';
import '../data/auth_repository.dart';

/// 앱 전역에서 공유하는 인증 세션 상태.
///
/// - 부팅 시 토큰 존재 여부로 자동 로그인 가능 여부 판정
/// - 직전 로그인한 [SocialProvider] 를 메모리에 보관하여 로그아웃 시 SDK 측 정리에 사용
/// - 로그인 성공 시 FCM 토큰을 서버에 등록, 로그아웃/탈퇴 시 해제
class AuthSession extends ChangeNotifier {
  AuthSession({
    required AuthRepository repository,
    required ApiClient api,
    required DeviceRepository deviceRepository,
    required TokenStorage tokenStorage,
  })  : _repository = repository,
        _api = api,
        _deviceRepo = deviceRepository,
        _tokenStorage = tokenStorage;

  final AuthRepository _repository;
  final ApiClient _api;
  final DeviceRepository _deviceRepo;
  final TokenStorage _tokenStorage;

  AuthUser? _user;
  SocialProvider? _lastProvider;
  bool _isAuthenticated = false;
  /// 한 프로세스 내에서 onTokenRefresh 리스너가 중복 부착되는 것을 막는 가드.
  bool _tokenRefreshAttached = false;

  AuthUser? get user => _user;
  SocialProvider? get provider => _lastProvider;
  bool get isAuthenticated => _isAuthenticated;

  /// 앱 부팅 시 호출. 저장된 토큰이 있으면 [isAuthenticated]=true.
  Future<void> hydrate() async {
    _isAuthenticated = await _api.tokens.hasSession;
    notifyListeners();
  }

  /// 자동 로그인(이미 인증된) 상태에서 부팅했을 때 FCM 디바이스 토큰을 다시 등록한다.
  /// 예전엔 [signIn] 에서만 등록해, 로그인 상태를 유지하는 사용자는 FCM 토큰이
  /// 회전/만료되거나 서버에서 무효 토큰으로 정리된 뒤 영영 재등록되지 않아
  /// 일정 리마인더 등 푸시가 조용히 끊겼다. 부팅 때마다 best-effort 로 갱신한다.
  Future<void> ensureDeviceRegistered() async {
    if (!_isAuthenticated) return;
    await _registerDevice();
  }

  Future<LoginResult> signIn(SocialProvider provider) async {
    final result = await _repository.signInWith(provider);
    _user = result.user;
    _lastProvider = provider;
    _isAuthenticated = true;
    notifyListeners();
    await _registerDevice();
    return result;
  }

  Future<void> agreeTerms(TermsAgreement agreement) {
    return _repository.agreeTerms(agreement);
  }

  Future<void> signOut() async {
    await _unregisterDevice();
    final p = _lastProvider;
    await _repository.signOut(provider: p);
    _user = null;
    _lastProvider = null;
    _isAuthenticated = false;
    notifyListeners();
  }

  Future<void> deleteAccount() async {
    await _unregisterDevice();
    await _repository.deleteAccount();
    _user = null;
    _lastProvider = null;
    _isAuthenticated = false;
    notifyListeners();
  }

  void setUser(AuthUser user) {
    _user = user;
    notifyListeners();
  }

  /// 리프레시 토큰 만료 등으로 세션이 강제 종료될 때 호출.
  /// API 호출 없이 로컬 상태만 초기화한다.
  void forceSignOut() {
    _user = null;
    _lastProvider = null;
    _isAuthenticated = false;
    notifyListeners();
  }

  /// 네이티브 AppDelegate(iOS) 와의 APNs 진단/재적용 채널.
  static const _apnsChannel = MethodChannel('com.digda.app/apns');

  Future<void> _registerDevice() async {
    var diag = 'start';
    try {
      final messaging = FirebaseMessaging.instance;
      final platform =
          Platform.isIOS ? DevicePlatform.ios : DevicePlatform.android;

      // 느린 APNs 왕복으로 첫 토큰이 아래 폴링 구간을 넘겨 도착하더라도 등록되도록,
      // 토큰 갱신 리스너를 먼저 부착한다(프로세스당 1회). 초기 토큰 생성도
      // onTokenRefresh 로 통지되므로 "폴링은 실패했지만 잠시 뒤 도착" 케이스를
      // 이 리스너가 받아 서버에 등록한다.
      if (!_tokenRefreshAttached) {
        _tokenRefreshAttached = true;
        messaging.onTokenRefresh.listen((newToken) => _pushToken(newToken, platform));
      }

      final settings = await messaging.requestPermission();
      diag = 'perm=${settings.authorizationStatus.name}';
      debugPrint('[FCM] permission=${settings.authorizationStatus}');
      if (settings.authorizationStatus == AuthorizationStatus.denied) {
        await _reportIosDiag('$diag (알림 권한 거부)');
        return;
      }

      // iOS 는 APNs 토큰이 먼저 채워져야 getToken() 이 성공한다(미수신 상태에서
      // getToken() 호출 시 apns-token-not-set 예외). requestPermission 직후엔
      // APNs 왕복이 끝나지 않을 수 있어 폴링하며 기다린다 — 안드로이드는 APNs
      // 단계가 없어 곧장 진행.
      if (Platform.isIOS) {
        // 네이티브 AppDelegate 가 받아 둔 APNs 토큰을, Firebase 초기화가 끝난
        // 지금 Messaging 에 재적용한다(초기화 레이스로 토큰이 유실됐던 경우 복구).
        var native = await _syncNativeApns();
        String? apns;
        for (var i = 0; i < 15; i++) {
          apns = await messaging.getAPNSToken();
          if (apns != null) break;
          await Future.delayed(const Duration(seconds: 1));
          native = await _syncNativeApns(); // 폴링 중 늦게 도착한 토큰도 재적용
        }
        diag = '$diag apns=${apns == null ? 'NULL' : 'OK'} $native';
        debugPrint('[FCM] APNs token=${apns == null ? 'NULL(미수신)' : 'OK'} $native');
        if (apns == null) {
          // 15초간 APNs 토큰이 끝내 안 옴. native 상태로 원인을 구분한다:
          //  - native=err(...) : iOS 가 APNs 등록 실패(didFail, 사유 노출)
          //  - native=미응답   : didRegister/didFail 둘 다 미호출(네트워크/프로파일 의심)
          //  - native=tokenOK  : 네이티브엔 토큰 있는데 Messaging 전파 실패(플러그인 의심)
          // 이벤트 리스너는 유지되므로 늦게 오면 자동 등록된다.
          await _reportIosDiag('$diag (APNs 토큰 미수신)');
          return;
        }
      }

      String? token;
      try {
        token = await messaging.getToken();
      } catch (e) {
        await _reportIosDiag('$diag getToken_예외=$e');
        rethrow;
      }
      diag = '$diag token=${token == null ? 'NULL' : 'len${token.length}'}';
      debugPrint('[FCM] token=${token == null ? 'NULL' : 'len=${token.length}'}');
      if (token == null) {
        await _reportIosDiag('$diag (token NULL)');
        return;
      }

      await _pushToken(token, platform);
    } catch (e, st) {
      // FCM 설정 미완료/일시 오류 시 무시하되, 원인 파악용 로그는 남긴다.
      debugPrint('[FCM] 디바이스 등록 실패: $e');
      debugPrint('$st');
      await _reportIosDiag('$diag 예외=$e');
    }
  }

  /// FCM 토큰을 서버에 등록(upsert)하고 deviceId 를 저장한다.
  /// 초기 등록과 onTokenRefresh(늦은 도착·회전) 양쪽에서 공용으로 쓴다.
  Future<void> _pushToken(String token, DevicePlatform platform) async {
    try {
      final deviceId = await _deviceRepo.register(token: token, platform: platform);
      await _tokenStorage.saveDeviceId(deviceId);
      debugPrint('[FCM] 디바이스 등록 완료 deviceId=$deviceId platform=${platform.value}');
    } catch (e) {
      debugPrint('[FCM] 디바이스 등록(서버) 실패: $e');
      await _reportIosDiag('서버등록 예외=$e');
    }
  }

  /// 네이티브 AppDelegate 에 보관된 APNs 토큰을 Messaging 에 재적용하고 상태를 받는다.
  /// 반환값은 진단용 문자열(native=tokenOK / native=err(...) / native=미응답).
  Future<String> _syncNativeApns() async {
    if (!Platform.isIOS) return '';
    try {
      final res = await _apnsChannel.invokeMapMethod<String, dynamic>('sync');
      final hasToken = res?['hasToken'] == true;
      final err = res?['error'] as String?;
      if (hasToken) return 'native=tokenOK';
      return 'native=${err == null ? '미응답' : 'err($err)'}';
    } catch (e) {
      return 'native=조회실패($e)';
    }
  }

  /// iOS FCM 등록 실패 사유를 서버 로그로 노출한다. 윈도우 개발 환경에선 기기
  /// 콘솔(`[FCM]` 로그)을 못 보므로, 실패 원인을 서버 로그에서 확인하기 위함.
  /// 진단 보고 자체 실패는 무시한다.
  Future<void> _reportIosDiag(String detail) async {
    if (!Platform.isIOS) return;
    try {
      await _deviceRepo.reportDiagnostic(detail);
    } catch (_) {}
  }

  Future<void> _unregisterDevice() async {
    try {
      final deviceId = await _tokenStorage.readDeviceId();
      if (deviceId != null) {
        await _deviceRepo.unregister(deviceId);
      }
    } catch (_) {}
  }
}
