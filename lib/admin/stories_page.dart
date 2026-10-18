import 'package:flutter/material.dart';

import '../api/admin_api.dart';
import 'admin_theme.dart';
import 'admin_widgets.dart';

const _npcs = {1: '薯光', 2: '珍奶奶', 3: '阿達力', 4: '墨先生', 5: '霓霓', 6: '阿吉伯'};

int _i(dynamic v) => (v as num?)?.toInt() ?? 0;

Map<String, dynamic> _storyBody(Map<String, dynamic> d, {bool? isActive}) => {
  'story_title': d['story_title'],
  'story_prologue': d['story_prologue'],
  'story_synopsis': d['story_synopsis'],
  'city_name': d['city_name'],
  'district_name': d['district_name'],
  'party_size': d['party_size'],
  'sd_transport': d['sd_transport'],
  'npc_id': d['npc_id'],
  'is_night_mode': d['is_night_mode'],
  'is_active': isActive ?? d['is_active'],
};

class StoriesPage extends StatefulWidget {
  const StoriesPage({super.key});

  @override
  State<StoriesPage> createState() => _StoriesPageState();
}

class _StoriesPageState extends State<StoriesPage> {
  static const _size = 20;

  final _search = TextEditingController();
  final _userId = TextEditingController();
  bool? _active;
  int _page = 1;
  int _total = 0;
  List<Map<String, dynamic>> _items = [];
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _search.dispose();
    _userId.dispose();
    super.dispose();
  }

  Future<void> _load({int? page}) async {
    final target = page ?? _page;
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final r = await AdminApi.stories(
        keyword: _search.text.trim(),
        auId: int.tryParse(_userId.text.trim()),
        isActive: _active,
        page: target,
        pageSize: _size,
      );
      if (!mounted) return;
      setState(() {
        _items = r.items;
        _total = r.total;
        _page = target;
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = adminError(e);
        _loading = false;
      });
    }
  }

  Future<void> _openForm({int? id}) async {
    Map<String, dynamic>? initial;
    if (id != null) {
      try {
        initial = await AdminApi.getStory(id);
      } catch (e) {
        if (mounted) adminSnack(context, adminError(e), error: true);
        return;
      }
    }
    if (!mounted) return;
    final saved = await showDialog<bool>(
      context: context,
      builder: (_) => _StoryForm(initial: initial),
    );
    if (saved == true) {
      if (mounted) adminSnack(context, id == null ? '劇本新增成功' : '劇本修改成功');
      _load();
    }
  }

  Future<void> _toggle(Map<String, dynamic> s) async {
    final id = _i(s['s_id']);
    final active = s['is_active'] == true;
    if (active &&
        !await adminConfirm(
          context,
          '刪除劇本',
          '確定要刪除「${s['story_title']}」嗎？節點與遊玩紀錄會保留，但玩家端會查不到。',
          ok: '刪除',
        )) {
      return;
    }
    try {
      if (active) {
        await AdminApi.deleteStory(id);
      } else {
        final d = await AdminApi.getStory(id);
        await AdminApi.updateStory(id, _storyBody(d, isActive: true));
      }
      if (!mounted) return;
      adminSnack(context, active ? '劇本已刪除' : '劇本已還原');
      _load();
    } catch (e) {
      if (mounted) adminSnack(context, adminError(e), error: true);
    }
  }

  @override
  Widget build(BuildContext context) {
    return AdminPageFrame(
      toolbarBuilder: (w) => Wrap(
        spacing: 10,
        runSpacing: 10,
        crossAxisAlignment: WrapCrossAlignment.center,
        children: [
          SizedBox(
            width: w < 560 ? w : 280,
            child: AdminSearch(
              controller: _search,
              hint: '搜尋標題、縣市、鄉鎮區',
              onSubmit: () => _load(page: 1),
            ),
          ),
          SizedBox(
            width: 120,
            child: TextField(
              controller: _userId,
              keyboardType: TextInputType.number,
              onSubmitted: (_) => _load(page: 1),
              style: AdminText.bodySmall,
              decoration: const InputDecoration(labelText: '用戶 ID'),
            ),
          ),
          AdminDropdown<bool>(
            label: '狀態',
            value: _active,
            options: const {null: '使用中', false: '已刪除'},
            onChanged: (v) {
              setState(() => _active = v);
              _load(page: 1);
            },
          ),
          FilledButton.icon(
            onPressed: () => _openForm(),
            icon: const Icon(Icons.add, size: 18),
            label: const Text('新增劇本'),
          ),
        ],
      ),
      children: [
        adminState(
          loading: _loading,
          error: _error,
          empty: _items.isEmpty,
          onRetry: _load,
          child: AdminTable(
            columns: const [
              AdminCol('劇本', 5),
              AdminCol('用戶', 2),
              AdminCol('NPC', 2),
              AdminCol('人數', 1),
              AdminCol('節點', 1),
              AdminCol('建立時間', 3),
              AdminCol('狀態', 2),
              AdminCol('操作', 3),
            ],
            rows: [for (final s in _items) _row(s)],
          ),
        ),
      ],
      footer: AdminPager(
        page: _page,
        pageSize: _size,
        total: _total,
        onPage: (p) => _load(page: p),
      ),
    );
  }

  AdminRowData _row(Map<String, dynamic> s) {
    final id = _i(s['s_id']);
    final active = s['is_active'] == true;

    final statusChips = Wrap(
      spacing: 4,
      runSpacing: 4,
      children: [
        active
            ? const AdminChip(
                '使用中',
                AdminColors.highlight,
                AdminColors.highlightSoft,
              )
            : const AdminChip(
                '已刪除',
                AdminColors.danger,
                AdminColors.dangerSoft,
              ),
        if (s['is_night_mode'] == true)
          const AdminChip(
            '夜間',
            AdminColors.roleAdmin,
            AdminColors.roleAdminSoft,
          ),
        if (s['is_favorite'] == true)
          const AdminChip('已收藏', AdminColors.primary, AdminColors.primarySoft),
      ],
    );

    final actions = Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        adminIconButton('編輯', Icons.edit_outlined, () => _openForm(id: id)),
        adminIconButton(
          active ? '刪除' : '還原',
          active ? Icons.delete_outline : Icons.restore,
          () => _toggle(s),
          color: active ? AdminColors.danger : AdminColors.highlight,
        ),
      ],
    );

    final titleBlock = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          '${s['story_title'] ?? ''}',
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
          style: AdminText.bodySmall.copyWith(fontWeight: FontWeight.w700),
        ),
        Text(
          '#$id　${s['city_name'] ?? ''}・${s['district_name'] ?? ''}',
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: AdminText.caption,
        ),
      ],
    );

    return AdminRowData(
      onTap: () => _openForm(id: id),
      cells: [
        titleBlock,
        Text(
          '${s['auth_name'] ?? ''}\n#${s['au_id']}',
          style: AdminText.caption,
        ),
        Text('${s['npc_name'] ?? ''}', style: AdminText.bodySmall),
        Text('${s['party_size'] ?? 0} 人', style: AdminText.bodySmall),
        Text('${s['node_count'] ?? 0}', style: AdminText.bodySmall),
        Text(adminDate(s['created_at']), style: AdminText.caption),
        statusChips,
        actions,
      ],
      compact: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                titleBlock,
                const SizedBox(height: 6),
                Wrap(
                  spacing: 6,
                  runSpacing: 6,
                  children: [
                    AdminChip(
                      'NPC ${s['npc_name'] ?? ''}',
                      AdminColors.primary,
                      AdminColors.primarySoft,
                    ),
                    AdminChip(
                      '${s['party_size'] ?? 0} 人',
                      AdminColors.rolePlayer,
                      AdminColors.rolePlayerSoft,
                    ),
                    AdminChip(
                      '${s['node_count'] ?? 0} 節點',
                      AdminColors.highlight,
                      AdminColors.highlightSoft,
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                statusChips,
                const SizedBox(height: 4),
                Text(
                  '${s['auth_name'] ?? ''}・${adminDate(s['created_at'])}',
                  style: AdminText.caption,
                ),
              ],
            ),
          ),
          actions,
        ],
      ),
    );
  }
}

class _StoryForm extends StatefulWidget {
  const _StoryForm({this.initial});

  final Map<String, dynamic>? initial;

  @override
  State<_StoryForm> createState() => _StoryFormState();
}

class _StoryFormState extends State<_StoryForm> {
  late final _auId = TextEditingController();
  late final _title = TextEditingController(
    text: '${widget.initial?['story_title'] ?? ''}',
  );
  late final _prologue = TextEditingController(
    text: '${widget.initial?['story_prologue'] ?? ''}',
  );
  late final _synopsis = TextEditingController(
    text: '${widget.initial?['story_synopsis'] ?? ''}',
  );
  late final _city = TextEditingController(
    text: '${widget.initial?['city_name'] ?? ''}',
  );
  late final _district = TextEditingController(
    text: '${widget.initial?['district_name'] ?? ''}',
  );
  late final _party = TextEditingController(
    text: '${widget.initial?['party_size'] ?? 1}',
  );
  late final _transport = TextEditingController(
    text: '${widget.initial?['sd_transport'] ?? ''}',
  );
  late int _npc = _npcs.containsKey(_i(widget.initial?['npc_id']))
      ? _i(widget.initial?['npc_id'])
      : 1;
  late bool _night = widget.initial?['is_night_mode'] == true;
  late bool _active = widget.initial?['is_active'] != false;
  bool _saving = false;
  String? _err;

  bool get _edit => widget.initial != null;

  @override
  void dispose() {
    for (final c in [
      _auId,
      _title,
      _prologue,
      _synopsis,
      _city,
      _district,
      _party,
      _transport,
    ]) {
      c.dispose();
    }
    super.dispose();
  }

  String? _orNull(TextEditingController c) {
    final t = c.text.trim();
    return t.isEmpty ? null : t;
  }

  Future<void> _save() async {
    final title = _title.text.trim();
    final city = _city.text.trim();
    final district = _district.text.trim();
    final party = int.tryParse(_party.text.trim()) ?? 0;
    final auId = int.tryParse(_auId.text.trim());

    if (title.isEmpty || city.isEmpty || district.isEmpty || party < 1) {
      setState(() => _err = '請填寫標題、縣市、鄉鎮區與人數');
      return;
    }
    if (!_edit && auId == null) {
      setState(() => _err = '請填寫所屬用戶 ID');
      return;
    }
    setState(() {
      _saving = true;
      _err = null;
    });
    try {
      if (_edit) {
        await AdminApi.updateStory(_i(widget.initial!['s_id']), {
          'story_title': title,
          'story_prologue': _orNull(_prologue),
          'story_synopsis': _orNull(_synopsis),
          'city_name': city,
          'district_name': district,
          'party_size': party,
          'sd_transport': _orNull(_transport),
          'npc_id': _npc,
          'is_night_mode': _night,
          'is_active': _active,
        });
      } else {
        await AdminApi.createStory({
          'au_id': auId,
          'story_title': title,
          'city_name': city,
          'district_name': district,
          'party_size': party,
          'npc_id': _npc,
        });
      }
      if (mounted) Navigator.of(context).pop(true);
    } catch (e) {
      if (mounted) {
        setState(() {
          _saving = false;
          _err = adminError(e);
        });
      }
    }
  }

  String _nodeName(dynamic n) {
    if (n is Map) {
      for (final k in [
        'node_name',
        'spot_name',
        'n_name',
        'name',
        'label',
        'title',
      ]) {
        final v = n[k];
        if (v != null && '$v'.isNotEmpty) return '$v';
      }
      return '節點';
    }
    return '$n';
  }

  String _tagName(dynamic t) {
    if (t is Map) {
      for (final k in ['tag_name', 'name', 'label']) {
        final v = t[k];
        if (v != null && '$v'.isNotEmpty) return '$v';
      }
      return '標籤';
    }
    return '$t';
  }

  @override
  Widget build(BuildContext context) {
    final nodes = (widget.initial?['nodes'] as List?) ?? const [];
    final tags = (widget.initial?['tags'] as List?) ?? const [];

    return AdminDialogFrame(
      title: _edit ? '編輯劇本 #${widget.initial!['s_id']}' : '新增劇本',
      saving: _saving,
      onSave: _save,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SizedBox(height: 6),
          if (!_edit) adminField('所屬用戶 ID', _auId, type: TextInputType.number),
          adminField('劇本標題', _title),
          if (_edit) ...[
            adminField('前傳', _prologue, lines: 3),
            adminField('簡介', _synopsis, lines: 3),
          ],
          Row(
            children: [
              Expanded(child: adminField('縣市', _city)),
              const SizedBox(width: 10),
              Expanded(child: adminField('鄉鎮區', _district)),
            ],
          ),
          Row(
            children: [
              Expanded(
                child: adminField('人數', _party, type: TextInputType.number),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: DropdownButtonFormField<int>(
                    value: _npc,
                    isExpanded: true,
                    style: adminDropdownStyle(context),
                    decoration: const InputDecoration(labelText: 'NPC'),
                    items: [
                      for (final e in _npcs.entries)
                        DropdownMenuItem(
                          value: e.key,
                          child: Text(e.value, style: AdminText.bodySmall),
                        ),
                    ],
                    onChanged: (v) => setState(() => _npc = v ?? _npc),
                  ),
                ),
              ),
            ],
          ),
          if (_edit) ...[
            adminField('交通方式', _transport),
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              title: const Text('夜間模式', style: AdminText.body),
              value: _night,
              onChanged: (v) => setState(() => _night = v),
            ),
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              title: const Text('使用中（關閉 = 刪除）', style: AdminText.body),
              value: _active,
              onChanged: (v) => setState(() => _active = v),
            ),
            if (tags.isNotEmpty) ...[
              const SizedBox(height: 8),
              const Text('偏好標籤', style: AdminText.caption),
              const SizedBox(height: 6),
              Wrap(
                spacing: 6,
                runSpacing: 6,
                children: [
                  for (final t in tags)
                    AdminChip(
                      _tagName(t),
                      AdminColors.primary,
                      AdminColors.primarySoft,
                    ),
                ],
              ),
            ],
            if (nodes.isNotEmpty) ...[
              const SizedBox(height: 12),
              Text('節點（${nodes.length}，僅供檢視）', style: AdminText.caption),
              const SizedBox(height: 6),
              for (var i = 0; i < nodes.length; i++)
                Padding(
                  padding: const EdgeInsets.only(bottom: 4),
                  child: Text(
                    '${i + 1}. ${_nodeName(nodes[i])}',
                    style: AdminText.bodySmall,
                  ),
                ),
            ],
          ],
          if (_err != null)
            Padding(
              padding: const EdgeInsets.only(top: 8, bottom: 6),
              child: Text(
                _err!,
                style: AdminText.caption.copyWith(color: AdminColors.danger),
              ),
            ),
        ],
      ),
    );
  }
}
