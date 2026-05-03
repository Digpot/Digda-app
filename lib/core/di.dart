import 'auth/token_storage.dart';
import 'network/api_client.dart';
import '../features/auth/data/auth_repository.dart';
import '../features/auth/data/social_auth_service.dart';
import '../features/auth/state/auth_session.dart';
import '../features/user/data/user_repository.dart';
import '../features/user/state/user_session.dart';
import '../features/group_room/data/group_room_repository.dart';
import '../features/group_room/state/active_group_session.dart';
import '../features/invite/data/invite_repository.dart';
import '../features/membership/data/membership_repository.dart';
import '../features/schedule/data/schedule_repository.dart';
import '../features/diary/data/diary_repository.dart';
import '../features/comment/data/comment_repository.dart';
import '../features/todo/data/todo_repository.dart';
import '../features/notification/data/notification_repository.dart';
import '../features/device/data/device_repository.dart';
import '../features/upload/data/upload_repository.dart';

/// 외부 의존성 주입 프레임워크 없이 단일 인스턴스를 공유하기 위한 가벼운 로케이터.
class Di {
  Di._();

  static late final TokenStorage tokenStorage;
  static late final ApiClient apiClient;
  static late final SocialAuthService socialAuth;
  static late final AuthRepository authRepository;
  static late final UserRepository userRepository;
  static late final GroupRoomRepository groupRoomRepository;
  static late final InviteRepository inviteRepository;
  static late final MembershipRepository membershipRepository;
  static late final ScheduleRepository scheduleRepository;
  static late final DiaryRepository diaryRepository;
  static late final CommentRepository commentRepository;
  static late final TodoRepository todoRepository;
  static late final NotificationRepository notificationRepository;
  static late final DeviceRepository deviceRepository;
  static late final UploadRepository uploadRepository;
  static late final AuthSession authSession;
  static late final UserSession userSession;
  static late final ActiveGroupSession activeGroup;

  /// `main()` 의 `runApp` 직전에 호출.
  static void bootstrap() {
    tokenStorage = TokenStorage();
    apiClient = ApiClient(tokenStorage: tokenStorage);
    socialAuth = SocialAuthService();
    authRepository = AuthRepository(apiClient: apiClient, socialAuth: socialAuth);
    userRepository = UserRepository(apiClient: apiClient);
    groupRoomRepository = GroupRoomRepository(apiClient: apiClient);
    inviteRepository = InviteRepository(apiClient: apiClient);
    membershipRepository = MembershipRepository(apiClient: apiClient);
    scheduleRepository = ScheduleRepository(apiClient: apiClient);
    diaryRepository = DiaryRepository(apiClient: apiClient);
    commentRepository = CommentRepository(apiClient: apiClient);
    todoRepository = TodoRepository(apiClient: apiClient);
    notificationRepository = NotificationRepository(apiClient: apiClient);
    deviceRepository = DeviceRepository(apiClient: apiClient);
    uploadRepository = UploadRepository(apiClient: apiClient);
    authSession = AuthSession(
      repository: authRepository,
      api: apiClient,
      deviceRepository: deviceRepository,
      tokenStorage: tokenStorage,
    );
    userSession = UserSession(repository: userRepository);
    activeGroup = ActiveGroupSession();
  }
}
