import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import '../../core/di.dart';
import '../../core/network/api_exception.dart';
import '../../features/auth/models/auth_models.dart';
import '../../theme/colors.dart';
import '../../theme/text_styles.dart';
import '../../widgets/app_dialog.dart';
import '../../widgets/primary_button.dart';

/// 소셜 로그인 직후 노출되는 약관 동의 화면.
///
/// App Store / Play Store / KISA 가이드 준수를 위해 항목마다 다음을 명시:
///   - 수집 항목, 이용 목적, 보유 기간
///   - 필수/선택 구분
///   - 선택 항목 거부 시에도 서비스 이용 가능함을 안내
class TermsAgreementScreen extends StatefulWidget {
  const TermsAgreementScreen({super.key, this.loginType = 'kakao'});

  final String loginType;

  @override
  State<TermsAgreementScreen> createState() => _TermsAgreementScreenState();
}

class _TermsAgreementScreenState extends State<TermsAgreementScreen> {
  bool _checkAll = false;
  bool _submitting = false;
  List<bool> _checks = [false, false, false, false];

  bool get _allRequiredChecked => _checks[0] && _checks[1];

  void _toggleAll(bool? value) {
    setState(() {
      _checkAll = value ?? false;
      _checks = List.filled(_items.length, _checkAll);
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
        // 만 14세 확인 항목은 제거됨 — 서버 NOT NULL 컬럼 호환을 위해 true 전송.
        ageConfirmation: true,
        marketingConsent: _checks[2],
        pushConsent: _checks[3],
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

  static const List<_ConsentItem> _items = [
    _ConsentItem(
      label: '이용약관 동의',
      description: '서비스 이용을 위한 권리·의무, 운영 규칙',
      isRequired: true,
      detailType: 'terms',
    ),
    _ConsentItem(
      label: '개인정보 수집 및 이용 동의',
      description: '수집: 이름·이메일·프로필 사진 / 목적: 회원 식별·서비스 제공 / 보유: 탈퇴 시까지',
      isRequired: true,
      detailType: 'privacy',
    ),
    _ConsentItem(
      label: '마케팅 정보 수신 동의',
      description: '이벤트·혜택 안내 (거부해도 서비스 이용 가능)',
      isRequired: false,
      detailType: 'marketing',
    ),
    _ConsentItem(
      label: '푸시 알림 수신 동의',
      description: '그룹 활동·일정 알림 (거부해도 서비스 이용 가능)',
      isRequired: false,
      detailType: null,
    ),
  ];

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
              const SizedBox(height: 40),
              const Text(
                '서비스 이용을 위해',
                style: AppTextStyles.heading2,
              ),
              const Text(
                '약관에 동의해주세요',
                style: AppTextStyles.heading2,
              ),
              const SizedBox(height: 8),
              const Text(
                '필수 항목 동의 후 서비스를 시작할 수 있어요.\n선택 항목은 거부해도 서비스 이용에 제한이 없습니다.',
                style: TextStyle(
                  fontFamily: 'Inter',
                  fontWeight: FontWeight.w400,
                  fontSize: 13,
                  height: 1.5,
                  color: AppColors.gray500,
                ),
              ),
              const SizedBox(height: 24),
              _buildCheckAll(),
              const SizedBox(height: 8),
              Expanded(
                child: SingleChildScrollView(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const SizedBox(height: 16),
                      for (int i = 0; i < _items.length; i++) ...[
                        _buildCheckItem(i, _items[i]),
                        if (i == 1)
                          Padding(
                            padding: const EdgeInsets.symmetric(vertical: 12),
                            child: Container(
                              height: 1,
                              color: AppColors.gray100,
                            ),
                          )
                        else
                          const SizedBox(height: 16),
                      ],
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 8),
              Center(
                child: PrimaryButton(
                  text: _submitting ? '처리 중...' : '동의하고 시작하기',
                  onPressed:
                      (_allRequiredChecked && !_submitting) ? _submit : null,
                ),
              ),
              const SizedBox(height: 32),
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
            const Expanded(
              child: Text(
                '전체 동의 (선택 항목 포함)',
                style: AppTextStyles.title,
              ),
            ),
            const SizedBox(width: 16),
          ],
        ),
      ),
    );
  }

  Widget _buildCheckItem(int index, _ConsentItem item) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          GestureDetector(
            onTap: () => _toggleItem(index, !_checks[index]),
            child: Padding(
              padding: const EdgeInsets.only(top: 2),
              child: Icon(
                _checks[index]
                    ? Icons.check_box
                    : Icons.check_box_outline_blank,
                size: 22,
                color:
                    _checks[index] ? AppColors.primary : AppColors.gray300,
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: GestureDetector(
              onTap: () => _toggleItem(index, !_checks[index]),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Flexible(
                        child: Text(
                          item.label,
                          style: AppTextStyles.bodyMedium.copyWith(
                            color: AppColors.gray900,
                          ),
                        ),
                      ),
                      const SizedBox(width: 6),
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color: item.isRequired
                              ? AppColors.primary.withValues(alpha: 0.1)
                              : AppColors.gray100,
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Text(
                          item.isRequired ? '필수' : '선택',
                          style: AppTextStyles.tiny.copyWith(
                            color: item.isRequired
                                ? AppColors.primary
                                : AppColors.gray500,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(
                    item.description,
                    style: const TextStyle(
                      fontFamily: 'Inter',
                      fontWeight: FontWeight.w400,
                      fontSize: 12,
                      height: 1.5,
                      color: AppColors.gray500,
                    ),
                  ),
                ],
              ),
            ),
          ),
          if (item.detailType != null) ...[
            const SizedBox(width: 4),
            GestureDetector(
              onTap: () {
                Navigator.of(context)
                    .pushNamed('/terms-detail', arguments: item.detailType);
              },
              child: const Padding(
                padding: EdgeInsets.only(top: 2),
                child: Icon(
                  Icons.chevron_right,
                  size: 18,
                  color: AppColors.gray400,
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _ConsentItem {
  const _ConsentItem({
    required this.label,
    required this.description,
    required this.isRequired,
    required this.detailType,
  });

  final String label;
  final String description;
  final bool isRequired;
  final String? detailType;
}
