// 고객센터 문의(Inquiry) 도메인 모델.

DateTime _parseServerTime(String s) {
  // 서버(JVM TZ=Asia/Seoul)는 타임존 표기 없는 KST wall-clock 을 내려주므로,
  // 표기 없으면 로컬(KST)로 그대로 파싱한다. 예전처럼 'Z'를 붙이면 +9시간 어긋난다.
  // Z/오프셋이 붙은 값만 실제 시각으로 보고 toLocal 로 변환.
  if (s.endsWith('Z') || RegExp(r'[+-]\d{2}:\d{2}$').hasMatch(s)) {
    return DateTime.parse(s).toLocal();
  }
  return DateTime.parse(s);
}

/// 문의 한 건. 서버 InquiryResponse 와 매핑.
class Inquiry {
  Inquiry({
    required this.id,
    required this.content,
    required this.status,
    this.answer,
    required this.createdAt,
    this.answeredAt,
  });

  final String id;
  final String content;

  /// 'PENDING'(접수) | 'ANSWERED'(답변 완료).
  final String status;

  /// 어드민 답변 내용(미답변이면 null).
  final String? answer;
  final DateTime createdAt;
  final DateTime? answeredAt;

  bool get isAnswered => status == 'ANSWERED';

  factory Inquiry.fromJson(Map<String, dynamic> json) {
    return Inquiry(
      id: json['id'].toString(),
      content: json['content'] as String? ?? '',
      status: json['status'] as String? ?? 'PENDING',
      answer: json['answer'] as String?,
      createdAt: _parseServerTime(json['createdAt'] as String),
      answeredAt: json['answeredAt'] != null
          ? _parseServerTime(json['answeredAt'] as String)
          : null,
    );
  }
}
