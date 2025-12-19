import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../config/constants.dart';
import '../../services/coin_service.dart';

/// 코인 보관/출금 다이얼로그
class CoinStorageDialog extends ConsumerStatefulWidget {
  final String uid;
  final int currentCoin;
  final int storedCoin;
  final VoidCallback? onCoinChanged;

  const CoinStorageDialog({
    super.key,
    required this.uid,
    required this.currentCoin,
    required this.storedCoin,
    this.onCoinChanged,
  });

  @override
  ConsumerState<CoinStorageDialog> createState() => _CoinStorageDialogState();
}

class _CoinStorageDialogState extends ConsumerState<CoinStorageDialog>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final _amountController = TextEditingController();

  bool _isProcessing = false;
  String? _errorMessage;
  String? _successMessage;

  // 현재 상태 (로컬)
  late int _currentCoin;
  late int _storedCoin;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _currentCoin = widget.currentCoin;
    _storedCoin = widget.storedCoin;

    _tabController.addListener(() {
      setState(() {
        _amountController.clear();
        _errorMessage = null;
        _successMessage = null;
      });
    });
  }

  @override
  void dispose() {
    _tabController.dispose();
    _amountController.dispose();
    super.dispose();
  }

  /// 보관 가능한 최대 금액
  int get _maxDepositable => (_currentCoin - CoinService.minCoinAfterDeposit).clamp(0, _currentCoin);

  /// 출금 수수료 미리보기
  ({int fee, int netAmount}) _previewWithdraw(int amount) {
    final coinService = ref.read(coinServiceProvider);
    return coinService.previewWithdrawFee(amount);
  }

  /// 보관 처리
  Future<void> _handleDeposit() async {
    final amount = int.tryParse(_amountController.text) ?? 0;
    if (amount <= 0) {
      setState(() => _errorMessage = '보관할 금액을 입력해주세요.');
      return;
    }

    // 최대 보관 가능 금액 체크 (최소 10코인은 보유해야 함)
    if (amount > _maxDepositable) {
      setState(() => _errorMessage = '최대 $_maxDepositable코인까지 보관 가능합니다.\n(최소 ${CoinService.minCoinAfterDeposit}코인은 보유해야 합니다)');
      return;
    }

    setState(() {
      _isProcessing = true;
      _errorMessage = null;
      _successMessage = null;
    });

    try {
      final coinService = ref.read(coinServiceProvider);
      final result = await coinService.depositCoins(widget.uid, amount);

      if (result.success) {
        setState(() {
          _currentCoin = result.newCoin;
          _storedCoin = result.newStoredCoin;
          _successMessage = result.message;
          _amountController.clear();
        });
        widget.onCoinChanged?.call();
      } else {
        setState(() => _errorMessage = result.message);
      }
    } catch (e) {
      setState(() => _errorMessage = '오류가 발생했습니다.');
    } finally {
      setState(() => _isProcessing = false);
    }
  }

  /// 출금 처리
  Future<void> _handleWithdraw() async {
    final amount = int.tryParse(_amountController.text) ?? 0;
    if (amount <= 0) {
      setState(() => _errorMessage = '출금할 금액을 입력해주세요.');
      return;
    }

    setState(() {
      _isProcessing = true;
      _errorMessage = null;
      _successMessage = null;
    });

    try {
      final coinService = ref.read(coinServiceProvider);
      final result = await coinService.withdrawCoins(widget.uid, amount);

      if (result.success) {
        setState(() {
          _currentCoin = result.newCoin;
          _storedCoin = result.newStoredCoin;
          _successMessage = result.message;
          _amountController.clear();
        });
        widget.onCoinChanged?.call();
      } else {
        setState(() => _errorMessage = result.message);
      }
    } catch (e) {
      setState(() => _errorMessage = '오류가 발생했습니다.');
    } finally {
      setState(() => _isProcessing = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: Colors.transparent,
      child: Container(
        width: 360,
        constraints: const BoxConstraints(maxHeight: 520),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              Colors.indigo.shade900,
              Colors.indigo.shade800,
            ],
          ),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: Colors.amber.shade400, width: 2),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.5),
              blurRadius: 20,
              spreadRadius: 5,
            ),
          ],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            _buildHeader(),
            _buildCoinSummary(),
            _buildTabBar(),
            Flexible(child: _buildTabContent()),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [Colors.amber.shade700, Colors.amber.shade600],
        ),
        borderRadius: const BorderRadius.vertical(top: Radius.circular(18)),
      ),
      child: Row(
        children: [
          const Icon(Icons.account_balance, color: Colors.black, size: 28),
          const SizedBox(width: 8),
          const Text(
            '코인 보관함',
            style: TextStyle(
              color: Colors.black,
              fontSize: 20,
              fontWeight: FontWeight.bold,
            ),
          ),
          const Spacer(),
          IconButton(
            icon: const Icon(Icons.close, color: Colors.black),
            onPressed: () => Navigator.of(context).pop(),
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(),
          ),
        ],
      ),
    );
  }

  Widget _buildCoinSummary() {
    return Container(
      margin: const EdgeInsets.all(16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.3),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.amber.withValues(alpha: 0.3)),
      ),
      child: Row(
        children: [
          Expanded(
            child: _buildCoinInfo(
              label: '소유 코인',
              amount: _currentCoin,
              color: Colors.amber,
              icon: Icons.monetization_on,
            ),
          ),
          Container(
            width: 1,
            height: 50,
            color: Colors.white.withValues(alpha: 0.2),
          ),
          Expanded(
            child: _buildCoinInfo(
              label: '보관 코인',
              amount: _storedCoin,
              color: Colors.cyanAccent,
              icon: Icons.savings,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCoinInfo({
    required String label,
    required int amount,
    required Color color,
    required IconData icon,
  }) {
    return Column(
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, color: color, size: 18),
            const SizedBox(width: 4),
            Text(
              label,
              style: TextStyle(
                color: Colors.white.withValues(alpha: 0.7),
                fontSize: 12,
              ),
            ),
          ],
        ),
        const SizedBox(height: 4),
        Text(
          '$amount',
          style: TextStyle(
            color: color,
            fontSize: 24,
            fontWeight: FontWeight.bold,
          ),
        ),
      ],
    );
  }

  Widget _buildTabBar() {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16),
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.3),
        borderRadius: BorderRadius.circular(25),
      ),
      child: TabBar(
        controller: _tabController,
        indicator: BoxDecoration(
          gradient: LinearGradient(
            colors: [Colors.amber.shade600, Colors.amber.shade400],
          ),
          borderRadius: BorderRadius.circular(25),
        ),
        labelColor: Colors.black,
        unselectedLabelColor: Colors.white.withValues(alpha: 0.7),
        labelStyle: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
        dividerColor: Colors.transparent,
        tabs: const [
          Tab(text: '보관하기'),
          Tab(text: '출금하기'),
        ],
      ),
    );
  }

  Widget _buildTabContent() {
    return TabBarView(
      controller: _tabController,
      children: [
        _buildDepositTab(),
        _buildWithdrawTab(),
      ],
    );
  }

  Widget _buildDepositTab() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 설명
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.blue.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: Colors.blue.withValues(alpha: 0.3)),
            ),
            child: Row(
              children: [
                Icon(Icons.info_outline, color: Colors.blue.shade300, size: 20),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    '보관된 코인은 게임 정산에 포함되지 않습니다.\n최소 ${CoinService.minCoinAfterDeposit}코인은 보유해야 합니다.',
                    style: TextStyle(
                      color: Colors.blue.shade200,
                      fontSize: 12,
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),

          // 보관 가능 금액
          Text(
            '보관 가능: $_maxDepositable 코인',
            style: TextStyle(
              color: Colors.white.withValues(alpha: 0.7),
              fontSize: 13,
            ),
          ),
          const SizedBox(height: 8),

          // 금액 입력
          _buildAmountInput(
            hint: '보관할 금액 입력',
            maxAmount: _maxDepositable,
          ),
          const SizedBox(height: 12),

          // 빠른 선택 버튼
          _buildQuickAmountButtons(_maxDepositable),
          const SizedBox(height: 16),

          // 메시지
          _buildMessages(),
          const SizedBox(height: 16),

          // 보관 버튼
          _buildActionButton(
            label: '보관하기',
            onPressed: _maxDepositable > 0 ? _handleDeposit : null,
            color: Colors.blue,
          ),
        ],
      ),
    );
  }

  Widget _buildWithdrawTab() {
    final inputAmount = int.tryParse(_amountController.text) ?? 0;
    final preview = inputAmount > 0 ? _previewWithdraw(inputAmount) : null;

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 설명
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.orange.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: Colors.orange.withValues(alpha: 0.3)),
            ),
            child: Row(
              children: [
                Icon(Icons.warning_amber, color: Colors.orange.shade300, size: 20),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    '출금 시 ${(CoinService.withdrawFeeRate * 100).toInt()}% 수수료가 차감됩니다.',
                    style: TextStyle(
                      color: Colors.orange.shade200,
                      fontSize: 12,
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),

          // 출금 가능 금액
          Text(
            '출금 가능: $_storedCoin 코인',
            style: TextStyle(
              color: Colors.white.withValues(alpha: 0.7),
              fontSize: 13,
            ),
          ),
          const SizedBox(height: 8),

          // 금액 입력
          _buildAmountInput(
            hint: '출금할 금액 입력',
            maxAmount: _storedCoin,
          ),
          const SizedBox(height: 12),

          // 빠른 선택 버튼
          _buildQuickAmountButtons(_storedCoin),
          const SizedBox(height: 12),

          // 수수료 미리보기
          if (preview != null && inputAmount > 0)
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.black.withValues(alpha: 0.3),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Column(
                children: [
                  _buildPreviewRow('출금 금액', '$inputAmount 코인', Colors.white),
                  const SizedBox(height: 4),
                  _buildPreviewRow('수수료 (15%)', '-${preview.fee} 코인', Colors.red.shade300),
                  const Divider(color: Colors.white24, height: 16),
                  _buildPreviewRow('실수령액', '${preview.netAmount} 코인', Colors.greenAccent),
                ],
              ),
            ),
          const SizedBox(height: 16),

          // 메시지
          _buildMessages(),
          const SizedBox(height: 16),

          // 출금 버튼
          _buildActionButton(
            label: '출금하기',
            onPressed: _storedCoin > 0 ? _handleWithdraw : null,
            color: Colors.orange,
          ),
        ],
      ),
    );
  }

  Widget _buildPreviewRow(String label, String value, Color valueColor) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          label,
          style: TextStyle(
            color: Colors.white.withValues(alpha: 0.7),
            fontSize: 13,
          ),
        ),
        Text(
          value,
          style: TextStyle(
            color: valueColor,
            fontSize: 13,
            fontWeight: FontWeight.bold,
          ),
        ),
      ],
    );
  }

  Widget _buildAmountInput({
    required String hint,
    required int maxAmount,
  }) {
    return TextField(
      controller: _amountController,
      keyboardType: TextInputType.number,
      inputFormatters: [FilteringTextInputFormatter.digitsOnly],
      style: const TextStyle(color: Colors.white, fontSize: 18),
      decoration: InputDecoration(
        hintText: hint,
        hintStyle: TextStyle(color: Colors.white.withValues(alpha: 0.3)),
        filled: true,
        fillColor: Colors.black.withValues(alpha: 0.3),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: Colors.amber.withValues(alpha: 0.5)),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: Colors.amber.withValues(alpha: 0.3)),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: Colors.amber, width: 2),
        ),
        suffixText: '코인',
        suffixStyle: TextStyle(color: Colors.white.withValues(alpha: 0.7)),
        suffixIcon: IconButton(
          icon: const Icon(Icons.all_inclusive, color: Colors.amber),
          onPressed: () {
            _amountController.text = maxAmount.toString();
            setState(() {});
          },
          tooltip: '전액',
        ),
      ),
      onChanged: (_) => setState(() {}),
    );
  }

  Widget _buildQuickAmountButtons(int maxAmount) {
    final amounts = [10, 50, 100, 500];
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: amounts
          .where((a) => a <= maxAmount)
          .map((amount) => _buildQuickButton(amount))
          .toList(),
    );
  }

  Widget _buildQuickButton(int amount) {
    return InkWell(
      onTap: () {
        _amountController.text = amount.toString();
        setState(() {});
      },
      borderRadius: BorderRadius.circular(20),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        decoration: BoxDecoration(
          color: Colors.amber.withValues(alpha: 0.2),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: Colors.amber.withValues(alpha: 0.5)),
        ),
        child: Text(
          '+$amount',
          style: const TextStyle(
            color: Colors.amber,
            fontWeight: FontWeight.bold,
            fontSize: 13,
          ),
        ),
      ),
    );
  }

  Widget _buildMessages() {
    if (_errorMessage != null) {
      return Container(
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          color: Colors.red.withValues(alpha: 0.2),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: Colors.red.withValues(alpha: 0.5)),
        ),
        child: Row(
          children: [
            const Icon(Icons.error_outline, color: Colors.red, size: 18),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                _errorMessage!,
                style: const TextStyle(color: Colors.red, fontSize: 13),
              ),
            ),
          ],
        ),
      );
    }

    if (_successMessage != null) {
      return Container(
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          color: Colors.green.withValues(alpha: 0.2),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: Colors.green.withValues(alpha: 0.5)),
        ),
        child: Row(
          children: [
            const Icon(Icons.check_circle_outline, color: Colors.green, size: 18),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                _successMessage!,
                style: const TextStyle(color: Colors.green, fontSize: 13),
              ),
            ),
          ],
        ),
      );
    }

    return const SizedBox.shrink();
  }

  Widget _buildActionButton({
    required String label,
    required VoidCallback? onPressed,
    required Color color,
  }) {
    return SizedBox(
      width: double.infinity,
      height: 50,
      child: ElevatedButton(
        onPressed: _isProcessing ? null : onPressed,
        style: ElevatedButton.styleFrom(
          backgroundColor: color,
          foregroundColor: Colors.white,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          elevation: 4,
        ),
        child: _isProcessing
            ? const SizedBox(
                width: 24,
                height: 24,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                ),
              )
            : Text(
                label,
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
              ),
      ),
    );
  }
}
