import 'dart:convert';

import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';

import 'notification_router.dart';

const String _channelId = 'digda_default';
const String _channelName = '디그팟 알림';

/// 앱이 포그라운드일 때 FCM 메시지를 시스템 알림으로 표시하고, 알림 탭 시
/// 종류에 맞는 화면으로 이동시킨다(딥링크 라우팅).
///
/// 세 경로 모두 [NotificationRouter] 로 모은다:
///  - 포그라운드: 로컬 알림 탭(payload 에 data 를 실어 보냄)
///  - 백그라운드에서 탭: [FirebaseMessaging.onMessageOpenedApp]
///  - 종료 상태에서 탭: [FirebaseMessaging.getInitialMessage] (pending 으로 보관)
class PushService {
  static final _plugin = FlutterLocalNotificationsPlugin();

  static Future<void> init() async {
    const androidSettings = AndroidInitializationSettings('@mipmap/ic_launcher');
    await _plugin.initialize(
      const InitializationSettings(android: androidSettings),
      onDidReceiveNotificationResponse: _onLocalNotificationTap,
    );

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
        // 탭 시 라우팅에 쓰도록 FCM data 를 payload 로 실어 보낸다.
        payload: jsonEncode(message.data),
      );
    });

    // 백그라운드 상태에서 알림을 탭해 앱이 열린 경우.
    FirebaseMessaging.onMessageOpenedApp.listen((message) {
      NotificationRouter.route(message.data);
    });

    // 종료 상태에서 알림 탭으로 앱이 시작된 경우 — 첫 프레임 후 처리하도록 보관.
    final initial = await FirebaseMessaging.instance.getInitialMessage();
    if (initial != null) {
      NotificationRouter.setPending(initial.data);
    }
  }

  static void _onLocalNotificationTap(NotificationResponse response) {
    final payload = response.payload;
    if (payload == null || payload.isEmpty) return;
    try {
      final data = (jsonDecode(payload) as Map).cast<String, dynamic>();
      NotificationRouter.route(data);
    } catch (_) {}
  }
}

/// 앱 종료/백그라운드 상태에서 호출되는 최상위 핸들러.
/// notification+data 페이로드는 OS가 자동 표시하므로 별도 처리 불필요.
@pragma('vm:entry-point')
Future<void> firebaseBackgroundHandler(RemoteMessage message) async {}
