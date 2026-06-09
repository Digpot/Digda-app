import 'package:flutter/material.dart';
import 'screens/splash/splash_screen.dart';
import 'screens/auth/social_login_screen.dart';
import 'screens/auth/terms_agreement_screen.dart';
import 'screens/onboarding/empty_state_screen.dart';
import 'screens/onboarding/code_generate_screen.dart';
import 'screens/onboarding/create_diary_screen.dart';
import 'screens/onboarding/code_input_screen.dart';
import 'screens/group/group_list_screen.dart';
import 'screens/group/group_home_screen.dart';
import 'screens/group/transfer_owner_screen.dart';
import 'screens/schedule/schedule_calendar_screen.dart';
import 'screens/schedule/schedule_detail_screen.dart';
import 'screens/schedule/add_schedule_screen.dart';
import 'screens/diary/diary_calendar_screen.dart';
import 'screens/diary/diary_detail_screen.dart';
import 'screens/diary/write_diary_screen.dart';
import 'screens/diary/edit_diary_screen.dart';
import 'screens/character/character_main_screen.dart';
import 'screens/character/character_dex_screen.dart';
import 'screens/character/character_stage_tree_screen.dart';
import 'screens/character/character_shop_screen.dart';
import 'screens/character/quiz/character_quiz_play_screen.dart';
import 'screens/character/quiz/character_quiz_create_screen.dart';
import 'screens/mypage/my_page_screen.dart';
import 'screens/title/title_collection_screen.dart';
import 'screens/mypage/edit_profile_screen.dart';
import 'screens/mypage/notification_settings_screen.dart';
import 'screens/mypage/privacy_settings_screen.dart';
import 'screens/notifications/notifications_screen.dart';
import 'screens/todo/todo_list_screen.dart';
import 'screens/legal/terms_detail_screen.dart';
import 'screens/legal/delete_account_screen.dart';
import 'screens/onboarding/app_guide_screen.dart';
import 'screens/onboarding/manage_diary_screen.dart';

class AppRouter {
  // 탭 전환 시 푸터 애니메이션 없이 즉시 전환
  static PageRoute<T> _tabRoute<T>(Widget screen, RouteSettings settings) {
    return PageRouteBuilder<T>(
      settings: settings,
      pageBuilder: (_, __, ___) => screen,
      transitionDuration: Duration.zero,
      reverseTransitionDuration: Duration.zero,
    );
  }

  static Route<dynamic> generateRoute(RouteSettings settings) {
    switch (settings.name) {
      case '/':
        return MaterialPageRoute(
            settings: settings, builder: (_) => const SplashScreen());
      case '/login':
        return MaterialPageRoute(
            settings: settings, builder: (_) => const SocialLoginScreen());
      case '/terms':
        final loginType = settings.arguments as String? ?? 'kakao';
        return MaterialPageRoute(
            settings: settings,
            builder: (_) => TermsAgreementScreen(loginType: loginType));
      case '/home':
        return _tabRoute(const EmptyStateScreen(), settings);
      case '/code-generate':
        return MaterialPageRoute(
            settings: settings, builder: (_) => const CodeGenerateScreen());
      case '/create-diary':
        return MaterialPageRoute(
            settings: settings, builder: (_) => const CreateDiaryScreen());
      case '/update-diary':
        return MaterialPageRoute(
            settings: settings,
            builder: (_) => const CreateDiaryScreen(isEdit: true));
      case '/manage-diary':
        return MaterialPageRoute(
            settings: settings, builder: (_) => const ManageDiaryScreen());
      case '/group-list':
        return MaterialPageRoute(
            settings: settings, builder: (_) => const GroupListScreen());
      case '/group-home':
        final groupArgs = settings.arguments;
        final groupName = groupArgs is Map<String, dynamic>
            ? groupArgs['name'] as String? ?? ''
            : groupArgs is String
                ? groupArgs
                : '';
        return _tabRoute(GroupHomeScreen(
          groupName: groupName,
        ), settings);
      case '/transfer-owner':
        return MaterialPageRoute(
            settings: settings, builder: (_) => const TransferOwnerScreen());
      case '/schedule':
        return _tabRoute(const ScheduleCalendarScreen(), settings);
      case '/schedule-detail':
        return MaterialPageRoute(
            settings: settings, builder: (_) => const ScheduleDetailScreen());
      case '/add-schedule':
        return MaterialPageRoute(
            settings: settings, builder: (_) => const AddScheduleScreen());
      case '/diary':
        return _tabRoute(const DiaryCalendarScreen(), settings);
      case '/diary-detail':
        return MaterialPageRoute(
            settings: settings, builder: (_) => const DiaryDetailScreen());
      case '/write-diary':
        return MaterialPageRoute(
            settings: settings, builder: (_) => const WriteDiaryScreen());
      case '/edit-diary':
        return MaterialPageRoute(
            settings: settings, builder: (_) => const EditDiaryScreen());
      case '/character':
        return _tabRoute(const CharacterMainScreen(), settings);
      case '/character-dex':
        return MaterialPageRoute(
            settings: settings, builder: (_) => const CharacterDexScreen());
      case '/character-stages':
        return MaterialPageRoute(
            settings: settings,
            builder: (_) => const CharacterStageTreeScreen());
      case '/character-shop':
        return MaterialPageRoute(
            settings: settings,
            builder: (_) => const CharacterShopScreen());
      case '/character-quiz-play':
        return MaterialPageRoute(
            settings: settings,
            builder: (_) => const CharacterQuizPlayScreen());
      case '/character-quiz-create':
        return MaterialPageRoute(
            settings: settings,
            builder: (_) => const CharacterQuizCreateScreen());
      case '/my-page':
        return MaterialPageRoute(
            settings: settings, builder: (_) => const MyPageScreen());
      case '/titles':
        return MaterialPageRoute(
            settings: settings, builder: (_) => const TitleCollectionScreen());
      case '/edit-profile':
        return MaterialPageRoute(
            settings: settings, builder: (_) => const EditProfileScreen());
      case '/notification-settings':
        return MaterialPageRoute(
            settings: settings,
            builder: (_) => const NotificationSettingsScreen());
      case '/privacy-settings':
        return MaterialPageRoute(
            settings: settings,
            builder: (_) => const PrivacySettingsScreen());
      case '/notifications':
        return MaterialPageRoute(
            settings: settings, builder: (_) => const NotificationsScreen());
      case '/todo':
        return MaterialPageRoute(
            settings: settings, builder: (_) => const TodoListScreen());
      case '/code-input':
        final code = settings.arguments as String?;
        return MaterialPageRoute(
            settings: settings,
            builder: (_) => CodeInputScreen(initialCode: code));
      case '/terms-detail':
        final type = settings.arguments as String? ?? 'terms';
        return MaterialPageRoute(
            settings: settings,
            builder: (_) => TermsDetailScreen(type: type));
      case '/delete-account':
        return MaterialPageRoute(
            settings: settings, builder: (_) => const DeleteAccountScreen());
      case '/app-guide':
        final isFromMyPage = settings.arguments as bool? ?? false;
        return MaterialPageRoute(
            settings: settings,
            builder: (_) => AppGuideScreen(isFromMyPage: isFromMyPage));
      default:
        return MaterialPageRoute(
          settings: settings,
          builder: (_) => Scaffold(
            body: Center(
              child: Text('경로를 찾을 수 없어요: ${settings.name}'),
            ),
          ),
        );
    }
  }
}
