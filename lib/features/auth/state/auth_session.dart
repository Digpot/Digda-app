import 'package:flutter/foundation.dart';

import '../../../core/network/api_client.dart';
import '../models/auth_models.dart';
import '../data/auth_repository.dart';

/// 앱 전역에서 공유하는 인증 세션 상태.
///
/// - 부팅 시 토큰 존재 여부로 자동 로그인 가능 여부 판정
/// - 직전 로그인한 [SocialProvider] 를 메모리에 보관하여 로그아웃 시 SDK 측 정리에 사용
class AuthSession extends ChangeNotifier {
  AuthSession({required AuthRepository repository, required ApiClient api})
      : _repository = repository,
        _api = api;

  final AuthRepository _repository;
  final ApiClient _api;

  AuthUser? _user;
  SocialProvider? _lastProvider;
  bool _isAuthenticated = false;

  AuthUser? get user => _user;
  SocialProvider? get provider => _lastProvider;
  bool get isAuthenticated => _isAuthenticated;

  /// 앱 부팅 시 호출. 저장된 토큰이 있으면 [isAuthenticated]=true.
  Future<void> hydrate() async {
    _isAuthenticated = await _api.tokens.hasSession;
    notifyListeners();
  }

  Future<LoginResult> signIn(SocialProvider provider) async {
    final result = await _repository.signInWith(provider);
    _user = result.user;
    _lastProvider = provider;
    _isAuthenticated = true;
    notifyListeners();
    return result;
  }

  Future<void> agreeTerms(TermsAgreement agreement) {
    return _repository.agreeTerms(agreement);
  }

  Future<void> signOut() async {
    final p = _lastProvider;
    await _repository.signOut(provider: p);
    _user = null;
    _lastProvider = null;
    _isAuthenticated = false;
    notifyListeners();
  }

  Future<void> deleteAccount() async {
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
}
