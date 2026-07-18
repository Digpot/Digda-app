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
    this.focusColor,
  });

  final KoreaMapData data;

  /// 색칠 키 → 일기 수.
  final Map<String, int> counts;

  /// 모든 시·군·구가 채워진 도(버킷) — 도 정복 칭호용(색칠엔 쓰지 않음).
  final Set<String> completedGroups;

  /// 일부만 채워진 도(버킷) — 진행률 집계용.
  final Set<String> partialGroups;

  final double scale;
  final double dx;
  final double dy;

  /// 선택된 탭 버킷(광역시/경기북부/강원/…). 지정 시 그 버킷만 또렷하고 나머지는 디밍.
  final String? focusGroup;

  /// 포커스 버킷의 시그니처 색 — 그 도 경계선을 이 색으로 그린다.
  final Color? focusColor;

  /// 비포커스 권역을 가라앉히는 슬레이트 베일.
  final Paint _dimVeil = Paint()..color = const Color(0xCCEFF2F7);

  @override
  void paint(Canvas canvas, Size size) {
    // 배경은 깔끔한 흰 카드 그대로 둔다 — 슬레이트(푸른빛) 비네트를 깔았더니
    // 지도 전체가 탁해 보인다는 피드백으로 제거(2026-07-17).
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

    // 0) 북한 "업데이트 예정" 레이어 — 무조건 맨 뒤(가장 먼저)에 그린다.
    final nk = data.northKorea;
    if (nk != null) _paintNorthKorea(canvas, nk, warmShader);

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

    // 3) Top faces — 조각(시·군) 개별 색칠. 시·군은 1회만 써도 코랄, 광역시는 10회.
    //    (도 전체를 다 채워야 칠해지던 버킷 색칠 제거 — 남원만 채우면 남원만 칠해진다.)
    final warmPaint = Paint()..shader = warmShader;
    final coralPaint = Paint()..shader = coralShader;
    final softPaint = Paint()..color = KoreaMapTokens.coralSoft;
    // 채색(코랄) 조각 전용 웜 글로스 — 좌상단에서 내려오는 옅은 흰 광택으로
    // 채운 지역이 도자기처럼 반질하게 떠 보인다(전역 1개 공유, 한색 아님).
    final coralGloss = Paint()
      ..shader = ui.Gradient.linear(
        Offset(w * 0.35, 0),
        Offset(w * 0.55, h * 0.85),
        const [Color(0x40FFFFFF), Color(0x00FFFFFF)],
        const [0.0, 0.65],
      );
    for (final r in data.regions) {
      final count = counts[r.key] ?? 0;
      final metro = data.keyMetro[r.key] == true;
      final threshold = metro ? 10 : 1;
      final achieved = count >= threshold;
      final Paint p;
      if (achieved) {
        p = coralPaint; // 달성 → 코랄
      } else if (count > 0) {
        p = softPaint; // 진행 중(광역시 1~9) → 소프트
      } else {
        p = warmPaint; // 미시작 → 웜
      }
      canvas.drawPath(r.path, p);
      if (achieved) canvas.drawPath(r.path, coralGloss);
      // 탭 포커스 시 다른 버킷은 아이보리 베일로 덮어 가라앉힌다.
      if (focusGroup != null && data.keyFocusGroup[r.key] != focusGroup) {
        canvas.drawPath(r.path, _dimVeil);
      }
    }

    // 4) Grooves — 경계선. 은은한 하이라이트를 먼저 깔고, 또렷한 슬레이트 선을
    //    위에 더 굵게 올려 안 채운 지역끼리도 경계가 분명히 보이게 한다.
    final grooveHi = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 0.5
      ..color = KoreaMapTokens.grooveHi;
    final grooveLo = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.0
      ..color = KoreaMapTokens.grooveLo;
    for (final r in data.regions) {
      canvas.drawPath(r.path, grooveHi);
      canvas.drawPath(r.path, grooveLo);
    }

    // 5) 포커스 경계선 — 선택한 도(버킷)의 외곽을 시그니처 색으로(헤일로 + 실선).
    final fg = focusGroup;
    final fc = focusColor;
    if (fg != null && fc != null) {
      final outline = data.focusGroupOutline(fg);
      final halo = Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 5.0
        ..strokeJoin = StrokeJoin.round
        ..color = fc.withValues(alpha: 0.22)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 2);
      final line = Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2.2
        ..strokeJoin = StrokeJoin.round
        ..color = fc;
      canvas.drawPath(outline, halo);
      canvas.drawPath(outline, line);
    }

    canvas.restore();
  }

  /// 북한 장식 레이어 — 남한과 같은 점토 톤이되 살짝 가라앉혀(예정) 그리고,
  /// 시·군 느낌의 분할선을 실루엣에 클립해 올린 뒤 "업데이트 예정" 배지를 항상 띄운다.
  void _paintNorthKorea(Canvas canvas, NorthKoreaLayer nk, ui.Gradient warm) {
    // ambient
    canvas.save();
    canvas.translate(0, 12);
    canvas.drawPath(
      nk.outline,
      Paint()
        ..color = KoreaMapTokens.ambientShadow
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 6),
    );
    canvas.restore();
    // side wall(두께)
    canvas.save();
    canvas.translate(0, 7);
    canvas.drawPath(nk.outline, Paint()..color = KoreaMapTokens.sideWall);
    canvas.restore();
    // top face — 남한과 같은 웜 베이스 위에 안개 낀 듯한 흰 베일을 얹어
    // "아직 잠긴 땅" 분위기를 만든다.
    canvas.drawPath(nk.outline, Paint()..shader = warm);
    final bounds = nk.bounds;
    canvas.drawPath(
      nk.outline,
      Paint()
        ..shader = ui.Gradient.linear(
          bounds.topCenter,
          bounds.bottomCenter,
          const [Color(0x8CFFFFFF), Color(0x33FFFFFF)],
        ),
    );
    // 시·군 분할선 — 실루엣 안쪽으로만.
    final grooveHi = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 0.5
      ..color = KoreaMapTokens.grooveHi;
    final grooveLo = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.0
      ..color = KoreaMapTokens.grooveLo;
    canvas.save();
    canvas.clipPath(nk.outline);
    for (final d in nk.dividers) {
      canvas.drawPath(d, grooveHi);
      canvas.drawPath(d, grooveLo);
    }
    // 사선 해치 — "준비 중 구역" 시그널. 푸른빛 대신 웜 그레이로 은은하게.
    final hatch = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.4
      ..color = const Color(0x26A29488);
    final span = bounds.width + bounds.height;
    for (double o = 0; o < span; o += 30) {
      canvas.drawLine(
        Offset(bounds.left + o, bounds.top),
        Offset(bounds.left, bounds.top + o),
        hatch,
      );
    }
    canvas.restore();
    // 외곽선
    canvas.drawPath(nk.outline, grooveLo);
    // "업데이트 예정" 배지 — 무조건 노출.
    _paintPendingBadge(canvas, nk.labelCenter);
  }

  void _paintPendingBadge(Canvas canvas, Offset center) {
    const text = '업데이트 예정';
    final tp = TextPainter(
      text: const TextSpan(
        text: text,
        style: TextStyle(
          fontFamily: 'Inter',
          fontSize: 21,
          fontWeight: FontWeight.w800,
          height: 1.0,
          letterSpacing: 0.5,
          color: Color(0xFF64748B),
        ),
      ),
      textDirection: TextDirection.ltr,
    )..layout();
    // 자물쇠 점 아이콘 자리(원) + 텍스트를 담는 알약.
    const dotR = 10.0;
    const gap = 9.0;
    const padH = 17.0;
    const padV = 11.0;
    final contentW = dotR * 2 + gap + tp.width;
    final rect = Rect.fromCenter(
      center: center,
      width: contentW + padH * 2,
      height: tp.height + padV * 2,
    );
    final rrect = RRect.fromRectAndRadius(rect, const Radius.circular(24));
    // 그림자 + 흰 알약(위→아래로 아주 옅은 슬레이트 그라디언트)
    canvas.drawRRect(
      rrect.shift(const Offset(0, 3)),
      Paint()
        ..color = const Color(0x26000000)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 5),
    );
    canvas.drawRRect(
      rrect,
      Paint()
        ..shader = ui.Gradient.linear(
          rect.topCenter,
          rect.bottomCenter,
          const [Colors.white, Color(0xFFF2F5F9)],
        ),
    );
    canvas.drawRRect(
      rrect,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.2
        ..color = const Color(0xFFD7DEE8),
    );
    // 자물쇠 느낌의 슬레이트 점 + 흰 열쇠구멍.
    final dotC = Offset(rect.left + padH + dotR, center.dy);
    canvas.drawCircle(
      dotC,
      dotR,
      Paint()
        ..shader = ui.Gradient.linear(
          dotC.translate(0, -dotR),
          dotC.translate(0, dotR),
          const [Color(0xFFAFBCCC), Color(0xFF8D9EB8)],
        ),
    );
    canvas.drawCircle(
        dotC.translate(0, -1.5), 2.2, Paint()..color = Colors.white);
    canvas.drawRect(
      Rect.fromCenter(
          center: dotC.translate(0, 1.8), width: 2.4, height: 4.6),
      Paint()..color = Colors.white,
    );
    tp.paint(
      canvas,
      Offset(rect.left + padH + dotR * 2 + gap, center.dy - tp.height / 2),
    );
  }

  @override
  bool shouldRepaint(covariant KoreaBasePainter old) =>
      old.focusGroup != focusGroup ||
      old.focusColor != focusColor ||
      !identical(old.counts, counts) ||
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

    // 라벨 — 시·군 글자는 띄우지 않고 "도 단위"로만(전북/강원/경기북부/서울…).
    // 화면 밖이면 컬링. 포커스 시 다른 도 라벨은 흐리게.
    for (final entry in data.labelGroupCenter.entries) {
      final g = entry.key;
      final center = entry.value;
      if (visible != null && !visible.contains(center)) continue;
      final dimmed =
          focusGroup != null && data.labelGroupToFocus[g] != focusGroup;
      _drawLabel(canvas, g, g, center, false, 12.0, dimmed);
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
          (onCoral ? Colors.white : const Color(0xFF334155))
              .withValues(alpha: op);
      final Color outline =
          (onCoral ? const Color(0xFFB23A2C) : const Color(0xFFF1F4F9))
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
