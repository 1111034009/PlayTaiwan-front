import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../api/pair_api.dart';
import '../core/app_notice.dart';
import '../core/app_colors.dart';
import '../core/app_text_styles.dart';
import 'pair_lobby_page.dart';

class PairJoinPage extends StatefulWidget {
  const PairJoinPage({super.key});

  @override
  State<PairJoinPage> createState() => _PairJoinPageState();
}

class _PairJoinPageState extends State<PairJoinPage> {
  static const Color _pageColor = AppColors.background;
  static const Color _red = AppColors.primaryAccent;
  static const Color _darkText = AppColors.textPrimary;

  final TextEditingController _controller = TextEditingController();

  bool _checking = true;
  bool _busy = false;

  Map<String, dynamic>? _playing;
  Map<String, dynamic>? _pair;

  String get _storyId => _playing?['story_id']?.toString().trim() ?? '';

  bool get _isHost => _pair?['is_host'] == true;

  @override
  void initState() {
    super.initState();
    _loadStatus();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _loadStatus() async {
    try {
      final Map<String, dynamic>? playing = await PairApi.currentPlaying();

      Map<String, dynamic>? pair;

      final String id = playing?['story_id']?.toString().trim() ?? '';

      if (id.isNotEmpty) {
        pair = await PairApi.getByStory(storyId: id);
      }

      if (!mounted) return;

      setState(() {
        _playing = id.isEmpty ? null : playing;
        _pair = pair;
        _checking = false;
      });
    } catch (_) {
      if (!mounted) return;

      setState(() {
        _checking = false;
      });
    }
  }

  Future<void> _join() async {
    if (_busy) return;

    final String code = _controller.text.trim();

    if (code.length != 4) {
      _showMessage('請輸入 4 位數配對碼');
      return;
    }

    setState(() {
      _busy = true;
    });

    try {
      final Map<String, dynamic> pair = await PairApi.join(pairCode: code);

      if (!mounted) return;

      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (_) => PairLobbyPage(pair: pair)),
      );
    } catch (e) {
      _showMessage(e.toString().replaceFirst('Exception: ', ''));

      if (mounted) {
        setState(() {
          _busy = false;
        });
      }
    }
  }

  void _continuePair() {
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(builder: (_) => PairLobbyPage(pair: _pair!)),
    );
  }

  void _continueStory() {
    Navigator.pushNamedAndRemoveUntil(context, '/home', (route) => false);
  }

  Future<void> _quit() async {
    if (_busy) return;

    final bool hasPair = _pair != null;

    final bool ok = await _confirm(
      title: hasPair ? (_isHost ? '取消隊伍？' : '退出隊伍？') : '結束劇本？',
      message: hasPair
          ? (_isHost ? '隊伍取消後配對碼失效，其他隊員的遊玩狀態會暫停。' : '退出後這份劇本的遊玩狀態會暫停。')
          : '結束後這份劇本的進度將不會保留。',
    );

    if (!ok || !mounted) return;

    setState(() {
      _busy = true;
    });

    try {
      if (hasPair) {
        if (_isHost) {
          await PairApi.cancel(storyId: _storyId);
        } else {
          await PairApi.leave(storyId: _storyId);
        }
      } else {
        await PairApi.endStory(storyId: _storyId);
      }

      if (!mounted) return;

      setState(() {
        _playing = null;
        _pair = null;
        _busy = false;
      });

      _showMessage(hasPair ? '已退出隊伍' : '已結束劇本');
    } catch (e) {
      _showMessage(e.toString().replaceFirst('Exception: ', ''));

      if (mounted) {
        setState(() {
          _busy = false;
        });
      }
    }
  }

  Future<bool> _confirm({
    required String title,
    required String message,
  }) async {
    final bool? result = await showDialog<bool>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          backgroundColor: AppColors.warmPaper,
          title: Text(
            title,
            style: AppTextStyles.title.copyWith(color: _darkText),
          ),
          content: Text(
            message,
            style: AppTextStyles.bodySmallBold.copyWith(
              color: AppColors.darkBrown,
              height: 1.5,
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext, false),
              child: Text(
                '再想想',
                style: AppTextStyles.bodyBold.copyWith(
                  color: AppColors.darkBrown,
                ),
              ),
            ),
            TextButton(
              onPressed: () => Navigator.pop(dialogContext, true),
              child: Text(
                '確定',
                style: AppTextStyles.bodyBold.copyWith(color: _red),
              ),
            ),
          ],
        );
      },
    );

    return result == true;
  }

  void _showMessage(String message) {
    if (!mounted) return;

    AppNotice.show(message);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _pageColor,
      body: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(8, 10, 20, 6),
              child: Row(
                children: [
                  IconButton(
                    onPressed: _busy ? null : () => Navigator.of(context).pop(),
                    icon: const Icon(
                      Icons.arrow_back_ios_new_rounded,
                      color: _darkText,
                      size: 20,
                    ),
                  ),
                  Expanded(
                    child: Text(
                      '夥伴配對',
                      style: AppTextStyles.titleLarge.copyWith(
                        color: _darkText,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            Expanded(
              child: _checking
                  ? const Center(child: CircularProgressIndicator(color: _red))
                  : SingleChildScrollView(
                      padding: const EdgeInsets.fromLTRB(18, 20, 18, 18),
                      child: _playing == null
                          ? _buildPaper(_buildJoinForm())
                          : _buildPaper(_buildPlaying()),
                    ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPaper(Widget child) {
    return Stack(
      children: [
        Positioned.fill(
          child: Image.asset('img/set_papper.png', fit: BoxFit.fill),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(26, 28, 26, 28),
          child: child,
        ),
      ],
    );
  }

  Widget _buildPlaying() {
    final bool hasPair = _pair != null;

    final String title = _playing?['title']?.toString().trim() ?? '';

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Icon(
          hasPair ? Icons.groups_rounded : Icons.menu_book_rounded,
          size: 40,
          color: _red,
        ),
        const SizedBox(height: 10),
        Text(
          hasPair ? '已與夥伴配對劇本' : '你有進行中的劇本',
          textAlign: TextAlign.center,
          style: AppTextStyles.title.copyWith(color: _darkText),
        ),
        const SizedBox(height: 8),
        Text(
          title,
          textAlign: TextAlign.center,
          style: AppTextStyles.bodyBold.copyWith(color: _red),
        ),
        if (hasPair) ...[
          const SizedBox(height: 6),
          Text(
            '隊員 ${_pair!['member_count']}/${_pair!['party_size']}',
            textAlign: TextAlign.center,
            style: AppTextStyles.captionBold.copyWith(
              color: AppColors.darkBrown,
            ),
          ),
        ],
        const SizedBox(height: 26),
        Row(
          children: [
            Expanded(
              child: _buildButton(
                text: hasPair && _isHost ? '取消隊伍' : '退出',
                primary: false,
                onTap: _busy ? null : _quit,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _buildButton(
                text: '繼續',
                primary: true,
                onTap: _busy
                    ? null
                    : (hasPair ? _continuePair : _continueStory),
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildJoinForm() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          '輸入配對碼',
          textAlign: TextAlign.center,
          style: AppTextStyles.title.copyWith(color: _darkText),
        ),
        const SizedBox(height: 8),
        Text(
          '請輸入隊長提供的 4 位數配對碼',
          textAlign: TextAlign.center,
          style: AppTextStyles.bodySmallBold.copyWith(
            color: AppColors.mutedText,
          ),
        ),
        const SizedBox(height: 22),
        TextField(
          controller: _controller,
          keyboardType: TextInputType.number,
          textAlign: TextAlign.center,
          inputFormatters: [
            FilteringTextInputFormatter.digitsOnly,
            LengthLimitingTextInputFormatter(4),
          ],
          cursorColor: _red,
          style: AppTextStyles.displayMedium.copyWith(
            color: _red,
            letterSpacing: 10,
          ),
          decoration: const InputDecoration(
            hintText: '0000',
            enabledBorder: UnderlineInputBorder(
              borderSide: BorderSide(color: Color(0xFF514A44)),
            ),
            focusedBorder: UnderlineInputBorder(
              borderSide: BorderSide(color: _red, width: 1.5),
            ),
          ),
        ),
        const SizedBox(height: 28),
        _buildButton(
          text: '加入隊伍',
          primary: true,
          loading: _busy,
          onTap: _busy ? null : _join,
        ),
      ],
    );
  }

  Widget _buildButton({
    required String text,
    required bool primary,
    bool loading = false,
    VoidCallback? onTap,
  }) {
    return Opacity(
      opacity: onTap == null && !loading ? 0.5 : 1,
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          height: 46,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(24),
            border: Border.all(color: AppColors.primaryDark, width: 2),
            color: primary ? null : AppColors.warmPaper,
            gradient: primary
                ? const LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [AppColors.primaryLight, AppColors.primary],
                  )
                : null,
          ),
          child: loading
              ? const SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: Colors.white,
                  ),
                )
              : Text(
                  text,
                  style: AppTextStyles.bodyEmphasisBold.copyWith(
                    color: primary ? Colors.white : AppColors.primaryDark,
                  ),
                ),
        ),
      ),
    );
  }
}
