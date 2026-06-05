import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

/// 그룹 사진을 따로 지정하지 않은 그룹의 기본 썸네일.
/// 앱 브랜드 로고(코랄 배경 + 활짝 모찌)를 그대로 채워 "우리 로고" 기본 이미지로 쓴다.
/// [borderRadius] 가 null 이면 원형으로 그린다(그룹 전환 시트의 CircleAvatar 등).
class GroupDefaultAvatar extends StatelessWidget {
  final double size;
  final BorderRadius? borderRadius;

  const GroupDefaultAvatar({
    super.key,
    required this.size,
    this.borderRadius,
  });

  @override
  Widget build(BuildContext context) {
    // 코랄 배경과 중앙 정렬된 모찌를 모두 포함한 정사각 로고를 통째로 채운 뒤,
    // 모서리만 원하는 모양(둥근 사각/원)으로 클립한다.
    final logo = SvgPicture.asset(
      'assets/svg/logo_square.svg',
      width: size,
      height: size,
      fit: BoxFit.cover,
    );
    if (borderRadius == null) {
      return ClipOval(
        child: SizedBox(width: size, height: size, child: logo),
      );
    }
    return ClipRRect(
      borderRadius: borderRadius!,
      child: SizedBox(width: size, height: size, child: logo),
    );
  }
}
