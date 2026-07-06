import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:share_plus/share_plus.dart';
import '../../core/di.dart';
import '../../theme/colors.dart';
import '../../widgets/primary_button.dart';
import '../../widgets/outline_button.dart';

/// CreateDiaryScreen 에서 그룹방 생성 후 받은 초대 코드를 노출.
/// 라우트 인자(`Map`)로 `code`/`groupRoomId`/`groupName` 을 받음.
class CodeGenerateScreen extends StatefulWidget {
  const CodeGenerateScreen({super.key});

  @override
  State<CodeGenerateScreen> createState() => _CodeGenerateScreenState();
}

class _CodeGenerateScreenState extends State<CodeGenerateScreen> {
  bool _copied = false;
  String? _code;
  String? _groupRoomId;
  String? _groupName;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final args = ModalRoute.of(context)?.settings.arguments;
    if (args is Map<String, dynamic>) {
      _code = args['code'] as String?;
      _groupRoomId = args['groupRoomId'] as String?;
      _groupName = args['groupName'] as String?;
    }
  }

  void _copyCode() {
    final code = _code;
    if (code == null) return;
    Clipboard.setData(ClipboardData(text: code));
    setState(() => _copied = true);
    Future.delayed(const Duration(seconds: 2), () {
      if (mounted) setState(() => _copied = false);
    });
  }

  void _shareCode() {
    final code = _code;
    if (code == null) return;
    Share.share(
      '디그팟에서 함께 일기를 써요!\n\n초대 코드: $code\n\n디그팟 앱을 열고 초대 코드를 입력해주세요 🙌',
    );
  }

  void _enterGroupHome() {
    if (_groupRoomId != null) {
      Di.activeGroup.enter(
        groupRoomId: _groupRoomId!,
        groupRoomName: _groupName ?? '',
        isOwner: true,
      );
    }
    // 그룹방 생성 직후에는 empty_state(`/home`) 가 스택에 남아 있을 수 있다.
    // 뒤로가기로 다시 "다이어리 없음" 화면이 뜨지 않도록 스택을 전부 비우고
    // group-home 만 남긴다.
    Navigator.of(context).pushNamedAndRemoveUntil(
      '/group-home',
      (route) => false,
      arguments: {
        'name': _groupName ?? '',
        'members': 1,
        'isOwner': true,
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final bottomPadding = MediaQuery.of(context).padding.bottom;
    final code = _code ?? '------';

    return Scaffold(
      backgroundColor: AppColors.white,
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 24),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      '초대 코드가 생성됐어요!',
                      style: TextStyle(
                        fontFamily: 'Inter',
                        fontWeight: FontWeight.w700,
                        fontSize: 20,
                        height: 1.3,
                        color: AppColors.gray900,
                      ),
                    ),
                    const SizedBox(height: 20),
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.symmetric(vertical: 20),
                      decoration: BoxDecoration(
                        color: AppColors.primary.withValues(alpha: 0.08),
                        borderRadius: BorderRadius.circular(14),
                      ),
                      child: Center(
                        child: Text(
                          code,
                          style: const TextStyle(
                            fontFamily: 'Inter',
                            fontWeight: FontWeight.w800,
                            fontSize: 36,
                            letterSpacing: 6,
                            color: AppColors.primary,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),
                    Row(
                      children: [
                        Expanded(
                          child: AppOutlineButton(
                            text: _copied ? '복사됨' : '코드 복사',
                            onPressed: _copyCode,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: PrimaryButton(
                            text: '공유하기',
                            onPressed: _shareCode,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 20),
                    const Center(
                      child: Text(
                        '상대방이 이 코드를 입력하면 연결돼요',
                        style: TextStyle(
                          fontFamily: 'Inter',
                          fontWeight: FontWeight.w400,
                          fontSize: 13,
                          color: AppColors.gray500,
                        ),
                      ),
                    ),
                    const SizedBox(height: 4),
                    const Center(
                      child: Text(
                        '코드는 24시간 후 만료됩니다',
                        style: TextStyle(
                          fontFamily: 'Inter',
                          fontWeight: FontWeight.w400,
                          fontSize: 12,
                          color: AppColors.gray400,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            Padding(
              padding: EdgeInsets.fromLTRB(24, 0, 24, bottomPadding + 16),
              child: PrimaryButton(
                text: '그룹방으로 이동하기',
                onPressed: _enterGroupHome,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
