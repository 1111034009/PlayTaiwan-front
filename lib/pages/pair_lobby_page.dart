import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../api/pair_api.dart';
import '../api/story_api.dart';
import '../core/app_colors.dart';
import '../core/app_notice.dart';
import '../core/app_text_styles.dart';
import 'story_play_page.dart';

class PairLobbyPage extends StatefulWidget {
  final Map<String, dynamic> pair;
  final Map<String, dynamic>? story;

  const PairLobbyPage({super.key, required this.pair, this.story});

  @override
  State<PairLobbyPage> createState() => _PairLobbyPageState();
}

class _PairLobbyPageState extends State<PairLobbyPage> {
  static const Color _pageColor = AppColors.background;
  static const Color _red = AppColors.primaryAccent;
  static const Color _darkText = AppColors.textPrimary;
  static const Color _darkBrown = AppColors.darkBrown;
  static const bool _requireFull = true;
  late Map<String, dynamic> _pair;

  Timer? _pollTimer;
  Timer? _tickTimer;

  int _secondsLeft = 0;
  bool _busy = false;
  bool _gone = false;

  int _int(dynamic value) => int.tryParse(value?.toString() ?? '') ?? 0;

  String _text(dynamic value) => value?.toString().trim() ?? '';

  String get _storyId => _text(_pair['story_id']);

  bool get _isHost => _pair['is_host'] == true;

  List<Map<String, dynamic>> get _members {
    final dynamic raw = _pair['members'];

    if (raw is! List) return [];

    return raw
        .whereType<Map>()
        .map((member) => Map<String, dynamic>.from(member))
        .toList();
  }

  int get _memberCount {
    final int count = _int(_pair['member_count']);

    return count > 0 ? count : _members.length;
  }

  int get _partySize {
    final int size = _int(_pair['party_size']);

    return size > 0 ? size : _memberCount;
  }

  bool get _isFull => _memberCount >= _partySize;

  bool get _isClosed => _gone || _text(_pair['pair_status']) == 'cancelled';

  bool get _isExpired => !_isFull && _secondsLeft <= 0;

  String get _statusText {
    if (_isClosed) return '隊伍已不存在';
    if (_isFull) return '隊伍已集滿，可以出發了';
    if (_isExpired) return '配對碼已過期';

    final String minutes = (_secondsLeft ~/ 60).toString().padLeft(2, '0');
    final String seconds = (_secondsLeft % 60).toString().padLeft(2, '0');

    return '配對碼剩餘 $minutes:$seconds';
  }

  @override
  void initState() {
    super.initState();

    _pair = widget.pair;
    _secondsLeft = _int(_pair['expires_in_seconds']);

    _tickTimer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (!mounted || _secondsLeft <= 0) return;

      setState(() {
        _secondsLeft--;
      });
    });

    _pollTimer = Timer.periodic(const Duration(seconds: 3), (_) => _poll());
  }

  @override
  void dispose() {
    _pollTimer?.cancel();
    _tickTimer?.cancel();
    super.dispose();
  }

  void _applyPair(Map<String, dynamic> pair) {
    _pair = pair;
    _secondsLeft = _int(pair['expires_in_seconds']);
    _gone = false;
  }

  Future<void> _poll() async {
    if (_busy) return;

    try {
      final Map<String, dynamic>? pair = await PairApi.getByStory(
        storyId: _storyId,
      );

      if (!mounted) return;

      setState(() {
        if (pair == null) {
          _gone = true;
        } else {
          _applyPair(pair);
        }
      });
    } catch (_) {}
  }

  Future<void> _regenerate() async {
    if (_busy) return;

    setState(() {
      _busy = true;
    });

    try {
      final Map<String, dynamic> pair = await PairApi.createCode(
        storyId: _storyId,
      );

      if (!mounted) return;

      setState(() {
        _applyPair(pair);
      });
    } catch (e) {
      _showMessage(e.toString().replaceFirst('Exception: ', ''));
    } finally {
      if (mounted) {
        setState(() {
          _busy = false;
        });
      }
    }
  }

  Future<void> _start() async {
    if (_busy) return;

    if (!_isFull) {
      if (_requireFull) {
        _showMessage('隊友尚未全數加入，請等待配對完成');
        return;
      }

      if (_isHost) {
        final bool ok = await _confirm(
          title: '隊伍尚未集滿',
          message: '目前 $_memberCount/$_partySize 人，未到的隊友需要用配對碼後續加入。確定要先出發嗎？',
          confirmText: '先出發',
        );

        if (!ok) return;
      }
    }

    await _enterStory();
  }

  Future<void> _enterStory() async {
    setState(() {
      _busy = true;
    });

    try {
      Map<String, dynamic>? story = widget.story;

      if (story == null) {
        final Map<String, dynamic> detail = await StoryApi.getStoryDetail(
          storyId: _storyId,
        );

        story = {'story_id': _storyId, 'data': detail};
      }

      if (!mounted) return;

      final Map<String, dynamic> storyForPage = story;

      Navigator.pushReplacement(
        context,
        MaterialPageRoute(
          builder: (_) => StoryPage(generatedScript: storyForPage),
        ),
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

  Future<void> _onBack() async {
    if (_busy) return;

    if (_isClosed) {
      Navigator.of(context).pop();
      return;
    }

    final bool ok = await _confirm(
      title: _isHost ? '取消隊伍？' : '退出隊伍？',
      message: _isHost
          ? '隊伍取消後配對碼失效，其他隊員的遊玩狀態會暫停。'
          : '退出後這份劇本的遊玩狀態會暫停，可以再用配對碼加入。',
      confirmText: _isHost ? '取消隊伍' : '退出隊伍',
    );

    if (!ok || !mounted) return;

    setState(() {
      _busy = true;
    });

    try {
      if (_isHost) {
        await PairApi.cancel(storyId: _storyId);
      } else {
        await PairApi.leave(storyId: _storyId);
      }

      if (!mounted) return;

      Navigator.of(context).pop();
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
    required String confirmText,
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
              color: _darkBrown,
              height: 1.5,
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext, false),
              child: Text(
                '再想想',
                style: AppTextStyles.bodyBold.copyWith(color: _darkBrown),
              ),
            ),
            TextButton(
              onPressed: () => Navigator.pop(dialogContext, true),
              child: Text(
                confirmText,
                style: AppTextStyles.bodyBold.copyWith(color: _red),
              ),
            ),
          ],
        );
      },
    );

    return result == true;
  }

  void _copyCode() {
    Clipboard.setData(ClipboardData(text: _text(_pair['pair_code'])));

    _showMessage('已複製配對碼');
  }

  void _showMessage(String message) {
    if (!mounted) return;

    AppNotice.show(message);
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, result) {
        if (!didPop) _onBack();
      },
      child: Scaffold(
        backgroundColor: _pageColor,
        body: SafeArea(
          child: Column(
            children: [
              _buildTopBar(),
              Expanded(
                child: SingleChildScrollView(
                  physics: const BouncingScrollPhysics(),
                  padding: const EdgeInsets.fromLTRB(18, 10, 18, 18),
                  child: _buildCard(),
                ),
              ),
              _buildActions(),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildTopBar() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(8, 10, 20, 6),
      child: Row(
        children: [
          IconButton(
            onPressed: _onBack,
            icon: const Icon(
              Icons.arrow_back_ios_new_rounded,
              color: _darkText,
              size: 20,
            ),
          ),
          Expanded(
            child: Text(
              '組隊大廳',
              style: AppTextStyles.titleLarge.copyWith(color: _darkText),
            ),
          ),
          const Icon(Icons.groups_rounded, color: _red, size: 26),
        ],
      ),
    );
  }

  Widget _buildCard() {
    final bool dimCode = _isExpired || _isClosed;

    return Stack(
      children: [
        Positioned.fill(
          child: Image.asset('img/set_papper.png', fit: BoxFit.fill),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(24, 24, 24, 24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                _text(_pair['story_title']),
                textAlign: TextAlign.center,
                style: AppTextStyles.title.copyWith(color: _darkText),
              ),
              const SizedBox(height: 18),
              Text(
                '配對碼',
                textAlign: TextAlign.center,
                style: AppTextStyles.bodySmallBold.copyWith(color: _darkBrown),
              ),
              const SizedBox(height: 4),
              GestureDetector(
                onTap: _copyCode,
                child: Text(
                  _text(_pair['pair_code']),
                  textAlign: TextAlign.center,
                  style: AppTextStyles.displayMedium.copyWith(
                    color: dimCode ? AppColors.mutedText : _red,
                    letterSpacing: 8,
                  ),
                ),
              ),
              const SizedBox(height: 4),
              Text(
                _statusText,
                textAlign: TextAlign.center,
                style: AppTextStyles.captionBold.copyWith(color: _darkBrown),
              ),
              const SizedBox(height: 18),
              Container(height: 1, color: const Color(0xFF514A44)),
              const SizedBox(height: 14),
              Text(
                '隊員 $_memberCount/$_partySize',
                style: AppTextStyles.bodyBold.copyWith(color: _darkText),
              ),
              const SizedBox(height: 10),
              for (int seat = 1; seat <= _partySize; seat++) _buildSeat(seat),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildSeat(int seat) {
    Map<String, dynamic>? member;

    for (final Map<String, dynamic> item in _members) {
      if (_int(item['seat_no']) == seat) {
        member = item;
        break;
      }
    }

    final bool filled = member != null;
    final bool isMe = seat == _int(_pair['my_seat_no']);
    final bool isHostSeat = member?['is_host'] == true;

    final String name = filled
        ? '${_text(member['auth_name'])}${isMe ? '（我）' : ''}'
        : '等待加入…';

    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        children: [
          Container(
            width: 30,
            height: 30,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: filled ? _red : Colors.transparent,
              border: Border.all(
                color: filled ? AppColors.primaryDark : AppColors.mutedText,
                width: 1.5,
              ),
            ),
            child: Text(
              '$seat',
              style: AppTextStyles.captionBold.copyWith(
                color: filled ? Colors.white : AppColors.mutedText,
              ),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              name,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: AppTextStyles.bodySmallBold.copyWith(
                color: filled ? _darkText : AppColors.mutedText,
              ),
            ),
          ),
          if (isHostSeat)
            Text('隊長', style: AppTextStyles.captionBold.copyWith(color: _red)),
        ],
      ),
    );
  }

  Widget _buildActions() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(18, 0, 18, 18),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (_isHost && (_isExpired || _isClosed)) ...[
            _ActionButton(
              text: '重新產生配對碼',
              primary: false,
              onTap: _busy ? null : _regenerate,
            ),
            const SizedBox(height: 10),
          ],
          Row(
            children: [
              Expanded(
                child: _ActionButton(
                  text: _isHost ? '取消隊伍' : '退出隊伍',
                  primary: false,
                  onTap: _busy ? null : _onBack,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _ActionButton(
                  text: (_requireFull && !_isFull)
                      ? '等待隊友 $_memberCount/$_partySize'
                      : (_isHost ? '出發' : '進入劇情'),
                  primary: true,
                  loading: _busy,
                  onTap: (_busy || _isClosed || (_requireFull && !_isFull))
                      ? null
                      : _start,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _ActionButton extends StatelessWidget {
  final String text;
  final bool primary;
  final bool loading;
  final VoidCallback? onTap;

  const _ActionButton({
    required this.text,
    required this.primary,
    this.loading = false,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
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
            gradient: primary
                ? const LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [AppColors.primaryLight, AppColors.primary],
                  )
                : null,
            color: primary ? null : AppColors.warmPaper,
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
