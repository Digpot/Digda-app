import 'package:flutter/material.dart';
import '../../core/di.dart';
import '../../core/network/error_message.dart';
import '../../features/todo/models/todo_models.dart';
import '../../theme/colors.dart';

class TodoListScreen extends StatefulWidget {
  const TodoListScreen({super.key});

  @override
  State<TodoListScreen> createState() => _TodoListScreenState();
}

class _TodoListScreenState extends State<TodoListScreen> {
  List<Todo> _todos = const [];
  TodoProgress? _progress;
  bool _loading = true;
  String? _errorMessage;

  final TextEditingController _addController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  final FocusNode _inputFocusNode = FocusNode();

  @override
  void initState() {
    super.initState();
    _inputFocusNode.addListener(_onFocusChange);
    WidgetsBinding.instance.addPostFrameCallback((_) => _load());
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

  Future<void> _load() async {
    final groupId = Di.activeGroup.groupRoomId;
    if (groupId == null) {
      setState(() {
        _loading = false;
        _errorMessage = '그룹방 정보를 불러올 수 없어요';
      });
      return;
    }
    setState(() {
      _loading = true;
      _errorMessage = null;
    });
    try {
      final result = await Di.todoRepository.list(groupId);
      if (!mounted) return;
      setState(() {
        _todos = result.todos;
        _progress = result.progress;
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

  Future<void> _toggleTodo(Todo todo) async {
    final groupId = Di.activeGroup.groupRoomId;
    if (groupId == null) return;
    final newCompleted = !todo.completed;
    // 낙관적 갱신
    setState(() {
      _todos = _todos
          .map((t) => t.id == todo.id
              ? Todo(
                  id: t.id,
                  text: t.text,
                  completed: newCompleted,
                  completedAt: newCompleted ? DateTime.now() : null,
                  completedBy: t.completedBy,
                  createdBy: t.createdBy,
                  createdAt: t.createdAt,
                )
              : t)
          .toList();
    });
    try {
      await Di.todoRepository
          .toggle(groupId, todo.id, completed: newCompleted);
      _load();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(errorMessageOf(e))));
      _load();
    }
  }

  Future<void> _addTodo() async {
    final groupId = Di.activeGroup.groupRoomId;
    final text = _addController.text.trim();
    if (text.isEmpty || groupId == null) return;
    _addController.clear();
    try {
      await Di.todoRepository.create(groupId, text);
      await _load();
      if (!mounted) return;
      Future.delayed(const Duration(milliseconds: 100), () {
        if (_scrollController.hasClients) {
          _scrollController.animateTo(
            0,
            duration: const Duration(milliseconds: 300),
            curve: Curves.easeOut,
          );
        }
      });
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(errorMessageOf(e))));
    }
  }

  String _formatCompletedDate(DateTime? d) {
    if (d == null) return '';
    return '${d.month}월 ${d.day}일 완료';
  }

  @override
  Widget build(BuildContext context) {
    final pending = _todos.where((t) => !t.completed).toList();
    final completed = _todos.where((t) => t.completed).toList();
    final progress = _progress;
    final total = progress?.total ?? _todos.length;
    final completedCount =
        progress?.completed ?? completed.length;
    final progressValue = total > 0 ? completedCount / total : 0.0;
    final progressPct = progress?.percent ?? (progressValue * 100).round();

    return Scaffold(
      backgroundColor: AppColors.scaffoldBg,
      resizeToAvoidBottomInset: true,
      body: SafeArea(
        child: _loading
            ? const Center(child: CircularProgressIndicator())
            : _errorMessage != null
                ? _buildError()
                : Column(
                    children: [
                      Padding(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 20, vertical: 14),
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
                        child: RefreshIndicator(
                          onRefresh: _load,
                          child: ListView(
                            controller: _scrollController,
                            physics: const AlwaysScrollableScrollPhysics(),
                            padding: const EdgeInsets.symmetric(
                                horizontal: 20, vertical: 8),
                            children: [
                              Container(
                                padding: const EdgeInsets.all(20),
                                decoration: BoxDecoration(
                                  color: AppColors.white,
                                  borderRadius: BorderRadius.circular(16),
                                  boxShadow: [
                                    BoxShadow(
                                      color:
                                          Colors.black.withValues(alpha: 0.04),
                                      blurRadius: 8,
                                      offset: const Offset(0, 2),
                                    ),
                                  ],
                                ),
                                child: Column(
                                  crossAxisAlignment:
                                      CrossAxisAlignment.start,
                                  children: [
                                    Row(
                                      mainAxisAlignment:
                                          MainAxisAlignment.spaceBetween,
                                      children: [
                                        Column(
                                          crossAxisAlignment:
                                              CrossAxisAlignment.start,
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
                                        value: progressValue,
                                        minHeight: 8,
                                        backgroundColor: AppColors.gray100,
                                        valueColor:
                                            const AlwaysStoppedAnimation<
                                                Color>(AppColors.blue),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              const SizedBox(height: 24),
                              if (pending.isNotEmpty) ...[
                                const Padding(
                                  padding: EdgeInsets.only(
                                      left: 4, bottom: 10),
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
                                ...pending.map((t) => _buildTodoCard(
                                      text: t.text,
                                      isCompleted: false,
                                      onToggle: () => _toggleTodo(t),
                                    )),
                                const SizedBox(height: 20),
                              ],
                              if (completed.isNotEmpty) ...[
                                Padding(
                                  padding: const EdgeInsets.only(
                                      left: 4, bottom: 10),
                                  child: Text(
                                    '완료 (${completed.length})',
                                    style: const TextStyle(
                                      fontFamily: 'Inter',
                                      fontWeight: FontWeight.w700,
                                      fontSize: 14,
                                      color: AppColors.gray400,
                                    ),
                                  ),
                                ),
                                ...completed.map((t) => _buildTodoCard(
                                      text: t.text,
                                      isCompleted: true,
                                      completedDate: _formatCompletedDate(
                                          t.completedAt),
                                      onToggle: () => _toggleTodo(t),
                                    )),
                              ],
                              if (_todos.isEmpty)
                                const Padding(
                                  padding: EdgeInsets.symmetric(vertical: 60),
                                  child: Center(
                                    child: Text(
                                      '아직 할 일이 없어요',
                                      style: TextStyle(
                                        fontFamily: 'Inter',
                                        fontWeight: FontWeight.w500,
                                        fontSize: 14,
                                        color: AppColors.gray500,
                                      ),
                                    ),
                                  ),
                                ),
                              const SizedBox(height: 16),
                            ],
                          ),
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.only(
                            left: 20, right: 20, top: 12, bottom: 12),
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
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 16),
                                height: 44,
                                decoration: BoxDecoration(
                                  color: AppColors.gray50,
                                  borderRadius: BorderRadius.circular(22),
                                ),
                                child: TextField(
                                  controller: _addController,
                                  focusNode: _inputFocusNode,
                                  maxLength: 100,
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
                                    counterText: '',
                                    contentPadding:
                                        EdgeInsets.symmetric(vertical: 12),
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

  Widget _buildError() {
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
              _errorMessage ?? '',
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
                color: AppColors.primary,
              ),
            ),
          ),
        ],
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
          padding:
              const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
          decoration: BoxDecoration(
            color: AppColors.white,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: AppColors.gray100, width: 1),
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
                    ? const Icon(Icons.check,
                        size: 16, color: AppColors.white)
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
                        fontWeight: isCompleted
                            ? FontWeight.w400
                            : FontWeight.w500,
                        fontSize: 15,
                        color: isCompleted
                            ? AppColors.gray400
                            : AppColors.gray900,
                        decoration: isCompleted
                            ? TextDecoration.lineThrough
                            : TextDecoration.none,
                        decorationColor: AppColors.gray400,
                      ),
                    ),
                    if (completedDate != null && completedDate.isNotEmpty) ...[
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
