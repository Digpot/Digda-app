import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../core/di.dart';
import '../../core/network/error_message.dart';
import '../../features/highlight/models/highlight_models.dart';
import '../../theme/colors.dart';
import '../../widgets/photo_view_screen.dart';
import '../../widgets/retrying_network_image.dart';

/// 월간 하이라이트 — "지난달의 디그팟".
///
/// 매월 1일 서버가 만들어 둔 결과를 한 편의 월간 리포트처럼 훑어본다.
/// 풀블리드 대표 사진 히어로 → 숫자 → 사람들 → 사진 캐러셀 → 기억에 남는 일기 → 이야기 → 마무리.
/// 상단에 떠 있는 월 선택 알약으로 이전 달을 오갈 수 있고, 일기 카드를 누르면 해당 일기로 이동한다.
class HighlightScreen extends StatefulWidget {
  const HighlightScreen({
    super.key,
    this.initialMonth,
    @visibleForTesting this.previewItems,
    @visibleForTesting this.previewDetail,
  });

  /// "yyyy-MM". 없으면 가장 최근 달.
  final String? initialMonth;

  /// 위젯 테스트용 — 서버 호출 없이 이 값으로 바로 그린다.
  final List<HighlightListItem>? previewItems;
  final HighlightDetail? previewDetail;

  @override
  State<HighlightScreen> createState() => _HighlightScreenState();
}

class _HighlightScreenState extends State<HighlightScreen> {
  static const _bg = Color(0xFFFFFAF6);
  static const _line = Color(0xFFF1E7E0);
  static const _peach = Color(0xFFFFEEE6);
  static const _coralSoft = Color(0xFFFFB8A8);
  static const _sun = Color(0xFFFBBF24);
  static const _weekdays = ['월', '화', '수', '목', '금', '토', '일'];
  static const _monthEn = [
    'JANUARY',
    'FEBRUARY',
    'MARCH',
    'APRIL',
    'MAY',
    'JUNE',
    'JULY',
    'AUGUST',
    'SEPTEMBER',
    'OCTOBER',
    'NOVEMBER',
    'DECEMBER',
  ];

  List<HighlightListItem> _items = const [];
  String? _selected;
  HighlightDetail? _detail;
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    if (widget.previewDetail != null) {
      setState(() {
        _items = widget.previewItems ?? const [];
        _selected = widget.previewDetail!.month;
        _detail = widget.previewDetail;
        _loading = false;
      });
      return;
    }
    final groupId = Di.activeGroup.groupRoomId;
    if (groupId == null) {
      setState(() {
        _loading = false;
        _error = '그룹 정보를 찾을 수 없어요';
      });
      return;
    }
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final items = await Di.highlightRepository.list(groupId);
      if (!mounted) return;
      final wanted = widget.initialMonth;
      final selected = items.any((e) => e.month == wanted)
          ? wanted
          : (items.isEmpty ? null : items.first.month);
      setState(() => _items = items);
      if (selected == null) {
        setState(() => _loading = false);
      } else {
        await _loadDetail(selected);
      }
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = errorMessageOf(e, fallback: '하이라이트를 불러오지 못했어요');
      });
    }
  }

  Future<void> _loadDetail(String month) async {
    final groupId = Di.activeGroup.groupRoomId;
    if (groupId == null) return;
    setState(() {
      _selected = month;
      _loading = true;
      _error = null;
    });
    try {
      final d = await Di.highlightRepository.detail(groupId, month);
      if (!mounted || _selected != month) return;
      setState(() {
        _detail = d;
        _loading = false;
      });
    } catch (e) {
      if (!mounted || _selected != month) return;
      setState(() {
        _detail = null;
        _loading = false;
        _error = errorMessageOf(e, fallback: '하이라이트를 불러오지 못했어요');
      });
    }
  }

  void _openDiary(HighlightDiary diary) {
    HapticFeedback.selectionClick();
    Navigator.of(context).pushNamed('/diary-detail', arguments: diary.diaryId);
  }

  @override
  Widget build(BuildContext context) {
    final hasHero = !_loading && _error == null && _detail != null;
    return AnnotatedRegion<SystemUiOverlayStyle>(
      // 히어로 위에서는 흰 아이콘, 그 외에는 어두운 아이콘.
      value: (hasHero ? SystemUiOverlayStyle.light : SystemUiOverlayStyle.dark)
          .copyWith(statusBarColor: Colors.transparent),
      child: Scaffold(
        backgroundColor: _bg,
        body: Stack(
          children: [
            Positioned.fill(child: _body()),
            _topBar(onHero: hasHero),
          ],
        ),
      ),
    );
  }

  // ── 상단: 떠 있는 뒤로가기 + 월 선택 알약 ──────────────────

  Widget _topBar({required bool onHero}) {
    final top = MediaQuery.of(context).padding.top;
    return Positioned(
      top: top + 8,
      left: 16,
      right: 16,
      child: Row(
        children: [
          _glass(
            onTap: () => Navigator.of(context).maybePop(),
            child: const Icon(Icons.arrow_back_ios_new_rounded,
                size: 16, color: AppColors.gray900),
          ),
          const SizedBox(width: 10),
          if (_items.isNotEmpty)
            Expanded(
              child: Container(
                height: 40,
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.92),
                  borderRadius: BorderRadius.circular(20),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.08),
                      blurRadius: 14,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: ListView.separated(
                  scrollDirection: Axis.horizontal,
                  padding:
                      const EdgeInsets.symmetric(horizontal: 6, vertical: 5),
                  itemCount: _items.length,
                  separatorBuilder: (_, __) => const SizedBox(width: 4),
                  itemBuilder: (_, i) {
                    final it = _items[i];
                    final on = it.month == _selected;
                    return GestureDetector(
                      onTap: on ? null : () => _loadDetail(it.month),
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 220),
                        padding: const EdgeInsets.symmetric(horizontal: 14),
                        alignment: Alignment.center,
                        decoration: BoxDecoration(
                          color: on ? AppColors.primary : Colors.transparent,
                          borderRadius: BorderRadius.circular(16),
                        ),
                        child: Text(
                          '${it.year}.${it.monthValue.toString().padLeft(2, '0')}',
                          style: TextStyle(
                            fontFamily: 'Inter',
                            fontSize: 13,
                            fontWeight: on ? FontWeight.w700 : FontWeight.w500,
                            color: on ? Colors.white : AppColors.gray600,
                          ),
                        ),
                      ),
                    );
                  },
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _glass({required VoidCallback onTap, required Widget child}) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 40,
        height: 40,
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.92),
          shape: BoxShape.circle,
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.08),
              blurRadius: 14,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: child,
      ),
    );
  }

  Widget _body() {
    if (_loading) {
      return const Center(
          child: CircularProgressIndicator(
              color: AppColors.primary, strokeWidth: 2));
    }
    if (_error != null) {
      return _message(_error!, actionLabel: '다시 시도', onAction: _load);
    }
    if (_items.isEmpty) {
      return _message('아직 도착한 하이라이트가 없어요.\n매월 1일, 지난달의 추억을 모아 전해드릴게요.');
    }
    final d = _detail;
    if (d == null) return const SizedBox.shrink();
    return _story(d);
  }

  Widget _message(String text, {String? actionLabel, VoidCallback? onAction}) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('📖', style: TextStyle(fontSize: 40)),
            const SizedBox(height: 14),
            Text(
              text,
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontFamily: 'Inter',
                fontSize: 14,
                height: 1.7,
                color: AppColors.gray600,
              ),
            ),
            if (actionLabel != null)
              TextButton(
                onPressed: onAction,
                child: Text(actionLabel,
                    style: const TextStyle(color: AppColors.primary)),
              ),
          ],
        ),
      ),
    );
  }

  // ── 본문 ──────────────────────────────────────────────────

  Widget _story(HighlightDetail d) {
    final sections = <Widget>[
      _numbers(d),
      _members(d),
      if (d.photos.isNotEmpty) _PhotoCarousel(photos: d.photos),
      if (d.featuredDiaries.isNotEmpty) _diaries(d),
      _storyBlock(d),
      _closing(d),
    ];
    return ListView.builder(
      key: ValueKey(d.month),
      padding: EdgeInsets.zero,
      itemCount: sections.length + 1,
      itemBuilder: (_, i) {
        if (i == 0) return _hero(d);
        final idx = i - 1;
        return _Reveal(
          child: Padding(
            padding: EdgeInsets.fromLTRB(
                24, idx == 0 ? 8 : 0, 24, idx == sections.length - 1 ? 56 : 44),
            child: sections[idx],
          ),
        );
      },
    );
  }

  Widget _hero(HighlightDetail d) {
    final h = MediaQuery.of(context).size.height * 0.62;
    final heroH = h.clamp(420.0, 560.0);
    return SizedBox(
      height: heroH + 28,
      child: Stack(
        children: [
          // 사진 / 폴백 그라데이션
          Positioned.fill(
            bottom: 28,
            child: d.coverImageUrl != null
                ? GestureDetector(
                    onTap: () =>
                        openPhotoViewer(context, images: [d.coverImageUrl!]),
                    child: RetryingNetworkImage(url: d.coverImageUrl!),
                  )
                : const _FallbackHero(),
          ),
          // 가독성용 그라데이션
          Positioned.fill(
            bottom: 28,
            child: IgnorePointer(
              child: DecoratedBox(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    stops: const [0, 0.35, 1],
                    colors: [
                      Colors.black.withValues(alpha: 0.28),
                      Colors.transparent,
                      Colors.black.withValues(alpha: 0.72),
                    ],
                  ),
                ),
              ),
            ),
          ),
          // 거대한 월 숫자 워터마크
          Positioned(
            right: 20,
            top: MediaQuery.of(context).padding.top + 64,
            child: IgnorePointer(
              child: Text(
                d.monthValue.toString().padLeft(2, '0'),
                style: TextStyle(
                  fontFamily: 'Inter',
                  fontWeight: FontWeight.w800,
                  fontSize: 120,
                  height: 1,
                  color: Colors.white.withValues(alpha: 0.22),
                ),
              ),
            ),
          ),
          // 타이틀
          Positioned(
            left: 24,
            right: 24,
            bottom: 56,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.2),
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(
                        color: Colors.white.withValues(alpha: 0.5), width: 1),
                  ),
                  child: Text(
                    '${_monthEn[(d.monthValue - 1).clamp(0, 11)]} ${d.year}',
                    style: const TextStyle(
                      fontFamily: 'Inter',
                      fontWeight: FontWeight.w700,
                      fontSize: 11,
                      letterSpacing: 1.6,
                      color: Colors.white,
                    ),
                  ),
                ),
                const SizedBox(height: 14),
                const Text(
                  '우리의 기록',
                  style: TextStyle(
                    fontFamily: 'Inter',
                    fontWeight: FontWeight.w800,
                    fontSize: 40,
                    height: 1.1,
                    color: Colors.white,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  '${d.groupRoomName} · ${d.totalDiaryCount}편의 일기',
                  style: TextStyle(
                    fontFamily: 'Inter',
                    fontSize: 14,
                    color: Colors.white.withValues(alpha: 0.9),
                  ),
                ),
              ],
            ),
          ),
          // 본문으로 이어지는 둥근 모서리
          Positioned(
            left: 0,
            right: 0,
            bottom: 0,
            child: Container(
              height: 28,
              decoration: const BoxDecoration(
                color: _bg,
                borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _numbers(HighlightDetail d) {
    final ratio =
        d.daysInMonth == 0 ? 0.0 : (d.activeDays / d.daysInMonth).clamp(0.0, 1.0);
    final facts = <(String, String, String)>[
      if (d.busiestWeekday != null &&
          d.busiestWeekday! >= 1 &&
          d.busiestWeekday! <= 7)
        ('📅', '가장 많은 요일', '${_weekdays[d.busiestWeekday! - 1]}요일'),
      if (d.topLocation != null) ('📍', '자주 간 곳', d.topLocation!),
    ];
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          padding: const EdgeInsets.all(22),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(26),
            boxShadow: [
              BoxShadow(
                color: AppColors.primary.withValues(alpha: 0.10),
                blurRadius: 28,
                offset: const Offset(0, 10),
              ),
            ],
          ),
          child: Row(
            children: [
              SizedBox(
                width: 108,
                height: 108,
                child: TweenAnimationBuilder<double>(
                  tween: Tween(begin: 0, end: ratio),
                  duration: const Duration(milliseconds: 1100),
                  curve: Curves.easeOutCubic,
                  builder: (_, v, __) => CustomPaint(
                    painter: _RingPainter(progress: v),
                    child: Center(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            '${d.activeDays}',
                            style: const TextStyle(
                              fontFamily: 'Inter',
                              fontWeight: FontWeight.w800,
                              fontSize: 26,
                              height: 1,
                              color: AppColors.gray900,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            '/ ${d.daysInMonth}일',
                            style: const TextStyle(
                              fontFamily: 'Inter',
                              fontSize: 11,
                              color: AppColors.gray500,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 22),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      '이달의 일기',
                      style: TextStyle(
                        fontFamily: 'Inter',
                        fontSize: 13,
                        color: AppColors.gray500,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        TweenAnimationBuilder<int>(
                          tween: IntTween(begin: 0, end: d.totalDiaryCount),
                          duration: const Duration(milliseconds: 1000),
                          curve: Curves.easeOutCubic,
                          builder: (_, v, __) => Text(
                            '$v',
                            style: const TextStyle(
                              fontFamily: 'Inter',
                              fontWeight: FontWeight.w800,
                              fontSize: 52,
                              height: 1,
                              color: AppColors.primary,
                            ),
                          ),
                        ),
                        const Padding(
                          padding: EdgeInsets.only(left: 4, bottom: 6),
                          child: Text(
                            '편',
                            style: TextStyle(
                              fontFamily: 'Inter',
                              fontWeight: FontWeight.w700,
                              fontSize: 18,
                              color: AppColors.gray900,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 6),
                    Text(
                      '${d.activeDays}일 동안 함께 기록했어요',
                      style: const TextStyle(
                        fontFamily: 'Inter',
                        fontSize: 12,
                        color: AppColors.gray600,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        if (facts.isNotEmpty) ...[
          const SizedBox(height: 12),
          Row(
            children: [
              for (var i = 0; i < facts.length; i++) ...[
                if (i > 0) const SizedBox(width: 12),
                Expanded(
                  child: Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: _peach,
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(facts[i].$1, style: const TextStyle(fontSize: 20)),
                        const SizedBox(height: 8),
                        Text(
                          facts[i].$2,
                          style: const TextStyle(
                            fontFamily: 'Inter',
                            fontSize: 12,
                            color: AppColors.gray600,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          facts[i].$3,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            fontFamily: 'Inter',
                            fontWeight: FontWeight.w800,
                            fontSize: 17,
                            color: AppColors.gray900,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ],
          ),
        ],
      ],
    );
  }

  Widget _sectionTitle(String t, {String? caption, String? emoji}) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              if (emoji != null) ...[
                Text(emoji, style: const TextStyle(fontSize: 20)),
                const SizedBox(width: 8),
              ],
              Text(
                t,
                style: const TextStyle(
                  fontFamily: 'Inter',
                  fontWeight: FontWeight.w800,
                  fontSize: 22,
                  color: AppColors.gray900,
                ),
              ),
            ],
          ),
          if (caption != null) ...[
            const SizedBox(height: 4),
            Text(
              caption,
              style: const TextStyle(
                fontFamily: 'Inter',
                fontSize: 13,
                color: AppColors.gray500,
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _members(HighlightDetail d) {
    final max =
        d.members.fold<int>(0, (m, e) => e.diaryCount > m ? e.diaryCount : m);
    final topIds = d.topWriters.map((e) => e.userId).toSet();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _sectionTitle('함께 쓴 사람들', emoji: '👥', caption: '누가 얼마나 기록했을까요'),
        for (final m in d.members)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 7),
            child: Row(
              children: [
                _avatar(m, crown: topIds.contains(m.userId)),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Flexible(
                            child: Text(
                              m.name,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                fontFamily: 'Inter',
                                fontWeight: FontWeight.w700,
                                fontSize: 15,
                                color: AppColors.gray900,
                              ),
                            ),
                          ),
                          if (topIds.contains(m.userId)) ...[
                            const SizedBox(width: 6),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 8, vertical: 2),
                              decoration: BoxDecoration(
                                gradient: const LinearGradient(
                                  colors: [AppColors.primary, _coralSoft],
                                ),
                                borderRadius: BorderRadius.circular(9),
                              ),
                              child: const Text(
                                '기록왕',
                                style: TextStyle(
                                  fontFamily: 'Inter',
                                  fontWeight: FontWeight.w700,
                                  fontSize: 10,
                                  color: Colors.white,
                                ),
                              ),
                            ),
                          ],
                        ],
                      ),
                      const SizedBox(height: 8),
                      TweenAnimationBuilder<double>(
                        tween: Tween(
                            begin: 0,
                            end: max == 0 ? 0 : m.diaryCount / max),
                        duration: const Duration(milliseconds: 900),
                        curve: Curves.easeOutCubic,
                        builder: (_, v, __) => ClipRRect(
                          borderRadius: BorderRadius.circular(4),
                          child: LinearProgressIndicator(
                            value: v,
                            minHeight: 7,
                            backgroundColor: _line,
                            color: topIds.contains(m.userId)
                                ? AppColors.primary
                                : _coralSoft,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 14),
                Text(
                  '${m.diaryCount}편',
                  style: const TextStyle(
                    fontFamily: 'Inter',
                    fontWeight: FontWeight.w700,
                    fontSize: 14,
                    color: AppColors.gray700,
                  ),
                ),
              ],
            ),
          ),
      ],
    );
  }

  Widget _avatar(HighlightMember m, {bool crown = false}) {
    final initial = m.name.isEmpty ? '?' : m.name.characters.first;
    return SizedBox(
      width: 46,
      height: 46,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          Container(
            width: 46,
            height: 46,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: _peach,
              border: Border.all(
                  color: crown ? _sun : Colors.white, width: crown ? 2.5 : 2),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.06),
                  blurRadius: 8,
                  offset: const Offset(0, 3),
                ),
              ],
            ),
            clipBehavior: Clip.antiAlias,
            alignment: Alignment.center,
            child: (m.profileImage != null && m.profileImage!.isNotEmpty)
                ? RetryingNetworkImage(
                    url: m.profileImage!,
                    width: 46,
                    height: 46,
                    fallback: _initialText(initial),
                  )
                : _initialText(initial),
          ),
          if (crown)
            const Positioned(
              top: -9,
              right: -4,
              child: Text('👑', style: TextStyle(fontSize: 16)),
            ),
        ],
      ),
    );
  }

  Widget _initialText(String s) => Text(
        s,
        style: const TextStyle(
          fontFamily: 'Inter',
          fontWeight: FontWeight.w800,
          fontSize: 16,
          color: AppColors.primary,
        ),
      );

  Widget _diaries(HighlightDetail d) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _sectionTitle('기억에 남는 일기',
            emoji: '💌', caption: '반응이 가장 뜨거웠던 순간들 · 눌러서 다시 읽어보세요'),
        for (var i = 0; i < d.featuredDiaries.length; i++)
          Padding(
            padding: EdgeInsets.only(
                bottom: i == d.featuredDiaries.length - 1 ? 0 : 16),
            child: _diaryCard(d.featuredDiaries[i], i),
          ),
      ],
    );
  }

  Widget _diaryCard(HighlightDiary diary, int rank) {
    const badges = ['가장 사랑받은 일기', '두 번째 추억', '세 번째 추억'];
    return GestureDetector(
      onTap: () => _openDiary(diary),
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(26),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.07),
              blurRadius: 24,
              offset: const Offset(0, 10),
            ),
          ],
        ),
        clipBehavior: Clip.antiAlias,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (diary.imageUrl != null)
              Stack(
                children: [
                  AspectRatio(
                    aspectRatio: 16 / 10,
                    child: RetryingNetworkImage(url: diary.imageUrl!),
                  ),
                  Positioned(
                    left: 14,
                    top: 14,
                    child: _rankChip(rank, badges[rank.clamp(0, 2)]),
                  ),
                ],
              ),
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 18, 20, 18),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (diary.imageUrl == null) ...[
                    _rankChip(rank, badges[rank.clamp(0, 2)]),
                    const SizedBox(height: 12),
                  ],
                  Text(
                    '${diary.date.replaceAll('-', '.')}  ·  ${diary.authorName}',
                    style: const TextStyle(
                      fontFamily: 'Inter',
                      fontSize: 12,
                      color: AppColors.gray500,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    diary.title,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontFamily: 'Inter',
                      fontWeight: FontWeight.w800,
                      fontSize: 19,
                      height: 1.3,
                      color: AppColors.gray900,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    diary.excerpt,
                    maxLines: 3,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontFamily: 'Inter',
                      fontSize: 14,
                      height: 1.7,
                      color: AppColors.gray700,
                    ),
                  ),
                  const SizedBox(height: 14),
                  Row(
                    children: [
                      if (diary.engagement > 0) ...[
                        _miniStat('♥', '${diary.likeCount + diary.reactionCount}'),
                        const SizedBox(width: 12),
                        _miniStat('💬', '${diary.commentCount}'),
                      ],
                      const Spacer(),
                      const Text(
                        '일기 보러가기',
                        style: TextStyle(
                          fontFamily: 'Inter',
                          fontWeight: FontWeight.w700,
                          fontSize: 12,
                          color: AppColors.primary,
                        ),
                      ),
                      const Icon(Icons.chevron_right_rounded,
                          size: 18, color: AppColors.primary),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _rankChip(int rank, String label) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 5),
      decoration: BoxDecoration(
        color: rank == 0 ? _sun : _peach,
        borderRadius: BorderRadius.circular(14),
      ),
      child: Text(
        rank == 0 ? '👑 $label' : label,
        style: TextStyle(
          fontFamily: 'Inter',
          fontWeight: FontWeight.w800,
          fontSize: 11,
          color: rank == 0 ? const Color(0xFF5B3A00) : AppColors.primary,
        ),
      ),
    );
  }

  Widget _miniStat(String icon, String value) => Row(
        children: [
          Text(icon,
              style: const TextStyle(fontSize: 13, color: AppColors.primary)),
          const SizedBox(width: 4),
          Text(
            value,
            style: const TextStyle(
              fontFamily: 'Inter',
              fontWeight: FontWeight.w700,
              fontSize: 13,
              color: AppColors.gray700,
            ),
          ),
        ],
      );

  Widget _storyBlock(HighlightDetail d) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(24, 20, 24, 28),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(28),
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFFFFF1EA), Color(0xFFFFE6EE)],
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '“',
            style: TextStyle(
              fontFamily: 'Inter',
              fontWeight: FontWeight.w800,
              fontSize: 64,
              height: 0.9,
              color: AppColors.primary.withValues(alpha: 0.55),
            ),
          ),
          const Text(
            '이달의 이야기',
            style: TextStyle(
              fontFamily: 'Inter',
              fontWeight: FontWeight.w800,
              fontSize: 13,
              letterSpacing: 0.6,
              color: AppColors.primary,
            ),
          ),
          const SizedBox(height: 12),
          Text(
            d.summary,
            style: const TextStyle(
              fontFamily: 'Inter',
              fontWeight: FontWeight.w600,
              fontSize: 17,
              height: 1.85,
              color: AppColors.gray900,
            ),
          ),
        ],
      ),
    );
  }

  Widget _closing(HighlightDetail d) {
    return Container(
      width: double.infinity,
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(28),
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [AppColors.primary, Color(0xFFFF8E72)],
        ),
        boxShadow: [
          BoxShadow(
            color: AppColors.primary.withValues(alpha: 0.35),
            blurRadius: 28,
            offset: const Offset(0, 12),
          ),
        ],
      ),
      child: Stack(
        children: [
          Positioned(
            right: -30,
            top: -30,
            child: _bubble(120, 0.14),
          ),
          Positioned(
            left: -20,
            bottom: -40,
            child: _bubble(110, 0.10),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 36, horizontal: 26),
            child: Column(
              children: [
                const Text('🍙', style: TextStyle(fontSize: 38)),
                const SizedBox(height: 14),
                Text(
                  d.closingMessage,
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    fontFamily: 'Inter',
                    fontWeight: FontWeight.w700,
                    fontSize: 16,
                    height: 1.75,
                    color: Colors.white,
                  ),
                ),
                const SizedBox(height: 18),
                Text(
                  'DIGDA POT',
                  style: TextStyle(
                    fontFamily: 'Inter',
                    fontWeight: FontWeight.w800,
                    fontSize: 11,
                    letterSpacing: 3,
                    color: Colors.white.withValues(alpha: 0.7),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _bubble(double size, double alpha) => Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: Colors.white.withValues(alpha: alpha),
        ),
      );
}

/// 대표 사진이 없을 때의 히어로 배경.
class _FallbackHero extends StatelessWidget {
  const _FallbackHero();

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFFFF8E72), AppColors.primary, Color(0xFFE5589E)],
        ),
      ),
      child: Stack(
        children: [
          Positioned(
            left: -50,
            top: 120,
            child: Container(
              width: 220,
              height: 220,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: Colors.white.withValues(alpha: 0.12),
              ),
            ),
          ),
          Positioned(
            right: -40,
            bottom: 60,
            child: Container(
              width: 160,
              height: 160,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: Colors.white.withValues(alpha: 0.10),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// 활동일 링 — 시작을 12시 방향으로, 둥근 끝의 코랄 그라데이션 호.
class _RingPainter extends CustomPainter {
  _RingPainter({required this.progress});

  final double progress;

  @override
  void paint(Canvas canvas, Size size) {
    const stroke = 11.0;
    final rect = Offset.zero & size;
    final arcRect = rect.deflate(stroke / 2);
    final track = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = stroke
      ..color = const Color(0xFFFFE9E0);
    canvas.drawArc(arcRect, 0, math.pi * 2, false, track);
    final sweep = math.pi * 2 * progress;
    if (sweep <= 0) return;
    final paint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = stroke
      ..strokeCap = StrokeCap.round
      ..shader = const SweepGradient(
        startAngle: -math.pi / 2,
        endAngle: math.pi * 1.5,
        colors: [Color(0xFFFF9A8B), AppColors.primary],
        transform: GradientRotation(-math.pi / 2),
      ).createShader(arcRect);
    canvas.drawArc(arcRect, -math.pi / 2, sweep, false, paint);
  }

  @override
  bool shouldRepaint(_RingPainter old) => old.progress != progress;
}

/// 이달의 사진 — 좌우로 넘기는 캐러셀. 가운데 사진이 크게 보인다.
class _PhotoCarousel extends StatefulWidget {
  const _PhotoCarousel({required this.photos});

  final List<String> photos;

  @override
  State<_PhotoCarousel> createState() => _PhotoCarouselState();
}

class _PhotoCarouselState extends State<_PhotoCarousel> {
  late final PageController _controller =
      PageController(viewportFraction: 0.74);
  double _page = 0;

  @override
  void initState() {
    super.initState();
    _controller.addListener(() {
      final p = _controller.page ?? 0;
      if (p != _page) setState(() => _page = p);
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final photos = widget.photos;
    // 본문 좌우 패딩(24)을 상쇄해 화면 끝까지 캐러셀이 닿게 한다.
    return Transform.translate(
      offset: Offset.zero,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Text('📸', style: TextStyle(fontSize: 20)),
              const SizedBox(width: 8),
              const Text(
                '이달의 사진',
                style: TextStyle(
                  fontFamily: 'Inter',
                  fontWeight: FontWeight.w800,
                  fontSize: 22,
                  color: AppColors.gray900,
                ),
              ),
              const Spacer(),
              Text(
                '${(_page.round() + 1).clamp(1, photos.length)} / ${photos.length}',
                style: const TextStyle(
                  fontFamily: 'Inter',
                  fontWeight: FontWeight.w600,
                  fontSize: 12,
                  color: AppColors.gray500,
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          const Text(
            '가장 사랑받은 순간들을 골랐어요',
            style: TextStyle(
                fontFamily: 'Inter', fontSize: 13, color: AppColors.gray500),
          ),
          const SizedBox(height: 16),
          SizedBox(
            height: 300,
            child: OverflowBox(
              maxWidth: MediaQuery.of(context).size.width,
              child: PageView.builder(
                controller: _controller,
                clipBehavior: Clip.none,
                itemCount: photos.length,
                itemBuilder: (_, i) {
                  final t = (1 - (_page - i).abs()).clamp(0.0, 1.0);
                  final scale = 0.88 + 0.12 * t;
                  return Transform.scale(
                    scale: scale,
                    child: GestureDetector(
                      onTap: () => openPhotoViewer(context,
                          images: photos, initialIndex: i),
                      child: Container(
                        margin: const EdgeInsets.symmetric(horizontal: 6),
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(26),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withValues(alpha: 0.10 * t),
                              blurRadius: 22,
                              offset: const Offset(0, 10),
                            ),
                          ],
                        ),
                        clipBehavior: Clip.antiAlias,
                        child: RetryingNetworkImage(url: photos[i]),
                      ),
                    ),
                  );
                },
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// 아래에서 위로 떠오르며 나타난다. 스크롤로 빌드되는 시점에 한 번 재생된다.
class _Reveal extends StatelessWidget {
  const _Reveal({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0, end: 1),
      duration: const Duration(milliseconds: 650),
      curve: Curves.easeOutCubic,
      builder: (_, v, c) => Opacity(
        opacity: v,
        child: Transform.translate(offset: Offset(0, 26 * (1 - v)), child: c),
      ),
      child: child,
    );
  }
}
