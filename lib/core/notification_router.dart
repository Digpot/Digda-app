import 'package:flutter/material.dart';

import '../screens/character/games/alkkagi_game_screen.dart';
import '../screens/character/games/catchmind_game_screen.dart';
import '../screens/character/games/word_chain_game_screen.dart';
import '../screens/character/games/omok_game_screen.dart';
import '../screens/character/games/tap_battle_screen.dart';
import 'di.dart';

/// 앱 전역 Navigator 키 — 푸시 알림 탭 등 위젯 밖에서 화면을 전환할 때 쓴다.
final GlobalKey<NavigatorState> appNavigatorKey = GlobalKey<NavigatorState>();

/// FCM 데이터 페이로드를 받아 알림 종류에 맞는 화면으로 이동시킨다.
///
/// 서버가 실어 보내는 데이터: `type`, `groupRoomId`, `relatedId`, `relatedType`.
/// 예전엔 알림을 눌러도 전부 홈으로만 갔는데(딥링크 미처리), 이제 일기 알림은
/// 일기 탭, 일정 알림은 일정 탭, 퀴즈/캐릭터 알림은 모찌 탭으로 보낸다.
class NotificationRouter {
  NotificationRouter._();

  /// 앱이 종료 상태에서 알림 탭으로 시작된 경우, Navigator/인증이 준비되기 전이라
  /// 데이터를 잠시 보관했다가 [consumePending] 에서 처리한다.
  static Map<String, dynamic>? _pending;

  static void setPending(Map<String, dynamic>? data) {
    if (data != null && data.isNotEmpty) _pending = data;
  }

  /// 앱이 첫 프레임을 그린 뒤(app.dart) 호출 — 보관해 둔 알림이 있으면 이동.
  static Future<void> consumePending() async {
    final data = _pending;
    if (data == null) return;
    _pending = null;
    await route(data);
  }

  /// 알림 데이터로 화면 이동. 실패/애매하면 알림 목록으로 폴백한다.
  static Future<void> route(Map<String, dynamic> data) async {
    final nav = appNavigatorKey.currentState;
    if (nav == null) return;

    // 로그인 상태가 아니면 이동하지 않는다(로그인 후 정상 진입 흐름을 따른다).
    if (!Di.authSession.isAuthenticated) return;

    // 이용 제한 계정은 메인 탭 진입이 막혀 있으므로 알림 목록으로만 보낸다.
    if (Di.userSession.profile?.restricted == true) {
      nav.pushNamed('/notifications');
      return;
    }

    final groupRoomId = _stringOf(data['groupRoomId']);
    final section = _sectionRouteFor(data);

    // 그룹 컨텍스트가 없는 알림(공지 등)은 알림 목록으로.
    if (groupRoomId == null) {
      nav.pushNamed('/notifications');
      return;
    }

    // 알림이 가리키는 그룹이 현재 활성 그룹이 아니면, 내 그룹 목록에서 찾아 진입한다.
    if (Di.activeGroup.groupRoomId != groupRoomId) {
      final GroupEntry? entry = await _resolveGroup(groupRoomId);
      if (entry == null) {
        // 이미 나갔거나 조회 실패 → 알림 목록으로 폴백.
        nav.pushNamed('/notifications');
        return;
      }
      Di.activeGroup.enter(
        groupRoomId: entry.id,
        groupRoomName: entry.name,
        isOwner: entry.isOwner,
        isDeleteScheduled: entry.isDeleteScheduled,
      );
      // 삭제 예정 그룹은 관리(복구) 화면으로.
      if (entry.isDeleteScheduled) {
        nav.pushNamedAndRemoveUntil('/group-home', (r) => false,
            arguments: {'name': entry.name});
        nav.pushNamed('/manage-diary');
        return;
      }
    }

    final name = Di.activeGroup.groupRoomName ?? '';

    // 게임 초대(오목/캐치마인드/탭배틀) — 모찌 탭 위에 해당 게임 화면
    // (수락/거절/참가 포함)을 바로 띄운다.
    final relatedType = _stringOf(data['relatedType'])?.toUpperCase();
    if (relatedType == 'OMOK' ||
        relatedType == 'CATCHMIND' ||
        relatedType == 'TAP_BATTLE' ||
        relatedType == 'WORD_CHAIN' ||
        relatedType == 'ALKKAGI') {
      final gameId = int.tryParse(_stringOf(data['relatedId']) ?? '');
      if (gameId != null) {
        nav.pushNamedAndRemoveUntil('/character', (r) => false,
            arguments: {'name': name});
        nav.push(MaterialPageRoute(
          builder: (_) => switch (relatedType) {
            'CATCHMIND' => CatchmindGameScreen(gameId: gameId),
            'TAP_BATTLE' => TapBattleScreen(gameId: gameId),
            'WORD_CHAIN' => WordChainGameScreen(gameId: gameId),
            'ALKKAGI' => AlkkagiGameScreen(gameId: gameId),
            _ => OmokGameScreen(gameId: gameId),
          },
        ));
        return;
      }
    }

    // 섹션 화면을 스택 최상위로 세팅(하단 탭으로 다른 화면 이동 가능).
    nav.pushNamedAndRemoveUntil(section, (r) => false,
        arguments: {'name': name});
  }

  /// 내 그룹 목록에서 [groupRoomId] 에 해당하는 항목을 찾는다.
  static Future<GroupEntry?> _resolveGroup(String groupRoomId) async {
    try {
      final groups = await Di.groupRoomRepository.myList();
      for (final g in groups) {
        if (g.id == groupRoomId) {
          return GroupEntry(
            id: g.id,
            name: g.name,
            isOwner: g.isOwner,
            isDeleteScheduled: g.isDeleteScheduled,
          );
        }
      }
    } catch (_) {}
    return null;
  }

  /// 알림 종류 → 이동할 메인 탭 라우트. relatedType 을 우선 쓰고 type 으로 보강.
  static String _sectionRouteFor(Map<String, dynamic> data) {
    final relatedType = _stringOf(data['relatedType'])?.toUpperCase();
    switch (relatedType) {
      case 'DIARY':
        return '/diary';
      case 'SCHEDULE':
        return '/schedule';
      case 'QUIZ':
        return '/character';
      case 'GROUP_ROOM':
        return '/group-home';
    }
    final type = _stringOf(data['type'])?.toUpperCase();
    if (type != null) {
      if (type.contains('DIARY')) return '/diary';
      if (type.contains('SCHEDULE')) return '/schedule';
      if (type.startsWith('QUIZ') ||
          type == 'MOCHI_LEVELUP' ||
          type == 'DIKO_UNLOCKED') {
        return '/character';
      }
    }
    // 멤버 변동·방장 이양·삭제 예약 등은 그룹 홈으로.
    return '/group-home';
  }

  static String? _stringOf(Object? v) {
    if (v == null) return null;
    final s = v.toString().trim();
    return s.isEmpty ? null : s;
  }
}

/// 알림 라우팅에 필요한 최소 그룹 정보.
class GroupEntry {
  const GroupEntry({
    required this.id,
    required this.name,
    required this.isOwner,
    required this.isDeleteScheduled,
  });

  final String id;
  final String name;
  final bool isOwner;
  final bool isDeleteScheduled;
}
