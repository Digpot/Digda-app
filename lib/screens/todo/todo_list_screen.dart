import 'package:flutter/material.dart';
import '../../theme/colors.dart';

class TodoListScreen extends StatefulWidget {
  const TodoListScreen({super.key});

  @override
  State<TodoListScreen> createState() => _TodoListScreenState();
}

class _TodoListScreenState extends State<TodoListScreen> {
  final List<Map<String, dynamic>> _todos = [
    {'text': '다음 모임 장소 정하기', 'isCompleted': false, 'completedDate': null},
    {'text': '회비 걷기', 'isCompleted': false, 'completedDate': null},
    {'text': '단체 사진 공유하기', 'isCompleted': false, 'completedDate': null},
    {'text': '생일 선물 아이디어 모으기', 'isCompleted': false, 'completedDate': null},
    {'text': '날짜 정하기', 'isCompleted': true, 'completedDate': '2월 5일 완료'},
    {'text': '인원 확인하기', 'isCompleted': true, 'completedDate': '2월 3일 완료'},
    {'text': '그룹방 만들기', 'isCompleted': true, 'completedDate': '1월 26일 완료'},
  ];

  final TextEditingController _addController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  final FocusNode _inputFocusNode = FocusNode();

  @override
  void initState() {
    super.initState();
    _inputFocusNode.addListener(_onFocusChange);
  }

  @override
  void dispose() {
    _addController.dispose();
    _scrollController.dispose();
    _inputFocusNode.removeListener(_onFocusChange);
    _inputFocusNode.dispose();
    super.dispose();
  }

  void _onFocusChange() {
    if (_inputFocusNode.hasFocus) {
      // 키보드가 올라오면 목록 하단으로 스크롤
      Future.delayed(const Duration(milliseconds: 300), () {
        if (_scrollController.hasClients) {
          _scrollController.animateTo(
            _scrollController.position.maxScrollExtent,
            duration: const Duration(milliseconds: 300),
            curve: Curves.easeOut,
          );
        }
      });
    }
  }

  void _toggleTodo(int index) {
    setState(() {
      final todo = _todos[index];
      todo['isCompleted'] = !(todo['isCompleted'] as bool);
      if (todo['isCompleted'] as bool) {
        final now = DateTime.now();
        todo['completedDate'] = '${now.month}월 ${now.day}일 완료';
      } else {
        todo['completedDate'] = null;
      }
    });
  }

  void _addTodo() {
    final text = _addController.text.trim();
    if (text.isEmpty) return;
    setState(() {
      _todos.insert(0, {
        'text': text,
        'isCompleted': false,
        'completedDate': null,
      });
      _addController.clear();
    });
    // 새로 추가된 항목이 보이도록 맨 위로 스크롤
    Future.delayed(const Duration(milliseconds: 100), () {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          0,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final pending =
        _todos.where((t) => !(t['isCompleted'] as bool)).toList();
    final completed =
        _todos.where((t) => t['isCompleted'] as bool).toList();
    final total = _todos.length;
    final completedCount = completed.length;
    final progress = total > 0 ? completedCount / total : 0.0;
    final progressPct = (progress * 100).round();

    return Scaffold(
      backgroundColor: AppColors.scaffoldBg,
      resizeToAvoidBottomInset: true,
      body: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
              child: Row(
                children: [
                  GestureDetector(
                    onTap: () => Navigator.of(context).pop(),
                    child: const Icon(
                      Icons.arrow_back_ios,
                      size: 20,
                      color: AppColors.gray900,
                    ),
                  ),
                  const SizedBox(width: 16),
                  const Text(
                    '투두리스트',
                    style: TextStyle(
                      fontFamily: 'Inter',
                      fontWeight: FontWeight.w700,
                      fontSize: 20,
                      color: AppColors.gray900,
                    ),
                  ),
                ],
              ),
            ),
            Expanded(
              child: ListView(
                controller: _scrollController,
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
                children: [
                  // 진행률 카드
                  Container(
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      color: AppColors.white,
                      borderRadius: BorderRadius.circular(16),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.04),
                          blurRadius: 8,
                          offset: const Offset(0, 2),
                        ),
                      ],
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text(
                                  '진행률',
                                  style: TextStyle(
                                    fontFamily: 'Inter',
                                    fontWeight: FontWeight.w600,
                                    fontSize: 14,
                                    color: AppColors.gray700,
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  '$total개 중 $completedCount개 완료',
                                  style: const TextStyle(
                                    fontFamily: 'Inter',
                                    fontWeight: FontWeight.w400,
                                    fontSize: 12,
                                    color: AppColors.gray500,
                                  ),
                                ),
                              ],
                            ),
                            Text(
                              '$progressPct%',
                              style: const TextStyle(
                                fontFamily: 'Inter',
                                fontWeight: FontWeight.w800,
                                fontSize: 28,
                                color: AppColors.gray900,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),
                        ClipRRect(
                          borderRadius: BorderRadius.circular(6),
                          child: LinearProgressIndicator(
                            value: progress,
                            minHeight: 8,
                            backgroundColor: AppColors.gray100,
                            valueColor: const AlwaysStoppedAnimation<Color>(
                              AppColors.blue,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 24),
                  // 할 일 섹션
                  if (pending.isNotEmpty) ...[
                    const Padding(
                      padding: EdgeInsets.only(left: 4, bottom: 10),
                      child: Text(
                        '할 일',
                        style: TextStyle(
                          fontFamily: 'Inter',
                          fontWeight: FontWeight.w700,
                          fontSize: 14,
                          color: AppColors.gray700,
                        ),
                      ),
                    ),
                    ...pending.map((todo) {
                      final index = _todos.indexOf(todo);
                      return _buildTodoCard(
                        text: todo['text'] as String,
                        isCompleted: false,
                        onToggle: () => _toggleTodo(index),
                      );
                    }),
                    const SizedBox(height: 20),
                  ],
                  // 완료 섹션
                  if (completed.isNotEmpty) ...[
                    Padding(
                      padding: const EdgeInsets.only(left: 4, bottom: 10),
                      child: Text(
                        '완료 ($completedCount)',
                        style: const TextStyle(
                          fontFamily: 'Inter',
                          fontWeight: FontWeight.w700,
                          fontSize: 14,
                          color: AppColors.gray400,
                        ),
                      ),
                    ),
                    ...completed.map((todo) {
                      final index = _todos.indexOf(todo);
                      return _buildTodoCard(
                        text: todo['text'] as String,
                        isCompleted: true,
                        completedDate: todo['completedDate'] as String?,
                        onToggle: () => _toggleTodo(index),
                      );
                    }),
                  ],
                  const SizedBox(height: 16),
                ],
              ),
            ),
            // 하단 입력 바
            Container(
              padding: const EdgeInsets.only(
                left: 20,
                right: 20,
                top: 12,
                bottom: 12,
              ),
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
              child: Row(
                children: [
                  Expanded(
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      height: 44,
                      decoration: BoxDecoration(
                        color: AppColors.gray50,
                        borderRadius: BorderRadius.circular(22),
                      ),
                      child: TextField(
                        controller: _addController,
                        focusNode: _inputFocusNode,
                        style: const TextStyle(
                          fontFamily: 'Inter',
                          fontWeight: FontWeight.w400,
                          fontSize: 14,
                          color: AppColors.gray900,
                        ),
                        decoration: const InputDecoration(
                          hintText: '할 일을 입력하세요',
                          hintStyle: TextStyle(
                            fontFamily: 'Inter',
                            fontWeight: FontWeight.w400,
                            fontSize: 14,
                            color: AppColors.gray400,
                          ),
                          border: InputBorder.none,
                          contentPadding: EdgeInsets.symmetric(vertical: 12),
                        ),
                        onSubmitted: (_) => _addTodo(),
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  GestureDetector(
                    onTap: _addTodo,
                    child: Container(
                      width: 44,
                      height: 44,
                      decoration: const BoxDecoration(
                        color: AppColors.primary,
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(
                        Icons.arrow_upward_rounded,
                        size: 22,
                        color: AppColors.white,
                      ),
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

  Widget _buildTodoCard({
    required String text,
    required bool isCompleted,
    String? completedDate,
    required VoidCallback onToggle,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: GestureDetector(
        onTap: onToggle,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
          decoration: BoxDecoration(
            color: AppColors.white,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
              color: isCompleted ? AppColors.gray100 : AppColors.gray100,
              width: 1,
            ),
            boxShadow: isCompleted
                ? null
                : [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.04),
                      blurRadius: 6,
                      offset: const Offset(0, 2),
                    ),
                  ],
          ),
          child: Row(
            children: [
              Container(
                width: 24,
                height: 24,
                decoration: BoxDecoration(
                  color: isCompleted ? AppColors.blue : Colors.transparent,
                  borderRadius: BorderRadius.circular(7),
                  border: isCompleted
                      ? null
                      : Border.all(color: AppColors.gray300, width: 1.5),
                ),
                child: isCompleted
                    ? const Icon(Icons.check, size: 16, color: AppColors.white)
                    : null,
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      text,
                      style: TextStyle(
                        fontFamily: 'Inter',
                        fontWeight: isCompleted ? FontWeight.w400 : FontWeight.w500,
                        fontSize: 15,
                        color: isCompleted ? AppColors.gray400 : AppColors.gray900,
                        decoration: isCompleted
                            ? TextDecoration.lineThrough
                            : TextDecoration.none,
                        decorationColor: AppColors.gray400,
                      ),
                    ),
                    if (completedDate != null) ...[
                      const SizedBox(height: 3),
                      Text(
                        completedDate,
                        style: const TextStyle(
                          fontFamily: 'Inter',
                          fontWeight: FontWeight.w400,
                          fontSize: 11,
                          color: AppColors.gray400,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
