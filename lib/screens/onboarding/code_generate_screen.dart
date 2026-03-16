import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:share_plus/share_plus.dart';
import '../../theme/colors.dart';
import '../../widgets/primary_button.dart';

class CodeGenerateScreen extends StatefulWidget {
  const CodeGenerateScreen({super.key});

  @override
  State<CodeGenerateScreen> createState() => _CodeGenerateScreenState();
}

class _CodeGenerateScreenState extends State<CodeGenerateScreen> {
  final String _generatedCode = 'A3X9K2';
  bool _copied = false;

  void _copyCode() {
    Clipboard.setData(ClipboardData(text: _generatedCode));
    setState(() => _copied = true);
    Future.delayed(const Duration(seconds: 2), () {
      if (mounted) setState(() => _copied = false);
    });
  }

  void _shareCode() {
    Share.share(
      'Digda에서 함께 일기를 써요!\n\n초대 코드: $_generatedCode\n\nDigda 앱을 열고 초대 코드를 입력해주세요 🙌',
    );
  }

  @override
  Widget build(BuildContext context) {
    final bottomPadding = MediaQuery.of(context).padding.bottom;

    return Scaffold(
      backgroundColor: AppColors.white,
      body: SafeArea(
        child: Column(
          children: [
            // 코드 영역
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
                          _generatedCode,
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
            // 하단 버튼 2개
            Padding(
              padding: EdgeInsets.fromLTRB(24, 0, 24, bottomPadding + 16),
              child: PrimaryButton(
                text: '그룹방으로 이동하기',
                onPressed: () => Navigator.of(context)
                    .pushReplacementNamed('/group-home'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
