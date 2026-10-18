import 'package:flutter/material.dart';
import 'package:flutter_markdown_plus/flutter_markdown_plus.dart';
import '../api/visitor_analysis_api.dart';

class AudienceDashboardPage extends StatefulWidget {
  const AudienceDashboardPage({super.key});

  @override
  State<AudienceDashboardPage> createState() => _AudienceDashboardPageState();
}

class _AudienceDashboardPageState extends State<AudienceDashboardPage> {
  static const navy = Color(0xFF4A3728);
  static const blue = Color(0xFFA9754F);
  static const background = Color(0xFFF7F1E8);
  static const ink = Color(0xFF4A3728);
  static const muted = Color(0xFF806F61);

  bool loading = true;
  String? error;
  List<VisitorAttraction> attractions = [];
  int selected = 0;

  VisitorAttraction? get spot =>
      attractions.isEmpty ? null : attractions[selected];

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      loading = true;
      error = null;
    });

    try {
      final data = await VisitorAnalysisApi.fetchDashboard();
      if (!mounted) return;
      final defaultIndex = data.attractions.indexWhere(
        (item) => item.name.contains('九族文化村'),
      );
      setState(() {
        attractions = data.attractions;
        selected = defaultIndex >= 0 ? defaultIndex : 0;
        loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        error = e.toString();
        loading = false;
      });
    }
  }

  String _pct(double? value) =>
      value == null ? '—' : '${value.toStringAsFixed(1)}%';

  String _num(num? value, {int digits = 1, String suffix = ''}) {
    if (value == null) return '—';
    if (value is int) return '$value$suffix';
    return '${value.toStringAsFixed(digits)}$suffix';
  }

  @override
  Widget build(BuildContext context) {
    return Theme(
      data: Theme.of(context).copyWith(
        textTheme: Theme.of(
          context,
        ).textTheme.apply(fontFamily: 'KaiseiHarunoUmi'),
      ),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final tablet = constraints.maxWidth >= 780;
          return Scaffold(
            backgroundColor: background,
            appBar: tablet
                ? null
                : AppBar(
                    title: const Text(
                      '智慧觀光客群分析',
                      style: TextStyle(fontSize: 17),
                    ),
                    backgroundColor: navy,
                    foregroundColor: Colors.white,
                    actions: [
                      IconButton(
                        onPressed: _load,
                        icon: const Icon(Icons.refresh),
                      ),
                      IconButton(
                        onPressed: () => _openChat(context),
                        icon: const Icon(Icons.chat_outlined),
                      ),
                    ],
                  ),
            body: Column(
              children: [
                if (tablet) _toolbar(),
                Expanded(child: _buildBody(tablet, constraints.maxWidth)),
              ],
            ),
            floatingActionButton: tablet
                ? null
                : FloatingActionButton.extended(
                    onPressed: () => _openChat(context),
                    backgroundColor: blue,
                    foregroundColor: Colors.white,
                    icon: const Icon(Icons.chat_bubble_outline),
                    label: const Text('智慧助手'),
                  ),
          );
        },
      ),
    );
  }

  Widget _buildBody(bool tablet, double maxWidth) {
    if (loading) {
      return const Center(child: CircularProgressIndicator(color: blue));
    }

    if (error != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.error_outline, color: navy, size: 40),
              const SizedBox(height: 12),
              Text(
                error!,
                textAlign: TextAlign.center,
                style: const TextStyle(color: muted, fontSize: 13),
              ),
              const SizedBox(height: 16),
              FilledButton(
                onPressed: _load,
                style: FilledButton.styleFrom(backgroundColor: blue),
                child: const Text('重新載入'),
              ),
            ],
          ),
        ),
      );
    }

    if (attractions.isEmpty) {
      return const Center(
        child: Text('目前沒有景點分析資料', style: TextStyle(color: muted)),
      );
    }

    if (tablet) {
      return Row(
        children: [
          Expanded(flex: 7, child: _dashboard()),
          SizedBox(
            width: maxWidth >= 1100 ? 340 : 290,
            child: _StrategyChatPanel(
              key: ValueKey(spot?.uid ?? ''),
              attractionUid: spot?.uid ?? '',
              attractionName: spot?.name ?? '',
            ),
          ),
        ],
      );
    }

    return _dashboard();
  }

  Widget _toolbar() => Container(
    height: 58,
    padding: const EdgeInsets.symmetric(horizontal: 22),
    color: Colors.white,
    child: Row(
      children: [
        const Icon(Icons.analytics_outlined, color: blue),
        const SizedBox(width: 10),
        const Text(
          '智慧觀光客群分析',
          style: TextStyle(
            fontWeight: FontWeight.bold,
            fontSize: 17,
            color: navy,
          ),
        ),
        const Spacer(),
        Text(
          '共 ${attractions.length} 個景點',
          style: const TextStyle(fontSize: 12, color: muted),
        ),
        const SizedBox(width: 12),
        IconButton(
          tooltip: '重新載入',
          onPressed: _load,
          icon: const Icon(Icons.refresh, color: blue),
        ),
      ],
    ),
  );

  Widget _dashboard() {
    final current = spot!;
    final domestic = current.domestic;
    final inbound = current.inbound;

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        _hero(current),
        const SizedBox(height: 16),
        _sectionTitle('國內旅客客群分析', Icons.people_alt_outlined),
        const SizedBox(height: 10),
        _domestic(domestic),
        const SizedBox(height: 20),
        _sectionTitle('來臺旅客客群分析', Icons.public),
        const SizedBox(height: 10),
        _inbound(inbound),
        const SizedBox(height: 20),
        _sectionTitle('景點人流分析', Icons.show_chart),
        const SizedBox(height: 10),
        _footfall(domestic, inbound),
        const SizedBox(height: 24),
      ],
    );
  }

  Widget _hero(VisitorAttraction current) => Container(
    padding: const EdgeInsets.all(18),
    decoration: BoxDecoration(
      borderRadius: BorderRadius.circular(16),
      gradient: const LinearGradient(
        colors: [Color(0xFF4A3728), Color(0xFFA9754F)],
      ),
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          '景點客群洞察',
          style: TextStyle(color: Colors.white70, fontSize: 13),
        ),
        const SizedBox(height: 12),
        Autocomplete<int>(
          key: ValueKey(current.uid),
          initialValue: TextEditingValue(text: current.name),
          displayStringForOption: (index) => attractions[index].name,
          optionsBuilder: (value) {
            final query = value.text.trim().toLowerCase();
            return Iterable<int>.generate(attractions.length).where((index) {
              final item = attractions[index];
              return query.isEmpty ||
                  item.name.toLowerCase().contains(query) ||
                  item.city.toLowerCase().contains(query);
            });
          },
          onSelected: (index) => setState(() => selected = index),
          fieldViewBuilder: (context, controller, focusNode, onFieldSubmitted) {
            return TextField(
              controller: controller,
              focusNode: focusNode,
              style: const TextStyle(fontSize: 15, color: ink),
              decoration: InputDecoration(
                hintText: '搜尋景點名稱或縣市，例如：勤美、臺南',
                hintStyle: const TextStyle(color: muted, fontSize: 13),
                prefixIcon: const Icon(Icons.search, color: blue),
                suffixIcon: IconButton(
                  tooltip: '清除搜尋',
                  onPressed: () => controller.clear(),
                  icon: const Icon(Icons.close, size: 18, color: muted),
                ),
                filled: true,
                fillColor: Colors.white,
                isDense: true,
                contentPadding: const EdgeInsets.symmetric(
                  vertical: 13,
                  horizontal: 12,
                ),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(11),
                  borderSide: BorderSide.none,
                ),
              ),
            );
          },
          optionsViewBuilder: (context, onSelected, options) => Align(
            alignment: Alignment.topLeft,
            child: Material(
              elevation: 6,
              borderRadius: BorderRadius.circular(12),
              child: ConstrainedBox(
                constraints: const BoxConstraints(
                  maxHeight: 260,
                  maxWidth: 480,
                ),
                child: ListView.builder(
                  padding: EdgeInsets.zero,
                  shrinkWrap: true,
                  itemCount: options.length,
                  itemBuilder: (context, i) {
                    final index = options.elementAt(i);
                    final item = attractions[index];
                    return ListTile(
                      dense: true,
                      leading: const Icon(Icons.place_outlined, color: blue),
                      title: Text(item.name),
                      subtitle: Text(item.city),
                      onTap: () => onSelected(index),
                    );
                  },
                ),
              ),
            ),
          ),
        ),
        const SizedBox(height: 12),
        Text(
          current.name,
          style: const TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.bold,
            fontSize: 22,
          ),
        ),
        const SizedBox(height: 3),
        Row(
          children: [
            const Icon(Icons.place_outlined, color: Colors.white70, size: 15),
            const SizedBox(width: 4),
            Text(
              current.city,
              style: const TextStyle(color: Colors.white70, fontSize: 12),
            ),
          ],
        ),
        if (current.domestic?.years != null) ...[
          const SizedBox(height: 8),
          Text(
            '國內樣本年：${current.domestic!.years}｜問卷旅次：${current.domestic!.nTrips ?? '—'}',
            style: const TextStyle(color: Colors.white70, fontSize: 11),
          ),
        ],
      ],
    ),
  );

  Widget _domestic(DomesticAnalysis? domestic) {
    if (domestic == null) {
      return _emptyCard('此景點尚無國內旅客分析資料。');
    }

    final ageMap = <String, double>{
      if (domestic.mainAge != null && domestic.mainAgePct != null)
        domestic.mainAge!: domestic.mainAgePct!,
    };

    return Column(
      children: [
        LayoutBuilder(
          builder: (context, constraints) {
            final columns = constraints.maxWidth >= 660 ? 4 : 2;
            final width = (constraints.maxWidth - (columns - 1) * 10) / columns;
            return Wrap(
              spacing: 10,
              runSpacing: 10,
              children: [
                _metric(
                  width,
                  Icons.groups_outlined,
                  '主要年齡層',
                  domestic.mainAge ?? '—',
                  _pct(domestic.mainAgePct),
                ),
                _metric(
                  width,
                  Icons.female_outlined,
                  '女性比例',
                  _pct(domestic.femalePct),
                  '國內旅客',
                ),
                _metric(
                  width,
                  Icons.explore_outlined,
                  '主要旅遊目的',
                  domestic.mainPurpose ?? '—',
                  _pct(domestic.mainPurposePct),
                ),
                _metric(
                  width,
                  Icons.hotel_outlined,
                  '平均旅次天數',
                  _num(domestic.meanDays, suffix: ' 天'),
                  '非景點停留時間',
                ),
              ],
            );
          },
        ),
        const SizedBox(height: 10),
        LayoutBuilder(
          builder: (context, constraints) {
            final twoColumns = constraints.maxWidth >= 590;
            final width = twoColumns
                ? (constraints.maxWidth - 10) / 2
                : constraints.maxWidth;
            return Wrap(
              spacing: 10,
              runSpacing: 10,
              children: [
                if (ageMap.isNotEmpty) _chartCard(width, '主要年齡層', ageMap),
                if (domestic.purposes.isNotEmpty)
                  _chartCard(width, '旅遊目的', domestic.purposes),
                if (domestic.topTransports.isNotEmpty)
                  _chartCard(width, '交通方式（前三）', domestic.topTransports),
                if (domestic.topActivities.isNotEmpty)
                  _chartCard(width, '旅遊活動（前三）', domestic.topActivities),
              ],
            );
          },
        ),
        const SizedBox(height: 10),
        _card(
          Row(
            children: [
              const CircleAvatar(
                backgroundColor: Color(0xFFEDE0D3),
                child: Icon(Icons.hub_outlined, color: blue),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      '旅客分群',
                      style: TextStyle(color: muted, fontSize: 12),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      domestic.inCluster == 1
                          ? (domestic.clusterName?.isNotEmpty == true
                                ? domestic.clusterName!
                                : '已入群')
                          : '樣本不足未入群',
                      style: const TextStyle(
                        color: navy,
                        fontWeight: FontWeight.bold,
                        fontSize: 15,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _inbound(InboundAnalysis? inbound) {
    if (inbound == null) {
      return _emptyCard('此景點尚無來臺旅客分析資料。');
    }

    return Column(
      children: [
        LayoutBuilder(
          builder: (context, constraints) {
            final columns = constraints.maxWidth >= 660 ? 4 : 2;
            final width = (constraints.maxWidth - (columns - 1) * 10) / columns;
            return Wrap(
              spacing: 10,
              runSpacing: 10,
              children: [
                _metric(
                  width,
                  Icons.groups_outlined,
                  '主要年齡層',
                  inbound.mainAge ?? '—',
                  _pct(inbound.mainAgePct),
                ),
                _metric(
                  width,
                  Icons.female_outlined,
                  '女性比例',
                  _pct(inbound.femalePct),
                  '來臺旅客',
                ),
                _metric(
                  width,
                  Icons.explore_outlined,
                  '主要旅遊目的',
                  inbound.mainPurpose ?? '—',
                  _pct(inbound.mainPurposePct),
                ),
                _metric(
                  width,
                  Icons.hotel_outlined,
                  '平均停留',
                  inbound.meanDays != null
                      ? _num(inbound.meanDays, suffix: ' 天')
                      : _num(inbound.meanNights, suffix: ' 夜'),
                  '來臺旅客',
                ),
              ],
            );
          },
        ),
        const SizedBox(height: 10),
        LayoutBuilder(
          builder: (context, constraints) {
            final twoColumns = constraints.maxWidth >= 590;
            final width = twoColumns
                ? (constraints.maxWidth - 10) / 2
                : constraints.maxWidth;
            return Wrap(
              spacing: 10,
              runSpacing: 10,
              children: [
                if (inbound.ages.isNotEmpty)
                  _chartCard(width, '年齡結構', inbound.ages),
                if (inbound.purposes.isNotEmpty)
                  _chartCard(width, '旅遊目的', inbound.purposes),
                if (inbound.topTransports.isNotEmpty)
                  _chartCard(width, '交通方式（前三）', inbound.topTransports),
                if (inbound.topActivities.isNotEmpty)
                  _chartCard(width, '旅遊活動（前三）', inbound.topActivities),
              ],
            );
          },
        ),
        const SizedBox(height: 10),
        _card(
          Row(
            children: [
              const CircleAvatar(
                backgroundColor: Color(0xFFEDE0D3),
                child: Icon(Icons.hub_outlined, color: blue),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      '來臺旅客分群',
                      style: TextStyle(color: muted, fontSize: 12),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      inbound.inCluster == 1
                          ? (inbound.clusterName?.isNotEmpty == true
                                ? inbound.clusterName!
                                : '已入群')
                          : '樣本不足未入群',
                      style: const TextStyle(
                        color: navy,
                        fontWeight: FontWeight.bold,
                        fontSize: 15,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _footfall(DomesticAnalysis? domestic, InboundAnalysis? inbound) {
    final sum = domestic?.ffVisitorsSum ?? inbound?.ffVisitorsSum;
    final mean = domestic?.ffVisitorsMean ?? inbound?.ffVisitorsMean;
    final years = domestic?.ffYears ?? inbound?.ffYears;

    if (sum == null && mean == null) {
      return _card(
        const Row(
          children: [
            Icon(Icons.info_outline, color: blue),
            SizedBox(width: 10),
            Expanded(
              child: Text(
                '此景點尚未載入已核對的據點人流資料；人流量與問卷樣本數不能混用。',
                style: TextStyle(color: muted, fontSize: 13),
              ),
            ),
          ],
        ),
      );
    }

    return LayoutBuilder(
      builder: (context, constraints) {
        final columns = constraints.maxWidth >= 660 ? 3 : 1;
        final width = (constraints.maxWidth - (columns - 1) * 10) / columns;
        return Wrap(
          spacing: 10,
          runSpacing: 10,
          children: [
            _metric(
              width,
              Icons.groups_2_outlined,
              '人流合計',
              _num(sum, digits: 0),
              '據點人流',
            ),
            _metric(
              width,
              Icons.trending_up,
              '年平均人流',
              _num(mean, digits: 0),
              '據點人流',
            ),
            _metric(
              width,
              Icons.calendar_month_outlined,
              '人流年數',
              '${years ?? '—'}',
              '有資料年度',
            ),
          ],
        );
      },
    );
  }

  Widget _emptyCard(String text) => _card(
    Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Icon(Icons.info_outline, color: blue),
        const SizedBox(width: 12),
        Expanded(
          child: Text(
            text,
            style: const TextStyle(color: muted, fontSize: 13, height: 1.5),
          ),
        ),
      ],
    ),
  );

  Widget _sectionTitle(String title, IconData icon) => Row(
    children: [
      Icon(icon, color: blue, size: 21),
      const SizedBox(width: 8),
      Expanded(
        child: Text(
          title,
          style: const TextStyle(
            color: navy,
            fontSize: 17,
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
    ],
  );

  Widget _card(Widget child) => Container(
    width: double.infinity,
    padding: const EdgeInsets.all(14),
    decoration: BoxDecoration(
      color: Colors.white,
      borderRadius: BorderRadius.circular(13),
      border: Border.all(color: const Color(0xFFFFF9F2)),
    ),
    child: child,
  );

  Widget _metric(
    double width,
    IconData icon,
    String label,
    String value,
    String detail,
  ) => SizedBox(
    width: width,
    child: _card(
      Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              Icon(icon, size: 18, color: blue),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(color: muted, fontSize: 12),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.centerLeft,
            child: Text(
              value,
              style: const TextStyle(
                color: navy,
                fontSize: 20,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
          const SizedBox(height: 3),
          Text(
            detail,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(color: blue, fontSize: 12),
          ),
        ],
      ),
    ),
  );

  Widget _chartCard(double width, String title, Map<String, double> values) =>
      SizedBox(
        width: width,
        child: _card(
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                title,
                style: const TextStyle(
                  color: navy,
                  fontWeight: FontWeight.bold,
                  fontSize: 14,
                ),
              ),
              const SizedBox(height: 12),
              ...values.entries.map(
                (entry) => Padding(
                  padding: const EdgeInsets.only(bottom: 9),
                  child: Row(
                    children: [
                      SizedBox(
                        width: 78,
                        child: Text(
                          entry.key,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(color: ink, fontSize: 11),
                        ),
                      ),
                      Expanded(
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(5),
                          child: LinearProgressIndicator(
                            value: (entry.value / 100).clamp(0.0, 1.0),
                            minHeight: 9,
                            backgroundColor: const Color(0xFFEDE0D3),
                            color: blue,
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      SizedBox(
                        width: 45,
                        child: Text(
                          '${entry.value.toStringAsFixed(1)}%',
                          textAlign: TextAlign.right,
                          style: const TextStyle(color: ink, fontSize: 11),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      );

  void _openChat(BuildContext context) {
    final s = spot;
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      builder: (sheetContext) => FractionallySizedBox(
        heightFactor: .88,
        child: Padding(
          padding: EdgeInsets.only(
            bottom: MediaQuery.viewInsetsOf(sheetContext).bottom,
          ),
          child: _StrategyChatPanel(
            key: ValueKey(s?.uid ?? ''),
            attractionUid: s?.uid ?? '',
            attractionName: s?.name ?? '',
          ),
        ),
      ),
    );
  }
}

class _StrategyChatPanel extends StatefulWidget {
  const _StrategyChatPanel({
    super.key,
    required this.attractionUid,
    required this.attractionName,
  });

  final String attractionUid;
  final String attractionName;

  @override
  State<_StrategyChatPanel> createState() => _StrategyChatPanelState();
}

class _StrategyChatPanelState extends State<_StrategyChatPanel> {
  static const navy = Color(0xFF4A3728);
  static const blue = Color(0xFFA9754F);
  static const background = Color(0xFFF7F1E8);
  static const ink = Color(0xFF4A3728);
  static const muted = Color(0xFF806F61);

  final chatController = TextEditingController();
  final chatScroll = ScrollController();
  final messages = <_Message>[
    const _Message(false, '你好！可以詢問目前景點的國內／來臺旅客客群，或請我提供經營策略建議。'),
  ];
  bool sending = false;

  @override
  void dispose() {
    chatController.dispose();
    chatScroll.dispose();
    super.dispose();
  }

  Future<void> send([String? preset]) async {
    final question = (preset ?? chatController.text).trim();
    if (question.isEmpty || sending) return;

    if (widget.attractionUid.isEmpty) {
      setState(() {
        messages.add(_Message(true, question));
        messages.add(const _Message(false, '目前尚未載入景點資料，請稍候或重新整理。'));
        chatController.clear();
      });
      _scrollToEnd();
      return;
    }

    setState(() {
      sending = true;
      messages.add(_Message(true, question));
      messages.add(const _Message(false, '思考中…'));
      chatController.clear();
    });
    _scrollToEnd();

    String replyText;
    try {
      final result = await VisitorAnalysisApi.chatStrategy(
        attractionUid: widget.attractionUid,
        question: question,
      );
      replyText = result.displayText();
    } catch (e) {
      replyText = '連線失敗：$e';
    }

    if (!mounted) return;
    setState(() {
      sending = false;
      if (messages.isNotEmpty &&
          !messages.last.user &&
          messages.last.text == '思考中…') {
        messages.removeLast();
      }
      messages.add(_Message(false, replyText));
    });
    _scrollToEnd();
  }

  void _scrollToEnd() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (chatScroll.hasClients) {
        chatScroll.animateTo(
          chatScroll.position.maxScrollExtent,
          duration: const Duration(milliseconds: 240),
          curve: Curves.easeOut,
        );
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      color: Colors.white,
      child: SafeArea(
        top: false,
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.all(15),
              child: Row(
                children: [
                  const CircleAvatar(
                    backgroundColor: Color(0xFFEDE0D3),
                    child: Icon(Icons.smart_toy_outlined, color: blue),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          '旅遊智慧助手',
                          style: TextStyle(
                            color: navy,
                            fontSize: 15,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        Text(
                          widget.attractionName.isEmpty
                              ? '客群分析・經營策略'
                              : widget.attractionName,
                          style: const TextStyle(color: muted, fontSize: 12),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const Divider(height: 1),
            Expanded(
              child: ListView(
                controller: chatScroll,
                padding: const EdgeInsets.all(12),
                children: [
                  for (final message in messages)
                    Align(
                      alignment: message.user
                          ? Alignment.centerRight
                          : Alignment.centerLeft,
                      child: Container(
                        margin: const EdgeInsets.only(bottom: 10),
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: message.user
                              ? const Color(0xFFEDE0D3)
                              : const Color(0xFFF1F5FB),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: message.user
                            ? Text(
                                message.text,
                                style: const TextStyle(
                                  color: ink,
                                  fontSize: 13,
                                  height: 1.5,
                                ),
                              )
                            : MarkdownBody(
                                data: message.text,
                                selectable: true,
                                styleSheet: MarkdownStyleSheet(
                                  p: const TextStyle(
                                    color: ink,
                                    fontSize: 13,
                                    height: 1.5,
                                  ),
                                  strong: const TextStyle(
                                    color: ink,
                                    fontSize: 13,
                                    fontWeight: FontWeight.bold,
                                  ),
                                  h1: const TextStyle(
                                    color: navy,
                                    fontSize: 17,
                                    fontWeight: FontWeight.bold,
                                  ),
                                  h2: const TextStyle(
                                    color: navy,
                                    fontSize: 15,
                                    fontWeight: FontWeight.bold,
                                  ),
                                  h3: const TextStyle(
                                    color: navy,
                                    fontSize: 14,
                                    fontWeight: FontWeight.bold,
                                  ),
                                  listBullet: const TextStyle(
                                    color: ink,
                                    fontSize: 13,
                                  ),
                                ),
                              ),
                      ),
                    ),
                  const Padding(
                    padding: EdgeInsets.symmetric(vertical: 8),
                    child: Text(
                      '你可以這樣問：',
                      style: TextStyle(color: muted, fontSize: 12),
                    ),
                  ),
                  for (final question in [
                    '主要客群是誰？',
                    '請提供經營策略建議',
                    '來臺旅客的特徵是什麼？',
                    '有旺季人流資料嗎？',
                  ])
                    Padding(
                      padding: const EdgeInsets.only(bottom: 7),
                      child: OutlinedButton(
                        onPressed: sending ? null : () => send(question),
                        style: OutlinedButton.styleFrom(
                          alignment: Alignment.centerLeft,
                          side: const BorderSide(color: Color(0xFFFFF9F2)),
                        ),
                        child: Text(
                          question,
                          style: const TextStyle(color: navy, fontSize: 12),
                        ),
                      ),
                    ),
                ],
              ),
            ),
            const Divider(height: 1),
            Padding(
              padding: const EdgeInsets.all(10),
              child: Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: chatController,
                      enabled: !sending,
                      onSubmitted: (_) => send(),
                      maxLines: 3,
                      minLines: 1,
                      decoration: InputDecoration(
                        hintText: sending ? '回覆生成中…' : '輸入你的問題…',
                        filled: true,
                        fillColor: background,
                        isDense: true,
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(10),
                          borderSide: BorderSide.none,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 6),
                  IconButton.filled(
                    onPressed: sending ? null : () => send(),
                    style: IconButton.styleFrom(backgroundColor: blue),
                    icon: sending
                        ? const SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: Colors.white,
                            ),
                          )
                        : const Icon(Icons.arrow_upward, color: Colors.white),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _Message {
  const _Message(this.user, this.text);
  final bool user;
  final String text;
}
