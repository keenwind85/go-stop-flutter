import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:slot_machine_roller/slot_machine_roller.dart';
import '../../config/constants.dart';
import '../../models/slot_result.dart';
import '../../services/slot_machine_service.dart';
import '../../services/sound_service.dart';

/// 화투 슬롯머신 다이얼로그
class SlotMachineDialog extends ConsumerStatefulWidget {
  final String uid;
  final int initialCoin;
  final VoidCallback? onCoinChanged;

  const SlotMachineDialog({
    super.key,
    required this.uid,
    required this.initialCoin,
    this.onCoinChanged,
  });

  @override
  ConsumerState<SlotMachineDialog> createState() => _SlotMachineDialogState();
}

class _SlotMachineDialogState extends ConsumerState<SlotMachineDialog>
    with TickerProviderStateMixin {
  late final SlotMachineService _slotService;
  late final SoundService _soundService;

  // 상태 변수
  int _currentCoin = 0;
  int _betAmount = 5;
  int _remainingBase = 10;   // 기본 횟수 (매일 10회)
  int _remainingBonus = 0;   // 보너스 횟수 (게임 완료로 획득)
  bool _isSpinning = false;
  SlotResult? _lastResult;

  // 릴 타겟 인덱스 (null = 회전 중, 값 = 정지 위치)
  List<int?> _targetIndices = [null, null, null];

  // 결과 표시용
  bool _showResult = false;
  String _resultMessage = '';

  // 애니메이션 컨트롤러
  late AnimationController _resultAnimController;
  late Animation<double> _resultScaleAnim;

  @override
  void initState() {
    super.initState();
    _currentCoin = widget.initialCoin;
    _slotService = ref.read(slotMachineServiceProvider);
    _soundService = ref.read(soundServiceProvider);

    _resultAnimController = AnimationController(
      duration: const Duration(milliseconds: 500),
      vsync: this,
    );
    _resultScaleAnim = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _resultAnimController, curve: Curves.elasticOut),
    );

    _loadStats();
  }

  @override
  void dispose() {
    _resultAnimController.dispose();
    super.dispose();
  }

  /// 총 남은 횟수
  int get _totalRemaining => _remainingBase + _remainingBonus;

  /// 통계 로드
  Future<void> _loadStats() async {
    final stats = await _slotService.getTodayStats(widget.uid);
    if (mounted) {
      setState(() {
        _remainingBase = stats.baseRemaining;
        _remainingBonus = stats.bonusRemaining;
      });
    }
  }

  /// 스핀 실행
  Future<void> _spin() async {
    if (_isSpinning) return;
    if (_currentCoin < _betAmount) {
      _showErrorSnackbar('코인이 부족합니다!');
      return;
    }
    if (_totalRemaining <= 0) {
      _showErrorSnackbar('오늘의 기회를 모두 사용하셨습니다!');
      return;
    }

    setState(() {
      _isSpinning = true;
      _showResult = false;
      _targetIndices = [null, null, null]; // 회전 시작
    });

    // 스핀 사운드
    _soundService.playClick();

    // 서버에서 결과 계산
    final spinResult = await _slotService.spin(widget.uid, _betAmount);

    if (!spinResult.success || spinResult.result == null) {
      setState(() => _isSpinning = false);
      _showErrorSnackbar(spinResult.message);
      return;
    }

    final result = spinResult.result!;
    _lastResult = result;

    // 릴 순차 정지 애니메이션 (각 500ms 간격)
    for (int i = 0; i < 3; i++) {
      await Future.delayed(const Duration(milliseconds: 600));
      if (!mounted) return;

      // 릴 정지 사운드
      _soundService.playCardPlace();

      setState(() {
        // 월은 1-12, 인덱스는 0-11
        _targetIndices[i] = result.reels[i] - 1;
      });
    }

    // 모든 릴 정지 후 결과 표시
    await Future.delayed(const Duration(milliseconds: 300));
    if (!mounted) return;

    setState(() {
      _isSpinning = false;
      _showResult = true;
      _resultMessage = result.resultMessage;
      _currentCoin = spinResult.newBalance;
      _remainingBase = spinResult.remainingBase;
      _remainingBonus = spinResult.remainingBonus;
    });

    // 결과에 따른 사운드
    if (result.isJackpot) {
      _soundService.playWinner();
    } else if (result.isWin) {
      _soundService.playGo();
    } else {
      _soundService.playTakMiss();
    }

    // 결과 애니메이션
    _resultAnimController.forward(from: 0);

    // 코인 변경 콜백
    widget.onCoinChanged?.call();
  }

  void _showErrorSnackbar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.red.shade700,
        duration: const Duration(seconds: 2),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    final dialogWidth = screenWidth > 400 ? 340.0 : screenWidth * 0.9;

    return Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
      child: Container(
        width: dialogWidth,
        constraints: const BoxConstraints(maxHeight: 580),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              AppColors.woodDark,
              AppColors.woodDark.withValues(alpha: 0.95),
            ],
          ),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: AppColors.accent, width: 2),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.5),
              blurRadius: 20,
              offset: const Offset(0, 10),
            ),
          ],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            _buildHeader(),
            Flexible(
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    _buildCoinDisplay(),
                    const SizedBox(height: 8),
                    _buildSlotMachine(),
                    const SizedBox(height: 4),
                    _buildResultDisplay(),
                    const SizedBox(height: 4),
                    _buildBetSelector(),
                    const SizedBox(height: 10),
                    _buildSpinButton(),
                    const SizedBox(height: 6),
                    _buildPayoutInfo(),
                    const SizedBox(height: 8),
                    _buildUsageInfo(),
                    const SizedBox(height: 12),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// 헤더
  Widget _buildHeader() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: AppColors.accent.withValues(alpha: 0.2),
        borderRadius: const BorderRadius.vertical(top: Radius.circular(18)),
      ),
      child: Row(
        children: [
          const Text(
            '🎰',
            style: TextStyle(fontSize: 24),
          ),
          const SizedBox(width: 8),
          const Expanded(
            child: Text(
              '화투 슬롯머신',
              style: TextStyle(
                color: AppColors.text,
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              color: Colors.amber.withValues(alpha: 0.3),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  '$_remainingBase',
                  style: const TextStyle(
                    color: Colors.amber,
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                if (_remainingBonus > 0) ...[
                  Text(
                    '+$_remainingBonus',
                    style: const TextStyle(
                      color: Colors.greenAccent,
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
                const Text(
                  '회',
                  style: TextStyle(
                    color: Colors.amber,
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          GestureDetector(
            onTap: () => Navigator.of(context).pop(),
            child: Container(
              padding: const EdgeInsets.all(4),
              decoration: BoxDecoration(
                color: Colors.red.withValues(alpha: 0.3),
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Icon(
                Icons.close,
                color: Colors.white70,
                size: 20,
              ),
            ),
          ),
        ],
      ),
    );
  }

  /// 코인 표시
  Widget _buildCoinDisplay() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.monetization_on, color: Colors.amber, size: 24),
          const SizedBox(width: 8),
          Text(
            '보유 코인: $_currentCoin',
            style: const TextStyle(
              color: AppColors.text,
              fontSize: 16,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }

  /// 슬롯머신 릴
  Widget _buildSlotMachine() {
    return Container(
      padding: const EdgeInsets.all(10),
      margin: const EdgeInsets.symmetric(horizontal: 12),
      decoration: BoxDecoration(
        color: Colors.black54,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.amber.withValues(alpha: 0.5), width: 2),
        boxShadow: [
          BoxShadow(
            color: Colors.amber.withValues(alpha: 0.2),
            blurRadius: 10,
            spreadRadius: 2,
          ),
        ],
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: [
          _buildReel(0),
          _buildDivider(),
          _buildReel(1),
          _buildDivider(),
          _buildReel(2),
        ],
      ),
    );
  }

  /// 개별 릴
  Widget _buildReel(int index) {
    return Container(
      width: 65,
      height: 90,
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: _targetIndices[index] != null
              ? Colors.amber.withValues(alpha: 0.8)
              : Colors.white24,
          width: 2,
        ),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(6),
        child: SlotMachineRoller(
          height: 86,
          width: 61,
          target: _targetIndices[index],
          delay: Duration(milliseconds: 100 + (index * 50)),
          itemBuilder: (itemIndex) {
            final month = (itemIndex % 12) + 1;
            final monthStr = month.toString().padLeft(2, '0');
            return Container(
              height: 86,
              width: 61,
              padding: const EdgeInsets.all(2),
              child: Image.asset(
                'assets/cards/${monthStr}month_1.png',
                fit: BoxFit.contain,
                errorBuilder: (context, error, stackTrace) {
                  return Center(
                    child: Text(
                      '${SlotResult.monthNames[month]}',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 11,
                      ),
                    ),
                  );
                },
              ),
            );
          },
        ),
      ),
    );
  }

  /// 릴 구분선
  Widget _buildDivider() {
    return Container(
      width: 2,
      height: 80,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            Colors.amber.withValues(alpha: 0.1),
            Colors.amber.withValues(alpha: 0.5),
            Colors.amber.withValues(alpha: 0.1),
          ],
        ),
      ),
    );
  }

  /// 결과 표시
  Widget _buildResultDisplay() {
    if (!_showResult || _lastResult == null) {
      return const SizedBox(height: 40);
    }

    final result = _lastResult!;
    final Color bgColor;
    final Color textColor;

    if (result.isJackpot) {
      bgColor = Colors.amber.withValues(alpha: 0.3);
      textColor = Colors.amber;
    } else if (result.isWin) {
      bgColor = Colors.green.withValues(alpha: 0.3);
      textColor = Colors.greenAccent;
    } else {
      bgColor = Colors.red.withValues(alpha: 0.2);
      textColor = Colors.redAccent;
    }

    return ScaleTransition(
      scale: _resultScaleAnim,
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 20),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        decoration: BoxDecoration(
          color: bgColor,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: textColor.withValues(alpha: 0.5)),
        ),
        child: Text(
          _resultMessage,
          textAlign: TextAlign.center,
          style: TextStyle(
            color: textColor,
            fontSize: 14,
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
    );
  }

  /// 베팅 금액 선택
  Widget _buildBetSelector() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Column(
        children: [
          const Text(
            '베팅 금액',
            style: TextStyle(
              color: AppColors.textSecondary,
              fontSize: 12,
            ),
          ),
          const SizedBox(height: 8),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: SlotMachineService.betOptions.map((amount) {
              final isSelected = _betAmount == amount;
              final canAfford = _currentCoin >= amount;

              return GestureDetector(
                onTap: _isSpinning || !canAfford
                    ? null
                    : () {
                        _soundService.playClick();
                        setState(() => _betAmount = amount);
                      },
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                  decoration: BoxDecoration(
                    color: isSelected
                        ? Colors.amber.withValues(alpha: 0.3)
                        : Colors.white.withValues(alpha: canAfford ? 0.1 : 0.05),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(
                      color: isSelected
                          ? Colors.amber
                          : Colors.white.withValues(alpha: canAfford ? 0.3 : 0.1),
                      width: isSelected ? 2 : 1,
                    ),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        Icons.monetization_on,
                        size: 12,
                        color: canAfford
                            ? (isSelected ? Colors.amber : Colors.amber.withValues(alpha: 0.7))
                            : Colors.grey,
                      ),
                      const SizedBox(width: 2),
                      Text(
                        '$amount',
                        style: TextStyle(
                          fontSize: 12,
                          color: canAfford
                              ? (isSelected ? Colors.amber : AppColors.text)
                              : Colors.grey,
                          fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                        ),
                      ),
                    ],
                  ),
                ),
              );
            }).toList(),
          ),
        ],
      ),
    );
  }

  /// 스핀 버튼
  Widget _buildSpinButton() {
    final canSpin = !_isSpinning && _currentCoin >= _betAmount && _totalRemaining > 0;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: GestureDetector(
        onTap: canSpin ? _spin : null,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          width: double.infinity,
          padding: const EdgeInsets.symmetric(vertical: 14),
          decoration: BoxDecoration(
            gradient: canSpin
                ? const LinearGradient(
                    colors: [Colors.amber, Colors.orange],
                  )
                : LinearGradient(
                    colors: [Colors.grey.shade600, Colors.grey.shade700],
                  ),
            borderRadius: BorderRadius.circular(16),
            boxShadow: canSpin
                ? [
                    BoxShadow(
                      color: Colors.amber.withValues(alpha: 0.4),
                      blurRadius: 10,
                      offset: const Offset(0, 4),
                    ),
                  ]
                : null,
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              if (_isSpinning) ...[
                const SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    valueColor: AlwaysStoppedAnimation(Colors.white),
                  ),
                ),
                const SizedBox(width: 8),
              ],
              Text(
                _isSpinning ? '회전 중...' : '🎰 스핀! (-$_betAmount)',
                style: TextStyle(
                  color: canSpin ? Colors.white : Colors.white60,
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// 배당 정보
  Widget _buildPayoutInfo() {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 20),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        children: [
          const Row(
            children: [
              Icon(Icons.info_outline, color: Colors.white54, size: 14),
              SizedBox(width: 4),
              Text(
                '배당표',
                style: TextStyle(
                  color: Colors.white70,
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          _buildPayoutRow('🌟 광 3매치 (잭팟)', '35x~50x', Colors.amber),
          _buildPayoutRow('🎴 일반월 3매치', '10x', Colors.greenAccent),
          _buildPayoutRow('🎯 2매치', '1.5x', Colors.lightBlueAccent),
          const Divider(color: Colors.white24, height: 12),
          Text(
            '특별월: 1월(송학), 3월(벚꽃), 8월(공산), 11월(오동), 12월(비)',
            style: TextStyle(
              color: Colors.amber.withValues(alpha: 0.7),
              fontSize: 10,
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  Widget _buildPayoutRow(String label, String payout, Color color) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: TextStyle(color: color.withValues(alpha: 0.9), fontSize: 11),
          ),
          Text(
            payout,
            style: TextStyle(
              color: color,
              fontSize: 11,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }

  /// 이용 안내 정보
  Widget _buildUsageInfo() {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 20),
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: Colors.cyan.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(
          color: Colors.cyan.withValues(alpha: 0.3),
          width: 1,
        ),
      ),
      child: Column(
        children: [
          Row(
            children: [
              Icon(
                Icons.access_time,
                color: Colors.cyan.withValues(alpha: 0.8),
                size: 14,
              ),
              const SizedBox(width: 4),
              Text(
                '이용 안내',
                style: TextStyle(
                  color: Colors.cyan.withValues(alpha: 0.9),
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          _buildUsageRow(
            '기본 횟수',
            '매일 ${SlotMachineService.maxDailySpins}회 무료',
            Colors.amber,
          ),
          _buildUsageRow(
            '보너스 횟수',
            '게임 완료 시 +${SlotMachineService.bonusSpinsPerGame}회',
            Colors.greenAccent,
          ),
          const SizedBox(height: 4),
          Text(
            '※ 매일 자정에 모든 횟수가 초기화됩니다',
            style: TextStyle(
              color: Colors.white.withValues(alpha: 0.5),
              fontSize: 9,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildUsageRow(String label, String value, Color color) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: TextStyle(
              color: Colors.white.withValues(alpha: 0.7),
              fontSize: 11,
            ),
          ),
          Text(
            value,
            style: TextStyle(
              color: color,
              fontSize: 11,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }
}
