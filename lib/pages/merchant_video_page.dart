import 'dart:convert';
import 'dart:io';
import 'package:crypto/crypto.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:gal/gal.dart';
import 'package:http/http.dart' as http;
import 'package:share_plus/share_plus.dart';
import 'package:video_player/video_player.dart';

import 'merchant_home_page.dart';
import 'merchant_input_page.dart';
import '../api/merchant_vlog_api.dart';
import '../core/app_notice.dart';
import '../core/app_colors.dart';
import '../core/app_session.dart';
import '../core/app_text_styles.dart';

const Color _backgroundColor = Color(0xFFC4ADA0);
const Color _cardColor = AppColors.merchantPaper;
const Color _darkRed = AppColors.primaryAccent;
const Color _textColor = Color(0xFF17110F);
const Color _lightText = AppColors.merchantPaper;
const Color _buttonText = AppColors.paper;
const Color _buttonInner = Color(0xFF724E4E);
const Color _buttonOuter = AppColors.textPrimary;
const Color _black = Colors.black;

enum _ShareChoice { copyAndShare, shareOnly }

class MerchantVideoPage extends StatefulWidget {
  final dynamic mmId;

  const MerchantVideoPage({super.key, required this.mmId});

  @override
  State<MerchantVideoPage> createState() => _MerchantVideoPageState();
}

class _MerchantVideoPageState extends State<MerchantVideoPage> {
  final String _apiBaseUrl =
      (dotenv.env['API_BASE_URL'] ?? 'https://backend.angelalala.com')
          .trim()
          .replaceFirst(RegExp(r'/$'), '');

  bool _isLoading = true;
  String? _error;
  _VlogDetail? _detail;

  File? _videoFile;
  bool _isPreparingVideo = false;
  bool _isSavingVideo = false;
  String? _videoError;

  @override
  void initState() {
    super.initState();
    _fetchDetail();
  }

  Future<void> _fetchDetail() async {
    if (!mounted) return;

    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      final token = AppSession.token;

      if (token == null || token.isEmpty) {
        throw Exception('登入狀態已失效，請重新登入');
      }

      final uri = Uri.parse(
        '$_apiBaseUrl/api/MerchantVlog/Status/${widget.mmId}',
      );

      final response = await http
          .get(
            uri,
            headers: {'accept': 'text/plain', 'Authorization': 'Bearer $token'},
          )
          .timeout(const Duration(seconds: 15));

      if (response.statusCode < 200 || response.statusCode >= 300) {
        throw Exception('取得內容失敗（HTTP ${response.statusCode}）');
      }

      final dynamic decoded = jsonDecode(utf8.decode(response.bodyBytes));

      if (decoded is! Map<String, dynamic>) {
        throw Exception('伺服器回傳格式錯誤');
      }

      if (decoded['isSuccess'] != true) {
        throw Exception(decoded['message']?.toString() ?? '查詢內容失敗');
      }

      final dynamic result = decoded['Result'];

      if (result is! Map) {
        throw Exception('內容資料格式錯誤');
      }

      final detail = _VlogDetail.fromJson(Map<String, dynamic>.from(result));

      if (!mounted) return;

      setState(() {
        _detail = detail;
        _isLoading = false;
        _error = null;
      });

      if (detail.isCompleted && detail.videoUrl.isNotEmpty) {
        _prepareVideo(detail);
      }
    } catch (e) {
      if (!mounted) return;

      setState(() {
        _isLoading = false;
        _error = e.toString().replaceFirst('Exception: ', '');
      });
    }
  }

  Future<void> _prepareVideo(_VlogDetail detail) async {
    if (_isPreparingVideo) return;

    final videoUrl = detail.videoUrl.trim();

    if (videoUrl.isEmpty) {
      if (!mounted) return;

      setState(() {
        _videoFile = null;
        _videoError = '沒有影片下載網址';
      });
      return;
    }

    setState(() {
      _isPreparingVideo = true;
      _videoError = null;
    });

    final client = http.Client();

    try {
      final uri = Uri.parse(videoUrl);

      if (uri.scheme != 'https' && uri.scheme != 'http') {
        throw Exception('影片網址格式錯誤');
      }

      // 使用影片網址產生唯一檔名。
      // URL 改變時，檔名也會改變，不會誤用舊影片。
      final urlHash = sha256.convert(utf8.encode(videoUrl));
      final tempDir = Directory.systemTemp;

      final file = File(
        '${tempDir.path}/merchant_vlog_${widget.mmId}_$urlHash.mp4',
      );

      final partialFile = File('${file.path}.part');

      // 同一網址已經下載完成的影片可以重複使用。
      if (await file.exists() && await file.length() > 0) {
        if (!mounted) return;

        setState(() {
          _videoFile = file;
          _videoError = null;
        });
        return;
      }

      // 清除上次下載失敗留下的暫存片段。
      if (await partialFile.exists()) {
        await partialFile.delete();
      }

      final request = http.Request('GET', uri);
      final response = await client
          .send(request)
          .timeout(const Duration(minutes: 2));

      if (response.statusCode < 200 || response.statusCode >= 300) {
        throw Exception('影片下載失敗（HTTP ${response.statusCode}）');
      }

      final sink = partialFile.openWrite();
      var receivedBytes = 0;

      try {
        await for (final chunk in response.stream) {
          sink.add(chunk);
          receivedBytes += chunk.length;
        }

        await sink.flush();
      } finally {
        await sink.close();
      }

      if (receivedBytes == 0) {
        throw Exception('影片內容為空');
      }

      // 下載成功後才改成正式檔名。
      await partialFile.rename(file.path);

      if (!mounted) return;

      setState(() {
        _videoFile = file;
        _videoError = null;
      });
    } catch (e) {
      debugPrint('準備影片失敗：$e');

      if (!mounted) return;

      setState(() {
        _videoFile = null;
        _videoError = '影片載入失敗，點擊重試';
      });
    } finally {
      client.close();

      if (mounted) {
        setState(() {
          _isPreparingVideo = false;
        });
      }
    }
  }

  void _openFullScreen() {
    final file = _videoFile;

    if (file == null) {
      _showMessage('影片尚未準備完成');
      return;
    }

    Navigator.of(context).push(
      PageRouteBuilder<void>(
        opaque: true,
        transitionDuration: const Duration(milliseconds: 250),
        reverseTransitionDuration: const Duration(milliseconds: 200),
        pageBuilder: (_, __, ___) =>
            _FullScreenVideoPage(file: file, onDownload: _saveVideoToGallery),
        transitionsBuilder: (_, animation, __, child) {
          return FadeTransition(opacity: animation, child: child);
        },
      ),
    );
  }

  Future<void> _saveVideoToGallery() async {
    if (_isSavingVideo) return;

    if (_isPreparingVideo) {
      _showMessage('影片正在準備中，請稍候');
      return;
    }

    final file = _videoFile;

    if (file == null || !await file.exists()) {
      _showMessage('影片尚未準備完成');
      return;
    }

    if (mounted) {
      setState(() {
        _isSavingVideo = true;
      });
    }

    try {
      bool hasAccess = await Gal.hasAccess();

      if (!hasAccess) {
        hasAccess = await Gal.requestAccess();
      }

      if (!hasAccess) {
        _showMessage('沒有相簿權限，無法儲存影片');
        return;
      }

      await Gal.putVideo(file.path, album: 'PlayTaiwan');

      _showMessage('影片已儲存到手機相簿');
    } on GalException catch (e) {
      _showMessage('儲存失敗：${e.type.message}');
    } catch (e) {
      debugPrint('儲存影片失敗：$e');
      _showMessage('儲存影片失敗');
    } finally {
      if (mounted) {
        setState(() {
          _isSavingVideo = false;
        });
      }
    }
  }

  Future<void> _openEdit() async {
    final mmId = int.tryParse(widget.mmId.toString());

    if (mmId == null) {
      _showMessage('此檔案缺少編號，無法編輯');
      return;
    }

    await Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => MerchantInputPage(initialMmId: mmId)),
    );
  }

  void _goHome(BuildContext context) {
    Navigator.pushAndRemoveUntil(
      context,
      MaterialPageRoute(builder: (_) => const MerchantHomePage()),
      (route) => false,
    );
  }

  void _showMessage(String message) {
    if (!mounted) return;

    AppNotice.show(message);
  }

  Future<void> _copy(String text, String successMessage) async {
    if (text.trim().isEmpty) {
      _showMessage('沒有可複製的內容');
      return;
    }

    await Clipboard.setData(ClipboardData(text: text));

    _showMessage(successMessage);
  }

  Future<void> _shareToSocial() async {
    final detail = _detail;

    if (detail == null) return;

    final text = <String>[
      if (detail.caption.isNotEmpty) detail.caption,
      if (detail.hashtags.isNotEmpty) detail.hashtags.join(' '),
    ].join('\n\n');

    if (text.isNotEmpty) {
      final choice = await showDialog<_ShareChoice>(
        context: context,
        barrierColor: const Color.fromARGB(199, 0, 0, 0),
        builder: (_) => const _ShareNoticeDialog(),
      );

      if (choice == null || !mounted) return;

      if (choice == _ShareChoice.copyAndShare) {
        await Clipboard.setData(ClipboardData(text: text));
        _showMessage('已複製配文與標籤');
      }
    }

    try {
      final file = _videoFile;

      if (file != null && await file.exists()) {
        await Share.shareXFiles(
          [XFile(file.path, mimeType: 'video/mp4')],
          text: text.isEmpty ? null : text,
          subject: detail.title,
        );
        return;
      }

      final fallback = <String>[
        if (text.isNotEmpty) text,
        if (detail.videoUrl.isNotEmpty) detail.videoUrl,
      ].join('\n\n');

      if (fallback.isEmpty) {
        _showMessage('沒有可分享的內容');
        return;
      }

      await Share.share(fallback, subject: detail.title);
    } catch (e) {
      debugPrint('分享失敗：$e');
      _showMessage('分享失敗，請稍後再試');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _backgroundColor,
      body: SafeArea(
        child: LayoutBuilder(
          builder: (context, constraints) {
            return SingleChildScrollView(
              physics: const BouncingScrollPhysics(),
              padding: const EdgeInsets.fromLTRB(16, 10, 16, 32),
              child: ConstrainedBox(
                constraints: BoxConstraints(
                  minHeight: constraints.maxHeight - 42,
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Align(
                      alignment: Alignment.centerLeft,
                      child: GestureDetector(
                        behavior: HitTestBehavior.opaque,
                        onTap: () => _goHome(context),
                        child: Padding(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 7,
                            vertical: 5,
                          ),
                          child: Text(
                            '<< 返回',
                            style: AppTextStyles.bodySmallBold
                                .copyWith(color: _lightText)
                                .copyWith(
                                  shadows: const [
                                    Shadow(
                                      color: Color(0x55000000),
                                      offset: Offset(1, 1),
                                      blurRadius: 3,
                                    ),
                                  ],
                                ),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 10),
                    _buildBody(),
                  ],
                ),
              ),
            );
          },
        ),
      ),
    );
  }

  Widget _buildBody() {
    if (_isLoading) {
      return Container(
        height: 320,
        decoration: _cardDecoration(),
        child: const Center(
          child: CircularProgressIndicator(strokeWidth: 2, color: _darkRed),
        ),
      );
    }

    if (_error != null || _detail == null) {
      return Container(
        width: double.infinity,
        padding: const EdgeInsets.all(24),
        decoration: _cardDecoration(),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              _error ?? '讀取失敗',
              textAlign: TextAlign.center,
              style: AppTextStyles.captionBold.copyWith(color: _textColor),
            ),
            const SizedBox(height: 12),
            GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: _fetchDetail,
              child: Padding(
                padding: const EdgeInsets.all(6),
                child: Text(
                  '重新載入',
                  style: AppTextStyles.captionBold.copyWith(
                    color: _darkRed,
                    decoration: TextDecoration.underline,
                  ),
                ),
              ),
            ),
          ],
        ),
      );
    }

    final detail = _detail!;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _ContentCard(
          detail: detail,
          videoSection: _VideoSection(
            detail: detail,
            videoFile: _videoFile,
            isPreparing: _isPreparingVideo,
            error: _videoError,
            onRetry: () => _prepareVideo(detail),
            onOpen: _openFullScreen,
          ),
          isSavingVideo: _isSavingVideo,
          onDownloadVideo: _saveVideoToGallery,
          onEdit: detail.status == 2 ? null : _openEdit,
          onCopyCaption: () => _copy(detail.caption, '已複製配文'),
          onCopyTags: () => _copy(detail.hashtags.join(' '), '已複製標籤'),
        ),
        const SizedBox(height: 18),
        _ShareButton(
          text: '分享到社群',
          enabled: detail.isCompleted,
          onTap: _shareToSocial,
        ),
      ],
    );
  }

  BoxDecoration _cardDecoration() {
    return BoxDecoration(
      color: _cardColor,
      border: Border.all(color: _black, width: 1),
      borderRadius: BorderRadius.circular(4),
    );
  }
}

class _VlogDetail {
  final dynamic id;
  final int status;
  final String statusText;
  final String title;
  final String caption;
  final List<String> hashtags;
  final String videoUrl;
  final String thumbnail;
  final String errorMessage;
  final String updatedAt;

  const _VlogDetail({
    required this.id,
    required this.status,
    required this.statusText,
    required this.title,
    required this.caption,
    required this.hashtags,
    required this.videoUrl,
    required this.thumbnail,
    required this.errorMessage,
    required this.updatedAt,
  });

  bool get isCompleted => status == 3;

  factory _VlogDetail.fromJson(Map<String, dynamic> json) {
    final rawTags = json['hashtags'];

    return _VlogDetail(
      id: json['mm_id'],
      status: int.tryParse(json['status']?.toString() ?? '') ?? 0,
      statusText: json['status_text']?.toString() ?? '',
      title: json['title']?.toString() ?? '',
      caption: json['caption']?.toString() ?? '',
      hashtags: rawTags is List
          ? rawTags
                .map((e) => e?.toString().trim() ?? '')
                .where((e) => e.isNotEmpty)
                .toList()
          : <String>[],
      videoUrl: json['video_url']?.toString() ?? '',
      thumbnail: json['thumbnail']?.toString() ?? '',
      errorMessage: json['error_message']?.toString() ?? '',
      updatedAt: json['updated_at']?.toString() ?? '',
    );
  }
}

class _ContentCard extends StatelessWidget {
  final _VlogDetail detail;
  final Widget videoSection;
  final bool isSavingVideo;
  final VoidCallback onDownloadVideo;
  final VoidCallback? onEdit;
  final VoidCallback onCopyCaption;
  final VoidCallback onCopyTags;

  const _ContentCard({
    required this.detail,
    required this.videoSection,
    required this.isSavingVideo,
    required this.onDownloadVideo,
    required this.onEdit,
    required this.onCopyCaption,
    required this.onCopyTags,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 18),
      decoration: BoxDecoration(
        color: _cardColor,
        border: Border.all(color: _black, width: 1),
        borderRadius: BorderRadius.circular(4),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          if (detail.title.isNotEmpty) ...[
            Text(
              detail.title,
              style: AppTextStyles.sectionTitle.copyWith(color: _textColor),
            ),
            const SizedBox(height: 4),
            if (detail.statusText.isNotEmpty)
              Text(
                '狀態：${detail.statusText}',
                style: AppTextStyles.captionBold.copyWith(
                  color: detail.isCompleted ? _textColor : _darkRed,
                ),
              ),
            const SizedBox(height: 10),
          ],
          _SectionHeader(
            icon: 'img/reel.png',
            title: 'Reels 影音',
            actions: [
              _HeaderAction(
                icon: 'img/video_download.png',
                onTap: onDownloadVideo,
                busy: isSavingVideo,
              ),
              if (onEdit != null)
                _HeaderAction(icon: 'img/video_edit.png', onTap: onEdit!),
            ],
          ),
          const SizedBox(height: 10),
          Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 230),
              child: AspectRatio(aspectRatio: 230 / 318, child: videoSection),
            ),
          ),
          const SizedBox(height: 12),
          _SectionHeader(
            icon: 'img/reel_content.png',
            title: 'Reels 推薦配文',
            actions: [
              _HeaderAction(icon: 'img/copy.png', onTap: onCopyCaption),
            ],
          ),
          const SizedBox(height: 5),
          _ContentTextBox(
            text: detail.caption.isEmpty ? '尚無推薦配文' : detail.caption,
          ),
          const SizedBox(height: 15),
          _SectionHeader(
            icon: 'img/tag.png',
            title: 'Reels 推薦標籤',
            actions: [_HeaderAction(icon: 'img/copy.png', onTap: onCopyTags)],
          ),
          const SizedBox(height: 8),
          if (detail.hashtags.isEmpty)
            Text(
              '尚無推薦標籤',
              style: AppTextStyles.captionBold.copyWith(color: _textColor),
            )
          else
            Wrap(
              spacing: 7,
              runSpacing: 7,
              children: [for (final tag in detail.hashtags) _Tag(text: tag)],
            ),
        ],
      ),
    );
  }
}

class _VideoSection extends StatelessWidget {
  final _VlogDetail detail;
  final File? videoFile;
  final bool isPreparing;
  final String? error;
  final VoidCallback onRetry;
  final VoidCallback onOpen;

  const _VideoSection({
    required this.detail,
    required this.videoFile,
    required this.isPreparing,
    required this.error,
    required this.onRetry,
    required this.onOpen,
  });

  @override
  Widget build(BuildContext context) {
    if (videoFile != null) {
      return _VideoPreview(
        key: ValueKey(videoFile!.path),
        file: videoFile!,
        thumbnail: detail.thumbnail,
        onTap: onOpen,
      );
    }

    String? hint;
    bool showSpinner = false;
    bool canRetry = false;

    if (!detail.isCompleted) {
      hint = detail.errorMessage.isNotEmpty
          ? detail.errorMessage
          : (detail.statusText.isEmpty ? '影片尚未完成' : detail.statusText);
    } else if (detail.videoUrl.isEmpty) {
      hint = '尚無影片';
    } else if (isPreparing) {
      showSpinner = true;
      hint = '正在準備影片……';
    } else {
      hint = error ?? '點擊載入影片';
      canRetry = true;
    }

    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: canRetry ? onRetry : null,
      child: Container(
        width: double.infinity,
        color: Colors.black,
        child: Stack(
          fit: StackFit.expand,
          children: [
            if (detail.thumbnail.isNotEmpty)
              Opacity(
                opacity: 0.5,
                child: Image.network(
                  detail.thumbnail,
                  fit: BoxFit.cover,
                  errorBuilder: (_, __, ___) => const SizedBox.shrink(),
                ),
              ),
            Center(
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (showSpinner)
                      const SizedBox(
                        width: 28,
                        height: 28,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.white,
                        ),
                      )
                    else if (canRetry)
                      const Icon(
                        Icons.refresh_rounded,
                        size: 40,
                        color: Colors.white70,
                      ),
                    if (hint != null) ...[
                      const SizedBox(height: 10),
                      Text(
                        hint,
                        textAlign: TextAlign.center,
                        style: AppTextStyles.captionBold.copyWith(
                          color: Colors.white,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _VideoPreview extends StatefulWidget {
  final File file;
  final String thumbnail;
  final VoidCallback onTap;

  const _VideoPreview({
    super.key,
    required this.file,
    required this.thumbnail,
    required this.onTap,
  });

  @override
  State<_VideoPreview> createState() => _VideoPreviewState();
}

class _VideoPreviewState extends State<_VideoPreview> {
  late final VideoPlayerController _controller;
  bool _isInitialized = false;

  @override
  void initState() {
    super.initState();
    _controller = VideoPlayerController.file(widget.file);
    _initialize();
  }

  Future<void> _initialize() async {
    try {
      await _controller.initialize();
      await _controller.setVolume(0);
      await _controller.seekTo(const Duration(milliseconds: 100));

      if (!mounted) return;

      setState(() {
        _isInitialized = true;
      });
    } catch (e) {
      debugPrint('影片預覽初始化失敗：$e');
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: widget.onTap,
      child: Container(
        color: Colors.black,
        child: Stack(
          fit: StackFit.expand,
          children: [
            if (_isInitialized)
              ClipRect(
                child: FittedBox(
                  fit: BoxFit.cover,
                  child: SizedBox(
                    width: _controller.value.size.width,
                    height: _controller.value.size.height,
                    child: VideoPlayer(_controller),
                  ),
                ),
              )
            else if (widget.thumbnail.isNotEmpty)
              Image.network(
                widget.thumbnail,
                fit: BoxFit.cover,
                errorBuilder: (_, __, ___) => const SizedBox.shrink(),
              ),
            Container(color: Colors.black.withOpacity(0.18)),
            const Center(
              child: Icon(
                Icons.play_circle_fill_rounded,
                size: 58,
                color: Colors.white70,
              ),
            ),
            Positioned(
              right: 8,
              bottom: 8,
              child: Container(
                padding: const EdgeInsets.all(4),
                decoration: BoxDecoration(
                  color: Colors.black.withOpacity(0.45),
                  borderRadius: BorderRadius.circular(4),
                ),
                child: const Icon(
                  Icons.fullscreen_rounded,
                  size: 18,
                  color: Colors.white,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _FullScreenVideoPage extends StatefulWidget {
  final File file;
  final Future<void> Function() onDownload;

  const _FullScreenVideoPage({required this.file, required this.onDownload});

  @override
  State<_FullScreenVideoPage> createState() => _FullScreenVideoPageState();
}

class _FullScreenVideoPageState extends State<_FullScreenVideoPage> {
  late final VideoPlayerController _controller;
  bool _isInitialized = false;
  bool _isSaving = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _controller = VideoPlayerController.file(widget.file);
    _initialize();
  }

  Future<void> _initialize() async {
    try {
      await _controller.initialize();
      await _controller.setLooping(false);

      if (!mounted) return;

      setState(() {
        _isInitialized = true;
      });

      await _controller.play();
    } catch (e) {
      debugPrint('全螢幕播放器初始化失敗：$e');

      if (!mounted) return;

      setState(() {
        _error = '影片無法播放，請確認影片檔案是否完整';
      });
    }
  }

  Future<void> _togglePlay() async {
    final value = _controller.value;

    if (value.isPlaying) {
      await _controller.pause();
      return;
    }

    if (value.duration > Duration.zero && value.position >= value.duration) {
      await _controller.seekTo(Duration.zero);
    }

    await _controller.play();
  }

  Future<void> _download() async {
    if (_isSaving) return;

    setState(() {
      _isSaving = true;
    });

    try {
      await widget.onDownload();
    } finally {
      if (mounted) {
        setState(() {
          _isSaving = false;
        });
      }
    }
  }

  String _formatDuration(Duration duration) {
    final minutes = duration.inMinutes.remainder(60).toString().padLeft(2, '0');
    final seconds = duration.inSeconds.remainder(60).toString().padLeft(2, '0');

    if (duration.inHours > 0) {
      return '${duration.inHours.toString().padLeft(2, '0')}:$minutes:$seconds';
    }

    return '$minutes:$seconds';
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: SafeArea(
        child: Stack(
          children: [
            Positioned.fill(child: _buildPlayer()),
            Positioned(
              top: 8,
              left: 8,
              right: 8,
              child: Row(
                children: [
                  _RoundIconButton(
                    icon: Icons.close_rounded,
                    onTap: () => Navigator.of(context).pop(),
                  ),
                  const Spacer(),
                  _RoundIconButton(
                    icon: Icons.download_rounded,
                    busy: _isSaving,
                    onTap: _download,
                  ),
                ],
              ),
            ),
            if (_isInitialized)
              Positioned(
                left: 16,
                right: 16,
                bottom: 16,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    VideoProgressIndicator(
                      _controller,
                      allowScrubbing: true,
                      padding: const EdgeInsets.symmetric(vertical: 10),
                      colors: const VideoProgressColors(
                        playedColor: _darkRed,
                        bufferedColor: Color(0x66FFFFFF),
                        backgroundColor: Color(0x33FFFFFF),
                      ),
                    ),
                    ValueListenableBuilder<VideoPlayerValue>(
                      valueListenable: _controller,
                      builder: (context, value, _) {
                        return Row(
                          children: [
                            Text(
                              _formatDuration(value.position),
                              style: AppTextStyles.captionBold.copyWith(
                                color: Colors.white,
                              ),
                            ),
                            const Spacer(),
                            Text(
                              _formatDuration(value.duration),
                              style: AppTextStyles.captionBold.copyWith(
                                color: Colors.white70,
                              ),
                            ),
                          ],
                        );
                      },
                    ),
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildPlayer() {
    if (_error != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Text(
            _error!,
            textAlign: TextAlign.center,
            style: AppTextStyles.bodySmallBold.copyWith(color: Colors.white),
          ),
        ),
      );
    }

    if (!_isInitialized) {
      return const Center(
        child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
      );
    }

    final aspectRatio = _controller.value.aspectRatio > 0
        ? _controller.value.aspectRatio
        : 9 / 16;

    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: _togglePlay,
      child: Stack(
        alignment: Alignment.center,
        children: [
          Center(
            child: AspectRatio(
              aspectRatio: aspectRatio,
              child: VideoPlayer(_controller),
            ),
          ),
          IgnorePointer(
            child: ValueListenableBuilder<VideoPlayerValue>(
              valueListenable: _controller,
              builder: (context, value, _) {
                return AnimatedOpacity(
                  opacity: value.isPlaying ? 0 : 1,
                  duration: const Duration(milliseconds: 150),
                  child: const Icon(
                    Icons.play_circle_fill_rounded,
                    size: 76,
                    color: Colors.white70,
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

class _RoundIconButton extends StatelessWidget {
  final IconData icon;
  final VoidCallback onTap;
  final bool busy;

  const _RoundIconButton({
    required this.icon,
    required this.onTap,
    this.busy = false,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: busy ? null : onTap,
      child: Container(
        width: 42,
        height: 42,
        decoration: BoxDecoration(
          color: Colors.black.withOpacity(0.45),
          shape: BoxShape.circle,
          border: Border.all(color: Colors.white.withOpacity(0.35)),
        ),
        child: busy
            ? const Padding(
                padding: EdgeInsets.all(11),
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  color: Colors.white,
                ),
              )
            : Icon(icon, color: Colors.white, size: 24),
      ),
    );
  }
}

class _HeaderAction {
  final String? icon;
  final IconData? iconData;
  final VoidCallback onTap;
  final bool busy;

  const _HeaderAction({
    this.icon,
    this.iconData,
    required this.onTap,
    this.busy = false,
  });
}

class _SectionHeader extends StatelessWidget {
  final String icon;
  final String title;
  final List<_HeaderAction> actions;

  const _SectionHeader({
    required this.icon,
    required this.title,
    required this.actions,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Image.asset(icon, width: 22, height: 22, fit: BoxFit.contain),
        const SizedBox(width: 6),
        Expanded(
          child: Text(
            title,
            maxLines: 2,
            overflow: TextOverflow.visible,
            style: AppTextStyles.sectionTitle.copyWith(color: _textColor),
          ),
        ),
        if (actions.isNotEmpty) ...[
          const SizedBox(width: 5),
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              for (int i = 0; i < actions.length; i++) ...[
                if (i > 0) const SizedBox(width: 5),
                GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onTap: actions[i].busy ? null : actions[i].onTap,
                  child: Padding(
                    padding: const EdgeInsets.all(3),
                    child: actions[i].busy
                        ? const SizedBox(
                            width: 21,
                            height: 21,
                            child: Padding(
                              padding: EdgeInsets.all(2),
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: _darkRed,
                              ),
                            ),
                          )
                        : actions[i].iconData != null
                        ? Icon(actions[i].iconData, size: 21, color: _textColor)
                        : Image.asset(
                            actions[i].icon!,
                            width: 21,
                            height: 21,
                            fit: BoxFit.contain,
                          ),
                  ),
                ),
              ],
            ],
          ),
        ],
      ],
    );
  }
}

class _ContentTextBox extends StatelessWidget {
  final String text;

  const _ContentTextBox({required this.text});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(9, 8, 9, 9),
      decoration: BoxDecoration(
        color: _cardColor,
        border: Border.all(color: _black, width: 1),
        borderRadius: BorderRadius.circular(5),
      ),
      child: Text(
        text,
        softWrap: true,
        style: AppTextStyles.captionBold
            .copyWith(color: _textColor)
            .copyWith(height: 1.42),
      ),
    );
  }
}

class _Tag extends StatelessWidget {
  final String text;

  const _Tag({required this.text});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: _darkRed,
        border: Border.all(color: _black, width: 1),
        borderRadius: BorderRadius.circular(6),
        boxShadow: const [
          BoxShadow(color: _buttonOuter, offset: Offset(0, 2), blurRadius: 0),
        ],
      ),
      child: Text(
        text,
        softWrap: false,
        style: AppTextStyles.label
            .copyWith(color: _lightText)
            .copyWith(height: 1),
      ),
    );
  }
}

class _ShareButton extends StatefulWidget {
  final String text;
  final bool enabled;
  final VoidCallback onTap;

  const _ShareButton({
    required this.text,
    required this.onTap,
    this.enabled = true,
  });

  @override
  State<_ShareButton> createState() => _ShareButtonState();
}

class _ShareButtonState extends State<_ShareButton> {
  bool _pressed = false;

  @override
  Widget build(BuildContext context) {
    return Opacity(
      opacity: widget.enabled ? 1 : 0.5,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTapDown: widget.enabled
            ? (_) => setState(() => _pressed = true)
            : null,
        onTapUp: widget.enabled
            ? (_) {
                setState(() => _pressed = false);
                widget.onTap();
              }
            : null,
        onTapCancel: widget.enabled
            ? () => setState(() => _pressed = false)
            : null,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 100),
          constraints: const BoxConstraints(minHeight: 48),
          transform: Matrix4.translationValues(0, _pressed ? 2 : 0, 0),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(24),
            gradient: const RadialGradient(
              center: Alignment.center,
              radius: 1.25,
              colors: [_buttonInner, _buttonOuter],
            ),
            border: Border.all(color: _buttonText, width: 2),
            boxShadow: const [
              BoxShadow(color: _black, offset: Offset(0, 3), blurRadius: 0),
            ],
          ),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 10),
            child: Center(
              child: FittedBox(
                fit: BoxFit.scaleDown,
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(
                      Icons.ios_share_rounded,
                      size: 18,
                      color: _buttonText,
                    ),
                    const SizedBox(width: 6),
                    Text(
                      widget.text,
                      maxLines: 1,
                      style: AppTextStyles.button
                          .copyWith(color: _buttonText)
                          .copyWith(height: 1),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _ShareNoticeDialog extends StatelessWidget {
  const _ShareNoticeDialog();

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: _cardColor,
      insetPadding: const EdgeInsets.symmetric(horizontal: 36),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(4),
        side: const BorderSide(color: _black, width: 1.2),
      ),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 20, 20, 18),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              '分享前提醒',
              style: AppTextStyles.sectionTitle.copyWith(color: _textColor),
            ),
            const SizedBox(height: 10),
            Text(
              '分享時只會傳送影片，配文與標籤不會一併帶入。\n建議先複製資訊，分享後再貼上。',
              textAlign: TextAlign.center,
              style: AppTextStyles.captionBold
                  .copyWith(color: _textColor)
                  .copyWith(height: 1.5),
            ),
            const SizedBox(height: 16),
            _DialogButton(
              text: '複製資訊並分享',
              primary: true,
              onTap: () => Navigator.pop(context, _ShareChoice.copyAndShare),
            ),
            const SizedBox(height: 10),
            _DialogButton(
              text: '直接分享',
              primary: false,
              onTap: () => Navigator.pop(context, _ShareChoice.shareOnly),
            ),
          ],
        ),
      ),
    );
  }
}

class _DialogButton extends StatelessWidget {
  final String text;
  final bool primary;
  final VoidCallback onTap;

  const _DialogButton({
    required this.text,
    required this.primary,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      child: Container(
        width: double.infinity,
        height: 42,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: primary ? _darkRed : _cardColor,
          borderRadius: BorderRadius.circular(6),
          border: Border.all(color: _black, width: 1),
          boxShadow: const [
            BoxShadow(color: _buttonOuter, offset: Offset(0, 2), blurRadius: 0),
          ],
        ),
        child: Text(
          text,
          style: AppTextStyles.bodySmallBold.copyWith(
            color: primary ? _lightText : _textColor,
          ),
        ),
      ),
    );
  }
}
