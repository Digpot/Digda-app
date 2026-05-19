import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_svg/flutter_svg.dart';
import '../../core/di.dart';
import '../../core/route_observer.dart';
import '../../theme/colors.dart';
import '../../widgets/notification_bell_icon.dart';
import '../../widgets/primary_button.dart';
import '../../widgets/outline_button.dart';

class EmptyStateScreen extends StatefulWidget {
  const EmptyStateScreen({super.key});

  @override
  State<EmptyStateScreen> createState() => _EmptyStateScreenState();
}

class _EmptyStateScreenState extends State<EmptyStateScreen>
    with RouteAware {
  /// 그룹방 목록 조회 결과를 알기 전까지는 컨텐츠를 그리지 않는다.
  /// 그룹방이 1개라도 있으면 즉시 /group-list 로 replace 하므로, 잠깐의 빈 화면이
  /// 깜빡이지 않도록 로딩 인디케이터로 가린다.
  bool _checking = true;
  PageRoute<dynamic>? _subscribedRoute;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _redirectIfHasGroup());
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // 라우트 변경(다른 화면이 위로 push/pop)을 감지하기 위해 RouteObserver 구독.
    final route = ModalRoute.of(context);
    if (route is PageRoute) {
      if (!identical(route, _subscribedRoute)) {
        if (_subscribedRoute != null) {
          appRouteObserver.unsubscribe(this);
        }
        appRouteObserver.subscribe(this, route);
        _subscribedRoute = route;
      }
    }
  }

  @override
  void dispose() {
    appRouteObserver.unsubscribe(this);
    super.dispose();
  }

  /// 다른 화면이 위에서 pop 되어 이 화면이 다시 노출됐을 때 호출된다.
  /// 그 사이 그룹방이 생겼다면 즉시 /group-list 로 보낸다 — 예: code-input 에서
  /// join 한 뒤 group-home 을 뒤로가기로 빠져나와 stale 인스턴스에 닿는 케이스.
  @override
  void didPopNext() {
    _redirectIfHasGroup(silent: true);
  }

  /// [silent] = true 면 빈 결과여도 로딩 인디케이터를 다시 띄우지 않는다
  /// (didPopNext 시 화면이 깜빡이지 않게).
  Future<void> _redirectIfHasGroup({bool silent = false}) async {
    if (!silent && !_checking) {
      setState(() => _checking = true);
    }
    try {
      final list = await Di.groupRoomRepository.myList();
      if (!mounted) return;
      if (list.isNotEmpty) {
        // 이미 그룹방이 있는 사용자에게는 그룹방 목록이 홈이다.
        // create-diary 에서 뒤로가기로 돌아왔을 때도 empty 화면이 다시 뜨지 않게
        // pushReplacement 로 스택을 교체한다.
        Navigator.of(context).pushReplacementNamed('/group-list');
        return;
      }
    } catch (_) {
      // 조회 실패 시에는 그냥 empty 상태를 보여준다.
    }
    if (mounted && _checking) setState(() => _checking = false);
  }

  @override
  Widget build(BuildContext context) {
    if (_checking) {
      return const Scaffold(
        backgroundColor: AppColors.white,
        body: Center(child: CircularProgressIndicator()),
      );
    }
    return Scaffold(
      backgroundColor: AppColors.white,
      body: SafeArea(
        child: Column(
          children: [
            // 헤더
            Padding(
              padding:
                  const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              child: Row(
                children: [
                  SvgPicture.asset(
                    'assets/svg/logo.svg',
                    width: 28,
                    height: 29,
                  ),
                  const SizedBox(width: 8),
                  const Text(
                    '디그팟',
                    style: TextStyle(
                      fontFamily: 'Inter',
                      fontWeight: FontWeight.w700,
                      fontSize: 20,
                      height: 1.2,
                      letterSpacing: 0,
                      color: AppColors.gray900,
                    ),
                  ),
                  const Spacer(),
                  const NotificationBellIcon(),
                  const SizedBox(width: 16),
                  GestureDetector(
                    onTap: () =>
                        Navigator.of(context).pushNamed('/my-page'),
                    child: const Icon(
                      Icons.settings_outlined,
                      size: 22,
                      color: AppColors.gray700,
                    ),
                  ),
                ],
              ),
            ),
            const Spacer(),
            // 빈 상태 일러스트
            Column(
              children: [
                Container(
                  width: 120,
                  height: 120,
                  decoration: BoxDecoration(
                    color: AppColors.primary.withValues(alpha: 0.08),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.auto_stories_outlined,
                    size: 52,
                    color: AppColors.primary,
                  ),
                ),
                const SizedBox(height: 24),
                const Text(
                  '아직 참여 중인 다이어리가 없어요',
                  style: TextStyle(
                    fontFamily: 'Inter',
                    fontWeight: FontWeight.w700,
                    fontSize: 18,
                    height: 1.3,
                    letterSpacing: 0,
                    color: AppColors.gray900,
                  ),
                ),
                const SizedBox(height: 8),
                const Text(
                  '초대 코드를 입력하거나, 새로 만들어보세요',
                  style: TextStyle(
                    fontFamily: 'Inter',
                    fontWeight: FontWeight.w400,
                    fontSize: 14,
                    height: 1.5,
                    letterSpacing: 0,
                    color: AppColors.gray500,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 40),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24),
              child: AppOutlineButton(
                text: '초대 코드 입력하기',
                onPressed: () {
                  showModalBottomSheet(
                    context: context,
                    isScrollControlled: true,
                    shape: const RoundedRectangleBorder(
                      borderRadius:
                          BorderRadius.vertical(top: Radius.circular(20)),
                    ),
                    builder: (context) => const CodeInputBottomSheet(),
                  );
                },
              ),
            ),
            const SizedBox(height: 12),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24),
              child: PrimaryButton(
                text: '새 다이어리 만들기',
                onPressed: () =>
                    Navigator.of(context).pushNamed('/create-diary'),
              ),
            ),
            const Spacer(),
          ],
        ),
      ),
    );
  }
}

class CodeInputBottomSheet extends StatefulWidget {
  const CodeInputBottomSheet({super.key});

  @override
  State<CodeInputBottomSheet> createState() => _CodeInputBottomSheetState();
}

class _CodeInputBottomSheetState extends State<CodeInputBottomSheet> {
  static const int _codeLength = 6;
  final List<TextEditingController> _controllers =
      List.generate(_codeLength, (_) => TextEditingController());
  final List<FocusNode> _focusNodes =
      List.generate(_codeLength, (_) => FocusNode());

  bool get _isFilled => _controllers.every((c) => c.text.isNotEmpty);

  @override
  void dispose() {
    for (final c in _controllers) {
      c.dispose();
    }
    for (final f in _focusNodes) {
      f.dispose();
    }
    super.dispose();
  }

  String get _enteredCode => _controllers.map((c) => c.text).join();

  void _onChanged(String value, int index) {
    if (value.length == 1 && index < _codeLength - 1) {
      _focusNodes[index + 1].requestFocus();
    } else if (value.isEmpty && index > 0) {
      _focusNodes[index - 1].requestFocus();
    }
    setState(() {});
  }

  void _onSubmit() {
    final code = _enteredCode;
    Navigator.of(context).pop(); // 바텀시트 닫기
    Navigator.of(context).pushNamed('/code-input', arguments: code);
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(
        left: 24,
        right: 24,
        top: 16,
        bottom: MediaQuery.of(context).viewInsets.bottom + MediaQuery.of(context).padding.bottom + 24,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Center(
            child: Container(
              width: 36,
              height: 4,
              decoration: BoxDecoration(
                color: AppColors.gray200,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          const SizedBox(height: 24),
          const Text(
            '초대 코드를 입력하세요',
            style: TextStyle(
              fontFamily: 'Inter',
              fontWeight: FontWeight.w700,
              fontSize: 20,
              height: 1.3,
              letterSpacing: 0,
              color: AppColors.gray900,
            ),
          ),
          const SizedBox(height: 6),
          const Text(
            '상대방에게 받은 6자리 코드를 입력해주세요',
            style: TextStyle(
              fontFamily: 'Inter',
              fontWeight: FontWeight.w400,
              fontSize: 14,
              height: 1.5,
              letterSpacing: 0,
              color: AppColors.gray500,
            ),
          ),
          const SizedBox(height: 24),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: List.generate(_codeLength, (index) {
              return SizedBox(
                width: 48,
                height: 56,
                child: TextField(
                  controller: _controllers[index],
                  focusNode: _focusNodes[index],
                  maxLength: 1,
                  textAlign: TextAlign.center,
                  keyboardType: TextInputType.number,
                  inputFormatters: [
                    FilteringTextInputFormatter.digitsOnly,
                  ],
                  style: const TextStyle(
                    fontFamily: 'Inter',
                    fontWeight: FontWeight.w600,
                    fontSize: 20,
                    color: AppColors.gray900,
                  ),
                  decoration: InputDecoration(
                    counterText: '',
                    filled: true,
                    fillColor: AppColors.gray50,
                    contentPadding: EdgeInsets.zero,
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(10),
                      borderSide: BorderSide(
                        color: _controllers[index].text.isNotEmpty
                            ? AppColors.primary
                            : AppColors.gray200,
                      ),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(10),
                      borderSide: const BorderSide(
                        color: AppColors.primary,
                        width: 1.5,
                      ),
                    ),
                  ),
                  onChanged: (value) => _onChanged(value, index),
                  onTap: () => setState(() {}),
                ),
              );
            }),
          ),
          const SizedBox(height: 32),
          PrimaryButton(
            text: '참여하기',
            onPressed: _isFilled ? _onSubmit : null,
          ),
        ],
      ),
    );
  }
}
