/// 디그다 역대 별명 전시관 카드 1장.
///
/// 앞면 = [imageUrl] + [nickname], 뒷면 = [history](별명이 생긴 배경·역사·설명).
class NicknameExhibit {
  const NicknameExhibit({
    required this.id,
    required this.nickname,
    required this.imageUrl,
    required this.history,
  });

  final int id;
  final String nickname;
  final String? imageUrl;
  final String history;

  factory NicknameExhibit.fromJson(Map<String, dynamic> json) {
    return NicknameExhibit(
      id: (json['id'] as num).toInt(),
      nickname: json['nickname'] as String? ?? '',
      imageUrl: json['imageUrl'] as String?,
      history: json['history'] as String? ?? '',
    );
  }
}
