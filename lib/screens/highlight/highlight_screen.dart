import 'package:flutter/material.dart';

import '../../core/di.dart';
import '../../core/network/error_message.dart';
import '../../features/highlight/models/highlight_models.dart';
import '../../theme/colors.dart';
import '../../widgets/back_header.dart';
import '../../widgets/photo_view_screen.dart';
import '../../widgets/retrying_network_image.dart';

/// 월간 하이라이트 — "지난달의 디그팟". 매월 1일 서버가 만들어 둔 결과를 스토리처럼 훑어본다.
///
/// 상단 월 칩으로 이전 달 하이라이트를 오갈 수 있다. [initialMonth]("yyyy-MM") 가 없으면 가장 최근 달.
class HighlightScreen extends StatefulWidget {
  const HighlightScreen({super.key, this.initialMonth});

  final String? initialMonth;

  @override
  State<HighlightScreen> createState() => _HighlightScreenState();
}

class _HighlightScreenState extends State<HighlightScreen> {
  static const _ink = Color(0xFF2A1B2E);
  static const _coralLight = Color(0xFFFF9A8B);
  static const _weekdays = ['월', '화', '수', '목', '금', '토', '일'];

  List<HighlightListItem> _items = const [];
  String? _selected;
  HighlightDetail? _detail;
  bool _loading = true;
  bool _detailLoading = false;
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
      setState(() {
        _items = items;
        _selected = selected;
        _loading = false;
      });
      if (selected != null) await _loadDetail(selected);
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
      _detailLoading = true;
      _error = null;
    });
    try {
      final d = await Di.highlightRepository.detail(groupId, month);
      if (!mounted || _selected != month) return;
      setState(() {
        _detail = d;
        _detailLoading = false;
      });
    } catch (e) {
      if (!mounted || _selected != month) return;
      setState(() {
        _detail = null;
        _detailLoading = false;
        _error = errorMessageOf(e, fallback: '하이라이트를 불러오지 못했어요');
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _ink,
      body: SafeArea(
        child: Column(
          children: [
            const BackHeader(title: '지난달의 디그팟', dark: true),
            if (_items.length > 1) _monthChips(),
            Expanded(child: _body()),
          ],
        ),
      ),
    );
  }

  Widget _body() {
    if (_loading || _detailLoading) {
      return const Center(
          child: CircularProgressIndicator(color: AppColors.primary));
    }
    if (_error != null) {
      return _message(_error!, actionLabel: '다시 시도', onAction: _load);
    }
    if (_items.isEmpty) {
      return _message(
        '아직 도착한 하이라이트가 없어요.\n매월 1일, 지난달의 추억을 모아 보여드릴게요 📖',
      );
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
            Text(
              text,
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontFamily: 'Inter',
                fontSize: 14,
                height: 1.6,
                color: Colors.white70,
              ),
            ),
            if (actionLabel != null) ...[
              const SizedBox(height: 16),
              TextButton(
                onPressed: onAction,
                child: Text(actionLabel,
                    style: const TextStyle(color: AppColors.primary)),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _monthChips() {
    return SizedBox(
      height: 44,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 6),
        itemCount: _items.length,
        separatorBuilder: (_, __) => const SizedBox(width: 8),
        itemBuilder: (_, i) {
          final it = _items[i];
          final on = it.month == _selected;
          return GestureDetector(
            onTap: on ? null : () => _loadDetail(it.month),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 14),
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: on ? AppColors.primary : Colors.white12,
                borderRadius: BorderRadius.circular(16),
              ),
              child: Text(
                '${it.year}.${it.monthValue.toString().padLeft(2, '0')}',
                style: TextStyle(
                  fontFamily: 'Inter',
                  fontWeight: on ? FontWeight.w700 : FontWeight.w400,
                  fontSize: 12,
                  color: Colors.white,
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  // ── 스토리 본문 ─────────────────────────────────────────

  Widget _story(HighlightDetail d) {
    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 8, 20, 48),
      children: [
        _hero(d),
        const SizedBox(height: 28),
        _statCards(d),
        const SizedBox(height: 28),
        _membersSection(d),
        if (d.photos.isNotEmpty) ...[
          const SizedBox(height: 32),
          _title('이달의 사진'),
          const SizedBox(height: 12),
          _photos(d),
        ],
        if (d.featuredDiaries.isNotEmpty) ...[
          const SizedBox(height: 32),
          _title('기억에 남는 일기'),
          const SizedBox(height: 12),
          for (final diary in d.featuredDiaries) _diaryCard(diary),
        ],
        const SizedBox(height: 32),
        _title('이달의 이야기'),
        const SizedBox(height: 12),
        _panel(
          Text(
            d.summary,
            style: const TextStyle(
              fontFamily: 'Inter',
              fontSize: 14,
              height: 1.7,
              color: Colors.white,
            ),
          ),
        ),
        const SizedBox(height: 32),
        _closing(d),
      ],
    );
  }

  Widget _hero(HighlightDetail d) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(24),
      child: AspectRatio(
        aspectRatio: 4 / 5,
        child: Stack(
          fit: StackFit.expand,
          children: [
            if (d.coverImageUrl != null)
              RetryingNetworkImage(url: d.coverImageUrl!)
            else
              const DecoratedBox(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [AppColors.primary, _coralLight],
                  ),
                ),
              ),
            const DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [Color(0x33000000), Color(0xCC000000)],
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.end,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    d.groupRoomName,
                    style: const TextStyle(
                      fontFamily: 'Inter',
                      fontSize: 13,
                      color: Colors.white70,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    d.title,
                    style: const TextStyle(
                      fontFamily: 'Inter',
                      fontWeight: FontWeight.w700,
                      fontSize: 26,
                      height: 1.25,
                      color: Colors.white,
                    ),
                  ),
                  const SizedBox(height: 10),
                  Text(
                    '${d.totalDiaryCount}편의 일기가 쌓인 한 달',
                    style: const TextStyle(
                      fontFamily: 'Inter',
                      fontSize: 14,
                      color: Colors.white,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _statCards(HighlightDetail d) {
    final stats = <(String, String)>[
      ('전체 일기', '${d.totalDiaryCount}편'),
      ('기록한 날', '${d.activeDays}/${d.daysInMonth}일'),
      if (d.busiestWeekday != null &&
          d.busiestWeekday! >= 1 &&
          d.busiestWeekday! <= 7)
        ('가장 많은 요일', '${_weekdays[d.busiestWeekday! - 1]}요일'),
      if (d.topLocation != null) ('자주 간 곳', d.topLocation!),
    ];
    return Wrap(
      spacing: 10,
      runSpacing: 10,
      children: [
        for (final s in stats)
          Container(
            width: (MediaQuery.of(context).size.width - 40 - 10) / 2,
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white10,
              borderRadius: BorderRadius.circular(16),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(s.$1,
                    style: const TextStyle(
                        fontFamily: 'Inter',
                        fontSize: 12,
                        color: Colors.white60)),
                const SizedBox(height: 6),
                Text(
                  s.$2,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontFamily: 'Inter',
                    fontWeight: FontWeight.w700,
                    fontSize: 20,
                    color: Colors.white,
                  ),
                ),
              ],
            ),
          ),
      ],
    );
  }

  Widget _membersSection(HighlightDetail d) {
    final max = d.members.fold<int>(0, (m, e) => e.diaryCount > m ? e.diaryCount : m);
    final topIds = d.topWriters.map((e) => e.userId).toSet();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _title('우리의 기록 지분'),
        const SizedBox(height: 12),
        _panel(
          Column(
            children: [
              for (final m in d.members)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 6),
                  child: Row(
                    children: [
                      SizedBox(
                        width: 84,
                        child: Text(
                          '${topIds.contains(m.userId) ? '👑 ' : ''}${m.name}',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                              fontFamily: 'Inter',
                              fontSize: 13,
                              color: Colors.white),
                        ),
                      ),
                      Expanded(
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(6),
                          child: LinearProgressIndicator(
                            value: max == 0 ? 0 : m.diaryCount / max,
                            minHeight: 10,
                            backgroundColor: Colors.white12,
                            color: topIds.contains(m.userId)
                                ? AppColors.primary
                                : _coralLight,
                          ),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Text('${m.diaryCount}편',
                          style: const TextStyle(
                              fontFamily: 'Inter',
                              fontSize: 12,
                              color: Colors.white70)),
                    ],
                  ),
                ),
              if (d.topWriters.isNotEmpty) ...[
                const SizedBox(height: 8),
                Text(
                  '이달의 기록왕: ${d.topWriters.map((e) => e.name).join(', ')}',
                  style: const TextStyle(
                    fontFamily: 'Inter',
                    fontWeight: FontWeight.w700,
                    fontSize: 13,
                    color: _coralLight,
                  ),
                ),
              ],
            ],
          ),
        ),
      ],
    );
  }

  Widget _photos(HighlightDetail d) {
    return SizedBox(
      height: 150,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: d.photos.length,
        separatorBuilder: (_, __) => const SizedBox(width: 10),
        itemBuilder: (_, i) => GestureDetector(
          onTap: () =>
              openPhotoViewer(context, images: d.photos, initialIndex: i),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(14),
            child: SizedBox(
              width: 130,
              child: RetryingNetworkImage(url: d.photos[i]),
            ),
          ),
        ),
      ),
    );
  }

  Widget _diaryCard(HighlightDiary diary) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (diary.imageUrl != null)
            SizedBox(
              height: 160,
              width: double.infinity,
              child: RetryingNetworkImage(url: diary.imageUrl!),
            ),
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '${diary.date.replaceAll('-', '.')} · ${diary.authorName}',
                  style: const TextStyle(
                      fontFamily: 'Inter',
                      fontSize: 11,
                      color: AppColors.gray500),
                ),
                const SizedBox(height: 6),
                Text(
                  diary.title,
                  style: const TextStyle(
                    fontFamily: 'Inter',
                    fontWeight: FontWeight.w700,
                    fontSize: 16,
                    color: AppColors.gray900,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  diary.excerpt,
                  style: const TextStyle(
                    fontFamily: 'Inter',
                    fontSize: 13,
                    height: 1.6,
                    color: AppColors.gray700,
                  ),
                ),
                if (diary.engagement > 0) ...[
                  const SizedBox(height: 10),
                  Text(
                    '❤️ ${diary.likeCount + diary.reactionCount}  💬 ${diary.commentCount}',
                    style: const TextStyle(
                        fontFamily: 'Inter',
                        fontSize: 12,
                        color: AppColors.gray600),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _closing(HighlightDetail d) {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [AppColors.primary, _coralLight],
        ),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Column(
        children: [
          const Text('🍙', style: TextStyle(fontSize: 28)),
          const SizedBox(height: 10),
          Text(
            d.closingMessage,
            textAlign: TextAlign.center,
            style: const TextStyle(
              fontFamily: 'Inter',
              fontWeight: FontWeight.w700,
              fontSize: 15,
              height: 1.6,
              color: Colors.white,
            ),
          ),
        ],
      ),
    );
  }

  Widget _title(String t) => Text(
        t,
        style: const TextStyle(
          fontFamily: 'Inter',
          fontWeight: FontWeight.w700,
          fontSize: 17,
          color: Colors.white,
        ),
      );

  Widget _panel(Widget child) => Container(
        width: double.infinity,
        padding: const EdgeInsets.all(18),
        decoration: BoxDecoration(
          color: Colors.white10,
          borderRadius: BorderRadius.circular(16),
        ),
        child: child,
      );
}
