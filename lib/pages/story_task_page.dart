import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

import '../route_map/api.dart';
import '../route_map/models.dart';
import '../route_map/theme.dart';
import '../core/app_notice.dart';

/// 做任務：地圖頁按「做任務」打開的答題頁，這一關的題目在這裡作答。
/// 題目、作答方式、通過了沒都問後端（GET /api/Task/Node/{id}），送出答案是 POST /api/Task/Answer；
/// 全部通過這一關就破關：這一頁會自己關掉回地圖，地圖確認破關後解鎖下一關、跳出這一關的明信片。
/// 配色跟地圖頁同一套（開這一頁的人把它包在 buildTheme 裡）
class StoryTaskPage extends StatefulWidget {
  const StoryTaskPage({
    super.key,
    required this.node,
    required this.myLocation,
  });

  /// 要做任務的這一關。要已經抵達，不然後端不給題目
  final MapNode node;

  /// 我現在的位置，地圖頁一直在追蹤的那一個：送出答案時後端會檢查人在景點 200 公尺內。拿不到時是 null
  final Future<PlacePoint?> Function() myLocation;

  @override
  State<StoryTaskPage> createState() => _StoryTaskPageState();
}

/// 這一頁破關後自己關掉（或按「回到地圖」）時回給開它的人：這一關破關了沒；[photo] 是這一次在拍照任務交出去的照片
/// （破關後做明信片用），這一關沒有拍照任務、或照片是之前交的就是 null。按左上角返回離開的不會有這個結果
typedef StoryTaskResult = ({bool cleared, XFile? photo});

/// 一題任務。作答方式（[mode]）決定畫面上給什麼輸入、送出時帶哪個欄位：
/// choice 選一個選項、photo 交照片、audio_or_video 交影片、gps 人在現場就好，其他都是打字回答
class _Task {
  _Task.fromJson(Map<String, dynamic> j)
    : id = (j['task_id'] as num?)?.toInt() ?? 0,
      typeName = _str(j['type_name']),
      mode = _str(j['answer_mode']),
      describe = _str(j['task_describe']),
      clue = _str(j['clue_text']),
      options = ((j['options'] as List?) ?? const [])
          .cast<Map<String, dynamic>>(),
      passed = j['pass'] == 1,
      hintAvailable = j['hint_available'] == true;

  final int id;
  final String typeName;
  final String mode;
  final String describe;

  /// 協作解謎型：自己座位的線索，其他題型是空的
  final String clue;
  final List<Map<String, dynamic>> options;
  final bool passed;

  /// 現在能不能看提示：選擇題要先答錯一次，後端決定
  final bool hintAvailable;
}

String _str(Object? value) => value is String ? value.trim() : '';

class _StoryTaskPageState extends State<StoryTaskPage> {
  final _picker = ImagePicker();

  /// 後端給的這一關：劇情、NPC 和題目。還沒載入時是 null
  Map<String, dynamic>? _play;
  List<_Task> _tasks = const [];
  String? _loadError;

  // 每一題還沒送出的作答，key 是 task_id
  final Map<int, String> _choice = {};
  final Map<int, TextEditingController> _answer = {};
  final Map<int, ({XFile file, Widget? preview})> _media = {};

  /// 每一題上一次送出後後端說的話（答對、答錯、審核中）
  final Map<int, ({String text, bool ok})> _feedback = {};

  /// 正在送出的那一題；一次只送一題
  int? _sending;

  /// 拍照任務交出去、後端收下的照片（最後一張），破關後拿去做明信片
  XFile? _photo;

  StoryTaskResult get _result => (cleared: _allPassed, photo: _photo);

  int get _passed => _tasks.where((t) => t.passed).length;

  /// 沒有任務的站抵達就算破關，也算全部通過
  bool get _allPassed => _tasks.every((t) => t.passed);

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    for (final controller in _answer.values) {
      controller.dispose();
    }
    super.dispose();
  }

  Future<void> _load() async {
    setState(() => _loadError = null);
    try {
      final play = await _fetch();
      if (mounted) setState(() => _apply(play));
    } catch (e) {
      if (mounted) setState(() => _loadError = '$e');
    }
  }

  Future<Map<String, dynamic>> _fetch() async =>
      await Api.instance.get('/api/Task/Node/${widget.node.nodeId}')
          as Map<String, dynamic>;

  void _apply(Map<String, dynamic> play) {
    _play = play;
    _tasks = ((play['tasks'] as List?) ?? const [])
        .cast<Map<String, dynamic>>()
        .map(_Task.fromJson)
        .toList();
  }

  TextEditingController _controller(_Task task) =>
      _answer.putIfAbsent(task.id, TextEditingController.new);

  /// 這一題還缺什麼才能送出；可以送了就是 null
  String? _missing(_Task task) => switch (task.mode) {
    'choice' => _choice[task.id] == null ? '請先選一個答案' : null,
    'photo' => _media[task.id] == null ? '請先拍一張照片' : null,
    'audio_or_video' => _media[task.id] == null ? '請先錄一段影片' : null,
    'gps' => null,
    _ => _controller(task).text.trim().isEmpty ? '請先輸入答案' : null,
  };

  /// 送出一題的答案。後端要我現在的位置（要在景點 200 公尺內）；照片、影片先上傳，送的是上傳後的網址
  Future<void> _submit(_Task task) async {
    if (_sending != null) return;
    final missing = _missing(task);
    if (missing != null) {
      _snack(missing, Pal.inkSoft);
      return;
    }

    var cleared = false;
    setState(() => _sending = task.id);
    try {
      final me = await widget.myLocation();
      if (me == null) throw ApiException('拿不到定位，沒辦法送出答案（要確認你在景點附近）');

      final media = _media[task.id];
      final url = media == null
          ? null
          : await Api.instance.upload(
              _fileName(media.file, task),
              media.file.openRead(),
              await media.file.length(),
            );

      final result =
          await Api.instance.post('/api/Task/Answer', {
                'task_id': task.id,
                'gps_lat': me.lat,
                'gps_lon': me.lng,
                ...switch (task.mode) {
                  'choice' => {'selected_option_key': _choice[task.id]},
                  'photo' => {'photo_url': url},
                  'audio_or_video' => {'video_url': url},
                  'gps' => const <String, Object?>{},
                  _ => {'text_answer': _controller(task).text.trim()},
                },
              })
              as Map<String, dynamic>;

      final correct = result['is_correct'] == true || result['pass'] == 1;
      final pending = result['is_pending_review'] == true;
      final message = _str(result['feedback_message']);
      cleared = result['node_completed'] == true;

      // 重新拿一次這一關：哪幾題通過了、有沒有提示可以看、全部通過後的完成劇情。拿不到就維持原本的畫面
      Map<String, dynamic>? play;
      try {
        play = await _fetch();
      } catch (_) {}
      if (!mounted) return;
      setState(() {
        if (play != null) _apply(play);
        if (task.mode == 'photo' && media != null && (correct || pending))
          _photo = media.file;
        _feedback[task.id] = (
          text: message.isNotEmpty
              ? message
              : (pending ? '已送出，等待審核。' : (correct ? '答對了！' : '答錯了，再試一次。')),
          ok: correct || pending,
        );
      });
    } catch (e) {
      if (mounted) _snack('$e', Pal.cinnabar);
    } finally {
      if (mounted) setState(() => _sending = null);
    }
    if (cleared) await _closeCleared();
  }

  /// 這一關的任務全部通過：最後一題的結果看一下，這一頁就自己關掉回地圖，不用再按一次。
  /// 後端說破關了就是破關，就算剛才重新拿題目沒拿到
  Future<void> _closeCleared() async {
    await Future<void>.delayed(const Duration(milliseconds: 800));
    // 這 0.8 秒裡已經自己按返回離開，或上面還開著別的視窗，就不關
    if (!mounted || !(ModalRoute.of(context)?.isCurrent ?? true)) return;
    Navigator.of(context).pop<StoryTaskResult>((cleared: true, photo: _photo));
  }

  /// 上傳用的檔名。後端看副檔名認檔案類型，沒有副檔名（有些瀏覽器）就補上
  String _fileName(XFile file, _Task task) {
    if (file.name.contains('.')) return file.name;
    return '${file.name.isEmpty ? 'answer' : file.name}${task.mode == 'photo' ? '.jpg' : '.mp4'}';
  }

  /// 選這一題要交的照片或影片：現場拍，或從手機裡選
  Future<void> _pick(_Task task, ImageSource source) async {
    final video = task.mode == 'audio_or_video';
    try {
      final file = video
          ? await _picker.pickVideo(
              source: source,
              maxDuration: const Duration(minutes: 1),
            )
          : await _picker.pickImage(
              source: source,
              maxWidth: 1920,
              imageQuality: 85,
            );
      if (file == null || !mounted) return;
      final preview = video
          ? null
          : Image.memory(
              await file.readAsBytes(),
              height: 150,
              fit: BoxFit.cover,
            );
      if (mounted)
        setState(() => _media[task.id] = (file: file, preview: preview));
    } catch (e) {
      if (mounted) _snack('開不了相機或相簿：$e', Pal.cinnabar);
    }
  }

  /// 看提示（GET /api/Task/{id}/Hint）
  Future<void> _showHint(_Task task) async {
    try {
      final hint =
          await Api.instance.get('/api/Task/${task.id}/Hint')
              as Map<String, dynamic>;
      if (!mounted) return;
      final npc = _str(hint['npc_name']);
      showDialog<void>(
        context: context,
        builder: (dialog) => AlertDialog(
          title: Text(npc.isEmpty ? '提示' : '$npc的提示'),
          content: Text(_str(hint['hint_text'])),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialog).pop(),
              child: const Text('知道了'),
            ),
          ],
        ),
      );
    } catch (e) {
      if (mounted) _snack('$e', Pal.cinnabar);
    }
  }

  void _snack(String text, Color color) {
    AppNotice.show(text);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('做任務・${widget.node.label}')),
      body: SafeArea(
        top: false,
        child: _play == null ? _waiting() : _content(),
      ),
    );
  }

  /// 還在跟後端拿題目，或拿不到（例如還沒抵達這一站）
  Widget _waiting() {
    if (_loadError == null)
      return const Center(child: CircularProgressIndicator());
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              _loadError!,
              textAlign: TextAlign.center,
              style: const TextStyle(color: Pal.cinnabar),
            ),
            const SizedBox(height: 12),
            FilledButton(onPressed: _load, child: const Text('重試')),
          ],
        ),
      ),
    );
  }

  Widget _content() {
    final node = _play!['node'] as Map<String, dynamic>?;
    final npc = _play!['npc'] as Map<String, dynamic>?;
    final opening = _str(node?['opening_text']);
    final success = _str(node?['success_text']);
    return Align(
      alignment: Alignment.topCenter,
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 560),
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 14, 16, 24),
          children: [
            if (npc != null) _npcRow(npc),
            if (opening.isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(top: 10),
                child: Text(
                  opening,
                  style: const TextStyle(color: Pal.inkSoft, height: 1.5),
                ),
              ),
            const SizedBox(height: 14),
            Text(
              _tasks.isEmpty
                  ? '這一站沒有任務，抵達就算破關。'
                  : '已通過 $_passed / ${_tasks.length} 題',
              style: const TextStyle(
                fontWeight: FontWeight.bold,
                color: Pal.ink,
              ),
            ),
            const SizedBox(height: 4),
            for (final (i, task) in _tasks.indexed) _taskCard(i + 1, task),
            if (_allPassed) ...[
              if (success.isNotEmpty)
                Padding(
                  padding: const EdgeInsets.only(top: 10),
                  child: Text(
                    success,
                    style: const TextStyle(color: Pal.ink, height: 1.5),
                  ),
                ),
              const SizedBox(height: 12),
              FilledButton.icon(
                onPressed: () =>
                    Navigator.of(context).pop<StoryTaskResult>(_result),
                icon: const Icon(Icons.map_outlined),
                label: const Text('回到地圖'),
                style: FilledButton.styleFrom(
                  minimumSize: const Size.fromHeight(48),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  /// 這一站出題的 NPC：頭像、名字和身分
  Widget _npcRow(Map<String, dynamic> npc) {
    final name = _str(npc['npc_name']);
    final role = _str(npc['npc_role']);
    final avatar = _str(npc['npc_avatar_url']);
    const placeholder = ColoredBox(
      color: Pal.parchmentDeep,
      child: Center(child: Icon(Icons.person, color: Pal.inkSoft)),
    );
    return Row(
      children: [
        ClipOval(
          child: SizedBox(
            width: 44,
            height: 44,
            child: avatar.isEmpty
                ? placeholder
                : Image.network(
                    avatar,
                    fit: BoxFit.cover,
                    errorBuilder: (_, _, _) => placeholder,
                  ),
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                name.isEmpty ? 'NPC' : name,
                style: const TextStyle(
                  fontWeight: FontWeight.bold,
                  color: Pal.ink,
                ),
              ),
              if (role.isNotEmpty)
                Text(
                  role,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontSize: 12, color: Pal.inkSoft),
                ),
            ],
          ),
        ),
      ],
    );
  }

  /// 一題：題號（通過了打勾）、題型、題目、作答的地方和送出的按鈕。通過的題目只留題目
  Widget _taskCard(int number, _Task task) {
    final busy = _sending != null;
    final sending = _sending == task.id;
    final feedback = _feedback[task.id];
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Container(
                  width: 26,
                  height: 26,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: task.passed ? Pal.moss : Pal.cinnabar,
                    shape: BoxShape.circle,
                  ),
                  child: task.passed
                      ? const Icon(Icons.check, size: 16, color: Colors.white)
                      : Text(
                          '$number',
                          style: const TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                            fontSize: 12,
                          ),
                        ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    '${task.typeName}・${task.passed ? '已通過' : '未通過'}',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                      color: task.passed ? Pal.moss : Pal.inkSoft,
                    ),
                  ),
                ),
                if (task.hintAvailable)
                  TextButton.icon(
                    onPressed: () => _showHint(task),
                    icon: const Icon(Icons.lightbulb_outline, size: 18),
                    label: const Text('提示'),
                    style: TextButton.styleFrom(
                      visualDensity: VisualDensity.compact,
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              task.describe,
              style: const TextStyle(
                fontSize: 15,
                color: Pal.ink,
                height: 1.45,
              ),
            ),
            if (task.clue.isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(top: 6),
                child: Text(
                  '${task.clue}',
                  style: const TextStyle(fontSize: 13, color: Pal.inkSoft),
                ),
              ),
            if (!task.passed) ...[
              const SizedBox(height: 10),
              ..._input(task, busy),
            ],
            if (feedback != null)
              Padding(
                padding: const EdgeInsets.only(top: 8),
                child: Text(
                  feedback.text,
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    color: feedback.ok ? Pal.moss : Pal.cinnabar,
                  ),
                ),
              ),
            if (!task.passed) ...[
              const SizedBox(height: 10),
              FilledButton.icon(
                onPressed: busy ? null : () => _submit(task),
                icon: sending
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.white,
                        ),
                      )
                    : Icon(task.mode == 'gps' ? Icons.place : Icons.send),
                label: Text(
                  sending
                      ? '送出中…'
                      : (task.mode == 'gps' ? '我在現場，完成這一題' : '送出答案'),
                ),
                style: FilledButton.styleFrom(
                  minimumSize: const Size.fromHeight(46),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  /// 這一題作答的地方，依作答方式不同
  List<Widget> _input(_Task task, bool busy) {
    switch (task.mode) {
      case 'choice':
        return [
          for (final option in task.options) _optionTile(task, option, busy),
        ];
      case 'photo':
      case 'audio_or_video':
        final video = task.mode == 'audio_or_video';
        final media = _media[task.id];
        return [
          if (media?.preview != null)
            Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: media!.preview,
              ),
            )
          else if (media != null)
            Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Row(
                children: [
                  const Icon(Icons.videocam, size: 18, color: Pal.moss),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      '已選好影片：${media.file.name}',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(fontSize: 13, color: Pal.ink),
                    ),
                  ),
                ],
              ),
            ),
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: busy
                      ? null
                      : () => _pick(task, ImageSource.camera),
                  icon: Icon(
                    video
                        ? Icons.videocam_outlined
                        : Icons.photo_camera_outlined,
                  ),
                  label: Text(video ? '錄影' : '拍照'),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: busy
                      ? null
                      : () => _pick(task, ImageSource.gallery),
                  icon: const Icon(Icons.photo_library_outlined),
                  label: Text(video ? '選影片' : '選照片'),
                ),
              ),
            ],
          ),
        ];
      case 'gps':
        return const [
          Text(
            '這一題不用作答：人在景點現場，按下面的按鈕就完成。',
            style: TextStyle(fontSize: 13, color: Pal.inkSoft),
          ),
        ];
      default:
        return [
          TextField(
            controller: _controller(task),
            enabled: !busy,
            minLines: 1,
            maxLines: 4,
            textInputAction: TextInputAction.done,
            decoration: const InputDecoration(
              hintText: '輸入你的答案',
              border: OutlineInputBorder(),
              isDense: true,
            ),
          ),
        ];
    }
  }

  /// 選擇題的一個選項：點了選起來（紅框），有圖片的選項圖片放在文字下面
  Widget _optionTile(_Task task, Map<String, dynamic> option, bool busy) {
    final key = _str(option['option_key']);
    final image = _str(option['option_url']);
    final selected = _choice[task.id] == key;
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Material(
        color: selected
            ? Pal.selected.withValues(alpha: 0.35)
            : Colors.transparent,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(8),
          side: BorderSide(
            color: selected ? Pal.cinnabar : Pal.parchmentDeep,
            width: selected ? 2 : 1.2,
          ),
        ),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: busy ? null : () => setState(() => _choice[task.id] = key),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 9),
            child: Row(
              children: [
                Icon(
                  selected
                      ? Icons.radio_button_checked
                      : Icons.radio_button_off,
                  size: 20,
                  color: selected ? Pal.cinnabar : Pal.inkSoft,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '$key. ${_str(option['option_text'])}',
                        style: const TextStyle(color: Pal.ink),
                      ),
                      if (image.isNotEmpty)
                        Padding(
                          padding: const EdgeInsets.only(top: 6),
                          child: ClipRRect(
                            borderRadius: BorderRadius.circular(6),
                            child: Image.network(
                              image,
                              height: 120,
                              fit: BoxFit.cover,
                              errorBuilder: (_, _, _) =>
                                  const SizedBox.shrink(),
                            ),
                          ),
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
}
