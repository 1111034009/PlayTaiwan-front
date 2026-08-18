import 'package:flutter/material.dart';
import 'pages/login_page.dart';
import 'pages/home_page.dart';
import 'pages/story_play_page.dart';
import 'pages/story_map_page.dart';
import 'pages/collection_page.dart';
import 'pages/past_page.dart';

import 'pages/user_type_page.dart';
import 'pages/merchant_home_page.dart';

void main() {
  runApp(const PlayTaiwanApp());
}

class PlayTaiwanApp extends StatelessWidget {
  const PlayTaiwanApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: '日遊所思，夜遊所夢',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        scaffoldBackgroundColor: const Color(0xFFB9ACA2),
        fontFamily: 'serif',
      ),
      initialRoute: '/login',
      routes: {
        '/login': (context) => const LoginPage(),
        '/home': (context) => const HomePage(),
        '/story': (context) => const StoryPage(),
        '/story-map': (context) => const StoryMapPage(),
        '/collection': (context) => const CollectionPage(),
        '/past': (context) => const PastPage(),
        '/user-type': (context) => const UserTypePage(),
        '/merchant-home': (context) => const MerchantHomePage(),
      },
    );
  }
}
