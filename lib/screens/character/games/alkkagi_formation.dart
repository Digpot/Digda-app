import 'dart:math' as math;

import 'package:flutter/material.dart';

/// 알까기 시작 대형 — 서버 `AlkkagiGame.Formation` 과 1:1 대응.
enum AlkkagiFormation {
  line('LINE', '일렬 횡대', '기본. 앞줄에 나란히'),
  double_('DOUBLE', '이열 종대', '두 줄 기둥으로 튼튼하게'),
  wedge('WEDGE', '쐐기(V자)', '한 점 돌파 공격형'),
  diamond('DIAMOND', '다이아몬드', '사방을 둘러싼 진형'),
  sides('SIDES', '양 날개', '좌우 협공 스타일');

  const AlkkagiFormation(this.key, this.label, this.desc);

  /// 서버로 보내는 enum 이름.
  final String key;
  final String label;
  final String desc;
}

/// 대형별 로컬 배치 (x ∈ [0,1], depth ∈ [0,1]) — 서버 formationPoints 와 동일 로직.
/// 프리뷰 렌더 전용(실제 배치는 서버가 계산).
List<Offset> alkkagiFormationPoints(AlkkagiFormation f, int count) {
  switch (f) {
    case AlkkagiFormation.line:
      final pts = <Offset>[];
      final front = count < 5 ? count : 5;
      final back = count - front;
      List<double> rowXs(int k) =>
          [for (var i = 0; i < k; i++) 0.5 + (i - (k - 1) / 2.0) * 0.14];
      for (final x in rowXs(front)) {
        pts.add(Offset(x, 0.25));
      }
      for (final x in rowXs(back)) {
        pts.add(Offset(x, 0.75));
      }
      return pts;
    case AlkkagiFormation.double_:
      final pts = <Offset>[];
      final leftCol = (count + 1) ~/ 2;
      final rightCol = count - leftCol;
      List<double> colDepths(int k) =>
          [for (var i = 0; i < k; i++) k == 1 ? 0.5 : i / (k - 1)];
      for (final d in colDepths(leftCol)) {
        pts.add(Offset(0.36, d));
      }
      for (final d in colDepths(rightCol)) {
        pts.add(Offset(0.64, d));
      }
      return pts;
    case AlkkagiFormation.wedge:
      final pts = <Offset>[const Offset(0.5, 0)];
      var k = 1;
      while (pts.length < count && k <= 4) {
        pts.add(Offset(0.5 - 0.1 * k, 0.22 * k));
        if (pts.length < count) pts.add(Offset(0.5 + 0.1 * k, 0.22 * k));
        k += 1;
      }
      if (pts.length < count) pts.add(const Offset(0.5, 0.55));
      return pts;
    case AlkkagiFormation.diamond:
      if (count == 1) return const [Offset(0.5, 0.5)];
      return [
        for (var i = 0; i < count; i++)
          Offset(
            0.5 + 0.24 * math.cos(2 * math.pi * i / count - math.pi / 2),
            0.5 + 0.46 * math.sin(2 * math.pi * i / count - math.pi / 2),
          ),
      ];
    case AlkkagiFormation.sides:
      final pts = <Offset>[];
      final leftCol = (count + 1) ~/ 2;
      final rightCol = count - leftCol;
      List<double> colDepths(int k) =>
          [for (var i = 0; i < k; i++) k == 1 ? 0.5 : i / (k - 1)];
      for (final d in colDepths(leftCol)) {
        pts.add(Offset(0.14, d));
      }
      for (final d in colDepths(rightCol)) {
        pts.add(Offset(0.86, d));
      }
      return pts;
  }
}

/// 대형 선택 그리드 — 미니 프리뷰와 함께 5종 중 하나를 고른다.
class AlkkagiFormationPicker extends StatelessWidget {
  const AlkkagiFormationPicker({
    super.key,
    required this.selected,
    required this.stoneCount,
    required this.onChanged,
    this.dark = false,
  });

  final AlkkagiFormation selected;
  final int stoneCount;
  final ValueChanged<AlkkagiFormation> onChanged;

  /// 어두운 배경(대국 화면 수락 카드)용 색상.
  final bool dark;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 96,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: AlkkagiFormation.values.length,
        separatorBuilder: (_, __) => const SizedBox(width: 8),
        itemBuilder: (context, i) {
          final f = AlkkagiFormation.values[i];
          final isSel = f == selected;
          const accent = Color(0xFFF59E0B);
          final baseColor = dark
              ? Colors.white.withValues(alpha: 0.07)
              : const Color(0xFFF9FAFB);
          final borderColor = isSel
              ? accent
              : dark
                  ? Colors.white24
                  : const Color(0xFFE5E7EB);
          return GestureDetector(
            onTap: () => onChanged(f),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 150),
              width: 86,
              padding: const EdgeInsets.symmetric(vertical: 8),
              decoration: BoxDecoration(
                color: isSel ? accent.withValues(alpha: 0.12) : baseColor,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(
                  color: borderColor,
                  width: isSel ? 1.8 : 1,
                ),
              ),
              child: Column(
                children: [
                  Expanded(
                    child: CustomPaint(
                      size: const Size(60, 44),
                      painter: _FormationPreviewPainter(
                        formation: f,
                        count: stoneCount,
                        color: isSel
                            ? accent
                            : dark
                                ? Colors.white70
                                : const Color(0xFF6B7280),
                      ),
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    f.label,
                    style: TextStyle(
                      fontFamily: 'Inter',
                      fontWeight: isSel ? FontWeight.w800 : FontWeight.w600,
                      fontSize: 10.5,
                      color: isSel
                          ? accent
                          : dark
                              ? Colors.white70
                              : const Color(0xFF6B7280),
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}

class _FormationPreviewPainter extends CustomPainter {
  _FormationPreviewPainter({
    required this.formation,
    required this.count,
    required this.color,
  });

  final AlkkagiFormation formation;
  final int count;
  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final pts = alkkagiFormationPoints(formation, count);
    final paint = Paint()..color = color;
    for (final p in pts) {
      canvas.drawCircle(
        Offset(p.dx * size.width, p.dy * size.height * 0.9 + size.height * 0.05),
        3.2,
        paint,
      );
    }
  }

  @override
  bool shouldRepaint(_FormationPreviewPainter old) =>
      old.formation != formation || old.count != count || old.color != color;
}
