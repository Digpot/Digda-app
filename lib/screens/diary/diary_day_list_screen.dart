import 'package:flutter/material.dart';

import '../../core/di.dart';
import '../../core/network/error_message.dart';
import '../../features/block/models/block_models.dart';
import '../../features/diary/diary_window.dart';
import '../../features/diary/models/diary_models.dart';
import '../../theme/colors.dart';
import '../../widgets/app_dialog.dart';
import '../../widgets/retrying_network_image.dart';

/// 특정 날짜의 그림일기 목록 — 캘린더에서 날짜를 탭하면 진입한다.
///
/// 2.0.0: 일기는 인당 하루 1편이라 하루에 그룹원 수만큼 쌓일 수 있다.
/// - 전체 일기를 먼저 쓴 순으로 나열하고, 대표 썸네일 일기는 테두리+우상단 ✔ 로 강조.
/// - 대표는 그룹원 누구나 변경 가능(카드의 ✔ 아이콘 탭).
/// - 내가 아직 안 쓴 날(작성 가능 기간 내)이면 하단에 작성 버튼 노출.
class DiaryDayListScreen extends StatefulWidget {
  const DiaryDayListScreen({super.key, required this.date});

  final DateTime date;

  @override
  State<DiaryDayListScreen> createState() => _DiaryDayListScreenState();
}

class _DiaryDayListScreenState extends State<DiaryDayListScreen> {
  bool _loading = true;
  String? _error;
  DiaryDayResult? _day;
  bool _changingRep = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  String? get _groupRoomId => Di.activeGroup.groupRoomId;

  Future<void> _load() async {
    final groupRoomId = _groupRoomId;
    if (groupRoomId == null) {
      setState(() {
        _loading = false;
        _error = '그룹에 들어간 뒤 사용할 수 있어요.';
      });
      return;
    }
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final day = await Di.diaryRepository.byDate(groupRoomId, widget.date);
      if (!mounted) return;
      setState(() {
        _day = day;
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = errorMessageOf(e);
        _loading = false;
      });
    }
  }

  /// 대표 썸네일 변경 — 그룹원 누구나. 확인 다이얼로그 후 서버 반영.
  Future<void> _changeRepresentative(DiarySummary diary) async {
    if (_changingRep) return;
    final groupRoomId = _groupRoomId;
    if (groupRoomId == null) return;

    final ok = await showDialog<bool>(
      context: context,
      builder: (dialogCtx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text(
          '대표 썸네일 변경',
          style: TextStyle(
            fontFamily: 'Inter',
            fontWeight: FontWeight.w700,
            fontSize: 17,
            color: AppColors.gray900,
          ),
        ),
        content: Text(
          '\'${diary.title}\' 일기를 이 날의 대표 썸네일로 지정할까요?\n캘린더에 이 일기가 표시돼요.',
          style: const TextStyle(
            fontFamily: 'Inter',
            fontWeight: FontWeight.w400,
            fontSize: 14,
            height: 1.5,
            color: AppColors.gray700,
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogCtx).pop(false),
            child: const Text(
              '취소',
              style: TextStyle(
                fontFamily: 'Inter',
                fontWeight: FontWeight.w500,
                fontSize: 14,
                color: AppColors.gray500,
              ),
            ),
          ),
          TextButton(
            onPressed: () => Navigator.of(dialogCtx).pop(true),
            child: const Text(
              '지정하기',
              style: TextStyle(
                fontFamily: 'Inter',
                fontWeight: FontWeight.w600,
                fontSize: 14,
                color: AppColors.primary,
              ),
            ),
          ),
        ],
      ),
    );
    if (ok != true || !mounted) return;

    setState(() => _changingRep = true);
    try {
      final day = await Di.diaryRepository.setRepresentative(
        groupRoomId,
        diary.id,
      );
      if (!mounted) return;
      setState(() {
        _day = day;
        _changingRep = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _changingRep = false);
      showErrorDialog(context, errorMessageOf(e));
    }
  }

  bool get _canWrite {
    final day = _day;
    if (day == null) return false;
    if (day.myDiaryId != null) return false; // 인당 하루 1편 — 이미 썼으면 숨김.
    final d = widget.date;
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final target = DateTime(d.year, d.month, d.day);
    if (target.isAfter(today)) return false;
    return isDiaryDateEditable(target);
  }

  void _openWrite() {
    Navigator.of(context)
        .pushNamed('/write-diary', arguments: widget.date)
        .then((_) {
      if (mounted) _load();
    });
  }

  void _openDetail(DiarySummary diary) {
    Navigator.of(context)
        .pushNamed('/diary-detail', arguments: diary.id)
        .then((_) {
      if (mounted) _load();
    });
  }

  @override
  Widget build(BuildContext context) {
    final d = widget.date;
    return Scaffold(
      backgroundColor: AppColors.white,
      appBar: AppBar(
        backgroundColor: AppColors.white,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: AppColors.gray900),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: Text(
          '${d.month}월 ${d.day}일 일기',
          style: const TextStyle(
            fontFamily: 'Inter',
            fontWeight: FontWeight.w700,
            fontSize: 17,
            color: AppColors.gray900,
          ),
        ),
        centerTitle: true,
      ),
      body: SafeArea(child: _buildBody()),
      bottomNavigationBar: _canWrite
          ? SafeArea(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(24, 8, 24, 16),
                child: SizedBox(
                  height: 52,
                  child: ElevatedButton(
                    onPressed: _openWrite,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.primary,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14),
                      ),
                      elevation: 0,
                    ),
                    child: const Text(
                      '나도 이 날 일기 쓰기',
                      style: TextStyle(
                        fontFamily: 'Inter',
                        fontWeight: FontWeight.w700,
                        fontSize: 15,
                        color: AppColors.white,
                      ),
                    ),
                  ),
                ),
              ),
            )
          : null,
    );
  }

  Widget _buildBody() {
    if (_loading) {
      return const Center(
        child: CircularProgressIndicator(color: AppColors.primary),
      );
    }
    if (_error != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.cloud_off, size: 40, color: AppColors.gray400),
              const SizedBox(height: 12),
              Text(
                _error!,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  fontFamily: 'Inter',
                  fontWeight: FontWeight.w500,
                  fontSize: 14,
                  color: AppColors.gray700,
                ),
              ),
              const SizedBox(height: 16),
              TextButton(
                onPressed: _load,
                child: const Text(
                  '다시 시도',
                  style: TextStyle(
                    fontFamily: 'Inter',
                    fontWeight: FontWeight.w700,
                    fontSize: 14,
                    color: AppColors.primary,
                  ),
                ),
              ),
            ],
          ),
        ),
      );
    }
    final day = _day;
    if (day == null || day.diaries.isEmpty) {
      return const Center(
        child: Text(
          '이 날 작성된 일기가 없어요',
          style: TextStyle(
            fontFamily: 'Inter',
            fontSize: 13,
            color: AppColors.gray500,
          ),
        ),
      );
    }
    return RefreshIndicator(
      onRefresh: _load,
      color: AppColors.primary,
      child: ListView.builder(
        padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
        itemCount: day.diaries.length + 1,
        itemBuilder: (context, i) {
          if (i == 0) {
            return Padding(
              padding: const EdgeInsets.only(bottom: 10, left: 4),
              child: Text(
                '총 ${day.diaries.length}편 · 대표 썸네일은 캘린더에 표시돼요',
                style: const TextStyle(
                  fontFamily: 'Inter',
                  fontWeight: FontWeight.w500,
                  fontSize: 12,
                  color: AppColors.gray500,
                ),
              ),
            );
          }
          final diary = day.diaries[i - 1];
          final isRep = diary.id == day.representativeDiaryId;
          return Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: _DayDiaryCard(
              diary: diary,
              isRepresentative: isRep,
              onTap: diary.hidden ? null : () => _openDetail(diary),
              onSetRepresentative:
                  (diary.hidden || isRep) ? null : () => _changeRepresentative(diary),
            ),
          );
        },
      ),
    );
  }
}

/// 하루 일기 1건 카드. 대표는 primary 테두리 + 우상단 ✔ 뱃지로 강조된다.
class _DayDiaryCard extends StatelessWidget {
  const _DayDiaryCard({
    required this.diary,
    required this.isRepresentative,
    this.onTap,
    this.onSetRepresentative,
  });

  final DiarySummary diary;
  final bool isRepresentative;
  final VoidCallback? onTap;

  /// null 이면 ✔ 지정 버튼을 숨긴다(이미 대표이거나 숨김 일기).
  final VoidCallback? onSetRepresentative;

  static const _moodEmojis = ['😊', '😌', '😢', '😠', '😪'];

  String _emojiOf(int mood) =>
      (mood >= 0 && mood < _moodEmojis.length) ? _moodEmojis[mood] : '😊';

  @override
  Widget build(BuildContext context) {
    final hidden = diary.hidden;
    return Container(
      decoration: BoxDecoration(
        color: AppColors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isRepresentative ? AppColors.primary : AppColors.gray100,
          width: isRepresentative ? 2 : 1,
        ),
        boxShadow: [
          BoxShadow(
            color: AppColors.gray900.withValues(alpha: 0.04),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      clipBehavior: Clip.antiAlias,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(16),
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.all(14),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // 썸네일 — 사진 없으면 기분 이모지 타일.
                ClipRRect(
                  borderRadius: BorderRadius.circular(12),
                  child: SizedBox(
                    width: 64,
                    height: 64,
                    child: (!hidden &&
                            diary.thumbnailUrl != null &&
                            diary.thumbnailUrl!.isNotEmpty)
                        ? RetryingNetworkImage(
                            url: diary.thumbnailUrl!,
                            width: 64,
                            height: 64,
                            fit: BoxFit.cover,
                            fallback: _emojiTile(diary.mood),
                          )
                        : _emojiTile(diary.mood),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          if (isRepresentative) ...[
                            Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 7, vertical: 2),
                              decoration: BoxDecoration(
                                color:
                                    AppColors.primary.withValues(alpha: 0.10),
                                borderRadius: BorderRadius.circular(999),
                              ),
                              child: const Text(
                                '대표',
                                style: TextStyle(
                                  fontFamily: 'Inter',
                                  fontWeight: FontWeight.w700,
                                  fontSize: 10,
                                  color: AppColors.primary,
                                ),
                              ),
                            ),
                            const SizedBox(width: 6),
                          ],
                          Expanded(
                            child: Text(
                              hidden
                                  ? hiddenReasonMessage(diary.hiddenReason,
                                      noun: '일기')
                                  : diary.title,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                fontFamily: 'Inter',
                                fontWeight: FontWeight.w700,
                                fontSize: 15,
                                color: hidden
                                    ? AppColors.gray500
                                    : AppColors.gray900,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 6),
                      Row(
                        children: [
                          Text(_emojiOf(diary.mood),
                              style: const TextStyle(fontSize: 13)),
                          const SizedBox(width: 6),
                          Expanded(
                            child: Text(
                              diary.createdBy.name,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                fontFamily: 'Inter',
                                fontWeight: FontWeight.w500,
                                fontSize: 12,
                                color: AppColors.gray500,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 6),
                      Row(
                        children: [
                          const Icon(Icons.favorite,
                              size: 12, color: AppColors.gray400),
                          const SizedBox(width: 3),
                          Text(
                            '${diary.likeCount}',
                            style: const TextStyle(
                              fontFamily: 'Inter',
                              fontSize: 11,
                              color: AppColors.gray500,
                            ),
                          ),
                          const SizedBox(width: 10),
                          const Icon(Icons.chat_bubble,
                              size: 11, color: AppColors.gray400),
                          const SizedBox(width: 3),
                          Text(
                            '${diary.commentCount}',
                            style: const TextStyle(
                              fontFamily: 'Inter',
                              fontSize: 11,
                              color: AppColors.gray500,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                // 우상단 체크 — 대표는 채워진 ✔, 아니면 탭해서 대표로 지정.
                if (isRepresentative)
                  const Icon(Icons.check_circle_rounded,
                      size: 24, color: AppColors.primary)
                else if (onSetRepresentative != null)
                  GestureDetector(
                    behavior: HitTestBehavior.opaque,
                    onTap: onSetRepresentative,
                    child: const Padding(
                      padding: EdgeInsets.all(2),
                      child: Icon(Icons.check_circle_outline_rounded,
                          size: 24, color: AppColors.gray300),
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _emojiTile(int mood) {
    return Container(
      color: AppColors.gray50,
      alignment: Alignment.center,
      child: Text(_emojiOf(mood), style: const TextStyle(fontSize: 26)),
    );
  }
}
