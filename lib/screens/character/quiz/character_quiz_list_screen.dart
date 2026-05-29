import 'package:flutter/material.dart';

import '../../../core/di.dart';
import '../../../core/network/error_message.dart';
import '../../../features/character/models/character_models.dart';
import '../../../theme/colors.dart';
import '../../../widgets/app_dialog.dart';
import 'character_quiz_create_screen.dart';

/// 그룹 퀴즈 목록. 무한 스크롤 페이지네이션 + FAB으로 만들기 진입.
class CharacterQuizListScreen extends StatefulWidget {
  const CharacterQuizListScreen({super.key});

  @override
  State<CharacterQuizListScreen> createState() =>
      _CharacterQuizListScreenState();
}

class _CharacterQuizListScreenState extends State<CharacterQuizListScreen> {
  final List<CharacterQuiz> _items = [];
  final ScrollController _scroll = ScrollController();

  int _page = 0;
  int _totalPages = 0;
  bool _loading = true;
  bool _loadingMore = false;
  String? _errorMessage;
  // 사진 퀴즈 만들기/잠금 표시를 위해 그룹의 디코 해금 여부를 함께 들고 있는다.
  // 응답 실패 시 보수적으로 false (사진 슬롯 잠금 노출).
  bool _dikoUnlocked = false;

  @override
  void initState() {
    super.initState();
    _scroll.addListener(_onScroll);
    WidgetsBinding.instance.addPostFrameCallback((_) => _fetchPage(0));
  }

  @override
  void dispose() {
    _scroll.dispose();
    super.dispose();
  }

  void _onScroll() {
    if (_scroll.position.pixels >= _scroll.position.maxScrollExtent - 200 &&
        !_loadingMore &&
        _page + 1 < _totalPages) {
      _fetchMore();
    }
  }

  Future<void> _fetchPage(int page) async {
    final groupRoomIdStr = Di.activeGroup.groupRoomId;
    if (groupRoomIdStr == null) {
      setState(() {
        _loading = false;
        _errorMessage = '그룹에 들어간 뒤 사용할 수 있어요.';
      });
      return;
    }
    final groupRoomId = int.tryParse(groupRoomIdStr);
    if (groupRoomId == null) {
      setState(() {
        _loading = false;
        _errorMessage = '활성 그룹을 확인할 수 없어요.';
      });
      return;
    }
    setState(() {
      if (_items.isEmpty) _loading = true;
      _errorMessage = null;
    });
    try {
      final result = await Di.characterRepository.listQuizzes(
        groupRoomId: groupRoomId,
        page: page,
        size: 20,
      );
      // 캐릭터 상태는 best-effort — 실패해도 목록은 보여준다 (dikoUnlocked=false 보수).
      bool dikoUnlocked = false;
      try {
        final state = await Di.characterRepository
            .getMyState(groupRoomId: groupRoomId);
        dikoUnlocked = state.dikoUnlocked;
      } catch (_) {}
      if (!mounted) return;
      setState(() {
        _items
          ..clear()
          ..addAll(result.items);
        _page = result.page;
        _totalPages = result.totalPages;
        _dikoUnlocked = dikoUnlocked;
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      if (_items.isNotEmpty) {
        setState(() => _loading = false);
        showAppSnackBar(context, '새로고침에 실패했어요.', isError: true);
      } else {
        setState(() {
          _loading = false;
          _errorMessage = errorMessageOf(e);
        });
      }
    }
  }

  Future<void> _fetchMore() async {
    final groupRoomIdStr = Di.activeGroup.groupRoomId;
    final groupRoomId = int.tryParse(groupRoomIdStr ?? '');
    if (groupRoomId == null) return;
    setState(() => _loadingMore = true);
    try {
      final result = await Di.characterRepository.listQuizzes(
        groupRoomId: groupRoomId,
        page: _page + 1,
        size: 20,
      );
      if (!mounted) return;
      setState(() {
        _items.addAll(result.items);
        _page = result.page;
        _totalPages = result.totalPages;
        _loadingMore = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _loadingMore = false);
      showErrorDialog(context, errorMessageOf(e));
    }
  }

  Future<void> _openCreate() async {
    final created = await Navigator.of(context).push<bool>(
      MaterialPageRoute(
        builder: (_) => CharacterQuizCreateScreen(dikoUnlocked: _dikoUnlocked),
      ),
    );
    if (created == true) _fetchPage(0);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.white,
      appBar: AppBar(
        backgroundColor: AppColors.white,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: AppColors.gray900),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: const Text(
          '퀴즈 목록',
          style: TextStyle(
            fontFamily: 'Inter',
            fontWeight: FontWeight.w700,
            fontSize: 17,
            color: AppColors.gray900,
          ),
        ),
        centerTitle: true,
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: _openCreate,
        backgroundColor: AppColors.primary,
        foregroundColor: Colors.white,
        elevation: 2,
        child: const Icon(Icons.add),
      ),
      body: _buildBody(),
    );
  }

  Widget _buildBody() {
    if (_loading) {
      return const Center(child: CircularProgressIndicator());
    }
    if (_errorMessage != null) {
      return _ErrorRetry(message: _errorMessage!, onRetry: () => _fetchPage(0));
    }
    if (_items.isEmpty) {
      return const _EmptyState();
    }
    // 날짜별 그룹화. 서버가 최신순으로 내려준다는 전제에서 순서를 유지하며
    // 같은 날짜끼리 연속된 카드 묶음으로 보여준다. createdAt 이 없으면 '날짜 없음'
    // 섹션으로 묶여 분리되지 않도록 fallback. (구버전 서버 호환)
    final sections = _groupByDate(_items);
    final flat = <_ListEntry>[];
    for (final section in sections) {
      flat.add(_ListEntry.header(section.label));
      for (final q in section.items) {
        flat.add(_ListEntry.quiz(q));
      }
    }
    return RefreshIndicator(
      onRefresh: () => _fetchPage(0),
      child: ListView.builder(
        controller: _scroll,
        padding: const EdgeInsets.fromLTRB(24, 4, 24, 100),
        itemCount: flat.length + (_loadingMore ? 1 : 0),
        itemBuilder: (_, i) {
          if (i == flat.length) {
            return const Padding(
              padding: EdgeInsets.symmetric(vertical: 16),
              child: Center(child: CircularProgressIndicator()),
            );
          }
          final entry = flat[i];
          return entry.header != null
              ? _DateHeader(label: entry.header!)
              : Padding(
                  padding: const EdgeInsets.only(bottom: 10),
                  child: _QuizCard(quiz: entry.quiz!),
                );
        },
      ),
    );
  }

  /// 최신순으로 정렬된 [items] 를 날짜별 섹션 리스트로 변환.
  /// createdAt 이 모두 null 인 응답은 1개 그룹으로 묶인다.
  List<_DateSection> _groupByDate(List<CharacterQuiz> items) {
    final today = DateTime.now();
    final result = <_DateSection>[];
    String? currentKey;
    for (final q in items) {
      final created = q.createdAt?.toLocal();
      final label = _labelFor(created, today);
      final key = label;
      if (key != currentKey) {
        result.add(_DateSection(label: label, items: []));
        currentKey = key;
      }
      result.last.items.add(q);
    }
    return result;
  }

  String _labelFor(DateTime? d, DateTime today) {
    if (d == null) return '날짜 없음';
    bool sameDay(DateTime a, DateTime b) =>
        a.year == b.year && a.month == b.month && a.day == b.day;
    final yesterday = today.subtract(const Duration(days: 1));
    if (sameDay(d, today)) return '오늘';
    if (sameDay(d, yesterday)) return '어제';
    return '${d.year}년 ${d.month}월 ${d.day}일';
  }
}

class _DateSection {
  _DateSection({required this.label, required this.items});
  final String label;
  final List<CharacterQuiz> items;
}

class _ListEntry {
  _ListEntry.header(String text)
      : header = text,
        quiz = null;
  _ListEntry.quiz(CharacterQuiz q)
      : header = null,
        quiz = q;
  final String? header;
  final CharacterQuiz? quiz;
}

class _DateHeader extends StatelessWidget {
  const _DateHeader({required this.label});
  final String label;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 16, bottom: 8),
      child: Row(
        children: [
          Text(
            label,
            style: const TextStyle(
              fontFamily: 'Inter',
              fontWeight: FontWeight.w700,
              fontSize: 13,
              color: AppColors.gray700,
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Container(
              height: 1,
              color: AppColors.gray100,
            ),
          ),
        ],
      ),
    );
  }
}

class _QuizCard extends StatelessWidget {
  const _QuizCard({required this.quiz});
  final CharacterQuiz quiz;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.gray50,
        borderRadius: BorderRadius.circular(14),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              _CategoryChip(quiz.categoryDisplayName),
              const SizedBox(width: 8),
              _ExpChip(quiz.expMultiplier),
              if (quiz.imageUrl != null) ...[
                const SizedBox(width: 8),
                const _ImageBadge(),
              ],
              const Spacer(),
              Text(
                quiz.authorName,
                style: const TextStyle(
                  fontFamily: 'Inter',
                  fontWeight: FontWeight.w400,
                  fontSize: 12,
                  color: AppColors.gray500,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          if (quiz.imageUrl != null) ...[
            ClipRRect(
              borderRadius: BorderRadius.circular(10),
              child: AspectRatio(
                aspectRatio: 16 / 9,
                child: Image.network(
                  quiz.imageUrl!,
                  fit: BoxFit.cover,
                  errorBuilder: (_, __, ___) => Container(
                    color: AppColors.gray100,
                    alignment: Alignment.center,
                    child: const Icon(Icons.broken_image_outlined,
                        color: AppColors.gray400, size: 28),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 10),
          ],
          Text(
            quiz.question,
            style: const TextStyle(
              fontFamily: 'Inter',
              fontWeight: FontWeight.w600,
              fontSize: 15,
              height: 1.4,
              color: AppColors.gray900,
            ),
          ),
          const SizedBox(height: 10),
          Wrap(
            spacing: 6,
            runSpacing: 6,
            children: List.generate(quiz.options.length, (i) {
              return Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                decoration: BoxDecoration(
                  color: AppColors.white,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: AppColors.gray200),
                ),
                child: Text(
                  '${i + 1}. ${quiz.options[i]}',
                  style: const TextStyle(
                    fontFamily: 'Inter',
                    fontWeight: FontWeight.w400,
                    fontSize: 12,
                    color: AppColors.gray700,
                  ),
                ),
              );
            }),
          ),
        ],
      ),
    );
  }
}

class _ImageBadge extends StatelessWidget {
  const _ImageBadge();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: const Color(0xFFEFE7FF),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: const Color(0xFFA78BFA)),
      ),
      child: const Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.image_outlined,
              size: 11, color: Color(0xFFA78BFA)),
          SizedBox(width: 3),
          Text(
            '사진',
            style: TextStyle(
              fontFamily: 'Inter',
              fontWeight: FontWeight.w700,
              fontSize: 11,
              color: Color(0xFFA78BFA),
            ),
          ),
        ],
      ),
    );
  }
}

class _CategoryChip extends StatelessWidget {
  const _CategoryChip(this.label);
  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: AppColors.primary.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        label,
        style: const TextStyle(
          fontFamily: 'Inter',
          fontWeight: FontWeight.w700,
          fontSize: 11,
          color: AppColors.primary,
        ),
      ),
    );
  }
}

class _ExpChip extends StatelessWidget {
  const _ExpChip(this.multiplier);
  final int multiplier;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: const Color(0xFFFFF7E2),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: const Color(0xFFFCD34D)),
      ),
      child: Text(
        'EXP x$multiplier',
        style: const TextStyle(
          fontFamily: 'Inter',
          fontWeight: FontWeight.w700,
          fontSize: 11,
          color: AppColors.gray900,
        ),
      ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  const _EmptyState();

  @override
  Widget build(BuildContext context) {
    return const Center(
      child: Padding(
        padding: EdgeInsets.symmetric(horizontal: 32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.quiz_outlined, size: 56, color: AppColors.gray400),
            SizedBox(height: 16),
            Text(
              '아직 퀴즈가 없어요.\n+ 버튼으로 첫 퀴즈를 만들어 보세요!',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontFamily: 'Inter',
                fontWeight: FontWeight.w500,
                fontSize: 14,
                height: 1.6,
                color: AppColors.gray700,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ErrorRetry extends StatelessWidget {
  const _ErrorRetry({required this.message, required this.onRetry});
  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.cloud_off, size: 40, color: AppColors.gray400),
            const SizedBox(height: 12),
            Text(
              message,
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
              onPressed: onRetry,
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
}
