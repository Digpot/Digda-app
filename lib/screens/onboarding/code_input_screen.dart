import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../core/di.dart';
import '../../core/network/error_message.dart';
import '../../theme/colors.dart';
import '../../widgets/primary_button.dart';

class CodeInputScreen extends StatefulWidget {
  final String? initialCode;

  const CodeInputScreen({super.key, this.initialCode});

  @override
  State<CodeInputScreen> createState() => _CodeInputScreenState();
}

class _CodeInputScreenState extends State<CodeInputScreen> {
  static const int _codeLength = 6;
  final List<TextEditingController> _controllers =
      List.generate(_codeLength, (_) => TextEditingController());
  final List<FocusNode> _focusNodes =
      List.generate(_codeLength, (_) => FocusNode());

  bool _submitting = false;

  bool get _isFilled => _controllers.every((c) => c.text.isNotEmpty);

  String get _enteredCode => _controllers.map((c) => c.text).join();

  @override
  void initState() {
    super.initState();
    final code = widget.initialCode;
    if (code != null && code.length == _codeLength) {
      for (int i = 0; i < _codeLength; i++) {
        _controllers[i].text = code[i];
      }
    }
  }

  @override
  void dispose() {
    for (final c in _controllers) {
      c.dispose();
    }
    for (final f in _focusNodes) {
      f.dispose();
    }
    super.dispose();
  }

  void _onChanged(String value, int index) {
    final digits = value.replaceAll(RegExp(r'[^0-9]'), '');
    // 붙여넣기(여러 자리) — 0번 칸부터 분배하고 마지막 입력 칸으로 포커스.
    if (digits.length > 1) {
      for (int i = 0; i < _codeLength; i++) {
        _controllers[i].text = i < digits.length ? digits[i] : '';
      }
      final focusIdx = digits.length.clamp(1, _codeLength) - 1;
      _focusNodes[focusIdx].requestFocus();
      setState(() {});
      return;
    }
    // 단일 입력 — 한 글자만 유지.
    if (_controllers[index].text != digits) {
      _controllers[index].text = digits;
      _controllers[index].selection =
          TextSelection.collapsed(offset: digits.length);
    }
    if (digits.isNotEmpty && index < _codeLength - 1) {
      _focusNodes[index + 1].requestFocus();
    } else if (digits.isEmpty && index > 0) {
      _focusNodes[index - 1].requestFocus();
    }
    setState(() {});
  }

  Future<void> _onSubmit() async {
    if (_submitting) return;
    setState(() => _submitting = true);
    final code = _enteredCode;
    try {
      // 1) 미리보기 검증 (만료/이미 참여/인원 초과 여기서 잡힘)
      await Di.inviteRepository.validate(code);
      if (!mounted) return;
      // 2) 참여
      final result = await Di.inviteRepository.join(code);
      if (!mounted) return;
      Di.activeGroup.enter(
        groupRoomId: result.groupRoom.id,
        groupRoomName: result.groupRoom.name,
        isOwner: false,
      );
      // join 진입 경로가 /home, /my-page, /group-list 등 다양해서 어느 경로든
      // 잔류하지 않도록 스택을 비우고 group-home 만 남긴다.
      Navigator.of(context).pushNamedAndRemoveUntil(
        '/group-home',
        (route) => false,
        arguments: {
          'name': result.groupRoom.name,
          'members': result.memberships.length,
          'isOwner': false,
        },
      );
    } catch (e) {
      if (!mounted) return;
      setState(() => _submitting = false);
      _showInvalidCodeDialog(errorMessageOf(e, fallback: '유효하지 않은 초대 코드예요'));
    }
  }

  void _showInvalidCodeDialog(String message) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: AppColors.white,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
        ),
        title: const Text(
          '초대 코드 오류',
          style: TextStyle(
            fontFamily: 'Inter',
            fontWeight: FontWeight.w700,
            fontSize: 17,
            color: AppColors.gray900,
          ),
        ),
        content: Text(
          message,
          style: const TextStyle(
            fontFamily: 'Inter',
            fontWeight: FontWeight.w400,
            fontSize: 14,
            color: AppColors.gray700,
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text(
              '확인',
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

  @override
  Widget build(BuildContext context) {
    final bottomPadding = MediaQuery.of(context).padding.bottom;
    return Scaffold(
      backgroundColor: AppColors.white,
      body: Column(
        children: [
          const Spacer(),
          Container(
            width: double.infinity,
            padding: EdgeInsets.fromLTRB(24, 12, 24, bottomPadding + 30),
            decoration: const BoxDecoration(
              color: AppColors.white,
              borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Center(
                  child: Container(
                    width: 36,
                    height: 4,
                    decoration: BoxDecoration(
                      color: AppColors.gray200,
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),
                const SizedBox(height: 24),
                const Text(
                  '초대 코드를 입력하세요',
                  style: TextStyle(
                    fontFamily: 'Inter',
                    fontWeight: FontWeight.w700,
                    fontSize: 20,
                    height: 1.3,
                    color: AppColors.gray900,
                  ),
                ),
                const SizedBox(height: 8),
                const Text(
                  '상대방에게 받은 6자리 코드를 입력해주세요',
                  style: TextStyle(
                    fontFamily: 'Inter',
                    fontWeight: FontWeight.w400,
                    fontSize: 14,
                    height: 1.5,
                    color: AppColors.gray500,
                  ),
                ),
                const SizedBox(height: 28),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: List.generate(_codeLength, (index) {
                    return SizedBox(
                      width: 48,
                      height: 56,
                      child: TextField(
                        controller: _controllers[index],
                        focusNode: _focusNodes[index],
                        textAlign: TextAlign.center,
                        keyboardType: TextInputType.number,
                        inputFormatters: [
                          FilteringTextInputFormatter.digitsOnly,
                        ],
                        style: const TextStyle(
                          fontFamily: 'Inter',
                          fontWeight: FontWeight.w600,
                          fontSize: 20,
                          color: AppColors.gray900,
                        ),
                        decoration: InputDecoration(
                          counterText: '',
                          filled: true,
                          fillColor: AppColors.gray50,
                          contentPadding: EdgeInsets.zero,
                          enabledBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: BorderSide(
                              color: _controllers[index].text.isNotEmpty
                                  ? AppColors.primary
                                  : AppColors.gray100,
                            ),
                          ),
                          focusedBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: const BorderSide(
                              color: AppColors.primary,
                              width: 1.5,
                            ),
                          ),
                        ),
                        onChanged: (value) => _onChanged(value, index),
                        onTap: () => setState(() {}),
                      ),
                    );
                  }),
                ),
                const SizedBox(height: 32),
                PrimaryButton(
                  text: _submitting ? '참여 중...' : '참여하기',
                  onPressed:
                      (_isFilled && !_submitting) ? _onSubmit : null,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

