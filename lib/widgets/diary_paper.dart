import 'dart:io';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import '../theme/colors.dart';

/// 그림일기 화면(작성/수정/조회) 공용 디자인 시스템.
///
/// 한국 초등 그림일기의 정서(원고지·줄공책·아기자기함)를
/// 모던한 커플 다이어리 톤으로 재해석. 작성/수정/조회 화면이
/// 같은 카드·라벨·라인 스타일을 공유해 통일감을 유지.
class DiaryStyle {
  DiaryStyle._();

  // ── 종이/배경 ────────────────────────────────────────────────
  /// 페이지 베이스 — 따뜻한 크림 컬러
  static const Color pageBg = Color(0xFFFFFBF2);

  /// 카드 베이스
  static const Color cardBg = Color(0xFFFFFFFF);

  /// 카드 외곽선 — 옅은 베이지
  static const Color cardBorder = Color(0xFFEFE5D2);

  /// 카드 그림자 — 따뜻한 베이지 계열
  static Color cardShadow = const Color(0xFFB89F73).withValues(alpha: 0.08);

  // ── 강조/포인트 ──────────────────────────────────────────────
  /// 메인 핑크 (primary 와 통일)
  static const Color accent = AppColors.primary;

  /// 옅은 핑크 — 헤더 띠/뱃지 배경
  static const Color accentSoft = Color(0xFFFFEDED);

  /// 헤더 라벨 톤(은은한 브라운)
  static const Color labelBrown = Color(0xFFB8A07A);

  // ── 텍스트 ──────────────────────────────────────────────────
  /// 본문 텍스트 — 약간 따뜻한 다크 그레이
  static const Color textPrimary = Color(0xFF2E2A24);

  /// 보조 텍스트
  static const Color textSecondary = Color(0xFF8A8275);

  /// 옅은 텍스트(플레이스홀더)
  static const Color textPlaceholder = Color(0xFFC8BFAE);

  // ── 줄공책 ──────────────────────────────────────────────────
  /// 줄공책 베이스라인 색
  static const Color ruledLine = Color(0xFFF0E6D2);

  /// 입력 한 줄 높이(px) — fontSize × lineHeight 와 정확히 같아야
  /// 베이스라인과 캐럿이 어긋나지 않는다. (15 × 2.933 ≒ 44)
  static const double rowHeight = 44.0;

  /// 본문 글꼴 크기
  static const double contentFontSize = 15;

  /// 본문 line-height factor (rowHeight / contentFontSize)
  static const double contentLineHeight = rowHeight / contentFontSize;

  // ── 라운드/간격 ──────────────────────────────────────────────
  static const double cardRadius = 18;
  static const double sectionGap = 14;
  static const double pagePadding = 18;
}

/// 날씨 옵션 — 작성/수정/조회 공통
const List<DiaryWeatherOption> diaryWeatherOptions = [
  DiaryWeatherOption(
    icon: Icons.wb_sunny_rounded,
    label: '맑음',
    color: Color(0xFFFBBF24),
  ),
  DiaryWeatherOption(
    icon: Icons.wb_cloudy_rounded,
    label: '흐림',
    color: AppColors.gray400,
  ),
  DiaryWeatherOption(
    icon: Icons.grain_rounded,
    label: '비',
    color: AppColors.blue,
  ),
  DiaryWeatherOption(
    icon: Icons.ac_unit_rounded,
    label: '눈',
    color: AppColors.saturdayBlue,
  ),
];

class DiaryWeatherOption {
  const DiaryWeatherOption({
    required this.icon,
    required this.label,
    required this.color,
  });
  final IconData icon;
  final String label;
  final Color color;
}

/// 기분 옵션 — emoji + label
const List<DiaryMoodOption> diaryMoodOptions = [
  DiaryMoodOption(emoji: '😊', label: '행복'),
  DiaryMoodOption(emoji: '😍', label: '사랑'),
  DiaryMoodOption(emoji: '😂', label: '웃음'),
  DiaryMoodOption(emoji: '🥰', label: '뿌듯'),
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

/// 줄공책 베이스라인을 그리는 CustomPaint 백그라운드.
/// TextField/Text 와 동일한 [rowHeight] 를 사용하면 줄에 정확히 정렬됨.
class DiaryRuledBackground extends StatelessWidget {
  const DiaryRuledBackground({
    super.key,
    this.rowHeight = DiaryStyle.rowHeight,
    this.lineColor = DiaryStyle.ruledLine,
    this.topOffset = 0,
  });

  final double rowHeight;
  final Color lineColor;
  final double topOffset;

  @override
  Widget build(BuildContext context) {
    return Positioned.fill(
      child: IgnorePointer(
        child: CustomPaint(
          painter: _RuledPainter(
            rowHeight: rowHeight,
            lineColor: lineColor,
            topOffset: topOffset,
          ),
        ),
      ),
    );
  }
}

class _RuledPainter extends CustomPainter {
  _RuledPainter({
    required this.rowHeight,
    required this.lineColor,
    required this.topOffset,
  });

  final double rowHeight;
  final Color lineColor;
  final double topOffset;

  @override
  void paint(Canvas canvas, Size size) {
    if (rowHeight <= 0) return;
    final paint = Paint()
      ..color = lineColor
      ..strokeWidth = 1
      ..style = PaintingStyle.stroke;
    // 첫 줄은 topOffset + rowHeight 위치에 그린다 (텍스트가 줄 위에 앉도록).
    double y = topOffset + rowHeight;
    while (y < size.height) {
      canvas.drawLine(Offset(0, y), Offset(size.width, y), paint);
      y += rowHeight;
    }
  }

  @override
  bool shouldRepaint(covariant _RuledPainter old) =>
      old.rowHeight != rowHeight ||
      old.lineColor != lineColor ||
      old.topOffset != topOffset;
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
    return Container(
      clipBehavior: clipBehavior,
      decoration: BoxDecoration(
        color: DiaryStyle.cardBg,
        borderRadius: BorderRadius.circular(DiaryStyle.cardRadius),
        border: Border.all(color: DiaryStyle.cardBorder, width: 1),
        boxShadow: [
          BoxShadow(
            color: DiaryStyle.cardShadow,
            blurRadius: 14,
            offset: const Offset(0, 4),
          ),
        ],
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
