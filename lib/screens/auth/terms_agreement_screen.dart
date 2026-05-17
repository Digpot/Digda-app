import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import '../../core/di.dart';
import '../../core/network/api_exception.dart';
import '../../features/auth/models/auth_models.dart';
import '../../theme/colors.dart';
import '../../theme/text_styles.dart';
import '../../widgets/app_dialog.dart';
import '../../widgets/primary_button.dart';

class TermsAgreementScreen extends StatefulWidget {
  const TermsAgreementScreen({super.key, this.loginType = 'kakao'});

  final String loginType;

  @override
  State<TermsAgreementScreen> createState() => _TermsAgreementScreenState();
}

class _TermsAgreementScreenState extends State<TermsAgreementScreen> {
  bool _checkAll = false;
  bool _submitting = false;
  List<bool> _checks = [false, false, false, false, false];

  bool get _allRequiredChecked => _checks[0] && _checks[1] && _checks[2];

  void _toggleAll(bool? value) {
    setState(() {
      _checkAll = value ?? false;
      _checks = List.filled(5, _checkAll);
    });
  }

  void _toggleItem(int index, bool? value) {
    setState(() {
      _checks[index] = value ?? false;
      _checkAll = _checks.every((e) => e);
    });
  }

  Future<void> _submit() async {
    if (!_allRequiredChecked || _submitting) return;
    setState(() => _submitting = true);
    try {
      await Di.authSession.agreeTerms(TermsAgreement(
        termsOfService: _checks[0],
        privacyPolicy: _checks[1],
        ageConfirmation: _checks[2],
        marketingConsent: _checks[3],
        pushConsent: _checks[4],
      ));
      if (!mounted) return;
      Navigator.of(context).pushReplacementNamed('/app-guide');
    } catch (e) {
      if (!mounted) return;
      String message = '약관 동의 처리 중 오류가 발생했습니다.';
      if (e is DioException && e.error is ApiException) {
        message = (e.error as ApiException).message;
      } else if (e is ApiException) {
        message = e.message;
      }
      showErrorDialog(context, message);
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.white,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SizedBox(height: 60),
              const Text(
                '서비스 이용을 위해',
                style: AppTextStyles.heading2,
              ),
              const Text(
                '약관에 동의해주세요',
                style: AppTextStyles.heading2,
              ),
              const SizedBox(height: 32),
              _buildCheckAll(),
              const SizedBox(height: 32),
              _buildCheckItem(0, '이용약관 동의', true),
              const SizedBox(height: 36),
              _buildCheckItem(1, '개인정보 수집 및 이용 동의', true),
              const SizedBox(height: 36),
              _buildCheckItem(2, '만 14세 이상입니다', true),
              const SizedBox(height: 36),
              Container(height: 1, color: AppColors.gray100),
              const SizedBox(height: 36),
              _buildCheckItem(3, '마케팅 정보 수신 동의', false),
              const SizedBox(height: 36),
              _buildCheckItem(4, '푸시 알림 수신 동의', false),
              const Spacer(),
              Center(
                child: PrimaryButton(
                  text: _submitting ? '처리 중...' : '동의하고 시작하기',
                  onPressed: (_allRequiredChecked && !_submitting) ? _submit : null,
                ),
              ),
              const SizedBox(height: 48),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildCheckAll() {
    return GestureDetector(
      onTap: () => _toggleAll(!_checkAll),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 14),
        decoration: BoxDecoration(
          color: AppColors.gray50,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Row(
          children: [
            const SizedBox(width: 16),
            Icon(
              _checkAll ? Icons.check_box : Icons.check_box_outline_blank,
              size: 22,
              color: _checkAll ? AppColors.primary : AppColors.gray300,
            ),
            const SizedBox(width: 12),
            const Text(
              '전체 동의',
              style: AppTextStyles.title,
            ),
            const SizedBox(width: 16),
          ],
        ),
      ),
    );
  }

  String? _getDetailType(int index) {
    switch (index) {
      case 0:
        return 'terms';
      case 1:
        return 'privacy';
      case 3:
        return 'marketing';
      default:
        return null;
    }
  }

  Widget _buildCheckItem(int index, String label, bool isRequired) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 0),
      child: Row(
        children: [
          GestureDetector(
            onTap: () => _toggleItem(index, !_checks[index]),
            child: Row(
              children: [
                Icon(
                  _checks[index]
                      ? Icons.check_box
                      : Icons.check_box_outline_blank,
                  size: 22,
                  color:
                      _checks[index] ? AppColors.primary : AppColors.gray300,
                ),
                const SizedBox(width: 12),
              ],
            ),
          ),
          Expanded(
            child: GestureDetector(
              onTap: () => _toggleItem(index, !_checks[index]),
              child: Text(
                label,
                style: AppTextStyles.bodyMedium.copyWith(
                  color: AppColors.gray900,
                ),
              ),
            ),
          ),
          const SizedBox(width: 8),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
            decoration: BoxDecoration(
              color: isRequired
                  ? AppColors.primary.withValues(alpha: 0.1)
                  : AppColors.gray100,
              borderRadius: BorderRadius.circular(4),
            ),
            child: Text(
              isRequired ? '필수' : '선택',
              style: AppTextStyles.tiny.copyWith(
                color: isRequired ? AppColors.primary : AppColors.gray500,
              ),
            ),
          ),
          const SizedBox(width: 4),
          GestureDetector(
            onTap: () {
              final type = _getDetailType(index);
              if (type != null) {
                Navigator.of(context)
                    .pushNamed('/terms-detail', arguments: type);
              }
            },
            child: const Icon(
              Icons.chevron_right,
              size: 16,
              color: AppColors.gray400,
            ),
          ),
        ],
      ),
    );
  }
}
