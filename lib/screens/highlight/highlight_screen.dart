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
/// 매월 1일 서버가 만들어 둔 결과를 한 장의 리포트처럼 훑어본다. 밝은 바탕, 코랄 한 가지 포인트,
/// 박스 대신 여백과 얇은 선으로 구성한다. 상단 월 탭으로 이전 달을 오갈 수 있다.
class HighlightScreen extends StatefulWidget {
  const HighlightScreen({super.key, this.initialMonth});

  /// "yyyy-MM". 없으면 가장 최근 달.
  final String? initialMonth;

  @override
  State<HighlightScreen> createState() => _HighlightScreenState();
}

class _HighlightScreenState extends State<HighlightScreen> {
  static const _bg = Color(0xFFFFFBF8);
  static const _line = Color(0xFFEFE7E1);
  static const _peach = Color(0xFFFFEEE6);
  static const _weekdays = ['월', '화', '수', '목', '금', '토', '일'];

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

  @override
  Widget build(BuildContext context) {
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle.dark.copyWith(
        statusBarColor: Colors.transparent,
        statusBarIconBrightness: Brightness.dark,
        statusBarBrightness: Brightness.light,
      ),
      child: Scaffold(
        backgroundColor: _bg,
        body: SafeArea(
          child: Column(
            children: [
              _topBar(),
              Expanded(child: _body()),
            ],
          ),
        ),
      ),
    );
  }

  // ── 상단: 뒤로가기 + 월 탭 ─────────────────────────────────

  Widget _topBar() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(8, 4, 20, 0),
      child: Row(
        children: [
          IconButton(
            onPressed: () => Navigator.of(context).maybePop(),
            icon: const Icon(Icons.arrow_back_ios_new_rounded,
                size: 18, color: AppColors.gray900),
          ),
          Expanded(
            child: SizedBox(
              height: 40,
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                reverse: false,
                itemCount: _items.length,
                separatorBuilder: (_, __) => const SizedBox(width: 20),
                itemBuilder: (_, i) {
                  final it = _items[i];
                  final on = it.month == _selected;
                  return GestureDetector(
                    behavior: HitTestBehavior.opaque,
                    onTap: on ? null : () => _loadDetail(it.month),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(
                          '${it.year}.${it.monthValue.toString().padLeft(2, '0')}',
                          style: TextStyle(
                            fontFamily: 'Inter',
                            fontSize: 14,
                            fontWeight: on ? FontWeight.w700 : FontWeight.w400,
                            color: on ? AppColors.gray900 : AppColors.gray400,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Container(
                          width: 4,
                          height: 4,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: on ? AppColors.primary : Colors.transparent,
                          ),
                        ),
                      ],
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
            const Text('📖', style: TextStyle(fontSize: 36)),
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
      _hero(d),
      _numbers(d),
      _members(d),
      if (d.photos.isNotEmpty) _photos(d),
      if (d.featuredDiaries.isNotEmpty) _diaries(d),
      _story2(d),
      _closing(d),
    ];
    return ListView.builder(
      key: ValueKey(d.month),
      padding: const EdgeInsets.fromLTRB(24, 12, 24, 56),
      itemCount: sections.length,
      itemBuilder: (_, i) => _Reveal(
        index: i,
        child: Padding(
          padding: EdgeInsets.only(bottom: i == sections.length - 1 ? 0 : 44),
          child: sections[i],
        ),
      ),
    );
  }

  Widget _hero(HighlightDetail d) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          '${d.year}년 ${d.monthValue}월',
          style: const TextStyle(
            fontFamily: 'Inter',
            fontWeight: FontWeight.w700,
            fontSize: 14,
            letterSpacing: 0.4,
            color: AppColors.primary,
          ),
        ),
        const SizedBox(height: 8),
        const Text(
          '우리의 기록',
          style: TextStyle(
            fontFamily: 'Inter',
            fontWeight: FontWeight.w800,
            fontSize: 34,
            height: 1.15,
            color: AppColors.gray900,
          ),
        ),
        const SizedBox(height: 6),
        Text(
          d.groupRoomName,
          style: const TextStyle(
            fontFamily: 'Inter',
            fontSize: 14,
            color: AppColors.gray500,
          ),
        ),
        const SizedBox(height: 22),
        ClipRRect(
          borderRadius: BorderRadius.circular(24),
          child: AspectRatio(
            aspectRatio: 4 / 3,
            child: d.coverImageUrl != null
                ? GestureDetector(
                    onTap: () => openPhotoViewer(context,
                        images: [d.coverImageUrl!]),
                    child: RetryingNetworkImage(url: d.coverImageUrl!),
                  )
                : Container(
                    color: _peach,
                    alignment: Alignment.center,
                    child: const Text('📖', style: TextStyle(fontSize: 48)),
                  ),
          ),
        ),
      ],
    );
  }

  Widget _numbers(HighlightDetail d) {
    final facts = <(String, String)>[
      ('기록한 날', '${d.activeDays}일'),
      if (d.busiestWeekday != null &&
          d.busiestWeekday! >= 1 &&
          d.busiestWeekday! <= 7)
        ('가장 많은 요일', _weekdays[d.busiestWeekday! - 1]),
      if (d.topLocation != null) ('자주 간 곳', d.topLocation!),
    ];
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Text(
              '${d.totalDiaryCount}',
              style: const TextStyle(
                fontFamily: 'Inter',
                fontWeight: FontWeight.w800,
                fontSize: 64,
                height: 1,
                color: AppColors.primary,
              ),
            ),
            const SizedBox(width: 8),
            const Padding(
              padding: EdgeInsets.only(bottom: 8),
              child: Text(
                '편의 일기를 함께 남겼어요',
                style: TextStyle(
                  fontFamily: 'Inter',
                  fontSize: 15,
                  color: AppColors.gray700,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 24),
        Container(height: 1, color: _line),
        IntrinsicHeight(
          child: Row(
            children: [
              for (var i = 0; i < facts.length; i++) ...[
                if (i > 0) Container(width: 1, color: _line),
                Expanded(
                  child: Padding(
                    padding: EdgeInsets.fromLTRB(i == 0 ? 0 : 16, 16, 8, 16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          facts[i].$1,
                          style: const TextStyle(
                            fontFamily: 'Inter',
                            fontSize: 12,
                            color: AppColors.gray500,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          facts[i].$2,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            fontFamily: 'Inter',
                            fontWeight: FontWeight.w700,
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
        ),
        Container(height: 1, color: _line),
      ],
    );
  }

  Widget _sectionTitle(String t, {String? caption}) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            t,
            style: const TextStyle(
              fontFamily: 'Inter',
              fontWeight: FontWeight.w800,
              fontSize: 20,
              color: AppColors.gray900,
            ),
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
        _sectionTitle('함께 쓴 사람들'),
        for (final m in d.members)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 8),
            child: Row(
              children: [
                _avatar(m),
                const SizedBox(width: 12),
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
                                fontWeight: FontWeight.w600,
                                fontSize: 14,
                                color: AppColors.gray900,
                              ),
                            ),
                          ),
                          if (topIds.contains(m.userId)) ...[
                            const SizedBox(width: 6),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 7, vertical: 2),
                              decoration: BoxDecoration(
                                color: _peach,
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: const Text(
                                '기록왕',
                                style: TextStyle(
                                  fontFamily: 'Inter',
                                  fontWeight: FontWeight.w700,
                                  fontSize: 10,
                                  color: AppColors.primary,
                                ),
                              ),
                            ),
                          ],
                        ],
                      ),
                      const SizedBox(height: 6),
                      ClipRRect(
                        borderRadius: BorderRadius.circular(3),
                        child: LinearProgressIndicator(
                          value: max == 0 ? 0 : m.diaryCount / max,
                          minHeight: 4,
                          backgroundColor: _line,
                          color: topIds.contains(m.userId)
                              ? AppColors.primary
                              : const Color(0xFFFFB8A8),
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
                    fontWeight: FontWeight.w600,
                    fontSize: 13,
                    color: AppColors.gray700,
                  ),
                ),
              ],
            ),
          ),
      ],
    );
  }

  Widget _avatar(HighlightMember m) {
    final initial = m.name.isEmpty ? '?' : m.name.characters.first;
    return Container(
      width: 36,
      height: 36,
      decoration: const BoxDecoration(shape: BoxShape.circle, color: _peach),
      clipBehavior: Clip.antiAlias,
      alignment: Alignment.center,
      child: (m.profileImage != null && m.profileImage!.isNotEmpty)
          ? RetryingNetworkImage(
              url: m.profileImage!,
              width: 36,
              height: 36,
              fallback: _initialText(initial),
            )
          : _initialText(initial),
    );
  }

  Widget _initialText(String s) => Text(
        s,
        style: const TextStyle(
          fontFamily: 'Inter',
          fontWeight: FontWeight.w700,
          fontSize: 14,
          color: AppColors.primary,
        ),
      );

  Widget _photos(HighlightDetail d) {
    final p = d.photos;
    Widget tile(int i, {double? aspect}) => GestureDetector(
          onTap: () => openPhotoViewer(context, images: p, initialIndex: i),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(16),
            child: AspectRatio(
              aspectRatio: aspect ?? 1,
              child: RetryingNetworkImage(url: p[i]),
            ),
          ),
        );
    final rest = <Widget>[];
    for (var i = 1; i < p.length; i += 2) {
      rest.add(Padding(
        padding: const EdgeInsets.only(top: 10),
        child: Row(
          children: [
            Expanded(child: tile(i)),
            const SizedBox(width: 10),
            Expanded(child: i + 1 < p.length ? tile(i + 1) : const SizedBox()),
          ],
        ),
      ));
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _sectionTitle('이달의 사진', caption: '사진 ${p.length}장을 골랐어요'),
        tile(0, aspect: 16 / 10),
        ...rest,
      ],
    );
  }

  Widget _diaries(HighlightDetail d) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _sectionTitle('기억에 남는 일기', caption: '반응이 가장 뜨거웠던 순간들'),
        for (var i = 0; i < d.featuredDiaries.length; i++) ...[
          if (i > 0) Container(height: 1, color: _line),
          _diaryRow(d.featuredDiaries[i]),
        ],
      ],
    );
  }

  Widget _diaryRow(HighlightDiary diary) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 18),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
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
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontFamily: 'Inter',
                    fontWeight: FontWeight.w700,
                    fontSize: 17,
                    color: AppColors.gray900,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  diary.excerpt,
                  maxLines: 3,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontFamily: 'Inter',
                    fontSize: 13,
                    height: 1.65,
                    color: AppColors.gray700,
                  ),
                ),
                if (diary.engagement > 0) ...[
                  const SizedBox(height: 8),
                  Text(
                    '♥ ${diary.likeCount + diary.reactionCount}   댓글 ${diary.commentCount}',
                    style: const TextStyle(
                      fontFamily: 'Inter',
                      fontSize: 12,
                      color: AppColors.primary,
                    ),
                  ),
                ],
              ],
            ),
          ),
          if (diary.imageUrl != null) ...[
            const SizedBox(width: 14),
            ClipRRect(
              borderRadius: BorderRadius.circular(14),
              child: SizedBox(
                width: 84,
                height: 84,
                child: RetryingNetworkImage(url: diary.imageUrl!),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _story2(HighlightDetail d) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: 28,
          height: 3,
          decoration: BoxDecoration(
            color: AppColors.primary,
            borderRadius: BorderRadius.circular(2),
          ),
        ),
        const SizedBox(height: 16),
        Text(
          d.summary,
          style: const TextStyle(
            fontFamily: 'Inter',
            fontWeight: FontWeight.w500,
            fontSize: 17,
            height: 1.85,
            color: AppColors.gray900,
          ),
        ),
      ],
    );
  }

  Widget _closing(HighlightDetail d) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(vertical: 32, horizontal: 24),
      decoration: BoxDecoration(
        color: _peach,
        borderRadius: BorderRadius.circular(24),
      ),
      child: Column(
        children: [
          const Text('🍙', style: TextStyle(fontSize: 26)),
          const SizedBox(height: 12),
          Text(
            d.closingMessage,
            textAlign: TextAlign.center,
            style: const TextStyle(
              fontFamily: 'Inter',
              fontWeight: FontWeight.w600,
              fontSize: 15,
              height: 1.7,
              color: AppColors.gray900,
            ),
          ),
        ],
      ),
    );
  }
}

/// 위에서 아래로 차례로 떠오르는 등장 효과. [index] 가 클수록 조금 늦게 끝난다.
class _Reveal extends StatelessWidget {
  const _Reveal({required this.index, required this.child});

  final int index;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0, end: 1),
      duration: Duration(milliseconds: 420 + (index > 6 ? 6 : index) * 90),
      curve: Curves.easeOutCubic,
      builder: (_, v, c) => Opacity(
        opacity: v,
        child: Transform.translate(offset: Offset(0, 18 * (1 - v)), child: c),
      ),
      child: child,
    );
  }
}
