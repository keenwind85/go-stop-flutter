import 'package:flutter/material.dart';
import 'package:firebase_database/firebase_database.dart';
import '../../config/constants.dart';

/// 게임 가이드 다이얼로그
class GameGuideDialog extends StatefulWidget {
  final bool showDontShowAgain;
  final String? userId;
  final VoidCallback? onClose;

  const GameGuideDialog({
    super.key,
    this.showDontShowAgain = true,
    this.userId,
    this.onClose,
  });

  /// 다시 보지 않기 설정 확인 (Firebase)
  static Future<bool> shouldNotShowAgain(String userId) async {
    try {
      final ref = FirebaseDatabase.instance.ref('users/$userId/settings/dontShowGuide');
      final snapshot = await ref.get();
      return snapshot.value == true;
    } catch (e) {
      return false;
    }
  }

  /// 가이드를 봤는지 확인 (Firebase)
  static Future<bool> hasSeenGuide(String userId) async {
    try {
      final ref = FirebaseDatabase.instance.ref('users/$userId/settings/guideShown');
      final snapshot = await ref.get();
      return snapshot.value == true;
    } catch (e) {
      return false;
    }
  }

  /// 가이드를 봤음을 기록
  static Future<void> markAsShown(String userId) async {
    try {
      final ref = FirebaseDatabase.instance.ref('users/$userId/settings/guideShown');
      await ref.set(true);
    } catch (e) {
      // 무시
    }
  }

  /// 다시 보지 않기 설정
  static Future<void> setDontShowAgain(String userId, bool value) async {
    try {
      final ref = FirebaseDatabase.instance.ref('users/$userId/settings/dontShowGuide');
      await ref.set(value);
    } catch (e) {
      // 무시
    }
  }

  /// 최초 로그인 시 가이드 표시 여부 확인
  static Future<bool> shouldShowOnFirstLogin(String userId) async {
    final dontShow = await shouldNotShowAgain(userId);
    if (dontShow) return false;

    final hasShown = await hasSeenGuide(userId);
    return !hasShown;
  }

  @override
  State<GameGuideDialog> createState() => _GameGuideDialogState();
}

class _GameGuideDialogState extends State<GameGuideDialog>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  bool _dontShowAgain = false;

  final List<_GuideSection> _sections = [
    _GuideSection(
      title: '시작하기',
      icon: Icons.play_arrow,
      content: _buildStartSection(),
    ),
    _GuideSection(
      title: '기본 룰',
      icon: Icons.school,
      content: _buildBasicRulesSection(),
    ),
    _GuideSection(
      title: '특수 룰',
      icon: Icons.star,
      content: _buildSpecialRulesSection(),
    ),
    _GuideSection(
      title: '점수',
      icon: Icons.calculate,
      content: _buildScoreSection(),
    ),
    _GuideSection(
      title: '아이템',
      icon: Icons.inventory_2,
      content: _buildItemSection(),
    ),
  ];

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: _sections.length, vsync: this);
    _loadDontShowAgain();
  }

  Future<void> _loadDontShowAgain() async {
    if (widget.userId != null) {
      final value = await GameGuideDialog.shouldNotShowAgain(widget.userId!);
      if (mounted) {
        setState(() => _dontShowAgain = value);
      }
    }
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _handleClose() async {
    if (widget.userId != null) {
      await GameGuideDialog.markAsShown(widget.userId!);
      if (_dontShowAgain) {
        await GameGuideDialog.setDontShowAgain(widget.userId!, true);
      }
    }
    if (mounted) {
      Navigator.of(context).pop();
      widget.onClose?.call();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
      child: Container(
        constraints: BoxConstraints(
          maxWidth: 500,
          maxHeight: MediaQuery.of(context).size.height * 0.85,
        ),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              AppColors.woodDark,
              AppColors.woodDark.withValues(alpha: 0.98),
            ],
          ),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: AppColors.woodLight, width: 4),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.6),
              blurRadius: 20,
              offset: const Offset(0, 10),
            ),
          ],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // 헤더
            _buildHeader(),
            // 탭 바
            _buildTabBar(),
            // 컨텐츠
            Flexible(
              child: TabBarView(
                controller: _tabController,
                children: _sections.map((s) => s.content).toList(),
              ),
            ),
            // 하단 (다시보지 않기 + 닫기 버튼)
            _buildFooter(),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            Colors.amber.shade700.withValues(alpha: 0.3),
            Colors.amber.shade900.withValues(alpha: 0.2),
          ],
        ),
        borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: Colors.amber.shade700,
              shape: BoxShape.circle,
            ),
            child: const Icon(
              Icons.help_outline,
              color: Colors.white,
              size: 24,
            ),
          ),
          const SizedBox(width: 12),
          const Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '맞고 게임 가이드',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                SizedBox(height: 2),
                Text(
                  '게임 방법과 규칙을 알아보세요!',
                  style: TextStyle(
                    color: AppColors.textSecondary,
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          ),
          IconButton(
            onPressed: _handleClose,
            icon: const Icon(Icons.close, color: AppColors.text),
          ),
        ],
      ),
    );
  }

  Widget _buildTabBar() {
    return Container(
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.3),
        border: Border(
          bottom: BorderSide(
            color: AppColors.woodLight.withValues(alpha: 0.3),
          ),
        ),
      ),
      child: TabBar(
        controller: _tabController,
        isScrollable: true,
        tabAlignment: TabAlignment.start,
        indicatorColor: Colors.amber,
        indicatorWeight: 3,
        labelColor: Colors.amber,
        unselectedLabelColor: AppColors.textSecondary,
        labelStyle: const TextStyle(
          fontWeight: FontWeight.bold,
          fontSize: 13,
        ),
        tabs: _sections
            .map((s) => Tab(
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(s.icon, size: 18),
                      const SizedBox(width: 6),
                      Text(s.title),
                    ],
                  ),
                ))
            .toList(),
      ),
    );
  }

  Widget _buildFooter() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.3),
        borderRadius: const BorderRadius.vertical(bottom: Radius.circular(16)),
      ),
      child: Column(
        children: [
          // 다시 보지 않기 체크박스
          if (widget.showDontShowAgain)
            GestureDetector(
              onTap: () => setState(() => _dontShowAgain = !_dontShowAgain),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                margin: const EdgeInsets.only(bottom: 12),
                decoration: BoxDecoration(
                  color: _dontShowAgain
                      ? Colors.amber.withValues(alpha: 0.2)
                      : Colors.transparent,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(
                    color: _dontShowAgain
                        ? Colors.amber.withValues(alpha: 0.5)
                        : AppColors.textSecondary.withValues(alpha: 0.3),
                  ),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      _dontShowAgain
                          ? Icons.check_box
                          : Icons.check_box_outline_blank,
                      color: _dontShowAgain
                          ? Colors.amber
                          : AppColors.textSecondary,
                      size: 20,
                    ),
                    const SizedBox(width: 8),
                    Text(
                      '다시 보지 않기',
                      style: TextStyle(
                        color: _dontShowAgain
                            ? Colors.amber
                            : AppColors.textSecondary,
                        fontSize: 14,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          // 닫기 버튼
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: _handleClose,
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.amber.shade700,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
                elevation: 4,
              ),
              child: const Text(
                '확인',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ============= 섹션 컨텐츠 빌더 =============

  static Widget _buildStartSection() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildSectionTitle('게임 로비'),
          _buildInfoCard(
            icon: '🪙',
            title: '코인 카드',
            description: '화면 상단에 현재 보유 코인이 표시됩니다.\n코인은 게임 참가, 아이템 구매 등에 사용됩니다.\n\n💰 코인 보관: 코인을 안전하게 보관할 수 있습니다.\n🎁 코인 기부: 코인을 기부하여 특별 보상을 받으세요!',
          ),
          _buildInfoCard(
            icon: '🔥',
            title: '광끼 게이지',
            description: '코인 카드 아래에 광끼 게이지가 표시됩니다.\n게이지가 100에 도달하면 특별한 광끼 모드를 활성화할 수 있습니다.\n\n⚠️ 광끼 모드가 활성화되면:\n• 해당 게임에서는 오직 "고"만 가능\n• 활성화한 사용자가 승리 시 다른 플레이어의 모든 코인 독식!\n\n💡 TIP: 광끼 모드에서 모든 코인을 잃기 싫다면 미리미리 은행에 코인을 보관해두세요.',
            color: Colors.deepOrange,
          ),
          _buildInfoCard(
            icon: '📅',
            title: '일일 활동',
            description: '• 출석 체크: 매일 출석하여 보상 획득\n• 슬롯머신: 코인을 베팅하여 대박 도전!\n• 기부: 코인을 기부하여 특별 보상\n• 랭킹: 전체 플레이어 순위 확인',
          ),
          _buildInfoCard(
            icon: '⚙️',
            title: '설정',
            description: '우측 상단 설정 아이콘을 터치하세요.\n• 닉네임 변경: 원하는 닉네임으로 변경 가능\n• 사운드 설정: 게임 효과음 ON/OFF',
            color: Colors.blueGrey,
          ),
          const SizedBox(height: 16),
          _buildSectionTitle('게임 시작 방법'),
          _buildInfoCard(
            icon: '🎮',
            title: '게임 모드 선택',
            description: '방을 만들 때 게임 모드를 선택할 수 있습니다:\n\n• 맞고 모드: 2인 플레이 (손패 10장, 바닥 8장)\n• 고스톱 모드: 2~3인 플레이 (손패 7장, 바닥 6장)',
            color: Colors.cyan,
          ),
          _buildStepCard(
            step: 1,
            title: '방 만들기',
            description: '"새 게임 만들기" 버튼 터치 → 게임 모드 선택 → 상대방 입장 대기',
          ),
          _buildStepCard(
            step: 2,
            title: '방 참가하기',
            description: '대기 중인 방 목록에서 선택 → "입장" 버튼 터치',
          ),
          _buildStepCard(
            step: 3,
            title: '친구와 함께',
            description: '방 코드 4자리를 공유하여 직접 참가 가능',
          ),
        ],
      ),
    );
  }

  static Widget _buildBasicRulesSection() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildSectionTitle('맞고 vs 고스톱 차이점'),
          _buildInfoCard(
            icon: '👥',
            title: '맞고 모드 (2인)',
            description: '• 플레이어: 2명\n• 손패: 10장씩\n• 바닥패: 8장\n• 피박 기준: 7장 이하',
            color: Colors.blue,
          ),
          _buildInfoCard(
            icon: '👥',
            title: '고스톱 모드 (2~3인)',
            description: '• 플레이어: 2~3명\n• 손패: 7장씩\n• 바닥패: 6장\n• 피박 기준: 5장 이하',
            color: Colors.purple,
          ),
          const SizedBox(height: 16),
          _buildSectionTitle('게임 진행'),
          _buildNumberedList([
            '각 플레이어에게 패가 배분됩니다 (맞고 10장/고스톱 7장)',
            '바닥에 패가 깔립니다 (맞고 8장/고스톱 6장)',
            '자신의 턴에 손패 1장을 바닥에 내려놓습니다',
            '같은 월(花)의 패가 있으면 가져옵니다',
            '더미에서 1장을 뒤집어 같은 월의 패가 있으면 가져옵니다',
            '7점 이상 모으면 "고" 또는 "스톱"을 선택할 수 있습니다',
          ]),
          const SizedBox(height: 16),
          _buildSectionTitle('패의 종류'),
          _buildCardTypeRow(
            emoji: '🌟',
            name: '광(光)',
            count: '5장',
            description: '1월, 3월, 8월, 11월, 12월의 특별한 패',
            color: Colors.amber,
          ),
          _buildCardTypeRow(
            emoji: '🦌',
            name: '열끗(動物)',
            count: '9장',
            description: '각 월의 동물 그림 패',
            color: Colors.green,
          ),
          _buildCardTypeRow(
            emoji: '📜',
            name: '띠(短冊)',
            count: '10장',
            description: '각 월의 띠 그림 패',
            color: Colors.blue,
          ),
          _buildCardTypeRow(
            emoji: '🍂',
            name: '피(カス)',
            count: '24장',
            description: '일반 패',
            color: Colors.grey,
          ),
          const SizedBox(height: 16),
          _buildSectionTitle('고(Go)와 스톱(Stop)'),
          _buildInfoCard(
            icon: '🚀',
            title: '고(Go)',
            description: '게임을 계속하여 더 높은 점수를 노립니다.\n점수가 2배씩 증가합니다!',
            color: Colors.red,
          ),
          _buildInfoCard(
            icon: '✋',
            title: '스톱(Stop)',
            description: '현재 점수로 게임을 종료합니다.\n안전하게 승리를 확정합니다.',
            color: Colors.green,
          ),
        ],
      ),
    );
  }

  static Widget _buildSpecialRulesSection() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildSectionTitle('특수 이벤트'),
          _buildInfoCard(
            icon: '💋',
            title: '쪽',
            description: '내 패와 바닥 패가 같은 월일 때 발생\n→ 상대방 피 1장 가져오기',
            color: Colors.pink,
          ),
          _buildInfoCard(
            icon: '💥',
            title: '뻑',
            description: '바닥에 같은 월 패가 2장 있을 때, 3장째가 나오면\n→ 모두 가져오기',
            color: Colors.orange,
          ),
          _buildInfoCard(
            icon: '🔥',
            title: '따닥',
            description: '바닥에 같은 월 패가 3장 있을 때\n→ 모두 가져오기',
            color: Colors.red,
          ),
          _buildInfoCard(
            icon: '🧹',
            title: '싹쓸이',
            description: '바닥의 모든 패를 가져갈 때\n→ 상대방 피 1장 가져오기',
            color: Colors.purple,
          ),
          const SizedBox(height: 16),
          _buildSectionTitle('손패 특수 규칙'),
          _buildInfoCard(
            icon: '💣',
            title: '폭탄',
            description: '손패에 같은 월 패가 4장 있으면\n한 번에 모두 내려놓을 수 있습니다.\n→ 점수 2배',
            color: Colors.deepOrange,
          ),
          _buildInfoCard(
            icon: '🎲',
            title: '흔들기',
            description: '손패에 같은 월 패가 3장 있으면\n흔들어서 점수를 2배로 만들 수 있습니다.',
            color: Colors.indigo,
          ),
          const SizedBox(height: 16),
          _buildSectionTitle('설사 (초장 특수 패)'),
          _buildInfoCard(
            icon: '👑',
            title: '총통',
            description: '처음 받은 패 중 같은 월이 4장 있으면\n→ 즉시 승리!',
            color: Colors.amber,
          ),
        ],
      ),
    );
  }

  static Widget _buildScoreSection() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildSectionTitle('광 점수'),
          _buildScoreTable([
            ['삼광', '3점', '비광(12월) 제외 광 3장'],
            ['비광삼광', '2점', '비광 포함 광 3장'],
            ['사광', '4점', '비광 제외 광 4장'],
            ['비광사광', '4점', '비광 포함 광 4장'],
            ['오광', '15점', '광 5장 모두'],
          ]),
          const SizedBox(height: 16),
          _buildSectionTitle('특수 조합 점수'),
          _buildScoreTable([
            ['고도리', '5점', '2월, 4월, 8월 열끗 3장'],
            ['홍단', '3점', '1월, 2월, 3월 홍단 3장'],
            ['청단', '3점', '6월, 9월, 10월 청단 3장'],
            ['초단', '3점', '4월, 5월, 7월 초단 3장'],
          ]),
          const SizedBox(height: 16),
          _buildSectionTitle('기본 점수'),
          _buildScoreTable([
            ['열끗', '5장부터', '1점씩 추가'],
            ['띠', '5장부터', '1점씩 추가'],
            ['피', '10장부터', '1점씩 추가'],
          ]),
          const SizedBox(height: 16),
          _buildSectionTitle('점수 배수 규칙'),
          _buildScoreTable([
            ['고(Go) 1회', '+1점', '기본 점수에 1점 추가'],
            ['고(Go) 2회', '+2점', '기본 점수에 2점 추가'],
            ['고(Go) 3회', 'x2', '기본 점수 2배'],
            ['고(Go) 4회', 'x4', '기본 점수 4배'],
            ['고(Go) 5회+', 'x8, x16...', '2배씩 증가'],
          ]),
          const SizedBox(height: 12),
          _buildMultiplierTable([
            ['흔들기', 'x2'],
            ['폭탄', 'x2'],
            ['멍따 (열끗 7장+)', 'x2'],
          ]),
          const SizedBox(height: 16),
          _buildSectionTitle('코인 정산 배수'),
          _buildMultiplierTable([
            ['피박', 'x2'],
            ['광박 (상대 광 0장)', 'x2'],
            ['고박', 'x2'],
          ]),
        ],
      ),
    );
  }

  static Widget _buildItemSection() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildSectionTitle('아이템 목록'),
          _buildItemCard(
            emoji: '🧪',
            name: '광끼의 물약',
            price: '50',
            effect: '광끼 게이지를 즉시 20 증가',
          ),
          _buildItemCard(
            emoji: '🎯',
            name: '제발 Go만해!',
            price: '30',
            effect: '상대방이 다음 선택에서 반드시 Go 선택',
          ),
          _buildItemCard(
            emoji: '🛑',
            name: '제발 Stop만해!',
            price: '30',
            effect: '상대방이 다음 선택에서 반드시 Stop 선택',
          ),
          _buildItemCard(
            emoji: '🔄',
            name: '우리 패 바꾸자!',
            price: '80',
            effect: '상대방과 손패를 교환',
          ),
          _buildItemCard(
            emoji: '🃏',
            name: '밑장 빼기',
            price: '60',
            effect: '더미의 맨 아래 카드를 확인하고 가져옴',
          ),
          _buildItemCard(
            emoji: '♻️',
            name: '손패 교체',
            price: '50',
            effect: '자신의 손패를 새로운 패로 교체',
          ),
          _buildItemCard(
            emoji: '🎴',
            name: '바닥패 교체',
            price: '50',
            effect: '바닥에 깔린 패를 새로운 패로 교체',
          ),
          _buildItemCard(
            emoji: '✨',
            name: '光의 기운',
            price: '100',
            effect: '다음 뽑는 카드가 광일 확률 대폭 증가',
          ),
          const SizedBox(height: 16),
          _buildSectionTitle('아이템 사용 규칙'),
          _buildInfoCard(
            icon: '📋',
            title: '사용 조건',
            description: '• 아이템은 자신의 턴에만 사용 가능\n• 한 게임당 사용 가능한 아이템 수 제한\n• 일부 아이템은 하루 구매 수량 제한',
            color: Colors.blue,
          ),
        ],
      ),
    );
  }

  // ============= UI 컴포넌트 헬퍼 =============

  static Widget _buildSectionTitle(String title) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        children: [
          Container(
            width: 4,
            height: 20,
            decoration: BoxDecoration(
              color: Colors.amber,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const SizedBox(width: 8),
          Text(
            title,
            style: const TextStyle(
              color: Colors.amber,
              fontSize: 18,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }

  static Widget _buildInfoCard({
    required String icon,
    required String title,
    required String description,
    Color? color,
  }) {
    final cardColor = color ?? Colors.blueGrey;
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: cardColor.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: cardColor.withValues(alpha: 0.4),
        ),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(icon, style: const TextStyle(fontSize: 28)),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: TextStyle(
                    color: cardColor,
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  description,
                  style: const TextStyle(
                    color: AppColors.text,
                    fontSize: 13,
                    height: 1.4,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  static Widget _buildStepCard({
    required int step,
    required String title,
    required String description,
  }) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.green.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: Colors.green.withValues(alpha: 0.3),
        ),
      ),
      child: Row(
        children: [
          Container(
            width: 36,
            height: 36,
            decoration: const BoxDecoration(
              color: Colors.green,
              shape: BoxShape.circle,
            ),
            child: Center(
              child: Text(
                '$step',
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    color: Colors.greenAccent,
                    fontSize: 15,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  description,
                  style: const TextStyle(
                    color: AppColors.text,
                    fontSize: 13,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  static Widget _buildNumberedList(List<String> items) {
    return Column(
      children: items.asMap().entries.map((entry) {
        final index = entry.key + 1;
        final text = entry.value;
        return Padding(
          padding: const EdgeInsets.only(bottom: 8),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 24,
                height: 24,
                decoration: BoxDecoration(
                  color: Colors.amber.withValues(alpha: 0.3),
                  shape: BoxShape.circle,
                ),
                child: Center(
                  child: Text(
                    '$index',
                    style: const TextStyle(
                      color: Colors.amber,
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  text,
                  style: const TextStyle(
                    color: AppColors.text,
                    fontSize: 14,
                  ),
                ),
              ),
            ],
          ),
        );
      }).toList(),
    );
  }

  static Widget _buildCardTypeRow({
    required String emoji,
    required String name,
    required String count,
    required String description,
    required Color color,
  }) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Row(
        children: [
          Text(emoji, style: const TextStyle(fontSize: 24)),
          const SizedBox(width: 10),
          Text(
            name,
            style: TextStyle(
              color: color,
              fontSize: 15,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(width: 8),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.3),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Text(
              count,
              style: TextStyle(
                color: color,
                fontSize: 11,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              description,
              style: const TextStyle(
                color: AppColors.textSecondary,
                fontSize: 12,
              ),
            ),
          ),
        ],
      ),
    );
  }

  static Widget _buildScoreTable(List<List<String>> rows) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.3),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: AppColors.woodLight.withValues(alpha: 0.3)),
      ),
      child: Column(
        children: rows.asMap().entries.map((entry) {
          final isLast = entry.key == rows.length - 1;
          final row = entry.value;
          return Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            decoration: BoxDecoration(
              border: isLast
                  ? null
                  : Border(
                      bottom: BorderSide(
                        color: AppColors.woodLight.withValues(alpha: 0.2),
                      ),
                    ),
            ),
            child: Row(
              children: [
                Expanded(
                  flex: 2,
                  child: Text(
                    row[0],
                    style: const TextStyle(
                      color: Colors.amber,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                Expanded(
                  flex: 1,
                  child: Text(
                    row[1],
                    style: const TextStyle(color: Colors.greenAccent),
                    textAlign: TextAlign.center,
                  ),
                ),
                Expanded(
                  flex: 3,
                  child: Text(
                    row[2],
                    style: const TextStyle(
                      color: AppColors.textSecondary,
                      fontSize: 12,
                    ),
                  ),
                ),
              ],
            ),
          );
        }).toList(),
      ),
    );
  }

  static Widget _buildMultiplierTable(List<List<String>> rows) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.red.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.red.withValues(alpha: 0.3)),
      ),
      child: Column(
        children: rows.asMap().entries.map((entry) {
          final isLast = entry.key == rows.length - 1;
          final row = entry.value;
          return Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(
              border: isLast
                  ? null
                  : Border(
                      bottom: BorderSide(
                        color: Colors.red.withValues(alpha: 0.2),
                      ),
                    ),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  row[0],
                  style: const TextStyle(color: AppColors.text),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: Colors.red.withValues(alpha: 0.3),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    row[1],
                    style: const TextStyle(
                      color: Colors.redAccent,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ],
            ),
          );
        }).toList(),
      ),
    );
  }

  static Widget _buildItemCard({
    required String emoji,
    required String name,
    required String price,
    required String effect,
  }) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.indigo.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: Colors.indigo.withValues(alpha: 0.4)),
      ),
      child: Row(
        children: [
          Text(emoji, style: const TextStyle(fontSize: 28)),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Text(
                      name,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 14,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        color: Colors.amber.withValues(alpha: 0.3),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Text('🪙', style: TextStyle(fontSize: 10)),
                          const SizedBox(width: 2),
                          Text(
                            price,
                            style: TextStyle(
                              color: Colors.amber.shade400,
                              fontSize: 11,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                Text(
                  effect,
                  style: const TextStyle(
                    color: AppColors.textSecondary,
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _GuideSection {
  final String title;
  final IconData icon;
  final Widget content;

  const _GuideSection({
    required this.title,
    required this.icon,
    required this.content,
  });
}
