import 'package:flutter/material.dart';

import '../api/admin_api.dart';
import '../core/app_session.dart';
import 'admin_account_dialog.dart';
import 'admin_theme.dart';
import 'admin_widgets.dart';
import 'badges_page.dart';
import 'stories_page.dart';
import 'users_page.dart';
import 'visitor_dashboard_page.dart';

class _Nav {
  const _Nav(this.id, this.label, this.icon);
  final String id;
  final String label;
  final IconData icon;
}

const _navs = [
  _Nav('dashboard', '首頁總覽', Icons.dashboard_outlined),
  _Nav('users', '用戶管理', Icons.people_alt_outlined),
  _Nav('stories', '劇本管理', Icons.menu_book_outlined),
  _Nav('badges', '徽章管理', Icons.workspace_premium_outlined),
];

class AdminShell extends StatefulWidget {
  const AdminShell({super.key, this.onLogout});

  final VoidCallback? onLogout;

  @override
  State<AdminShell> createState() => _AdminShellState();
}

class _AdminShellState extends State<AdminShell> {
  String _tab = 'dashboard';
  bool _open = false;
  double _dragX = 0;
  Map<String, dynamic>? _profile;

  @override
  void initState() {
    super.initState();
    _loadProfile();
  }

  Future<void> _loadProfile() async {
    try {
      final p = await AdminApi.profile();
      if (mounted) setState(() => _profile = p);
    } catch (_) {}
  }

  void _close() {
    _dragX = 0;
    if (_open) setState(() => _open = false);
  }

  void _dragClose(DragUpdateDetails d) {
    _dragX += d.delta.dx;
    if (_dragX < -20) _close();
  }

  void _select(String id) {
    _dragX = 0;
    setState(() {
      _tab = id;
      _open = false;
    });
  }

  Future<void> _account() async {
    _close();
    final r = await showDialog<Map<String, String?>>(
      context: context,
      builder: (_) => AccountDialog(name: '${_profile?['auth_name'] ?? ''}'),
    );
    if (r == null || !mounted) return;
    final name = r['name'];
    if (name != null) {
      setState(() => _profile = {...?_profile, 'auth_name': name});
    }
    adminSnack(context, r['message'] ?? '已更新');
  }

  Future<void> _logout() async {
    _close();
    if (!await adminConfirm(context, '登出', '確定要登出嗎？', ok: '登出')) return;
    try {
      await AdminApi.logout();
    } catch (_) {}
    AppSession.clear();
    if (!mounted) return;
    widget.onLogout?.call();
  }

  Widget _page() {
    switch (_tab) {
      case 'users':
        return const UsersPage();
      case 'stories':
        return const StoriesPage();
      case 'badges':
        return const BadgesPage();
      default:
        return const AudienceDashboardPage();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Theme(
      data: adminTheme(Theme.of(context)),
      child: LayoutBuilder(
        builder: (context, box) {
          final compact = box.maxWidth < AdminR.desktop;
          final panelW = box.maxWidth < 320 ? box.maxWidth : 280.0;
          final open = compact && _open;
          final title = _navs.firstWhere((n) => n.id == _tab).label;

          final sidebar = _Sidebar(
            selected: _tab,
            profile: _profile,
            onSelect: _select,
            onAccount: _account,
            onLogout: _logout,
            onClose: compact ? _close : null,
          );

          return Scaffold(
            backgroundColor: AdminColors.canvas,
            body: Stack(
              children: [
                Row(
                  children: [
                    if (!compact) SizedBox(width: 244, child: sidebar),
                    Expanded(
                      child: Column(
                        children: [
                          _Header(
                            title: title,
                            compact: compact,
                            onMenu: () => setState(() => _open = true),
                            onLogout: _logout,
                          ),
                          Expanded(
                            child: KeyedSubtree(
                              key: ValueKey(_tab),
                              child: _page(),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                if (compact) ...[
                  Positioned(
                    left: 0,
                    top: 0,
                    bottom: 0,
                    width: 14,
                    child: GestureDetector(
                      behavior: HitTestBehavior.translucent,
                      onHorizontalDragUpdate: (d) {
                        if (!_open && d.delta.dx > 4)
                          setState(() => _open = true);
                      },
                    ),
                  ),
                  Positioned.fill(
                    child: IgnorePointer(
                      ignoring: !open,
                      child: GestureDetector(
                        onTap: _close,
                        onHorizontalDragStart: (_) => _dragX = 0,
                        onHorizontalDragUpdate: _dragClose,
                        child: AnimatedOpacity(
                          opacity: open ? 1 : 0,
                          duration: const Duration(milliseconds: 200),
                          child: const ColoredBox(color: Color(0x66000000)),
                        ),
                      ),
                    ),
                  ),
                  AnimatedPositioned(
                    duration: const Duration(milliseconds: 220),
                    curve: Curves.easeOutCubic,
                    left: open ? 0 : -panelW,
                    top: 0,
                    bottom: 0,
                    width: panelW,
                    child: GestureDetector(
                      onHorizontalDragStart: (_) => _dragX = 0,
                      onHorizontalDragUpdate: _dragClose,
                      child: Material(
                        elevation: 8,
                        color: AdminColors.surface,
                        child: sidebar,
                      ),
                    ),
                  ),
                ],
              ],
            ),
          );
        },
      ),
    );
  }
}

class _Sidebar extends StatelessWidget {
  const _Sidebar({
    required this.selected,
    required this.profile,
    required this.onSelect,
    required this.onAccount,
    required this.onLogout,
    this.onClose,
  });

  final String selected;
  final Map<String, dynamic>? profile;
  final ValueChanged<String> onSelect;
  final VoidCallback onAccount;
  final VoidCallback onLogout;
  final VoidCallback? onClose;

  @override
  Widget build(BuildContext context) {
    final name = '${profile?['auth_name'] ?? '管理者'}';
    final type = '${profile?['account_type_name'] ?? 'Admin'}';

    return Container(
      decoration: const BoxDecoration(
        color: AdminColors.surface,
        border: Border(right: BorderSide(color: AdminColors.border)),
      ),
      child: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(14, 16, 14, 14),
          child: Column(
            children: [
              Row(
                children: [
                  Container(
                    width: 48,
                    height: 48,
                    decoration: BoxDecoration(
                      color: AdminColors.primarySoft,
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: const Icon(
                      Icons.person_rounded,
                      color: AdminColors.primary,
                      size: 28,
                    ),
                  ),
                  const SizedBox(width: 12),
                  const Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('PLAYTAIWAN', style: AdminText.section),
                        SizedBox(height: 3),
                        Text('內容管理後台', style: AdminText.caption),
                      ],
                    ),
                  ),
                  if (onClose != null)
                    IconButton(
                      tooltip: '收起選單',
                      onPressed: onClose,
                      icon: const Icon(
                        Icons.chevron_left_rounded,
                        color: AdminColors.textMuted,
                      ),
                    ),
                ],
              ),
              const SizedBox(height: 24),
              Expanded(
                child: ListView(
                  padding: EdgeInsets.zero,
                  children: [
                    for (final n in _navs) ...[
                      _item(n, selected == n.id),
                      const SizedBox(height: 4),
                    ],
                  ],
                ),
              ),
              const Divider(color: AdminColors.border),
              const SizedBox(height: 4),
              Material(
                color: Colors.transparent,
                child: InkWell(
                  borderRadius: BorderRadius.circular(12),
                  onTap: onAccount,
                  child: Padding(
                    padding: const EdgeInsets.all(6),
                    child: Row(
                      children: [
                        const CircleAvatar(
                          radius: 17,
                          backgroundColor: AdminColors.highlightSoft,
                          child: Icon(
                            Icons.person,
                            size: 18,
                            color: AdminColors.highlight,
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                name,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: AdminText.bodySmall.copyWith(
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                              Text(
                                type,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: AdminText.caption,
                              ),
                            ],
                          ),
                        ),
                        IconButton(
                          tooltip: '登出',
                          onPressed: onLogout,
                          icon: const Icon(
                            Icons.power_settings_new_rounded,
                            size: 20,
                            color: AdminColors.secondary,
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
      ),
    );
  }

  Widget _item(_Nav n, bool on) {
    return Material(
      color: on ? AdminColors.primarySoft : Colors.transparent,
      borderRadius: BorderRadius.circular(12),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: () => onSelect(n.id),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 11),
          child: Row(
            children: [
              Icon(
                n.icon,
                size: 21,
                color: on ? AdminColors.primary : AdminColors.textMuted,
              ),
              const SizedBox(width: 11),
              Expanded(
                child: Text(
                  n.label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: AdminText.body.copyWith(
                    fontWeight: on ? FontWeight.w700 : FontWeight.w500,
                    color: on ? AdminColors.primary : AdminColors.textMain,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _Header extends StatelessWidget {
  const _Header({
    required this.title,
    required this.compact,
    required this.onMenu,
    required this.onLogout,
  });

  final String title;
  final bool compact;
  final VoidCallback onMenu;
  final VoidCallback onLogout;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        color: Color(0xE6FFFFFF),
        border: Border(bottom: BorderSide(color: AdminColors.border)),
      ),
      child: SafeArea(
        bottom: false,
        child: SizedBox(
          height: compact ? 56 : 68,
          child: Padding(
            padding: EdgeInsets.symmetric(horizontal: compact ? 8 : 28),
            child: Row(
              children: [
                if (compact)
                  IconButton(
                    tooltip: '開啟選單',
                    onPressed: onMenu,
                    icon: const Icon(
                      Icons.menu_rounded,
                      color: AdminColors.textMain,
                    ),
                  ),
                Expanded(
                  child: Text(
                    title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: AdminText.title.copyWith(
                      fontSize: compact ? 18 : 21,
                    ),
                  ),
                ),
                if (!compact)
                  OutlinedButton.icon(
                    onPressed: onLogout,
                    icon: const Icon(
                      Icons.power_settings_new_rounded,
                      size: 17,
                    ),
                    label: const Text('登出'),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
