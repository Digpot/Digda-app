import 'package:flutter/material.dart';
import '../../core/di.dart';
import '../../features/auth/data/auth_repository.dart';
import '../../theme/colors.dart';

class TermsDetailScreen extends StatefulWidget {
  const TermsDetailScreen({super.key, this.type = 'terms'});

  final String type;

  @override
  State<TermsDetailScreen> createState() => _TermsDetailScreenState();
}

class _TermsDetailScreenState extends State<TermsDetailScreen> {
  late Future<TermsDocument> _future;

  @override
  void initState() {
    super.initState();
    _future = _load();
  }

  Future<TermsDocument> _load() async {
    final type = TermsType.fromKey(widget.type);
    try {
      return await Di.authRepository.fetchTerms(type);
    } catch (_) {
      // 네트워크 실패 시 임베디드 텍스트로 폴백.
      return TermsDocument(
        title: _fallbackTitle,
        content: _fallbackContent,
        version: 'local',
        updatedAt: '',
      );
    }
  }

  String get _fallbackTitle {
    switch (widget.type) {
      case 'privacy':
      case 'privacy-policy':
        return '개인정보처리방침';
      case 'marketing':
        return '마케팅 정보 수신 동의';
      default:
        return '이용약관';
    }
  }

  String get _fallbackContent {
    switch (widget.type) {
      case 'privacy':
      case 'privacy-policy':
        return _privacyPolicy;
      case 'marketing':
        return _marketingTerms;
      default:
        return _termsOfService;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.white,
      body: SafeArea(
        child: FutureBuilder<TermsDocument>(
          future: _future,
          builder: (context, snap) {
            final title = snap.data?.title.isNotEmpty == true
                ? snap.data!.title
                : _fallbackTitle;
            final body = snap.connectionState == ConnectionState.waiting
                ? null
                : snap.data?.content ?? _fallbackContent;
            return Column(
              children: [
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
                      Text(
                        title,
                        style: const TextStyle(
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
                  child: body == null
                      ? const Center(child: CircularProgressIndicator())
                      : SingleChildScrollView(
                          padding: const EdgeInsets.all(24),
                          child: Text(
                            body,
                            style: const TextStyle(
                              fontFamily: 'Inter',
                              fontWeight: FontWeight.w400,
                              fontSize: 14,
                              height: 1.8,
                              color: AppColors.gray700,
                            ),
                          ),
                        ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }
}

const String _termsOfService = '''제1조 (목적)
본 약관은 Digda(이하 "회사")가 제공하는 그룹 다이어리 서비스(이하 "서비스")의 이용과 관련하여 회사와 이용자 간의 권리, 의무 및 책임사항, 기타 필요한 사항을 규정함을 목적으로 합니다.

제2조 (정의)
1. "서비스"란 회사가 제공하는 모바일 애플리케이션을 통해 이용자가 그룹 다이어리, 일정 관리, 할 일 목록 등을 작성하고 공유할 수 있는 서비스를 말합니다.
2. "이용자"란 본 약관에 따라 회사가 제공하는 서비스를 이용하는 자를 말합니다.
3. "그룹"이란 서비스 내에서 이용자들이 함께 다이어리를 작성하기 위해 구성한 단위를 말합니다.

제3조 (약관의 효력 및 변경)
1. 본 약관은 서비스를 이용하고자 하는 모든 이용자에게 그 효력이 발생합니다.
2. 회사는 합리적인 사유가 발생할 경우 관련 법령에 위배되지 않는 범위에서 본 약관을 변경할 수 있으며, 변경 시 최소 7일 전에 공지합니다.

제4조 (서비스의 제공)
1. 회사는 다음과 같은 서비스를 제공합니다:
   - 그룹 다이어리 작성 및 공유
   - 일정 관리 및 공유
   - 할 일 목록 관리
   - 그룹 초대 및 관리
   - 알림 서비스
2. 서비스는 연중무휴 24시간 제공함을 원칙으로 합니다.

제5조 (이용자의 의무)
1. 이용자는 서비스 이용 시 다음 행위를 하여서는 안 됩니다:
   - 타인의 정보를 도용하는 행위
   - 서비스에서 얻은 정보를 회사의 사전 승낙 없이 복제, 유통, 이용하는 행위
   - 타인의 명예를 훼손하거나 불이익을 주는 행위
   - 공공질서 및 미풍양속에 위반되는 내용을 유포하는 행위

제6조 (개인정보보호)
회사는 이용자의 개인정보를 보호하기 위해 개인정보처리방침을 수립하고 이를 준수합니다. 자세한 사항은 개인정보처리방침을 참고하시기 바랍니다.

제7조 (서비스 이용의 제한 및 중지)
1. 회사는 다음과 같은 경우 서비스 이용을 제한하거나 중지할 수 있습니다:
   - 서비스용 설비의 보수 등 공사로 인한 부득이한 경우
   - 이용자가 본 약관의 의무를 위반한 경우
   - 기타 불가항력적 사유가 있는 경우

제8조 (책임제한)
1. 회사는 천재지변 또는 이에 준하는 불가항력으로 인하여 서비스를 제공할 수 없는 경우에는 책임이 면제됩니다.
2. 회사는 이용자의 귀책사유로 인한 서비스 이용의 장애에 대하여 책임을 지지 않습니다.

제9조 (분쟁해결)
본 약관에서 정하지 않은 사항이나 해석에 대해서는 관련 법령 또는 상관례에 따릅니다.

부칙
본 약관은 2026년 1월 1일부터 시행합니다.
''';

const String _privacyPolicy = '''Digda(이하 "회사")는 이용자의 개인정보를 중요시하며, 「개인정보 보호법」을 준수하고 있습니다.

1. 수집하는 개인정보 항목
회사는 서비스 제공을 위해 다음과 같은 개인정보를 수집합니다:
- 필수 항목: 이름, 이메일 주소, 소셜 로그인 식별자
- 선택 항목: 프로필 사진, 상태 메시지
- 자동 수집 항목: 기기 정보, 앱 사용 기록, 접속 로그

2. 개인정보의 수집 및 이용 목적
- 서비스 제공 및 운영: 회원 관리, 그룹 다이어리 서비스 제공
- 서비스 개선: 이용 통계 분석, 서비스 품질 향상
- 안전한 서비스 환경: 부정 이용 방지, 본인 확인

3. 개인정보의 보유 및 이용 기간
- 회원 탈퇴 시까지 보유하며, 탈퇴 후 즉시 파기합니다.
- 단, 관련 법령에 따라 보존이 필요한 경우 해당 기간 동안 보관합니다:
  · 계약 또는 청약철회에 관한 기록: 5년
  · 소비자 불만 또는 분쟁 처리에 관한 기록: 3년
  · 접속 로그 기록: 3개월

4. 개인정보의 제3자 제공
회사는 원칙적으로 이용자의 개인정보를 제3자에게 제공하지 않습니다. 다만, 다음의 경우에는 예외로 합니다:
- 이용자가 사전에 동의한 경우
- 법령의 규정에 의한 경우

5. 개인정보의 파기 절차 및 방법
- 전자적 파일 형태: 복구 불가능한 방법으로 영구 삭제
- 종이 문서: 분쇄기로 분쇄하거나 소각

6. 개인정보 보호책임자
- 성명: 개인정보보호팀
- 이메일: privacy@digda.app

7. 이용자의 권리
이용자는 언제든지 자신의 개인정보에 대해 열람, 정정, 삭제, 처리 정지를 요구할 수 있습니다. 회원 탈퇴를 통해 개인정보 삭제를 요청할 수 있습니다.

8. 개인정보의 안전성 확보 조치
회사는 개인정보의 안전성 확보를 위해 다음과 같은 조치를 취하고 있습니다:
- 개인정보의 암호화
- 해킹 등에 대비한 보안 시스템 구축
- 접근 통제 및 접근 권한 관리
- 개인정보 취급 직원의 최소화 및 교육

9. 개인정보처리방침 변경
본 개인정보처리방침은 법률이나 서비스의 변경사항을 반영하기 위해 수정될 수 있으며, 변경 시 앱 내 공지사항을 통해 안내합니다.

시행일: 2026년 1월 1일
''';

const String _marketingTerms = '''마케팅 정보 수신 동의

Digda(이하 "회사")는 이용자에게 다양한 혜택과 정보를 제공하기 위해 마케팅 정보를 발송할 수 있습니다.

1. 마케팅 정보의 내용
- 신규 기능 및 서비스 안내
- 이벤트 및 프로모션 정보
- 맞춤형 서비스 추천

2. 수신 채널
- 푸시 알림
- 이메일
- 앱 내 알림

3. 동의 철회
마케팅 정보 수신 동의는 언제든지 앱 내 설정에서 철회할 수 있습니다.
설정 > 알림 설정에서 마케팅 알림을 끌 수 있습니다.

4. 동의를 거부할 권리
마케팅 정보 수신에 동의하지 않아도 서비스 이용에는 제한이 없습니다.
''';
