import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../core/format/money.dart';
import '../features/ledger/models/ledger_models.dart';
import '../features/membership/models/membership_models.dart';
import '../theme/colors.dart';
import 'ledger_style.dart';
import 'primary_button.dart';

/// 일정 추가/수정 화면의 '금액' 섹션.
///
/// 한 일정에 지출 여러 건을 붙일 수 있고, 각 건마다 금액·분류·낸 사람·내용을 가진다.
/// 저장은 일정 저장과 함께 나가므로 이 위젯은 목록 편집만 하고 통신은 하지 않는다.
class ExpenseListEditor extends StatelessWidget {
  const ExpenseListEditor({
    super.key,
    required this.expenses,
    required this.members,
    required this.onChanged,
  });

  final List<ExpenseWrite> expenses;
  final List<Membership> members;
  final ValueChanged<List<ExpenseWrite>> onChanged;

  int get _total => expenses.fold(0, (sum, e) => sum + e.amount);

  Future<void> _add(BuildContext context) async {
    final result = await showExpenseEditSheet(context, members: members);
    if (result == null) return;
    onChanged([...expenses, result]);
  }

  Future<void> _edit(BuildContext context, int index) async {
    final result = await showExpenseEditSheet(
      context,
      members: members,
      initial: expenses[index],
    );
    if (result == null) return;
    final next = [...expenses];
    next[index] = result;
    onChanged(next);
  }

  void _remove(int index) {
    final next = [...expenses]..removeAt(index);
    onChanged(next);
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        for (int i = 0; i < expenses.length; i++)
          Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: _ExpenseRow(
              expense: expenses[i],
              members: members,
              onTap: () => _edit(context, i),
              onRemove: () => _remove(i),
            ),
          ),
        // 합계는 2건 이상일 때만 — 1건이면 바로 윗줄과 똑같은 숫자가 두 번 나온다.
        if (expenses.length > 1)
          Padding(
            padding: const EdgeInsets.only(bottom: 8, right: 4),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                const Text(
                  '합계',
                  style: TextStyle(
                    fontFamily: 'Inter',
                    fontWeight: FontWeight.w500,
                    fontSize: 13,
                    color: AppColors.gray500,
                  ),
                ),
                const SizedBox(width: 8),
                Text(
                  formatWon(_total),
                  style: const TextStyle(
                    fontFamily: 'Inter',
                    fontWeight: FontWeight.w800,
                    fontSize: 15,
                    color: AppColors.ledgerInk,
                  ),
                ),
              ],
            ),
          ),
        _AddExpenseButton(
          isFirst: expenses.isEmpty,
          onTap: () => _add(context),
        ),
      ],
    );
  }
}

class _ExpenseRow extends StatelessWidget {
  const _ExpenseRow({
    required this.expense,
    required this.members,
    required this.onTap,
    required this.onRemove,
  });

  final ExpenseWrite expense;
  final List<Membership> members;
  final VoidCallback onTap;
  final VoidCallback onRemove;

  @override
  Widget build(BuildContext context) {
    final payer = findMemberById(members, expense.payerId);
    final memo = expense.memo?.trim();
    final subtitle = [
      expense.category.label,
      if (payer != null) '${payer.name} 결제',
    ].join(' · ');

    return Material(
      color: AppColors.gray50,
      borderRadius: BorderRadius.circular(14),
      child: InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(12, 12, 6, 12),
          child: Row(
            children: [
              CategoryBadge(category: expense.category),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      (memo != null && memo.isNotEmpty)
                          ? memo
                          : expense.category.label,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontFamily: 'Inter',
                        fontWeight: FontWeight.w600,
                        fontSize: 14,
                        color: AppColors.gray900,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      subtitle,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontFamily: 'Inter',
                        fontWeight: FontWeight.w400,
                        fontSize: 12,
                        color: AppColors.gray500,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Text(
                formatWon(expense.amount),
                style: const TextStyle(
                  fontFamily: 'Inter',
                  fontWeight: FontWeight.w700,
                  fontSize: 15,
                  color: AppColors.ledgerInk,
                ),
              ),
              IconButton(
                onPressed: onRemove,
                visualDensity: VisualDensity.compact,
                tooltip: '삭제',
                icon: const Icon(
                  Icons.close_rounded,
                  size: 18,
                  color: AppColors.gray400,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _AddExpenseButton extends StatelessWidget {
  const _AddExpenseButton({required this.isFirst, required this.onTap});

  final bool isFirst;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: onTap,
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(vertical: 14),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: AppColors.gray200),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.add_rounded, size: 18, color: AppColors.primary),
              const SizedBox(width: 6),
              Text(
                isFirst ? '이 일정에 쓴 금액 추가' : '금액 더 추가',
                style: const TextStyle(
                  fontFamily: 'Inter',
                  fontWeight: FontWeight.w600,
                  fontSize: 14,
                  color: AppColors.primary,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// userId 로 그룹원을 찾는다. 못 찾으면 null(탈퇴했거나 미지정).
Membership? findMemberById(List<Membership> members, String? userId) {
  if (userId == null) return null;
  for (final m in members) {
    if (m.userId == userId) return m;
  }
  return null;
}

// ─── 입력 시트 ────────────────────────────────────────────────────────────────

/// 지출 한 건 입력/수정 시트. 저장하면 [ExpenseWrite], 취소하면 null 을 돌려준다.
Future<ExpenseWrite?> showExpenseEditSheet(
  BuildContext context, {
  required List<Membership> members,
  ExpenseWrite? initial,
}) {
  return showModalBottomSheet<ExpenseWrite>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (_) => _ExpenseEditSheet(members: members, initial: initial),
  );
}

class _ExpenseEditSheet extends StatefulWidget {
  const _ExpenseEditSheet({required this.members, this.initial});

  final List<Membership> members;
  final ExpenseWrite? initial;

  @override
  State<_ExpenseEditSheet> createState() => _ExpenseEditSheetState();
}

class _ExpenseEditSheetState extends State<_ExpenseEditSheet> {
  late final TextEditingController _amountController;
  late final TextEditingController _memoController;
  late ExpenseCategory _category;
  String? _payerId;

  /// 서버 검증(EXPENSE_AMOUNT_INVALID)과 같은 상한. 앱에서 먼저 막아 왕복을 아낀다.
  static const int _maxAmount = 9999999999;

  @override
  void initState() {
    super.initState();
    final initial = widget.initial;
    _amountController = TextEditingController(
      text: initial == null ? '' : formatAmount(initial.amount),
    );
    _memoController = TextEditingController(text: initial?.memo ?? '');
    _category = initial?.category ?? ExpenseCategory.food;
    _payerId = initial?.payerId;
  }

  @override
  void dispose() {
    _amountController.dispose();
    _memoController.dispose();
    super.dispose();
  }

  /// 표시용 콤마를 걷어내고 숫자만 읽는다.
  int get _amount {
    final digits = _amountController.text.replaceAll(RegExp(r'[^0-9]'), '');
    if (digits.isEmpty) return 0;
    return int.tryParse(digits) ?? 0;
  }

  bool get _canSave => _amount > 0 && _amount <= _maxAmount;

  /// 타이핑하는 동안 천 단위 콤마를 유지하고 커서를 끝에 둔다.
  /// 금액은 뒤에서 이어 치는 입력이라 중간 커서를 보존할 이유가 없고,
  /// 보존하려 들면 콤마가 늘거나 줄 때 커서가 한 칸씩 밀린다.
  void _onAmountChanged(String raw) {
    final digits = raw.replaceAll(RegExp(r'[^0-9]'), '');
    final formatted =
        digits.isEmpty ? '' : formatAmount(int.tryParse(digits) ?? 0);
    if (formatted != raw) {
      _amountController.value = TextEditingValue(
        text: formatted,
        selection: TextSelection.collapsed(offset: formatted.length),
      );
    }
    setState(() {});
  }

  void _submit() {
    if (!_canSave) return;
    final memo = _memoController.text.trim();
    Navigator.of(context).pop(
      ExpenseWrite(
        amount: _amount,
        category: _category,
        payerId: _payerId,
        memo: memo.isEmpty ? null : memo,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
      child: Container(
        decoration: const BoxDecoration(
          color: AppColors.bottomSheetBg,
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        ),
        child: SafeArea(
          top: false,
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(24, 12, 24, 20),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Center(
                  child: Container(
                    width: 40,
                    height: 4,
                    decoration: BoxDecoration(
                      color: AppColors.gray200,
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),
                const SizedBox(height: 20),
                Text(
                  widget.initial == null ? '금액 추가' : '금액 수정',
                  style: const TextStyle(
                    fontFamily: 'Inter',
                    fontWeight: FontWeight.w700,
                    fontSize: 18,
                    color: AppColors.gray900,
                  ),
                ),
                const SizedBox(height: 20),
                _label('얼마 썼나요'),
                const SizedBox(height: 8),
                _AmountField(
                  controller: _amountController,
                  onChanged: _onAmountChanged,
                ),
                const SizedBox(height: 22),
                _label('분류'),
                const SizedBox(height: 10),
                _CategoryPicker(
                  selected: _category,
                  onSelected: (c) => setState(() => _category = c),
                ),
                const SizedBox(height: 22),
                _label('누가 냈나요'),
                const SizedBox(height: 10),
                _PayerPicker(
                  members: widget.members,
                  selectedId: _payerId,
                  // 같은 사람을 다시 누르면 해제 — '미지정'으로 되돌린다.
                  onSelected: (id) => setState(
                    () => _payerId = (_payerId == id) ? null : id,
                  ),
                ),
                const SizedBox(height: 22),
                _label('내용 (선택)'),
                const SizedBox(height: 8),
                TextField(
                  controller: _memoController,
                  maxLength: 100,
                  style: const TextStyle(
                    fontFamily: 'Inter',
                    fontWeight: FontWeight.w400,
                    fontSize: 15,
                    color: AppColors.gray900,
                  ),
                  decoration: InputDecoration(
                    counterText: '',
                    hintText: '예) 숙소값, 저녁 회식',
                    hintStyle: const TextStyle(
                      fontFamily: 'Inter',
                      fontWeight: FontWeight.w400,
                      fontSize: 15,
                      color: AppColors.gray300,
                    ),
                    filled: true,
                    fillColor: AppColors.gray50,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide.none,
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: const BorderSide(color: AppColors.primary),
                    ),
                    contentPadding:
                        const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                  ),
                ),
                const SizedBox(height: 24),
                PrimaryButton(
                  text: widget.initial == null ? '추가하기' : '수정하기',
                  onPressed: _canSave ? _submit : null,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _label(String text) => Text(
        text,
        style: const TextStyle(
          fontFamily: 'Inter',
          fontWeight: FontWeight.w700,
          fontSize: 14,
          color: AppColors.gray900,
        ),
      );
}

class _AmountField extends StatelessWidget {
  const _AmountField({required this.controller, required this.onChanged});

  final TextEditingController controller;
  final ValueChanged<String> onChanged;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      decoration: BoxDecoration(
        color: AppColors.gray50,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          Expanded(
            child: TextField(
              controller: controller,
              // 자동 포커스를 주지 않는다 — 시트가 열리자마자 키보드가 올라오면
              // 화면이 통째로 밀려 올라가 분류·낸 사람이 가려진다. 금액 칸을
              // 직접 눌러야 키보드가 뜬다.
              autofocus: false,
              keyboardType: TextInputType.number,
              inputFormatters: [FilteringTextInputFormatter.digitsOnly],
              textAlign: TextAlign.right,
              style: const TextStyle(
                fontFamily: 'Inter',
                fontWeight: FontWeight.w800,
                fontSize: 24,
                color: AppColors.ledgerInk,
              ),
              decoration: const InputDecoration(
                hintText: '0',
                hintStyle: TextStyle(
                  fontFamily: 'Inter',
                  fontWeight: FontWeight.w800,
                  fontSize: 24,
                  color: AppColors.gray300,
                ),
                border: InputBorder.none,
                contentPadding: EdgeInsets.symmetric(vertical: 14),
              ),
              onChanged: onChanged,
            ),
          ),
          const SizedBox(width: 6),
          const Text(
            '원',
            style: TextStyle(
              fontFamily: 'Inter',
              fontWeight: FontWeight.w700,
              fontSize: 17,
              color: AppColors.gray600,
            ),
          ),
        ],
      ),
    );
  }
}

class _CategoryPicker extends StatelessWidget {
  const _CategoryPicker({required this.selected, required this.onSelected});

  final ExpenseCategory selected;
  final ValueChanged<ExpenseCategory> onSelected;

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: ExpenseCategory.values.map((c) {
        final isSelected = c == selected;
        final color = categoryColor(c);
        return Material(
          color: isSelected ? color.withValues(alpha: 0.14) : AppColors.gray50,
          borderRadius: BorderRadius.circular(999),
          child: InkWell(
            borderRadius: BorderRadius.circular(999),
            onTap: () => onSelected(c),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(999),
                border: Border.all(
                  color: isSelected ? color : Colors.transparent,
                  width: 1.4,
                ),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    categoryIcon(c),
                    size: 16,
                    color: isSelected ? color : AppColors.gray500,
                  ),
                  const SizedBox(width: 6),
                  Text(
                    c.label,
                    style: TextStyle(
                      fontFamily: 'Inter',
                      fontWeight: FontWeight.w700,
                      fontSize: 13,
                      color: isSelected ? color : AppColors.gray600,
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      }).toList(),
    );
  }
}

class _PayerPicker extends StatelessWidget {
  const _PayerPicker({
    required this.members,
    required this.selectedId,
    required this.onSelected,
  });

  final List<Membership> members;
  final String? selectedId;
  final ValueChanged<String> onSelected;

  Color _colorOf(Membership m) {
    final cleaned = m.color.replaceAll('#', '');
    final argb = int.tryParse('FF$cleaned', radix: 16);
    return argb != null ? Color(argb) : AppColors.primary;
  }

  @override
  Widget build(BuildContext context) {
    if (members.isEmpty) {
      return const Text(
        '그룹원을 불러오지 못했어요',
        style: TextStyle(
          fontFamily: 'Inter',
          fontWeight: FontWeight.w400,
          fontSize: 13,
          color: AppColors.gray500,
        ),
      );
    }
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: members.map((m) {
        final isSelected = m.userId == selectedId;
        final color = _colorOf(m);
        return Material(
          color: isSelected ? color.withValues(alpha: 0.14) : AppColors.gray50,
          borderRadius: BorderRadius.circular(999),
          child: InkWell(
            borderRadius: BorderRadius.circular(999),
            onTap: () => onSelected(m.userId),
            child: Container(
              padding: const EdgeInsets.fromLTRB(6, 6, 14, 6),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(999),
                border: Border.all(
                  color: isSelected ? color : Colors.transparent,
                  width: 1.4,
                ),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  MemberAvatarDot(member: m, color: color),
                  const SizedBox(width: 8),
                  Text(
                    m.name,
                    style: TextStyle(
                      fontFamily: 'Inter',
                      fontWeight: FontWeight.w700,
                      fontSize: 13,
                      color: isSelected ? color : AppColors.gray700,
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      }).toList(),
    );
  }
}

/// 작은 원형 그룹원 아바타 — 프로필 이미지가 없거나 로드 실패면 이름 첫 글자.
class MemberAvatarDot extends StatelessWidget {
  const MemberAvatarDot({
    super.key,
    required this.member,
    required this.color,
    this.size = 26,
  });

  final Membership member;
  final Color color;
  final double size;

  @override
  Widget build(BuildContext context) {
    final initial = member.name.isNotEmpty ? member.name[0] : '?';
    final image = member.profileImage;
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.2),
        shape: BoxShape.circle,
      ),
      clipBehavior: Clip.antiAlias,
      child: (image != null && image.isNotEmpty)
          ? Image.network(
              image,
              fit: BoxFit.cover,
              errorBuilder: (_, __, ___) => _initial(initial),
            )
          : _initial(initial),
    );
  }

  Widget _initial(String initial) => Center(
        child: Text(
          initial,
          style: TextStyle(
            fontFamily: 'Inter',
            fontWeight: FontWeight.w700,
            fontSize: size * 0.46,
            color: color,
          ),
        ),
      );
}
