// 차단/숨김(Block) 도메인 모델.

DateTime _parseServerTime(String s) {
  // 서버(JVM TZ=Asia/Seoul)는 타임존 표기 없는 KST wall-clock 을 내려주므로,
  // 표기 없으면 로컬(KST)로 그대로 파싱한다. 예전처럼 'Z'를 붙이면 +9시간 어긋난다.
  // Z/오프셋이 붙은 값만 실제 시각으로 보고 toLocal 로 변환.
  if (s.endsWith('Z') || RegExp(r'[+-]\d{2}:\d{2}$').hasMatch(s)) {
    return DateTime.parse(s).toLocal();
  }
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
      blockedAt: _parseServerTime(json['blockedAt'] as String),
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
