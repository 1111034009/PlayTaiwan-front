import 'package:flutter/material.dart';

import '../api/admin_api.dart';
import 'admin_theme.dart';
import 'admin_widgets.dart';

const _roles = {1: '遊客', 2: '商家', 3: '管理員'};

Color _roleColor(int t) => t == 3
    ? AdminColors.roleAdmin
    : (t == 2 ? AdminColors.primary : AdminColors.rolePlayer);

Color _roleSoft(int t) => t == 3
    ? AdminColors.roleAdminSoft
    : (t == 2 ? AdminColors.primarySoft : AdminColors.rolePlayerSoft);

int _i(dynamic v) => (v as num?)?.toInt() ?? 0;

Map<String, dynamic> _userBody(Map<String, dynamic> d, {bool? isActive}) => {
  'auth_name': d['auth_name'],
  'auth_email': d['auth_email'],
  'auth_type': d['auth_type'],
  'is_active': isActive ?? d['is_active'],
  'is_email_verified': d['is_email_verified'],
  'au_birthday': d['au_birthday'],
  'au_gender': d['au_gender'],
};

class UsersPage extends StatefulWidget {
  const UsersPage({super.key});

  @override
  State<UsersPage> createState() => _UsersPageState();
}

class _UsersPageState extends State<UsersPage> {
  static const _size = 20;

  final _search = TextEditingController();
  int? _authType;
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
    super.dispose();
  }

  Future<void> _load({int? page}) async {
    final target = page ?? _page;
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final r = await AdminApi.users(
        keyword: _search.text.trim(),
        authType: _authType,
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
        initial = await AdminApi.getUser(id);
      } catch (e) {
        if (mounted) adminSnack(context, adminError(e), error: true);
        return;
      }
    }
    if (!mounted) return;
    final saved = await showDialog<bool>(
      context: context,
      builder: (_) => _UserForm(initial: initial),
    );
    if (saved == true) {
      if (mounted) adminSnack(context, id == null ? '用戶新增成功' : '用戶資料已更新');
      _load();
    }
  }

  Future<void> _toggle(Map<String, dynamic> u) async {
    final id = _i(u['au_id']);
    final active = u['is_active'] == true;
    if (active &&
        !await adminConfirm(
          context,
          '停用用戶',
          '確定要停用「${u['auth_name']}」嗎？停用後無法登入，資料會保留。',
          ok: '停用',
        )) {
      return;
    }
    try {
      if (active) {
        await AdminApi.deleteUser(id);
      } else {
        final d = await AdminApi.getUser(id);
        await AdminApi.updateUser(id, _userBody(d, isActive: true));
      }
      if (!mounted) return;
      adminSnack(context, active ? '用戶已停用' : '用戶已還原');
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
              hint: '搜尋名稱或 Email',
              onSubmit: () => _load(page: 1),
            ),
          ),
          AdminDropdown<int>(
            label: '身分',
            value: _authType,
            options: const {null: '全部', 1: '遊客', 2: '商家', 3: '管理員'},
            onChanged: (v) {
              setState(() => _authType = v);
              _load(page: 1);
            },
          ),
          AdminDropdown<bool>(
            label: '狀態',
            value: _active,
            options: const {null: '全部', true: '啟用', false: '停用'},
            onChanged: (v) {
              setState(() => _active = v);
              _load(page: 1);
            },
          ),
          FilledButton.icon(
            onPressed: () => _openForm(),
            icon: const Icon(Icons.person_add_alt_1, size: 18),
            label: const Text('新增用戶'),
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
              AdminCol('用戶', 4),
              AdminCol('身分', 2),
              AdminCol('狀態', 2),
              AdminCol('劇本 / 徽章', 2),
              AdminCol('最後登入', 3),
              AdminCol('操作', 3),
            ],
            rows: [for (final u in _items) _row(u)],
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

  AdminRowData _row(Map<String, dynamic> u) {
    final id = _i(u['au_id']);
    final type = _i(u['auth_type']);
    final active = u['is_active'] == true;
    final name = '${u['auth_name'] ?? ''}';

    final avatar = CircleAvatar(
      radius: 18,
      backgroundColor: _roleSoft(type),
      child: Text(
        name.isEmpty ? '?' : String.fromCharCode(name.runes.first),
        style: AdminText.bodySmall.copyWith(
          color: _roleColor(type),
          fontWeight: FontWeight.w700,
        ),
      ),
    );

    final roleChip = AdminChip(
      _roles[type] ?? '未知',
      _roleColor(type),
      _roleSoft(type),
    );
    final statusChip = active
        ? const AdminChip(
            '啟用',
            AdminColors.highlight,
            AdminColors.highlightSoft,
          )
        : const AdminChip('停用', AdminColors.danger, AdminColors.dangerSoft);

    final actions = Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        adminIconButton('編輯', Icons.edit_outlined, () => _openForm(id: id)),
        adminIconButton(
          active ? '停用' : '還原',
          active ? Icons.block : Icons.restore,
          () => _toggle(u),
          color: active ? AdminColors.danger : AdminColors.highlight,
        ),
      ],
    );

    final nameText = Text(
      name,
      maxLines: 1,
      overflow: TextOverflow.ellipsis,
      style: AdminText.bodySmall.copyWith(fontWeight: FontWeight.w700),
    );
    final emailText = Text(
      '${u['auth_email'] ?? ''}',
      maxLines: 1,
      overflow: TextOverflow.ellipsis,
      style: AdminText.caption,
    );

    return AdminRowData(
      onTap: () => _openForm(id: id),
      cells: [
        Row(
          children: [
            avatar,
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [nameText, emailText],
              ),
            ),
          ],
        ),
        roleChip,
        statusChip,
        Text(
          '${u['story_count'] ?? 0} / ${u['badge_count'] ?? 0}',
          style: AdminText.bodySmall,
        ),
        Text(adminDate(u['last_login_at']), style: AdminText.caption),
        actions,
      ],
      compact: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          avatar,
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                nameText,
                emailText,
                const SizedBox(height: 6),
                Wrap(
                  spacing: 6,
                  runSpacing: 6,
                  children: [roleChip, statusChip],
                ),
                const SizedBox(height: 4),
                Text(
                  '劇本 ${u['story_count'] ?? 0}・徽章 ${u['badge_count'] ?? 0}・登入 ${adminDate(u['last_login_at'])}',
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

class _UserForm extends StatefulWidget {
  const _UserForm({this.initial});

  final Map<String, dynamic>? initial;

  @override
  State<_UserForm> createState() => _UserFormState();
}

class _UserFormState extends State<_UserForm> {
  late final _name = TextEditingController(
    text: '${widget.initial?['auth_name'] ?? ''}',
  );
  late final _email = TextEditingController(
    text: '${widget.initial?['auth_email'] ?? ''}',
  );
  final _pswd = TextEditingController();
  late int _type = _roles.containsKey(_i(widget.initial?['auth_type']))
      ? _i(widget.initial?['auth_type'])
      : 1;
  late bool _active = widget.initial?['is_active'] != false;
  late bool _verified = widget.initial?['is_email_verified'] == true;
  late String? _birthday = widget.initial?['au_birthday']?.toString();
  late String? _gender = widget.initial?['au_gender']?.toString();
  bool _saving = false;
  String? _err;

  bool get _edit => widget.initial != null;

  @override
  void dispose() {
    _name.dispose();
    _email.dispose();
    _pswd.dispose();
    super.dispose();
  }

  Future<void> _pickBirthday() async {
    final now = DateTime.now();
    final cur = DateTime.tryParse(_birthday ?? '') ?? DateTime(2000);
    final d = await showDatePicker(
      context: context,
      initialDate: cur.isAfter(now) ? now : cur,
      firstDate: DateTime(1900),
      lastDate: now,
    );
    if (d != null) {
      setState(
        () => _birthday = DateTime(d.year, d.month, d.day).toIso8601String(),
      );
    }
  }

  Future<void> _save() async {
    final name = _name.text.trim();
    final email = _email.text.trim();
    if (name.isEmpty || email.isEmpty) {
      setState(() => _err = '請填寫名稱與 Email');
      return;
    }
    if (!_edit && _pswd.text.length < 6) {
      setState(() => _err = '密碼至少 6 碼');
      return;
    }
    setState(() {
      _saving = true;
      _err = null;
    });
    try {
      if (_edit) {
        await AdminApi.updateUser(_i(widget.initial!['au_id']), {
          'auth_name': name,
          'auth_email': email,
          'auth_type': _type,
          'is_active': _active,
          'is_email_verified': _verified,
          'au_birthday': _birthday,
          'au_gender': _gender,
        });
      } else {
        await AdminApi.createUser({
          'auth_name': name,
          'auth_email': email,
          'auth_pswd': _pswd.text,
          'auth_type': _type,
          if (_birthday != null) 'au_birthday': _birthday,
          if (_gender != null && _gender!.isNotEmpty) 'au_gender': _gender,
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
    final g = _gender?.toLowerCase();

    return AdminDialogFrame(
      title: _edit ? '編輯用戶' : '新增用戶',
      saving: _saving,
      onSave: _save,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SizedBox(height: 6),
          adminField('名稱', _name),
          adminField('Email', _email, type: TextInputType.emailAddress),
          if (!_edit) adminField('密碼（至少 6 碼）', _pswd, obscure: true),
          Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: DropdownButtonFormField<int>(
              value: _type,
              style: adminDropdownStyle(context),
              decoration: const InputDecoration(labelText: '身分'),
              items: [
                for (final e in _roles.entries)
                  DropdownMenuItem(
                    value: e.key,
                    child: Text(e.value, style: AdminText.bodySmall),
                  ),
              ],
              onChanged: (v) => setState(() => _type = v ?? _type),
            ),
          ),
          Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: DropdownButtonFormField<String?>(
              value: (g == 'male' || g == 'female') ? g : null,
              style: adminDropdownStyle(context),
              decoration: const InputDecoration(labelText: '性別'),
              items: const [
                DropdownMenuItem(
                  value: null,
                  child: Text('未設定', style: AdminText.bodySmall),
                ),
                DropdownMenuItem(
                  value: 'male',
                  child: Text('男', style: AdminText.bodySmall),
                ),
                DropdownMenuItem(
                  value: 'female',
                  child: Text('女', style: AdminText.bodySmall),
                ),
              ],
              onChanged: (v) => setState(() => _gender = v),
            ),
          ),
          Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: InkWell(
              onTap: _pickBirthday,
              child: InputDecorator(
                decoration: InputDecoration(
                  labelText: '生日',
                  suffixIcon: _birthday == null
                      ? const Icon(Icons.calendar_today_outlined, size: 18)
                      : IconButton(
                          icon: const Icon(Icons.close, size: 18),
                          onPressed: () => setState(() => _birthday = null),
                        ),
                ),
                child: Text(
                  _birthday == null ? '未設定' : _birthday!.split('T').first,
                  style: AdminText.body,
                ),
              ),
            ),
          ),
          if (_edit) ...[
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              title: const Text('啟用帳號', style: AdminText.body),
              value: _active,
              onChanged: (v) => setState(() => _active = v),
            ),
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              title: const Text('信箱已驗證', style: AdminText.body),
              value: _verified,
              onChanged: (v) => setState(() => _verified = v),
            ),
          ],
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
