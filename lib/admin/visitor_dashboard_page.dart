import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart' hide Text;
import 'package:flutter_markdown_plus/flutter_markdown_plus.dart';
import '../api/visitor_analysis_api.dart';
import 'admin_theme.dart';

import 'package:playtaiwan/core/i18n.dart';
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

  static const palette = [
    Color(0xFFA9754F),
    Color(0xFF4A3728),
    Color(0xFFD4A373),
    Color(0xFF6B8F71),
    Color(0xFF8C5A3C),
    Color(0xFFC9B79C),
  ];

  bool loading = true;
  String? error;
  List<VisitorAttraction> attractions = [];

  /// null = 還沒搜尋，顯示全台總覽
  int? selected;

  /// 全台總覽（Neo4j 統計）；跟景點清單分開載入，一邊失敗不影響另一邊
  VisitorOverview? overview;
  String? overviewError;
  String cityMetric = '景點';

  VisitorAttraction? get spot =>
      selected == null || selected! >= attractions.length
          ? null
          : attractions[selected!];

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load({bool refresh = false}) async {
    setState(() {
      loading = true;
      error = null;
      overviewError = null;
    });

    await Future.wait([
      VisitorAnalysisApi.fetchDashboard().then((data) {
        final uid = spot?.uid;
        attractions = data.attractions;
        final index = attractions.indexWhere((item) => item.uid == uid);
        selected = index >= 0 ? index : null;
      }).catchError((Object e) {
        error = e.toString().replaceFirst('Exception: ', '');
      }),
      VisitorAnalysisApi.fetchOverview(refresh: refresh).then((data) {
        overview = data;
      }).catchError((Object e) {
        overviewError = e.toString().replaceFirst('Exception: ', '');
      }),
    ]);

    if (!mounted) return;
    setState(() => loading = false);
  }

  /// 搜尋比對：不分大小寫、忽略空白，「台」「臺」視為同一字
  static String _norm(String text) =>
      text.toLowerCase().replaceAll('台', '臺').replaceAll(RegExp(r'\s'), '');

  List<int> _matches(String query) {
    final q = _norm(query);
    if (q.isEmpty) return const [];
    return [
      for (var i = 0; i < attractions.length; i++)
        if (_norm(attractions[i].name).contains(q) ||
            _norm(attractions[i].city).contains(q))
          i,
    ];
  }

  /// 按 Enter：完全同名優先，否則選第一個符合的；都沒有就提示確認搜尋值
  void _submitSearch(String query) {
    final q = _norm(query);
    if (q.isEmpty) {
      _showOverview();
      return;
    }
    final found = _matches(query);
    if (found.isEmpty) {
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(
          SnackBar(content: Text('查無「${query.trim()}」的資料，請確認搜尋值')),
        );
      return;
    }
    final exact = found.firstWhere(
      (i) => _norm(attractions[i].name) == q,
      orElse: () => found.first,
    );
    ScaffoldMessenger.of(context).hideCurrentSnackBar();
    setState(() => selected = exact);
  }

  void _showOverview() => setState(() => selected = null);

  void _selectByUid(String uid) {
    final index = attractions.indexWhere((item) => item.uid == uid);
    if (index < 0) {
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(const SnackBar(content: Text('這個景點沒有客群分析資料')));
      return;
    }
    setState(() => selected = index);
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
        textTheme: Theme.of(context).textTheme.apply(
          fontFamily: AdminText.family,
          fontFamilyFallback: AdminText.fallback,
        ),
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
                        onPressed: () => _load(refresh: true),
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

    // 景點清單和全台總覽都載不到才整頁顯示錯誤；只壞一邊時另一邊照常顯示
    if (overview == null && attractions.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.error_outline, color: navy, size: 40),
              const SizedBox(height: 12),
              Text(
                [
                  overviewError ?? '全台總覽沒有資料',
                  error ?? '目前沒有景點分析資料',
                ].join('\n'),
                textAlign: TextAlign.center,
                style: const TextStyle(color: muted, fontSize: 13),
              ),
              const SizedBox(height: 16),
              FilledButton(
                onPressed: () => _load(refresh: true),
                style: FilledButton.styleFrom(backgroundColor: blue),
                child: const Text('重新載入'),
              ),
            ],
          ),
        ),
      );
    }

    if (tablet) {
      return Row(
        children: [
          Expanded(flex: 7, child: _dashboard()),
          SizedBox(
            width: maxWidth >= 1100 ? 340 : 290,
            child: _StrategyChatPanel(
              key: ValueKey(spot?.uid ?? 'overview'),
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
          '可查詢 ${attractions.length} 個景點',
          style: const TextStyle(fontSize: 12, color: muted),
        ),
        const SizedBox(width: 12),
        IconButton(
          tooltip: trs('重新載入（重新統計全台資料）'),
          onPressed: () => _load(refresh: true),
          icon: const Icon(Icons.refresh, color: blue),
        ),
      ],
    ),
  );

  Widget _dashboard() {
    final current = spot;
    if (current == null) {
      return ListView(
        padding: const EdgeInsets.all(16),
        children: [_hero(null), const SizedBox(height: 16), ..._overviewSections()],
      );
    }

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

  Widget _hero(VisitorAttraction? current) => Container(
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
        Text(
          current == null ? '全台觀光總覽｜搜尋景點看單一景點客群' : '景點客群洞察',
          style: const TextStyle(color: Colors.white70, fontSize: 13),
        ),
        const SizedBox(height: 12),
        Autocomplete<int>(
          key: ValueKey(current?.uid ?? 'overview'),
          initialValue: TextEditingValue(text: current?.name ?? ''),
          displayStringForOption: (index) => attractions[index].name,
          optionsBuilder: (value) => _matches(value.text),
          onSelected: (index) => setState(() => selected = index),
          fieldViewBuilder: (context, controller, focusNode, onFieldSubmitted) {
            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: controller,
                  focusNode: focusNode,
                  enabled: attractions.isNotEmpty,
                  textInputAction: TextInputAction.search,
                  onSubmitted: _submitSearch,
                  // 按 Enter 後游標留在搜尋框，查無資料時可以直接改字
                  onEditingComplete: () {},
                  style: const TextStyle(fontSize: 15, color: ink),
                  decoration: InputDecoration(
                    hintText: trs(attractions.isEmpty
                        ? '景點清單載入失敗，暫時無法搜尋'
                        : '搜尋景點名稱或縣市，例如：勤美、臺南'),
                    hintStyle: const TextStyle(color: muted, fontSize: 13),
                    prefixIcon: const Icon(Icons.search, color: blue),
                    suffixIcon: IconButton(
                      tooltip: trs('清除搜尋，回到全台總覽'),
                      onPressed: () {
                        controller.clear();
                        _showOverview();
                      },
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
                ),
                // 打字當下就檢查：一個景點或縣市都對不到時提示確認搜尋值
                ValueListenableBuilder<TextEditingValue>(
                  valueListenable: controller,
                  builder: (context, value, _) {
                    final text = value.text.trim();
                    if (text.isEmpty ||
                        text == current?.name ||
                        _matches(text).isNotEmpty) {
                      return const SizedBox.shrink();
                    }
                    return Container(
                      margin: const EdgeInsets.only(top: 8),
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 6,
                      ),
                      decoration: BoxDecoration(
                        color: const Color(0xFFFFF4E5),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(
                            Icons.warning_amber_rounded,
                            size: 16,
                            color: Color(0xFFB45309),
                          ),
                          const SizedBox(width: 6),
                          Flexible(
                            child: Text(
                              '查無「$text」的景點或縣市資料，請確認搜尋值',
                              style: const TextStyle(
                                color: Color(0xFF8A4B08),
                                fontSize: 12,
                              ),
                            ),
                          ),
                        ],
                      ),
                    );
                  },
                ),
              ],
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
        if (current == null) ...[
          const Text(
            '全台觀光總覽',
            style: TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.bold,
              fontSize: 22,
            ),
          ),
          const SizedBox(height: 3),
          Text(
            overview == null
                ? '全台統計載入失敗：${overviewError ?? '沒有資料'}'
                : '資料來源：Neo4j 觀光資料庫｜${overview!.totals.cities} 個縣市・'
                      '${_int(overview!.totals.analyzedAttractions)} 個景點有客群分析',
            style: const TextStyle(color: Colors.white70, fontSize: 12),
          ),
        ] else ...[
          Row(
            children: [
              Expanded(
                child: Text(
                  current.name,
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                    fontSize: 22,
                  ),
                ),
              ),
              TextButton.icon(
                onPressed: _showOverview,
                style: TextButton.styleFrom(foregroundColor: Colors.white),
                icon: const Icon(Icons.public, size: 16),
                label: const Text('回到全台總覽', style: TextStyle(fontSize: 12)),
              ),
            ],
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
        ],
        if (current?.domestic?.years != null) ...[
          const SizedBox(height: 8),
          Text(
            '國內樣本年：${current!.domestic!.years}｜問卷旅次：${current.domestic!.nTrips ?? '—'}',
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
                  maxLines: 2,
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
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(color: blue, fontSize: 12),
          ),
        ],
      ),
    ),
  );

  /// 橫條清單。預設值是百分比（滿格 100）；景點數、人次等用 maxValue＋format
  Widget _chartCard(
    double width,
    String title,
    Map<String, double> values, {
    double? maxValue,
    String Function(double value)? format,
    double labelWidth = 78,
    double valueWidth = 62,
    String? note,
    void Function(String label)? onTap,
  }) {
    final max = maxValue ??
        (format == null
            ? 100.0
            : values.values.fold<double>(0, (a, b) => b > a ? b : a));
    final show = format ?? (double v) => '${v.toStringAsFixed(1)}%';
    return SizedBox(
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
            if (note != null) ...[
              const SizedBox(height: 3),
              Text(note, style: const TextStyle(color: muted, fontSize: 11)),
            ],
            const SizedBox(height: 12),
            if (values.isEmpty)
              const Text('資料未提供', style: TextStyle(color: muted, fontSize: 12)),
            ...values.entries.map(
              (entry) => InkWell(
                onTap: onTap == null ? null : () => onTap(entry.key),
                child: Padding(
                  padding: const EdgeInsets.only(bottom: 9),
                  child: Row(
                    children: [
                      SizedBox(
                        width: labelWidth,
                        child: Tooltip(
                          message: trs(entry.key),
                          child: Text(
                            entry.key,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              color: onTap == null ? ink : blue,
                              fontSize: 11,
                              decoration: onTap == null
                                  ? null
                                  : TextDecoration.underline,
                            ),
                          ),
                        ),
                      ),
                      Expanded(
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(5),
                          child: LinearProgressIndicator(
                            value: max <= 0
                                ? 0
                                : (entry.value / max).clamp(0.0, 1.0),
                            minHeight: 9,
                            backgroundColor: const Color(0xFFEDE0D3),
                            color: blue,
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      SizedBox(
                        width: valueWidth,
                        child: Text(
                          show(entry.value),
                          textAlign: TextAlign.right,
                          style: const TextStyle(color: ink, fontSize: 11),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ===================== 全台總覽（沒選景點時） =====================

  static String _int(num value) => value.round().toString().replaceAllMapped(
    RegExp(r'(\d)(?=(\d{3})+$)'),
    (m) => '${m[1]},',
  );

  /// 人次：中日韓用「萬／万／만」；英文用 K、M（萬換不成英文單位，不能只靠翻譯表）
  static String _people(double value) {
    if (AppLang.code == 'en') {
      if (value >= 1e6) return '${(value / 1e6).toStringAsFixed(1)}M';
      if (value >= 1e4) return '${(value / 1e3).toStringAsFixed(0)}K';
      return _int(value);
    }
    return value >= 10000
        ? '${(value / 10000).toStringAsFixed(1)} 萬'
        : _int(value);
  }

  List<Widget> _overviewSections() {
    final o = overview;
    if (o == null) {
      return [
        _emptyCard('全台統計載入失敗：${overviewError ?? '沒有資料'}。請確認 Neo4j 有開，再按右上角重新載入。'),
      ];
    }

    final t = o.totals;
    return [
      LayoutBuilder(
        builder: (context, constraints) {
          final columns = constraints.maxWidth >= 860
              ? 5
              : (constraints.maxWidth >= 520 ? 3 : 2);
          final width = (constraints.maxWidth - (columns - 1) * 10) / columns;
          return Wrap(
            spacing: 10,
            runSpacing: 10,
            children: [
              _metric(width, Icons.landscape_outlined, '觀光景點', _int(t.attractions), '${t.cities} 個縣市'),
              _metric(width, Icons.hotel_outlined, '旅宿', _int(t.hotels), '民宿、旅館'),
              _metric(width, Icons.restaurant_outlined, '餐廳', _int(t.restaurants), '美食資料'),
              _metric(width, Icons.celebration_outlined, '活動', _int(t.events), '節慶與活動'),
              _metric(
                width,
                Icons.groups_outlined,
                '有客群分析的景點',
                _int(t.analyzedAttractions),
                '國內 ${t.domesticAttractions}・來臺 ${t.inboundAttractions}',
              ),
            ],
          );
        },
      ),
      const SizedBox(height: 20),
      _sectionTitle('給觀光署的改善重點', Icons.tips_and_updates_outlined),
      const SizedBox(height: 4),
      const Text(
        '依下方統計自動整理，可再到右側旅遊智慧助手追問。',
        style: TextStyle(color: muted, fontSize: 12),
      ),
      const SizedBox(height: 10),
      if (o.insights.isEmpty) _emptyCard('目前的資料不足以整理改善重點。'),
      ...o.insights.map(_insightCard),
      const SizedBox(height: 20),
      _sectionTitle('各縣市觀光資源', Icons.map_outlined),
      const SizedBox(height: 10),
      _cityChart(o),
      const SizedBox(height: 20),
      _sectionTitle('國內旅客整體輪廓', Icons.people_alt_outlined),
      const SizedBox(height: 10),
      _profile(o.domestic, inbound: false),
      const SizedBox(height: 20),
      _sectionTitle('來臺旅客整體輪廓', Icons.public),
      const SizedBox(height: 10),
      _profile(o.inbound, inbound: true),
      const SizedBox(height: 20),
      _sectionTitle('人流與活動淡旺季', Icons.show_chart),
      const SizedBox(height: 10),
      LayoutBuilder(
        builder: (context, constraints) {
          final width = constraints.maxWidth >= 760
              ? (constraints.maxWidth - 10) / 2
              : constraints.maxWidth;
          return Wrap(
            spacing: 10,
            runSpacing: 10,
            children: [
              _chartCard(
                width,
                '年平均人流前 10 名（人次）',
                {for (final f in o.topFootfall) '${f.name}（${f.city}）': f.visitorsMean},
                format: _people,
                labelWidth: 130,
                valueWidth: 72,
                note: '有人流資料 ${t.footfallAttractions} 個景點；點景點名稱看該景點客群',
                onTap: (label) {
                  final hit = o.topFootfall.firstWhere(
                    (f) => '${f.name}（${f.city}）' == label,
                  );
                  _selectByUid(hit.uid);
                },
              ),
              SizedBox(
                width: width,
                child: _card(
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        '各月進行中的活動數',
                        style: TextStyle(color: navy, fontWeight: FontWeight.bold, fontSize: 14),
                      ),
                      const SizedBox(height: 3),
                      const Text('跨月活動每個月都算', style: TextStyle(color: muted, fontSize: 11)),
                      const SizedBox(height: 12),
                      SizedBox(
                        height: 220,
                        child: _barChart(
                          o.eventMonths,
                          format: (v) => '${v.round()} 場',
                          vertical: false,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          );
        },
      ),
      const SizedBox(height: 20),
      _sectionTitle('旅宿與景點類型', Icons.category_outlined),
      const SizedBox(height: 10),
      LayoutBuilder(
        builder: (context, constraints) {
          final width = constraints.maxWidth >= 760
              ? (constraints.maxWidth - 10) / 2
              : constraints.maxWidth;
          return Wrap(
            spacing: 10,
            runSpacing: 10,
            children: [
              _pieCard(width, '旅宿類型', o.hotelClasses, unit: '家'),
              _chartCard(
                width,
                '景點分類前 10 名',
                o.attractionCategories,
                format: (v) => '${_int(v)} 個',
                labelWidth: 92,
              ),
            ],
          );
        },
      ),
      const SizedBox(height: 14),
      Text(
        '統計時間：${o.generatedAt == null ? '—' : o.generatedAt!.toLocal().toString().substring(0, 16)}'
        '（每 30 分鐘更新，按右上角重新載入可立即重算）。客群比例依各景點問卷旅次加權，'
        '交通與活動是「列在該景點前三名」的景點占比。',
        style: const TextStyle(color: muted, fontSize: 11, height: 1.5),
      ),
      const SizedBox(height: 24),
    ];
  }

  Widget _insightCard(VisitorOverviewInsight insight) {
    const icons = {
      'transport': Icons.directions_bus_outlined,
      'lodging': Icons.hotel_outlined,
      'crowd': Icons.groups_2_outlined,
      'audience': Icons.elderly_outlined,
      'event': Icons.event_outlined,
      'survey': Icons.fact_check_outlined,
      'data': Icons.dataset_outlined,
    };
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: _card(
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            CircleAvatar(
              radius: 17,
              backgroundColor: const Color(0xFFEDE0D3),
              child: Icon(icons[insight.topic] ?? Icons.lightbulb_outline, color: blue, size: 18),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    insight.title,
                    style: const TextStyle(color: navy, fontWeight: FontWeight.bold, fontSize: 14),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    insight.text,
                    style: const TextStyle(color: ink, fontSize: 13, height: 1.55),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// 各縣市長條圖：上方切換指標，比例類指標畫全台平均線
  Widget _cityChart(VisitorOverview o) {
    final t = o.totals;
    final metrics = <String, (double Function(VisitorOverviewCity), String Function(double), double?)>{
      '景點': ((c) => c.attractions.toDouble(), (v) => '${_int(v)} 個', null),
      '旅宿': ((c) => c.hotels.toDouble(), (v) => '${_int(v)} 家', null),
      '每景點旅宿': (
        (c) => c.hotelsPerAttraction,
        (v) => '${v.toStringAsFixed(1)} 間',
        t.attractions > 0 ? t.hotels / t.attractions : null,
      ),
      '餐廳': ((c) => c.restaurants.toDouble(), (v) => '${_int(v)} 家', null),
      '活動': ((c) => c.events.toDouble(), (v) => '${_int(v)} 場', null),
      '客群分析覆蓋率': (
        (c) => c.analyzedPct,
        (v) => '${v.toStringAsFixed(1)}%',
        t.attractions > 0 ? 100 * t.analyzedAttractions / t.attractions : null,
      ),
      '年平均人流': ((c) => c.footfallMeanSum, (v) => '${_people(v)}人次', null),
    };
    final metric = metrics[cityMetric] ?? metrics['景點']!;
    final sorted = [...o.cities]..sort((a, b) => metric.$1(b).compareTo(metric.$1(a)));

    return _card(
      Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Wrap(
            spacing: 6,
            runSpacing: 6,
            children: [
              for (final name in metrics.keys)
                ChoiceChip(
                  label: Text(name, style: const TextStyle(fontSize: 12)),
                  selected: cityMetric == name,
                  selectedColor: const Color(0xFFEDE0D3),
                  onSelected: (_) => setState(() => cityMetric = name),
                ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            metric.$3 == null
                ? '依數值由高到低排列，點長條看數字'
                : '虛線是全台平均 ${metric.$2(metric.$3!)}；低於平均的縣市是優先改善對象',
            style: const TextStyle(color: muted, fontSize: 11),
          ),
          const SizedBox(height: 12),
          LayoutBuilder(
            builder: (context, constraints) {
              final width = constraints.maxWidth < sorted.length * 32.0
                  ? sorted.length * 32.0
                  : constraints.maxWidth;
              return SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: SizedBox(
                  width: width,
                  height: 280,
                  child: _barChart(
                    {for (final c in sorted) c.city: metric.$1(c)},
                    format: metric.$2,
                    average: metric.$3,
                    vertical: true,
                  ),
                ),
              );
            },
          ),
        ],
      ),
    );
  }

  /// 長條圖；vertical = 底下的標籤直排（縣市名）
  Widget _barChart(
    Map<String, double> data, {
    required String Function(double value) format,
    double? average,
    required bool vertical,
  }) {
    final labels = data.keys.toList();
    final values = data.values.toList();
    final top = [...values, average ?? 0].fold<double>(0, (a, b) => b > a ? b : a);
    return BarChart(
      BarChartData(
        maxY: top <= 0 ? 1 : top * 1.12,
        alignment: BarChartAlignment.spaceAround,
        borderData: FlBorderData(show: false),
        gridData: FlGridData(
          drawVerticalLine: false,
          getDrawingHorizontalLine: (_) =>
              const FlLine(color: Color(0xFFEDE0D3), strokeWidth: 1),
        ),
        titlesData: FlTitlesData(
          topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
          rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
          leftTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              reservedSize: 44,
              // 最上面那格是 maxY（留白用），不標數字
              getTitlesWidget: (value, meta) => value == meta.max
                  ? const SizedBox.shrink()
                  : SideTitleWidget(
                      meta: meta,
                      child: Text(
                        value >= 10000
                            ? (AppLang.code == 'en'
                                  ? _people(value)
                                  : '${(value / 10000).toStringAsFixed(0)}萬')
                            : _shortNum(value),
                        style: const TextStyle(color: muted, fontSize: 10),
                      ),
                    ),
            ),
          ),
          bottomTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              reservedSize: vertical ? (AppLang.contentLang == AppLang.zhTW ? 52 : 74) : 24,
              getTitlesWidget: (value, meta) {
                final i = value.toInt();
                if (i < 0 || i >= labels.length) return const SizedBox.shrink();
                // 中文縣市名一字一行直排；外語先翻成譯名（Taipei City）再斜著放，不要拆字去翻
                if (vertical && AppLang.contentLang != AppLang.zhTW) {
                  return SideTitleWidget(
                    meta: meta,
                    space: 4,
                    angle: -0.9,
                    child: FlutterText(
                      translate(labels[i]),
                      style: const TextStyle(color: ink, fontSize: 9),
                    ),
                  );
                }
                final text = vertical ? labels[i].split('').join('\n') : labels[i];
                return SideTitleWidget(
                  meta: meta,
                  space: 4,
                  child: Text(
                    text,
                    textAlign: TextAlign.center,
                    style: const TextStyle(color: ink, fontSize: 10, height: 1.1),
                  ),
                );
              },
            ),
          ),
        ),
        extraLinesData: ExtraLinesData(
          horizontalLines: [
            if (average != null)
              HorizontalLine(
                y: average,
                color: navy.withValues(alpha: .7),
                strokeWidth: 1.5,
                dashArray: [6, 4],
                label: HorizontalLineLabel(
                  show: true,
                  alignment: Alignment.topRight,
                  style: const TextStyle(color: navy, fontSize: 10, fontWeight: FontWeight.bold),
                  labelResolver: (_) => '全台平均 ${format(average)}',
                ),
              ),
          ],
        ),
        barTouchData: BarTouchData(
          touchTooltipData: BarTouchTooltipData(
            getTooltipColor: (_) => navy,
            maxContentWidth: 160,
            getTooltipItem: (group, groupIndex, rod, rodIndex) => BarTooltipItem(
              trs('${labels[group.x]}\n${format(rod.toY)}'),
              const TextStyle(color: Colors.white, fontSize: 12),
            ),
          ),
        ),
        barGroups: [
          for (var i = 0; i < values.length; i++)
            BarChartGroupData(
              x: i,
              barRods: [
                BarChartRodData(
                  toY: values[i],
                  width: vertical ? 14 : 16,
                  color: average != null && values[i] < average
                      ? const Color(0xFFD4A373)
                      : blue,
                  borderRadius: const BorderRadius.vertical(top: Radius.circular(4)),
                ),
              ],
            ),
        ],
      ),
    );
  }

  static String _shortNum(double value) =>
      value == value.roundToDouble() ? _int(value) : value.toStringAsFixed(1);

  /// 占比：不到 1% 的顯示一位小數，不要變成 0%
  static String _share(double value, double total) {
    final pct = 100 * value / total;
    return '${pct.toStringAsFixed(pct < 1 ? 1 : 0)}%';
  }

  /// 圓餅圖＋圖例
  Widget _pieCard(double width, String title, Map<String, double> values, {required String unit}) {
    final total = values.values.fold<double>(0, (a, b) => a + b);
    final entries = values.entries.toList();
    return SizedBox(
      width: width,
      child: _card(
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(title, style: const TextStyle(color: navy, fontWeight: FontWeight.bold, fontSize: 14)),
            const SizedBox(height: 12),
            if (total <= 0)
              const Text('資料未提供', style: TextStyle(color: muted, fontSize: 12))
            else
              Row(
                children: [
                  SizedBox(
                    width: 120,
                    height: 120,
                    child: PieChart(
                      PieChartData(
                        centerSpaceRadius: 30,
                        sectionsSpace: 1.5,
                        sections: [
                          for (var i = 0; i < entries.length; i++)
                            PieChartSectionData(
                              value: entries[i].value,
                              color: palette[i % palette.length],
                              radius: 28,
                              showTitle: false,
                            ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        for (var i = 0; i < entries.length; i++)
                          Padding(
                            padding: const EdgeInsets.only(bottom: 5),
                            child: Row(
                              children: [
                                Container(
                                  width: 10,
                                  height: 10,
                                  decoration: BoxDecoration(
                                    color: palette[i % palette.length],
                                    borderRadius: BorderRadius.circular(2),
                                  ),
                                ),
                                const SizedBox(width: 6),
                                Expanded(
                                  child: Text(
                                    entries[i].key,
                                    overflow: TextOverflow.ellipsis,
                                    style: const TextStyle(color: ink, fontSize: 11),
                                  ),
                                ),
                                Text(
                                  unit == '%'
                                      ? '${entries[i].value.toStringAsFixed(1)}%'
                                      : '${_int(entries[i].value)} $unit・${_share(entries[i].value, total)}',
                                  style: const TextStyle(color: muted, fontSize: 11),
                                ),
                              ],
                            ),
                          ),
                      ],
                    ),
                  ),
                ],
              ),
          ],
        ),
      ),
    );
  }

  /// 國內／來臺旅客的全台輪廓
  Widget _profile(VisitorOverviewProfile p, {required bool inbound}) {
    if (p.attractions == 0) {
      return _emptyCard(inbound ? '目前沒有來臺旅客分析資料。' : '目前沒有國內旅客分析資料。');
    }
    final stay = inbound ? p.meanNights : p.meanDays;
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
                _metric(width, Icons.place_outlined, '有分析的景點', _int(p.attractions), inbound ? '來臺旅客' : '國內旅客'),
                _metric(width, Icons.assignment_outlined, '問卷旅次', _int(p.trips), '各景點加總'),
                _metric(width, Icons.female_outlined, '女性比例', _pct(p.femalePct), '依旅次加權'),
                _metric(
                  width,
                  Icons.hotel_outlined,
                  inbound ? '平均停留' : '平均旅遊天數',
                  stay == null ? '—' : '${stay.toStringAsFixed(1)} ${inbound ? '夜' : '天'}',
                  '依旅次加權',
                ),
              ],
            );
          },
        ),
        const SizedBox(height: 10),
        LayoutBuilder(
          builder: (context, constraints) {
            final width = constraints.maxWidth >= 590
                ? (constraints.maxWidth - 10) / 2
                : constraints.maxWidth;
            return Wrap(
              spacing: 10,
              runSpacing: 10,
              children: [
                if (p.ageShares.isNotEmpty)
                  _chartCard(width, '年齡結構', p.ageShares, note: '依旅次加權')
                else
                  _chartCard(
                    width,
                    '各景點的主要年齡層',
                    p.mainAges,
                    format: (v) => '${v.round()} 個景點',
                    note: '每個景點最多人的年齡層',
                  ),
                _pieCard(width, '旅遊目的', p.purposes, unit: '%'),
                _chartCard(
                  width,
                  '交通方式',
                  p.transports,
                  labelWidth: 92,
                  note: '列在該景點前三大交通方式的景點占比',
                ),
                _chartCard(
                  width,
                  '旅遊活動',
                  p.activities,
                  labelWidth: 130,
                  note: '列在該景點前三大活動的景點占比',
                ),
                _chartCard(
                  width,
                  '旅客分群',
                  p.clusters,
                  format: (v) => '${v.round()} 個景點',
                  labelWidth: 200,
                ),
              ],
            );
          },
        ),
      ],
    );
  }

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

  /// 沒選景點時問全台
  bool get national => widget.attractionUid.isEmpty;

  late final messages = <_Message>[
    _Message(
      false,
      national
          ? '你好！目前是全台模式，可以問全台客群、各縣市住宿、交通、人潮與活動淡旺季，或請我提供改善建議。搜尋景點後會改成問該景點。'
          : '你好！可以詢問目前景點的國內／來臺旅客客群，或請我提供經營策略建議。',
    ),
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

    setState(() {
      sending = true;
      messages.add(_Message(true, question));
      messages.add(const _Message(false, '思考中…'));
      chatController.clear();
    });
    _scrollToEnd();

    String replyText;
    try {
      final result = national
          ? await VisitorAnalysisApi.chatOverview(question)
          : await VisitorAnalysisApi.chatStrategy(
              attractionUid: widget.attractionUid,
              question: question,
            );
      replyText = result.displayText();
    } catch (e) {
      replyText = '連線失敗：${e.toString().replaceFirst('Exception: ', '')}';
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
                          national
                              ? '全台觀光數據・改善建議'
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
                                data: trs(message.text),
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
                  for (final question in national
                      ? const [
                          '全台主要客群是誰？',
                          '哪些縣市住宿相對不足？',
                          '交通可及性要怎麼改善？',
                          '請提供觀光署三個優先改善建議',
                        ]
                      : const [
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
                        hintText: trs(sending ? '回覆生成中…' : '輸入你的問題…'),
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
