/// 12번 도메인(Upload) 응답 DTO.

class UploadedImage {
  UploadedImage({
    required this.id,
    required this.url,
    required this.width,
    required this.height,
  });

  final String id;
  final String url;
  final int width;
  final int height;

  factory UploadedImage.fromJson(Map<String, dynamic> json) {
    return UploadedImage(
      id: json['id'].toString(),
      url: json['url'] as String,
      width: (json['width'] as num).toInt(),
      height: (json['height'] as num).toInt(),
    );
  }
}

/// 업로드 용도. 서버 enum 과 일치.
enum UploadPurpose {
  profile('profile'),
  groupThumbnail('group_thumbnail'),
  diary('diary');

  const UploadPurpose(this.value);
  final String value;
}
