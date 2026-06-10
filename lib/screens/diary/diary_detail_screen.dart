import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../core/di.dart';
import '../../core/network/error_message.dart';
import '../../features/common/models/common_models.dart';
import '../../features/diary/diary_window.dart';
import '../../features/diary/models/diary_models.dart';
import '../../theme/colors.dart';
import '../../widgets/app_dialog.dart';
import '../../widgets/diary_paper.dart';
import 'diary_delete_sheet.dart';

/// 일기 상세 — docs/re/reDiary_read.png 스펙 기반 리뉴얼.
class DiaryDetailScreen extends StatefulWidget {
  const DiaryDetailScreen({super.key});

  @override
  State<DiaryDetailScreen> createState() => _DiaryDetailScreenState();
}

class _DiaryDetailScreenState extends State<DiaryDetailScreen> {
  static const Color _coral = Color(0xFFFF6B6B);
  static const Color _coralSoft = Color(0xFFFFEDED);
  static const Color _ink = Color(0xFF191F28);
  static const Color _sub = Color(0xFF4E5968);
  static const Color _muted = Color(0xFF8B95A1);
  static const Color _line = Color(0xFFF2F4F6);
  static const Color _chipBg = Color(0xFFF6F7F9);

  bool _loading = true;
  String? _errorMessage;
  bool _argsConsumed = false;
  String? _diaryId;

  DiaryDetail? _detail;
  int _heroIndex = 0;
  late final PageController _photoController = PageController();

  final TextEditingController _commentController = TextEditingController();
  final FocusNode _commentFocus = FocusNode();
  bool _commentSending = false;

  // 더보기 팝오버 OverlayEntry. NavigatorOverlay 에 붙기 때문에 화면이 pop 되어도
  // 자동으로 제거되지 않아 다음 화면 위에 남아 보이는 버그가 있었음.
  // dispose 와 메뉴 액션 시점에 명시적으로 정리한다.
  OverlayEntry? _moreMenuEntry;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_argsConsumed) return;
    _argsConsumed = true;
    final args = ModalRoute.of(context)?.settings.arguments;
    if (args is String) _diaryId = args;
    WidgetsBinding.instance.addPostFrameCallback((_) => _load());
  }

  @override
  void dispose() {
    _moreMenuEntry?.remove();
    _moreMenuEntry = null;
    _photoController.dispose();
    _commentController.dispose();
    _commentFocus.dispose();
    super.dispose();
  }

  void _closeMoreMenu() {
    _moreMenuEntry?.remove();
    _moreMenuEntry = null;
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
        if (_heroIndex >= detail.diary.imageUrls.length) _heroIndex = 0;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _errorMessage = errorMessageOf(e);
      });
    }
  }

  Future<void> _toggleReaction(DiaryReactionType type) async {
    final detail = _detail;
    final groupId = Di.activeGroup.groupRoomId;
    if (detail == null || groupId == null) return;
    try {
      final res = await Di.diaryRepository
          .toggleReaction(groupId, detail.diary.id, type);
      if (!mounted) return;
      setState(() => _detail = _replaceDiary(
            detail.diary.copyWith(reactions: res.reactions),
          ));
    } catch (e) {
      if (!mounted) return;
      showErrorDialog(context, errorMessageOf(e));
    }
  }

  DiaryDetail _replaceDiary(Diary diary) =>
      DiaryDetail(diary: diary, comments: _detail!.comments);

  Future<void> _sendComment() async {
    final text = _commentController.text.trim();
    if (text.isEmpty || _commentSending) return;
    final groupId = Di.activeGroup.groupRoomId;
    final detail = _detail;
    if (groupId == null || detail == null) return;
    setState(() => _commentSending = true);
    try {
      final created = await Di.commentRepository.writeOnDiary(
        groupRoomId: groupId,
        diaryId: detail.diary.id,
        text: text,
      );
      if (!mounted) return;
      _commentController.clear();
      _commentFocus.unfocus();
      setState(() {
        _detail = DiaryDetail(
          diary: detail.diary,
          comments: [...detail.comments, created],
        );
        _commentSending = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _commentSending = false);
      showErrorDialog(context, errorMessageOf(e));
    }
  }

  Future<void> _onEditTap() async {
    final diaryId = _diaryId;
    if (diaryId == null) return;
    if (_isLockedByAge) {
      _showLockedDialog();
      return;
    }
    await Navigator.of(context)
        .pushNamed('/edit-diary', arguments: diaryId);
    if (!mounted) return;
    _load();
  }

  /// 작성 후 3개월이 지나 수정·삭제가 잠긴 일기인지.
  bool get _isLockedByAge {
    final d = _detail?.diary;
    return d != null && !isDiaryDateEditable(d.date);
  }

  void _showLockedDialog() {
    showLimitDialog(
      context,
      title: '수정·삭제할 수 없어요',
      message:
          '작성한 지 $kDiaryEditableMonths개월이 지난 일기는\n수정하거나 삭제할 수 없어요.',
    );
  }

  void _openMoreMenu() {
    final detail = _detail;
    if (detail == null) return;
    // 이미 떠 있는 메뉴는 먼저 정리 (중복 insert 방지)
    _closeMoreMenu();
    final overlay = Overlay.of(context);
    final entry = OverlayEntry(builder: (ctx) {
      return _MoreMenuOverlay(
        onClose: _closeMoreMenu,
        onEdit: _isMine
            ? () {
                _closeMoreMenu();
                _onEditTap();
              }
            : null,
        onDelete: _isMine
            ? () {
                _closeMoreMenu();
                _openDeleteSheet();
              }
            : null,
      );
    });
    _moreMenuEntry = entry;
    overlay.insert(entry);
  }

  void _openDeleteSheet() {
    final detail = _detail;
    if (detail == null) return;
    if (_isLockedByAge) {
      _showLockedDialog();
      return;
    }
    showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      barrierColor: Colors.black.withValues(alpha: 0.55),
      builder: (_) => DiaryDeleteSheet(
        diary: detail.diary,
        commentCount: detail.comments.length,
        onConfirm: _confirmDelete,
      ),
    );
  }

  Future<bool> _confirmDelete() async {
    final groupId = Di.activeGroup.groupRoomId;
    final diaryId = _diaryId;
    if (groupId == null || diaryId == null) return false;
    try {
      await Di.diaryRepository.delete(groupId, diaryId);
      if (mounted) {
        Navigator.of(context).pop();
        showAppSnackBar(context, '일기를 삭제했어요');
      }
      return true;
    } catch (e) {
      if (mounted) showErrorDialog(context, errorMessageOf(e));
      return false;
    }
  }

  bool get _isMine {
    final detail = _detail;
    if (detail == null) return false;
    final myId = Di.userSession.profile?.id;
    return myId != null && detail.diary.createdBy.id == myId;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.white,
      body: _loading
          ? _buildLoading()
          : _errorMessage != null
              ? _buildError()
              : _buildContent(context),
    );
  }

  Widget _buildLoading() => const Center(
        child: CircularProgressIndicator(color: _coral),
      );

  Widget _buildError() {
    return SafeArea(
      child: Stack(
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 32),
            child: Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.error_outline,
                      size: 48, color: _muted),
                  const SizedBox(height: 12),
                  Text(
                    _errorMessage!,
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      fontFamily: 'Inter',
                      fontWeight: FontWeight.w600,
                      fontSize: 14,
                      color: _sub,
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextButton(
                    onPressed: _load,
                    child: const Text('다시 시도'),
                  ),
                ],
              ),
            ),
          ),
          Positioned(
            top: 12,
            left: 12,
            child: _CircleIconButton(
              icon: Icons.arrow_back_ios_new_rounded,
              onTap: () => Navigator.of(context).pop(),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildContent(BuildContext context) {
    final diary = _detail!.diary;
    final mediaQuery = MediaQuery.of(context);
    final heroHeight = mediaQuery.size.height * 0.45;

    return Column(
      children: [
        Expanded(
          child: Stack(
            children: [
              SingleChildScrollView(
                padding: const EdgeInsets.only(bottom: 16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    _buildHero(diary, heroHeight),
                    Transform.translate(
                      offset: const Offset(0, -40),
                      child: _buildSheet(diary),
                    ),
                  ],
                ),
              ),
              Positioned(
                left: 0,
                right: 0,
                top: mediaQuery.padding.top + 12,
                child: _buildFloatingBar(diary),
              ),
            ],
          ),
        ),
        _buildCommentBar(),
      ],
    );
  }

  // ── Hero photo ───────────────────────────────────────────────────────
  Widget _buildHero(Diary diary, double height) {
    final urls = diary.imageUrls;
    if (urls.isEmpty) {
      return _buildEmptyHero(diary);
    }
    return SizedBox(
      height: height,
      child: Stack(
        children: [
          PageView.builder(
            controller: _photoController,
            itemCount: urls.length,
            onPageChanged: (i) => setState(() => _heroIndex = i),
            itemBuilder: (_, index) => Image.network(
              urls[index],
              fit: BoxFit.cover,
              width: double.infinity,
              errorBuilder: (_, __, ___) => Container(
                color: _chipBg,
                alignment: Alignment.center,
                child: const Icon(Icons.broken_image_outlined,
                    size: 36, color: _muted),
              ),
            ),
          ),
          Positioned.fill(
            child: IgnorePointer(
              child: DecoratedBox(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [
                      Colors.black.withValues(alpha: 0.35),
                      Colors.transparent,
                    ],
                    stops: const [0.0, 0.45],
                  ),
                ),
              ),
            ),
          ),
          if (urls.length > 1)
            Positioned(
              right: 16,
              bottom: 56,
              child: Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: Colors.black.withValues(alpha: 0.55),
                  borderRadius: BorderRadius.circular(999),
                ),
                child: Text(
                  '${_heroIndex + 1}/${urls.length}',
                  style: const TextStyle(
                    fontFamily: 'Inter',
                    fontWeight: FontWeight.w700,
                    fontSize: 12,
                    color: AppColors.white,
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }

  // 사진이 없는 일기일 때 hero 자리. 회색 placeholder 대신 mood·weather 컬러로
  // 분위기를 살린 컴팩트한 카드. 높이를 줄여 sheet 본문이 자연스럽게 위로 올라온다.
  Widget _buildEmptyHero(Diary diary) {
    final mood = diaryMoodOf(diary.mood);
    final weather = diaryWeatherOf(diary.weather);
    final palette = _moodPalette(diary.mood);

    return Container(
      height: 240,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [palette.$1, palette.$2],
        ),
      ),
      child: Stack(
        children: [
          Positioned(
            top: -36,
            right: -36,
            child: Container(
              width: 160,
              height: 160,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: Colors.white.withValues(alpha: 0.18),
              ),
            ),
          ),
          Positioned(
            bottom: -20,
            left: -30,
            child: Container(
              width: 120,
              height: 120,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: Colors.white.withValues(alpha: 0.14),
              ),
            ),
          ),
          Positioned.fill(
            child: IgnorePointer(
              child: DecoratedBox(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [
                      Colors.black.withValues(alpha: 0.25),
                      Colors.transparent,
                    ],
                    stops: const [0.0, 0.4],
                  ),
                ),
              ),
            ),
          ),
          Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 92,
                  height: 92,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: Colors.white.withValues(alpha: 0.9),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.08),
                        blurRadius: 18,
                        offset: const Offset(0, 6),
                      ),
                    ],
                  ),
                  alignment: Alignment.center,
                  child: Text(
                    mood.emoji,
                    style: const TextStyle(fontSize: 48),
                  ),
                ),
                const SizedBox(height: 14),
                Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 14, vertical: 7),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.25),
                    borderRadius: BorderRadius.circular(999),
                    border: Border.all(
                      color: Colors.white.withValues(alpha: 0.45),
                      width: 1,
                    ),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(weather.emoji,
                          style: const TextStyle(fontSize: 14)),
                      const SizedBox(width: 6),
                      Text(
                        '${weather.label} · ${mood.label}',
                        style: const TextStyle(
                          fontFamily: 'Inter',
                          fontWeight: FontWeight.w700,
                          fontSize: 13,
                          color: AppColors.white,
                          letterSpacing: -0.2,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // mood 인덱스(0..4) 별 그라데이션 컬러쌍. 본문 위 hero 자리에서 분위기를 짧게 전달.
  (Color, Color) _moodPalette(int mood) {
    switch (mood) {
      case 0: // 행복
        return (const Color(0xFFFFB199), const Color(0xFFFF6B6B));
      case 1: // 평온
        return (const Color(0xFF8FDDC5), const Color(0xFF5BA8E0));
      case 2: // 슬픔
        return (const Color(0xFF9BB5DD), const Color(0xFF5063A6));
      case 3: // 화남
        return (const Color(0xFFFFAE8A), const Color(0xFFE85D5D));
      case 4: // 피곤
        return (const Color(0xFFC3A9E0), const Color(0xFF8E7AB5));
      default:
        return (const Color(0xFFFFB199), const Color(0xFFFF6B6B));
    }
  }

  // ── Floating bar ─────────────────────────────────────────────────────
  Widget _buildFloatingBar(Diary diary) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Row(
        children: [
          _CircleIconButton(
            icon: Icons.arrow_back_ios_new_rounded,
            onTap: () => Navigator.of(context).pop(),
          ),
          const Spacer(),
          // 일기는 작성자 본인만 수정/삭제 가능 — 메뉴에 그 두 항목뿐이므로
          // 내 일기가 아니면 점 3개 메뉴 버튼 자체를 숨긴다.
          if (_isMine)
            _CircleIconButton(
              icon: Icons.more_horiz_rounded,
              onTap: _openMoreMenu,
            ),
        ],
      ),
    );
  }

  // ── White sheet ──────────────────────────────────────────────────────
  Widget _buildSheet(Diary diary) {
    final author = diary.createdBy;
    final dateText = _formatDate(diary.date);
    final groupName = Di.activeGroup.groupRoomName ?? '그룹';
    final timeText = _relativeTime(diary.createdAt);

    return Container(
      decoration: const BoxDecoration(
        color: AppColors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(32)),
      ),
      padding: const EdgeInsets.fromLTRB(24, 24, 24, 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildChips(diary),
          const SizedBox(height: 16),
          Text(
            diary.title,
            style: const TextStyle(
              fontFamily: 'Inter',
              fontWeight: FontWeight.w800,
              fontSize: 26,
              height: 1.25,
              letterSpacing: -0.5,
              color: _ink,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            dateText,
            style: const TextStyle(
              fontFamily: 'Inter',
              fontWeight: FontWeight.w500,
              fontSize: 13,
              color: _muted,
            ),
          ),
          const SizedBox(height: 18),
          _buildAuthorRow(author.name, groupName, timeText,
              author.profileImage),
          const SizedBox(height: 18),
          Text(
            diary.content,
            style: const TextStyle(
              fontFamily: 'Inter',
              fontWeight: FontWeight.w400,
              fontSize: 16,
              height: 1.7,
              color: _ink,
            ),
          ),
          const SizedBox(height: 20),
          _buildReactionRow(diary),
          const SizedBox(height: 24),
          _buildCommentSection(),
        ],
      ),
    );
  }

  Widget _buildChips(Diary diary) {
    final weather = diaryWeatherOf(diary.weather);
    final mood = diaryMoodOf(diary.mood);
    final chips = <Widget>[
      _MetaChip(
        label: weather.label,
        emoji: weather.emoji,
        background: const Color(0xFFFEF3C7),
        foreground: const Color(0xFFB45309),
      ),
      _MetaChip(
        label: mood.label,
        emoji: mood.emoji,
        background: _coralSoft,
        foreground: _coral,
      ),
      if ((diary.location ?? '').isNotEmpty)
        _MetaChip(
          label: diary.location!,
          emoji: '📍',
          background: const Color(0xFFEDE9FE),
          foreground: const Color(0xFF6D28D9),
        ),
    ];
    return Wrap(spacing: 8, runSpacing: 8, children: chips);
  }

  Widget _buildAuthorRow(
    String name,
    String groupName,
    String timeText,
    String? profileImage,
  ) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 12),
      decoration: const BoxDecoration(
        border: Border(
          top: BorderSide(color: _line),
          bottom: BorderSide(color: _line),
        ),
      ),
      child: Row(
        children: [
          _Avatar(name: name, image: profileImage, size: 44),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  name,
                  style: const TextStyle(
                    fontFamily: 'Inter',
                    fontWeight: FontWeight.w700,
                    fontSize: 15,
                    color: _ink,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  '$groupName · $timeText',
                  style: const TextStyle(
                    fontFamily: 'Inter',
                    fontWeight: FontWeight.w400,
                    fontSize: 12,
                    color: _muted,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildReactionRow(Diary diary) {
    final byType = {for (final r in diary.reactions) r.type: r};
    return Row(
      children: [
        for (final t in DiaryReactionType.values)
          Padding(
            padding: const EdgeInsets.only(right: 8),
            child: _ReactionPill(
              emoji: _emojiOf(t),
              count: byType[t]?.count ?? 0,
              active: byType[t]?.reactedByMe ?? false,
              onTap: () => _toggleReaction(t),
            ),
          ),
      ],
    );
  }

  Widget _buildCommentSection() {
    final comments = _detail?.comments ?? const [];
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          '댓글 ${comments.length}',
          style: const TextStyle(
            fontFamily: 'Inter',
            fontWeight: FontWeight.w700,
            fontSize: 15,
            color: _ink,
          ),
        ),
        const SizedBox(height: 12),
        if (comments.isEmpty)
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 16),
            child: Text(
              '첫 댓글을 남겨보세요.',
              style: TextStyle(
                fontFamily: 'Inter',
                fontWeight: FontWeight.w500,
                fontSize: 13,
                color: _muted,
              ),
            ),
          )
        else
          for (final c in comments)
            Padding(
              padding: const EdgeInsets.only(bottom: 14),
              child: _CommentRow(comment: c),
            ),
      ],
    );
  }

  // ── Bottom sticky comment bar ────────────────────────────────────────
  Widget _buildCommentBar() {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.white,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.06),
            blurRadius: 8,
            offset: const Offset(0, -2),
          ),
        ],
      ),
      padding: EdgeInsets.fromLTRB(
        16,
        10,
        16,
        MediaQuery.of(context).padding.bottom + 10,
      ),
      child: Row(
        children: [
          Expanded(
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              height: 40,
              decoration: BoxDecoration(
                color: _chipBg,
                borderRadius: BorderRadius.circular(20),
              ),
              child: TextField(
                controller: _commentController,
                focusNode: _commentFocus,
                cursorColor: _coral,
                maxLength: 200,
                maxLines: 1,
                textInputAction: TextInputAction.send,
                onSubmitted: (_) => _sendComment(),
                style: const TextStyle(
                  fontFamily: 'Inter',
                  fontWeight: FontWeight.w500,
                  fontSize: 14,
                  color: _ink,
                ),
                decoration: const InputDecoration(
                  isCollapsed: true,
                  counterText: '',
                  border: InputBorder.none,
                  contentPadding: EdgeInsets.symmetric(vertical: 13),
                  hintText: '댓글로 마음을 남겨보세요',
                  hintStyle: TextStyle(
                    fontFamily: 'Inter',
                    fontWeight: FontWeight.w500,
                    fontSize: 14,
                    color: _muted,
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(width: 8),
          GestureDetector(
            onTap: _sendComment,
            child: Container(
              width: 40,
              height: 40,
              decoration: const BoxDecoration(
                color: _coral,
                shape: BoxShape.circle,
              ),
              child: _commentSending
                  ? const Padding(
                      padding: EdgeInsets.all(10),
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: AppColors.white,
                      ),
                    )
                  : const Icon(
                      Icons.arrow_upward_rounded,
                      size: 20,
                      color: AppColors.white,
                    ),
            ),
          ),
        ],
      ),
    );
  }

  static String _formatDate(DateTime d) {
    final weekday =
        ['월', '화', '수', '목', '금', '토', '일'][d.weekday - 1];
    return DateFormat('yyyy년 M월 d일').format(d) + ' · $weekday요일';
  }

  static String _relativeTime(DateTime t) {
    final diff = DateTime.now().difference(t.toLocal());
    if (diff.inMinutes < 1) return '방금 전';
    if (diff.inHours < 1) return '${diff.inMinutes}분 전';
    if (diff.inDays < 1) return '${diff.inHours}시간 전';
    if (diff.inDays < 7) return '${diff.inDays}일 전';
    return DateFormat('M월 d일').format(t.toLocal());
  }

  static String _emojiOf(DiaryReactionType t) {
    switch (t) {
      case DiaryReactionType.heart:
        return '❤️';
      case DiaryReactionType.cry:
        return '🥹';
      case DiaryReactionType.sparkle:
        return '✨';
      case DiaryReactionType.laugh:
        return '😆';
      case DiaryReactionType.fire:
        return '🔥';
    }
  }
}

extension on Diary {
  Diary copyWith({
    int? likeCount,
    bool? likedByMe,
    List<DiaryReactionSummary>? reactions,
  }) {
    return Diary(
      id: id,
      title: title,
      content: content,
      date: date,
      weather: weather,
      mood: mood,
      location: location,
      imageUrls: imageUrls,
      createdBy: createdBy,
      createdAt: createdAt,
      updatedAt: updatedAt,
      likeCount: likeCount ?? this.likeCount,
      likedByMe: likedByMe ?? this.likedByMe,
      reactions: reactions ?? this.reactions,
    );
  }
}

// ──────────────────────────────────────────────────────────────────────
// Sub widgets
// ──────────────────────────────────────────────────────────────────────

class _CircleIconButton extends StatelessWidget {
  const _CircleIconButton({
    required this.icon,
    required this.onTap,
  });
  final IconData icon;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: ClipOval(
        child: BackdropFilter(
          filter: ui.ImageFilter.blur(sigmaX: 8, sigmaY: 8),
          child: Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: Colors.black.withValues(alpha: 0.35),
              shape: BoxShape.circle,
            ),
            child: Icon(icon, size: 20, color: AppColors.white),
          ),
        ),
      ),
    );
  }
}

class _MetaChip extends StatelessWidget {
  const _MetaChip({
    required this.label,
    required this.emoji,
    required this.background,
    required this.foreground,
  });
  final String label;
  final String emoji;
  final Color background;
  final Color foreground;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(emoji, style: const TextStyle(fontSize: 13)),
          const SizedBox(width: 4),
          Text(
            label,
            style: TextStyle(
              fontFamily: 'Inter',
              fontWeight: FontWeight.w700,
              fontSize: 12,
              color: foreground,
            ),
          ),
        ],
      ),
    );
  }
}

class _Avatar extends StatelessWidget {
  const _Avatar({required this.name, required this.image, required this.size});
  final String name;
  final String? image;
  final double size;

  @override
  Widget build(BuildContext context) {
    final initial = name.isNotEmpty ? name[0] : '?';
    final hasImage = image != null && image!.isNotEmpty;
    return Container(
      width: size,
      height: size,
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: const Color(0xFFFFEDED),
      ),
      child: hasImage
          ? Image.network(image!,
              fit: BoxFit.cover,
              errorBuilder: (_, __, ___) => _fallback(initial))
          : _fallback(initial),
    );
  }

  Widget _fallback(String initial) => Center(
        child: Text(
          initial,
          style: TextStyle(
            fontFamily: 'Inter',
            fontWeight: FontWeight.w700,
            fontSize: size * 0.4,
            color: const Color(0xFFFF6B6B),
          ),
        ),
      );
}

class _ReactionPill extends StatelessWidget {
  const _ReactionPill({
    required this.emoji,
    required this.count,
    required this.active,
    required this.onTap,
  });
  final String emoji;
  final int count;
  final bool active;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 120),
        padding:
            const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
          color: active ? const Color(0xFFFFEDED) : const Color(0xFFF6F7F9),
          borderRadius: BorderRadius.circular(999),
          border: Border.all(
            color: active ? const Color(0xFFFF6B6B) : Colors.transparent,
            width: 1.5,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(emoji, style: const TextStyle(fontSize: 14)),
            const SizedBox(width: 6),
            Text(
              '$count',
              style: TextStyle(
                fontFamily: 'Inter',
                fontWeight: FontWeight.w700,
                fontSize: 12,
                color: active
                    ? const Color(0xFFFF6B6B)
                    : const Color(0xFF4E5968),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _CommentRow extends StatelessWidget {
  const _CommentRow({required this.comment});
  final CommentEntity comment;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _Avatar(
            name: comment.createdBy.name,
            image: comment.createdBy.profileImage,
            size: 36),
        const SizedBox(width: 10),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                padding: const EdgeInsets.symmetric(
                    horizontal: 12, vertical: 10),
                decoration: BoxDecoration(
                  color: const Color(0xFFF6F7F9),
                  borderRadius: const BorderRadius.only(
                    topLeft: Radius.circular(4),
                    topRight: Radius.circular(18),
                    bottomLeft: Radius.circular(18),
                    bottomRight: Radius.circular(18),
                  ),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      comment.createdBy.name,
                      style: const TextStyle(
                        fontFamily: 'Inter',
                        fontWeight: FontWeight.w700,
                        fontSize: 12,
                        color: Color(0xFF4E5968),
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      comment.text,
                      style: const TextStyle(
                        fontFamily: 'Inter',
                        fontWeight: FontWeight.w500,
                        fontSize: 14,
                        height: 1.5,
                        color: Color(0xFF191F28),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 4),
              Text(
                _relativeTime(comment.createdAt),
                style: const TextStyle(
                  fontFamily: 'Inter',
                  fontWeight: FontWeight.w500,
                  fontSize: 11,
                  color: Color(0xFF8B95A1),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  static String _relativeTime(DateTime t) {
    final diff = DateTime.now().difference(t.toLocal());
    if (diff.inMinutes < 1) return '방금 전';
    if (diff.inHours < 1) return '${diff.inMinutes}분 전';
    if (diff.inDays < 1) return '${diff.inHours}시간 전';
    if (diff.inDays < 7) return '${diff.inDays}일 전';
    return DateFormat('M월 d일').format(t.toLocal());
  }
}

// ──────────────────────────────────────────────────────────────────────
// More menu (popover)
// ──────────────────────────────────────────────────────────────────────

class _MoreMenuOverlay extends StatelessWidget {
  const _MoreMenuOverlay({
    required this.onClose,
    this.onEdit,
    this.onDelete,
  });
  final VoidCallback onClose;
  final VoidCallback? onEdit;
  final VoidCallback? onDelete;

  @override
  Widget build(BuildContext context) {
    final top = MediaQuery.of(context).padding.top + 56;
    return Stack(
      children: [
        Positioned.fill(
          child: GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: onClose,
          ),
        ),
        Positioned(
          right: 16,
          top: top,
          child: _AnimatedAppear(
            child: Material(
              color: Colors.transparent,
              child: Container(
                width: 200,
                padding: const EdgeInsets.symmetric(vertical: 6),
                decoration: BoxDecoration(
                  color: AppColors.white,
                  borderRadius: BorderRadius.circular(18),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.18),
                      blurRadius: 24,
                      offset: const Offset(0, 12),
                    ),
                  ],
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (onEdit != null)
                      _MoreMenuRow(
                        icon: Icons.edit_outlined,
                        label: '수정하기',
                        onTap: onEdit!,
                      ),
                    if (onEdit != null && onDelete != null)
                      const Divider(
                        height: 8,
                        thickness: 1,
                        color: Color(0xFFF2F4F6),
                        indent: 8,
                        endIndent: 8,
                      ),
                    if (onDelete != null)
                      _MoreMenuRow(
                        icon: Icons.delete_outline_rounded,
                        label: '삭제하기',
                        iconColor: const Color(0xFFFF6B6B),
                        labelColor: const Color(0xFFFF6B6B),
                        iconBg: const Color(0xFFFFEDED),
                        onTap: onDelete!,
                      ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class _MoreMenuRow extends StatelessWidget {
  const _MoreMenuRow({
    required this.icon,
    required this.label,
    required this.onTap,
    this.iconColor = const Color(0xFF4E5968),
    this.labelColor = const Color(0xFF191F28),
    this.iconBg = const Color(0xFFF6F7F9),
  });
  final IconData icon;
  final String label;
  final VoidCallback onTap;
  final Color iconColor;
  final Color labelColor;
  final Color iconBg;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Padding(
        padding:
            const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
        child: Row(
          children: [
            Container(
              width: 32,
              height: 32,
              decoration: BoxDecoration(
                color: iconBg,
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(icon, size: 18, color: iconColor),
            ),
            const SizedBox(width: 12),
            Text(
              label,
              style: TextStyle(
                fontFamily: 'Inter',
                fontWeight: FontWeight.w600,
                fontSize: 15,
                color: labelColor,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _AnimatedAppear extends StatefulWidget {
  const _AnimatedAppear({required this.child});
  final Widget child;

  @override
  State<_AnimatedAppear> createState() => _AnimatedAppearState();
}

class _AnimatedAppearState extends State<_AnimatedAppear>
    with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 180),
  )..forward();

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _c,
      builder: (_, child) {
        final t = Curves.easeOut.transform(_c.value);
        return Opacity(
          opacity: t,
          child: Transform.scale(
            scale: 0.95 + 0.05 * t,
            alignment: Alignment.topRight,
            child: child,
          ),
        );
      },
      child: widget.child,
    );
  }
}
