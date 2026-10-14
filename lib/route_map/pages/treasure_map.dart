import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:geolocator/geolocator.dart';
import 'package:latlong2/latlong.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../api/pair_api.dart';
import '../../pages/story_end_page.dart';
import '../api.dart';
import '../models.dart';
import '../route_follow.dart';
import '../theme.dart';
import '../widgets/fog_layer.dart';
import '../widgets/map_kit.dart';
import '../widgets/node_sheets.dart';
import '../widgets/npc_buddy.dart';
import '../widgets/place_ticket.dart';

/// 一個劇本的藏寶圖：景點是一關一關的關卡，進度由後端決定（GET /api/Map/{story_id}）。
/// - 地圖蓋著迷霧，只露出我走過的地方、已解鎖的景點，和走過／正要走的路線
/// - 目前這一關的景點發亮，還沒輪到的景點是暗的（後端只給大概位置和代號）；到了現場才顯示真名
/// - 景點照片也是到了現場才有：還沒抵達的關卡（包含目前這一關）卡片上放的是迷霧圖
/// - 路線只規劃目前這一關（我現在的位置 → 這一關的景點），破關後才出現下一關
/// - 路線跟著我的位置走：走過的部分調淡，亮的部分往景點縮短；偏離路線太遠就從現在的位置重新規劃
///   （計算在 route_follow.dart）。打開展示工具（demoTools）可以模擬行走，坐在電腦前也能示範
/// - 破關：到現場確認抵達，再把這一關的任務做完（在正式 App）；後端有開示範模式時可以直接破關
/// - 周邊好去跟著我的位置更新
class TreasureMap extends StatefulWidget {
  const TreasureMap({
    super.key,
    required this.story,
    this.embedded = false,
    this.onProgress,
    this.onPostcards,
    this.npcAvatar,
    this.isActive,
    this.demoTools = false,
    this.onDoTasks,
    this.onStageCleared,
  });

  final RouteStory story;

  /// 嵌在別的 App 裡（正式 App）：劇本名稱和進度條不畫，那邊的上列自己有；下方面板最底下多留一點空間
  final bool embedded;

  /// 進度變了（載入、破關、重來）：破了幾關、總共幾關。給外面的上列顯示用
  final void Function(int cleared, int total)? onProgress;

  /// 這份劇本的明信片：拿到幾張、總共可以拿幾張（後端跟著進度一起給）。給外面的上列顯示用
  final void Function(int have, int total)? onPostcards;

  /// 地圖上的 NPC 用這個當頭像（正式 App 右下角那隻貓，點了是它自己的功能），放在右下角，提醒的泡泡從它旁邊跳出來。
  /// 沒給就用這份劇本的 NPC 頭像，點了問天氣
  final Widget? npcAvatar;

  /// 這一頁現在是不是在畫面上（例如分頁切走了就不是）；不是的話不去問後端進度。沒給就當成一直都在
  final bool Function()? isActive;

  /// 展示工具：面板上多了「模擬沿路線走」「故意走偏」「模擬隊友」，不用後端開示範模式，坐在電腦前也能展示。
  /// 打開時模擬的位置會被當成真的定位（確認抵達、作答、回報給隊友的都是它），所以預設關閉，正式上線前不要開
  final bool demoTools;

  /// 「做任務」（正式 App 才有）：抵達目前這一關之後，面板上多一顆「做任務」，按了由這裡打開那一關的答題頁。
  /// 送出答案時後端要檢查人在現場，位置用 [myLocation] 跟地圖拿（地圖一直在追蹤的那一個，拿不到是 null）。
  /// 答題頁關掉之後地圖會再問一次後端進度。沒給就沒有這顆按鈕
  final Future<void> Function(
    MapNode node,
    Future<PlacePoint?> Function() myLocation,
  )?
  onDoTasks;

  /// 破了一關：後端的進度說這一關過了才算，不管是自己做完任務、隊友做完，還是示範模式直接破關。[node] 是剛破的那一關。
  /// 正式 App 用來在破關的時候自動跳出這一關的明信片。答題頁開著的時候不會叫，等它關掉、地圖重新問過進度才叫
  final void Function(MapNode node)? onStageCleared;

  @override
  State<TreasureMap> createState() => _TreasureMapState();
}

class _TreasureMapState extends State<TreasureMap> {
  static const _defaultModes = {'步行', '公車', '台灣好行', '捷運'};

  // 迷霧露出的範圍（公尺）：我的位置與破關過的景點、路線與走過的軌跡兩側。目前這一關的範圍由後端決定
  static const _revealVisited = 1200.0;
  static const _revealPath = 1000.0;

  /// 走了這麼遠（公尺）就重新查一次周邊好去
  static const _nearbyRefreshMeters = 150.0;

  static const _distance = Distance();

  final _map = MapController();

  RouteStory get _story => widget.story;

  /// 後端的藏寶圖：每一關解鎖了沒、是不是目前這一關、到了沒、破關了沒。還沒載入時是空的
  List<MapNode> _nodes = [];
  double _revealRadius = 300;
  String? _mapError;

  /// 後端有開示範模式時才看得到開關；打開後「破關」不檢查定位、不用作答
  bool _demoAvailable = false;
  bool _demo = false;

  /// 目前在第幾關（0 起算）；等於景點數表示全部破關
  int get _stage {
    final i = _nodes.indexWhere((n) => n.current);
    return i >= 0 ? i : _nodes.length;
  }

  bool get _finished => _nodes.isNotEmpty && _stage >= _nodes.length;
  MapNode? get _currentNode =>
      _nodes.isEmpty || _finished ? null : _nodes[_stage];

  /// 使用者現在的位置，每一關都從這裡出發。拿不到定位時是 null
  PlacePoint? _myLocation;
  bool _locating = false;
  StreamSubscription<Position>? _positionSub;

  /// 走過的地方（定位軌跡），迷霧會沿著散開
  final List<LatLng> _trail = [];

  /// 我在目前這一關路線上的進度：對到路線上的哪一點、走了多少、還剩多少。還沒有路線或位置時是 null
  RouteProgress? _progress;

  /// 判斷有沒有偏離路線、要不要重新規劃
  final _offRoute = OffRouteDetector();

  /// 模擬行走（展示工具）：定時器在跑表示正在走；_simulated 表示現在的位置是模擬出來的，不是真的定位
  Timer? _simTimer;
  bool _simulated = false;

  /// 模擬的人沿著路線走了多遠、往路線旁邊偏了多遠（公尺）；_simAstray 表示正在故意走偏
  double _simMeters = 0;
  double _simDrift = 0;
  bool _simAstray = false;

  /// 模擬隊友（展示工具）：定時器在跑表示打開了。假的隊友沿著打開時這一關的路線（_matePath）走，
  /// 我之後重新規劃他們也不會跳來跳去；進到下一關、新的路線出來才換過去。_mateSteps 是他們走了幾步
  Timer? _mateTimer;
  RouteOption? _matePath;
  int _mateStage = -1;
  int _mateSteps = 0;

  /// 假的隊友：從路線的哪裡出發（0 是起點、1 是景點）、一步走我的幾倍遠、站在路線旁邊幾公尺
  static const _mates = [
    (name: '小安', from: 0.45, pace: 0.8, side: 0.0), // 走在前面
    (name: '阿哲', from: 0.0, pace: 0.6, side: 12.0), // 落在後面
    (name: '小美', from: 1.0, pace: 0.0, side: 35.0), // 已經在景點等
  ];

  /// 每一關規劃好的路線，破關後留著（地圖上調淡），key 是關卡索引
  final Map<int, RoutePlan> _plans = {};
  final Map<int, int> _chosen = {};
  bool _showSteps = false;

  /// 順路去周邊地點的路線放在 _plans 的這個 key（關卡是 0 以上）
  static const _detourKey = -1;

  /// 順路要去的周邊地點；null = 沒有順路。到這一關的主路線不會消失，兩條都畫在地圖上
  NearbyPlace? _detour;

  /// 現在跟著走的是順路的那一條，還是到這一關的主路線。點地圖上的路線或面板上的「改走這條路線」切換
  bool _detourActive = false;

  /// 現在跟著走的路線在 _plans 的 key
  int get _activeKey =>
      _detourActive && _plans.containsKey(_detourKey) ? _detourKey : _stage;

  Map<String, TransportAvailability> _availability = {};
  final Set<String> _modes = {..._defaultModes};

  /// null = 依螢幕寬度決定（寬螢幕展開、手機收起）
  bool? _legendOpen;

  // 周邊好去：帶「我現在的位置」向後端查，走遠了就重新查；只有在迷霧露出來的範圍裡才看得到
  List<NearbyPlace> _nearby = [];

  /// 上一次是在哪裡查周邊好去的
  LatLng? _nearbyAt;

  // 地圖上打開卡片的地點：周邊好去的地點，或劇本景點（關卡索引），最多一個
  NearbyPlace? _selectedPlace;
  int? _selectedStop;

  bool _checking = false;
  bool _planning = false;

  /// 在地圖上換交通方式後稍等一下才重新規劃，連點幾個只規劃一次
  Timer? _replanTimer;

  /// 正在進入一關（等定位、查交通方式、規劃路線）；_fixWait 是等定位的上限
  bool _entering = false;
  Timer? _fixWait;

  // 地圖上的 NPC：平常只是角落的頭像，時間到（用餐時間、開始下雨）才跳出對話泡泡。用這份劇本的 NPC
  String? _npcName;
  String? _npcAvatar;

  /// 現在的對話泡泡；kind 是 'meal'（用餐提醒，places 是附近的店家）或 'weather'
  ({String kind, String text, IconData icon, List<NearbyPlace> places})?
  _bubble;
  bool _npcBusy = false;

  /// 每 5 分鐘問後端一次有沒有要提醒的事；_bubbleTimer 讓泡泡過一陣子自己收起來
  Timer? _npcTimer;
  Timer? _bubbleTimer;

  /// 後端說要提醒、還在排隊等著跳出來的（一次只跳一個泡泡）；_reminded 是已經跳過的 key，存在手機裡
  final List<
    ({
      String key,
      ({String kind, String text, IconData icon, List<NearbyPlace> places})
      bubble,
    })
  >
  _reminderQueue = [];
  static const _remindedPref = 'npc_reminded_keys';
  Set<String>? _reminded;
  bool _remindersBusy = false;

  // 一起玩的隊友：每 8 秒回報自己的位置並拿回隊友的，畫在地圖上
  List<Teammate> _team = [];
  Timer? _teamTimer;
  bool _teamBusy = false;

  /// 查不到隊友（沒有隊伍、後端沒開）時先跳過幾次，不要每 8 秒打一次
  int _teamSkip = 0;

  /// 正在確認抵達／破關／重來
  bool _advancing = false;

  /// 答題頁開著（按了「做任務」還沒關掉）
  bool _inTasks = false;
  List<MetroLine> _metroLines = [];
  Timer? _progressTimer;

  @override
  void initState() {
    super.initState();
    _loadMetroLines();
    WidgetsBinding.instance.addPostFrameCallback((_) => _start());
    // 任務是在正式 App 裡完成的：定時問後端進度，那邊破關了這裡就會跟著開下一關
    _progressTimer = Timer.periodic(
      const Duration(seconds: 20),
      (_) => _pollProgress(),
    );
    _npcTimer = Timer.periodic(
      const Duration(minutes: 5),
      (_) => _pollReminders(),
    );
    _teamTimer = Timer.periodic(const Duration(seconds: 8), (_) => _pollTeam());
  }

  @override
  void dispose() {
    _progressTimer?.cancel();
    _npcTimer?.cancel();
    _bubbleTimer?.cancel();
    _teamTimer?.cancel();
    _replanTimer?.cancel();
    _fixWait?.cancel();
    _simTimer?.cancel();
    _mateTimer?.cancel();
    _positionSub?.cancel();
    super.dispose();
  }

  // ─────────────────────────── 關卡進度（後端） ───────────────────────────

  Future<void> _start() async {
    await _loadMap();
    if (!mounted || _nodes.isEmpty) return;
    _pollTeam();
    await _enterStage();
  }

  /// 向後端拿藏寶圖：每一關的狀態。迷霧中的關卡後端只給大概位置和代號
  Future<void> _loadMap() async {
    try {
      final result =
          await Api.instance.get('/api/Map/${_story.storyId}')
              as Map<String, dynamic>;
      if (mounted) setState(() => _applyMap(TreasureMapData.fromJson(result)));
    } catch (e) {
      if (mounted) setState(() => _mapError = '$e');
    }
  }

  void _applyMap(TreasureMapData data) {
    // 後端有開示範模式：預設就用示範模式（坐在電腦前展示用），也可以關掉改用真的定位
    if (data.demoMode && !_demoAvailable) _demo = true;
    if (!data.demoMode) _demo = false;
    _demoAvailable = data.demoMode;
    _nodes = data.nodes;
    _revealRadius = data.revealRadius;
    _mapError = null;
    // 這裡常常是在 setState 裡面被呼叫，等這一幀畫完再告訴外面，外面才能放心 setState
    final cleared = _stage, total = _nodes.length;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      widget.onProgress?.call(cleared, total);
      widget.onPostcards?.call(data.postcardCount, data.postcardTotal);
    });
  }

  /// 後端回來新的進度：破關了就進下一關；只是抵達，提示還要完成任務。
  /// [asked] 是使用者自己按按鈕問的，沒有變化時要回一句話；定時檢查的不用
  void _onProgress(TreasureMapData data, {bool asked = false}) {
    final before = _stage;
    final wasArrived = _currentNode?.arrived ?? false;
    setState(() => _applyMap(data));
    final after = _stage;

    if (after > before) {
      final cleared = _nodes[before];
      _stopSim();
      setState(() {
        _selectedPlace = null;
        _selectedStop = null;
        _showSteps = false;
        _progress = null;
        _dropDetour();
      });
      _snack(
        _finished
            ? '全部破關！最後一關是「${cleared.label}」'
            : '第 ${before + 1} 關破關，這裡是「${cleared.label}」。下一關：${_nodes[after].label}',
        Pal.moss,
      );
      _enterStage();
      widget.onStageCleared?.call(cleared);
    } else if (after < before) {
      // 進度被重設（示範模式的重來）
      _stopSim();
      setState(() {
        _plans.clear();
        _chosen.clear();
        _dropDetour();
        _selectedPlace = null;
        _selectedStop = null;
        _showSteps = false;
        _progress = null;
      });
      _enterStage();
    } else if (!wasArrived && (_currentNode?.arrived ?? false)) {
      _snack('已抵達「${_currentNode!.label}」。把這一關的任務做完，下一關才會解鎖', Pal.gold);
    } else if (asked && !_finished) {
      _snack('這一關的任務還沒全部完成，完成後下一關才會解鎖', Pal.inkSoft);
    }
  }

  /// 定時檢查進度（不出聲）：正式 App 那邊抵達或破關了，這裡跟著更新。
  /// 答題頁開著的時候不檢查：破關要等它關掉才處理，不然破關的明信片會跳在答題頁上面
  Future<void> _pollProgress() async {
    if (!mounted ||
        _nodes.isEmpty ||
        _finished ||
        _advancing ||
        _inTasks ||
        !(widget.isActive?.call() ?? true))
      return;
    try {
      final result =
          await Api.instance.get('/api/Map/${_story.storyId}')
              as Map<String, dynamic>;
      if (mounted && !_advancing) _onProgress(TreasureMapData.fromJson(result));
    } catch (_) {}
  }

  /// 「我到了」：用定位向後端確認抵達（要在景點 200 公尺內）。抵達後把這一關的任務做完，下一關才會解鎖。
  /// 已經抵達過再按，是重新檢查任務做完了沒。示範模式：不檢查定位、不用作答，後端直接把這一關當成破關。
  Future<void> _advance() async {
    final node = _currentNode;
    if (node == null || _advancing) return;
    setState(() => _advancing = true);
    try {
      Object? result;
      if (_demo) {
        result = await Api.instance.post(
          '/api/Map/Node/${node.nodeId}/DemoClear',
          const <String, Object?>{},
        );
      } else {
        if (!node.arrived) {
          await _locate();
          final me = _myLocation;
          if (me == null) throw ApiException('拿不到定位，無法確認抵達');
          await Api.instance.post(
            '/api/Map/Node/${node.nodeId}/Arrive',
            const <String, Object?>{},
            query: {'lat': me.lat, 'lng': me.lng},
          );
        }
        result = await Api.instance.get('/api/Map/${_story.storyId}');
      }
      if (mounted)
        _onProgress(
          TreasureMapData.fromJson(result as Map<String, dynamic>),
          asked: true,
        );
    } catch (e) {
      if (mounted) showError(context, e);
    } finally {
      if (mounted) setState(() => _advancing = false);
    }
  }

  /// 「做任務」：打開正式 App 的答題頁（[TreasureMap.onDoTasks]）。回來之後問一次後端進度，這一關的任務全部通過了就開下一關
  Future<void> _doTasks() async {
    final node = _currentNode;
    final open = widget.onDoTasks;
    if (node == null || open == null || _advancing || _inTasks) return;
    _inTasks = true;
    try {
      await open(node, () async {
        // 地圖還沒定到位（剛開、定位很慢）就再定一次
        if (_myLocation == null && mounted) await _locate();
        return _myLocation;
      });
    } finally {
      _inTasks = false;
    }
    if (!mounted || _advancing) return;
    setState(() => _advancing = true);
    try {
      final result = await Api.instance.get('/api/Map/${_story.storyId}');
      if (mounted)
        _onProgress(TreasureMapData.fromJson(result as Map<String, dynamic>));
    } catch (e) {
      if (mounted) showError(context, e);
    } finally {
      if (mounted) setState(() => _advancing = false);
    }
  }

  /// 示範模式的「重來」：後端把這份劇本的進度退回第一關
  Future<void> _restart() async {
    if (_advancing) return;
    setState(() => _advancing = true);
    try {
      final result = await Api.instance.post(
        '/api/Map/${_story.storyId}/DemoReset',
        const <String, Object?>{},
      );
      if (!mounted) return;
      _stopSim();
      setState(() {
        _plans.clear();
        _chosen.clear();
        _dropDetour();
        _selectedPlace = null;
        _selectedStop = null;
        _showSteps = false;
        _progress = null;
        _applyMap(TreasureMapData.fromJson(result as Map<String, dynamic>));
      });
      _enterStage();
    } catch (e) {
      if (mounted) showError(context, e);
    } finally {
      if (mounted) setState(() => _advancing = false);
    }
  }

  void _snack(String text, Color color) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(backgroundColor: color, content: Text(text)));
  }

  // ─────────────────────────── 關卡 ───────────────────────────

  PlacePoint _pointOf(MapNode n) =>
      PlacePoint(lat: n.point.latitude, lng: n.point.longitude, name: n.label);

  /// 拿不到定位時從哪裡出發：第一關是劇本的建議起點，之後是上一關的景點
  PlacePoint? get _fallbackOrigin {
    if (_stage == 0 || _nodes.isEmpty) return _story.suggestedStart;
    final previous = _nodes[math.min(_stage, _nodes.length) - 1];
    return previous.hasPoint ? _pointOf(previous) : _story.suggestedStart;
  }

  /// 這一關從哪裡出發：我現在的位置
  PlacePoint? get _origin => _myLocation ?? _fallbackOrigin;

  /// 這一關要去哪：目前關卡的景點（已解鎖，後端給的是精確位置）；查不到座標時是 null
  PlacePoint? get _target => _currentNode == null || !_currentNode!.hasPoint
      ? null
      : _pointOf(_currentNode!);

  RouteOption? _optionOf(int stage) {
    final legs = _plans[stage]?.legs ?? const <RouteLeg>[];
    if (legs.isEmpty || legs.first.options.isEmpty) return null;
    return legs.first.options[(_chosen[stage] ?? 0).clamp(
      0,
      legs.first.options.length - 1,
    )];
  }

  /// 進入一關：鏡頭對到我的位置與這一關的景點，查附近的周邊好去和交通方式，規劃過去的路線。
  /// 已經有位置（定位一直在追蹤，或是模擬行走的位置）就直接用。還沒有位置才定位，而且最多等 4 秒：
  /// 定位還沒回來就先從上一關（第一關是建議起點）規劃，讓路線先出來；定位到了再從我的位置重新規劃
  Future<void> _enterStage() async {
    _fitStage();
    _loadNpc();
    if (_finished || _nodes.isEmpty) {
      _pollReminders();
      return;
    }
    final stage = _stage;
    setState(() => _entering = true);
    try {
      if (_myLocation == null) {
        final located = _locate();
        final waited = Completer<bool>();
        _fixWait = Timer(const Duration(seconds: 4), () {
          if (!waited.isCompleted) waited.complete(false);
        });
        located.then((_) {
          if (!waited.isCompleted) waited.complete(true);
        });
        final inTime = await waited.future;
        _fixWait?.cancel();
        if (!inTime) located.then((_) => _onLateFix(stage));
      }
      if (mounted) await _planFromOrigin();
    } finally {
      if (mounted) setState(() => _entering = false);
    }
    // 路線出來了才問 NPC 有沒有要提醒的事，不跟載入中的畫面搶
    _pollReminders();
  }

  /// 用現在的出發地查周邊好去和可用的交通方式，規劃這一關的路線
  Future<void> _planFromOrigin() async {
    _fitStage();
    _loadNearby();
    await _checkAvailability();
    if (mounted) await _replanAll();
  }

  /// 重新規劃到這一關的主路線；有順路的話那一條也從現在的位置重新規劃
  Future<void> _replanAll() async {
    await _planRoute();
    if (mounted && _detour != null) await _planDetour(refresh: true);
  }

  /// 路線已經先從別的地方規劃了，定位才回來：等手上的規劃做完，再從我的位置重新規劃
  Future<void> _onLateFix(int stage) async {
    while (mounted && (_entering || _checking || _planning)) {
      await Future<void>.delayed(const Duration(milliseconds: 200));
    }
    if (mounted && _myLocation != null && stage == _stage && !_finished)
      await _planFromOrigin();
  }

  /// 抓使用者現在的位置。拿不到（沒給權限、逾時）就維持上一次的位置；從來沒拿到過，這一關改從上一關的景點出發。
  /// 正在用模擬行走的位置時不抓：不然每進一關，人就從模擬走到的地方跳回真的位置（按「重新定位」才換回來）
  Future<void> _locate() async {
    if (_simulated && _myLocation != null) return;
    setState(() => _locating = true);
    try {
      // 整個定位（含問權限）最多等 20 秒：權限視窗沒有回答時瀏覽器不會回來，不能讓它一直卡在定位中
      final pos = await () async {
        var permission = await Geolocator.checkPermission();
        if (permission == LocationPermission.denied)
          permission = await Geolocator.requestPermission();
        if (permission == LocationPermission.denied ||
            permission == LocationPermission.deniedForever) {
          throw '沒有定位權限';
        }
        return Geolocator.getCurrentPosition(
          locationSettings: const LocationSettings(
            accuracy: LocationAccuracy.high,
            timeLimit: Duration(seconds: 10),
          ),
        );
      }().timeout(const Duration(seconds: 20));
      if (!mounted) return;
      setState(() {
        _myLocation = PlacePoint(
          lat: pos.latitude,
          lng: pos.longitude,
          name: '我的位置',
        );
        _addTrail(LatLng(pos.latitude, pos.longitude));
      });
      _watchPosition();
    } catch (e) {
      if (mounted && _myLocation == null) {
        final fallback = _fallbackOrigin?.name;
        final why = e is TimeoutException ? '等太久沒有回應' : '$e';
        showError(
          context,
          fallback == null ? '無法取得定位（$why）' : '無法取得定位（$why），這一關先從 $fallback 出發',
        );
      }
    } finally {
      if (mounted) setState(() => _locating = false);
    }
  }

  /// 持續追蹤位置（每移動 10 公尺更新一次）：走過的地方迷霧散開，走遠了周邊好去跟著更新，
  /// 路線跟著縮短，偏離路線太遠就自動重新規劃
  void _watchPosition() {
    if (_positionSub != null) return;
    try {
      _positionSub = Geolocator.getPositionStream(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.high,
          distanceFilter: 10,
        ),
      ).listen(_onPosition, onError: (_) {});
    } catch (_) {}
  }

  /// 真的定位。正在模擬行走時不理它，免得兩個位置搶來搶去
  void _onPosition(Position pos) {
    if (_simulated) return;
    _onFix(LatLng(pos.latitude, pos.longitude), accuracy: pos.accuracy);
  }

  /// 位置更新了（真的定位或模擬行走都走這裡）：迷霧散開、路線跟著縮短、偏離太遠就重新規劃。
  /// [accuracy] 是定位的誤差半徑（公尺）
  void _onFix(LatLng here, {double accuracy = 0}) {
    if (!mounted) return;
    setState(() {
      _myLocation = PlacePoint(
        lat: here.latitude,
        lng: here.longitude,
        name: '我的位置',
      );
      _addTrail(here);
      _updateProgress();
    });
    if (_nearbyAt == null ||
        _distance(_nearbyAt!, here) >= _nearbyRefreshMeters)
      _loadNearby();
    _checkOffRoute(accuracy);
  }

  void _addTrail(LatLng p) {
    if (_trail.isEmpty || _distance(_trail.last, p) >= 30) _trail.add(p);
  }

  /// 「重新定位」：重新抓位置（模擬行走的位置也換回真的定位），抓到後這一關的路線從新的位置重新規劃。
  /// 定位要等一下，原本的路線先留在畫面上，不然定位回來之前什麼都看不到
  Future<void> _relocate() async {
    _stopSim();
    setState(() {
      _simulated = false;
      _progress = null;
    });
    await _locate();
    if (mounted && !_finished) await _planFromOrigin();
  }

  // ─────────────────────────── 跟著位置走 ───────────────────────────

  /// 把我的位置對到現在跟著走的路線上（到這一關的主路線，或順路的那一條），算出走到哪裡。
  /// 進度只會往前，最多退 30 公尺（定位飄動）：路線繞回來時才不會跳回前面走過的那一段
  void _updateProgress() {
    final option = _optionOf(_activeKey), me = _myLocation;
    _progress = option == null || me == null
        ? null
        : locateOnRoute(
            option,
            me.latLng,
            minDone: (_progress?.doneMeters ?? 0) - 30,
          );
  }

  /// 換了一條路線（重新規劃、換交通方式）：進度與偏離的累計都從頭算
  void _resetFollow() {
    _progress = null;
    _offRoute.reset();
    _updateProgress();
  }

  /// 我是不是在路線上（離路線不超過門檻）。在的話地圖上的「我」貼在路線上，路線才不會跟人之間有空隙
  bool get _onRoute {
    final option = _optionOf(_activeKey), progress = _progress;
    if (option == null || progress == null) return false;
    return progress.offMeters <=
        offRouteThreshold(option.segments[progress.segment].mode);
  }

  /// 偏離路線就重新規劃：離路線超過門檻連續兩次才算，重新規劃後 12 秒內不再重算（OffRouteDetector）
  void _checkOffRoute(double accuracy) {
    final option = _optionOf(_activeKey), progress = _progress;
    if (option == null || progress == null || _planning || _finished) return;
    final seg = option.segments[progress.segment];
    final reroute = _offRoute.update(
      offMeters: progress.offMeters,
      mode: seg.mode,
      onRide: seg.isRide,
      accuracy: accuracy,
    );
    if (reroute) {
      _offRoute.rerouted();
      _activeKey == _detourKey
          ? _planDetour(auto: true)
          : _planRoute(auto: true);
    }
  }

  // ─────────────────────────── 模擬行走、模擬隊友（展示工具） ───────────────────────────

  /// 開始／暫停模擬行走：每 0.6 秒沿著目前這一關的路線往前走一步，把位置當成定位送進 _onFix，
  /// 走的是跟真的定位一樣的流程（路線縮短、偏離重新規劃）
  void _toggleSim() => _simTimer == null ? _startSim() : _stopSim();

  void _startSim() {
    if (_optionOf(_activeKey) == null || _simTimer != null) return;
    setState(() {
      _simulated = true;
      _simMeters = _progress?.doneMeters ?? 0;
      _simDrift = 0;
      _simTimer = Timer.periodic(
        const Duration(milliseconds: 600),
        (_) => _simStep(),
      );
    });
  }

  void _stopSim() {
    if (_simTimer == null && !_simAstray) return;
    _simTimer?.cancel();
    _simTimer = null;
    _simAstray = false;
    if (mounted) setState(() {});
  }

  void _simStep() {
    final option = _optionOf(_activeKey);
    if (!mounted || option == null || _planning) return; // 重新規劃中：等新路線出來再走
    final total = routeMeters(option);
    if (total <= 0) {
      _stopSim();
      return;
    }

    // 一步走多遠：整條路線大約 60 步走完，最少 15 公尺；故意走偏時每一步再往旁邊偏 30 公尺
    _simMeters = math.min(total, _simMeters + math.max(15.0, total / 60));
    if (_simAstray) _simDrift += 30;
    _onFix(pointOnRoute(option, _simMeters, drift: _simDrift));

    if (_simMeters >= total && !_simAstray && _simTimer != null) {
      _stopSim();
      // 我的位置已經在景點了：示範模式可以直接破關，不然就用這個位置確認抵達
      final next = _demo
          ? '，可以破關'
          : ((_currentNode?.arrived ?? true) ? '' : '，按「我到了」確認抵達');
      _snack(
        _activeKey == _detourKey
            ? '模擬走到「${_detour?.name ?? '順路的地點'}」了'
            : '模擬走到「${_currentNode?.label ?? '這一關'}」了$next',
        Pal.moss,
      );
    }
  }

  /// 故意走偏：模擬的人開始離開路線，偏到超過門檻就會觸發重新規劃
  void _simGoAstray() {
    setState(() => _simAstray = true);
    _startSim();
  }

  /// 開／關模擬隊友
  void _toggleMates() {
    if (_mateTimer != null) {
      _mateTimer!.cancel();
      setState(() {
        _mateTimer = null;
        _matePath = null;
      });
      return;
    }
    setState(
      () => _mateTimer = Timer.periodic(
        const Duration(milliseconds: 600),
        (_) => _mateStep(),
      ),
    );
    _mateStep();
  }

  /// 假的隊友往前走一步。剛打開、或進到新的一關而且路線出來了：換成這一關的路線，從頭走
  void _mateStep() {
    if (!mounted) return;
    final option = _optionOf(_stage) ?? _optionOf(_activeKey);
    setState(() {
      if (option != null && (_matePath == null || _mateStage != _stage)) {
        _matePath = option;
        _mateStage = _stage;
        _mateSteps = 0;
      } else {
        _mateSteps++;
      }
    });
  }

  /// 假的隊友現在的位置；沒打開、或路線還沒出來時是空的
  List<({String name, LatLng point})> get _fakeTeam {
    final path = _matePath;
    if (path == null) return const [];
    final total = routeMeters(path);
    final step = math.max(15.0, total / 60); // 跟我模擬行走的一步一樣遠
    return [
      for (final m in _mates)
        (
          name: m.name,
          point: pointOnRoute(
            path,
            math.min(total, total * m.from + _mateSteps * step * m.pace),
            drift: m.side,
          ),
        ),
    ];
  }

  // ─────────────────────────── 資料 ───────────────────────────

  /// 周邊好去（/api/Map/{story_id}/Nearby）：帶我現在的位置去查，後端由近到遠回傳。
  /// 劇本自己的關卡後端不會放進來，所以不會把迷霧中的景點洩漏出來
  Future<void> _loadNearby() async {
    final here = _origin?.latLng;
    if (here == null) return;
    _nearbyAt = here;
    try {
      final result =
          await Api.instance.get('/api/Map/${_story.storyId}/Nearby', {
                'lat': here.latitude,
                'lng': here.longitude,
                'radius_m': 1000,
                'limit': 50,
              })
              as List;
      final places = result
          .cast<Map<String, dynamic>>()
          .map(NearbyPlace.fromJson)
          .where((p) => p.point != null)
          .toList();
      if (!mounted) return;
      setState(() {
        _nearby = places;
        if (_selectedPlace != null &&
            !places.any((p) => p.key == _selectedPlace!.key))
          _selectedPlace = null;
      });
    } catch (_) {
      // 周邊好去只是參考資訊，查不到不影響路線規劃
    }
  }

  /// 查這一關的出發地與景點附近有沒有公車、捷運；不能用的交通方式反灰
  Future<void> _checkAvailability() async {
    final origin = _origin, target = _target;
    if (origin == null || target == null) return;
    setState(() => _checking = true);
    try {
      final result = await Api.instance.post('/api/Route/Availability', [
        origin.toJson(),
        target.toJson(),
      ]);
      final list = (result as List).cast<Map<String, dynamic>>().map(
        TransportAvailability.fromJson,
      );
      if (!mounted) return;
      setState(() {
        _availability = {for (final a in list) a.mode: a};
        if (_modes.every((m) => _availability[m]?.enabled == false))
          _modes.add('步行');
      });
    } catch (e) {
      if (mounted) showError(context, e);
    } finally {
      if (mounted) setState(() => _checking = false);
    }
  }

  /// 點地圖上的交通方式：勾選或取消，稍等一下自動重新規劃。附近沒有的（反灰）點了只說明原因
  void _toggleMode(String mode) {
    final availability = _availability[mode];
    if (availability?.enabled == false) {
      _snack('$mode：${availability!.reason}', Pal.gold);
      return;
    }
    setState(() {
      _modes.contains(mode) ? _modes.remove(mode) : _modes.add(mode);
      if (_modes.isEmpty) _modes.add('步行');
    });
    _replanTimer?.cancel();
    _replanTimer = Timer(const Duration(milliseconds: 700), _replanWhenIdle);
  }

  /// 上一次規劃還沒回來就再等一下，免得兩次的結果互相蓋掉
  void _replanWhenIdle() {
    if (!mounted || _finished) return;
    if (_planning || _entering || _checking) {
      _replanTimer = Timer(const Duration(milliseconds: 300), _replanWhenIdle);
      return;
    }
    _replanAll();
  }

  // ─────────────────────────── 順路去周邊地點 ───────────────────────────

  /// 周邊地點卡片上的「前往」：在這張地圖上規劃一條過去的路線並改走這一條。
  /// 到這一關的主路線留在地圖上（調淡），點它就切回去
  Future<void> _goToPlace(NearbyPlace place) async {
    if (place.point == null) return;
    if (_origin == null) {
      _snack('還不知道從哪裡出發，先按地圖右上的「重新定位」', Pal.gold);
      return;
    }
    _stopSim();
    setState(() {
      // 換了一個要去的地點：上一個順路的路線不留
      if (_detour?.key != place.key) {
        _plans.remove(_detourKey);
        _chosen.remove(_detourKey);
      }
      _detour = place;
      _selectedPlace = null;
    });
    await _planDetour();
  }

  /// 規劃順路的路線：我的位置 → 那個地點，跟主路線用同一支 API（不帶劇本，只帶要去的點）。
  /// [auto]：走順路時偏離了，自動重新規劃；[refresh]：重新定位或換了交通方式。這兩種都沿用原本選的方案、鏡頭不動，
  /// 也不改變現在跟著走的是哪一條
  Future<void> _planDetour({bool auto = false, bool refresh = false}) async {
    final place = _detour, origin = _origin;
    if (place == null || place.point == null || origin == null) return;
    final to = place.point!;
    final previousMode = _optionOf(_detourKey)?.mode;
    setState(() => _planning = true);
    try {
      final result = await Api.instance.post('/api/Route/Plan', {
        'start': origin.toJson(),
        'points': [
          PlacePoint(
            lat: to.latitude,
            lng: to.longitude,
            name: place.name,
          ).toJson(),
        ],
        'transportation': allModes
            .where(
              (m) => _modes.contains(m) && _availability[m]?.enabled != false,
            )
            .toList(),
        'include_return': false,
      });
      if (!mounted || _detour?.key != place.key) return;
      final plan = RoutePlan.fromJson(result as Map<String, dynamic>);
      final options = plan.legs.isEmpty
          ? const <RouteOption>[]
          : plan.legs.first.options;
      final keep = auto || refresh
          ? options.indexWhere((o) => o.mode == previousMode)
          : -1;
      setState(() {
        _plans[_detourKey] = plan;
        keep > 0 ? _chosen[_detourKey] = keep : _chosen.remove(_detourKey);
        if (!auto && !refresh) _detourActive = true;
        _resetFollow();
        _simMeters = 0;
        _simDrift = 0;
        _simAstray = false;
      });
      if (auto) {
        _snack('偏離路線，已從現在的位置重新規劃', Pal.gold);
      } else if (!refresh) {
        WidgetsBinding.instance.addPostFrameCallback((_) => _fitStage());
      }
    } catch (e) {
      if (!mounted) return;
      showError(context, e);
      // 第一次就規劃不出來：不留著一個沒有路線的順路
      if (!_plans.containsKey(_detourKey)) setState(_dropDetour);
    } finally {
      if (mounted) setState(() => _planning = false);
    }
  }

  /// 順路的路線和要去的地點都拿掉（不重畫，放在 setState 裡呼叫）
  void _dropDetour() {
    _plans.remove(_detourKey);
    _chosen.remove(_detourKey);
    _detour = null;
    _detourActive = false;
  }

  /// 「結束順路」：順路的路線拿掉，回到這一關的主路線。人可能已經走開了，主路線從現在的位置重新規劃
  void _endDetour() {
    _stopSim();
    setState(() {
      _dropDetour();
      _resetFollow();
    });
    if (!_finished) _planRoute();
  }

  /// 改走另一條：順路的路線，或到這一關的主路線。兩條都留在地圖上
  void _setActive({required bool detour}) {
    if (_detourActive == detour) return;
    setState(() {
      _detourActive = detour;
      _resetFollow();
      _simMeters = 0;
      _simDrift = 0;
    });
    _fitStage();
  }

  /// 點地圖：點到另一條路線就改走那一條（同一段路的其他方案、順路的路線或主路線），沒點到路線就關掉卡片。
  /// 不用地圖元件的點擊偵測，自己算點的位置離每條線多遠（跟「我離路線多遠」同一個算法）
  void _onMapTap(LatLng tap) {
    final active = _activeKey;
    final chosen = _optionOf(active);
    // 螢幕上 22 像素以內算點到，換算成公尺
    final reach =
        22 *
        156543.03392 *
        math.cos(tap.latitudeInRad) /
        math.pow(2, _map.camera.zoom);
    double off(RouteOption option) => option.segments
        .map((s) => snapToLine(s.points, tap)?.offMeters ?? double.infinity)
        .fold(double.infinity, (a, b) => math.min(a, b));

    // 離點的地方最近的那一條：(在 _plans 的 key, 第幾個方案, 多遠)
    (int, int, double)? best;
    void consider(int key, int index, RouteOption option) {
      final meters = off(option);
      if (meters <= reach && (best == null || meters < best!.$3))
        best = (key, index, meters);
    }

    if (chosen != null) {
      final options = _plans[active]!.legs.first.options;
      for (var k = 0; k < options.length; k++) {
        if (!identical(options[k], chosen)) consider(active, k, options[k]);
      }
    }
    final other = active == _detourKey ? _stage : _detourKey;
    final otherOption = _optionOf(other);
    if (otherOption != null)
      consider(
        other,
        (_chosen[other] ?? 0).clamp(
          0,
          _plans[other]!.legs.first.options.length - 1,
        ),
        otherOption,
      );

    // 兩條線疊在一起的地方（離現在走的這條一樣近）不切換
    final hit = best;
    if (hit != null && (chosen == null || hit.$3 < off(chosen))) {
      setState(() {
        _detourActive = hit.$1 == _detourKey;
        _chosen[hit.$1] = hit.$2;
        _resetFollow();
        _simMeters = 0;
        _simDrift = 0;
      });
      return;
    }
    if (_card != null) _closeCard();
  }

  /// 附近的捷運路網，淡淡地畫在底圖上
  Future<void> _loadMetroLines() async {
    final center =
        _story.suggestedStart?.latLng ??
        (_story.nodes.isEmpty ? null : _story.nodes.first.point);
    if (center == null) return;
    try {
      final result =
          await Api.instance.get('/api/Metro/Lines', {
                'lat': center.latitude,
                'lng': center.longitude,
                'radius_km': 15,
              })
              as List;
      if (mounted)
        setState(
          () => _metroLines = result
              .cast<Map<String, dynamic>>()
              .map(MetroLine.fromJson)
              .toList(),
        );
    } catch (_) {}
  }

  /// 規劃這一關的路線：我的位置 → 這一關的景點。帶劇本代號給後端，後端只規劃到目前這一關，
  /// 沒有定位時後端自己決定從哪裡出發（第一關：建議起點；之後：上一關）。
  /// [auto]：偏離路線時自動重新規劃。跟手動按的是同一支 API，差別只有：沿用原本選的交通方式、鏡頭不動
  Future<void> _planRoute({bool auto = false}) async {
    final stage = _stage;
    final origin = _origin;
    if (_currentNode == null) return;
    final previousMode = _optionOf(stage)?.mode;
    setState(() => _planning = true);
    try {
      final result = await Api.instance.post('/api/Route/Plan', {
        'story_id': _story.storyId,
        if (origin != null) 'start': origin.toJson(),
        'transportation': allModes
            .where(
              (m) => _modes.contains(m) && _availability[m]?.enabled != false,
            )
            .toList(),
        'include_return': false,
        'current_only': true,
      });
      if (!mounted || stage != _stage) return;
      final plan = RoutePlan.fromJson(result as Map<String, dynamic>);
      final options = plan.legs.isEmpty
          ? const <RouteOption>[]
          : plan.legs.first.options;
      final keep = auto
          ? options.indexWhere((o) => o.mode == previousMode)
          : -1;
      setState(() {
        _plans[stage] = plan;
        keep > 0 ? _chosen[stage] = keep : _chosen.remove(stage);
        // 新路線從我現在的位置出發：進度、偏離的累計、模擬行走都從頭算
        _resetFollow();
        _simMeters = 0;
        _simDrift = 0;
        _simAstray = false;
      });
      if (auto) {
        _snack('偏離路線，已從現在的位置重新規劃', Pal.gold);
      } else {
        WidgetsBinding.instance.addPostFrameCallback((_) => _fitStage());
      }
    } catch (e) {
      if (mounted) showError(context, e);
    } finally {
      if (mounted) setState(() => _planning = false);
    }
  }

  // ─────────────────────────── 地圖上的 NPC ───────────────────────────

  /// 地圖上的 NPC 用這份劇本的 NPC：目前這一關的（全部破關後用最後一關的；後端沒指定時是預設的薯光）
  Future<void> _loadNpc() async {
    if (_nodes.isEmpty) return;
    final node = _currentNode ?? _nodes.last;
    if (!node.unlocked) return;
    try {
      final r =
          await Api.instance.get('/api/Map/Node/${node.nodeId}/Interact')
              as Map<String, dynamic>;
      if (!mounted) return;
      setState(() {
        _npcName = r['npc_name'] as String?;
        _npcAvatar = r['npc_avatar_url'] as String?;
      });
    } catch (_) {
      // 查不到就用預設的頭像，NPC 一樣可以說話
    }
  }

  /// NPC 要不要自己跳出來由後端判斷（GET /api/Map/Reminders）：快下雨、太熱、到了用餐時間而且附近有店…才會回提醒，
  /// 沒事回空的。地圖開著時每 5 分鐘帶目前位置問一次（進入一關、路線出來後也問一次）。
  /// 每一則提醒有一個 key：還沒跳過的才排進去跳，同一個 key 不再跳（同一種天氣 3 小時內、同一餐一天內 key 一樣）
  Future<void> _pollReminders() async {
    final here = _origin?.latLng;
    if (!mounted || here == null || _remindersBusy) return;
    _remindersBusy = true;
    try {
      final r =
          await Api.instance.get('/api/Map/Reminders', {
                'lat': here.latitude,
                'lng': here.longitude,
                'story_id': _story.storyId,
              })
              as Map<String, dynamic>;
      final reminded = await _loadReminded();
      for (final item
          in ((r['reminders'] as List?) ?? const [])
              .cast<Map<String, dynamic>>()) {
        final key = item['key'] as String? ?? '';
        final message = (item['message'] as String? ?? '').trim();
        if (key.isEmpty ||
            message.isEmpty ||
            reminded.contains(key) ||
            _reminderQueue.any((q) => q.key == key))
          continue;
        final meal = item['type'] == 'meal';
        _reminderQueue.add((
          key: key,
          bubble: (
            kind: meal ? 'meal' : 'weather',
            text: message,
            icon: meal
                ? Icons.restaurant
                : weatherIcon(
                    (item['weather'] as Map<String, dynamic>?)?['condition']
                        as String?,
                  ),
            places: _foodPlaces(item['places']),
          ),
        ));
      }
      _nextReminder();
    } catch (_) {
      // 問不到（後端沒開、網路斷了）就安靜，下一次再問
    } finally {
      _remindersBusy = false;
    }
  }

  /// 輪到下一則提醒：一次只跳一個泡泡，前一個收起來才輪到下一個。跳出來的同時把 key 記起來
  void _nextReminder() {
    if (!mounted || _bubble != null || _reminderQueue.isEmpty) return;
    final next = _reminderQueue.removeAt(0);
    _markReminded(next.key);
    _showBubble(next.bubble);
  }

  /// 已經跳過的提醒，存在手機裡，App 重開也記得
  Future<Set<String>> _loadReminded() async {
    if (_reminded != null) return _reminded!;
    try {
      _reminded = {
        ...?(await SharedPreferences.getInstance()).getStringList(
          _remindedPref,
        ),
      };
    } catch (_) {
      _reminded = {};
    }
    return _reminded!;
  }

  Future<void> _markReminded(String key) async {
    final reminded = await _loadReminded();
    reminded.add(key);
    try {
      // 只留最近 60 個：key 裡有日期，舊的不會再出現
      final keys = reminded.toList();
      await (await SharedPreferences.getInstance()).setStringList(
        _remindedPref,
        keys.sublist(math.max(0, keys.length - 60)),
      );
    } catch (_) {}
  }

  /// 後端回的店家（用餐提醒、NearbyFood 的 places）
  List<NearbyPlace> _foodPlaces(Object? places) =>
      ((places as List?) ?? const [])
          .cast<Map<String, dynamic>>()
          .map(NearbyPlace.food)
          .where((p) => p.point != null)
          .toList();

  /// 使用者自己點 NPC 問：向後端要一句話放進泡泡。'meal' = 附近吃什麼（GET /api/Map/NearbyFood，連店家一起回來），
  /// 'weather' = 現在的天氣（GET /api/Map/Weather）。這兩支不管天氣好不好、是不是用餐時間都會回答
  Future<void> _npcSay(String kind) async {
    final here = _origin?.latLng;
    if (here == null || _npcBusy) return;
    setState(() => _npcBusy = true);
    try {
      final query = {'lat': here.latitude, 'lng': here.longitude};
      if (kind == 'meal') {
        final r =
            await Api.instance.get('/api/Map/NearbyFood', query)
                as Map<String, dynamic>;
        final places = _foodPlaces(r['places']);
        final message = (r['message'] as String? ?? '').trim();
        _showBubble((
          kind: kind,
          text: message.isNotEmpty
              ? message
              : (places.isEmpty
                    ? '這附近暫時找不到吃的。'
                    : '附近有 ${places.length} 間店家可以吃。'),
          icon: Icons.restaurant,
          places: places,
        ));
      } else {
        final r =
            await Api.instance.get('/api/Map/Weather', query)
                as Map<String, dynamic>;
        final message = (r['message'] as String? ?? '').trim();
        _showBubble((
          kind: kind,
          text: message.isEmpty ? '現在查不到天氣。' : message,
          icon: weatherIcon(r['condition'] as String?),
          places: const [],
        ));
      }
    } catch (e) {
      if (mounted) showError(context, e);
    } finally {
      if (mounted) setState(() => _npcBusy = false);
    }
  }

  /// 跳出泡泡，15 秒後自己收起來
  void _showBubble(
    ({String kind, String text, IconData icon, List<NearbyPlace> places})
    bubble,
  ) {
    if (!mounted) return;
    setState(() => _bubble = bubble);
    _bubbleTimer?.cancel();
    _bubbleTimer = Timer(const Duration(seconds: 15), _hideBubble);
  }

  /// 泡泡收起來；還有排隊中的提醒就接著跳下一則
  void _hideBubble() {
    _bubbleTimer?.cancel();
    if (mounted && _bubble != null) setState(() => _bubble = null);
    _nextReminder();
  }

  Widget _npcBuddy() {
    final bubble = _bubble;
    return NpcBuddy(
      avatar: widget.npcAvatar,
      name: _npcName,
      avatarUrl: _npcAvatar,
      busy: _npcBusy,
      kind: bubble?.kind,
      text: bubble?.text,
      icon: bubble?.icon,
      // 點頭像：泡泡開著就收起來，沒開就問天氣
      onTap: () => bubble != null ? _hideBubble() : _npcSay('weather'),
      onAsk: _npcSay,
      onClose: _hideBubble,
      actionLabel: bubble == null || bubble.places.isEmpty
          ? null
          : '看 ${bubble.places.length} 間店家',
      onAction: bubble == null || bubble.places.isEmpty
          ? null
          : () {
              _hideBubble();
              showFoodPlaces(
                context,
                places: bubble.places,
                onPick: _showPlace,
              );
            },
    );
  }

  // ─────────────────────────── 隊友的位置 ───────────────────────────

  /// 回報自己的位置並拿回隊友各自最後的位置（POST /api/Pair/Story/{story_id}/Location）。
  /// 沒有定位時只看不回報（GET …/Locations）。模擬行走的位置照樣回報：展示時隊友才看得到我在走。
  /// 自己和還沒回報過位置的隊友不畫
  Future<void> _pollTeam() async {
    if (!mounted || _teamBusy) return;
    if (_teamSkip > 0) {
      _teamSkip--;
      return;
    }
    _teamBusy = true;
    try {
      final me = _myLocation;
      final path = '/api/Pair/Story/${_story.storyId}/Location';
      final r =
          (me == null
                  ? await Api.instance.get('${path}s')
                  : await Api.instance.post(path, {
                      'lat': me.lat,
                      'lng': me.lng,
                    }))
              as Map<String, dynamic>;
      final team = ((r['members'] as List?) ?? const [])
          .cast<Map<String, dynamic>>()
          .map(Teammate.fromJson)
          .where((t) => !t.isMe && t.point != null)
          .toList();
      if (mounted) setState(() => _team = team);
    } catch (_) {
      _teamSkip = 7;
    } finally {
      _teamBusy = false;
    }
  }

  // ─────────────────────────── 迷霧 ───────────────────────────

  /// 迷霧露出來的地點：每一關出發的地方、我現在的位置，和已解鎖的景點（破關過的、目前這一關）
  List<(LatLng, double)> get _revealSpots => [
    for (final plan in _plans.values) (plan.start.latLng, _revealVisited),
    if (_origin != null) (_origin!.latLng, _revealVisited),
    for (final n in _nodes)
      if (n.unlocked && n.hasPoint)
        (
          n.point,
          n.current ? _revealRadius : math.max(_revealRadius, _revealVisited),
        ),
    // 打開卡片的和順路要去的地點周圍露出一小塊，不然標記會被霧蓋住
    for (final p in _pinnedPlaces) (p.point!, 150.0),
  ];

  /// 迷霧露出來的路線：走過的每一關、目前這一關規劃好的路線，和我實際走過的軌跡
  List<List<LatLng>> get _revealPaths => [
    for (final stage in _plans.keys)
      for (final s in _optionOf(stage)?.segments ?? const <RouteSegment>[])
        s.points,
    if (_trail.length >= 2) _trail,
  ];

  bool _isRevealed(LatLng p) =>
      _revealSpots.any((s) => _distance(p, s.$1) <= s.$2 * 0.85) ||
      _trail.any((t) => _distance(p, t) <= _revealPath * 0.85);

  List<NearbyPlace> get _visibleNearby =>
      _nearby.where((p) => _isRevealed(p.point!)).toList();

  /// 打開卡片的和順路要去的周邊地點。從景點的「周邊好去」清單選的地點可能不在我附近，所以另外記
  List<NearbyPlace> get _pinnedPlaces => [
    for (final p in [?_selectedPlace, ?_detour])
      if (p.point != null) p,
  ];

  /// 地圖上畫出來的周邊地點：迷霧露出來的，加上 [_pinnedPlaces]
  List<NearbyPlace> get _shownNearby {
    final shown = _visibleNearby;
    for (final p in _pinnedPlaces) {
      // 順路走回破關過的景點：景點自己有印章，不用再畫一個周邊地點的標記
      if (p.key.startsWith('node-')) continue;
      // 同一間店從用餐提醒和周邊好去來的代號不一樣，名字和位置一樣就當成同一個
      final same = shown.any(
        (s) =>
            s.key == p.key ||
            (s.name == p.name && _distance(s.point!, p.point!) < 15),
      );
      if (!same) shown.add(p);
    }
    return shown;
  }

  // ─────────────────────────── 卡片與鏡頭 ───────────────────────────

  /// 目前打開的卡片。景點：抵達後顯示真名、可以導航；還沒抵達的目前這一關只給代號和迷霧圖當線索（真實照片後端抵達後才給）；還沒輪到的是未解鎖
  ({NearbyPlace place, String? title, String? note, bool locked})? get _card {
    final stop = _selectedStop;
    if (stop != null && stop < _nodes.length) {
      final node = _nodes[stop];
      // 不給開 Google 地圖的連結：要去破關過的景點是在這張地圖上規劃路線（卡片的 onGo）
      final place = NearbyPlace.node(node, navigable: false);
      if (!node.unlocked) {
        return (
          place: place,
          title: node.label,
          note: '第 ${stop + 1} 關，破完前面的關卡才會解鎖',
          locked: true,
        );
      }
      if (node.current) {
        final note = node.arrived
            ? '已抵達，任務做完才會解鎖下一關'
            : (node.title.isEmpty ? '目前關卡' : node.title);
        return (
          place: place,
          title: node.label,
          note: '第 ${stop + 1} 關・$note',
          locked: false,
        );
      }
      return (
        place: place,
        title: null,
        note: '第 ${stop + 1} 關・已破關',
        locked: false,
      );
    }
    final place = _selectedPlace;
    if (place == null) return null;
    // 距離自己算：從景點的「周邊好去」清單選的地點，後端給的距離是離那個景點，不是離我
    final me = _myLocation?.latLng;
    final meters = me == null || place.point == null
        ? null
        : _distance(me, place.point!).round();
    final distance = meters == null
        ? null
        : '離你 ${meters < 1000 ? '$meters m' : '${(meters / 1000).toStringAsFixed(1)} km'}';
    final status = switch (place.isOpenNow) {
      true => '營業中',
      false => '休息中',
      null => null,
    };
    final note = [?distance, ?status].join('・');
    return (
      place: place,
      title: null,
      note: note.isEmpty ? null : note,
      locked: false,
    );
  }

  /// 點地圖上的景點或從關卡選單選：打開它的卡片（地圖上再點一次關掉），地圖移到看得到的位置
  void _showStop(int index, {double? zoom}) {
    final open = _selectedStop != index || zoom != null;
    setState(() {
      _selectedStop = open ? index : null;
      _selectedPlace = null;
    });
    if (open && _nodes[index].hasPoint)
      _focusOn(_nodes[index].point, zoom: zoom);
  }

  /// 點地圖上的周邊好去地點
  void _showPlace(NearbyPlace place) {
    final open = _selectedPlace?.key != place.key;
    setState(() {
      _selectedPlace = open ? place : null;
      _selectedStop = null;
    });
    if (open) _focusOn(place.point!);
  }

  void _closeCard() => setState(() {
    _selectedPlace = null;
    _selectedStop = null;
  });

  /// 鏡頭對到這一關：有路線就看整段路線，還沒有就看我的位置與景點；全部破關後看所有景點
  void _fitStage() {
    try {
      final route = [
        for (final s
            in _optionOf(_activeKey)?.segments ?? const <RouteSegment>[])
          ...s.points,
      ];
      final node = _currentNode;
      final points = route.isNotEmpty
          ? route
          : node == null
          ? [
              for (final n in _nodes)
                if (n.hasPoint) n.point,
            ]
          : [
              if (_origin != null) _origin!.latLng,
              if (node.hasPoint) node.point,
            ];
      fitTo(_map, points, padding: mapFitPadding(context, base: 70));
    } catch (_) {}
  }

  /// 把地圖移到這個點，不拉遠。點要落在沒被蓋住的地方：
  /// 手機上卡片在地圖上緣、面板從下方拉起（約 42% 高），放在兩者中間；寬螢幕卡片在左下，稍微往上。
  void _focusOn(LatLng point, {double? zoom}) {
    try {
      final camera = _map.camera;
      final height = camera.nonRotatedSize.height;
      final wide = MediaQuery.sizeOf(context).width >= 900;
      final dy = wide ? -30.0 : (210 + height * 0.58) / 2 - height / 2;
      _map.move(
        point,
        math.max(camera.zoom, zoom ?? camera.zoom),
        offset: Offset(0, dy),
      );
    } catch (_) {}
  }

  // ─────────────────────────── 畫面 ───────────────────────────

  @override
  Widget build(BuildContext context) {
    if (_nodes.isEmpty) {
      return ColoredBox(
        color: Pal.parchment,
        child: Center(
          child: _mapError == null
              ? const CircularProgressIndicator()
              : Padding(
                  padding: const EdgeInsets.all(24),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        _mapError!,
                        textAlign: TextAlign.center,
                        style: const TextStyle(color: Pal.cinnabar),
                      ),
                      const SizedBox(height: 12),
                      FilledButton.icon(
                        onPressed: () {
                          setState(() => _mapError = null);
                          _start();
                        },
                        icon: const Icon(Icons.refresh),
                        label: const Text('重試'),
                      ),
                    ],
                  ),
                ),
        ),
      );
    }
    return MapWithPanel(
      map: _buildMap(),
      panel: _buildPanel,
      floating: _npcBuddy(),
      floatingRight: widget.npcAvatar != null,
    );
  }

  Widget _buildMap() {
    final routeLines = <Polyline>[];
    final rideStops = <Marker>[];
    final arrows = <Marker>[];
    final badges = <Marker>[];

    // 走過的路線調淡：前面的關卡整段調淡；目前這一關從我的位置切開，走過的調淡、還沒走的是亮的，
    // 所以人往前走，亮的部分就往景點縮短。只有亮的部分畫箭頭、站牌和交通方式徽章
    // 現在跟著走的那一條最後畫，在最上面
    final active = _activeKey;
    for (final stage in [
      ..._plans.keys.where((k) => k != active),
      if (_plans.containsKey(active)) active,
    ]) {
      final option = _optionOf(stage);
      if (option == null) continue;

      // 同一段路的其他方案：灰色的線墊在下面，點了就改走那一條（_onMapTap）
      if (stage == active) {
        for (final other in _plans[stage]!.legs.first.options) {
          if (identical(other, option)) continue;
          for (final seg in other.segments) {
            if (seg.points.length < 2) continue;
            routeLines.add(
              Polyline(
                points: seg.points,
                color: const Color(0xCC8A7F70),
                strokeWidth: 5,
                borderStrokeWidth: 2,
                borderColor: const Color(0xCCFFFFFF),
              ),
            );
          }
        }
      }

      // 還能改走的另一條（順路時的主路線，或走主路線時的順路）比走過的關卡亮一點，看得出來可以點
      final selectable =
          stage != active && (stage == _stage || stage == _detourKey);
      final split = splitRoute(option, stage == active ? _progress : null);
      final parts = [
        for (final (seg, points) in split.passed) (seg, points, false),
        for (final (seg, points) in split.ahead) (seg, points, stage == active),
      ];

      for (final (seg, points, bright) in parts) {
        if (points.length < 2) continue;
        final alpha = bright ? 1.0 : (selectable ? 0.65 : 0.45);
        final style = modeStyle(seg.mode, lineColor: seg.color);
        final color = seg.mode == '捷運' ? seg.color : style.color;

        routeLines.add(
          Polyline(
            points: points,
            color: color.withValues(alpha: alpha),
            strokeWidth: style.width,
            pattern: style.pattern,
            borderStrokeWidth: style.casing ? 2.5 : 0,
            borderColor: Colors.white.withValues(alpha: alpha),
          ),
        );
        if (!bright) continue;

        arrows.addAll(arrowMarkers(points, color));

        if (seg.isRide) {
          for (final stop in seg.stops) {
            rideStops.add(
              Marker(
                point: stop.latLng,
                width: 11,
                height: 11,
                child: Container(
                  decoration: BoxDecoration(
                    color: Colors.white,
                    shape: BoxShape.circle,
                    border: Border.all(color: color, width: 2.5),
                  ),
                ),
              ),
            );
          }
        }

        // 步行只在整段都是步行時放徽章，搭車前後的短步行不放，避免太亂
        final showBadge =
            seg.mode != '轉乘' && (seg.mode != '步行' || option.mode == '步行');
        if (showBadge) {
          badges.add(
            Marker(
              point: midpoint(points),
              width: 140,
              height: 30,
              child: Center(
                child: ModeBadge(
                  mode: seg.mode,
                  color: color,
                  label: seg.isRide ? seg.routeName : null,
                ),
              ),
            ),
          );
        }
      }
    }

    final wide = MediaQuery.sizeOf(context).width >= 900;
    final card = _card;
    final cardStop = _selectedStop;
    final cardNode =
        cardStop != null &&
            cardStop < _nodes.length &&
            _nodes[cardStop].unlocked
        ? _nodes[cardStop]
        : null;
    final myLocation = _myLocation;
    // 拿不到定位時，第一關從劇本的建議起點出發，在地圖上標出來（之後的關卡是從上一關的景點，已經有印章）
    final start = myLocation == null && _stage == 0
        ? _story.suggestedStart
        : null;

    return Stack(
      children: [
        FlutterMap(
          mapController: _map,
          options: MapOptions(
            initialCenter: _nodes
                .firstWhere((n) => n.hasPoint, orElse: () => _nodes.first)
                .point,
            initialZoom: 15,
            interactionOptions: mapInteraction,
            onTap: (_, point) => _onMapTap(point),
          ),
          children: [
            treasureTiles(),
            // 捷運路網（淡色背景）
            PolylineLayer(
              polylines: [
                for (final line in _metroLines)
                  for (final part in line.shape)
                    Polyline(
                      points: part,
                      color: line.color.withValues(alpha: 0.35),
                      strokeWidth: 4,
                    ),
              ],
            ),
            PolylineLayer(polylines: routeLines),
            MarkerLayer(markers: rideStops),
            MarkerLayer(markers: arrows),
            MarkerLayer(markers: badges, rotate: true),
            MarkerLayer(
              markers: [for (final p in _shownNearby) _nearbyMarker(p)],
              rotate: true,
            ),
            // 迷霧蓋在底圖、路線和周邊地點上面；景點印章畫在迷霧上面，還沒輪到的景點才看得到位置
            FogLayer(
              spots: _revealSpots,
              paths: _revealPaths,
              pathMeters: _revealPath,
            ),
            MarkerLayer(
              markers: [
                if (start != null)
                  sealMarker(
                    start.latLng,
                    '起',
                    label: start.name,
                    color: Pal.ink,
                  ),
                // 一起玩的隊友：紫色印章，太久沒回報位置的畫成淡的
                for (final mate in _team)
                  sealMarker(
                    mate.point!,
                    mate.name.isEmpty ? '友' : mate.name.characters.first,
                    label: mate.name.isEmpty ? '隊友' : mate.name,
                    color: Pal.plum,
                    faded: !mate.online,
                  ),
                // 展示工具的模擬隊友：跟真的隊友同一種印章
                for (final mate in _fakeTeam)
                  sealMarker(
                    mate.point,
                    mate.name.characters.first,
                    label: mate.name,
                    color: Pal.plum,
                  ),
                // 在路線上時「我」貼在路線上（定位會飄，貼上去才不會跟亮的路線之間有空隙）；偏離時畫在真正的位置
                if (myLocation != null)
                  sealMarker(
                    _onRoute ? _progress!.point : myLocation.latLng,
                    '我',
                    label: myLocation.name,
                    color: Pal.ink,
                  ),
                // 先畫還在迷霧中的（位置是後端給的迷霧中心），目前這一關畫在最上面
                for (final i in [
                  for (var k = _nodes.length - 1; k >= 0; k--)
                    if (!_nodes[k].unlocked) k,
                  for (var k = 0; k < _nodes.length; k++)
                    if (_nodes[k].unlocked && !_nodes[k].current) k,
                  if (!_finished) _stage,
                ])
                  if (_nodes[i].hasPoint)
                    sealMarker(
                      _nodes[i].point,
                      '${i + 1}',
                      label: _nodes[i].label,
                      color: _nodes[i].unlocked && !_nodes[i].current
                          ? Pal.moss
                          : Pal.cinnabar,
                      look: _nodes[i].current
                          ? SealLook.glow
                          : (_nodes[i].unlocked
                                ? SealLook.normal
                                : SealLook.dark),
                      onTap: () => _showStop(i),
                    ),
              ],
            ),
            osmAttribution(),
          ],
        ),
        Positioned(left: 12, top: 12, child: _legend()),
        if (!_finished) Positioned(top: 12, right: 12, child: _mapControls()),
        if (card != null)
          Positioned(
            left: 12,
            right: 12,
            top: wide ? null : 56,
            bottom: wide ? 28 : null,
            child: Align(
              alignment: wide ? Alignment.bottomLeft : Alignment.topCenter,
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 400),
                child: PlaceTicket(
                  place: card.place,
                  title: card.title,
                  note: card.note,
                  locked: card.locked,
                  compact: !wide,
                  onClose: _closeCard,
                  // 「前往」在這張地圖上規劃路線過去，不開外部地圖：周邊地點，和破關過的景點（想走回去看看）。
                  // 目前這一關不用：進關卡就自動規劃好路線了；還沒解鎖的不能去
                  onGo:
                      (cardStop == null
                          ? card.place.point != null
                          : cardNode != null &&
                                !cardNode.current &&
                                cardNode.hasPoint)
                      ? () => _goToPlace(card.place)
                      : null,
                  // 已解鎖的劇本景點：跟正式 App 地圖頁的彈窗一樣有周邊好去、查看任務、回顧劇情。
                  // 查看任務和回顧劇情要抵達之後才有：還沒到現場，任務還不能做（後端會擋），劇情也還沒發生，沒有東西可以回顧。
                  // 「開始導航」不用：進關卡就自動規劃好路線了
                  buttons: cardNode == null
                      ? const []
                      : [
                          if (cardNode.hasPoint)
                            (
                              label: '周邊好去',
                              onTap: () => showNodeNearby(
                                context,
                                storyId: _story.storyId,
                                node: cardNode,
                                onPick: _showPlace,
                              ),
                            ),
                          if (cardNode.arrived)
                            (
                              label: '查看任務',
                              onTap: () => showNodeTasks(context, cardNode),
                            ),
                        ],
                  link: cardNode == null || !cardNode.arrived
                      ? null
                      : (
                          label: '回顧劇情 >>',
                          onTap: () => showStoryReview(context, cardNode),
                        ),
                ),
              ),
            ),
          ),
      ],
    );
  }

  /// 周邊好去的地點標記：飲食是金色刀叉、其他是綠色相機，選中的放大加深色框
  Marker _nearbyMarker(NearbyPlace p) {
    final selected = _selectedPlace?.key == p.key || _detour?.key == p.key;
    final size = selected ? 32.0 : 26.0;
    return Marker(
      point: p.point!,
      width: size,
      height: size,
      child: GestureDetector(
        onTap: () => _showPlace(p),
        child: Tooltip(
          message: p.name,
          child: _nearbyIcon(p.isFood, size: size, selected: selected),
        ),
      ),
    );
  }

  static Widget _nearbyIcon(
    bool food, {
    double size = 26,
    bool selected = false,
  }) => Container(
    width: size,
    height: size,
    decoration: BoxDecoration(
      color: food ? Pal.gold : Pal.moss,
      borderRadius: BorderRadius.circular(size * 0.28),
      border: Border.all(
        color: selected ? Pal.ink : Colors.white,
        width: selected ? 2.5 : 2,
      ),
      boxShadow: const [BoxShadow(color: Color(0x55000000), blurRadius: 3)],
    ),
    child: Icon(
      food ? Icons.restaurant : Icons.local_see,
      size: size * 0.58,
      color: Colors.white,
    ),
  );

  /// 地圖右上的按鈕：交通方式（勾選的是實心、附近沒有的反灰，點一下切換並自動重新規劃）和重新定位
  Widget _mapControls() {
    Widget button({
      required String tooltip,
      required VoidCallback? onTap,
      required Widget child,
      Color? fill,
    }) => Tooltip(
      message: tooltip,
      child: Material(
        color: fill ?? const Color(0xF2EFE5CB),
        elevation: 2,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(8),
          side: BorderSide(
            color: fill == null ? PlaceTicket.frame : Colors.white,
            width: 1.3,
          ),
        ),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onTap,
          child: SizedBox(width: 36, height: 36, child: Center(child: child)),
        ),
      ),
    );

    Widget modeButton(String mode) {
      final availability = _availability[mode];
      final enabled = availability?.enabled != false;
      final selected = enabled && _modes.contains(mode);
      return button(
        tooltip: enabled ? mode : '$mode：${availability!.reason}',
        onTap: () => _toggleMode(mode),
        fill: selected ? modeStyle(mode).color : null,
        child: Icon(
          modeStyle(mode).icon,
          size: 20,
          color: selected
              ? Colors.white
              : (enabled ? Pal.inkSoft : Pal.disabled),
        ),
      );
    }

    Widget column(List<Widget> buttons) => Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        for (final b in buttons)
          Padding(padding: const EdgeInsets.only(bottom: 4), child: b),
      ],
    );

    // 排成兩排，不排成一長排：螢幕矮的時候最下面的按鈕會被面板蓋住。
    // 左邊是自己移動的（步行、腳踏車、機車、汽車），右邊是大眾運輸（公車、台灣好行、捷運）和重新定位
    const transit = ['公車', '台灣好行', '捷運'];
    return Row(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        column([
          for (final mode in allModes)
            if (!transit.contains(mode)) modeButton(mode),
        ]),
        const SizedBox(width: 4),
        column([
          for (final mode in allModes)
            if (transit.contains(mode)) modeButton(mode),
          button(
            tooltip: '重新定位',
            onTap: _locating ? null : _relocate,
            child: _locating || _checking || _planning
                ? const SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : Icon(
                    _myLocation != null
                        ? Icons.my_location
                        : Icons.location_disabled,
                    size: 20,
                    color: Pal.ink,
                  ),
          ),
        ]),
      ],
    );
  }

  /// 圖例：關卡的三種狀態、各交通方式的線型、周邊好去。手機上預設收起（展開會蓋掉快一半的地圖），點一下切換。
  Widget _legend() {
    final open = _legendOpen ?? MediaQuery.sizeOf(context).width >= 900;
    Widget row(Widget icon, String label) => Padding(
      padding: const EdgeInsets.symmetric(vertical: 1.5),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          icon,
          Text(' $label', style: const TextStyle(fontSize: 11, color: Pal.ink)),
        ],
      ),
    );
    Widget dot(
      Color color, {
      Color border = const Color(0xFFF7E7C4),
      bool glow = false,
    }) => Container(
      width: 14,
      height: 14,
      decoration: BoxDecoration(
        color: color,
        shape: BoxShape.circle,
        border: Border.all(color: border, width: 1.5),
        boxShadow: [
          if (glow)
            const BoxShadow(
              color: Color(0xE6FFD76A),
              blurRadius: 6,
              spreadRadius: 2,
            ),
        ],
      ),
    );

    return Material(
      color: const Color(0xEEF3E4C1),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(8),
        side: const BorderSide(color: Pal.inkSoft),
      ),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: () => setState(() => _legendOpen = !open),
        child: Padding(
          padding: const EdgeInsets.all(8),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.legend_toggle, size: 14, color: Pal.ink),
                  const Text(
                    ' 圖例',
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.bold,
                      color: Pal.ink,
                    ),
                  ),
                  Icon(
                    open ? Icons.expand_less : Icons.expand_more,
                    size: 16,
                    color: Pal.ink,
                  ),
                ],
              ),
              if (open) ...[
                const SizedBox(height: 4),
                row(dot(Pal.cinnabar, glow: true), '目前這一關'),
                row(dot(Pal.moss), '已破關'),
                row(
                  dot(const Color(0xFF4A3F35), border: const Color(0xFF8C7B66)),
                  '還沒解鎖',
                ),
                const Divider(height: 8),
                for (final mode in allModes)
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 1.5),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          modeStyle(mode).icon,
                          size: 14,
                          color: modeStyle(mode).color,
                        ),
                        const SizedBox(width: 4),
                        SizedBox(
                          width: 34,
                          height: 8,
                          child: CustomPaint(
                            painter: _LineSample(modeStyle(mode)),
                          ),
                        ),
                        const SizedBox(width: 4),
                        Text(
                          mode,
                          style: const TextStyle(fontSize: 11, color: Pal.ink),
                        ),
                      ],
                    ),
                  ),
                if (_nearby.isNotEmpty) ...[
                  const Divider(height: 8),
                  row(_nearbyIcon(true, size: 16), '周邊飲食'),
                  row(_nearbyIcon(false, size: 16), '周邊景點・其他'),
                ],
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildPanel(ScrollController? controller) {
    final total = _nodes.length;
    return ListView(
      controller: controller,
      // 最底下讓出系統和外面導覽列的高度（正式 App 的導覽列是浮在頁面上面的），最後一顆按鈕才不會被蓋住
      padding: EdgeInsets.fromLTRB(
        16,
        8,
        16,
        24 + MediaQuery.paddingOf(context).bottom,
      ),
      children: [
        if (controller != null)
          Center(
            child: Container(
              width: 40,
              height: 4,
              margin: const EdgeInsets.only(bottom: 10),
              decoration: BoxDecoration(
                color: Pal.inkSoft,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
        // 劇本與進度。嵌在正式 App 裡時進度條不畫：那邊上列的「地點探索度」就是同一個數字（onProgress）
        Text(
          _story.title,
          style: const TextStyle(
            fontSize: 17,
            fontWeight: FontWeight.bold,
            color: Pal.ink,
          ),
        ),
        if (!widget.embedded) ...[
          const SizedBox(height: 6),
          Row(
            children: [
              Expanded(
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(4),
                  child: LinearProgressIndicator(
                    value: total == 0 ? 0 : _stage / total,
                    minHeight: 8,
                    color: Pal.moss,
                    backgroundColor: Pal.parchmentDeep,
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Text(
                '已破 $_stage / $total 關',
                style: const TextStyle(fontSize: 12, color: Pal.inkSoft),
              ),
            ],
          ),
        ],
        const SizedBox(height: 12),
        // 關卡：破關過的和目前這一關可以選，地圖移過去並打開卡片；還沒輪到的鎖著
        DropdownButtonFormField<int>(
          initialValue: total == 0
              ? null
              : (_selectedStop ?? _stage).clamp(0, total - 1),
          key: ValueKey('stage-$_stage-$_selectedStop'),
          isExpanded: true,
          decoration: const InputDecoration(
            labelText: '關卡',
            border: OutlineInputBorder(),
            isDense: true,
          ),
          items: [
            for (var i = 0; i < total; i++)
              DropdownMenuItem(
                value: i,
                enabled: _nodes[i].unlocked,
                child: Row(
                  children: [
                    Icon(
                      _nodes[i].current
                          ? Icons.flag
                          : (_nodes[i].unlocked
                                ? Icons.check_circle
                                : Icons.lock_outline),
                      size: 16,
                      color: _nodes[i].current
                          ? Pal.cinnabar
                          : (_nodes[i].unlocked ? Pal.moss : Pal.disabled),
                    ),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Text(
                        '${i + 1}. ${_nodes[i].label}',
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          color: _nodes[i].unlocked ? null : Pal.disabled,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
          ],
          onChanged: (v) {
            if (v != null) _showStop(v, zoom: 16);
          },
        ),
        const SizedBox(height: 14),
        if (_finished) ..._finishedPanel() else ..._stagePanel(),
      ],
    );
  }

  /// 目前這一關：路線、破關。交通方式和重新定位在地圖右上，不放在這裡（手機上太擠）
  List<Widget> _stagePanel() {
    final node = _nodes[_stage];
    final plan = _plans[_stage];
    final busy = _entering || _checking || _planning;
    // 正式 App、已經抵達：可以按「做任務」開答題頁
    final canDoTasks = !_demo && node.arrived && widget.onDoTasks != null;
    return [
      _sectionTitle('這一關的路線'),
      if (!node.hasPoint)
        const Text(
          '後端查不到這一關的座標，地圖上不會顯示，也規劃不出路線。',
          style: TextStyle(fontSize: 12, color: Pal.cinnabar),
        )
      else if (plan == null)
        // 進入一關會自動規劃；失敗時（例如後端沒開）可以從這裡再試一次
        OutlinedButton.icon(
          onPressed: busy ? null : _planRoute,
          icon: busy
              ? const SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Icon(Icons.route),
          label: Text(
            _checking || _planning ? '規劃中…' : (_entering ? '定位中…' : '規劃這一關的路線'),
          ),
          style: OutlinedButton.styleFrom(
            minimumSize: const Size.fromHeight(44),
          ),
        )
      else ...[
        ..._routeResult(_stage, plan),
        ..._followOrSwitch(_stage),
      ],
      ..._detourPanel(),
      const SizedBox(height: 10),
      _sectionTitle('破關'),
      if (_demoAvailable)
        SwitchListTile(
          dense: true,
          contentPadding: EdgeInsets.zero,
          title: const Text(
            '示範模式',
            style: TextStyle(fontWeight: FontWeight.w600),
          ),
          subtitle: const Text(
            '不用到現場、不用作答，直接破關（展示用）',
            style: TextStyle(fontSize: 11),
          ),
          value: _demo,
          onChanged: _advancing ? null : (v) => setState(() => _demo = v),
        ),
      if (!_demo)
        Padding(
          padding: const EdgeInsets.only(bottom: 8),
          child: Text(
            node.arrived
                ? (canDoTasks
                      ? '已抵達「${node.label}」。按「做任務」把這一關的任務做完，下一關才會解鎖。'
                      : '已抵達「${node.label}」。把這一關的任務做完，下一關才會解鎖（每 20 秒自動檢查一次）。')
                : '走到景點 200 公尺內按「我到了」；抵達後把這一關的任務做完，下一關才會解鎖。',
            style: const TextStyle(fontSize: 12, color: Pal.inkSoft),
          ),
        ),
      // 可以做任務時「做任務」是主要的按鈕，檢查進度退到下面（隊友做完的時候用；自己做完回來會自動檢查）
      if (canDoTasks) ...[
        FilledButton.icon(
          onPressed: _advancing ? null : _doTasks,
          icon: const Icon(Icons.edit_note),
          label: const Text('做任務'),
          style: FilledButton.styleFrom(minimumSize: const Size.fromHeight(48)),
        ),
        const SizedBox(height: 6),
        OutlinedButton.icon(
          onPressed: _advancing ? null : _advance,
          icon: _advancing
              ? const SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Icon(Icons.refresh),
          label: const Text('任務做完了，檢查進度'),
          style: OutlinedButton.styleFrom(
            minimumSize: const Size.fromHeight(44),
          ),
        ),
      ] else
        FilledButton.icon(
          onPressed: _advancing ? null : _advance,
          icon: _advancing
              ? const SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: Colors.white,
                  ),
                )
              : Icon(
                  _demo
                      ? Icons.emoji_events
                      : (node.arrived ? Icons.refresh : Icons.flag),
                ),
          label: Text(
            _demo
                ? '示範：破第 ${_stage + 1} 關'
                : (node.arrived ? '任務做完了，檢查進度' : '我到了「${node.label}」'),
          ),
          style: FilledButton.styleFrom(minimumSize: const Size.fromHeight(48)),
        ),
      if (_demo && _stage > 0)
        Align(
          alignment: Alignment.centerRight,
          child: TextButton.icon(
            onPressed: _advancing ? null : _restart,
            icon: const Icon(Icons.replay, size: 18),
            label: const Text('從第 1 關重新開始'),
          ),
        ),
    ];
  }

  Future<void> _finishJourney() async {
    if (_advancing) return;

    setState(() => _advancing = true);

    try {
      await PairApi.endStory(storyId: '${_story.storyId}');

      if (!mounted) return;

      Navigator.of(context).pushReplacement(
        MaterialPageRoute(
          builder: (_) => StoryEndPage(storyId: '${_story.storyId}'),
        ),
      );
    } catch (e) {
      if (mounted) {
        showError(context, e);
        setState(() => _advancing = false);
      }
    }
  }

  /// 全部破關後
  List<Widget> _finishedPanel() {
    return [
      Card(
        color: Pal.ink,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 16),
          child: Column(
            children: [
              const Icon(Icons.emoji_events, color: Pal.selected, size: 36),
              const SizedBox(height: 6),
              Text(
                '全部 ${_nodes.length} 關都破關了！',
                style: const TextStyle(
                  color: Pal.parchment,
                  fontSize: 17,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
        ),
      ),
      const SizedBox(height: 10),
      FilledButton.icon(
        onPressed: _advancing ? null : _finishJourney,
        icon: _advancing
            ? const SizedBox(
                width: 18,
                height: 18,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  color: Colors.white,
                ),
              )
            : const Icon(Icons.card_giftcard),
        label: const Text('結束旅程，前往抽獎'),
        style: FilledButton.styleFrom(minimumSize: const Size.fromHeight(48)),
      ),
      ..._detourPanel(),
      // 重來是示範模式才有：正式遊玩的進度不能退回去
      if (_demo) ...[
        const SizedBox(height: 10),
        FilledButton.icon(
          onPressed: _advancing ? null : _restart,
          icon: const Icon(Icons.replay),
          label: const Text('從第 1 關重新開始'),
          style: FilledButton.styleFrom(minimumSize: const Size.fromHeight(46)),
        ),
      ],
    ];
  }

  /// 順路去周邊地點的路線（按了地點卡片上的「前往」才有），排在這一關的路線下面
  List<Widget> _detourPanel() {
    if (_detour == null) return const [];
    final plan = _plans[_detourKey];
    return [
      const SizedBox(height: 10),
      _sectionTitle(
        '順路',
        trailing: TextButton(
          onPressed: _endDetour,
          style: TextButton.styleFrom(visualDensity: VisualDensity.compact),
          child: const Text('結束順路'),
        ),
      ),
      if (plan == null)
        Text(
          '正在規劃去「${_detour!.name}」的路線…',
          style: const TextStyle(fontSize: 12, color: Pal.inkSoft),
        )
      else ...[
        ..._routeResult(_detourKey, plan),
        ..._followOrSwitch(_detourKey),
      ],
    ];
  }

  /// 路線卡片下面：現在跟著走的那一條顯示進度（展示工具打開時多了模擬行走）；另一條顯示「改走這條路線」
  List<Widget> _followOrSwitch(int key) {
    final option = _optionOf(key);
    if (option == null) return const [];
    if (key != _activeKey) {
      return [
        Align(
          alignment: Alignment.centerLeft,
          child: TextButton.icon(
            onPressed: () => _setActive(detour: key == _detourKey),
            icon: const Icon(Icons.alt_route, size: 18),
            label: const Text('改走這條路線'),
          ),
        ),
      ];
    }
    return [
      if (_progress != null) _followStatus(option, _progress!),
      if (widget.demoTools) _simControls(),
    ];
  }

  Widget _sectionTitle(String text, {Widget? trailing}) => Padding(
    padding: const EdgeInsets.only(bottom: 6),
    child: Row(
      children: [
        Text(
          text,
          style: const TextStyle(
            fontSize: 15,
            fontWeight: FontWeight.bold,
            color: Pal.cinnabar,
            letterSpacing: 1,
          ),
        ),
        const SizedBox(width: 6),
        const Expanded(child: Divider(color: Pal.inkSoft)),
        ?trailing,
      ],
    ),
  );

  Color _optionColor(RouteOption o) {
    final metro = o.segments.where((s) => s.mode == '捷運');
    return metro.isNotEmpty ? metro.first.color : modeStyle(o.mode).color;
  }

  /// 一關的路線：可以換交通方式；點一下展開每一步怎麼走
  List<Widget> _routeResult(int stage, RoutePlan plan) {
    final option = _optionOf(stage);
    if (option == null || plan.legs.isEmpty)
      return const [Text('這一關規劃不出路線', style: TextStyle(color: Pal.inkSoft))];
    final leg = plan.legs.first;
    final color = _optionColor(option);

    return [
      for (final w in plan.warnings)
        Padding(
          padding: const EdgeInsets.only(bottom: 4),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Icon(Icons.info_outline, size: 16, color: Pal.gold),
              const SizedBox(width: 4),
              Expanded(
                child: Text(
                  w,
                  style: const TextStyle(fontSize: 12, color: Pal.inkSoft),
                ),
              ),
            ],
          ),
        ),
      Card(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(10),
          side: BorderSide(
            color: _showSteps ? color : Pal.parchmentDeep,
            width: _showSteps ? 2.5 : 1.2,
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            InkWell(
              onTap: () {
                setState(() => _showSteps = !_showSteps);
                _fitStage();
              },
              borderRadius: BorderRadius.circular(10),
              child: Padding(
                padding: const EdgeInsets.fromLTRB(10, 10, 10, 6),
                child: Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            '${leg.fromName} → ${leg.toName}',
                            style: const TextStyle(fontWeight: FontWeight.bold),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            option.summary,
                            style: const TextStyle(
                              fontSize: 12,
                              color: Pal.inkSoft,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 6),
                    Column(
                      children: [
                        Icon(modeStyle(option.mode).icon, color: color),
                        Text(
                          '${option.minutes.ceil()} 分',
                          style: TextStyle(
                            color: color,
                            fontWeight: FontWeight.bold,
                            fontSize: 12,
                          ),
                        ),
                      ],
                    ),
                    Icon(
                      _showSteps ? Icons.expand_less : Icons.expand_more,
                      color: Pal.inkSoft,
                    ),
                  ],
                ),
              ),
            ),
            if (leg.options.length > 1)
              Padding(
                padding: const EdgeInsets.fromLTRB(10, 0, 10, 8),
                child: Wrap(
                  spacing: 6,
                  runSpacing: 4,
                  children: [
                    for (var k = 0; k < leg.options.length; k++)
                      ChoiceChip(
                        visualDensity: VisualDensity.compact,
                        avatar: Icon(
                          modeStyle(leg.options[k].mode).icon,
                          size: 16,
                          color: _optionColor(leg.options[k]),
                        ),
                        label: Text(
                          '${leg.options[k].mode} ${leg.options[k].minutes.ceil()} 分'
                          '${k == 0 ? '・最快' : ''}',
                          style: const TextStyle(fontSize: 12),
                        ),
                        selected: (_chosen[stage] ?? 0) == k,
                        selectedColor: _optionColor(
                          leg.options[k],
                        ).withValues(alpha: 0.2),
                        showCheckmark: false,
                        onSelected: (_) {
                          setState(() {
                            _chosen[stage] = k;
                            // 換了交通方式就是換了一條路線
                            _resetFollow();
                            _simMeters = 0;
                            _simDrift = 0;
                          });
                          _fitStage();
                        },
                      ),
                  ],
                ),
              ),
            if (_showSteps)
              Container(
                padding: const EdgeInsets.fromLTRB(12, 4, 12, 10),
                decoration: const BoxDecoration(
                  border: Border(top: BorderSide(color: Pal.parchmentDeep)),
                ),
                child: Column(
                  children: [
                    for (final seg in option.segments) _segmentRow(seg),
                  ],
                ),
              ),
          ],
        ),
      ),
    ];
  }

  static String _metersText(double meters) => meters < 1000
      ? '${(meters / 10).round() * 10} 公尺'
      : '${(meters / 1000).toStringAsFixed(1)} 公里';

  /// 跟著位置走的狀態：還剩多遠、多久，現在在路線上還是偏離了
  Widget _followStatus(RouteOption option, RouteProgress progress) {
    final seg = option.segments[progress.segment];
    final color = _optionColor(option);
    final arrived = progress.remainingMeters < 30;

    final (IconData icon, Color tone, String text) = seg.isRide
        ? (Icons.directions_transit, Pal.inkSoft, '搭${seg.mode}中，下車後才判斷有沒有偏離')
        : !_onRoute
        ? (
            _planning ? Icons.sync : Icons.warning_amber,
            Pal.gold,
            '離路線 ${_metersText(progress.offMeters)}${_planning ? '，重新規劃中…' : '，持續偏離會自動重新規劃'}',
          )
        : arrived
        ? (Icons.flag, Pal.moss, _activeKey == _detourKey ? '到了' : '到景點了')
        : (Icons.navigation, Pal.moss, '在路線上，路線會跟著你的位置縮短');

    return Padding(
      padding: const EdgeInsets.only(top: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  '還剩 ${_metersText(progress.remainingMeters)}・約 ${progress.remainingMinutes.ceil()} 分鐘',
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    color: Pal.ink,
                  ),
                ),
              ),
              Text(
                '已走 ${(progress.fraction * 100).round()}%',
                style: const TextStyle(fontSize: 12, color: Pal.inkSoft),
              ),
            ],
          ),
          const SizedBox(height: 4),
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(
              value: progress.fraction,
              minHeight: 6,
              color: color,
              backgroundColor: Pal.parchmentDeep,
            ),
          ),
          const SizedBox(height: 4),
          Row(
            children: [
              Icon(icon, size: 15, color: tone),
              const SizedBox(width: 4),
              Expanded(
                child: Text(text, style: TextStyle(fontSize: 12, color: tone)),
              ),
            ],
          ),
        ],
      ),
    );
  }

  /// 展示工具：模擬沿路線走、故意走偏、模擬隊友
  Widget _simControls() {
    final walking = _simTimer != null;
    final mates = _mateTimer != null;
    return Padding(
      padding: const EdgeInsets.only(top: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: _toggleSim,
                  icon: Icon(
                    walking ? Icons.pause : Icons.directions_walk,
                    size: 18,
                  ),
                  label: Text(walking ? '暫停' : '模擬沿路線走'),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: _simAstray ? null : _simGoAstray,
                  icon: const Icon(Icons.alt_route, size: 18),
                  label: const Text('故意走偏'),
                ),
              ),
            ],
          ),
          OutlinedButton.icon(
            onPressed: _toggleMates,
            icon: Icon(mates ? Icons.group_off : Icons.groups, size: 18),
            label: Text(mates ? '收起模擬隊友' : '模擬隊友'),
          ),
          Padding(
            padding: const EdgeInsets.only(top: 2),
            child: Text(
              _simulated
                  ? '現在的位置是模擬的，確認抵達用的也是它。按地圖右上的「重新定位」換回真的定位。'
                  : '展示用：模擬的位置會當成我的定位，路線縮短、偏離重新規劃、確認抵達走的是跟真的定位一樣的流程。',
              style: const TextStyle(fontSize: 11, color: Pal.inkSoft),
            ),
          ),
        ],
      ),
    );
  }

  Widget _segmentRow(RouteSegment seg) {
    final style = modeStyle(seg.mode, lineColor: seg.color);
    final color = seg.mode == '捷運' ? seg.color : style.color;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 5),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 26,
            height: 26,
            decoration: BoxDecoration(color: color, shape: BoxShape.circle),
            child: Icon(style.icon, size: 15, color: Colors.white),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(seg.instruction, style: const TextStyle(fontSize: 13)),
                if (seg.waitMinutes > 0)
                  Text(
                    '候車約 ${seg.waitMinutes.ceil()} 分鐘',
                    style: const TextStyle(fontSize: 11, color: Pal.inkSoft),
                  ),
                if (seg.isRide && seg.stops.length > 2)
                  Text(
                    '經過：${seg.stops.skip(1).take(seg.stops.length - 2).map((s) => s.name).join('、')}',
                    style: const TextStyle(fontSize: 11, color: Pal.inkSoft),
                  ),
              ],
            ),
          ),
          Text(
            '${seg.minutes.ceil()} 分',
            style: TextStyle(
              fontSize: 12,
              color: color,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }
}

/// 圖例上的線型樣本
class _LineSample extends CustomPainter {
  _LineSample(this.style);
  final ModeStyle style;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = style.color
      ..strokeWidth = 3.5
      ..strokeCap = StrokeCap.round;
    final y = size.height / 2;
    final segments = style.pattern.segments;
    if (style.pattern.spacingFactor != null) {
      for (double x = 2; x < size.width; x += 7) {
        canvas.drawCircle(Offset(x, y), 1.8, paint);
      }
    } else if (segments != null) {
      double x = 0;
      var i = 0;
      while (x < size.width) {
        final len = segments[i % segments.length];
        if (i.isEven)
          canvas.drawLine(
            Offset(x, y),
            Offset((x + len * 0.6).clamp(0, size.width), y),
            paint,
          );
        x += len * 0.6;
        i++;
      }
    } else {
      canvas.drawLine(Offset(0, y), Offset(size.width, y), paint);
    }
  }

  @override
  bool shouldRepaint(covariant _LineSample oldDelegate) =>
      oldDelegate.style != style;
}
