import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../config/constants.dart';
import '../../services/settings_service.dart';

/// 설정 다이얼로그
class SettingsDialog extends ConsumerStatefulWidget {
  final String uid;
  final String googleDisplayName; // 구글 기본 닉네임

  const SettingsDialog({
    super.key,
    required this.uid,
    required this.googleDisplayName,
  });

  @override
  ConsumerState<SettingsDialog> createState() => _SettingsDialogState();
}

class _SettingsDialogState extends ConsumerState<SettingsDialog> {
  final _nicknameController = TextEditingController();
  bool _soundEnabled = true;
  bool _isLoading = true;
  bool _isSaving = false;
  String? _nicknameError;
  String? _currentCustomNickname;

  @override
  void initState() {
    super.initState();
    _loadSettings();
  }

  @override
  void dispose() {
    _nicknameController.dispose();
    super.dispose();
  }

  Future<void> _loadSettings() async {
    final settingsService = ref.read(settingsServiceProvider);
    final settings = await settingsService.getUserSettings(widget.uid);

    if (mounted) {
      setState(() {
        _currentCustomNickname = settings.customNickname;
        _nicknameController.text = settings.customNickname ?? '';
        _soundEnabled = settings.soundEnabled;
        _isLoading = false;
      });
    }
  }

  /// 조합 중인 한글 자모가 있는지 확인
  bool _hasIncompleteHangul() {
    final value = _nicknameController.text;
    return RegExp(r'[ㄱ-ㅎㅏ-ㅣ]').hasMatch(value);
  }

  void _validateNickname(String value) {
    if (value.isEmpty) {
      setState(() => _nicknameError = null);
      return;
    }

    // 입력 중 유효성 검사 (한글 자모 조합 중에도 허용)
    // 조합 중인 한글 자모(ㄱ-ㅎ, ㅏ-ㅣ)가 포함되어 있으면 아직 입력 중이므로 에러 표시 안함
    final hasIncompleteHangul = RegExp(r'[ㄱ-ㅎㅏ-ㅣ]').hasMatch(value);
    if (hasIncompleteHangul) {
      setState(() => _nicknameError = null);
      return;
    }

    setState(() {
      _nicknameError = SettingsService.validateNickname(value);
    });
  }

  Future<void> _saveNickname() async {
    final nickname = _nicknameController.text.trim();

    // 변경 사항이 없으면 무시
    if (nickname == (_currentCustomNickname ?? '')) {
      return;
    }

    // 빈 값이면 기본 닉네임 복원
    final nicknameToSave = nickname.isEmpty ? null : nickname;

    // 유효성 검사
    if (nicknameToSave != null) {
      final error = SettingsService.validateNickname(nicknameToSave);
      if (error != null) {
        _showSnackBar(error, isError: true);
        return;
      }
    }

    setState(() => _isSaving = true);

    final settingsService = ref.read(settingsServiceProvider);
    final result = await settingsService.updateNickname(widget.uid, nicknameToSave);

    if (mounted) {
      setState(() => _isSaving = false);
      _showSnackBar(result.message, isError: !result.success);

      if (result.success) {
        setState(() => _currentCustomNickname = nicknameToSave);
      }
    }
  }

  Future<void> _toggleSound(bool enabled) async {
    setState(() => _soundEnabled = enabled);

    final settingsService = ref.read(settingsServiceProvider);
    final result = await settingsService.updateSoundEnabled(widget.uid, enabled);

    if (mounted && !result.success) {
      // 실패 시 원래 값으로 복원
      setState(() => _soundEnabled = !enabled);
      _showSnackBar(result.message, isError: true);
    }
  }

  void _showSnackBar(String message, {bool isError = false}) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: isError ? Colors.red : Colors.green,
        duration: const Duration(seconds: 2),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: Colors.transparent,
      child: Container(
        width: 340,
        constraints: const BoxConstraints(maxHeight: 500),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              AppColors.woodDark,
              AppColors.woodDark.withValues(alpha: 0.95),
            ],
          ),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: AppColors.woodLight, width: 3),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.5),
              blurRadius: 10,
              offset: const Offset(0, 5),
            ),
          ],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // 헤더
            _buildHeader(),
            const Divider(color: AppColors.woodLight, height: 1),

            // 내용
            if (_isLoading)
              const Padding(
                padding: EdgeInsets.all(40),
                child: CircularProgressIndicator(color: AppColors.accent),
              )
            else
              Flexible(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // 닉네임 설정
                      _buildNicknameSection(),
                      const SizedBox(height: 24),

                      // 사운드 설정
                      _buildSoundSection(),
                    ],
                  ),
                ),
              ),

            // 닫기 버튼
            _buildCloseButton(),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.indigo.shade900.withValues(alpha: 0.5),
        borderRadius: const BorderRadius.vertical(top: Radius.circular(13)),
      ),
      child: Row(
        children: [
          const Icon(Icons.settings, color: AppColors.accent, size: 24),
          const SizedBox(width: 8),
          const Expanded(
            child: Text(
              '설정',
              style: TextStyle(
                color: AppColors.text,
                fontSize: 20,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
          IconButton(
            onPressed: () => Navigator.of(context).pop(),
            icon: const Icon(Icons.close, color: AppColors.textSecondary),
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(),
          ),
        ],
      ),
    );
  }

  Widget _buildNicknameSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // 섹션 제목
        Row(
          children: [
            const Icon(Icons.person, color: AppColors.accent, size: 20),
            const SizedBox(width: 8),
            const Text(
              '닉네임 설정',
              style: TextStyle(
                color: AppColors.text,
                fontSize: 16,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),

        // 안내 텍스트
        Container(
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            color: Colors.blue.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: Colors.blue.withValues(alpha: 0.3)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                '현재 구글 닉네임: ${widget.googleDisplayName}',
                style: TextStyle(
                  color: Colors.blue.shade300,
                  fontSize: 12,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                '• 한글과 숫자만 사용 가능 (10자 이내)',
                style: TextStyle(
                  color: AppColors.textSecondary,
                  fontSize: 11,
                ),
              ),
              Text(
                '• 비워두면 구글 닉네임이 사용됩니다',
                style: TextStyle(
                  color: AppColors.textSecondary,
                  fontSize: 11,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),

        // 닉네임 입력 필드
        Row(
          children: [
            Expanded(
              child: TextField(
                controller: _nicknameController,
                style: const TextStyle(color: AppColors.text),
                maxLength: SettingsService.maxNicknameLength,
                inputFormatters: [
                  // 한글 자모(ㄱ-ㅎ, ㅏ-ㅣ) + 완성형 한글(가-힣) + 숫자 허용
                  FilteringTextInputFormatter.allow(RegExp(r'[가-힣ㄱ-ㅎㅏ-ㅣ0-9]')),
                ],
                onChanged: _validateNickname,
                decoration: InputDecoration(
                  hintText: '새 닉네임 입력',
                  hintStyle: TextStyle(color: AppColors.textSecondary),
                  filled: true,
                  fillColor: Colors.black.withValues(alpha: 0.3),
                  counterStyle: TextStyle(color: AppColors.textSecondary),
                  errorText: _nicknameError,
                  errorStyle: const TextStyle(color: Colors.red, fontSize: 11),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                    borderSide: BorderSide.none,
                  ),
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 10,
                  ),
                ),
              ),
            ),
            const SizedBox(width: 8),
            ElevatedButton(
              onPressed: _isSaving || _nicknameError != null || _hasIncompleteHangul()
                  ? null
                  : _saveNickname,
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.accent,
                foregroundColor: Colors.black,
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
              child: _isSaving
                  ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.black,
                      ),
                    )
                  : const Text(
                      '저장',
                      style: TextStyle(fontWeight: FontWeight.bold),
                    ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildSoundSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // 섹션 제목
        Row(
          children: [
            Icon(
              _soundEnabled ? Icons.volume_up : Icons.volume_off,
              color: AppColors.accent,
              size: 20,
            ),
            const SizedBox(width: 8),
            const Text(
              '사운드 설정',
              style: TextStyle(
                color: AppColors.text,
                fontSize: 16,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),

        // 사운드 토글
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          decoration: BoxDecoration(
            color: Colors.black.withValues(alpha: 0.3),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      '게임 사운드',
                      style: TextStyle(
                        color: AppColors.text,
                        fontSize: 15,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      _soundEnabled ? '효과음이 재생됩니다' : '모든 사운드가 꺼집니다',
                      style: TextStyle(
                        color: AppColors.textSecondary,
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ),
              Switch(
                value: _soundEnabled,
                onChanged: _toggleSound,
                activeColor: AppColors.accent,
                activeTrackColor: AppColors.accent.withValues(alpha: 0.5),
                inactiveThumbColor: Colors.grey,
                inactiveTrackColor: Colors.grey.withValues(alpha: 0.3),
              ),
            ],
          ),
        ),

        // 안내 텍스트
        const SizedBox(height: 8),
        Container(
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            color: Colors.orange.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: Colors.orange.withValues(alpha: 0.3)),
          ),
          child: Row(
            children: [
              Icon(
                Icons.info_outline,
                color: Colors.orange.shade300,
                size: 16,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  '이 설정은 게임 플레이 화면의 사운드 옵션에도 적용됩니다.',
                  style: TextStyle(
                    color: Colors.orange.shade300,
                    fontSize: 11,
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildCloseButton() {
    return Padding(
      padding: const EdgeInsets.all(12),
      child: SizedBox(
        width: double.infinity,
        child: ElevatedButton(
          onPressed: () => Navigator.of(context).pop(),
          style: ElevatedButton.styleFrom(
            backgroundColor: AppColors.woodLight,
            foregroundColor: Colors.white,
            padding: const EdgeInsets.symmetric(vertical: 12),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(8),
            ),
          ),
          child: const Text(
            '닫기',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
      ),
    );
  }
}
