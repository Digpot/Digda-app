import 'package:flutter/foundation.dart';

/// 현재 활성화된 그룹방 컨텍스트.
///
/// 그룹 홈 진입 시 [enter] 로 셋업되어 일정/일기/투두/알림 화면이
/// `Di.activeGroup.groupRoomId` 로 어떤 그룹방의 데이터를 조회할지 결정한다.
class ActiveGroupSession extends ChangeNotifier {
  String? _groupRoomId;
  String? _groupRoomName;
  bool _isOwner = false;
  bool _isDeleteScheduled = false;

  String? get groupRoomId => _groupRoomId;
  String? get groupRoomName => _groupRoomName;
  bool get isOwner => _isOwner;
  /// 리스트에서 진입할 때 전달받은 "삭제 예정" 상태. detail 응답의
  /// deleteScheduledAt 이 누락되는 경우에도 복구 UI 노출 판정에 활용한다.
  bool get isDeleteScheduled => _isDeleteScheduled;

  bool get hasActive => _groupRoomId != null;

  /// 그룹 홈 진입 시 호출.
  void enter({
    required String groupRoomId,
    required String groupRoomName,
    required bool isOwner,
    bool isDeleteScheduled = false,
  }) {
    _groupRoomId = groupRoomId;
    _groupRoomName = groupRoomName;
    _isOwner = isOwner;
    _isDeleteScheduled = isDeleteScheduled;
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

  /// 복구 등으로 삭제 예정 플래그 변경 시.
  void updateDeleteScheduled(bool value) {
    _isDeleteScheduled = value;
    notifyListeners();
  }

  /// 그룹방 나가기/삭제/그룹 리스트로 복귀 시.
  void clear() {
    _groupRoomId = null;
    _groupRoomName = null;
    _isOwner = false;
    _isDeleteScheduled = false;
    notifyListeners();
  }
}
