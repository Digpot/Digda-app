import 'package:flutter/material.dart';

/// 미니게임 화면 공용 소품 — 로비/랭킹 등에서 쓰는 참가자 아바타.
///
/// 게임 참가자에겐 멤버 색 정보가 없어(서버 스냅샷에 이름만),
/// 이름 해시로 파스텔 색을 안정적으로 골라 같은 사람은 늘 같은 색이 되게 한다.
class GamePlayerAvatar extends StatelessWidget {
  const GamePlayerAvatar({
    super.key,
    required this.name,
    this.size = 38,
    this.dimmed = false,
  });

  final String name;
  final double size;

  /// 탈락/거절 등 가라앉은 상태 — 회색 처리.
  final bool dimmed;

  static const List<Color> _palette = [
    Color(0xFFFF8A5B),
    Color(0xFFFF6B6B),
    Color(0xFF34C08A),
    Color(0xFFF4B53C),
    Color(0xFFA98BF0),
    Color(0xFF5BB7D9),
    Color(0xFFF47BB4),
    Color(0xFF8FBF5A),
  ];

  Color get _accent =>
      dimmed ? const Color(0xFF9CA3AF) : _palette[name.hashCode.abs() % _palette.length];

  @override
  Widget build(BuildContext context) {
    final accent = _accent;
    return Container(
      width: size,
      height: size,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: accent.withValues(alpha: 0.16),
        shape: BoxShape.circle,
        border: Border.all(color: accent.withValues(alpha: 0.45)),
      ),
      child: Text(
        name.isEmpty ? '?' : name.characters.first,
        style: TextStyle(
          fontFamily: 'Inter',
          fontWeight: FontWeight.w800,
          fontSize: size * 0.4,
          color: accent,
        ),
      ),
    );
  }
}
