import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import '../../core/di.dart';
import '../../core/network/api_exception.dart';
import '../../theme/colors.dart';
import '../../widgets/app_dialog.dart';
import '../../widgets/primary_button.dart';

class DeleteAccountScreen extends StatefulWidget {
  const DeleteAccountScreen({super.key});

  @override
  State<DeleteAccountScreen> createState() => _DeleteAccountScreenState();
}

class _DeleteAccountScreenState extends State<DeleteAccountScreen> {
  bool _confirmed = false;

  bool _processing = false;

  Future<void> _executeDelete() async {
    // 다이얼로그 컨텍스트(이미 dismiss됨) 가 아닌, 화면 자체의 컨텍스트로
    // Navigator/Messenger 를 미리 캡처해 async 경계 후에도 안전하게 사용.
    final navigator = Navigator.of(context);
    final messenger = ScaffoldMessenger.of(context);
    setState(() => _processing = true);
    try {
      await Di.authSession.deleteAccount();
      if (!mounted) return;
      navigator.pushNamedAndRemoveUntil('/login', (route) => false);
      // 새 화면이 push 된 다음 토스트가 표시되도록 한 프레임 뒤에 보여준다.
      WidgetsBinding.instance.addPostFrameCallback((_) {
        messenger.showSnackBar(
          SnackBar(
            content: const Text(
              '회원 탈퇴가 완료되었습니다',
              style: TextStyle(
                fontFamily: 'Inter',
                fontWeight: FontWeight.w500,
                fontSize: 14,
                color: AppColors.white,
              ),
            ),
            backgroundColor: AppColors.gray900,
            behavior: SnackBarBehavior.floating,
            margin: const EdgeInsets.fromLTRB(20, 0, 20, 24),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(10),
            ),
            duration: const Duration(seconds: 2),
          ),
        );
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _processing = false);
      String message = '탈퇴 처리 중 오류가 발생했습니다.';
      if (e is DioException && e.error is ApiException) {
        final api = e.error as ApiException;
        if (api.code == 'OWNS_ACTIVE_GROUP_ROOM') {
          message = '소유 중인 그룹방이 있어 탈퇴할 수 없습니다. 방장 양도 후 재시도하세요.';
        } else {
          message = api.message;
        }
      } else if (e is ApiException) {
        if (e.code == 'OWNS_ACTIVE_GROUP_ROOM') {
          message = '소유 중인 그룹방이 있어 탈퇴할 수 없습니다. 방장 양도 후 재시도하세요.';
        } else {
          message = e.message;
        }
      }
      showErrorDialog(context, message);
    }
  }

  void _showFinalConfirmDialog() {
    showDialog(
      context: context,
      builder: (dialogContext) => AlertDialog(
        backgroundColor: AppColors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text(
          '정말 탈퇴하시겠습니까?',
          style: TextStyle(
            fontFamily: 'Inter',
            fontWeight: FontWeight.w700,
            fontSize: 18,
            color: AppColors.gray900,
          ),
        ),
        content: const Text(
          '탈퇴 후 모든 데이터가 영구적으로 삭제되며\n복구할 수 없습니다.',
          style: TextStyle(
            fontFamily: 'Inter',
            fontWeight: FontWeight.w400,
            fontSize: 14,
            height: 1.5,
            color: AppColors.gray700,
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(),
            child: const Text(
              '취소',
              style: TextStyle(
                fontFamily: 'Inter',
                fontWeight: FontWeight.w600,
                fontSize: 14,
                color: AppColors.gray500,
              ),
            ),
          ),
          TextButton(
            onPressed: () {
              Navigator.of(dialogContext).pop();
              // 다이얼로그가 닫힌 직후 본 화면의 컨텍스트로 탈퇴 실행.
              _executeDelete();
            },
            child: const Text(
              '탈퇴하기',
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
    return Scaffold(
      backgroundColor: AppColors.white,
      body: SafeArea(
        child: Column(
          children: [
            // Header
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
              child: Row(
                children: [
                  GestureDetector(
                    onTap: () => Navigator.of(context).pop(),
                    child: const Icon(
                      Icons.arrow_back_ios,
                      size: 14,
                      color: AppColors.gray900,
                    ),
                  ),
                  const SizedBox(width: 16),
                  const Text(
                    '회원 탈퇴',
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
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 24),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const SizedBox(height: 32),
                    Container(
                      width: 56,
                      height: 56,
                      decoration: BoxDecoration(
                        color: AppColors.primary.withValues(alpha: 0.1),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(
                        Icons.warning_amber_rounded,
                        size: 28,
                        color: AppColors.primary,
                      ),
                    ),
                    const SizedBox(height: 20),
                    const Text(
                      '탈퇴 전 꼭 확인해주세요',
                      style: TextStyle(
                        fontFamily: 'Inter',
                        fontWeight: FontWeight.w700,
                        fontSize: 22,
                        color: AppColors.gray900,
                      ),
                    ),
                    const SizedBox(height: 24),
                    _buildWarningItem('작성한 모든 일기, 일정, 할 일이 삭제됩니다.'),
                    const SizedBox(height: 16),
                    _buildWarningItem('참여 중인 모든 그룹에서 자동으로 탈퇴됩니다.'),
                    const SizedBox(height: 16),
                    _buildWarningItem('삭제된 데이터는 복구할 수 없습니다.'),
                    const SizedBox(height: 16),
                    _buildWarningItem('소셜 로그인 연동 정보가 해제됩니다.'),
                    const SizedBox(height: 32),
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: AppColors.gray50,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Row(
                        children: [
                          GestureDetector(
                            onTap: () => setState(() => _confirmed = !_confirmed),
                            child: Icon(
                              _confirmed
                                  ? Icons.check_box
                                  : Icons.check_box_outline_blank,
                              size: 22,
                              color: _confirmed
                                  ? AppColors.primary
                                  : AppColors.gray300,
                            ),
                          ),
                          const SizedBox(width: 12),
                          const Expanded(
                            child: Text(
                              '위 내용을 모두 확인했으며, 회원 탈퇴에 동의합니다.',
                              style: TextStyle(
                                fontFamily: 'Inter',
                                fontWeight: FontWeight.w500,
                                fontSize: 14,
                                color: AppColors.gray700,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const Spacer(),
                    PrimaryButton(
                      text: _processing ? '처리 중...' : '탈퇴하기',
                      onPressed: (_confirmed && !_processing)
                          ? _showFinalConfirmDialog
                          : null,
                    ),
                    const SizedBox(height: 48),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildWarningItem(String text) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Padding(
          padding: EdgeInsets.only(top: 2),
          child: Icon(
            Icons.remove_circle_outline,
            size: 18,
            color: AppColors.primary,
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Text(
            text,
            style: const TextStyle(
              fontFamily: 'Inter',
              fontWeight: FontWeight.w400,
              fontSize: 15,
              height: 1.5,
              color: AppColors.gray700,
            ),
          ),
        ),
      ],
    );
  }
}
