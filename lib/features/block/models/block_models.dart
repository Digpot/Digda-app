/// 차단/숨김(Block) 도메인 모델.

DateTime _parseUtc(String s) {
  if (s.endsWith('Z') || RegExp(r'[+-]\d{2}:\d{2}$').hasMatch(s)) {
    return DateTime.parse(s);
  }
  if (s.contains('T')) return DateTime.parse('${s}Z');
  return DateTime.parse(s);
}

/// 개별 콘텐츠 숨김 대상. 서버 HideTargetType 과 wire 값 일치.
enum HideTargetType {
  diary('DIARY'),
  comment('COMMENT'),
  schedule('SCHEDULE');

  const HideTargetType(this.wire);
  final String wire;
}

/// 마이페이지 차단 목록 한 줄.
class BlockedUser {
  BlockedUser({
    required this.userId,
    required this.name,
    this.profileImage,
    required this.blockedAt,
  });

  final String userId;
  final String name;
  final String? profileImage;
  final DateTime blockedAt;

  factory BlockedUser.fromJson(Map<String, dynamic> json) {
    return BlockedUser(
      userId: (json['userId'] ?? json['id']).toString(),
      name: json['name'] as String? ?? '알 수 없음',
      profileImage: json['profileImage'] as String?,
      blockedAt: _parseUtc(json['blockedAt'] as String),
    );
  }
}

/// 숨김 사유 코드(서버 VisibilityReason) → 사용자 안내 문구.
/// [noun] 은 "일기"/"댓글"/"일정" 등 콘텐츠 종류.
String hiddenReasonMessage(String? reasonCode, {String noun = '콘텐츠'}) {
  switch (reasonCode) {
    case 'BLOCKED_USER':
      return '차단한 사용자의 $noun(이)라 볼 수 없어요';
    case 'REPORTED':
      return '신고하여 숨긴 $noun예요';
    case 'HIDDEN':
      return '숨긴 $noun예요';
    default:
      return '볼 수 없는 $noun예요';
  }
}
