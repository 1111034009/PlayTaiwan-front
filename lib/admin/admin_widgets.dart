import 'package:flutter/material.dart';
import '../core/app_notice.dart';
import 'admin_theme.dart';

String adminError(Object e) => e.toString().replaceFirst('Exception: ', '');

String adminDate(dynamic v) {
  final s = v?.toString() ?? '';
  if (s.isEmpty) return '—';
  final d = DateTime.tryParse(s);
  if (d == null) return s;
  String t(int n) => n.toString().padLeft(2, '0');
  return '${d.year}-${t(d.month)}-${t(d.day)} ${t(d.hour)}:${t(d.minute)}';
}

TextStyle adminDropdownStyle(BuildContext context) => AdminText.bodySmall;

void adminSnack(BuildContext context, String message, {bool error = false}) {
  AppNotice.show(message);
}

Future<bool> adminConfirm(
  BuildContext context,
  String title,
  String message, {
  String ok = '確定',
}) async {
  final r = await showDialog<bool>(
    context: context,
    builder: (d) => AlertDialog(
      backgroundColor: AdminColors.surface,
      title: Text(title, style: AdminText.section),
      content: Text(message, style: AdminText.body),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(d).pop(false),
          child: const Text('取消'),
        ),
        FilledButton(
          onPressed: () => Navigator.of(d).pop(true),
          child: Text(ok),
        ),
      ],
    ),
  );
  return r == true;
}

Widget adminState({
  required bool loading,
  String? error,
  required bool empty,
  required VoidCallback onRetry,
  required Widget child,
}) {
  Widget center(Widget w) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 60),
    child: Center(child: w),
  );

  if (loading) {
    return center(const CircularProgressIndicator(color: AdminColors.primary));
  }
  if (error != null) {
    return center(
      Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.error_outline, size: 36, color: AdminColors.danger),
          const SizedBox(height: 10),
          Text(error, textAlign: TextAlign.center, style: AdminText.caption),
          const SizedBox(height: 12),
          FilledButton(onPressed: onRetry, child: const Text('重新載入')),
        ],
      ),
    );
  }
  if (empty) {
    return center(const Text('沒有符合的資料', style: AdminText.caption));
  }
  return child;
}

Widget adminField(
  String label,
  TextEditingController controller, {
  int lines = 1,
  bool obscure = false,
  TextInputType? type,
  bool enabled = true,
  ValueChanged<String>? onChanged,
}) {
  return Padding(
    padding: const EdgeInsets.only(bottom: 12),
    child: TextField(
      controller: controller,
      enabled: enabled,
      obscureText: obscure,
      keyboardType: type,
      onChanged: onChanged,
      minLines: lines,
      maxLines: lines == 1 ? 1 : lines + 3,
      style: AdminText.body,
      decoration: InputDecoration(labelText: label),
    ),
  );
}

Widget adminIconButton(
  String tip,
  IconData icon,
  VoidCallback onPressed, {
  Color color = AdminColors.textMuted,
}) {
  return IconButton(
    tooltip: tip,
    onPressed: onPressed,
    padding: EdgeInsets.zero,
    constraints: const BoxConstraints(minWidth: 36, minHeight: 36),
    icon: Icon(icon, size: 20, color: color),
  );
}

class AdminChip extends StatelessWidget {
  const AdminChip(this.text, this.color, this.bg, {super.key});

  final String text;
  final Color color;
  final Color bg;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        text,
        style: AdminText.caption.copyWith(
          fontSize: 11,
          fontWeight: FontWeight.w700,
          color: color,
        ),
      ),
    );
  }
}

class AdminCol {
  const AdminCol(this.label, this.flex);

  final String label;
  final int flex;
}

class AdminRowData {
  const AdminRowData({required this.cells, required this.compact, this.onTap});

  final List<Widget> cells;
  final Widget compact;
  final VoidCallback? onTap;
}

class AdminTable extends StatelessWidget {
  const AdminTable({
    super.key,
    required this.columns,
    required this.rows,
    this.breakpoint = 820,
  });

  final List<AdminCol> columns;
  final List<AdminRowData> rows;
  final double breakpoint;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, box) {
        final wide = box.maxWidth >= breakpoint;

        return Material(
          color: AdminColors.surface,
          clipBehavior: Clip.antiAlias,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
            side: const BorderSide(color: AdminColors.border),
          ),
          child: Column(
            children: [
              if (wide)
                Container(
                  color: AdminColors.surfaceSoft,
                  padding: const EdgeInsets.fromLTRB(16, 10, 16, 10),
                  child: Row(
                    children: [
                      for (final c in columns)
                        Expanded(
                          flex: c.flex,
                          child: Text(
                            c.label,
                            style: AdminText.caption.copyWith(
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
              for (var i = 0; i < rows.length; i++) ...[
                if (wide || i > 0)
                  const Divider(height: 1, color: AdminColors.border),
                InkWell(
                  onTap: rows[i].onTap,
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 12,
                    ),
                    child: wide
                        ? Row(
                            children: [
                              for (var j = 0; j < columns.length; j++)
                                Expanded(
                                  flex: columns[j].flex,
                                  child: Padding(
                                    padding: const EdgeInsets.only(right: 8),
                                    child: Align(
                                      alignment: Alignment.centerLeft,
                                      child: rows[i].cells[j],
                                    ),
                                  ),
                                ),
                            ],
                          )
                        : rows[i].compact,
                  ),
                ),
              ],
            ],
          ),
        );
      },
    );
  }
}

class AdminPager extends StatelessWidget {
  const AdminPager({
    super.key,
    required this.page,
    required this.pageSize,
    required this.total,
    required this.onPage,
  });

  final int page;
  final int pageSize;
  final int total;
  final ValueChanged<int> onPage;

  @override
  Widget build(BuildContext context) {
    if (total <= 0) return const SizedBox.shrink();
    final pages = (total + pageSize - 1) ~/ pageSize;
    return Padding(
      padding: const EdgeInsets.only(top: 16),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          IconButton(
            onPressed: page > 1 ? () => onPage(page - 1) : null,
            icon: const Icon(Icons.chevron_left),
          ),
          Flexible(
            child: Text(
              '第 $page / $pages 頁・共 $total 筆',
              textAlign: TextAlign.center,
              style: AdminText.bodySmall,
            ),
          ),
          IconButton(
            onPressed: page < pages ? () => onPage(page + 1) : null,
            icon: const Icon(Icons.chevron_right),
          ),
        ],
      ),
    );
  }
}

class AdminSearch extends StatelessWidget {
  const AdminSearch({
    super.key,
    required this.controller,
    required this.hint,
    required this.onSubmit,
  });

  final TextEditingController controller;
  final String hint;
  final VoidCallback onSubmit;

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: controller,
      textInputAction: TextInputAction.search,
      onSubmitted: (_) => onSubmit(),
      style: AdminText.bodySmall,
      decoration: InputDecoration(
        hintText: hint,
        prefixIcon: const Icon(
          Icons.search,
          size: 20,
          color: AdminColors.textMuted,
        ),
        suffixIcon: IconButton(
          tooltip: '清除',
          icon: const Icon(Icons.close, size: 18, color: AdminColors.textMuted),
          onPressed: () {
            controller.clear();
            onSubmit();
          },
        ),
      ),
    );
  }
}

class AdminDropdown<T> extends StatelessWidget {
  const AdminDropdown({
    super.key,
    required this.label,
    required this.value,
    required this.options,
    required this.onChanged,
    this.width = 150,
  });

  final String label;
  final T? value;
  final Map<T?, String> options;
  final ValueChanged<T?> onChanged;
  final double width;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: width,
      child: DropdownButtonFormField<T?>(
        value: value,
        isExpanded: true,
        decoration: InputDecoration(labelText: label),
        style: AdminText.bodySmall,
        dropdownColor: AdminColors.surface,
        items: [
          for (final e in options.entries)
            DropdownMenuItem<T?>(
              value: e.key,
              child: Text(
                e.value,
                overflow: TextOverflow.ellipsis,
                style: AdminText.bodySmall,
              ),
            ),
        ],
        onChanged: onChanged,
      ),
    );
  }
}

class AdminPageFrame extends StatelessWidget {
  const AdminPageFrame({
    super.key,
    required this.toolbarBuilder,
    required this.children,
    this.footer,
  });

  final Widget Function(double width) toolbarBuilder;
  final List<Widget> children;
  final Widget? footer;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, box) {
        final pad = AdminR.padding(box.maxWidth);
        return Align(
          alignment: Alignment.topCenter,
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: AdminR.contentMax),
            child: Column(
              children: [
                Padding(
                  padding: EdgeInsets.fromLTRB(pad, pad, pad, 4),
                  child: Align(
                    alignment: Alignment.centerLeft,
                    child: toolbarBuilder(box.maxWidth - pad * 2),
                  ),
                ),
                Expanded(
                  child: ListView(
                    padding: EdgeInsets.fromLTRB(pad, 8, pad, pad),
                    children: [...children, if (footer != null) footer!],
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

class AdminDialogFrame extends StatelessWidget {
  const AdminDialogFrame({
    super.key,
    required this.title,
    required this.child,
    required this.onSave,
    this.saving = false,
    this.saveText = '儲存',
  });

  final String title;
  final Widget child;
  final VoidCallback onSave;
  final bool saving;
  final String saveText;

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: AdminColors.surface,
      insetPadding: const EdgeInsets.all(16),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxWidth: 520,
          maxHeight: MediaQuery.sizeOf(context).height * 0.9,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 18, 20, 10),
              child: Align(
                alignment: Alignment.centerLeft,
                child: Text(title, style: AdminText.title),
              ),
            ),
            Flexible(
              child: SingleChildScrollView(
                padding: const EdgeInsets.symmetric(
                  horizontal: 20,
                  vertical: 4,
                ),
                child: child,
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(14),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  TextButton(
                    onPressed: saving
                        ? null
                        : () => Navigator.of(context).pop(),
                    child: const Text('取消'),
                  ),
                  const SizedBox(width: 8),
                  FilledButton(
                    onPressed: saving ? null : onSave,
                    child: saving
                        ? const SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: Colors.white,
                            ),
                          )
                        : Text(saveText),
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
