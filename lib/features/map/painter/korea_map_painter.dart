import 'dart:ui' as ui;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import '../data/korea_map_models.dart';

/// 지형 베이스 레이어 — ambient/측벽/윗면/홈선. 색칠(counts)·권역 포커스·fit 이 바뀔
/// 때만 다시 그리며, RepaintBoundary 로 캐시돼 패닝/줌·선택 시엔 재래스터되지 않는다.
class KoreaBasePainter extends CustomPainter {
  KoreaBasePainter({
    required this.data,
    required this.counts,
    required this.completedGroups,
    required this.partialGroups,
    required this.scale,
    required this.dx,
    required this.dy,
    this.focusGroup,
  });

  final KoreaMapData data;

  /// 색칠 키 → 일기 수.
  final Map<String, int> counts;

  /// 모든 시·군·구가 채워진 도(버킷) — 그 도 전체를 코랄로 색칠.
  final Set<String> completedGroups;

  /// 일부만 채워진 도(버킷) — 진행 중 소프트 톤.
  final Set<String> partialGroups;

  final double scale;
  final double dx;
  final double dy;

  /// 선택된 탭 버킷(광역시/경기북부/강원/…). 지정 시 그 버킷만 또렷하고 나머지는 디밍.
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
      // 색칠은 도(버킷) 단위 — 그 도의 시·군·구가 다 차면 코랄, 일부면 소프트.
      final group = data.keyFocusGroup[r.key];
      final Paint p;
      if (completedGroups.contains(group)) {
        p = coralPaint;
      } else if (partialGroups.contains(group)) {
        p = softPaint;
      } else {
        p = warmPaint;
      }
      canvas.drawPath(r.path, p);
      // 탭 포커스 시 다른 버킷은 아이보리 베일로 덮어 가라앉힌다.
      if (focusGroup != null && group != focusGroup) {
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

    canvas.restore();
  }

  @override
  bool shouldRepaint(covariant KoreaBasePainter old) =>
      old.focusGroup != focusGroup ||
      !identical(old.counts, counts) ||
      !identical(old.completedGroups, completedGroups) ||
      !identical(old.partialGroups, partialGroups) ||
      old.scale != scale ||
      old.dx != dx ||
      old.dy != dy;
}

/// 선택 강조(lift) + 라벨 오버레이. InteractiveViewer 변환([transform])에 맞춰 다시 그리되,
/// 화면 밖 라벨은 컬링하고 줌 레벨로 노출을 조절해 가볍게 유지한다.
/// 베이스(지형)는 별도 RepaintBoundary 라 이 오버레이만 패닝/줌 때 재그려진다.
class KoreaOverlayPainter extends CustomPainter {
  KoreaOverlayPainter({
    required this.data,
    required this.counts,
    required this.completedGroups,
    required this.scale,
    required this.dx,
    required this.dy,
    required this.transform,
    this.selectedKey,
    this.focusGroup,
  }) : super(repaint: transform);

  final KoreaMapData data;
  final Map<String, int> counts;

  /// 모든 시·군·구가 채워진 도(버킷) — 그 도의 라벨을 코랄(흰 글자)로.
  final Set<String> completedGroups;
  final double scale;
  final double dx;
  final double dy;

  /// InteractiveViewer 의 현재 변환(child→screen). 줌/가시영역 계산에 사용.
  final ValueListenable<Matrix4> transform;

  final String? selectedKey;
  final String? focusGroup;

  /// 키별 [stroke, fill] TextPainter 캐시 — 매 프레임 layout 비용 제거(줌/팬 성능).
  /// 색칠·포커스·선택 상태가 바뀌면 setState 로 새 인스턴스가 생겨 캐시가 비므로
  /// (색/투명도/굵기를 생성 시 고정해도) 항상 최신이 보장된다.
  final Map<String, List<TextPainter>> _labelCache = {};

  @override
  void paint(Canvas canvas, Size size) {
    canvas.save();
    canvas.translate(dx, dy);
    canvas.scale(scale);

    final w = data.width;
    final h = data.height;
    final coralShader = ui.Gradient.linear(
      Offset(w * 0.3, h * 0.15),
      Offset(w * 0.7, h * 0.9),
      KoreaMapTokens.coral,
    );

    final m = transform.value;
    final zoom = m.getMaxScaleOnAxis();
    final Rect? visible = _visibleViewBox(m, size);

    // 선택 강조 — 선택 조각을 살짝 띄워(lift) 입체적으로 강조(handoff §5).
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
      // b) 측벽(원위치, 진한 코랄).
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

    // 라벨 — 줌 레벨별 노출 + 화면 밖 컬링. 채색/선택/광역시는 항상(보일 때).
    final double minFont = _minLabelFontForZoom(zoom);
    for (final entry in data.keyCenter.entries) {
      final center0 = entry.value;
      // 화면 밖이면 건너뜀(고배율에서 라벨 레이아웃 비용 절감).
      if (visible != null && !visible.contains(center0)) continue;
      final key = entry.key;
      final group = data.keyFocusGroup[key];
      final colored = completedGroups.contains(group);
      final isSel = key == sel;
      final sizeF = data.keyLabelSize[key] ?? 8.0;
      final alwaysShow = colored || isSel || data.keyMetro[key] == true;
      if (!alwaysShow && sizeF < minFont) continue;
      final dimmed = focusGroup != null && group != focusGroup;
      final center = isSel ? center0 - const Offset(0, lift) : center0;
      _drawLabel(
        canvas,
        key,
        data.keyLabel[key] ?? key,
        center,
        colored || isSel,
        sizeF,
        dimmed,
      );
    }

    canvas.restore();
  }

  /// 현재 변환에서 화면에 보이는 viewBox 영역(컬링용). 역행렬 실패 시 null(=전체 표시).
  Rect? _visibleViewBox(Matrix4 m, Size size) {
    final inv = Matrix4.tryInvert(m);
    if (inv == null) return null;
    // 화면 4모서리 → child 좌표 → viewBox 좌표 바운딩박스.
    final corners = [
      _apply(inv, 0, 0),
      _apply(inv, size.width, 0),
      _apply(inv, 0, size.height),
      _apply(inv, size.width, size.height),
    ];
    double minX = double.infinity, minY = double.infinity;
    double maxX = -double.infinity, maxY = -double.infinity;
    for (final c in corners) {
      final vx = (c.dx - dx) / scale;
      final vy = (c.dy - dy) / scale;
      if (vx < minX) minX = vx;
      if (vy < minY) minY = vy;
      if (vx > maxX) maxX = vx;
      if (vy > maxY) maxY = vy;
    }
    // 라벨 텍스트가 중심 밖으로 번지므로 약간의 여유.
    return Rect.fromLTRB(minX, minY, maxX, maxY).inflate(24);
  }

  Offset _apply(Matrix4 m, double x, double y) {
    final s = m.storage;
    final nx = s[0] * x + s[4] * y + s[12];
    final ny = s[1] * x + s[5] * y + s[13];
    final nw = s[3] * x + s[7] * y + s[15];
    if (nw == 0) return Offset(nx, ny);
    return Offset(nx / nw, ny / nw);
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
    String key,
    String text,
    Offset center,
    bool onCoral,
    double fontSize,
    bool dimmed,
  ) {
    var pair = _labelCache[key];
    if (pair == null) {
      final double op = dimmed ? 0.34 : 1.0;
      // 가독성: 진한 잉크 글자 + 대비되는 외곽선(stroke)을 뒤에 깔아 또렷하게.
      final Color fill =
          (onCoral ? Colors.white : const Color(0xFF453A2C))
              .withValues(alpha: op);
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

      pair = [strokePainter, fillPainter];
      _labelCache[key] = pair;
    }

    final strokePainter = pair[0];
    final fillPainter = pair[1];
    final pos =
        center - Offset(strokePainter.width / 2, strokePainter.height / 2);
    strokePainter.paint(canvas, pos);
    fillPainter.paint(canvas, pos);
  }

  @override
  bool shouldRepaint(covariant KoreaOverlayPainter old) =>
      old.selectedKey != selectedKey ||
      old.focusGroup != focusGroup ||
      !identical(old.counts, counts) ||
      !identical(old.completedGroups, completedGroups) ||
      old.scale != scale ||
      old.dx != dx ||
      old.dy != dy;
}
