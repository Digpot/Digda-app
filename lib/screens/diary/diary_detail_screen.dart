import 'package:flutter/material.dart';
import '../../core/di.dart';
import '../../core/network/error_message.dart';
import '../../features/diary/models/diary_models.dart';
import '../../theme/colors.dart';
import '../../widgets/app_dialog.dart';
import '../../widgets/diary_paper.dart';

class DiaryDetailScreen extends StatefulWidget {
  const DiaryDetailScreen({super.key});

  @override
  State<DiaryDetailScreen> createState() => _DiaryDetailScreenState();
}

class _DiaryDetailScreenState extends State<DiaryDetailScreen> {
  bool _showMenu = false;
  bool _loading = true;
  bool _argsConsumed = false;
  String? _errorMessage;
  DiaryDetail? _detail;
  String? _diaryId;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_argsConsumed) return;
    _argsConsumed = true;
    final args = ModalRoute.of(context)?.settings.arguments;
    if (args is String) _diaryId = args;
    WidgetsBinding.instance.addPostFrameCallback((_) => _load());
  }

  Future<void> _load() async {
    final groupId = Di.activeGroup.groupRoomId;
    final diaryId = _diaryId;
    if (groupId == null || diaryId == null) {
      setState(() {
        _loading = false;
        _errorMessage = '일기 정보를 불러올 수 없어요';
      });
      return;
    }
    setState(() {
      _loading = true;
      _errorMessage = null;
    });
    try {
      final detail = await Di.diaryRepository.detail(groupId, diaryId);
      if (!mounted) return;
      setState(() {
        _detail = detail;
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _errorMessage = errorMessageOf(e);
      });
    }
  }

  Future<void> _onEditTap() async {
    setState(() => _showMenu = false);
    await Navigator.of(context).pushNamed('/edit-diary', arguments: _diaryId);
    if (!mounted) return;
    _load();
  }

  Future<void> _confirmDelete() async {
    final groupId = Di.activeGroup.groupRoomId;
    final diaryId = _diaryId;
    if (groupId == null || diaryId == null) {
      Navigator.of(context).pop();
      Navigator.of(context).pop();
      return;
    }
    try {
      await Di.diaryRepository.delete(groupId, diaryId);
      if (!mounted) return;
      Navigator.of(context).pop(); // 시트 닫기
      Navigator.of(context).pop(); // detail 닫기
    } catch (e) {
      if (!mounted) return;
      Navigator.of(context).pop();
      showErrorDialog(context, errorMessageOf(e));
    }
  }

  void _onDeleteTap() {
    setState(() => _showMenu = false);
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (context) => Container(
        padding: const EdgeInsets.fromLTRB(20, 0, 20, 12),
        decoration: const BoxDecoration(
          color: AppColors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SizedBox(height: 12),
            Container(
              width: 36,
              height: 4,
              decoration: BoxDecoration(
                color: AppColors.gray200,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(height: 24),
            Container(
              width: 48,
              height: 48,
              decoration: BoxDecoration(
                color: DiaryStyle.accent.withValues(alpha: 0.1),
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.delete_outline_rounded,
                color: DiaryStyle.accent,
                size: 24,
              ),
            ),
            const SizedBox(height: 16),
            const Text(
              '일기를 삭제할까요?',
              style: TextStyle(
                fontFamily: 'Inter',
                fontWeight: FontWeight.w700,
                fontSize: 17,
                color: DiaryStyle.textPrimary,
              ),
            ),
            const SizedBox(height: 6),
            const Text(
              '삭제한 일기는 되돌릴 수 없어요',
              style: TextStyle(
                fontFamily: 'Inter',
                fontWeight: FontWeight.w400,
                fontSize: 14,
                color: DiaryStyle.textSecondary,
              ),
            ),
            const SizedBox(height: 24),
            Row(
              children: [
                Expanded(
                  child: SizedBox(
                    height: 48,
                    child: OutlinedButton(
                      onPressed: () => Navigator.of(context).pop(),
                      style: OutlinedButton.styleFrom(
                        side: const BorderSide(color: AppColors.gray200),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      child: const Text(
                        '취소',
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
                const SizedBox(width: 10),
                Expanded(
                  child: SizedBox(
                    height: 48,
                    child: ElevatedButton(
                      onPressed: _confirmDelete,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: DiaryStyle.accent,
                        elevation: 0,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      child: const Text(
                        '삭제',
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
              ],
            ),
            SizedBox(height: MediaQuery.of(context).padding.bottom + 8),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: DiaryStyle.pageBg,
      body: SafeArea(
        child: Stack(
          children: [
            Column(
              children: [
                _buildAppBar(),
                Expanded(child: _buildBody()),
              ],
            ),
            if (_showMenu) ...[
              Positioned.fill(
                child: GestureDetector(
                  onTap: () => setState(() => _showMenu = false),
                  child: Container(color: Colors.transparent),
                ),
              ),
              Positioned(
                top: 46,
                right: 14,
                child: _buildDropdownMenu(),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildAppBar() {
    return Container(
      color: DiaryStyle.pageBg,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      child: SizedBox(
        height: 44,
        child: Row(
          children: [
            IconButton(
              onPressed: () => Navigator.of(context).pop(),
              icon: const Icon(
                Icons.arrow_back_ios_rounded,
                size: 18,
                color: DiaryStyle.textPrimary,
              ),
              splashRadius: 22,
            ),
            const Spacer(),
            if (_detail != null)
              IconButton(
                onPressed: () => setState(() => _showMenu = !_showMenu),
                icon: const Icon(
                  Icons.more_horiz_rounded,
                  size: 22,
                  color: DiaryStyle.textPrimary,
                ),
                splashRadius: 22,
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildBody() {
    if (_loading) {
      return const Center(
        child: CircularProgressIndicator(color: DiaryStyle.accent),
      );
    }
    if (_errorMessage != null) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.error_outline,
                size: 48, color: AppColors.gray400),
            const SizedBox(height: 12),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24),
              child: Text(
                _errorMessage!,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  fontFamily: 'Inter',
                  fontWeight: FontWeight.w500,
                  fontSize: 14,
                  color: AppColors.gray700,
                ),
              ),
            ),
            const SizedBox(height: 12),
            TextButton(
              onPressed: _load,
              child: const Text(
                '다시 시도',
                style: TextStyle(
                  fontFamily: 'Inter',
                  fontWeight: FontWeight.w600,
                  fontSize: 14,
                  color: DiaryStyle.accent,
                ),
              ),
            ),
          ],
        ),
      );
    }
    final diary = _detail!.diary;
    final weather = diaryWeatherOf(diary.weather);
    final mood = diaryMoodOf(diary.mood);
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(
        DiaryStyle.pagePadding,
        8,
        DiaryStyle.pagePadding,
        32,
      ),
      child: Column(
        children: [
          _buildHeaderCard(diary, weather, mood),
          const SizedBox(height: DiaryStyle.sectionGap),
          if (diary.imageUrl != null && diary.imageUrl!.isNotEmpty) ...[
            _buildPhotoCard(diary.imageUrl!),
            const SizedBox(height: DiaryStyle.sectionGap),
          ],
          _buildContentCard(diary.content),
          const SizedBox(height: DiaryStyle.sectionGap),
          _buildAuthorCard(diary),
        ],
      ),
    );
  }

  // ── 헤더 카드 ────────────────────────────────────────────────
  Widget _buildHeaderCard(
    Diary diary,
    DiaryWeatherOption weather,
    DiaryMoodOption mood,
  ) {
    return DiaryPaperCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const DiaryCardAccentBar(),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 14, 16, 12),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        '날짜',
                        style: TextStyle(
                          fontFamily: 'Inter',
                          fontWeight: FontWeight.w500,
                          fontSize: 11,
                          color: DiaryStyle.labelBrown,
                          letterSpacing: 0.3,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        formatDiaryDate(diary.date),
                        style: const TextStyle(
                          fontFamily: 'Inter',
                          fontWeight: FontWeight.w700,
                          fontSize: 14,
                          color: DiaryStyle.textPrimary,
                        ),
                      ),
                    ],
                  ),
                ),
                _buildReadOnlyChip(
                  icon: weather.icon,
                  iconColor: weather.color,
                  label: weather.label,
                ),
                const SizedBox(width: 8),
                _buildReadOnlyChip(
                  emoji: mood.emoji,
                  label: mood.label,
                ),
              ],
            ),
          ),
          Container(height: 1, color: DiaryStyle.cardBorder),
          Container(
            color: AppColors.gray50,
            padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                const SizedBox(
                  width: 40,
                  child: Text(
                    '제목',
                    style: TextStyle(
                      fontFamily: 'Inter',
                      fontWeight: FontWeight.w700,
                      fontSize: 13,
                      color: DiaryStyle.labelBrown,
                    ),
                  ),
                ),
                Container(
                  width: 1,
                  height: 18,
                  color: DiaryStyle.cardBorder,
                  margin: const EdgeInsets.only(right: 12),
                ),
                Expanded(
                  child: Text(
                    diary.title,
                    style: const TextStyle(
                      fontFamily: 'Inter',
                      fontWeight: FontWeight.w700,
                      fontSize: 16,
                      height: 1.4,
                      color: DiaryStyle.textPrimary,
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

  Widget _buildReadOnlyChip({
    IconData? icon,
    Color? iconColor,
    String? emoji,
    required String label,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: DiaryStyle.accentSoft,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icon != null)
            Icon(icon, size: 14, color: iconColor)
          else if (emoji != null)
            Text(emoji, style: const TextStyle(fontSize: 14)),
          const SizedBox(width: 4),
          Text(
            label,
            style: const TextStyle(
              fontFamily: 'Inter',
              fontWeight: FontWeight.w600,
              fontSize: 12,
              color: DiaryStyle.accent,
            ),
          ),
        ],
      ),
    );
  }

  // ── 사진 카드 ────────────────────────────────────────────────
  Widget _buildPhotoCard(String imageUrl) {
    return DiaryPaperCard(
      child: AspectRatio(
        aspectRatio: 4 / 3,
        child: Image.network(
          imageUrl,
          width: double.infinity,
          fit: BoxFit.cover,
          loadingBuilder: (context, child, progress) {
            if (progress == null) return child;
            return Container(
              color: AppColors.gray50,
              child: const Center(
                child: SizedBox(
                  width: 28,
                  height: 28,
                  child: CircularProgressIndicator(
                    strokeWidth: 2.5,
                    color: DiaryStyle.accent,
                  ),
                ),
              ),
            );
          },
          errorBuilder: (_, __, ___) => Container(
            color: AppColors.gray50,
            child: const Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.broken_image_outlined,
                      size: 32, color: DiaryStyle.labelBrown),
                  SizedBox(height: 6),
                  Text(
                    '사진을 불러올 수 없어요',
                    style: TextStyle(
                      fontFamily: 'Inter',
                      fontWeight: FontWeight.w400,
                      fontSize: 12,
                      color: DiaryStyle.textSecondary,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  // ── 본문 카드 (읽기 전용 줄공책) ─────────────────────────────
  Widget _buildContentCard(String content) {
    return DiaryPaperCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const DiaryCardAccentBar(),
          const Padding(
            padding: EdgeInsets.fromLTRB(16, 14, 16, 0),
            child: Row(
              children: [
                Icon(
                  Icons.menu_book_rounded,
                  size: 18,
                  color: DiaryStyle.labelBrown,
                ),
                SizedBox(width: 6),
                Text(
                  '오늘의 이야기',
                  style: TextStyle(
                    fontFamily: 'Inter',
                    fontWeight: FontWeight.w700,
                    fontSize: 13,
                    color: DiaryStyle.labelBrown,
                  ),
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 10, 16, 18),
            child: _RuledText(text: content),
          ),
        ],
      ),
    );
  }

  // ── 작성자 카드 ─────────────────────────────────────────────
  Widget _buildAuthorCard(Diary diary) {
    final author = diary.createdBy;
    final initial = author.name.isNotEmpty ? author.name[0] : '?';
    return DiaryPaperCard(
      padding: const EdgeInsets.fromLTRB(16, 14, 14, 14),
      child: Row(
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: DiaryStyle.accent.withValues(alpha: 0.12),
              shape: BoxShape.circle,
            ),
            clipBehavior: Clip.antiAlias,
            child: (author.profileImage != null &&
                    author.profileImage!.isNotEmpty)
                ? Image.network(
                    author.profileImage!,
                    fit: BoxFit.cover,
                    errorBuilder: (_, __, ___) => _avatarFallback(initial),
                  )
                : _avatarFallback(initial),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  author.name,
                  style: const TextStyle(
                    fontFamily: 'Inter',
                    fontWeight: FontWeight.w700,
                    fontSize: 14,
                    color: DiaryStyle.textPrimary,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  '${formatDiaryTimestamp(diary.createdAt)}에 작성',
                  style: const TextStyle(
                    fontFamily: 'Inter',
                    fontWeight: FontWeight.w400,
                    fontSize: 12,
                    color: DiaryStyle.textSecondary,
                  ),
                ),
              ],
            ),
          ),
          Material(
            color: DiaryStyle.accent,
            borderRadius: BorderRadius.circular(20),
            child: InkWell(
              onTap: _onEditTap,
              borderRadius: BorderRadius.circular(20),
              splashColor: AppColors.white.withValues(alpha: 0.3),
              highlightColor: AppColors.white.withValues(alpha: 0.15),
              child: const Padding(
                padding: EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                child: Text(
                  '수정하기',
                  style: TextStyle(
                    fontFamily: 'Inter',
                    fontWeight: FontWeight.w600,
                    fontSize: 13,
                    color: AppColors.white,
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _avatarFallback(String initial) {
    return Center(
      child: Text(
        initial,
        style: const TextStyle(
          fontFamily: 'Inter',
          fontWeight: FontWeight.w700,
          fontSize: 16,
          color: DiaryStyle.accent,
        ),
      ),
    );
  }

  Widget _buildDropdownMenu() {
    return Container(
      width: 148,
      decoration: BoxDecoration(
        color: AppColors.white,
        borderRadius: BorderRadius.circular(14),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.08),
            blurRadius: 20,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          GestureDetector(
            onTap: _onEditTap,
            behavior: HitTestBehavior.opaque,
            child: const Padding(
              padding: EdgeInsets.symmetric(horizontal: 16, vertical: 14),
              child: Row(
                children: [
                  Icon(Icons.edit_outlined,
                      size: 18, color: DiaryStyle.textPrimary),
                  SizedBox(width: 10),
                  Text(
                    '편집',
                    style: TextStyle(
                      fontFamily: 'Inter',
                      fontWeight: FontWeight.w500,
                      fontSize: 14,
                      color: DiaryStyle.textPrimary,
                    ),
                  ),
                ],
              ),
            ),
          ),
          Container(
            height: 1,
            margin: const EdgeInsets.symmetric(horizontal: 12),
            color: AppColors.gray100,
          ),
          GestureDetector(
            onTap: _onDeleteTap,
            behavior: HitTestBehavior.opaque,
            child: const Padding(
              padding: EdgeInsets.symmetric(horizontal: 16, vertical: 14),
              child: Row(
                children: [
                  Icon(Icons.delete_outline_rounded,
                      size: 18, color: DiaryStyle.accent),
                  SizedBox(width: 10),
                  Text(
                    '삭제',
                    style: TextStyle(
                      fontFamily: 'Inter',
                      fontWeight: FontWeight.w500,
                      fontSize: 14,
                      color: DiaryStyle.accent,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// 본문 줄공책 — 읽기 전용. 텍스트 strut 이 [DiaryStyle.rowHeight] 라인 박스를 강제하고
/// painter 는 baseline 살짝 아래(firstLineY)에 줄을 그어 공책처럼 정렬된다.
class _RuledText extends StatelessWidget {
  const _RuledText({required this.text});
  final String text;

  @override
  Widget build(BuildContext context) {
    const style = TextStyle(
      fontFamily: 'Inter',
      fontWeight: FontWeight.w400,
      fontSize: DiaryStyle.contentFontSize,
      height: DiaryStyle.contentLineHeight,
      color: DiaryStyle.textPrimary,
    );
    // strut 의 fontFamily 가 비면 플랫폼 기본 폰트로 line metrics 가 계산되어
    // Inter 의 baseline 과 어긋날 수 있다. fontFamily 를 명시해 동기화.
    const strut = StrutStyle(
      fontFamily: 'Inter',
      fontSize: DiaryStyle.contentFontSize,
      height: DiaryStyle.contentLineHeight,
      forceStrutHeight: true,
      leading: 0,
      leadingDistribution: TextLeadingDistribution.even,
    );
    return ConstrainedBox(
      constraints: const BoxConstraints(
        minHeight: DiaryStyle.rowHeight * 8,
      ),
      child: Stack(
        children: [
          const DiaryRuledBackground(),
          SizedBox(
            width: double.infinity,
            child: Text(
              text.isEmpty ? ' ' : text,
              style: style,
              strutStyle: strut,
              textHeightBehavior: const TextHeightBehavior(
                leadingDistribution: TextLeadingDistribution.even,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
