import 'dart:ui' as ui;

import 'package:flutter/material.dart';

import '../data/korea_map_models.dart';

/// 시그니처 지도 CustomPainter. viewBox(data.width×height) 좌표를 [scale]/[dx],[dy] 로
/// 화면에 맞춰 그린다. 레이어(handoff §2): ambient → side → top → groove → label → 선택.
class KoreaMapPainter extends CustomPainter {
  KoreaMapPainter({
    required this.data,
    required this.counts,
    required this.scale,
    required this.dx,
    required this.dy,
    this.selectedKey,
    this.focusGroup,
  });

  final KoreaMapData data;

  /// 색칠 키 → 일기 수.
  final Map<String, int> counts;

  final double scale;
  final double dx;
  final double dy;
  final String? selectedKey;

  /// 선택된 권역(수도권/강원/…). 지정 시 그 권역만 또렷하고 나머지는 디밍.
  final String? focusGroup;

  /// 비포커스 권역을 가라앉히는 아이보리 베일.
  final Paint _dimVeil = Paint()..color = const Color(0xCCFBF7EF);

  @override
  void paint(Canvas canvas, Size size) {
    canvas.save();
    canvas.translate(dx, dy);
    canvas.scale(scale);

    final w = data.width;
    final h = data.height;

    // 공유 그라데이션(handoff §2 핵심: 시군별 개별 금지, 전역 1개 공유)
    final warmShader = ui.Gradient.linear(
      Offset(w * 0.42, h * 0.12),
      Offset(w * 0.58, h * 0.95),
      KoreaMapTokens.topFace,
      const [0.0, 0.5, 1.0],
    );
    final coralShader = ui.Gradient.linear(
      Offset(w * 0.3, h * 0.15),
      Offset(w * 0.7, h * 0.9),
      KoreaMapTokens.coral,
    );

    // 1) Ambient shadow — 전체를 아래로 깔고 블러.
    final ambient = Paint()
      ..color = KoreaMapTokens.ambientShadow
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 6);
    canvas.save();
    canvas.translate(0, 14);
    for (final r in data.regions) {
      canvas.drawPath(r.path, ambient);
    }
    canvas.restore();

    // 2) Side wall — 두께.
    final side = Paint()..color = KoreaMapTokens.sideWall;
    canvas.save();
    canvas.translate(0, 7);
    for (final r in data.regions) {
      canvas.drawPath(r.path, side);
    }
    canvas.restore();

    // 3) Top faces — 채색 여부에 따라 코랄/소프트/웜.
    final warmPaint = Paint()..shader = warmShader;
    final coralPaint = Paint()..shader = coralShader;
    final softPaint = Paint()..color = KoreaMapTokens.coralSoft;
    for (final r in data.regions) {
      final meta = data.metaOf(r.key);
      final count = counts[r.key] ?? 0;
      final Paint p;
      if (meta != null && meta.isColored(count)) {
        p = coralPaint;
      } else if (count > 0) {
        // 진행 중(특히 광역시 1..9) — 살짝 번지는 소프트 톤.
        p = softPaint;
      } else {
        p = warmPaint;
      }
      canvas.drawPath(r.path, p);
      // 권역 포커스 시 다른 권역은 아이보리 베일로 덮어 가라앉힌다.
      if (focusGroup != null && r.group != focusGroup) {
        canvas.drawPath(r.path, _dimVeil);
      }
    }

    // 4) Grooves — 경계선(하이라이트 + 섀도).
    final grooveHi = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 0.8
      ..color = KoreaMapTokens.grooveHi;
    final grooveLo = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 0.6
      ..color = KoreaMapTokens.grooveLo;
    for (final r in data.regions) {
      canvas.drawPath(r.path, grooveLo);
      canvas.drawPath(r.path, grooveHi);
    }

    // 5) 선택 강조 — 선택 key 조각 외곽선 + 살짝 lift.
    final sel = selectedKey;
    if (sel != null) {
      final selPaths = data.byKey[sel] ?? const [];
      final stroke = Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2.2
        ..color = KoreaMapTokens.selectedStroke;
      final selFill = Paint()..shader = coralShader;
      for (final r in selPaths) {
        canvas.drawPath(r.path, selFill);
        canvas.drawPath(r.path, stroke);
      }
    }

    // 6) Labels — 모든 지역명을 항상 표시(적응형 크기). 채색/선택은 흰 글씨로 강조.
    for (final entry in data.keyCenter.entries) {
      final key = entry.key;
      final count = counts[key] ?? 0;
      final meta = data.metaOf(key);
      final colored = meta != null && meta.isColored(count);
      final isSel = key == sel;
      final dimmed = focusGroup != null && data.keyGroup[key] != focusGroup;
      _drawLabel(
        canvas,
        data.keyLabel[key] ?? key,
        entry.value,
        colored || isSel,
        data.keyLabelSize[key] ?? 8.0,
        dimmed,
      );
    }

    canvas.restore();
  }

  void _drawLabel(
    Canvas canvas,
    String text,
    Offset center,
    bool onCoral,
    double fontSize,
    bool dimmed,
  ) {
    final Color ink = onCoral ? Colors.white : KoreaMapTokens.labelInk;
    final tp = TextPainter(
      text: TextSpan(
        text: text,
        style: TextStyle(
          fontFamily: 'Inter',
          fontSize: fontSize,
          fontWeight: FontWeight.w700,
          color: dimmed ? ink.withValues(alpha: 0.28) : ink,
          // paint-order:stroke 효과 — 반투명 아이보리 외곽으로 가독성 확보.
          shadows: onCoral
              ? const [Shadow(color: Color(0x55C2412F), blurRadius: 1.5)]
              : const [Shadow(color: Color(0xCCFFFDFA), blurRadius: 1.5)],
        ),
      ),
      textDirection: TextDirection.ltr,
      textAlign: TextAlign.center,
    )..layout();
    tp.paint(canvas, center - Offset(tp.width / 2, tp.height / 2));
  }

  @override
  bool shouldRepaint(covariant KoreaMapPainter old) =>
      old.selectedKey != selectedKey ||
      old.focusGroup != focusGroup ||
      !identical(old.counts, counts) ||
      old.scale != scale ||
      old.dx != dx ||
      old.dy != dy;
}
