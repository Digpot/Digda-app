import 'package:flutter/foundation.dart';

import '../data/user_repository.dart';
import '../models/user_models.dart';

/// 내 프로필을 메모리 캐시 + 갱신 알림으로 노출.
class UserSession extends ChangeNotifier {
  UserSession({required UserRepository repository}) : _repository = repository;

  final UserRepository _repository;

  UserProfile? _profile;
  bool _loading = false;
  Object? _error;

  UserProfile? get profile => _profile;
  bool get isLoading => _loading;
  Object? get error => _error;

  Future<UserProfile> refresh() async {
    _loading = true;
    _error = null;
    notifyListeners();
    try {
      final me = await _repository.me();
      _profile = me;
      return me;
    } catch (e) {
      _error = e;
      rethrow;
    } finally {
      _loading = false;
      notifyListeners();
    }
  }

  Future<UserProfile> update(UpdateProfileRequest body) async {
    final updated = await _repository.updateMe(body);
    _profile = updated;
    notifyListeners();
    return updated;
  }

  void clear() {
    _profile = null;
    _error = null;
    notifyListeners();
  }
}
