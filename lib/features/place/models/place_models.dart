/// 카카오 로컬 검색 응답에서 화면에 쓰는 최소 필드.
class PlaceSummary {
  PlaceSummary({
    required this.id,
    required this.name,
    required this.addressName,
    required this.roadAddressName,
    required this.category,
    required this.latitude,
    required this.longitude,
  });

  final String id;
  final String name;
  final String addressName;
  final String roadAddressName;
  final String category;
  final double? latitude;
  final double? longitude;

  /// 디스플레이용 짧은 라벨 (예: "성수동 카페").
  String get shortLabel => name;

  factory PlaceSummary.fromKakao(Map<String, dynamic> json) {
    return PlaceSummary(
      id: (json['id'] ?? '').toString(),
      name: (json['place_name'] as String?) ?? '',
      addressName: (json['address_name'] as String?) ?? '',
      roadAddressName: (json['road_address_name'] as String?) ?? '',
      category: (json['category_name'] as String?) ?? '',
      latitude: double.tryParse((json['y'] as String?) ?? ''),
      longitude: double.tryParse((json['x'] as String?) ?? ''),
    );
  }
}
