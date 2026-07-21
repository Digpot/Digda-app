import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../core/ads/ad_service.dart';
import '../../widgets/ad_banner.dart';

/// 탐험 기념품 도감 상태(반짝이 도장) — 세션 동안 유지되는 인메모리 저장소.
///
/// 탐험 명소를 방문하면 그 명소의 "기념품 스탬프"를 도감에 모으고, 리워드 광고를
/// 보면 그 스탬프를 **반짝이 도장(shiny)** 으로 승급시킬 수 있다. 반짝이 여부는
/// 서버 재화가 아니라 순수 장식이라 클라 인메모리로만 들고 있는다.
class ExploreCollection {
  ExploreCollection._();

  static final Set<String> _shiny = <String>{};

  /// `'jungle:temple'` 처럼 (탐험지키:명소id) 로 반짝임 여부를 조회한다.
  static bool isShiny(String key) => _shiny.contains(key);

  static void markShiny(String key) => _shiny.add(key);

  /// 세 탐험을 통틀어 지금까지 얻은 반짝이 도장 수.
  static int get shinyCount => _shiny.length;
}

/// 명소 상세 시트 하단에 공통으로 붙는 "기념품 획득 + 리워드/배너 광고" 블록.
///
/// 정글·우주·해저 세 탐험이 모두 같은 모양의 상세 바텀시트를 쓰므로, 보상 연출과
/// 광고 배치를 한 위젯으로 모아 세 화면이 동일한 경험을 갖게 했다. 각 화면은
/// 자기 테마색([accent])·탐험지 이모지([realmEmoji])·수집 진행도만 넘긴다.
class ExploreSpotExtras extends StatefulWidget {
  const ExploreSpotExtras({
    super.key,
    required this.realmKey,
    required this.realmEmoji,
    required this.spotId,
    required this.spotName,
    required this.accent,
    required this.collected,
    required this.total,
  });

  /// 탐험지 식별자 — 반짝임 저장 키 접두어. 예: `'jungle'`.
  final String realmKey;

  /// 탐험지 대표 이모지 — 스탬프 중앙에 찍힌다. 예: `'🌿'`.
  final String realmEmoji;

  /// 명소 식별자 — 반짝임 저장 키. 예: `'temple'`.
  final String spotId;

  /// 명소 이름 — 스탬프 라벨.
  final String spotName;

  /// 테마 강조색(명소 glow).
  final Color accent;

  /// 지금까지 방문(수집)한 명소 수(현재 명소 포함).
  final int collected;

  /// 탐험지 전체 명소 수.
  final int total;

  @override
  State<ExploreSpotExtras> createState() => _ExploreSpotExtrasState();
}

class _ExploreSpotExtrasState extends State<ExploreSpotExtras>
    with SingleTickerProviderStateMixin {
  late final AnimationController _revealCtrl;
  bool _watching = false;
  bool _adFailed = false;

  String get _shinyKey => '${widget.realmKey}:${widget.spotId}';
  bool get _shiny => ExploreCollection.isShiny(_shinyKey);

  @override
  void initState() {
    super.initState();
    _revealCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 720),
    )..forward();
  }

  @override
  void dispose() {
    _revealCtrl.dispose();
    super.dispose();
  }

  Future<void> _watchBonusAd() async {
    if (_watching || _shiny) return;
    setState(() {
      _watching = true;
      _adFailed = false;
    });
    final earned = await AdService.showRewarded();
    if (!mounted) return;
    if (earned) {
      ExploreCollection.markShiny(_shinyKey);
      // 스탬프가 다시 반짝이며 등장하도록 리빌 애니메이션을 재생한다.
      _revealCtrl
        ..reset()
        ..forward();
    }
    setState(() {
      _watching = false;
      _adFailed = !earned;
    });
  }

  @override
  Widget build(BuildContext context) {
    final accent = widget.accent;
    final progress =
        widget.total == 0 ? 0.0 : (widget.collected / widget.total).clamp(0, 1);
    final complete = widget.collected >= widget.total;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // ── 기념품 스탬프 카드 ─────────────────────────────────────────
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(18),
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                accent.withValues(alpha: 0.16),
                accent.withValues(alpha: 0.05),
              ],
            ),
            border: Border.all(color: accent.withValues(alpha: 0.4)),
          ),
          child: Row(
            children: [
              // 스탬프 — 등장 시 튕기며 나타나고, 반짝임이면 스파클이 돈다.
              AnimatedBuilder(
                animation: _revealCtrl,
                builder: (_, child) {
                  final v = Curves.elasticOut.transform(
                      _revealCtrl.value.clamp(0.0, 1.0));
                  return Transform.rotate(
                    angle: (1 - v) * -0.5,
                    child: Transform.scale(scale: 0.3 + v * 0.7, child: child),
                  );
                },
                child: SizedBox(
                  width: 76,
                  height: 76,
                  child: CustomPaint(
                    painter: _StampPainter(
                      accent: accent,
                      shiny: _shiny,
                    ),
                    child: Center(
                      child: Text(widget.realmEmoji,
                          style: const TextStyle(fontSize: 30)),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Text(
                          _shiny ? '반짝이 기념품 획득!' : '기념품을 획득했어요!',
                          style: TextStyle(
                            fontFamily: 'Inter',
                            fontWeight: FontWeight.w800,
                            fontSize: 14.5,
                            color: accent,
                          ),
                        ),
                        if (_shiny) ...[
                          const SizedBox(width: 4),
                          const Text('✨', style: TextStyle(fontSize: 13)),
                        ],
                      ],
                    ),
                    const SizedBox(height: 2),
                    Text(
                      '${widget.spotName} 스탬프',
                      style: const TextStyle(
                        fontFamily: 'Inter',
                        fontWeight: FontWeight.w700,
                        fontSize: 13,
                        color: Colors.white,
                      ),
                    ),
                    const SizedBox(height: 10),
                    // 도감 진행도.
                    Row(
                      children: [
                        Text(
                          complete ? '탐험 도감 완성' : '탐험 도감',
                          style: TextStyle(
                            fontFamily: 'Inter',
                            fontWeight: FontWeight.w600,
                            fontSize: 11,
                            color: Colors.white.withValues(alpha: 0.7),
                          ),
                        ),
                        const Spacer(),
                        Text(
                          '${widget.collected}/${widget.total}',
                          style: TextStyle(
                            fontFamily: 'Inter',
                            fontWeight: FontWeight.w800,
                            fontSize: 11.5,
                            color: complete ? const Color(0xFFFCD34D) : accent,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 5),
                    ClipRRect(
                      borderRadius: BorderRadius.circular(999),
                      child: LinearProgressIndicator(
                        value: progress.toDouble(),
                        minHeight: 6,
                        backgroundColor: Colors.white.withValues(alpha: 0.12),
                        valueColor: AlwaysStoppedAnimation(
                            complete ? const Color(0xFFFCD34D) : accent),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 10),
        // ── 리워드 광고 보너스 ─────────────────────────────────────────
        _buildBonus(accent),
        const SizedBox(height: 6),
        // ── 배너 광고 ─────────────────────────────────────────────────
        const AdBanner(padding: EdgeInsets.only(top: 6, bottom: 2)),
      ],
    );
  }

  Widget _buildBonus(Color accent) {
    if (_shiny) {
      return Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(vertical: 12),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(14),
          color: Colors.white.withValues(alpha: 0.06),
          border: Border.all(color: Colors.white.withValues(alpha: 0.10)),
        ),
        child: Center(
          child: Text(
            '✨ 반짝이 도장을 이미 찍었어요',
            style: TextStyle(
              fontFamily: 'Inter',
              fontWeight: FontWeight.w700,
              fontSize: 13,
              color: Colors.white.withValues(alpha: 0.75),
            ),
          ),
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        SizedBox(
          height: 52,
          child: ElevatedButton(
            onPressed: _watching ? null : _watchBonusAd,
            style: ElevatedButton.styleFrom(
              backgroundColor: accent,
              disabledBackgroundColor: accent.withValues(alpha: 0.4),
              foregroundColor: Colors.black.withValues(alpha: 0.85),
              elevation: 0,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(14),
              ),
            ),
            // 좁은 화면에서도 넘치지 않도록 라벨 전체를 축소 맞춤한다.
            child: FittedBox(
              fit: BoxFit.scaleDown,
              child: _watching
                  ? const Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(
                            strokeWidth: 2.2,
                            color: Colors.black54,
                          ),
                        ),
                        SizedBox(width: 10),
                        Text(
                          '광고 불러오는 중...',
                          style: TextStyle(
                            fontFamily: 'Inter',
                            fontWeight: FontWeight.w800,
                            fontSize: 14.5,
                            color: Colors.black87,
                          ),
                        ),
                      ],
                    )
                  : Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Text('✨', style: TextStyle(fontSize: 16)),
                        const SizedBox(width: 8),
                        const Text(
                          '광고 보고 반짝이 도장 찍기',
                          style: TextStyle(
                            fontFamily: 'Inter',
                            fontWeight: FontWeight.w800,
                            fontSize: 14.5,
                          ),
                        ),
                        const SizedBox(width: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 7, vertical: 2),
                          decoration: BoxDecoration(
                            color: Colors.black.withValues(alpha: 0.16),
                            borderRadius: BorderRadius.circular(999),
                          ),
                          child: const Text(
                            '리워드',
                            style: TextStyle(
                              fontFamily: 'Inter',
                              fontWeight: FontWeight.w800,
                              fontSize: 10,
                            ),
                          ),
                        ),
                      ],
                    ),
            ),
          ),
        ),
        if (_adFailed)
          Padding(
            padding: const EdgeInsets.only(top: 8),
            child: Text(
              '광고를 불러오지 못했어요. 잠시 후 다시 시도해주세요.',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontFamily: 'Inter',
                fontWeight: FontWeight.w500,
                fontSize: 11.5,
                color: Colors.white.withValues(alpha: 0.55),
              ),
            ),
          ),
      ],
    );
  }
}

/// 기념품 스탬프 배경 — 이중 링(여권 도장 느낌) + 반짝임이면 회전 스파클.
class _StampPainter extends CustomPainter {
  _StampPainter({required this.accent, required this.shiny});

  final Color accent;
  final bool shiny;

  @override
  void paint(Canvas canvas, Size size) {
    final c = Offset(size.width / 2, size.height / 2);
    final r = size.width / 2;

    // 채워진 원판.
    canvas.drawCircle(
      c,
      r - 2,
      Paint()
        ..shader = RadialGradient(
          colors: [
            accent.withValues(alpha: shiny ? 0.42 : 0.28),
            accent.withValues(alpha: 0.10),
          ],
        ).createShader(Rect.fromCircle(center: c, radius: r)),
    );

    // 이중 링.
    canvas.drawCircle(
      c,
      r - 3,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2
        ..color = accent.withValues(alpha: 0.9),
    );
    canvas.drawCircle(
      c,
      r - 8,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1
        ..color = accent.withValues(alpha: 0.5),
    );

    if (shiny) {
      // 4방향 스파클 — 반짝이 도장 표식.
      final spark = Paint()
        ..color = const Color(0xFFFDE68A)
        ..strokeWidth = 2
        ..strokeCap = StrokeCap.round;
      for (var i = 0; i < 4; i++) {
        final a = i * math.pi / 2 + math.pi / 4;
        final p = c + Offset(math.cos(a), math.sin(a)) * (r - 6);
        canvas.drawLine(p + const Offset(-3, 0), p + const Offset(3, 0), spark);
        canvas.drawLine(p + const Offset(0, -3), p + const Offset(0, 3), spark);
      }
    }
  }

  @override
  bool shouldRepaint(_StampPainter old) =>
      old.accent != accent || old.shiny != shiny;
}
