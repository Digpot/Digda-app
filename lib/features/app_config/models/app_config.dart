/// 앱 전역 운영 설정(서버) — 대공지 배너 + 피드백 메뉴 노출/링크 + 강제 업데이트.
class AppConfig {
  const AppConfig({
    required this.noticeEnabled,
    required this.noticeMessage,
    required this.feedbackEnabled,
    required this.feedbackUrl,
    this.minAppVersion = '',
    this.storeUrlAndroid = '',
    this.storeUrlIos = '',
    this.maintenanceEnabled = false,
    this.maintenanceMessage = '',
  });

  final bool noticeEnabled;
  final String noticeMessage;
  final bool feedbackEnabled;
  final String feedbackUrl;

  /// 강제 업데이트 최소 버전(semver "2.0.0"). 빈 값 = 게이트 끔.
  final String minAppVersion;

  /// 스토어 URL — 빈 값이면 앱이 플랫폼 기본 URL 로 폴백.
  final String storeUrlAndroid;
  final String storeUrlIos;

  /// 서버 점검(업데이트) 모드 — true 면 로그인 여부와 무관하게 전 기능 차단.
  final bool maintenanceEnabled;

  /// 점검 안내 문구. 빈 값이면 앱 기본 문구.
  final String maintenanceMessage;

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
      minAppVersion: json['minAppVersion'] as String? ?? '',
      storeUrlAndroid: json['storeUrlAndroid'] as String? ?? '',
      storeUrlIos: json['storeUrlIos'] as String? ?? '',
      maintenanceEnabled: json['maintenanceEnabled'] as bool? ?? false,
      maintenanceMessage: json['maintenanceMessage'] as String? ?? '',
    );
  }
}
