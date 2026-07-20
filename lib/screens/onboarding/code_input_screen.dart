import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../core/di.dart';
import '../../core/network/error_message.dart';
import '../../theme/colors.dart';
import '../../widgets/primary_button.dart';

class CodeInputScreen extends StatefulWidget {
  final String? initialCode;

  /// true 면 화면(Scaffold) 없이 패널만 그린다 — 바텀시트 임베드용.
  final bool embedded;

  const CodeInputScreen({super.key, this.initialCode, this.embedded = false});

  /// 그룹 리스트 등 현재 화면을 배경으로 둔 채 초대 코드 입력을
  /// 바텀시트로 띄운다. 참여 성공 시 내부에서 /group-home 으로 스택을 교체한다.
  static Future<void> showAsSheet(BuildContext context) {
    return showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => Padding(
        padding: EdgeInsets.only(bottom: MediaQuery.of(ctx).viewInsets.bottom),
        child: const CodeInputScreen(embedded: true),
      ),
    );
  }

  @override
  State<CodeInputScreen> createState() => _CodeInputScreenState();
}

class _CodeInputScreenState extends State<CodeInputScreen> {
  static const int _codeLength = 6;

  /// 코드 전체를 담는 단일 컨트롤러.
  ///
  /// 예전에는 칸마다 컨트롤러를 두고 onChanged 에서 글자를 재분배했는데, 칸 하나가
  /// 두 글자 이상을 물고 있을 수 있어(IME 합성·빠른 연타·붙여넣기) 총 6자리를
  /// 넘겨 입력되는 버그가 있었다. 지금은 컨트롤러 하나 + 길이 제한 포매터라
  /// 6자리 초과가 구조적으로 불가능하고, 6개 칸은 이 문자열을 그리기만 한다.
  final TextEditingController _controller = TextEditingController();
  final FocusNode _focus = FocusNode();

  bool _submitting = false;

  String get _enteredCode => _controller.text;

  bool get _isFilled => _enteredCode.length == _codeLength;

  @override
  void initState() {
    super.initState();
    final code = widget.initialCode;
    if (code != null && code.length == _codeLength) {
      _controller.text = code;
    }
    // 포커스 상태에 따라 커서 칸 강조가 바뀌므로 다시 그린다.
    _focus.addListener(() {
      if (mounted) setState(() {});
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    _focus.dispose();
    super.dispose();
  }

  Future<void> _onSubmit() async {
    if (_submitting) return;
    final code = _enteredCode;
    if (code.length != _codeLength) {
      _showInvalidCodeDialog('초대 코드는 숫자 6자리예요');
      return;
    }
    setState(() => _submitting = true);
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
    // 바텀시트 임베드 — 뒷배경(그룹 리스트 등)을 살린 채 패널만 그린다.
    if (widget.embedded) return _buildPanel(context);
    return Scaffold(
      backgroundColor: AppColors.white,
      body: Column(
        children: [
          const Spacer(),
          _buildPanel(context),
        ],
      ),
    );
  }

  /// 6칸 코드 입력 — 실제 입력은 투명한 TextField 하나가 받고, 칸들은 그 값을
  /// 그리기만 한다. 칸 사이 간격은 Expanded 바깥의 SizedBox 로 줘서 6개 칸의
  /// 폭이 정확히 같아진다(예전엔 마지막 칸만 패딩이 없어 8px 더 넓었다).
  Widget _buildCodeBoxes() {
    final code = _controller.text;
    final focused = _focus.hasFocus;
    // 다음에 입력될 칸 — 포커스 중일 때만 강조한다.
    final cursorIndex = code.length.clamp(0, _codeLength - 1);

    final boxes = <Widget>[];
    for (var i = 0; i < _codeLength; i++) {
      if (i > 0) boxes.add(const SizedBox(width: 8));
      final filled = i < code.length;
      final isCursor = focused && i == cursorIndex && code.length < _codeLength;
      boxes.add(
        Expanded(
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 140),
            height: 56,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: filled ? AppColors.white : AppColors.gray50,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: filled || isCursor
                    ? AppColors.primary
                    : AppColors.gray100,
                width: isCursor ? 1.8 : 1.2,
              ),
            ),
            child: Text(
              filled ? code[i] : '',
              style: const TextStyle(
                fontFamily: 'Inter',
                fontWeight: FontWeight.w700,
                fontSize: 22,
                color: AppColors.gray900,
              ),
            ),
          ),
        ),
      );
    }

    return Stack(
      children: [
        Row(children: boxes),
        // 입력을 받는 투명 필드 — 칸 전체를 덮어 어디를 탭해도 키보드가 열린다.
        Positioned.fill(
          child: TextField(
            controller: _controller,
            focusNode: _focus,
            autofocus: true,
            keyboardType: TextInputType.number,
            inputFormatters: [
              FilteringTextInputFormatter.digitsOnly,
              // 6자리 초과는 여기서 원천 차단된다.
              LengthLimitingTextInputFormatter(_codeLength),
            ],
            // 글자·커서·선택 UI 를 모두 숨기고 칸 렌더링에 맡긴다.
            style: const TextStyle(color: Colors.transparent, fontSize: 22),
            cursorColor: Colors.transparent,
            showCursor: false,
            enableInteractiveSelection: false,
            decoration: const InputDecoration(
              border: InputBorder.none,
              counterText: '',
              contentPadding: EdgeInsets.zero,
            ),
            onChanged: (_) => setState(() {}),
            onTap: () {
              // 항상 끝에 이어 쓰도록 캐럿을 마지막으로 보낸다.
              _controller.selection = TextSelection.collapsed(
                offset: _controller.text.length,
              );
              setState(() {});
            },
          ),
        ),
      ],
    );
  }

  Widget _buildPanel(BuildContext context) {
    final bottomPadding = MediaQuery.of(context).padding.bottom;
    return Container(
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
                _buildCodeBoxes(),
                const SizedBox(height: 32),
                PrimaryButton(
                  text: _submitting ? '참여 중...' : '참여하기',
                  onPressed:
                      (_isFilled && !_submitting) ? _onSubmit : null,
                ),
              ],
            ),
    );
  }
}

