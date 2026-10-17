import 'package:flutter/material.dart';
import 'app_session.dart';

class AuthGuard {
  static final GlobalKey<NavigatorState> navigatorKey =
      GlobalKey<NavigatorState>();

  /// 不需登入的頁面
  static const Set<String> publicRoutes = {'/login', '/register', '/splash'};

  static final NavigatorObserver observer = _AuthObserver();

  static void init() {
    AppSession.tokenNotifier.addListener(() {
      if (AppSession.token == null) _toLogin();
    });
  }

  static void _toLogin() {
    navigatorKey.currentState?.pushNamedAndRemoveUntil(
      '/login',
      (route) => false,
    );
  }
}

class _AuthObserver extends NavigatorObserver {
  @override
  void didPush(Route<dynamic> route, Route<dynamic>? previousRoute) {
    final name = route.settings.name;
    if (name != null &&
        !AuthGuard.publicRoutes.contains(name) &&
        AppSession.token == null) {
      WidgetsBinding.instance.addPostFrameCallback((_) => AuthGuard._toLogin());
    }
  }
}
