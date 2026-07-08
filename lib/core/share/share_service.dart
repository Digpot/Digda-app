import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:kakao_flutter_sdk_share/kakao_flutter_sdk_share.dart';
import 'package:share_plus/share_plus.dart';

import '../../widgets/app_dialog.dart';

/// 공유 진입점 모음 (2.0.0).
///
/// iOS 에서 share_plus 는
///  - iPad: `sharePositionOrigin` 이 없으면 팝오버 원점이 없어 공유 시트가 안 뜨고,
///  - UIScene 전환 후 키 윈도우/루트 VC 탐색이 실패하면 PlatformException 을 던지는데
///    호출부가 안 잡으면 "버튼이 아무 반응 없음"으로 보인다.
/// 그래서 모든 시스템 공유는 여기서 원점 지정 + 실패 시 클립보드 폴백을 공통 처리한다.
class ShareService {
  ShareService._();

  /// 초대 메시지 본문 — 코드 입력 안내 포함.
  static String inviteMessage(String code) =>
      '디그팟에서 함께 일기를 써요!\n\n초대 코드: $code\n\n디그팟 앱을 열고 초대 코드를 입력해주세요 🙌';

  /// 시스템 공유 시트로 텍스트 공유. 실패하면 클립보드 복사로 폴백해 사용자가
  /// 어떤 경우에도 초대 문구를 전달할 수 있게 한다.
  static Future<void> shareText(BuildContext context, String text) async {
    try {
      await Share.share(text, sharePositionOrigin: _originOf(context));
    } catch (e) {
      debugPrint('[share] 시스템 공유 실패, 클립보드 폴백: $e');
      await Clipboard.setData(ClipboardData(text: text));
      if (context.mounted) {
        showAppSnackBar(context, '공유 시트를 열 수 없어 내용을 복사했어요. 붙여넣기로 공유해주세요.');
      }
    }
  }

  /// 시스템 공유 시트로 파일(이미지 등) 공유. 원점 지정 공통 처리.
  /// 실패는 다시 던져 호출부의 기존 에러 안내를 그대로 쓴다.
  static Future<void> shareFiles(
    BuildContext context,
    List<XFile> files, {
    String? text,
  }) {
    return Share.shareXFiles(
      files,
      text: text,
      sharePositionOrigin: _originOf(context),
    );
  }

  /// 초대 코드 카카오톡 공유 — 메시지 카드 + "디그팟에서 코드 입력하기" 버튼.
  /// 버튼을 누르면 앱이 kakao{앱키}://kakaolink?invite_code=XXXXXX 로 실행되고
  /// (app.dart 딥링크 핸들러가 코드 입력 화면으로 라우팅), 앱이 없으면 카카오가
  /// 개발자 콘솔에 등록된 스토어로 유도한다.
  ///
  /// 카카오톡이 없거나 공유에 실패하면 시스템 공유 시트로 폴백한다.
  static Future<void> shareInviteViaKakao(
    BuildContext context,
    String code,
  ) async {
    try {
      if (await ShareClient.instance.isKakaoTalkSharingAvailable()) {
        final template = TextTemplate(
          text: '📔 디그팟에서 함께 일기를 써요!\n\n초대 코드: $code\n(코드는 24시간 후 만료돼요)',
          link: Link(
            androidExecutionParams: {'invite_code': code},
            iosExecutionParams: {'invite_code': code},
          ),
          buttonTitle: '디그팟에서 코드 입력하기',
        );
        final uri = await ShareClient.instance.shareDefault(template: template);
        await ShareClient.instance.launchKakaoTalk(uri);
        return;
      }
      debugPrint('[share] 카카오톡 미설치 — 시스템 공유로 폴백');
    } catch (e) {
      // 콘솔 설정/SDK 문제로 실패해도 초대 자체는 이어가야 하므로 시스템 시트로 폴백.
      debugPrint('[share] 카카오톡 공유 실패, 시스템 공유로 폴백: $e');
    }
    if (!context.mounted) return;
    await shareText(context, inviteMessage(code));
  }

  /// share_plus(iOS/iPad) 팝오버 원점 — 현재 위젯의 화면상 사각형.
  /// 렌더박스를 못 찾으면 화면 중앙의 1pt 사각형으로 폴백한다.
  static Rect _originOf(BuildContext context) {
    final box = context.findRenderObject() as RenderBox?;
    if (box != null && box.hasSize) {
      return box.localToGlobal(Offset.zero) & box.size;
    }
    final size = MediaQuery.of(context).size;
    return Rect.fromCenter(
      center: Offset(size.width / 2, size.height / 2),
      width: 1,
      height: 1,
    );
  }
}
