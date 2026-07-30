import 'package:flutter/material.dart';

import '../../../theme/colors.dart';

/// 미니게임 화면 공용 소품 — 게임마다 따로 굴러다니던 칩·카드·버튼을 한곳에 모아
/// 같은 결(둥근 20pt, 헤어라인 테두리, 옅은 그림자, 그라디언트 강조)을 공유한다.
///
/// 여기 있는 위젯만 써도 오목/알까기/캐치마인드/끝말잇기/탭배틀이 같은 톤으로 보인다.

/// 게임 화면 공통 배경 — 흰색이 아니라 아주 옅은 회색으로 깔아
/// 카드/캔버스의 흰색이 떠 보이게 한다.
const Color gameSurface = Color(0xFFF7F8FA);

/// 강조 그라디언트 — 주요 버튼/포커스 요소에 공통으로 쓴다.
const LinearGradient gamePrimaryGradient = LinearGradient(
  begin: Alignment.topLeft,
  end: Alignment.bottomRight,
  colors: [Color(0xFFFF8A7A), AppColors.primary],
);

/// 카드/칩에 공통으로 얹는 아주 옅은 그림자.
const List<BoxShadow> gameSoftShadow = [
  BoxShadow(
    color: Color(0x0F111827),
    blurRadius: 14,
    offset: Offset(0, 4),
  ),
];

/// 게임 참가자 아바타.
///
/// 게임 참가자에겐 멤버 색 정보가 없어(서버 스냅샷에 이름만),
/// 이름 해시로 파스텔 색을 안정적으로 골라 같은 사람은 늘 같은 색이 되게 한다.
class GamePlayerAvatar extends StatelessWidget {
  const GamePlayerAvatar({
    super.key,
    required this.name,
    this.size = 38,
    this.dimmed = false,
    this.highlighted = false,
  });

  final String name;
  final double size;

  /// 탈락/거절/기권 등 가라앉은 상태 — 회색 처리.
  final bool dimmed;

  /// 지금 차례 등 강조 — 바깥에 은은한 링을 두른다.
  final bool highlighted;

  static const List<Color> _palette = [
    Color(0xFFFF8A5B),
    Color(0xFFFF6B6B),
    Color(0xFF34C08A),
    Color(0xFFF4B53C),
    Color(0xFFA98BF0),
    Color(0xFF5BB7D9),
    Color(0xFFF47BB4),
    Color(0xFF8FBF5A),
  ];

  static Color accentOf(String name) =>
      _palette[name.hashCode.abs() % _palette.length];

  Color get _accent => dimmed ? const Color(0xFF9CA3AF) : accentOf(name);

  @override
  Widget build(BuildContext context) {
    final accent = _accent;
    return Container(
      width: size,
      height: size,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            accent.withValues(alpha: dimmed ? 0.10 : 0.22),
            accent.withValues(alpha: dimmed ? 0.06 : 0.10),
          ],
        ),
        shape: BoxShape.circle,
        border: Border.all(
          color: accent.withValues(alpha: highlighted ? 0.9 : 0.35),
          width: highlighted ? 2 : 1,
        ),
        boxShadow: highlighted
            ? [
                BoxShadow(
                  color: accent.withValues(alpha: 0.25),
                  blurRadius: 10,
                  offset: const Offset(0, 3),
                ),
              ]
            : null,
      ),
      child: Text(
        name.isEmpty ? '?' : name.characters.first,
        style: TextStyle(
          fontFamily: 'Inter',
          fontWeight: FontWeight.w800,
          fontSize: size * 0.4,
          color: accent,
        ),
      ),
    );
  }
}

/// 흰 카드 — 헤어라인 테두리 + 옅은 그림자. 강조 시 색 테두리로 바뀐다.
class GameCard extends StatelessWidget {
  const GameCard({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
    this.accent,
    this.radius = 18,
    this.margin,
  });

  final Widget child;
  final EdgeInsets padding;

  /// null 이 아니면 그 색의 옅은 배경 + 테두리로 강조한다.
  final Color? accent;
  final double radius;
  final EdgeInsets? margin;

  @override
  Widget build(BuildContext context) {
    final accent = this.accent;
    return Container(
      margin: margin,
      padding: padding,
      decoration: BoxDecoration(
        color: accent == null
            ? AppColors.white
            : Color.alphaBlend(accent.withValues(alpha: 0.06), AppColors.white),
        borderRadius: BorderRadius.circular(radius),
        border: Border.all(
          color: accent?.withValues(alpha: 0.45) ?? AppColors.gray100,
          width: accent == null ? 1 : 1.4,
        ),
        boxShadow: gameSoftShadow,
      ),
      child: child,
    );
  }
}

/// 작은 알약 라벨 — 라운드 표시, 규칙 안내, 상태 배지 등.
class GamePill extends StatelessWidget {
  const GamePill({
    super.key,
    required this.label,
    this.color = AppColors.primary,
    this.icon,
    this.solid = false,
    this.fontSize = 12,
  });

  final String label;
  final Color color;
  final IconData? icon;

  /// true 면 색을 꽉 채우고 흰 글씨.
  final bool solid;
  final double fontSize;

  @override
  Widget build(BuildContext context) {
    final fg = solid ? Colors.white : color;
    return Container(
      padding: EdgeInsets.symmetric(horizontal: icon == null ? 11 : 9, vertical: 5.5),
      decoration: BoxDecoration(
        color: solid ? color : color.withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(999),
        border: solid
            ? null
            : Border.all(color: color.withValues(alpha: 0.20)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icon != null) ...[
            Icon(icon, size: fontSize + 2, color: fg),
            const SizedBox(width: 4),
          ],
          Text(
            label,
            style: TextStyle(
              fontFamily: 'Inter',
              fontWeight: FontWeight.w800,
              fontSize: fontSize,
              color: fg,
            ),
          ),
        ],
      ),
    );
  }
}

/// 남은 시간 알약 — 임박하면(<= [urgentAt]) 빨갛게 물들며 은은하게 맥동한다.
class GameCountdownPill extends StatefulWidget {
  const GameCountdownPill({
    super.key,
    required this.seconds,
    this.urgentAt = 10,
    this.suffix = '',
  });

  final int seconds;
  final int urgentAt;
  final String suffix;

  @override
  State<GameCountdownPill> createState() => _GameCountdownPillState();
}

class _GameCountdownPillState extends State<GameCountdownPill>
    with SingleTickerProviderStateMixin {
  late final AnimationController _pulse = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 700),
  );

  bool get _urgent => widget.seconds <= widget.urgentAt;

  @override
  void initState() {
    super.initState();
    if (_urgent) _pulse.repeat(reverse: true);
  }

  @override
  void didUpdateWidget(covariant GameCountdownPill old) {
    super.didUpdateWidget(old);
    // 임박 구간에 들어올 때만 맥동을 켠다 — 평소엔 애니메이션을 아예 돌리지 않는다.
    if (_urgent && !_pulse.isAnimating) {
      _pulse.repeat(reverse: true);
    } else if (!_urgent && _pulse.isAnimating) {
      _pulse.stop();
      _pulse.value = 0;
    }
  }

  @override
  void dispose() {
    _pulse.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final urgent = _urgent;
    return AnimatedBuilder(
      animation: _pulse,
      builder: (context, child) => Transform.scale(
        scale: urgent ? 1 + _pulse.value * 0.06 : 1,
        child: child,
      ),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 6),
        decoration: BoxDecoration(
          color: urgent ? const Color(0xFFFFECEC) : AppColors.gray50,
          borderRadius: BorderRadius.circular(999),
          border: Border.all(
            color: urgent
                ? AppColors.primary.withValues(alpha: 0.35)
                : AppColors.gray100,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.timer_outlined,
              size: 13,
              color: urgent ? AppColors.primary : AppColors.gray600,
            ),
            const SizedBox(width: 4),
            Text(
              '${widget.seconds}${widget.suffix}',
              style: TextStyle(
                fontFamily: 'Inter',
                fontWeight: FontWeight.w800,
                fontSize: 12.5,
                color: urgent ? AppColors.primary : AppColors.gray700,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// 게임 화면의 주요 CTA — 그라디언트 채움. 비활성이면 회색 평면.
class GamePrimaryButton extends StatelessWidget {
  const GamePrimaryButton({
    super.key,
    required this.label,
    required this.onPressed,
    this.height = 52,
    this.busy = false,
  });

  final String label;
  final VoidCallback? onPressed;
  final double height;
  final bool busy;

  @override
  Widget build(BuildContext context) {
    final enabled = onPressed != null && !busy;
    return SizedBox(
      height: height,
      child: DecoratedBox(
        decoration: BoxDecoration(
          gradient: enabled ? gamePrimaryGradient : null,
          color: enabled ? null : AppColors.gray100,
          borderRadius: BorderRadius.circular(16),
          boxShadow: enabled
              ? [
                  BoxShadow(
                    color: AppColors.primary.withValues(alpha: 0.28),
                    blurRadius: 14,
                    offset: const Offset(0, 5),
                  ),
                ]
              : null,
        ),
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: enabled ? onPressed : null,
            borderRadius: BorderRadius.circular(16),
            child: Center(
              child: busy
                  ? const SizedBox(
                      width: 21,
                      height: 21,
                      child: CircularProgressIndicator(
                        strokeWidth: 2.4,
                        color: Colors.white,
                      ),
                    )
                  : Text(
                      label,
                      style: TextStyle(
                        fontFamily: 'Inter',
                        fontWeight: FontWeight.w800,
                        fontSize: 15.5,
                        color: enabled ? Colors.white : AppColors.gray400,
                      ),
                    ),
            ),
          ),
        ),
      ),
    );
  }
}

/// 보조 액션 — 흰 배경 + 헤어라인 테두리.
class GameGhostButton extends StatelessWidget {
  const GameGhostButton({
    super.key,
    required this.label,
    required this.onPressed,
    this.height = 52,
    this.color = AppColors.gray700,
  });

  final String label;
  final VoidCallback? onPressed;
  final double height;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: height,
      child: OutlinedButton(
        onPressed: onPressed,
        style: OutlinedButton.styleFrom(
          foregroundColor: color,
          backgroundColor: AppColors.white,
          side: const BorderSide(color: AppColors.gray200),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
        ),
        child: Text(
          label,
          style: const TextStyle(
            fontFamily: 'Inter',
            fontWeight: FontWeight.w800,
            fontSize: 15,
          ),
        ),
      ),
    );
  }
}

/// 헤더 우측에 다는 기권 버튼 — 모든 대전 게임이 같은 자리·같은 모양으로 쓴다.
class GameForfeitAction extends StatelessWidget {
  const GameForfeitAction({
    super.key,
    required this.onPressed,
    this.label = '기권',
    this.dark = false,
  });

  final VoidCallback onPressed;
  final String label;

  /// 어두운 배경 화면(알까기)용 — 흰 글씨 + 반투명 배경.
  final bool dark;

  @override
  Widget build(BuildContext context) {
    final fg = dark ? Colors.white70 : AppColors.gray700;
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onPressed,
        borderRadius: BorderRadius.circular(999),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
          decoration: BoxDecoration(
            color: dark ? Colors.white.withValues(alpha: 0.08) : AppColors.gray50,
            borderRadius: BorderRadius.circular(999),
            border: Border.all(
              color: dark
                  ? Colors.white.withValues(alpha: 0.20)
                  : AppColors.gray100,
            ),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.flag_outlined, size: 15, color: fg),
              const SizedBox(width: 5),
              Text(
                label,
                style: TextStyle(
                  fontFamily: 'Inter',
                  fontWeight: FontWeight.w800,
                  fontSize: 13,
                  color: fg,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// 로비 상단 — 큰 이모지 + 방 제목 + 부제 + 규칙 알약.
class GameLobbyIntro extends StatelessWidget {
  const GameLobbyIntro({
    super.key,
    required this.emoji,
    required this.title,
    required this.subtitle,
    this.rule,
  });

  final String emoji;
  final String title;
  final String subtitle;
  final String? rule;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        const SizedBox(height: 6),
        Container(
          width: 72,
          height: 72,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                AppColors.primary.withValues(alpha: 0.14),
                AppColors.primary.withValues(alpha: 0.04),
              ],
            ),
            border: Border.all(color: AppColors.primary.withValues(alpha: 0.16)),
          ),
          child: Text(emoji, style: const TextStyle(fontSize: 34)),
        ),
        const SizedBox(height: 12),
        Text(
          title,
          textAlign: TextAlign.center,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(
            fontFamily: 'Inter',
            fontWeight: FontWeight.w800,
            fontSize: 19,
            color: AppColors.gray900,
          ),
        ),
        const SizedBox(height: 5),
        Text(
          subtitle,
          textAlign: TextAlign.center,
          style: const TextStyle(
            fontFamily: 'Inter',
            fontWeight: FontWeight.w500,
            fontSize: 12.5,
            color: AppColors.gray500,
          ),
        ),
        if (rule != null) ...[
          const SizedBox(height: 10),
          GamePill(label: rule!),
        ],
      ],
    );
  }
}

/// 로비 참가자 한 줄 — 아바타 + 이름(+왕관) + 상태 배지.
class GameRosterTile extends StatelessWidget {
  const GameRosterTile({
    super.key,
    required this.name,
    required this.isMe,
    required this.isHost,
    required this.statusLabel,
    required this.statusColor,
    this.joined = false,
    this.dimmed = false,
  });

  final String name;
  final bool isMe;
  final bool isHost;
  final String statusLabel;
  final Color statusColor;
  final bool joined;
  final bool dimmed;

  @override
  Widget build(BuildContext context) {
    return GameCard(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      accent: joined ? AppColors.primary : null,
      child: Row(
        children: [
          GamePlayerAvatar(name: name, dimmed: dimmed),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              isMe ? '$name (나)' : name,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontFamily: 'Inter',
                fontWeight: FontWeight.w700,
                fontSize: 14.5,
                color: dimmed ? AppColors.gray500 : AppColors.gray900,
              ),
            ),
          ),
          if (isHost)
            const Padding(
              padding: EdgeInsets.only(right: 8),
              child: Text('👑', style: TextStyle(fontSize: 14)),
            ),
          Text(
            statusLabel,
            style: TextStyle(
              fontFamily: 'Inter',
              fontWeight: FontWeight.w800,
              fontSize: 12,
              color: statusColor,
            ),
          ),
        ],
      ),
    );
  }
}

/// 실시간 연결이 끊겼을 때 화면 위에 띄우는 얇은 안내 바.
/// 게임 화면은 소켓이 진실 출처라, 끊긴 걸 모르면 "아무 일도 안 일어나는" 것처럼 보인다.
class GameConnectionBanner extends StatelessWidget {
  const GameConnectionBanner({super.key, required this.connected});

  final bool connected;

  @override
  Widget build(BuildContext context) {
    return AnimatedSize(
      duration: const Duration(milliseconds: 200),
      child: connected
          ? const SizedBox(width: double.infinity, height: 0)
          : Container(
              width: double.infinity,
              margin: const EdgeInsets.fromLTRB(16, 0, 16, 6),
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                color: const Color(0xFFFFF6E5),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: const Color(0xFFF3D9A6)),
              ),
              child: const Row(
                children: [
                  SizedBox(
                    width: 13,
                    height: 13,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: Color(0xFFB88420),
                    ),
                  ),
                  SizedBox(width: 9),
                  Expanded(
                    child: Text(
                      '실시간 연결이 끊겼어요 — 다시 연결하는 중...',
                      style: TextStyle(
                        fontFamily: 'Inter',
                        fontWeight: FontWeight.w700,
                        fontSize: 12,
                        color: Color(0xFF8A6417),
                      ),
                    ),
                  ),
                ],
              ),
            ),
    );
  }
}
