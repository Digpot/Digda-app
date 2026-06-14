// 고객센터 문의(Inquiry) 도메인 모델.

DateTime _parseUtc(String s) {
  if (s.endsWith('Z') || RegExp(r'[+-]\d{2}:\d{2}$').hasMatch(s)) {
    return DateTime.parse(s);
  }
  if (s.contains('T')) return DateTime.parse('${s}Z');
  return DateTime.parse(s);
}

/// 문의 한 건. 서버 InquiryResponse 와 매핑.
class Inquiry {
  Inquiry({
    required this.id,
    required this.content,
    required this.status,
    required this.createdAt,
    this.answeredAt,
  });

  final String id;
  final String content;

  /// 'PENDING'(접수) | 'ANSWERED'(답변 완료).
  final String status;
  final DateTime createdAt;
  final DateTime? answeredAt;

  bool get isAnswered => status == 'ANSWERED';

  factory Inquiry.fromJson(Map<String, dynamic> json) {
    return Inquiry(
      id: json['id'].toString(),
      content: json['content'] as String? ?? '',
      status: json['status'] as String? ?? 'PENDING',
      createdAt: _parseUtc(json['createdAt'] as String),
      answeredAt: json['answeredAt'] != null
          ? _parseUtc(json['answeredAt'] as String)
          : null,
    );
  }
}
