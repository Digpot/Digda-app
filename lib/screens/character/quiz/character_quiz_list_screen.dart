import 'package:flutter/material.dart';

import '../../../core/di.dart';
import '../../../core/network/error_message.dart';
import '../../../features/character/models/character_models.dart';
import '../../../theme/colors.dart';
import '../../../widgets/app_dialog.dart';
import 'character_quiz_create_screen.dart';
import 'character_quiz_play_screen.dart';

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
  final TextEditingController _searchCtrl = TextEditingController();

  /// 접힌 날짜 섹션 라벨(노션식 토글). 비어있으면 전부 펼침.
  final Set<String> _collapsed = {};
  String _query = '';

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
    _searchCtrl.dispose();
    super.dispose();
  }

  /// 검색어로 로드된 퀴즈를 필터(질문/선택지/출제자/카테고리).
  List<CharacterQuiz> _applyQuery(List<CharacterQuiz> items) {
    final q = _query.trim().toLowerCase();
    if (q.isEmpty) return items;
    return items.where((quiz) {
      return quiz.question.toLowerCase().contains(q) ||
          quiz.authorName.toLowerCase().contains(q) ||
          quiz.categoryDisplayName.toLowerCase().contains(q) ||
          quiz.options.any((o) => o.toLowerCase().contains(q));
    }).toList();
  }

  /// 목록에서 특정 퀴즈를 '연습(재풀이)' 모드로 푼다(경험치 없음).
  Future<void> _openPractice(CharacterQuiz quiz) async {
    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => CharacterQuizPlayScreen(practiceQuiz: quiz),
      ),
    );
    // 연습은 목록·기록에 영향이 없어 새로고침 불필요.
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
        centerTitle: false,
        titleSpacing: 0,
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _openCreate,
        backgroundColor: AppColors.primary,
        foregroundColor: Colors.white,
        elevation: 2,
        icon: const Icon(Icons.add_rounded),
        label: const Text(
          '퀴즈 만들기',
          style: TextStyle(
            fontFamily: 'Inter',
            fontWeight: FontWeight.w700,
            fontSize: 14,
          ),
        ),
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
    return Column(
      children: [
        _SearchField(
          controller: _searchCtrl,
          onChanged: (v) => setState(() => _query = v),
          onClear: () => setState(() {
            _searchCtrl.clear();
            _query = '';
          }),
        ),
        Expanded(child: _buildList()),
      ],
    );
  }

  Widget _buildList() {
    final filtered = _applyQuery(_items);
    if (filtered.isEmpty) {
      return _NoSearchResult(query: _query);
    }
    // 날짜별 그룹화(최신순 유지). 각 섹션은 노션식 토글로 접을 수 있다.
    final sections = _groupByDate(filtered);
    final flat = <_ListEntry>[];
    final searching = _query.trim().isNotEmpty;
    for (final section in sections) {
      flat.add(_ListEntry.header(section.label, section.items.length));
      // 검색 중에는 접힘을 무시하고 모든 매칭 결과를 펼쳐 보여준다.
      if (searching || !_collapsed.contains(section.label)) {
        for (final q in section.items) {
          flat.add(_ListEntry.quiz(q));
        }
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
          if (entry.header != null) {
            final label = entry.header!;
            return _SectionToggle(
              label: label,
              count: entry.count,
              // 검색 중엔 항상 펼쳐 보이므로 셰브론도 펼침 상태로.
              collapsed: !searching && _collapsed.contains(label),
              onTap: () => setState(() {
                if (_collapsed.contains(label)) {
                  _collapsed.remove(label);
                } else {
                  _collapsed.add(label);
                }
              }),
            );
          }
          return Padding(
            padding: const EdgeInsets.only(bottom: 10),
            child: _QuizCard(
              quiz: entry.quiz!,
              onTap: () => _openPractice(entry.quiz!),
            ),
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
  _ListEntry.header(this.header, this.count) : quiz = null;
  _ListEntry.quiz(this.quiz)
      : header = null,
        count = 0;
  final String? header;
  final int count;
  final CharacterQuiz? quiz;
}

/// 노션식 날짜 토글 헤더 — 탭하면 그 날짜 섹션을 접고/펼친다.
class _SectionToggle extends StatelessWidget {
  const _SectionToggle({
    required this.label,
    required this.count,
    required this.collapsed,
    required this.onTap,
  });
  final String label;
  final int count;
  final bool collapsed;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 12, bottom: 4),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(8),
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 6),
            child: Row(
              children: [
                AnimatedRotation(
                  // 펼침=아래(▼), 접힘=오른쪽(▶).
                  turns: collapsed ? -0.25 : 0,
                  duration: const Duration(milliseconds: 180),
                  child: const Icon(Icons.keyboard_arrow_down_rounded,
                      size: 22, color: AppColors.gray700),
                ),
                const SizedBox(width: 4),
                Text(
                  label,
                  style: const TextStyle(
                    fontFamily: 'Inter',
                    fontWeight: FontWeight.w700,
                    fontSize: 13,
                    color: AppColors.gray900,
                  ),
                ),
                const SizedBox(width: 6),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                  decoration: BoxDecoration(
                    color: AppColors.gray100,
                    borderRadius: BorderRadius.circular(999),
                  ),
                  child: Text(
                    '$count',
                    style: const TextStyle(
                      fontFamily: 'Inter',
                      fontWeight: FontWeight.w700,
                      fontSize: 11,
                      color: AppColors.gray500,
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(child: Container(height: 1, color: AppColors.gray100)),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// 퀴즈 검색창.
class _SearchField extends StatelessWidget {
  const _SearchField({
    required this.controller,
    required this.onChanged,
    required this.onClear,
  });
  final TextEditingController controller;
  final ValueChanged<String> onChanged;
  final VoidCallback onClear;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 6, 24, 4),
      child: Container(
        decoration: BoxDecoration(
          color: AppColors.gray50,
          borderRadius: BorderRadius.circular(12),
        ),
        child: TextField(
          controller: controller,
          onChanged: onChanged,
          textInputAction: TextInputAction.search,
          style: const TextStyle(
            fontFamily: 'Inter',
            fontSize: 14,
            color: AppColors.gray900,
          ),
          decoration: InputDecoration(
            isDense: true,
            hintText: '질문·선택지·출제자 검색',
            hintStyle: const TextStyle(
              fontFamily: 'Inter',
              fontSize: 14,
              color: AppColors.gray400,
            ),
            prefixIcon:
                const Icon(Icons.search, size: 20, color: AppColors.gray400),
            suffixIcon: controller.text.isEmpty
                ? null
                : IconButton(
                    icon: const Icon(Icons.close,
                        size: 18, color: AppColors.gray400),
                    onPressed: onClear,
                  ),
            border: InputBorder.none,
            contentPadding:
                const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
          ),
        ),
      ),
    );
  }
}

/// 검색 결과 없음.
class _NoSearchResult extends StatelessWidget {
  const _NoSearchResult({required this.query});
  final String query;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.search_off, size: 44, color: AppColors.gray300),
            const SizedBox(height: 12),
            Text(
              '\'$query\' 검색 결과가 없어요',
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontFamily: 'Inter',
                fontWeight: FontWeight.w500,
                fontSize: 14,
                color: AppColors.gray500,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _QuizCard extends StatelessWidget {
  const _QuizCard({required this.quiz, this.onTap});
  final CharacterQuiz quiz;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.gray100),
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
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    _CategoryChip(quiz.categoryDisplayName),
                    const SizedBox(width: 6),
                    _ExpChip(quiz.expMultiplier),
                    if (quiz.imageUrl != null) ...[
                      const SizedBox(width: 6),
                      const _ImageBadge(),
                    ],
                  ],
                ),
                const SizedBox(height: 12),
                if (quiz.imageUrl != null) ...[
                  ClipRRect(
                    borderRadius: BorderRadius.circular(12),
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
                  const SizedBox(height: 12),
                ],
                Text(
                  quiz.question,
                  style: const TextStyle(
                    fontFamily: 'Inter',
                    fontWeight: FontWeight.w700,
                    fontSize: 16,
                    height: 1.4,
                    color: AppColors.gray900,
                  ),
                ),
                const SizedBox(height: 12),
                // 선택지는 항상 한 줄에 2개씩(2×2) 배치한다. Wrap 은 너비에 따라
                // 3+1 처럼 들쭉날쭉해져 균형이 안 맞아 고정 2열 그리드로 둔다.
                _OptionGrid(options: quiz.options),
                const SizedBox(height: 14),
                Container(height: 1, color: AppColors.gray50),
                const SizedBox(height: 12),
                Row(
                  children: [
                    const Icon(Icons.person_rounded,
                        size: 14, color: AppColors.gray400),
                    const SizedBox(width: 4),
                    // 작성자명이 남는 가로 공간을 모두 차지하게 해 '다시 풀기' 칩을
                    // 카드 오른쪽 끝에 딱 붙여 정렬한다(Flexible+Spacer 의 어중간한 틈 제거).
                    Expanded(
                      child: Text(
                        quiz.authorName,
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
                    const SizedBox(width: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 12, vertical: 6),
                      decoration: BoxDecoration(
                        color: AppColors.primary.withValues(alpha: 0.10),
                        borderRadius: BorderRadius.circular(999),
                      ),
                      child: const Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.replay_rounded,
                              size: 14, color: AppColors.primary),
                          SizedBox(width: 4),
                          Text(
                            '다시 풀기',
                            style: TextStyle(
                              fontFamily: 'Inter',
                              fontWeight: FontWeight.w700,
                              fontSize: 12,
                              color: AppColors.primary,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// 퀴즈 선택지 2×2 그리드 — 한 줄에 2개씩, 셀 폭은 동일하게 나눠 갖는다.
/// 텍스트가 길면 셀 안에서 말줄임(…)으로 처리해 줄바꿈 없이 균형을 유지.
class _OptionGrid extends StatelessWidget {
  const _OptionGrid({required this.options});
  final List<String> options;

  @override
  Widget build(BuildContext context) {
    // 인덱스가 범위를 벗어나면(홀수 개) 빈 칸으로 자리만 채워 2열 균형을 유지.
    Widget cell(int i) {
      if (i >= options.length) return const SizedBox.shrink();
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 9),
        decoration: BoxDecoration(
          color: AppColors.gray50,
          borderRadius: BorderRadius.circular(10),
        ),
        child: Row(
          children: [
            Text(
              '${i + 1}',
              style: const TextStyle(
                fontFamily: 'Inter',
                fontWeight: FontWeight.w800,
                fontSize: 12,
                color: AppColors.gray400,
              ),
            ),
            const SizedBox(width: 7),
            Expanded(
              child: Text(
                options[i],
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  fontFamily: 'Inter',
                  fontWeight: FontWeight.w500,
                  fontSize: 12,
                  color: AppColors.gray700,
                ),
              ),
            ),
          ],
        ),
      );
    }

    // 한 줄에 2개씩. Row 에 CrossAxisAlignment.stretch 를 주면 높이 무제약인
    // ListView 안에서 세로 제약이 깨져 둘째 줄이 사라지므로 쓰지 않는다.
    final rows = <Widget>[];
    for (int i = 0; i < options.length; i += 2) {
      if (rows.isNotEmpty) rows.add(const SizedBox(height: 6));
      rows.add(Row(
        children: [
          Expanded(child: cell(i)),
          const SizedBox(width: 6),
          Expanded(child: cell(i + 1)),
        ],
      ));
    }
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: rows,
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
