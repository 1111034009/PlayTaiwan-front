import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:audioplayers/audioplayers.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'pages/login_page.dart';
import 'pages/home_page.dart';
import 'pages/story_play_page.dart';
import 'pages/story_route_map_page.dart';
import 'pages/collection_page.dart';
import 'pages/past_page.dart';
import 'pages/register_page.dart';
import 'pages/merchant_home_page.dart';
import 'core/app_colors.dart';
import 'core/app_text_styles.dart';
import 'core/auth_guard.dart';
import 'core/bgm_service.dart';
import 'block/app_shell.dart';
import 'admin/admin_shell.dart';
import 'api/vlog_watcher.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await dotenv.load(fileName: ".env");
  AuthGuard.init();
  await AudioPlayer.global.setAudioContext(
    AudioContextConfig(focus: AudioContextConfigFocus.mixWithOthers).build(),
  );
  await BgmService.instance.init();
  runApp(const PlayTaiwanApp());
}

class PlayTaiwanApp extends StatelessWidget {
  const PlayTaiwanApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      navigatorKey: AuthGuard.navigatorKey,
      scaffoldMessengerKey: rootMessengerKey,
      navigatorObservers: [AuthGuard.observer],
      title: '日遊所思，夜遊所夢',
      debugShowCheckedModeBanner: false,

      // 設定繁體中文
      locale: const Locale('zh', 'TW'),
      supportedLocales: const [Locale('zh', 'TW'), Locale('en', 'US')],
      localizationsDelegates: const [
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      theme: ThemeData(
        scaffoldBackgroundColor: AppColors.background,
        colorScheme: const ColorScheme.light(
          primary: AppColors.primary,
          onPrimary: Colors.white,
          surface: AppColors.paper,
          onSurface: AppColors.textPrimary,
        ),
        textTheme: TextTheme(
          bodyLarge: AppTextStyles.body,
          bodyMedium: AppTextStyles.bodySmall,
          bodySmall: AppTextStyles.caption,
          titleLarge: AppTextStyles.title,
          titleMedium: AppTextStyles.sectionTitle,
          labelLarge: AppTextStyles.button,
          labelMedium: AppTextStyles.label,
        ),
      ),
      initialRoute: '/login',
      routes: {
        '/login': (context) => const LoginPage(),
        '/home': (context) => AppShell(child: HomePage()),
        '/story': (context) => const StoryPage(),
        // 真的地圖（lib/route_map）。原本手繪的那一頁還留在 pages/story_map_page.dart，沒有刪
        '/story-map': (context) => const StoryRouteMapPage(),
        '/collection': (context) => const CollectionPage(),
        '/past': (context) => const PastPage(),
        '/merchant-home': (context) => const MerchantHomePage(),
        '/register': (context) => const RegisterPage(),
        '/admin': (context) => const AdminShell(),
      },
    );
  }
}
