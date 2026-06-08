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
    this.zoom = 1.0,
    this.selectedKey,
    this.focusGroup,
  });

  final KoreaMapData data;

  /// 색칠 키 → 일기 수.
  final Map<String, int> counts;

  final double scale;
  final double dx;
  final double dy;

  /// InteractiveViewer 의 현재 확대 배율. 라벨 밀도 조절(줌 인할수록 작은 지역명 노출)에 사용.
  final double zoom;

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

    // 1) Ambient shadow — 합친 실루엣 1회 블러(250회 개별 블러 대비 대폭 절감).
    final ambient = Paint()
      ..color = KoreaMapTokens.ambientShadow
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 6);
    canvas.save();
    canvas.translate(0, 14);
    canvas.drawPath(data.combinedPath, ambient);
    canvas.restore();

    // 2) Side wall — 두께도 합친 실루엣 1회.
    final side = Paint()..color = KoreaMapTokens.sideWall;
    canvas.save();
    canvas.translate(0, 7);
    canvas.drawPath(data.combinedPath, side);
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

    // 5) 선택 강조 — 선택 조각을 살짝 띄워(lift) 입체적으로 강조(handoff §5).
    const double lift = 5.0;
    final sel = selectedKey;
    if (sel != null) {
      final selPaths = data.byKey[sel] ?? const [];
      // a) 떠오른 블록 아래 드롭 섀도.
      final dropShadow = Paint()
        ..color = const Color(0x4D7A4A2E)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 6);
      canvas.save();
      canvas.translate(0, 7);
      for (final r in selPaths) {
        canvas.drawPath(r.path, dropShadow);
      }
      canvas.restore();
      // b) 측벽(원위치, 진한 코랄) — 띄운 윗면 아래로 두께가 보이게.
      final selSide = Paint()..color = const Color(0xFFE07A63);
      for (final r in selPaths) {
        canvas.drawPath(r.path, selSide);
      }
      // c) 윗면(코랄) + 외곽선을 lift 만큼 위로.
      final selTop = Paint()..shader = coralShader;
      final selStroke = Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2.0
        ..color = KoreaMapTokens.selectedStroke;
      canvas.save();
      canvas.translate(0, -lift);
      for (final r in selPaths) {
        canvas.drawPath(r.path, selTop);
        canvas.drawPath(r.path, selStroke);
      }
      canvas.restore();
    }

    // 6) Labels — 줌 레벨에 따라 노출(축소 시 큰/외딴 지역만, 확대하면 작은 지역도).
    //    채색/선택/광역시는 항상 표시. 선택 지역 라벨은 lift 만큼 함께 위로.
    final double minFont = _minLabelFontForZoom(zoom);
    for (final entry in data.keyCenter.entries) {
      final key = entry.key;
      final count = counts[key] ?? 0;
      final meta = data.metaOf(key);
      final colored = meta != null && meta.isColored(count);
      final isSel = key == sel;
      final size = data.keyLabelSize[key] ?? 8.0;
      final alwaysShow = colored || isSel || data.keyMetro[key] == true;
      if (!alwaysShow && size < minFont) continue;
      final dimmed = focusGroup != null && data.keyGroup[key] != focusGroup;
      final center = isSel ? entry.value - const Offset(0, lift) : entry.value;
      _drawLabel(
        canvas,
        data.keyLabel[key] ?? key,
        center,
        colored || isSel,
        size,
        dimmed,
      );
    }

    canvas.restore();
  }

  /// 현재 줌에서 표시할 라벨의 최소 적응형 폰트 크기. 0 이면 전부 표시.
  double _minLabelFontForZoom(double z) {
    if (z >= 3.0) return 0;
    if (z >= 2.2) return 6.5;
    if (z >= 1.6) return 7.5;
    if (z >= 1.25) return 9.0;
    return 10.0;
  }

  void _drawLabel(
    Canvas canvas,
    String text,
    Offset center,
    bool onCoral,
    double fontSize,
    bool dimmed,
  ) {
    final double op = dimmed ? 0.34 : 1.0;
    // 가독성: 진한 잉크 글자 + 대비되는 외곽선(stroke)을 뒤에 깔아 또렷하게.
    final Color fill =
        (onCoral ? Colors.white : const Color(0xFF453A2C)).withValues(alpha: op);
    final Color outline =
        (onCoral ? const Color(0xFFB23A2C) : const Color(0xFFFBF6EC))
            .withValues(alpha: op);
    final double strokeW = (fontSize * 0.30).clamp(1.4, 4.0);

    final strokePainter = TextPainter(
      text: TextSpan(
        text: text,
        style: TextStyle(
          fontFamily: 'Inter',
          fontSize: fontSize,
          fontWeight: FontWeight.w800,
          height: 1.0,
          foreground: Paint()
            ..style = PaintingStyle.stroke
            ..strokeWidth = strokeW
            ..strokeJoin = StrokeJoin.round
            ..color = outline,
        ),
      ),
      textDirection: TextDirection.ltr,
      textAlign: TextAlign.center,
    )..layout();
    final pos = center - Offset(strokePainter.width / 2, strokePainter.height / 2);
    strokePainter.paint(canvas, pos);

    final fillPainter = TextPainter(
      text: TextSpan(
        text: text,
        style: TextStyle(
          fontFamily: 'Inter',
          fontSize: fontSize,
          fontWeight: FontWeight.w800,
          height: 1.0,
          color: fill,
        ),
      ),
      textDirection: TextDirection.ltr,
      textAlign: TextAlign.center,
    )..layout();
    fillPainter.paint(canvas, pos);
  }

  @override
  bool shouldRepaint(covariant KoreaMapPainter old) =>
      old.selectedKey != selectedKey ||
      old.focusGroup != focusGroup ||
      old.zoom != zoom ||
      !identical(old.counts, counts) ||
      old.scale != scale ||
      old.dx != dx ||
      old.dy != dy;
}
