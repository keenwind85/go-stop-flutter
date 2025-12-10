import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../config/constants.dart';
import '../../services/auth_service.dart';
import '../../services/coin_service.dart';
import '../../services/room_service.dart';
import '../../models/game_room.dart';
import '../../models/user_wallet.dart';
import '../game/game_screen_new.dart';
import '../widgets/screen_size_warning_overlay.dart';
import '../widgets/retro_background.dart';
import '../widgets/retro_button.dart';
import '../widgets/gwangkki_gauge.dart';

class LobbyScreen extends ConsumerStatefulWidget {
  const LobbyScreen({super.key});

  @override
  ConsumerState<LobbyScreen> createState() => _LobbyScreenState();
}

class _LobbyScreenState extends ConsumerState<LobbyScreen>
    with TickerProviderStateMixin {
  bool _isLoading = false;
  final _roomCodeController = TextEditingController();

  // 출석체크 애니메이션
  AnimationController? _attendanceAnimController;
  OverlayEntry? _attendanceOverlay;

  @override
  void initState() {
    super.initState();
    _cleanupStaleRooms();
    _attendanceAnimController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2000),
    );
  }

  @override
  void dispose() {
    _roomCodeController.dispose();
    _attendanceAnimController?.dispose();
    _attendanceOverlay?.remove();
    super.dispose();
  }

  /// 초기 로드 시 만료된 방 정리
  Future<void> _cleanupStaleRooms() async {
    final roomService = ref.read(roomServiceProvider);
    await roomService.cleanupAllStaleRooms();
  }

  Future<void> _createRoom() async {
    final authService = ref.read(authServiceProvider);
    final coinService = ref.read(coinServiceProvider);
    final user = authService.currentUser;
    if (user == null) return;

    // 코인 체크
    final canEnter = await coinService.canEnterGame(user.uid);
    if (!canEnter) {
      _showErrorSnackBar('코인이 부족합니다! (최소 ${CoinService.minEntryCoins} 코인 필요)');
      return;
    }

    setState(() => _isLoading = true);

    try {
      final roomService = ref.read(roomServiceProvider);
      final room = await roomService.createRoom(
        hostUid: user.uid,
        hostName: user.displayName ?? 'Player',
      );

      if (mounted) {
        Navigator.of(context).push(
          MaterialPageRoute(
            builder: (_) => GameScreenNew(roomId: room.roomId, isHost: true),
          ),
        );
      }
    } catch (e) {
      _showErrorSnackBar('방 생성 실패: $e');
    } finally {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _joinRoom(GameRoom room) async {
    final authService = ref.read(authServiceProvider);
    final coinService = ref.read(coinServiceProvider);
    final user = authService.currentUser;
    if (user == null) return;

    // 코인 체크
    final canEnter = await coinService.canEnterGame(user.uid);
    if (!canEnter) {
      _showErrorSnackBar('코인이 부족합니다! (최소 ${CoinService.minEntryCoins} 코인 필요)');
      return;
    }

    setState(() => _isLoading = true);

    try {
      final roomService = ref.read(roomServiceProvider);
      final joined = await roomService.joinRoom(
        roomId: room.roomId,
        guestUid: user.uid,
        guestName: user.displayName ?? 'Player',
      );

      if (joined != null && mounted) {
        Navigator.of(context).push(
          MaterialPageRoute(
            builder: (_) => GameScreenNew(roomId: room.roomId, isHost: false),
          ),
        );
      } else {
        _showErrorSnackBar('방에 입장할 수 없습니다');
      }
    } catch (e) {
      _showErrorSnackBar('입장 실패: $e');
    } finally {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _joinByCode() async {
    final code = _roomCodeController.text.trim().toUpperCase();
    if (code.length != 4) {
      _showErrorSnackBar('4자리 방 코드를 입력하세요');
      return;
    }

    final authService = ref.read(authServiceProvider);
    final coinService = ref.read(coinServiceProvider);
    final user = authService.currentUser;
    if (user == null) return;

    // 코인 체크
    final canEnter = await coinService.canEnterGame(user.uid);
    if (!canEnter) {
      _showErrorSnackBar('코인이 부족합니다! (최소 ${CoinService.minEntryCoins} 코인 필요)');
      return;
    }

    setState(() => _isLoading = true);

    try {
      final roomService = ref.read(roomServiceProvider);
      final joined = await roomService.joinRoom(
        roomId: code,
        guestUid: user.uid,
        guestName: user.displayName ?? 'Player',
      );

      if (joined != null && mounted) {
        Navigator.of(context).push(
          MaterialPageRoute(
            builder: (_) => GameScreenNew(roomId: code, isHost: false),
          ),
        );
      } else {
        _showErrorSnackBar('방을 찾을 수 없거나 입장할 수 없습니다');
      }
    } catch (e) {
      _showErrorSnackBar('입장 실패: $e');
    } finally {
      setState(() => _isLoading = false);
      _roomCodeController.clear();
    }
  }

  void _showErrorSnackBar(String message) {
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(message), backgroundColor: AppColors.error),
      );
    }
  }

  void _showSuccessSnackBar(String message) {
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(message), backgroundColor: Colors.green),
      );
    }
  }

  // ==================== 코인 기능 ====================

  Future<void> _checkAttendance() async {
    final authService = ref.read(authServiceProvider);
    final coinService = ref.read(coinServiceProvider);
    final user = authService.currentUser;
    if (user == null) return;

    final result = await coinService.checkAttendance(user.uid);
    if (result.success) {
      _showAttendanceAnimation(CoinService.attendanceReward);
    } else {
      _showErrorSnackBar(result.message);
    }
  }

  void _showAttendanceAnimation(int reward) {
    _attendanceOverlay?.remove();

    _attendanceOverlay = OverlayEntry(
      builder: (context) => _AttendanceAnimationOverlay(
        reward: reward,
        animationController: _attendanceAnimController!,
        onComplete: () {
          _attendanceOverlay?.remove();
          _attendanceOverlay = null;
        },
      ),
    );

    Overlay.of(context).insert(_attendanceOverlay!);
    _attendanceAnimController?.reset();
    _attendanceAnimController?.forward();
  }

  Future<void> _showRouletteDialog() async {
    final authService = ref.read(authServiceProvider);
    final coinService = ref.read(coinServiceProvider);
    final user = authService.currentUser;
    if (user == null) return;

    // 룰렛 가능 여부 확인
    final status = await coinService.canSpinRoulette(user.uid);

    if (!mounted) return;

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => _RouletteWheelDialog(
        initialRemainingSpins: status.remainingSpins,
        canSpin: status.canSpin,
        onSpin: () async {
          final result = await coinService.spinRoulette(user.uid);
          return result;
        },
      ),
    );
  }

  Future<void> _showDonationDialog() async {
    final authService = ref.read(authServiceProvider);
    final coinService = ref.read(coinServiceProvider);
    final user = authService.currentUser;
    if (user == null) return;

    // 현재 보유 코인 확인
    final wallet = await coinService.getUserWallet(user.uid);
    final currentCoins = wallet?.coin ?? 0;

    if (currentCoins <= 0) {
      _showErrorSnackBar('기부할 코인이 없습니다.');
      return;
    }

    // 랭킹에서 기부할 대상 선택
    final leaderboard = await coinService.getLeaderboard(limit: 50);
    final otherUsers = leaderboard.where((u) => u.uid != user.uid).toList();

    if (otherUsers.isEmpty) {
      _showErrorSnackBar('기부할 수 있는 사용자가 없습니다.');
      return;
    }

    if (!mounted) return;

    showDialog(
      context: context,
      builder: (context) => _DonationDialog(
        currentCoins: currentCoins,
        otherUsers: otherUsers,
        onDonate: (targetUid, targetName, amount) async {
          final result = await coinService.donateCoinsWithAmount(
            user.uid,
            targetUid,
            amount,
          );
          if (result.success) {
            _showSuccessSnackBar('$targetName님에게 $amount 코인을 기부했습니다!');
          } else {
            _showErrorSnackBar(result.message);
          }
          return result.success;
        },
      ),
    );
  }

  Future<void> _showLeaderboard() async {
    final coinService = ref.read(coinServiceProvider);
    final leaderboard = await coinService.getLeaderboard();

    if (!mounted) return;

    showModalBottomSheet(
      context: context,
      backgroundColor: AppColors.background,
      isScrollControlled: true,
      builder: (context) => DraggableScrollableSheet(
        initialChildSize: 0.7,
        maxChildSize: 0.9,
        minChildSize: 0.5,
        expand: false,
        builder: (context, scrollController) => Column(
          children: [
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: AppColors.primary,
                borderRadius: const BorderRadius.vertical(
                  top: Radius.circular(20),
                ),
              ),
              child: Row(
                children: [
                  const Icon(Icons.leaderboard, color: AppColors.accent),
                  const SizedBox(width: 8),
                  const Text(
                    '코인 랭킹 TOP 100',
                    style: TextStyle(
                      color: AppColors.text,
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const Spacer(),
                  IconButton(
                    onPressed: () => Navigator.pop(context),
                    icon: const Icon(Icons.close, color: AppColors.text),
                  ),
                ],
              ),
            ),
            Expanded(
              child: ListView.builder(
                controller: scrollController,
                itemCount: leaderboard.length,
                itemBuilder: (context, index) {
                  final entry = leaderboard[index];
                  final isTop3 = entry.rank <= 3;
                  final medalColor = entry.rank == 1
                      ? Colors.amber
                      : (entry.rank == 2
                            ? Colors.grey[300]
                            : Colors.brown[400]);

                  return Container(
                    margin: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: isTop3
                          ? medalColor?.withValues(alpha: 0.2)
                          : AppColors.primary.withValues(alpha: 0.3),
                      borderRadius: BorderRadius.circular(12),
                      border: isTop3
                          ? Border.all(
                              color: medalColor ?? Colors.transparent,
                              width: 2,
                            )
                          : null,
                    ),
                    child: ListTile(
                      leading: Container(
                        width: 40,
                        height: 40,
                        decoration: BoxDecoration(
                          color: isTop3 ? medalColor : AppColors.primary,
                          shape: BoxShape.circle,
                        ),
                        child: Center(
                          child: isTop3
                              ? Icon(
                                  Icons.emoji_events,
                                  color: entry.rank == 1
                                      ? Colors.black
                                      : Colors.white,
                                  size: 20,
                                )
                              : Text(
                                  '${entry.rank}',
                                  style: const TextStyle(
                                    color: AppColors.text,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                        ),
                      ),
                      title: Text(
                        entry.displayName,
                        style: TextStyle(
                          color: isTop3 ? medalColor : AppColors.text,
                          fontWeight: isTop3
                              ? FontWeight.bold
                              : FontWeight.normal,
                        ),
                      ),
                      trailing: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(
                            Icons.monetization_on,
                            color: AppColors.accent,
                            size: 20,
                          ),
                          const SizedBox(width: 4),
                          Text(
                            '${entry.coin}',
                            style: TextStyle(
                              color: isTop3 ? medalColor : AppColors.accent,
                              fontWeight: FontWeight.bold,
                              fontSize: 16,
                            ),
                          ),
                        ],
                      ),
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final authService = ref.read(authServiceProvider);
    final user = authService.currentUser;

    return ScreenSizeWarningOverlay(
      child: Scaffold(
        backgroundColor: AppColors.background,
        appBar: AppBar(
          backgroundColor: Colors.transparent,
          title: Text(
            '안녕하세요, ${user?.displayName ?? "Player"}님',
            style: const TextStyle(
              color: AppColors.text,
              shadows: [
                Shadow(
                  color: Colors.black,
                  offset: Offset(2, 2),
                  blurRadius: 0,
                ),
              ],
            ),
          ),
          actions: [
            IconButton(
              icon: const Icon(Icons.logout, color: AppColors.text),
              onPressed: () => authService.signOut(),
            ),
          ],
        ),
        body: RetroBackground(
          child: SafeArea(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // 코인 정보 카드
                  _buildCoinCard(),

                  const SizedBox(height: 16),

                  // 일일 활동 버튼들
                  _buildDailyActionsRow(),

                  const SizedBox(height: 24),

                  // 방 만들기 버튼
                  // 방 만들기 버튼
                  RetroButton(
                    onPressed: _isLoading ? null : _createRoom,
                    color: AppColors.primary,
                    width: double.infinity,
                    height: 60,
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: const [
                        Icon(Icons.add, color: AppColors.text),
                        SizedBox(width: 8),
                        Text(
                          '새 게임 만들기',
                          style: TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                            color: AppColors.text,
                          ),
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 16),

                  // 방 코드로 입장
                  Row(
                    children: [
                      Expanded(
                        child: TextField(
                          controller: _roomCodeController,
                          decoration: InputDecoration(
                            hintText: '방 코드 입력 (4자리)',
                            hintStyle: TextStyle(
                              color: AppColors.textSecondary.withValues(
                                alpha: 0.5,
                              ),
                            ),
                            filled: true,
                            fillColor: Colors.black.withValues(alpha: 0.5),
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                              borderSide: const BorderSide(
                                color: AppColors.woodLight,
                                width: 2,
                              ),
                            ),
                            enabledBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                              borderSide: const BorderSide(
                                color: AppColors.woodLight,
                                width: 2,
                              ),
                            ),
                            focusedBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                              borderSide: const BorderSide(
                                color: AppColors.accent,
                                width: 2,
                              ),
                            ),
                          ),
                          style: const TextStyle(
                            color: AppColors.text,
                            fontSize: 18,
                            letterSpacing: 4,
                            fontWeight: FontWeight.bold,
                          ),
                          textAlign: TextAlign.center,
                          textCapitalization: TextCapitalization.characters,
                          maxLength: 4,
                        ),
                      ),
                      const SizedBox(width: 8),
                      RetroButton(
                        onPressed: _isLoading ? null : _joinByCode,
                        text: '입장',
                        color: AppColors.accent,
                        textColor: Colors.black,
                        width: 80,
                        height: 60,
                        fontSize: 18,
                      ),
                    ],
                  ),

                  const SizedBox(height: 24),

                  // 대기 중인 방 목록
                  const Text(
                    '대기 중인 방',
                    style: TextStyle(
                      color: AppColors.text,
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 8),

                  // 방 목록 (실시간 동기화)
                  SizedBox(
                    height: 400,
                    child: StreamBuilder<List<GameRoom>>(
                      stream: ref.read(roomServiceProvider).watchWaitingRooms(),
                      builder: (context, snapshot) {
                        if (snapshot.connectionState ==
                                ConnectionState.waiting &&
                            !snapshot.hasData) {
                          return const Center(
                            child: CircularProgressIndicator(
                              color: AppColors.accent,
                            ),
                          );
                        }

                        final waitingRooms = snapshot.data ?? [];

                        if (waitingRooms.isEmpty) {
                          return Center(
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Opacity(
                                  opacity: 0.9,
                                  child: Image.asset(
                                    'assets/etc/login_img.png',
                                    height: 160,
                                    fit: BoxFit.contain,
                                  ),
                                ),
                                const SizedBox(height: 16),
                                const Text(
                                  '대기 중인 방이 없습니다',
                                  style: TextStyle(
                                    color: AppColors.textSecondary,
                                  ),
                                ),
                              ],
                            ),
                          );
                        }

                        return ListView.builder(
                          itemCount: waitingRooms.length,
                          itemBuilder: (context, index) {
                            final room = waitingRooms[index];
                            return Container(
                              margin: const EdgeInsets.only(bottom: 8),
                              decoration: BoxDecoration(
                                color: AppColors.woodLight.withValues(
                                  alpha: 0.9,
                                ),
                                borderRadius: BorderRadius.circular(8),
                                border: Border.all(
                                  color: AppColors.woodDark,
                                  width: 2,
                                ),
                                boxShadow: [
                                  BoxShadow(
                                    color: Colors.black.withValues(alpha: 0.3),
                                    blurRadius: 0,
                                    offset: const Offset(2, 2),
                                  ),
                                ],
                              ),
                              child: ListTile(
                                leading: const Icon(
                                  Icons.videogame_asset,
                                  color: AppColors.woodDark,
                                  size: 32,
                                ),
                                title: Text(
                                  '방 코드: ${room.roomId}',
                                  style: const TextStyle(
                                    color: AppColors.woodDark,
                                    fontWeight: FontWeight.bold,
                                    fontSize: 16,
                                  ),
                                ),
                                subtitle: Text(
                                  '호스트: ${room.host.displayName}',
                                  style: TextStyle(
                                    color: AppColors.woodDark.withValues(
                                      alpha: 0.7,
                                    ),
                                    fontSize: 14,
                                  ),
                                ),
                                trailing: RetroButton(
                                  onPressed: () => _joinRoom(room),
                                  text: '입장',
                                  color: AppColors.accent,
                                  textColor: Colors.black,
                                  width: 60,
                                  height: 40,
                                  fontSize: 14,
                                ),
                              ),
                            );
                          },
                        );
                      },
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildCoinCard() {
    final authService = ref.read(authServiceProvider);
    final coinService = ref.read(coinServiceProvider);
    final user = authService.currentUser;

    if (user == null) {
      return const SizedBox.shrink();
    }

    return StreamBuilder<UserWallet?>(
      stream: coinService.getUserWalletStream(user.uid),
      builder: (context, snapshot) {
        final wallet = snapshot.data;
        final coin = wallet?.coin ?? 0;
        final totalEarned = wallet?.totalEarned ?? 0;
        final gwangkkiScore = wallet?.gwangkkiScore ?? 0;

        return Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: AppColors.woodDark,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: AppColors.woodLight, width: 3),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.5),
                blurRadius: 0,
                offset: const Offset(4, 4),
              ),
            ],
          ),
          child: Row(
            children: [
              // 좌측: 코인 정보
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(
                          Icons.monetization_on,
                          color: AppColors.accent,
                          size: 28,
                        ),
                        const SizedBox(width: 6),
                        Text(
                          '$coin',
                          style: const TextStyle(
                            color: AppColors.accent,
                            fontSize: 28,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(width: 4),
                        const Text(
                          '코인',
                          style: TextStyle(color: AppColors.text, fontSize: 14),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '총 획득: $totalEarned',
                      style: TextStyle(color: AppColors.textSecondary, fontSize: 11),
                    ),
                  ],
                ),
              ),
              // 구분선
              Container(
                width: 1,
                height: 50,
                color: AppColors.woodLight.withValues(alpha: 0.5),
                margin: const EdgeInsets.symmetric(horizontal: 12),
              ),
              // 우측: 光끼 점수
              GwangkkiGauge(
                score: gwangkkiScore,
                showWarning: gwangkkiScore >= 100,
                showLabel: true,
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildDailyActionsRow() {
    return Row(
      children: [
        // 출석 체크
        Expanded(
          child: _buildActionButton(
            icon: Icons.calendar_today,
            label: '출석체크',
            color: Colors.green,
            onTap: _checkAttendance,
          ),
        ),
        const SizedBox(width: 8),
        // 룰렛
        Expanded(
          child: _buildActionButton(
            icon: Icons.casino,
            label: '룰렛',
            color: Colors.purple,
            onTap: _showRouletteDialog,
          ),
        ),
        const SizedBox(width: 8),
        // 기부
        Expanded(
          child: _buildActionButton(
            icon: Icons.volunteer_activism,
            label: '기부',
            color: Colors.pink,
            onTap: _showDonationDialog,
          ),
        ),
        const SizedBox(width: 8),
        // 랭킹
        Expanded(
          child: _buildActionButton(
            icon: Icons.leaderboard,
            label: '랭킹',
            color: Colors.orange,
            onTap: _showLeaderboard,
          ),
        ),
      ],
    );
  }

  Widget _buildActionButton({
    required IconData icon,
    required String label,
    required Color color,
    required VoidCallback onTap,
  }) {
    return RetroButton(
      onPressed: onTap,
      color: AppColors.woodLight,
      width: null,
      height: 80,
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(icon, color: color, size: 28),
          const SizedBox(height: 4),
          Text(
            label,
            style: TextStyle(
              color: AppColors.text,
              fontSize: 12,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }
}

// ==================== 출석체크 애니메이션 오버레이 ====================

class _AttendanceAnimationOverlay extends StatefulWidget {
  final int reward;
  final AnimationController animationController;
  final VoidCallback onComplete;

  const _AttendanceAnimationOverlay({
    required this.reward,
    required this.animationController,
    required this.onComplete,
  });

  @override
  State<_AttendanceAnimationOverlay> createState() =>
      _AttendanceAnimationOverlayState();
}

class _AttendanceAnimationOverlayState
    extends State<_AttendanceAnimationOverlay> {
  @override
  void initState() {
    super.initState();
    widget.animationController.addStatusListener(_onAnimationStatus);
  }

  void _onAnimationStatus(AnimationStatus status) {
    if (status == AnimationStatus.completed) {
      widget.onComplete();
    }
  }

  @override
  void dispose() {
    widget.animationController.removeStatusListener(_onAnimationStatus);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: widget.animationController,
      builder: (context, child) {
        final progress = widget.animationController.value;
        final opacity = progress < 0.8 ? 1.0 : (1.0 - (progress - 0.8) / 0.2);
        final scale = 0.5 + progress * 0.5;
        final yOffset = 100 * (1 - progress);

        return Positioned.fill(
          child: IgnorePointer(
            child: Center(
              child: Transform.translate(
                offset: Offset(0, yOffset),
                child: Transform.scale(
                  scale: scale,
                  child: Opacity(
                    opacity: opacity.clamp(0.0, 1.0),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        // 체크 아이콘
                        Container(
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            color: Colors.green.withValues(alpha: 0.9),
                            shape: BoxShape.circle,
                            boxShadow: [
                              BoxShadow(
                                color: Colors.green.withValues(alpha: 0.5),
                                blurRadius: 20,
                                spreadRadius: 5,
                              ),
                            ],
                          ),
                          child: const Icon(
                            Icons.check,
                            color: Colors.white,
                            size: 48,
                          ),
                        ),
                        const SizedBox(height: 16),
                        // 텍스트
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 24,
                            vertical: 12,
                          ),
                          decoration: BoxDecoration(
                            color: Colors.black.withValues(alpha: 0.8),
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: Column(
                            children: [
                              const Text(
                                '출석체크 완료!',
                                style: TextStyle(
                                  color: Colors.white,
                                  fontSize: 24,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                '+${widget.reward} 코인 획득!',
                                style: const TextStyle(
                                  color: AppColors.accent,
                                  fontSize: 20,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}

// ==================== 룰렛 휠 다이얼로그 ====================

class _RouletteWheelDialog extends StatefulWidget {
  final int initialRemainingSpins;
  final bool canSpin;
  final Future<
    ({
      bool success,
      int reward,
      int newBalance,
      int remainingSpins,
      String message,
    })
  >
  Function()
  onSpin;

  const _RouletteWheelDialog({
    required this.initialRemainingSpins,
    required this.canSpin,
    required this.onSpin,
  });

  @override
  State<_RouletteWheelDialog> createState() => _RouletteWheelDialogState();
}

class _RouletteWheelDialogState extends State<_RouletteWheelDialog>
    with SingleTickerProviderStateMixin {
  late AnimationController _spinController;
  late Animation<double> _spinAnimation;
  bool _isSpinning = false;
  int? _result;
  int _remainingSpins = 0;
  bool _canSpin = true;

  // 룰렛 섹션 정의
  static const List<({int value, Color color, String label})> _sections = [
    (value: 100, color: Colors.amber, label: '+100'),
    (value: -10, color: Colors.red, label: '-10'),
    (value: 10, color: Colors.green, label: '+10'),
    (value: 0, color: Colors.grey, label: '0'),
    (value: 50, color: Colors.blue, label: '+50'),
    (value: 0, color: Colors.grey, label: '0'),
    (value: 10, color: Colors.green, label: '+10'),
    (value: 0, color: Colors.grey, label: '0'),
  ];

  @override
  void initState() {
    super.initState();
    _remainingSpins = widget.initialRemainingSpins;
    _canSpin = widget.canSpin;
    _spinController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 4),
    );
    // 초기 애니메이션 값 설정
    _spinAnimation = Tween<double>(begin: 0, end: 0).animate(_spinController);
  }

  @override
  void dispose() {
    _spinController.dispose();
    super.dispose();
  }

  Future<void> _spin() async {
    if (_isSpinning || !_canSpin || _remainingSpins <= 0) return;

    setState(() {
      _isSpinning = true;
      _result = null;
    });

    // 결과 먼저 가져오기
    final result = await widget.onSpin();

    // 결과에 따른 각도 계산
    // 화살표는 위쪽(12시)에 고정, 휠이 시계방향으로 회전
    // 섹션 0은 12시 방향에서 시작, 시계방향으로 배치됨
    // 휠이 회전하면 화살표가 가리키는 섹션이 바뀜
    // targetSection을 화살표가 가리키게 하려면, 해당 섹션이 12시 위치로 오도록 회전해야 함
    final targetSection = _getSectionForReward(result.reward);
    final baseSpins = 5; // 기본 회전 수
    final sectionAngle = (2 * pi) / _sections.length;

    // 섹션의 중앙이 12시 위치(화살표)에 오도록 각도 계산
    // 섹션 인덱스가 증가하면 시계방향으로 위치
    // 휠을 시계방향으로 회전시키면, 섹션은 반시계방향으로 이동하는 것처럼 보임
    // 따라서 targetSection을 화살표로 가져오려면:
    // 전체 회전 - (targetSection * sectionAngle + sectionAngle/2)
    final targetAngle =
        baseSpins * 2 * pi - (targetSection * sectionAngle + sectionAngle / 2);

    _spinAnimation = Tween<double>(begin: 0, end: targetAngle).animate(
      CurvedAnimation(parent: _spinController, curve: Curves.easeOutCubic),
    );

    _spinController.reset();
    await _spinController.forward();

    setState(() {
      _isSpinning = false;
      _result = result.reward;
      _remainingSpins = result.remainingSpins;
      _canSpin = result.remainingSpins > 0;
    });
  }

  int _getSectionForReward(int reward) {
    // 결과값에 맞는 섹션 찾기
    // 같은 값이 여러 개 있으면 랜덤하게 선택
    final matchingSections = <int>[];
    for (int i = 0; i < _sections.length; i++) {
      if (_sections[i].value == reward) {
        matchingSections.add(i);
      }
    }
    if (matchingSections.isNotEmpty) {
      return matchingSections[DateTime.now().millisecond %
          matchingSections.length];
    }
    return 0;
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: Colors.transparent,
      child: Container(
        width: 340,
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: AppColors.primary,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: AppColors.accent.withValues(alpha: 0.5),
            width: 2,
          ),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // 헤더
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  '코인 룰렛',
                  style: TextStyle(
                    color: AppColors.text,
                    fontSize: 22,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                IconButton(
                  onPressed: _isSpinning ? null : () => Navigator.pop(context),
                  icon: const Icon(Icons.close, color: AppColors.text),
                ),
              ],
            ),
            const SizedBox(height: 8),
            // 남은 횟수
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              decoration: BoxDecoration(
                color: Colors.purple.withValues(alpha: 0.3),
                borderRadius: BorderRadius.circular(20),
              ),
              child: Text(
                '오늘 남은 횟수: $_remainingSpins회',
                style: const TextStyle(
                  color: Colors.purple,
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
            const SizedBox(height: 20),
            // 룰렛 휠
            SizedBox(
              width: 260,
              height: 260,
              child: Stack(
                alignment: Alignment.center,
                children: [
                  // 룰렛 휠
                  AnimatedBuilder(
                    animation: _spinController,
                    builder: (context, child) {
                      final rotation = _spinAnimation.value;
                      return Transform.rotate(
                        angle: rotation,
                        child: CustomPaint(
                          size: const Size(240, 240),
                          painter: _RouletteWheelPainter(sections: _sections),
                        ),
                      );
                    },
                  ),
                  // 중앙 버튼
                  GestureDetector(
                    onTap: _isSpinning || _remainingSpins <= 0 ? null : _spin,
                    child: Container(
                      width: 70,
                      height: 70,
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: _remainingSpins > 0
                              ? [Colors.purple, Colors.deepPurple]
                              : [Colors.grey, Colors.grey.shade700],
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        ),
                        shape: BoxShape.circle,
                        boxShadow: [
                          BoxShadow(
                            color: Colors.purple.withValues(alpha: 0.5),
                            blurRadius: 10,
                            spreadRadius: 2,
                          ),
                        ],
                      ),
                      child: Center(
                        child: Text(
                          _isSpinning ? '...' : 'SPIN',
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ),
                  ),
                  // 화살표 포인터
                  Positioned(
                    top: 0,
                    child: Container(
                      width: 0,
                      height: 0,
                      decoration: const BoxDecoration(),
                      child: CustomPaint(painter: _ArrowPainter()),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),
            // 결과 표시
            if (_result != null)
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 24,
                  vertical: 12,
                ),
                decoration: BoxDecoration(
                  color: _result! > 0
                      ? Colors.green.withValues(alpha: 0.3)
                      : (_result! < 0
                            ? Colors.red.withValues(alpha: 0.3)
                            : Colors.grey.withValues(alpha: 0.3)),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Column(
                  children: [
                    Text(
                      _result! > 0
                          ? '축하합니다!'
                          : (_result! < 0 ? '아쉽네요...' : '꽝!'),
                      style: TextStyle(
                        color: _result! > 0
                            ? Colors.greenAccent
                            : (_result! < 0 ? Colors.redAccent : Colors.grey),
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    Text(
                      _result! > 0 ? '+$_result 코인' : '$_result 코인',
                      style: TextStyle(
                        color: _result! > 0
                            ? Colors.greenAccent
                            : (_result! < 0 ? Colors.redAccent : Colors.grey),
                        fontSize: 28,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _RouletteWheelPainter extends CustomPainter {
  final List<({int value, Color color, String label})> sections;

  _RouletteWheelPainter({required this.sections});

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = size.width / 2;
    final sectionAngle = (2 * pi) / sections.length;

    for (int i = 0; i < sections.length; i++) {
      final startAngle = i * sectionAngle - pi / 2;
      final section = sections[i];

      // 섹션 그리기
      final paint = Paint()
        ..color = section.color
        ..style = PaintingStyle.fill;

      canvas.drawArc(
        Rect.fromCircle(center: center, radius: radius),
        startAngle,
        sectionAngle,
        true,
        paint,
      );

      // 테두리
      final borderPaint = Paint()
        ..color = Colors.white.withValues(alpha: 0.5)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2;

      canvas.drawArc(
        Rect.fromCircle(center: center, radius: radius),
        startAngle,
        sectionAngle,
        true,
        borderPaint,
      );

      // 텍스트
      final textAngle = startAngle + sectionAngle / 2;
      final textRadius = radius * 0.7;
      final textX = center.dx + textRadius * cos(textAngle);
      final textY = center.dy + textRadius * sin(textAngle);

      final textPainter = TextPainter(
        text: TextSpan(
          text: section.label,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 14,
            fontWeight: FontWeight.bold,
            shadows: [Shadow(color: Colors.black, blurRadius: 2)],
          ),
        ),
        textDirection: TextDirection.ltr,
      );
      textPainter.layout();

      canvas.save();
      canvas.translate(textX, textY);
      canvas.rotate(textAngle + pi / 2);
      textPainter.paint(
        canvas,
        Offset(-textPainter.width / 2, -textPainter.height / 2),
      );
      canvas.restore();
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

class _ArrowPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = Colors.white
      ..style = PaintingStyle.fill;

    final path = Path()
      ..moveTo(0, 0)
      ..lineTo(-12, -24)
      ..lineTo(12, -24)
      ..close();

    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

// ==================== 기부 다이얼로그 ====================

class _DonationDialog extends StatefulWidget {
  final int currentCoins;
  final List<
    ({String uid, String displayName, String? avatar, int coin, int rank})
  >
  otherUsers;
  final Future<bool> Function(String targetUid, String targetName, int amount)
  onDonate;

  const _DonationDialog({
    required this.currentCoins,
    required this.otherUsers,
    required this.onDonate,
  });

  @override
  State<_DonationDialog> createState() => _DonationDialogState();
}

class _DonationDialogState extends State<_DonationDialog> {
  String? _selectedUid;
  String? _selectedName;
  final _amountController = TextEditingController();
  bool _isProcessing = false;

  @override
  void dispose() {
    _amountController.dispose();
    super.dispose();
  }

  Future<void> _executeDonation() async {
    if (_selectedUid == null || _amountController.text.isEmpty) return;

    final amount = int.tryParse(_amountController.text) ?? 0;
    if (amount <= 0) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('1 이상의 코인을 입력해주세요')));
      return;
    }
    if (amount > widget.currentCoins) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('보유 코인보다 많이 기부할 수 없습니다')));
      return;
    }

    setState(() => _isProcessing = true);

    final success = await widget.onDonate(
      _selectedUid!,
      _selectedName!,
      amount,
    );

    if (mounted) {
      setState(() => _isProcessing = false);
      if (success) {
        Navigator.pop(context);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      backgroundColor: AppColors.primary,
      title: Row(
        children: [
          const Icon(Icons.volunteer_activism, color: Colors.pink),
          const SizedBox(width: 8),
          const Text(
            '코인 기부',
            style: TextStyle(
              color: AppColors.text,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
      content: SizedBox(
        width: double.maxFinite,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // 보유 코인 표시
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: AppColors.accent.withValues(alpha: 0.2),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                children: [
                  const Icon(Icons.monetization_on, color: AppColors.accent),
                  const SizedBox(width: 8),
                  Text(
                    '보유 코인: ${widget.currentCoins}',
                    style: const TextStyle(
                      color: AppColors.accent,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),

            // 기부 대상 선택
            const Text(
              '기부할 대상 선택:',
              style: TextStyle(color: AppColors.textSecondary),
            ),
            const SizedBox(height: 8),
            SizedBox(
              height: 150,
              child: ListView.builder(
                shrinkWrap: true,
                itemCount: widget.otherUsers.length,
                itemBuilder: (context, index) {
                  final target = widget.otherUsers[index];
                  final isSelected = _selectedUid == target.uid;
                  return ListTile(
                    selected: isSelected,
                    selectedTileColor: Colors.pink.withValues(alpha: 0.2),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                    leading: CircleAvatar(
                      backgroundColor: isSelected
                          ? Colors.pink
                          : AppColors.accent,
                      child: Text(
                        '${target.rank}',
                        style: TextStyle(
                          color: isSelected ? Colors.white : Colors.black,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                    title: Text(
                      target.displayName,
                      style: TextStyle(
                        color: isSelected ? Colors.pink : AppColors.text,
                        fontWeight: isSelected
                            ? FontWeight.bold
                            : FontWeight.normal,
                      ),
                    ),
                    subtitle: Text(
                      '${target.coin} 코인',
                      style: const TextStyle(color: AppColors.textSecondary),
                    ),
                    trailing: isSelected
                        ? const Icon(Icons.check_circle, color: Colors.pink)
                        : null,
                    onTap: () {
                      setState(() {
                        _selectedUid = target.uid;
                        _selectedName = target.displayName;
                      });
                    },
                  );
                },
              ),
            ),
            const SizedBox(height: 16),

            // 기부 금액 입력
            if (_selectedUid != null) ...[
              Text(
                '${_selectedName}님에게 기부할 코인:',
                style: const TextStyle(color: AppColors.textSecondary),
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _amountController,
                      keyboardType: TextInputType.number,
                      style: const TextStyle(color: AppColors.text),
                      decoration: InputDecoration(
                        hintText: '코인 수량',
                        hintStyle: const TextStyle(
                          color: AppColors.textSecondary,
                        ),
                        filled: true,
                        fillColor: AppColors.background,
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(8),
                          borderSide: BorderSide.none,
                        ),
                        prefixIcon: const Icon(
                          Icons.monetization_on,
                          color: AppColors.accent,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  // 빠른 선택 버튼
                  _QuickAmountButton(
                    label: '10',
                    onTap: () => _amountController.text = '10',
                  ),
                  const SizedBox(width: 4),
                  _QuickAmountButton(
                    label: '50',
                    onTap: () => _amountController.text = '50',
                  ),
                  const SizedBox(width: 4),
                  _QuickAmountButton(
                    label: 'MAX',
                    onTap: () =>
                        _amountController.text = '${widget.currentCoins}',
                  ),
                ],
              ),
            ],
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: _isProcessing ? null : () => Navigator.pop(context),
          child: const Text(
            '취소',
            style: TextStyle(color: AppColors.textSecondary),
          ),
        ),
        ElevatedButton(
          onPressed: _isProcessing || _selectedUid == null
              ? null
              : _executeDonation,
          style: ElevatedButton.styleFrom(backgroundColor: Colors.pink),
          child: _isProcessing
              ? const SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: Colors.white,
                  ),
                )
              : const Text('기부하기'),
        ),
      ],
    );
  }
}

class _QuickAmountButton extends StatelessWidget {
  final String label;
  final VoidCallback onTap;

  const _QuickAmountButton({required this.label, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        decoration: BoxDecoration(
          color: Colors.pink.withValues(alpha: 0.3),
          borderRadius: BorderRadius.circular(4),
        ),
        child: Text(
          label,
          style: const TextStyle(
            color: Colors.pink,
            fontSize: 12,
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
    );
  }
}
