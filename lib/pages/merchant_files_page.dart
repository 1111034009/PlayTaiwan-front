import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'merchant_file_item.dart';
import '../api/merchant_vlog_api.dart';
import '../core/app_colors.dart';
import '../core/app_text_styles.dart';

const Color _pageColor = AppColors.background;
const Color _paperColor = AppColors.merchantPaper;
const Color _darkText = AppColors.textPrimary;
const Color _red = AppColors.primaryDark;

class MerchantFilesPage extends StatefulWidget {
  const MerchantFilesPage({super.key});

  @override
  State<MerchantFilesPage> createState() => _MerchantFilesPageState();
}

class _MerchantFilesPageState extends State<MerchantFilesPage> {
  List<MerchantFile> _files = [];
  bool _isLoading = true;
  String? _error;

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

    _fetchFiles();
  }

  Future<void> _fetchFiles({bool silent = false}) async {
    if (!mounted) return;

    if (!silent) {
      setState(() {
        _isLoading = true;
        _error = null;
      });
    }

    try {
      final files = await MerchantVlogApi.fetchFiles();

      if (!mounted) return;

      setState(() {
        _files = files;
        _isLoading = false;
        _error = null;
      });
    } catch (e) {
      if (!mounted) return;

      setState(() {
        _isLoading = false;
        _error = e.toString().replaceFirst('Exception: ', '');
      });
    }
  }

  Future<void> _openFile(MerchantFile file) async {
    await openMerchantFile(context, file);

    if (mounted) _fetchFiles(silent: true);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _pageColor,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(22, 10, 22, 22),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Align(
                alignment: Alignment.centerLeft,
                child: GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onTap: () => Navigator.pop(context),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(vertical: 5),
                    child: Text(
                      '<< 返回',
                      style: AppTextStyles.bodySmallBold
                          .copyWith(color: const Color(0xFFFAF7F1))
                          .copyWith(
                            shadows: const [
                              Shadow(
                                color: Color(0x66000000),
                                offset: Offset(1.2, 1.5),
                                blurRadius: 1.5,
                              ),
                            ],
                          ),
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 8),
              const Center(child: _PageTitle(text: '檔案館')),
              const SizedBox(height: 14),
              Expanded(
                child: Container(
                  padding: const EdgeInsets.fromLTRB(16, 12, 16, 10),
                  decoration: BoxDecoration(
                    color: _paperColor,
                    borderRadius: BorderRadius.circular(5),
                    border: Border.all(color: Colors.black, width: 1.2),
                    boxShadow: const [
                      BoxShadow(
                        color: _darkText,
                        blurRadius: 0,
                        offset: Offset(1, 2),
                      ),
                    ],
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          const Spacer(),
                          if (!_isLoading && _error == null)
                            Text(
                              '共 ${_files.length} 部',
                              style: AppTextStyles.captionBold.copyWith(
                                color: _darkText,
                              ),
                            ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Expanded(child: _buildContent()),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildContent() {
    if (_isLoading) {
      return const Center(
        child: CircularProgressIndicator(strokeWidth: 2, color: _red),
      );
    }

    if (_error != null) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              _error!,
              maxLines: 3,
              overflow: TextOverflow.ellipsis,
              textAlign: TextAlign.center,
              style: AppTextStyles.captionBold.copyWith(color: _darkText),
            ),
            const SizedBox(height: 8),
            GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: _fetchFiles,
              child: Padding(
                padding: const EdgeInsets.all(6),
                child: Text(
                  '重新載入',
                  style: AppTextStyles.captionBold.copyWith(
                    color: _red,
                    decoration: TextDecoration.underline,
                  ),
                ),
              ),
            ),
          ],
        ),
      );
    }

    if (_files.isEmpty) {
      return Center(
        child: Text(
          '目前沒有生成檔案',
          style: AppTextStyles.captionBold.copyWith(color: _darkText),
        ),
      );
    }

    return RefreshIndicator(
      color: _red,
      onRefresh: () => _fetchFiles(silent: true),
      child: ListView.separated(
        padding: EdgeInsets.zero,
        physics: const AlwaysScrollableScrollPhysics(
          parent: BouncingScrollPhysics(),
        ),
        itemCount: _files.length,
        separatorBuilder: (_, __) => const SizedBox(height: 5),
        itemBuilder: (_, index) {
          final file = _files[index];

          return MerchantFileItem(file: file, onTap: () => _openFile(file));
        },
      ),
    );
  }
}

class _PageTitle extends StatelessWidget {
  final String text;

  const _PageTitle({required this.text});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Image.asset('img/reel.png', width: 24, height: 24),
        const SizedBox(width: 6),
        Stack(
          alignment: Alignment.center,
          children: [
            Text(
              text,
              style: AppTextStyles.pageTitle
                  .copyWith(color: Colors.white)
                  .copyWith(
                    foreground: Paint()
                      ..style = PaintingStyle.stroke
                      ..strokeWidth = 2.6
                      ..color = _darkText,
                  ),
            ),
            Text(
              text,
              style: AppTextStyles.pageTitle.copyWith(color: Colors.white),
            ),
          ],
        ),
      ],
    );
  }
}
