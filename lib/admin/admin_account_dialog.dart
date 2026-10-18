import 'package:flutter/material.dart';

import '../api/admin_api.dart';
import 'admin_theme.dart';
import 'admin_widgets.dart';

class AccountDialog extends StatefulWidget {
  const AccountDialog({super.key, required this.name});

  final String name;

  @override
  State<AccountDialog> createState() => _AccountDialogState();
}

class _AccountDialogState extends State<AccountDialog> {
  late final _name = TextEditingController(text: widget.name);
  final _old = TextEditingController();
  final _new = TextEditingController();
  final _confirm = TextEditingController();
  bool _saving = false;
  String? _err;

  @override
  void dispose() {
    _name.dispose();
    _old.dispose();
    _new.dispose();
    _confirm.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final name = _name.text.trim();
    final nameChanged = name != widget.name.trim();
    final anyPwd =
        _old.text.isNotEmpty ||
        _new.text.isNotEmpty ||
        _confirm.text.isNotEmpty;

    if (name.isEmpty) {
      setState(() => _err = '名稱不能是空的');
      return;
    }
    if (anyPwd) {
      if (_old.text.isEmpty || _new.text.isEmpty || _confirm.text.isEmpty) {
        setState(() => _err = '修改密碼需要填寫舊密碼、新密碼與再次輸入新密碼');
        return;
      }

      if (_new.text.length < 8 ||
          !RegExp(r'[A-Z]').hasMatch(_new.text) ||
          !RegExp(r'[a-z]').hasMatch(_new.text)) {
        setState(() {
          _err = '新密碼至少 8 碼，且必須包含英文大寫及小寫字母';
        });
        return;
      }

      if (_new.text != _confirm.text) {
        setState(() => _err = '兩次輸入的新密碼不一致');
        return;
      }
    }
    if (!nameChanged && !anyPwd) {
      setState(() => _err = '沒有要修改的內容');
      return;
    }

    setState(() {
      _saving = true;
      _err = null;
    });

    var pwdDone = false;
    try {
      if (anyPwd) {
        await AdminApi.changePassword(_old.text, _new.text);
        pwdDone = true;
      }
      if (nameChanged) {
        await AdminApi.updateProfile(name);
      }
      if (!mounted) return;
      Navigator.of(context).pop(<String, String?>{
        'name': nameChanged ? name : null,
        'message': nameChanged && anyPwd
            ? '名稱與密碼已更新'
            : (nameChanged ? '名稱已更新' : '密碼修改成功'),
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _saving = false;
        if (pwdDone) {
          _old.clear();
          _new.clear();
          _confirm.clear();
          _err = '密碼已修改，但名稱更新失敗：${adminError(e)}';
        } else {
          _err = adminError(e);
        }
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return AdminDialogFrame(
      title: '帳號設定',
      saving: _saving,
      onSave: _save,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SizedBox(height: 6),
          adminField('帳號名稱', _name),
          const Divider(color: AdminColors.border),
          const SizedBox(height: 10),
          const Text('修改密碼（不改請留空）', style: AdminText.section),
          const SizedBox(height: 12),
          adminField('舊密碼', _old, obscure: true),
          adminField('新密碼（至少 8 碼，需含英文大小寫）', _new, obscure: true),
          adminField('再次輸入新密碼', _confirm, obscure: true),
          if (_err != null)
            Padding(
              padding: const EdgeInsets.only(top: 4, bottom: 6),
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
