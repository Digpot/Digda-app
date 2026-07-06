import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../core/di.dart';
import '../../core/network/error_message.dart';
import '../../features/inquiry/models/inquiry_models.dart';
import '../../theme/colors.dart';
import '../../widgets/app_dialog.dart';

/// 마이페이지 — 고객센터. 문의 작성(하루 2건 제한은 서버에서 강제) + 내 문의 목록.
/// 헤더 우측 아이콘으로 비로그인 계정/데이터 삭제 요청 웹페이지(어드민)로 이동한다.
class SupportScreen extends StatefulWidget {
  const SupportScreen({super.key});

  @override
  State<SupportScreen> createState() => _SupportScreenState();
}

class _SupportScreenState extends State<SupportScreen> {
  /// 비로그인 계정/데이터 삭제 요청 페이지(디그팟 어드민 웹).
  static const String _deletionRequestUrl =
      'https://digda-admin.vercel.app/deletion-request';

  final TextEditingController _controller = TextEditingController();
  bool _submitting = false;
  bool _loading = true;
  String? _error;
  List<Inquiry> _inquiries = const [];

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final list = await Di.inquiryRepository.myInquiries();
      if (!mounted) return;
      setState(() => _inquiries = list);
    } catch (e) {
      if (!mounted) return;
      setState(() => _error = errorMessageOf(e));
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _openDeletionRequest() async {
    final uri = Uri.parse(_deletionRequestUrl);
    final ok = await launchUrl(uri, mode: LaunchMode.externalApplication);
    if (!ok && mounted) {
      showErrorDialog(context, '페이지를 열 수 없어요. 잠시 후 다시 시도해주세요.');
    }
  }

  Future<void> _submit() async {
    final text = _controller.text.trim();
    if (text.isEmpty) {
      showErrorDialog(context, '문의 내용을 입력해주세요');
      return;
    }
    if (_submitting) return;
    setState(() => _submitting = true);
    try {
      await Di.inquiryRepository.submit(text);
      if (!mounted) return;
      _controller.clear();
      FocusScope.of(context).unfocus();
      await showInfoDialog(
        context,
        '문의를 보냈어요',
        '확인 후 빠르게 도와드릴게요.\n답변은 등록하신 정보로 안내돼요.',
      );
      if (mounted) await _load();
    } catch (e) {
      // 하루 2건 초과(429) 등 서버 메시지를 그대로 안내.
      if (mounted) showErrorDialog(context, errorMessageOf(e));
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.white,
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
              child: Row(
                children: [
                  GestureDetector(
                    onTap: () => Navigator.of(context).pop(),
                    child: const Icon(Icons.arrow_back_ios,
                        size: 20, color: AppColors.gray900),
                  ),
                  const SizedBox(width: 16),
                  const Text(
                    '고객센터',
                    style: TextStyle(
                      fontFamily: 'Inter',
                      fontWeight: FontWeight.w700,
                      fontSize: 20,
                      color: AppColors.gray900,
                    ),
                  ),
                  const Spacer(),
                  // 비로그인 계정/데이터 삭제 요청 웹페이지로 이동.
                  GestureDetector(
                    onTap: _openDeletionRequest,
                    behavior: HitTestBehavior.opaque,
                    child: const Padding(
                      padding: EdgeInsets.all(4),
                      child: Icon(Icons.manage_accounts_outlined,
                          size: 24, color: AppColors.gray700),
                    ),
                  ),
                ],
              ),
            ),
            Expanded(
              child: ListView(
                padding: const EdgeInsets.fromLTRB(20, 4, 20, 24),
                children: [
                  _buildForm(),
                  const SizedBox(height: 28),
                  const Text(
                    '내 문의 내역',
                    style: TextStyle(
                      fontFamily: 'Inter',
                      fontWeight: FontWeight.w700,
                      fontSize: 15,
                      color: AppColors.gray900,
                    ),
                  ),
                  const SizedBox(height: 12),
                  _buildHistory(),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildForm() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          '무엇을 도와드릴까요?',
          style: TextStyle(
            fontFamily: 'Inter',
            fontWeight: FontWeight.w700,
            fontSize: 16,
            color: AppColors.gray900,
          ),
        ),
        const SizedBox(height: 6),
        const Text(
          '불편한 점이나 궁금한 점을 적어주세요. 문의는 하루 2번까지 보낼 수 있어요.',
          style: TextStyle(
            fontFamily: 'Inter',
            fontWeight: FontWeight.w400,
            fontSize: 13,
            color: AppColors.gray500,
          ),
        ),
        const SizedBox(height: 12),
        Container(
          decoration: BoxDecoration(
            color: AppColors.gray50,
            borderRadius: BorderRadius.circular(14),
          ),
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
          child: TextField(
            controller: _controller,
            maxLines: 6,
            maxLength: 1000,
            style: const TextStyle(
              fontFamily: 'Inter',
              fontSize: 14,
              height: 1.5,
              color: AppColors.gray900,
            ),
            decoration: const InputDecoration(
              hintText: '문의 내용을 입력하세요',
              hintStyle: TextStyle(
                fontFamily: 'Inter',
                fontSize: 14,
                color: AppColors.gray400,
              ),
              border: InputBorder.none,
              counterStyle: TextStyle(
                fontFamily: 'Inter',
                fontSize: 11,
                color: AppColors.gray400,
              ),
            ),
          ),
        ),
        const SizedBox(height: 12),
        SizedBox(
          width: double.infinity,
          height: 50,
          child: ElevatedButton(
            onPressed: _submitting ? null : _submit,
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primary,
              foregroundColor: AppColors.white,
              elevation: 0,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(14),
              ),
            ),
            child: _submitting
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(
                        strokeWidth: 2, color: AppColors.white),
                  )
                : const Text(
                    '문의 보내기',
                    style: TextStyle(
                      fontFamily: 'Inter',
                      fontWeight: FontWeight.w700,
                      fontSize: 16,
                    ),
                  ),
          ),
        ),
      ],
    );
  }

  Widget _buildHistory() {
    if (_loading) {
      return const Padding(
        padding: EdgeInsets.symmetric(vertical: 24),
        child: Center(child: CircularProgressIndicator()),
      );
    }
    if (_error != null) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 16),
        child: Column(
          children: [
            Text(
              _error!,
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontFamily: 'Inter',
                fontSize: 13,
                color: AppColors.gray500,
              ),
            ),
            const SizedBox(height: 8),
            TextButton(onPressed: _load, child: const Text('다시 시도')),
          ],
        ),
      );
    }
    if (_inquiries.isEmpty) {
      return const Padding(
        padding: EdgeInsets.symmetric(vertical: 24),
        child: Center(
          child: Text(
            '아직 보낸 문의가 없어요',
            style: TextStyle(
              fontFamily: 'Inter',
              fontWeight: FontWeight.w500,
              fontSize: 13,
              color: AppColors.gray400,
            ),
          ),
        ),
      );
    }
    return Column(
      children: _inquiries.map(_buildInquiryCard).toList(),
    );
  }

  Widget _buildInquiryCard(Inquiry inquiry) {
    final answered = inquiry.isAnswered;
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.gray100),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: (answered ? AppColors.green : AppColors.primary)
                      .withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(
                  answered ? '답변 완료' : '접수됨',
                  style: TextStyle(
                    fontFamily: 'Inter',
                    fontWeight: FontWeight.w700,
                    fontSize: 11,
                    color: answered ? AppColors.green : AppColors.primary,
                  ),
                ),
              ),
              const Spacer(),
              Text(
                _formatDate(inquiry.createdAt.toLocal()),
                style: const TextStyle(
                  fontFamily: 'Inter',
                  fontWeight: FontWeight.w400,
                  fontSize: 12,
                  color: AppColors.gray400,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            inquiry.content,
            style: const TextStyle(
              fontFamily: 'Inter',
              fontWeight: FontWeight.w400,
              fontSize: 14,
              height: 1.5,
              color: AppColors.gray800,
            ),
          ),
          if (answered && inquiry.answer != null && inquiry.answer!.isNotEmpty)
            _buildAnswer(inquiry),
        ],
      ),
    );
  }

  /// 어드민 답변 — 문의 카드 하단에 구분선 + 강조 박스로 표시.
  Widget _buildAnswer(Inquiry inquiry) {
    return Container(
      margin: const EdgeInsets.only(top: 12),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.primary.withValues(alpha: 0.06),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.support_agent_rounded,
                  size: 16, color: AppColors.primary),
              const SizedBox(width: 6),
              const Text(
                '디그팟 답변',
                style: TextStyle(
                  fontFamily: 'Inter',
                  fontWeight: FontWeight.w700,
                  fontSize: 12,
                  color: AppColors.primary,
                ),
              ),
              const Spacer(),
              if (inquiry.answeredAt != null)
                Text(
                  _formatDate(inquiry.answeredAt!.toLocal()),
                  style: const TextStyle(
                    fontFamily: 'Inter',
                    fontWeight: FontWeight.w400,
                    fontSize: 11,
                    color: AppColors.gray400,
                  ),
                ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            inquiry.answer!,
            style: const TextStyle(
              fontFamily: 'Inter',
              fontWeight: FontWeight.w400,
              fontSize: 14,
              height: 1.5,
              color: AppColors.gray800,
            ),
          ),
        ],
      ),
    );
  }

  String _formatDate(DateTime d) =>
      '${d.year}.${d.month.toString().padLeft(2, '0')}.${d.day.toString().padLeft(2, '0')}';
}
