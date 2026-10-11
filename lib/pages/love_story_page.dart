import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:url_launcher/url_launcher.dart';

import '../api/story_api.dart';
import '../core/app_colors.dart';
import '../core/app_text_styles.dart';
import 'script_detail_page.dart';

class LoveStoryPage extends StatefulWidget {
  const LoveStoryPage({super.key});

  @override
  State<LoveStoryPage> createState() => _LoveStoryPageState();
}

class _LoveStoryPageState extends State<LoveStoryPage> {
  static const Color _pageColor = AppColors.background;
  static const Color _red = AppColors.primaryAccent;
  static const Color _darkText = AppColors.textPrimary;
  static const Color _darkBrown = AppColors.darkBrown;
  static const Color _paperColor = Color(0xFFCBB57C);

  List<Map<String, dynamic>> _stories = [];
  final Set<String> _busyIds = {};

  bool _isLoading = true;
  bool _isWritingCalendar = false;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();

    SystemChrome.setSystemUIOverlayStyle(
      const SystemUiOverlayStyle(
        statusBarColor: _pageColor,
        statusBarIconBrightness: Brightness.dark,
        statusBarBrightness: Brightness.light,
        systemNavigationBarColor: _pageColor,
        systemNavigationBarIconBrightness: Brightness.dark,
      ),
    );

    _loadStories();
  }

  String _text(dynamic value) => value?.toString().trim() ?? '';

  String _errorText(Object error) {
    return error.toString().replaceFirst('Exception: ', '');
  }

  Future<void> _loadStories({bool showLoading = true}) async {
    if (showLoading) {
      setState(() {
        _isLoading = true;
        _errorMessage = null;
      });
    }

    try {
      final List<Map<String, dynamic>> stories =
          await StoryApi.getFavoriteStories();

      if (!mounted) return;

      setState(() {
        _stories = stories;
        _errorMessage = null;
        _isLoading = false;
      });
    } catch (e) {
      if (!mounted) return;

      setState(() {
        if (showLoading) _errorMessage = _errorText(e);
        _isLoading = false;
      });
    }
  }

  Future<void> _removeFavorite(Map<String, dynamic> story) async {
    final String id = _text(story['story_id']);

    if (id.isEmpty || _busyIds.contains(id)) return;

    setState(() {
      _busyIds.add(id);
    });

    try {
      await StoryApi.setFavorite(storyId: id, isFavorite: false);

      if (!mounted) return;

      setState(() {
        _stories.remove(story);
      });

      _showMessage('已取消喜愛');
    } catch (e) {
      _showMessage(_errorText(e));
    } finally {
      if (mounted) {
        setState(() {
          _busyIds.remove(id);
        });
      }
    }
  }

  Future<void> _addToCalendar(Map<String, dynamic> story) async {
    if (_isWritingCalendar) return;

    setState(() {
      _isWritingCalendar = true;
    });

    try {
      final String url = await StoryApi.createCalendarLink(
        storyId: _text(story['story_id']),
      );

      final bool opened = await launchUrl(
        Uri.parse(url),
        mode: LaunchMode.externalApplication,
      );

      if (!opened) throw Exception('無法開啟行事曆連結');
    } catch (e) {
      _showMessage(_errorText(e));
    } finally {
      if (mounted) {
        setState(() {
          _isWritingCalendar = false;
        });
      }
    }
  }

  Future<void> _openDetail(Map<String, dynamic> story) async {
    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => ScriptDetailPage(
          title: _text(story['title']),
          storyId: _text(story['story_id']),
        ),
      ),
    );

    if (!mounted) return;

    _loadStories(showLoading: false);
  }

  void _showMessage(String message) {
    if (!mounted) return;

    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: Text(
            message,
            textAlign: TextAlign.center,
            style: AppTextStyles.bodySmallBold.copyWith(color: Colors.white),
          ),
          backgroundColor: _red,
          behavior: SnackBarBehavior.floating,
          duration: const Duration(seconds: 2),
        ),
      );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _pageColor,
      body: SafeArea(
        child: Stack(
          children: [
            Column(
              children: [
                _buildHeader(),
                Expanded(child: _buildBody()),
              ],
            ),
            if (_isWritingCalendar) _buildCalendarOverlay(),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(8, 10, 20, 6),
      child: Row(
        children: [
          IconButton(
            onPressed: () => Navigator.of(context).pop(),
            icon: const Icon(
              Icons.arrow_back_ios_new_rounded,
              color: _darkText,
              size: 20,
            ),
          ),
          Expanded(
            child: Text(
              '我的喜愛劇本',
              style: AppTextStyles.titleLarge.copyWith(color: _darkText),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBody() {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator(color: _red));
    }

    if (_errorMessage != null) {
      return _buildMessageView(
        icon: Icons.error_outline_rounded,
        message: _errorMessage!,
        actionText: '重新載入',
        onAction: _loadStories,
      );
    }

    if (_stories.isEmpty) {
      return _buildMessageView(
        icon: Icons.favorite_border_rounded,
        message: '還沒有收藏的劇本\n在劇本詳情點擊愛心就能收藏',
      );
    }

    return RefreshIndicator(
      color: _red,
      onRefresh: () => _loadStories(showLoading: false),
      child: ListView.separated(
        physics: const AlwaysScrollableScrollPhysics(
          parent: BouncingScrollPhysics(),
        ),
        padding: const EdgeInsets.fromLTRB(18, 10, 18, 28),
        itemCount: _stories.length,
        separatorBuilder: (_, _) => const SizedBox(height: 18),
        itemBuilder: (context, index) => _buildStoryCard(_stories[index]),
      ),
    );
  }

  Widget _buildMessageView({
    required IconData icon,
    required String message,
    String? actionText,
    VoidCallback? onAction,
  }) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 40),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 46, color: _darkBrown.withValues(alpha: 0.6)),
            const SizedBox(height: 12),
            Text(
              message,
              textAlign: TextAlign.center,
              style: AppTextStyles.bodySmallBold.copyWith(
                color: AppColors.mutedText,
                height: 1.6,
              ),
            ),
            if (actionText != null) ...[
              const SizedBox(height: 16),
              TextButton(
                onPressed: onAction,
                child: Text(
                  actionText,
                  style: AppTextStyles.bodyBold.copyWith(color: _red),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildStoryCard(Map<String, dynamic> story) {
    final String id = _text(story['story_id']);
    final String location = [
      _text(story['city_name']),
      _text(story['district_name']),
    ].where((value) => value.isNotEmpty).join(' ');

    return Container(
      decoration: BoxDecoration(
        color: _paperColor,
        borderRadius: BorderRadius.circular(7),
        border: Border.all(color: AppColors.postcardLine),
        boxShadow: const [
          BoxShadow(
            color: Color(0x45000000),
            blurRadius: 6,
            offset: Offset(2, 3),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: () => _openDetail(story),
          borderRadius: BorderRadius.circular(7),
          child: Padding(
            padding: const EdgeInsets.all(8),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildCover(story, id),
                const SizedBox(height: 10),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 4),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        _text(story['title']),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: AppTextStyles.title.copyWith(color: _darkText),
                      ),
                      if (location.isNotEmpty) ...[
                        const SizedBox(height: 4),
                        Row(
                          children: [
                            const Icon(
                              Icons.location_on_rounded,
                              size: 14,
                              color: _red,
                            ),
                            const SizedBox(width: 3),
                            Text(
                              '$location・共 ${_text(story['node_count'])} 站',
                              style: AppTextStyles.captionBold.copyWith(
                                color: _darkBrown,
                              ),
                            ),
                          ],
                        ),
                      ],
                      const SizedBox(height: 6),
                      Text(
                        _text(story['synopsis']),
                        maxLines: 3,
                        overflow: TextOverflow.ellipsis,
                        style: AppTextStyles.caption.copyWith(
                          color: _darkText,
                          height: 1.5,
                        ),
                      ),
                      const SizedBox(height: 10),
                      Align(
                        alignment: Alignment.centerRight,
                        child: _buildCalendarButton(story),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildCover(Map<String, dynamic> story, String id) {
    final String coverUrl = _text(story['cover_image_url']);
    final bool isNight = story['is_night_mode'] == true;
    final bool isCompleted = story['is_completed'] == true;
    final bool isBusy = _busyIds.contains(id);

    return ClipRRect(
      borderRadius: BorderRadius.circular(3),
      child: AspectRatio(
        aspectRatio: 16 / 9,
        child: Stack(
          fit: StackFit.expand,
          children: [
            coverUrl.isEmpty
                ? _buildCoverFallback()
                : Image.network(
                    coverUrl,
                    fit: BoxFit.cover,
                    errorBuilder: (context, error, stackTrace) =>
                        _buildCoverFallback(),
                  ),
            Positioned(
              left: 8,
              bottom: 8,
              child: Row(
                children: [
                  _buildChip(
                    isNight ? Icons.nightlight_round : Icons.wb_sunny_rounded,
                    isNight ? '夜間劇本' : '日間劇本',
                  ),
                  if (isCompleted) ...[
                    const SizedBox(width: 6),
                    _buildChip(Icons.verified_rounded, '已完成'),
                  ],
                ],
              ),
            ),
            Positioned(
              right: 8,
              top: 8,
              child: GestureDetector(
                onTap: isBusy ? null : () => _removeFavorite(story),
                child: Container(
                  width: 34,
                  height: 34,
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.9),
                    shape: BoxShape.circle,
                  ),
                  child: isBusy
                      ? const Padding(
                          padding: EdgeInsets.all(8),
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: _red,
                          ),
                        )
                      : const Icon(
                          Icons.favorite_rounded,
                          color: _red,
                          size: 20,
                        ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCoverFallback() {
    return Container(
      color: AppColors.questionBackground,
      alignment: Alignment.center,
      child: const Icon(
        Icons.image_not_supported_outlined,
        color: _darkBrown,
        size: 34,
      ),
    );
  }

  Widget _buildChip(IconData icon, String label) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.55),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 12, color: AppColors.paper),
          const SizedBox(width: 4),
          Text(
            label,
            style: AppTextStyles.microBold.copyWith(color: AppColors.paper),
          ),
        ],
      ),
    );
  }

  Widget _buildCalendarButton(Map<String, dynamic> story) {
    return GestureDetector(
      onTap: () => _addToCalendar(story),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: AppColors.primaryDark, width: 1.5),
          gradient: const LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [AppColors.primaryLight, AppColors.primary],
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(
              Icons.event_available_rounded,
              size: 16,
              color: Colors.white,
            ),
            const SizedBox(width: 5),
            Text(
              '加入行事曆',
              style: AppTextStyles.captionBold.copyWith(color: Colors.white),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCalendarOverlay() {
    return Positioned.fill(
      child: AbsorbPointer(
        child: ColoredBox(
          color: Colors.black.withValues(alpha: 0.6),
          child: Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const CircularProgressIndicator(color: AppColors.paper),
                const SizedBox(height: 16),
                Text(
                  '正在書寫行事曆……',
                  style: AppTextStyles.bodyBold.copyWith(
                    color: AppColors.paper,
                    letterSpacing: 1.2,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
