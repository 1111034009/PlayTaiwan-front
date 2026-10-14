import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;
import 'package:flutter_dotenv/flutter_dotenv.dart';
import '../block/navigationbar.dart';
import '../core/app_colors.dart';
import '../core/app_text_styles.dart';
import '../core/app_session.dart';
import '../models/history_record.dart';
import 'past_detail_page.dart';

const Color _pageColor = AppColors.pastBackground;
const Color _subtitleText = Color(0xCCFFFFFF);
const Color _ticketText = AppColors.textPrimary;
const Color _seeMoreColor = AppColors.secondaryRed;

class PastPage extends StatefulWidget {
  const PastPage({super.key});

  @override
  State<PastPage> createState() => _PastPageState();
}

class _PastPageState extends State<PastPage> {
  static const double designWidth = 360;
  static const double contentScale = 1.04;
  String get _apiBaseUrl {
    final String baseUrl = (dotenv.env['API_BASE_URL'] ?? '').trim();

    return baseUrl.replaceFirst(RegExp(r'/$'), '');
  }

  int currentIndex = 3;
  List<HistoryRecord> historyRecords = [];
  bool isLoading = true;

  @override
  void initState() {
    super.initState();

    SystemChrome.setSystemUIOverlayStyle(
      const SystemUiOverlayStyle(
        statusBarColor: _pageColor,
        statusBarIconBrightness: Brightness.light,
        statusBarBrightness: Brightness.dark,
        systemNavigationBarColor: _pageColor,
        systemNavigationBarIconBrightness: Brightness.dark,
      ),
    );

    _fetchHistory();
  }

  Future<void> _fetchHistory() async {
    final token = AppSession.token;

    if (token == null || token.isEmpty) {
      if (!mounted) return;

      setState(() {
        historyRecords = [];
        isLoading = false;
      });

      return;
    }

    try {
      final response = await http.get(
        Uri.parse('$_apiBaseUrl/api/History'),
        headers: {'accept': 'text/plain', 'Authorization': 'Bearer $token'},
      );

      if (response.statusCode >= 200 && response.statusCode < 300) {
        final Map<String, dynamic> data = jsonDecode(
          utf8.decode(response.bodyBytes),
        );

        if (data['isSuccess'] == true) {
          final dynamic result = data['Result'];

          if (result is List) {
            final List<HistoryRecord> records = result
                .whereType<Map<String, dynamic>>()
                .map(HistoryRecord.fromJson)
                .toList();

            if (!mounted) return;

            setState(() {
              historyRecords = records;
              isLoading = false;
            });

            return;
          }
        }
      }
      if (!mounted) return;

      setState(() {
        historyRecords = [];
        isLoading = false;
      });
    } catch (e) {
      if (!mounted) return;

      setState(() {
        historyRecords = [];
        isLoading = false;
      });
    }
  }

  void openPastRecord(HistoryRecord record) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => PastDetailPage(
          title: record.title,
          storyId: record.storyId,
          completedDate: _formatCompletedDate(record.completedDate),
        ),
      ),
    );
  }

  String _formatCompletedDate(DateTime? date) {
    if (date == null) {
      return '';
    }
    return '${date.year}.'
        '${date.month.toString().padLeft(2, '0')}.'
        '${date.day.toString().padLeft(2, '0')}';
  }

  @override
  Widget build(BuildContext context) {
    final Size screenSize = MediaQuery.sizeOf(context);

    return Scaffold(
      backgroundColor: _pageColor,
      extendBody: true,
      body: Stack(
        children: [
          Align(
            alignment: Alignment.topCenter,
            child: Padding(
              padding: EdgeInsets.only(top: screenSize.height * 0.05),
              child: Transform.scale(
                scale: contentScale,
                alignment: Alignment.topCenter,
                child: FittedBox(
                  fit: BoxFit.contain,
                  alignment: Alignment.topCenter,
                  child: SizedBox(
                    width: designWidth,
                    height: screenSize.height / contentScale,
                    child: Stack(
                      clipBehavior: Clip.none,
                      children: [
                        const Positioned.fill(
                          child: ColoredBox(color: _pageColor),
                        ),
                        Positioned(
                          left: 0,
                          right: 0,
                          top: 20,
                          child: Column(
                            children: [
                              Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Image.asset(
                                    'img/Scroll.png',
                                    width: 27,
                                    height: 27,
                                    fit: BoxFit.contain,
                                  ),
                                  const SizedBox(width: 7),
                                  _OutlinedTitle(text: '收藏館'),
                                ],
                              ),
                              const SizedBox(height: 6),
                              Text(
                                '查看你過往紀錄',
                                textAlign: TextAlign.center,
                                style: AppTextStyles.bodySmallBold
                                    .copyWith(color: _subtitleText)
                                    .copyWith(height: 1.1),
                              ),
                            ],
                          ),
                        ),
                        Positioned(
                          left: 0,
                          right: 0,
                          top: 95,
                          bottom: 0,
                          child: ScrollConfiguration(
                            behavior: const _NoScrollbarScrollBehavior(),
                            child: _buildHistoryList(),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
      bottomNavigationBar: AppNavigationBar(currentIndex: currentIndex),
    );
  }

  Widget _buildHistoryList() {
    if (isLoading) {
      return const Center(
        child: CircularProgressIndicator(
          strokeWidth: 2,
          color: AppColors.secondaryRed,
        ),
      );
    }

    if (historyRecords.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 30),
          child: Text(
            '目前還沒有完成的探險紀錄',
            textAlign: TextAlign.center,
            style: AppTextStyles.bodySmallBold.copyWith(color: _subtitleText),
          ),
        ),
      );
    }

    return ListView.builder(
      physics: const BouncingScrollPhysics(),
      padding: const EdgeInsets.fromLTRB(15, 7, 15, 180),
      itemCount: historyRecords.length,
      itemBuilder: (_, index) {
        final HistoryRecord record = historyRecords[index];

        return Padding(
          padding: const EdgeInsets.only(bottom: 9),
          child: _PastTicket(
            record: record,
            onTap: () => openPastRecord(record),
          ),
        );
      },
    );
  }
}

class _PastTicket extends StatelessWidget {
  final HistoryRecord record;
  final VoidCallback onTap;
  const _PastTicket({required this.record, required this.onTap});
  @override
  Widget build(BuildContext context) {
    return _PressScale(
      scale: 0.985,
      onTap: onTap,
      child: SizedBox(
        width: 330,
        height: 133,
        child: Stack(
          clipBehavior: Clip.none,
          children: [
            Positioned.fill(
              child: Image.asset(
                'img/use_ticket.png',
                fit: BoxFit.fill,
                filterQuality: FilterQuality.high,
                errorBuilder: (_, __, ___) {
                  return Container(
                    decoration: BoxDecoration(
                      color: AppColors.paper,
                      borderRadius: BorderRadius.circular(6),
                      border: Border.all(color: AppColors.postcardLine),
                    ),
                  );
                },
              ),
            ),
            Positioned(
              left: 15,
              top: 16,
              width: 91,
              height: 94,
              child: Container(
                decoration: BoxDecoration(
                  color: const Color(0xFFE4D6B7),
                  border: Border.all(color: const Color(0xFF8C8176)),
                ),
                child: record.coverImageUrl.isEmpty
                    ? const Icon(
                        Icons.image_not_supported_outlined,
                        color: Color(0xFF8C8176),
                      )
                    : Image.network(
                        record.coverImageUrl,
                        fit: BoxFit.cover,
                        errorBuilder: (_, __, ___) => const Icon(
                          Icons.image_not_supported_outlined,
                          color: Color(0xFF8C8176),
                        ),
                      ),
              ),
            ),
            Positioned(
              left: 120,
              top: 15,
              right: 24,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    record.title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: AppTextStyles.subtitle.copyWith(
                      color: _seeMoreColor,
                    ),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    record.synopsis,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: AppTextStyles.microLabelWide
                        .copyWith(color: _ticketText)
                        .copyWith(height: 1.35),
                  ),
                ],
              ),
            ),
            Positioned(right: 40, bottom: 12, child: _ViewButton(onTap: onTap)),
          ],
        ),
      ),
    );
  }
}

class _ViewButton extends StatelessWidget {
  final VoidCallback onTap;

  const _ViewButton({required this.onTap});

  @override
  Widget build(BuildContext context) {
    return _PressScale(
      scale: 0.95,
      duration: const Duration(milliseconds: 150),
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: onTap,
        child: Container(
          height: 22,
          padding: const EdgeInsets.symmetric(horizontal: 12),
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: const Color(0xFFE4D4B5),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: AppColors.postcardLine),
          ),
          child: Text(
            '查看資料→',
            textAlign: TextAlign.center,
            style: AppTextStyles.microBold.copyWith(color: _ticketText),
          ),
        ),
      ),
    );
  }
}

class _PressScale extends StatefulWidget {
  final Widget child;
  final VoidCallback? onTap;
  final double scale;
  final Duration duration;

  const _PressScale({
    required this.child,
    this.onTap,
    this.scale = 0.96,
    this.duration = const Duration(milliseconds: 130),
  });

  @override
  State<_PressScale> createState() => _PressScaleState();
}

class _PressScaleState extends State<_PressScale> {
  bool pressing = false;

  void setPressing(bool value) {
    if (mounted) {
      setState(() {
        pressing = value;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: widget.onTap,
      onTapDown: (_) => setPressing(true),
      onTapUp: (_) => setPressing(false),
      onTapCancel: () => setPressing(false),
      child: AnimatedScale(
        scale: pressing ? widget.scale : 1,
        duration: widget.duration,
        curve: Curves.easeOutBack,
        child: widget.child,
      ),
    );
  }
}

class _OutlinedTitle extends StatelessWidget {
  final String text;

  const _OutlinedTitle({required this.text});

  @override
  Widget build(BuildContext context) {
    final TextStyle outlineStyle = AppTextStyles.displayMedium
        .copyWith(color: _ticketText)
        .copyWith(
          foreground: Paint()
            ..style = PaintingStyle.stroke
            ..strokeWidth = 3.2
            ..color = _ticketText,
        );

    return Stack(
      alignment: Alignment.center,
      children: [
        Text(text, style: outlineStyle),
        Text(
          text,
          style: AppTextStyles.displayMedium.copyWith(color: Colors.white),
        ),
      ],
    );
  }
}

class _NoScrollbarScrollBehavior extends ScrollBehavior {
  const _NoScrollbarScrollBehavior();

  @override
  Widget buildScrollbar(
    BuildContext context,
    Widget child,
    ScrollableDetails details,
  ) {
    return child;
  }

  @override
  Widget buildOverscrollIndicator(
    BuildContext context,
    Widget child,
    ScrollableDetails details,
  ) {
    return child;
  }
}
