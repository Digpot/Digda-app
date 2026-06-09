/// 앱 전역 운영 설정(서버) — 대공지 배너 + 피드백 메뉴 노출/링크.
class AppConfig {
  const AppConfig({
    required this.noticeEnabled,
    required this.noticeMessage,
    required this.feedbackEnabled,
    required this.feedbackUrl,
  });

  final bool noticeEnabled;
  final String noticeMessage;
  final bool feedbackEnabled;
  final String feedbackUrl;

  static const empty = AppConfig(
    noticeEnabled: false,
    noticeMessage: '',
    feedbackEnabled: false,
    feedbackUrl: '',
  );

  /// 대공지를 실제로 띄울지 — 켜져 있고 메시지가 있을 때만.
  bool get showNotice => noticeEnabled && noticeMessage.trim().isNotEmpty;

  /// 피드백 메뉴 노출 여부.
  bool get showFeedback => feedbackEnabled;

  factory AppConfig.fromJson(Map<String, dynamic> json) {
    return AppConfig(
      noticeEnabled: json['noticeEnabled'] as bool? ?? false,
      noticeMessage: json['noticeMessage'] as String? ?? '',
      feedbackEnabled: json['feedbackEnabled'] as bool? ?? false,
      feedbackUrl: json['feedbackUrl'] as String? ?? '',
    );
  }
}
