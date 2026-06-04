import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import '../theme/colors.dart';

/// 그룹 사진을 따로 지정하지 않은 그룹의 기본 썸네일.
/// 코랄 배경 위에 디그팟 모찌 마크를 얹어 브랜드 기본 이미지로 사용한다.
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
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: borderRadius == null ? BoxShape.circle : BoxShape.rectangle,
        borderRadius: borderRadius,
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFFFF8A8A), AppColors.primary],
        ),
      ),
      alignment: Alignment.center,
      child: SvgPicture.asset(
        'assets/svg/logo_mochi_mark.svg',
        width: size * 0.74,
        height: size * 0.74,
      ),
    );
  }
}
