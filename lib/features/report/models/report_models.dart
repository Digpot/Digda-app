/// 신고(Report) 도메인 모델. 서버 enum 과 wire 값을 맞춘다.

/// 신고 대상 종류.
enum ReportTargetType {
  diary('DIARY'),
  comment('COMMENT'),
  schedule('SCHEDULE'),
  user('USER');

  const ReportTargetType(this.wire);
  final String wire;
}

/// 신고 사유. [label] 은 사용자에게 보여줄 한국어 문구.
enum ReportReason {
  spam('SPAM', '스팸·광고·도배'),
  abuse('ABUSE', '욕설·비방·괴롭힘'),
  sexual('SEXUAL', '음란물·선정성'),
  violence('VIOLENCE', '폭력·혐오'),
  privacy('PRIVACY', '개인정보 노출'),
  etc('ETC', '기타');

  const ReportReason(this.wire, this.label);
  final String wire;
  final String label;
}
