import 'package:flutter/material.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

import '../../features/character/models/character_models.dart';
import '../../features/character/widgets/animated_mochi_widget.dart';

const _kIntroSeenKey = 'digda.characterIntroSeen';
const _storage = FlutterSecureStorage();

/// 캐릭터 탭 첫 진입 시 한 번만 보이는 온보딩 화면.
class CharacterIntroScreen extends StatefulWidget {
  const CharacterIntroScreen({super.key});

  static Future<bool> isAlreadySeen() async {
    final v = await _storage.read(key: _kIntroSeenKey);
    return v == 'true';
  }

  @override
  State<CharacterIntroScreen> createState() => _CharacterIntroScreenState();
}

class _CharacterIntroScreenState extends State<CharacterIntroScreen> {
  final PageController _page = PageController();
  int _current = 0;

  @override
  void dispose() {
    _page.dispose();
    super.dispose();
  }

  void _next() {
    if (_current < 1) {
      _page.nextPage(
        duration: const Duration(milliseconds: 280),
        curve: Curves.easeInOut,
      );
    } else {
      _finish();
    }
  }

  Future<void> _finish() async {
    await _storage.write(key: _kIntroSeenKey, value: 'true');
    if (!mounted) return;
    Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        children: [
          PageView(
            controller: _page,
            onPageChanged: (i) => setState(() => _current = i),
            children: [
              _PageOne(),
              _PageTwo(),
            ],
          ),
          Positioned(
            left: 0,
            right: 0,
            bottom: 0,
            child: _BottomBar(
              pageIndex: _current,
              onNext: _next,
            ),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// 페이지 1: 모찌 소개 (애니메이션 캐릭터)
// ─────────────────────────────────────────────────────────────────────────────
class _PageOne extends StatelessWidget {
  _PageOne();

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          colors: [Color(0xFFFF8E8E), Color(0xFFFF6B6B)],
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
        ),
      ),
      child: SafeArea(
        child: Column(
          children: [
            const Spacer(flex: 2),
            AnimatedMochiWidget(
              color: CharacterColor.coral,
              colorHex: '#FF6B6B',
              stage: CharacterStage.egg,
              size: 200,
              happiness: 0.8,
            ),
            const Spacer(flex: 1),
            const Padding(
              padding: EdgeInsets.symmetric(horizontal: 36),
              child: Column(
                children: [
                  Text(
                    '모찌를 소개해요!',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontFamily: 'Inter',
                      fontWeight: FontWeight.w700,
                      fontSize: 28,
                      color: Colors.white,
                      height: 1.2,
                    ),
                  ),
                  SizedBox(height: 16),
                  Text(
                    '디그팟과 함께하는 작은 마스코트,\n모찌예요. 함께 키워볼까요?',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontFamily: 'Inter',
                      fontWeight: FontWeight.w400,
                      fontSize: 16,
                      color: Colors.white,
                      height: 1.6,
                    ),
                  ),
                ],
              ),
            ),
            const Spacer(flex: 3),
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// 페이지 2: 키우는 방법 안내
// ─────────────────────────────────────────────────────────────────────────────
class _PageTwo extends StatelessWidget {
  _PageTwo();

  @override
  Widget build(BuildContext context) {
    return Container(
      color: const Color(0xFFFFF0F0),
      child: SafeArea(
        child: Column(
          children: [
            const Spacer(flex: 2),
            AnimatedMochiWidget(
              color: CharacterColor.coral,
              colorHex: '#FF6B6B',
              stage: CharacterStage.bloom,
              size: 160,
              happiness: 1.0,
            ),
            const Spacer(flex: 1),
            const Padding(
              padding: EdgeInsets.symmetric(horizontal: 36),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '이렇게 키워요',
                    style: TextStyle(
                      fontFamily: 'Inter',
                      fontWeight: FontWeight.w700,
                      fontSize: 24,
                      color: Color(0xFFFF6B6B),
                    ),
                  ),
                  SizedBox(height: 20),
                  _GuideRow(
                    emoji: '⚡',
                    title: '활동으로 EXP 획득',
                    body: '퀴즈를 풀거나 모찌를 쓰다듬으면 경험치가 쌓여요.',
                  ),
                  SizedBox(height: 14),
                  _GuideRow(
                    emoji: '🌱',
                    title: '레벨업하면 진화',
                    body: '3·6·10·15 레벨마다 모찌가 새 모습으로 자라요.',
                  ),
                  SizedBox(height: 14),
                  _GuideRow(
                    emoji: '🎨',
                    title: '코인으로 색 바꾸기',
                    body: '색상 상점에서 새로운 색을 해금해요.',
                  ),
                ],
              ),
            ),
            const Spacer(flex: 3),
          ],
        ),
      ),
    );
  }
}

class _GuideRow extends StatelessWidget {
  const _GuideRow({
    required this.emoji,
    required this.title,
    required this.body,
  });

  final String emoji;
  final String title;
  final String body;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(emoji, style: const TextStyle(fontSize: 22)),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: const TextStyle(
                  fontFamily: 'Inter',
                  fontWeight: FontWeight.w700,
                  fontSize: 15,
                  color: Color(0xFF191F28),
                ),
              ),
              const SizedBox(height: 2),
              Text(
                body,
                style: const TextStyle(
                  fontFamily: 'Inter',
                  fontWeight: FontWeight.w400,
                  fontSize: 13,
                  height: 1.5,
                  color: Color(0xFF4E5968),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// 하단 버튼 / 인디케이터
// ─────────────────────────────────────────────────────────────────────────────
class _BottomBar extends StatelessWidget {
  const _BottomBar({required this.pageIndex, required this.onNext});

  final int pageIndex;
  final VoidCallback onNext;

  @override
  Widget build(BuildContext context) {
    final isLast = pageIndex == 1;
    return Container(
      padding: EdgeInsets.fromLTRB(
        24,
        16,
        24,
        MediaQuery.of(context).padding.bottom + 24,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: List.generate(2, (i) {
              return AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                margin: const EdgeInsets.symmetric(horizontal: 4),
                width: i == pageIndex ? 20 : 8,
                height: 8,
                decoration: BoxDecoration(
                  color: i == pageIndex
                      ? const Color(0xFFFF6B6B)
                      : const Color(0xFFFFB3B3),
                  borderRadius: BorderRadius.circular(4),
                ),
              );
            }),
          ),
          const SizedBox(height: 20),
          SizedBox(
            width: double.infinity,
            height: 56,
            child: ElevatedButton(
              onPressed: onNext,
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFFFF6B6B),
                foregroundColor: Colors.white,
                elevation: 0,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
              ),
              child: Text(
                isLast ? '시작하기' : '다음',
                style: const TextStyle(
                  fontFamily: 'Inter',
                  fontWeight: FontWeight.w700,
                  fontSize: 17,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
