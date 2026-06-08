import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import '../data/korea_map_models.dart';

/// 지형 + 색칠 + 선택 강조 + 권역/광역시 포커스(디밍·경계선)를 모두 그리는 베이스 레이어.
/// InteractiveViewer 의 변환을 받는 child 안에 있으므로, 줌/패닝 시에는 이 레이어를
/// 다시 그리지 않고(RepaintBoundary 라스터를 GPU 가 변환만) — counts/포커스/선택이
/// 바뀔 때만 repaint 한다. 라벨은 별도의 화면 좌표 레이어([KoreaLabelPainter]).
class KoreaBasePainter extends CustomPainter {
  KoreaBasePainter({
    required this.data,
    required this.counts,
    required this.scale,
    required this.dx,
    required this.dy,
    this.focusGroup,
    this.focusKey,
    this.focusColor,
    this.selectedKey,
  });

  final KoreaMapData data;

  /// 색칠 키 → 일기 수.
  final Map<String, int> counts;

  final double scale;
  final double dx;
  final double dy;

  /// 포커스 권역(수도권/강원/…). focusKey 가 없을 때만 사용.
  final String? focusGroup;

  /// 포커스 광역시 색칠 키(서울/부산/…). 지정 시 그 시 1곳만 또렷.
  final String? focusKey;

  /// 포커스 대상의 시그니처 색 — 경계선을 이 색으로 그린다.
  final Color? focusColor;

  /// 선택(탭)된 조각 — 살짝 띄워 강조.
  final String? selectedKey;

  /// 비포커스 영역을 흰 바탕으로 가라앉히는 베일.
  final Paint _dimVeil = Paint()..color = KoreaMapTokens.dimVeil;

  bool get _hasFocus => focusKey != null || focusGroup != null;

  bool _isFocused(MapRegion r) {
    if (focusKey != null) return r.key == focusKey;
    if (focusGroup != null) return r.group == focusGroup;
    return true;
  }

  @override
  void paint(Canvas canvas, Size size) {
    canvas.save();
    canvas.translate(dx, dy);
    canvas.scale(scale);

    final w = data.width;
    final h = data.height;

    // 공유 그라데이션(시군별 개별 금지, 전역 1개 공유).
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

    // 1) Ambient shadow — 합친 실루엣 1회 블러.
    final ambient = Paint()
      ..color = KoreaMapTokens.ambientShadow
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 6);
    canvas.save();
    canvas.translate(0, 14);
    canvas.drawPath(data.combinedPath, ambient);
    canvas.restore();

    // 2) Side wall — 합친 실루엣 1회.
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
        p = softPaint;
      } else {
        p = warmPaint;
      }
      canvas.drawPath(r.path, p);
      // 포커스 시 대상 외 영역은 흰 베일로 가라앉힌다.
      if (_hasFocus && !_isFocused(r)) {
        canvas.drawPath(r.path, _dimVeil);
      }
    }

    // 4) Grooves — 경계선(섀도 + 하이라이트).
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

    // 5) 선택 강조 — 선택 조각을 살짝 띄워(lift) 입체적으로.
    const double lift = 5.0;
    final sel = selectedKey;
    if (sel != null) {
      final selPaths = data.byKey[sel] ?? const [];
      final dropShadow = Paint()
        ..color = const Color(0x4D7A4A2E)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 6);
      canvas.save();
      canvas.translate(0, 7);
      for (final r in selPaths) {
        canvas.drawPath(r.path, dropShadow);
      }
      canvas.restore();
      final selSide = Paint()..color = const Color(0xFFE07A63);
      for (final r in selPaths) {
        canvas.drawPath(r.path, selSide);
      }
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

    // 6) 포커스 경계선 — 권역/광역시 외곽을 포커스 색으로(헤일로 + 실선).
    if (_hasFocus && focusColor != null) {
      final outline = focusKey != null
          ? data.keyOutline(focusKey!)
          : data.groupOutline(focusGroup!);
      final halo = Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 5.0
        ..strokeJoin = StrokeJoin.round
        ..color = focusColor!.withValues(alpha: 0.22)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 2);
      final line = Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2.0
        ..strokeJoin = StrokeJoin.round
        ..color = focusColor!;
      canvas.drawPath(outline, halo);
      canvas.drawPath(outline, line);
    }

    canvas.restore();
  }

  @override
  bool shouldRepaint(covariant KoreaBasePainter old) =>
      old.focusGroup != focusGroup ||
      old.focusKey != focusKey ||
      old.focusColor != focusColor ||
      old.selectedKey != selectedKey ||
      !identical(old.counts, counts) ||
      old.scale != scale ||
      old.dx != dx ||
      old.dy != dy;
}

/// 라벨 전용 화면 좌표 레이어. InteractiveViewer **바깥**에 얹혀, 변환 행렬을 읽어
/// 각 라벨의 화면 위치를 직접 계산하고 **상수 크기**로 그린다. 그래서 확대하면
/// 지역은 벌어지지만 글자는 커지지 않아 밀집 지역이 분리되어 읽힌다.
///
/// 성능: ① 화면 밖 라벨은 컬링, ② TextPainter 는 키별 1회만 layout 후 캐시,
/// ③ 제스처 중([interacting])엔 주요 라벨만 그려 프레임을 가볍게 유지.
class KoreaLabelPainter extends CustomPainter {
  KoreaLabelPainter({
    required this.data,
    required this.counts,
    required this.scale,
    required this.dx,
    required this.dy,
    required this.transform,
    this.selectedKey,
    this.focusGroup,
    this.focusKey,
    this.interacting = false,
  }) : super(repaint: transform);

  final KoreaMapData data;
  final Map<String, int> counts;
  final double scale;
  final double dx;
  final double dy;

  /// InteractiveViewer 의 현재 변환(child→screen).
  final ValueListenable<Matrix4> transform;

  final String? selectedKey;
  final String? focusGroup;
  final String? focusKey;
  final bool interacting;

  /// 키별 [stroke, fill] TextPainter 캐시. 스타일은 인스턴스 내 키마다 고정.
  final Map<String, List<TextPainter>> _cache = {};

  @override
  void paint(Canvas canvas, Size size) {
    final m = transform.value;
    final zoom = m.getMaxScaleOnAxis();
    final viewport = (Offset.zero & size).inflate(48);
    final double minSpacingFont = _minLabelFontForZoom(zoom);
    // 확대하면 글씨도 커지되 지도보다 천천히(√zoom, 상한 2.6배) → 밀집 지역은
    // 지역이 더 빨리 벌어져 글자가 분리되면서도, 줌인하면 글씨가 커져 읽기 쉽다.
    final double growth = math.sqrt(zoom).clamp(1.0, 2.6).toDouble();

    data.keyCenter.forEach((key, vc) {
      // viewBox 중심 → child 좌표(fit) → 화면 좌표(변환 적용).
      final child = Offset(vc.dx * scale + dx, vc.dy * scale + dy);
      final sp = MatrixUtils.transformPoint(m, child);
      if (!viewport.contains(sp)) return; // 화면 밖 컬링

      final metro = data.keyMetro[key] == true;
      final count = counts[key] ?? 0;
      final colored = count >= (metro ? 10 : 1);
      final isSel = key == selectedKey;
      final spacingFont = data.keyLabelSize[key] ?? 8.0;
      final major = metro || colored || isSel || spacingFont >= 9.5;

      // 줌 레벨 LOD: 한산한(큰 폰트) 라벨부터, 확대할수록 촘촘한 것까지.
      if (!(metro || colored || isSel) && spacingFont < minSpacingFont) return;
      // 제스처 중에는 주요 라벨만 → 프레임 경량화.
      if (interacting && !major) return;

      final focused = focusKey != null
          ? key == focusKey
          : (focusGroup != null ? data.keyGroup[key] == focusGroup : true);

      _drawLabel(canvas, key, data.keyShortLabel[key] ?? key, sp, growth,
          colored || isSel, spacingFont, !focused);
    });
  }

  /// 현재 줌에서 표시할 라벨의 최소 간격-폰트. 0 이면 전부 표시.
  double _minLabelFontForZoom(double z) {
    if (z >= 4.5) return 0;
    if (z >= 3.0) return 6.5;
    if (z >= 2.2) return 7.5;
    if (z >= 1.6) return 8.5;
    if (z >= 1.25) return 9.5;
    return 10.0;
  }

  void _drawLabel(
    Canvas canvas,
    String key,
    String text,
    Offset screenCenter,
    double growth,
    bool onCoral,
    double spacingFont,
    bool dimmed,
  ) {
    var pair = _cache[key];
    if (pair == null) {
      final double op = dimmed ? 0.34 : 1.0;
      // 기준 화면 크기 — fit 스케일 반영 후 가독 범위로 클램프. 줌 성장(growth)은
      // layout 비용 없이 캔버스 스케일로 적용(아래)하므로 캐시는 키별 1회만.
      final double fontSize = (spacingFont * scale).clamp(8.5, 16.0).toDouble();
      final Color fill = (onCoral ? Colors.white : const Color(0xFF453A2C))
          .withValues(alpha: op);
      final Color outline =
          (onCoral ? const Color(0xFFB23A2C) : const Color(0xFFFBF6EC))
              .withValues(alpha: op);
      final double strokeW = (fontSize * 0.28).clamp(1.6, 4.0);

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
      _cache[key] = pair;
    }

    final strokePainter = pair[0];
    final fillPainter = pair[1];
    // 중심을 기준으로 growth 배 확대해 그린다(캐시된 레이아웃 재사용 → 비용 없음).
    final pos =
        Offset(-strokePainter.width / 2, -strokePainter.height / 2);
    canvas.save();
    canvas.translate(screenCenter.dx, screenCenter.dy);
    if (growth != 1.0) canvas.scale(growth);
    strokePainter.paint(canvas, pos);
    fillPainter.paint(canvas, pos);
    canvas.restore();
  }

  @override
  bool shouldRepaint(covariant KoreaLabelPainter old) =>
      old.selectedKey != selectedKey ||
      old.focusGroup != focusGroup ||
      old.focusKey != focusKey ||
      old.interacting != interacting ||
      !identical(old.counts, counts) ||
      old.scale != scale ||
      old.dx != dx ||
      old.dy != dy;
}
