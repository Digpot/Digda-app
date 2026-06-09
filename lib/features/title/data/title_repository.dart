import 'package:flutter/foundation.dart';

import '../../../core/network/api_client.dart';
import '../models/title_models.dart';

/// 칭호 API 래퍼. 칭호는 계정 단위로 보관되어 그룹방 탈퇴/삭제와 무관하게 유지된다.
///
/// list/claim 응답에서 **새로 획득한 칭호**를 감지해 [newlyEarned] 큐에 쌓는다.
/// 앱 전역 리스너(축하 팝업)가 이를 소비한다. 최초 1회는 기준선만 잡고 축하하지 않는다
/// (앱 켤 때 기존 칭호가 한꺼번에 뜨는 것 방지).
class TitleRepository {
  TitleRepository({required ApiClient apiClient}) : _api = apiClient;

  final ApiClient _api;

  /// 새로 획득해 아직 축하 팝업을 띄우지 않은 칭호 큐.
  final ValueNotifier<List<EarnedTitle>> newlyEarned =
      ValueNotifier<List<EarnedTitle>>(const []);

  final Set<String> _knownCodes = <String>{};
  bool _primed = false;

  /// 결과를 흡수해 새 코드만 큐에 추가. 최초(미prime) 호출은 기준선만 잡는다.
  List<EarnedTitle> _absorb(List<EarnedTitle> all) {
    final fresh = <EarnedTitle>[];
    for (final t in all) {
      if (_knownCodes.add(t.code) && _primed) fresh.add(t);
    }
    _primed = true;
    if (fresh.isNotEmpty) {
      newlyEarned.value = [...newlyEarned.value, ...fresh];
    }
    return all;
  }

  /// 축하 팝업을 띄운 칭호를 큐에서 제거(다음 것이 있으면 리스너가 이어서 처리).
  void popNewlyEarned() {
    final v = newlyEarned.value;
    if (v.isNotEmpty) newlyEarned.value = v.sublist(1);
  }

  /// 내가 획득한 칭호 전체. (작성 일기 수 칭호는 서버가 조회 시 자동 적재)
  Future<List<EarnedTitle>> list() async {
    final res = await _api.get<List<dynamic>>('/titles');
    final items = res.data ?? const [];
    final result = items
        .map((e) => EarnedTitle.fromJson((e as Map).cast<String, dynamic>()))
        .toList();
    return _absorb(result);
  }

  /// 앱이 판정한 획득 칭호들을 멱등 적재하고 전체 목록을 돌려받는다.
  /// (이미 보유/비멤버 그룹/잘못된 코드는 서버가 조용히 건너뜀)
  Future<List<EarnedTitle>> claim(List<TitleClaim> titles) async {
    if (titles.isEmpty) return list();
    final res = await _api.post<List<dynamic>>(
      '/titles/claim',
      body: {'titles': titles.map((t) => t.toJson()).toList()},
    );
    final items = res.data ?? const [];
    final result = items
        .map((e) => EarnedTitle.fromJson((e as Map).cast<String, dynamic>()))
        .toList();
    return _absorb(result);
  }

  /// 그룹 모찌에 장착된 칭호 조회(없으면 code=null).
  Future<EquippedTitle> equipped(String groupRoomId) async {
    final res = await _api.get<Map<String, dynamic>>(
      '/titles/equipped',
      query: {'groupRoomId': groupRoomId},
    );
    return EquippedTitle.fromJson(res.data ?? const {});
  }

  /// 그룹 모찌에 칭호 장착/해제(code=null 이면 해제). 본인 보유 칭호만 가능.
  Future<EquippedTitle> equip(String groupRoomId, String? code) async {
    final res = await _api.put<Map<String, dynamic>>(
      '/titles/equip',
      body: {
        'groupRoomId': int.tryParse(groupRoomId) ?? groupRoomId,
        'code': code,
      },
    );
    return EquippedTitle.fromJson(res.data ?? const {});
  }
}
