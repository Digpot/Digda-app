import 'dart:io';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import '../theme/colors.dart';

/// 그림일기 화면(작성/수정/조회) 공용 디자인 시스템.
///
/// 메인 앱(캘린더·그룹 리스트·일정 상세) 의 화이트+그레이 토큰을 그대로 가져와
/// 같은 시스템을 공유한다. 베이지·브라운 같은 별도 종이 팔레트는 일관성을
/// 깼던 원인이라 제거. 공책 정체성은 줄(ruledLine) + 옅은 카드 보더로만 표현.
class DiaryStyle {
  DiaryStyle._();

  // ── 페이지/카드 ──────────────────────────────────────────────
  /// 페이지 배경 — 메인 앱과 동일한 화이트
  static const Color pageBg = AppColors.white;

  /// 카드 배경 — 화이트
  static const Color cardBg = AppColors.white;

  /// 카드 외곽선 — 메인 앱 공통 옅은 보더
  static const Color cardBorder = AppColors.gray100;

  /// 카드 그림자 — 사용하지 않는다. 메인 앱이 그림자 없는 플랫 보더 카드.
  /// (남겨두면 기존 코드 호환을 위해 transparent 로)
  static const Color cardShadow = Color(0x00000000);

  // ── 강조/포인트 ──────────────────────────────────────────────
  /// 메인 핑크 (primary 와 통일)
  static const Color accent = AppColors.primary;

  /// 옅은 핑크 — 칩/뱃지 배경
  static const Color accentSoft = Color(0xFFFFEDED);

  /// 섹션 라벨 톤 — 메인 앱 보조 텍스트와 동일.
  /// (예전 baseline 인 brown 베이지를 대체. 이름은 호환을 위해 유지)
  static const Color labelBrown = AppColors.gray500;

  // ── 텍스트 ──────────────────────────────────────────────────
  /// 본문 텍스트 — 메인 앱 기본 텍스트
  static const Color textPrimary = AppColors.gray900;

  /// 보조 텍스트
  static const Color textSecondary = AppColors.gray500;

  /// 옅은 텍스트(플레이스홀더)
  static const Color textPlaceholder = AppColors.gray400;

  // ── 줄공책 ──────────────────────────────────────────────────
  /// 줄공책 베이스라인 색 — 베이지 대신 옅은 그레이로 모던하게.
  static const Color ruledLine = AppColors.gray100;

  /// 입력 한 줄 높이(px) — fontSize × lineHeight 와 정확히 같아야
  /// 베이스라인과 캐럿이 어긋나지 않는다. (15 × 2.933 ≒ 44)
  static const double rowHeight = 44.0;

  /// 본문 글꼴 크기
  static const double contentFontSize = 15;

  /// 본문 line-height factor (rowHeight / contentFontSize)
  static const double contentLineHeight = rowHeight / contentFontSize;

  /// 첫 번째 underline 의 y 위치. 행 맨 아래(44) 가 아니라 계산된
  /// 1행 baseline 살짝 아래에 두어, 공책처럼 텍스트가 줄 위에 자연스럽게
  /// 앉도록 한다.
  ///
  /// Inter 15px × strut height 2.933 / leadingDistribution=even 기준:
  ///   - 행 박스 44 안에서 half-leading ≈ 13, ascent ≈ 14.4
  ///   - 1행 baseline ≈ 13 + 14.4 = 27.4
  ///   - Inter descent ≈ 3.5
  ///   - 한글 fallback(Noto Sans CJK) descent 추가 여유까지 포함해
  ///     baseline 아래 6~7px 에 줄을 그으면 descender 가 줄에 가볍게 닿는
  ///     공책 룩이면서 어떤 fallback 글꼴이 와도 줄을 뚫지 않는다.
  /// 후속 줄은 [rowHeight] 간격으로 그린다.
  static const double firstLineY = 34.0;

  // ── 라운드/간격 ──────────────────────────────────────────────
  /// 메인 앱 radiusLarge(16) 와 통일.
  static const double cardRadius = 16;

  /// 메인 앱 spacing12 와 통일.
  static const double sectionGap = 12;

  /// 메인 앱 가로 패딩 20 과 통일.
  static const double pagePadding = 20;
}

/// 날씨 옵션 — 작성/수정/조회 공통
const List<DiaryWeatherOption> diaryWeatherOptions = [
  DiaryWeatherOption(
    icon: Icons.wb_sunny_rounded,
    label: '맑음',
    color: Color(0xFFFBBF24),
    emoji: '☀️',
  ),
  DiaryWeatherOption(
    icon: Icons.wb_cloudy_rounded,
    label: '구름',
    color: AppColors.gray400,
    emoji: '⛅',
  ),
  DiaryWeatherOption(
    icon: Icons.grain_rounded,
    label: '비',
    color: AppColors.blue,
    emoji: '🌧',
  ),
  DiaryWeatherOption(
    icon: Icons.ac_unit_rounded,
    label: '눈',
    color: AppColors.saturdayBlue,
    emoji: '❄️',
  ),
];

class DiaryWeatherOption {
  const DiaryWeatherOption({
    required this.icon,
    required this.label,
    required this.color,
    required this.emoji,
  });
  final IconData icon;
  final String label;
  final Color color;
  final String emoji;
}

/// 기분 옵션 — emoji + label (서버 mood 인덱스 0..4)
const List<DiaryMoodOption> diaryMoodOptions = [
  DiaryMoodOption(emoji: '😊', label: '행복'),
  DiaryMoodOption(emoji: '😌', label: '평온'),
  DiaryMoodOption(emoji: '😔', label: '슬픔'),
  DiaryMoodOption(emoji: '😤', label: '화남'),
  DiaryMoodOption(emoji: '🥱', label: '피곤'),
];

class DiaryMoodOption {
  const DiaryMoodOption({required this.emoji, required this.label});
  final String emoji;
  final String label;
}

DiaryWeatherOption diaryWeatherOf(int index) {
  if (index < 0 || index >= diaryWeatherOptions.length) {
    return diaryWeatherOptions[0];
  }
  return diaryWeatherOptions[index];
}

DiaryMoodOption diaryMoodOf(int index) {
  if (index < 0 || index >= diaryMoodOptions.length) {
    return diaryMoodOptions[0];
  }
  return diaryMoodOptions[index];
}

/// 한국식 날짜 표기: "2024년 9월 19일 (목)"
String formatDiaryDate(DateTime d) {
  const weekdays = ['월', '화', '수', '목', '금', '토', '일'];
  return '${d.year}년 ${d.month}월 ${d.day}일 (${weekdays[d.weekday - 1]})';
}

/// 작성 시각 표기: "2024.09.19 오후 6:30"
String formatDiaryTimestamp(DateTime t) {
  final local = t.toLocal();
  final h = local.hour;
  final period = h < 12 ? '오전' : '오후';
  final hour12 = h == 0 ? 12 : (h > 12 ? h - 12 : h);
  return '${local.year}.${local.month.toString().padLeft(2, '0')}.${local.day.toString().padLeft(2, '0')} '
      '$period $hour12:${local.minute.toString().padLeft(2, '0')}';
}

/// 본문 줄공책 텍스트의 공용 TextStyle / StrutStyle.
///
/// `_RuledText` / `_RuledTextField` / 측정용 TextPainter 가 동일한 메트릭을
/// 공유해야 줄 위치가 어긋나지 않는다. 한 곳에서만 정의한다.
const TextStyle diaryContentTextStyle = TextStyle(
  fontFamily: 'Inter',
  fontWeight: FontWeight.w400,
  fontSize: DiaryStyle.contentFontSize,
  height: DiaryStyle.contentLineHeight,
  color: DiaryStyle.textPrimary,
);

const StrutStyle diaryContentStrutStyle = StrutStyle(
  fontFamily: 'Inter',
  fontSize: DiaryStyle.contentFontSize,
  height: DiaryStyle.contentLineHeight,
  forceStrutHeight: true,
  leading: 0,
  leadingDistribution: TextLeadingDistribution.even,
);

/// 줄공책 컨테이너. 자식 위젯(읽기 전용 [Text] 또는 [TextField]) 의
/// 실제 줄 baseline 을 런타임에 측정해서 정확히 그 자리에 가로줄을 그어준다.
///
/// **고정 픽셀 오프셋(firstLineY 같은 상수) 으로 줄을 그리던 이전 구조의 문제**
///   - 글꼴 fallback (한글 Noto Sans CJK 등) 마다 실제 baseline 위치가 다름
///   - Android 버전·이모지 폰트·OEM 폰트 메트릭 차이로 한 환경에서 맞춰도 다른
///     환경에서 깨짐
///   - 행마다 누적 오차가 생겨 multi-line 입력 시 줄을 뚫는 케이스 발생
///
/// **이 위젯의 동작**
///   1. [LayoutBuilder] 로 현재 가용 가로폭을 얻고
///   2. 동일한 `TextStyle`/`StrutStyle` 로 [TextPainter] 를 만든 뒤 측정용 텍스트를
///      레이아웃해 [TextPainter.computeLineMetrics] 로 각 줄의 실측 baseline 을 받음
///   3. 측정된 baseline 마다 descent + 안전 마진(`_kBaselineToLineGap`) 아래에 줄을 그어,
///      텍스트가 자연스럽게 줄 위에 앉도록 함
///   4. 내용이 짧을 때도 공책 룩을 유지하려고 [minRows] 까지 행 간격으로 외삽
///
/// TextField 사용처는 [textForMeasure] 에 컨트롤러 텍스트를 매 빌드마다 흘려넣고
/// controller 의 [TextEditingController.addListener] 로 setState 를 트리거해야 한다.
class RuledContentBox extends StatelessWidget {
  const RuledContentBox({
    super.key,
    required this.child,
    required this.textForMeasure,
    this.minRows = 8,
    this.lineColor = DiaryStyle.ruledLine,
  });

  /// 본문을 그릴 위젯 — `Text(...)` 또는 `TextField(...)`.
  final Widget child;

  /// 줄 위치 측정을 위해 [TextPainter] 에 흘려넣는 텍스트.
  /// 읽기 전용은 본문 그대로, 편집은 controller.text 를 그대로 넘긴다.
  final String textForMeasure;

  /// 빈 영역도 공책 룩으로 보이게 최소로 그릴 줄 수.
  final int minRows;

  /// 줄 색상.
  final Color lineColor;

  /// 측정된 baseline 으로부터 줄을 얼마나 아래에 그을지(px).
  /// Inter descent (≈ 3.5) + 한글 fallback descent 여유까지 포함해 보수적으로 7px.
  static const double _kBaselineToLineGap = 7.0;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final width = constraints.maxWidth;
        // 빈 문자열이면 strut 만으로 1행이 잡히도록 공백 한 칸을 측정 텍스트로.
        final measureText = textForMeasure.isEmpty ? ' ' : textForMeasure;

        final painter = TextPainter(
          text: TextSpan(text: measureText, style: diaryContentTextStyle),
          strutStyle: diaryContentStrutStyle,
          textDirection: TextDirection.ltr,
          textHeightBehavior: const TextHeightBehavior(
            leadingDistribution: TextLeadingDistribution.even,
          ),
        )..layout(maxWidth: width);

        final metrics = painter.computeLineMetrics();
        final lineYs = <double>[
          for (final m in metrics) m.baseline + _kBaselineToLineGap,
        ];

        // 내용이 짧으면 마지막 측정 줄 위치를 기점으로 rowHeight 간격으로 외삽.
        const rowGap = DiaryStyle.rowHeight;
        var lastY = lineYs.isEmpty
            ? DiaryStyle.firstLineY - rowGap // 안전한 시작점(루프에서 +rowGap)
            : lineYs.last;
        while (lineYs.length < minRows) {
          lastY += rowGap;
          lineYs.add(lastY);
        }

        final measuredHeight = painter.height;
        final minHeight = minRows * rowGap;
        final containerMinHeight =
            measuredHeight > minHeight ? measuredHeight : minHeight;

        return ConstrainedBox(
          constraints: BoxConstraints(minHeight: containerMinHeight),
          child: Stack(
            children: [
              Positioned.fill(
                child: IgnorePointer(
                  child: CustomPaint(
                    painter: _MeasuredLinesPainter(
                      ys: lineYs,
                      color: lineColor,
                    ),
                  ),
                ),
              ),
              child,
            ],
          ),
        );
      },
    );
  }
}

class _MeasuredLinesPainter extends CustomPainter {
  _MeasuredLinesPainter({required this.ys, required this.color});

  final List<double> ys;
  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..strokeWidth = 1
      ..style = PaintingStyle.stroke;
    for (final y in ys) {
      if (y < 0 || y > size.height) continue;
      canvas.drawLine(Offset(0, y), Offset(size.width, y), paint);
    }
  }

  @override
  bool shouldRepaint(covariant _MeasuredLinesPainter old) {
    if (old.color != color) return true;
    if (old.ys.length != ys.length) return true;
    for (var i = 0; i < ys.length; i++) {
      if (old.ys[i] != ys[i]) return true;
    }
    return false;
  }
}

/// 공용 페이퍼 카드 — 작성/수정/조회 모든 섹션의 외곽 컨테이너.
class DiaryPaperCard extends StatelessWidget {
  const DiaryPaperCard({
    super.key,
    required this.child,
    this.padding,
    this.clipBehavior = Clip.antiAlias,
  });

  final Widget child;
  final EdgeInsetsGeometry? padding;
  final Clip clipBehavior;

  @override
  Widget build(BuildContext context) {
    // 메인 앱 카드와 동일한 플랫 룩: 그림자 없이 1px 보더 + 라운드.
    return Container(
      clipBehavior: clipBehavior,
      decoration: BoxDecoration(
        color: DiaryStyle.cardBg,
        borderRadius: BorderRadius.circular(DiaryStyle.cardRadius),
        border: Border.all(color: DiaryStyle.cardBorder, width: 1),
      ),
      child: padding == null ? child : Padding(padding: padding!, child: child),
    );
  }
}

/// 카드 상단의 얇은 핑크 띠 — 페이퍼 느낌의 포인트.
class DiaryCardAccentBar extends StatelessWidget {
  const DiaryCardAccentBar({super.key, this.height = 4, this.color});
  final double height;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: height,
      decoration: BoxDecoration(
        color: color ?? DiaryStyle.accent,
        borderRadius: const BorderRadius.vertical(
          top: Radius.circular(DiaryStyle.cardRadius - 1),
        ),
      ),
    );
  }
}

/// 사진 편집 시트 — 작성/수정 공용.
class DiaryImageCropSheet extends StatefulWidget {
  const DiaryImageCropSheet({
    super.key,
    required this.imageFile,
    required this.onCropped,
    required this.onReplace,
  });

  final File imageFile;
  final void Function(File) onCropped;
  final VoidCallback onReplace;

  @override
  State<DiaryImageCropSheet> createState() => _DiaryImageCropSheetState();
}

class _DiaryImageCropSheetState extends State<DiaryImageCropSheet> {
  final TransformationController _controller = TransformationController();
  final GlobalKey _repaintKey = GlobalKey();
  bool _saving = false;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _captureAndReturn() async {
    if (_saving) return;
    setState(() => _saving = true);
    try {
      final boundary = _repaintKey.currentContext!.findRenderObject()
          as RenderRepaintBoundary;
      final image = await boundary.toImage(pixelRatio: 2.0);
      final byteData = await image.toByteData(format: ui.ImageByteFormat.png);
      final bytes = byteData!.buffer.asUint8List();
      final file = File(
        '${Directory.systemTemp.path}/cropped_${DateTime.now().millisecondsSinceEpoch}.png',
      );
      await file.writeAsBytes(bytes);
      if (mounted) {
        Navigator.of(context).pop();
        widget.onCropped(file);
      }
    } catch (_) {
      if (mounted) Navigator.of(context).pop();
    }
  }

  @override
  Widget build(BuildContext context) {
    final screenHeight = MediaQuery.of(context).size.height;
    return Container(
      height: screenHeight * 0.85,
      decoration: const BoxDecoration(
        color: AppColors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: Column(
        children: [
          const SizedBox(height: 12),
          Center(
            child: Container(
              width: 36,
              height: 4,
              decoration: BoxDecoration(
                color: AppColors.gray200,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          const SizedBox(height: 16),
          const Text(
            '사진 편집',
            style: TextStyle(
              fontFamily: 'Inter',
              fontWeight: FontWeight.w700,
              fontSize: 17,
              color: AppColors.gray900,
            ),
          ),
          const SizedBox(height: 6),
          const Text(
            '핀치로 확대/축소, 드래그로 위치 조정',
            style: TextStyle(
              fontFamily: 'Inter',
              fontWeight: FontWeight.w400,
              fontSize: 13,
              color: AppColors.gray500,
            ),
          ),
          const SizedBox(height: 16),
          Expanded(
            child: Container(
              margin: const EdgeInsets.symmetric(horizontal: 16),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: AppColors.gray200),
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(16),
                child: RepaintBoundary(
                  key: _repaintKey,
                  child: InteractiveViewer(
                    transformationController: _controller,
                    minScale: 0.5,
                    maxScale: 4.0,
                    child: Image.file(
                      widget.imageFile,
                      fit: BoxFit.cover,
                      width: double.infinity,
                      height: double.infinity,
                    ),
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(height: 16),
          Padding(
            padding: EdgeInsets.fromLTRB(
              16,
              0,
              16,
              MediaQuery.of(context).padding.bottom + 16,
            ),
            child: Row(
              children: [
                Expanded(
                  child: GestureDetector(
                    onTap: widget.onReplace,
                    child: Container(
                      height: 48,
                      decoration: BoxDecoration(
                        border: Border.all(color: AppColors.gray200),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: const Center(
                        child: Text(
                          '다른 사진',
                          style: TextStyle(
                            fontFamily: 'Inter',
                            fontWeight: FontWeight.w600,
                            fontSize: 15,
                            color: AppColors.gray700,
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: GestureDetector(
                    onTap: _captureAndReturn,
                    child: Container(
                      height: 48,
                      decoration: BoxDecoration(
                        color: AppColors.primary,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Center(
                        child: _saving
                            ? const SizedBox(
                                width: 20,
                                height: 20,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  color: AppColors.white,
                                ),
                              )
                            : const Text(
                                '확인',
                                style: TextStyle(
                                  fontFamily: 'Inter',
                                  fontWeight: FontWeight.w600,
                                  fontSize: 15,
                                  color: AppColors.white,
                                ),
                              ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
