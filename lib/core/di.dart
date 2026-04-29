import 'auth/token_storage.dart';
import 'network/api_client.dart';
import '../features/auth/data/auth_repository.dart';
import '../features/auth/data/social_auth_service.dart';
import '../features/auth/state/auth_session.dart';
import '../features/user/data/user_repository.dart';
import '../features/user/state/user_session.dart';
import '../features/group_room/data/group_room_repository.dart';
import '../features/invite/data/invite_repository.dart';
import '../features/membership/data/membership_repository.dart';

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
  static late final AuthSession authSession;
  static late final UserSession userSession;

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
    authSession = AuthSession(repository: authRepository, api: apiClient);
    userSession = UserSession(repository: userRepository);
  }
}
