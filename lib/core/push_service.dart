import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';

const String _channelId = 'digda_default';
const String _channelName = '디그팟 알림';

/// 앱이 포그라운드일 때 FCM 메시지를 시스템 알림으로 표시.
/// 백그라운드/종료 상태에서는 Android OS가 notification payload를 자동 처리.
class PushService {
  static final _plugin = FlutterLocalNotificationsPlugin();

  static Future<void> init() async {
    const androidSettings = AndroidInitializationSettings('@mipmap/ic_launcher');
    // iOS(Darwin) 설정을 넘기지 않으면 flutter_local_notifications 가 내부에서
    // settings.iOS! 로 강제 언랩 → iOS 에서 null check 예외로 앱이 첫 프레임 전에
    // 죽는다(흰 화면). 실제 권한 요청은 FirebaseMessaging.requestPermission 가
    // 따로 처리하므로 여기선 요청 플래그를 꺼 둔다.
    const iosSettings = DarwinInitializationSettings(
      requestAlertPermission: false,
      requestBadgePermission: false,
      requestSoundPermission: false,
    );
    await _plugin.initialize(const InitializationSettings(
      android: androidSettings,
      iOS: iosSettings,
    ));

    await _plugin
        .resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>()
        ?.createNotificationChannel(const AndroidNotificationChannel(
          _channelId,
          _channelName,
          importance: Importance.high,
        ));

    FirebaseMessaging.onMessage.listen((message) {
      final n = message.notification;
      if (n == null) return;
      _plugin.show(
        n.hashCode,
        n.title,
        n.body,
        const NotificationDetails(
          android: AndroidNotificationDetails(
            _channelId,
            _channelName,
            importance: Importance.high,
            priority: Priority.high,
          ),
        ),
      );
    });
  }
}

/// 앱 종료/백그라운드 상태에서 호출되는 최상위 핸들러.
/// notification+data 페이로드는 OS가 자동 표시하므로 별도 처리 불필요.
@pragma('vm:entry-point')
Future<void> firebaseBackgroundHandler(RemoteMessage message) async {}
