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
      if (!mounted) return;
      setState(() {
        _items
          ..clear()
          ..addAll(result.items);
        _page = result.page;
        _totalPages = result.totalPages;
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
      MaterialPageRoute(builder: (_) => const CharacterQuizCreateScreen()),
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
    return RefreshIndicator(
      onRefresh: () => _fetchPage(0),
      child: ListView.separated(
        controller: _scroll,
        padding: const EdgeInsets.fromLTRB(24, 12, 24, 100),
        itemCount: _items.length + (_loadingMore ? 1 : 0),
        separatorBuilder: (_, __) => const SizedBox(height: 10),
        itemBuilder: (_, i) {
          if (i == _items.length) {
            return const Padding(
              padding: EdgeInsets.symmetric(vertical: 16),
              child: Center(child: CircularProgressIndicator()),
            );
          }
          return _QuizCard(quiz: _items[i]);
        },
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
