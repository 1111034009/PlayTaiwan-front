import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

import '../api/admin_api.dart';
import 'admin_theme.dart';
import 'admin_widgets.dart';

int _i(dynamic v) => (v as num?)?.toInt() ?? 0;

Map<String, dynamic> _badgeBody(Map<String, dynamic> d, {bool? isActive}) => {
  'b_fication': d['b_fication'],
  'b_thing': d['b_thing'],
  'b_name': d['b_name'],
  'b_image': d['b_image'],
  'is_active': isActive ?? d['is_active'],
};

Widget _badgeImage(String url, double size) {
  return Container(
    width: size,
    height: size,
    decoration: BoxDecoration(
      color: AdminColors.surfaceSoft,
      borderRadius: BorderRadius.circular(12),
      border: Border.all(color: AdminColors.border),
    ),
    clipBehavior: Clip.antiAlias,
    child: url.isEmpty
        ? const Icon(
            Icons.workspace_premium_outlined,
            color: AdminColors.secondary,
          )
        : Image.network(
            url,
            fit: BoxFit.contain,
            errorBuilder: (_, __, ___) => const Icon(
              Icons.image_not_supported_outlined,
              color: AdminColors.secondary,
            ),
          ),
  );
}

class BadgesPage extends StatefulWidget {
  const BadgesPage({super.key});

  @override
  State<BadgesPage> createState() => _BadgesPageState();
}

class _BadgesPageState extends State<BadgesPage> {
  static const _size = 20;

  final _search = TextEditingController();
  List<String> _cats = [];
  String? _category;
  bool? _active;
  int _page = 1;
  int _total = 0;
  List<Map<String, dynamic>> _items = [];
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadCats();
    _load();
  }

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  Future<void> _loadCats() async {
    try {
      final c = await AdminApi.badgeCategories();
      if (mounted) setState(() => _cats = c);
    } catch (_) {}
  }

  Future<void> _load({int? page}) async {
    final target = page ?? _page;
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final r = await AdminApi.badges(
        keyword: _search.text.trim(),
        category: _category,
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
        initial = await AdminApi.getBadge(id);
      } catch (e) {
        if (mounted) adminSnack(context, adminError(e), error: true);
        return;
      }
    }
    if (!mounted) return;
    final saved = await showDialog<bool>(
      context: context,
      builder: (_) => _BadgeForm(initial: initial, categories: _cats),
    );
    if (saved == true) {
      if (mounted) adminSnack(context, id == null ? '勳章新增成功' : '勳章修改成功');
      _load();
    }
  }

  Future<void> _toggle(Map<String, dynamic> b) async {
    final id = _i(b['b_id']);
    final active = b['is_active'] == true;
    if (active &&
        !await adminConfirm(
          context,
          '刪除勳章',
          '確定要刪除「${b['b_name']}」嗎？已收集的紀錄會保留，但之後抽不到。',
          ok: '刪除',
        )) {
      return;
    }
    try {
      if (active) {
        await AdminApi.deleteBadge(id);
      } else {
        final d = await AdminApi.getBadge(id);
        await AdminApi.updateBadge(id, _badgeBody(d, isActive: true));
      }
      if (!mounted) return;
      adminSnack(context, active ? '勳章已刪除' : '勳章已還原');
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
              hint: '搜尋勳章名稱或對應物件',
              onSubmit: () => _load(page: 1),
            ),
          ),
          AdminDropdown<String>(
            label: '分類',
            value: _category,
            width: 160,
            options: {null: '全部', for (final c in _cats) c: c},
            onChanged: (v) {
              setState(() => _category = v);
              _load(page: 1);
            },
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
            label: const Text('新增勳章'),
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
            breakpoint: 760,
            columns: const [
              AdminCol('勳章', 4),
              AdminCol('分類', 2),
              AdminCol('對應物件', 2),
              AdminCol('已收集', 1),
              AdminCol('更新時間', 3),
              AdminCol('狀態', 2),
              AdminCol('操作', 3),
            ],
            rows: [for (final b in _items) _row(b)],
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

  AdminRowData _row(Map<String, dynamic> b) {
    final id = _i(b['b_id']);
    final active = b['is_active'] == true;

    final category = AdminChip(
      '${b['b_fication'] ?? ''}',
      AdminColors.primary,
      AdminColors.primarySoft,
    );
    final status = active
        ? const AdminChip(
            '使用中',
            AdminColors.highlight,
            AdminColors.highlightSoft,
          )
        : const AdminChip('已刪除', AdminColors.danger, AdminColors.dangerSoft);

    final actions = Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        adminIconButton('編輯', Icons.edit_outlined, () => _openForm(id: id)),
        adminIconButton(
          active ? '刪除' : '還原',
          active ? Icons.delete_outline : Icons.restore,
          () => _toggle(b),
          color: active ? AdminColors.danger : AdminColors.highlight,
        ),
      ],
    );

    final nameText = Text(
      '${b['b_name'] ?? ''}',
      maxLines: 1,
      overflow: TextOverflow.ellipsis,
      style: AdminText.bodySmall.copyWith(fontWeight: FontWeight.w700),
    );

    return AdminRowData(
      onTap: () => _openForm(id: id),
      cells: [
        Row(
          children: [
            _badgeImage('${b['b_image'] ?? ''}', 40),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  nameText,
                  Text('#$id', style: AdminText.caption),
                ],
              ),
            ),
          ],
        ),
        category,
        Text(
          '${b['b_thing'] ?? ''}',
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: AdminText.bodySmall,
        ),
        Text('${b['owned_count'] ?? 0}', style: AdminText.bodySmall),
        Text(adminDate(b['updated_at']), style: AdminText.caption),
        status,
        actions,
      ],
      compact: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _badgeImage('${b['b_image'] ?? ''}', 48),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                nameText,
                Text(
                  '對應：${b['b_thing'] ?? ''}・已收集 ${b['owned_count'] ?? 0}',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: AdminText.caption,
                ),
                const SizedBox(height: 6),
                Wrap(spacing: 6, runSpacing: 6, children: [category, status]),
              ],
            ),
          ),
          actions,
        ],
      ),
    );
  }
}

class _BadgeForm extends StatefulWidget {
  const _BadgeForm({this.initial, required this.categories});

  final Map<String, dynamic>? initial;
  final List<String> categories;

  @override
  State<_BadgeForm> createState() => _BadgeFormState();
}

class _BadgeFormState extends State<_BadgeForm> {
  late final _thing = TextEditingController(
    text: '${widget.initial?['b_thing'] ?? ''}',
  );
  late final _name = TextEditingController(
    text: '${widget.initial?['b_name'] ?? ''}',
  );
  late final _image = TextEditingController(
    text: '${widget.initial?['b_image'] ?? ''}',
  );
  late String? _category =
      widget.initial?['b_fication']?.toString() ??
      (widget.categories.isEmpty ? null : widget.categories.first);
  late bool _active = widget.initial?['is_active'] != false;
  bool _uploading = false;
  bool _saving = false;
  String? _err;

  bool get _edit => widget.initial != null;

  @override
  void dispose() {
    _thing.dispose();
    _name.dispose();
    _image.dispose();
    super.dispose();
  }

  Future<void> _pick() async {
    try {
      final x = await ImagePicker().pickImage(source: ImageSource.gallery);
      if (x == null) return;
      setState(() {
        _uploading = true;
        _err = null;
      });
      final url = await AdminApi.upload(x.name, await x.readAsBytes());
      if (!mounted) return;
      setState(() {
        _image.text = url;
        _uploading = false;
      });
    } catch (e) {
      if (mounted) {
        setState(() {
          _uploading = false;
          _err = adminError(e);
        });
      }
    }
  }

  Future<void> _save() async {
    final thing = _thing.text.trim();
    final name = _name.text.trim();
    final image = _image.text.trim();
    if (_category == null || thing.isEmpty || name.isEmpty || image.isEmpty) {
      setState(() => _err = '請選擇分類，並填寫對應物件、名稱與圖片');
      return;
    }
    setState(() {
      _saving = true;
      _err = null;
    });
    try {
      if (_edit) {
        await AdminApi.updateBadge(_i(widget.initial!['b_id']), {
          'b_fication': _category,
          'b_thing': thing,
          'b_name': name,
          'b_image': image,
          'is_active': _active,
        });
      } else {
        await AdminApi.createBadge({
          'b_fication': _category,
          'b_thing': thing,
          'b_name': name,
          'b_image': image,
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

  @override
  Widget build(BuildContext context) {
    final cats = {
      ...widget.categories,
      if (_category != null) _category!,
    }.toList();

    return AdminDialogFrame(
      title: _edit ? '編輯勳章 #${widget.initial!['b_id']}' : '新增勳章',
      saving: _saving || _uploading,
      onSave: _save,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SizedBox(height: 6),
          Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: DropdownButtonFormField<String>(
              value: _category,
              isExpanded: true,
              style: adminDropdownStyle(context),
              decoration: const InputDecoration(labelText: '分類'),
              items: [
                for (final c in cats)
                  DropdownMenuItem(
                    value: c,
                    child: Text(c, style: AdminText.bodySmall),
                  ),
              ],
              onChanged: (v) => setState(() => _category = v),
            ),
          ),
          adminField('對應物件（島嶼城市填縣市、台灣印記填地標）', _thing),
          adminField('勳章名稱', _name),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _badgeImage(_image.text.trim(), 72),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    OutlinedButton.icon(
                      onPressed: _uploading ? null : _pick,
                      icon: _uploading
                          ? const SizedBox(
                              width: 16,
                              height: 16,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : const Icon(Icons.upload_outlined, size: 18),
                      label: Text(_uploading ? '上傳中…' : '選擇圖片'),
                    ),
                    const SizedBox(height: 10),
                    adminField(
                      '圖片網址',
                      _image,
                      onChanged: (_) => setState(() {}),
                    ),
                  ],
                ),
              ),
            ],
          ),
          if (_edit)
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              title: const Text('使用中（關閉 = 刪除）', style: AdminText.body),
              value: _active,
              onChanged: (v) => setState(() => _active = v),
            ),
          if (_err != null)
            Padding(
              padding: const EdgeInsets.only(top: 6, bottom: 6),
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
