import 'package:flutter/foundation.dart';

/// 현재 활성화된 그룹방 컨텍스트.
///
/// 그룹 홈 진입 시 [enter] 로 셋업되어 일정/일기/투두/알림 화면이
/// `Di.activeGroup.groupRoomId` 로 어떤 그룹방의 데이터를 조회할지 결정한다.
class ActiveGroupSession extends ChangeNotifier {
  String? _groupRoomId;
  String? _groupRoomName;
  bool _isOwner = false;

  String? get groupRoomId => _groupRoomId;
  String? get groupRoomName => _groupRoomName;
  bool get isOwner => _isOwner;

  bool get hasActive => _groupRoomId != null;

  /// 그룹 홈 진입 시 호출.
  void enter({
    required String groupRoomId,
    required String groupRoomName,
    required bool isOwner,
  }) {
    _groupRoomId = groupRoomId;
    _groupRoomName = groupRoomName;
    _isOwner = isOwner;
    notifyListeners();
  }

  /// 방장 양도 등으로 역할 변경 시.
  void updateRole({required bool isOwner}) {
    _isOwner = isOwner;
    notifyListeners();
  }

  /// 그룹방 이름 수정 시.
  void updateName(String name) {
    _groupRoomName = name;
    notifyListeners();
  }

  /// 그룹방 나가기/삭제/그룹 리스트로 복귀 시.
  void clear() {
    _groupRoomId = null;
    _groupRoomName = null;
    _isOwner = false;
    notifyListeners();
  }
}
