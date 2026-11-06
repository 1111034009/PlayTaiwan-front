// 跑版檢查要掃的頁面。新頁面加在這裡；需要參數的頁面給一份測試資料
import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';

import 'package:playtaiwan/admin/admin_shell.dart';
import 'package:playtaiwan/admin/badges_page.dart';
import 'package:playtaiwan/admin/stories_page.dart';
import 'package:playtaiwan/admin/users_page.dart';
import 'package:playtaiwan/admin/visitor_dashboard_page.dart';
import 'package:playtaiwan/block/policy_dialog.dart';
import 'package:playtaiwan/block/script_generating_overlay.dart';
import 'package:playtaiwan/block/story_location_popup.dart';
import 'package:playtaiwan/block/story_task_popup.dart';
import 'package:playtaiwan/pages/ai_talk_page.dart';
import 'package:playtaiwan/pages/choose_script_page.dart';
import 'package:playtaiwan/pages/merchant_video_page.dart';
import 'package:playtaiwan/pages/past_detail_page.dart';
import 'package:playtaiwan/pages/past_media_page.dart';
import 'package:playtaiwan/pages/qrcode_information_page.dart';
import 'package:playtaiwan/pages/script_detail_page.dart';
import 'package:playtaiwan/pages/story_map_page.dart';
import 'package:playtaiwan/pages/story_play_page.dart';
import 'package:playtaiwan/pages/story_postcard_page.dart';
import 'package:playtaiwan/pages/story_route_map_page.dart';
import 'package:playtaiwan/pages/travel_info_page.dart';
import 'package:playtaiwan/pages/vlog_check_page.dart';
import 'package:playtaiwan/pages/collection_page.dart';
import 'package:playtaiwan/pages/home_page.dart';
import 'package:playtaiwan/pages/login_page.dart';
import 'package:playtaiwan/pages/love_story_page.dart';
import 'package:playtaiwan/pages/merchant_browse_page.dart';
import 'package:playtaiwan/pages/merchant_coupon_page.dart';
import 'package:playtaiwan/pages/merchant_files_page.dart';
import 'package:playtaiwan/pages/merchant_home_page.dart';
import 'package:playtaiwan/pages/merchant_info_page.dart';
import 'package:playtaiwan/pages/merchant_input_page.dart';
import 'package:playtaiwan/pages/merchant_register_page.dart';
import 'package:playtaiwan/pages/merchant_task_page.dart';
import 'package:playtaiwan/pages/nearby_page.dart';
import 'package:playtaiwan/pages/pair_join_page.dart';
import 'package:playtaiwan/pages/past_page.dart';
import 'package:playtaiwan/pages/play_idea_page.dart';
import 'package:playtaiwan/pages/register_page.dart';
import 'package:playtaiwan/pages/selection_page.dart';
import 'package:playtaiwan/pages/story_end_page.dart';
import 'package:playtaiwan/pages/story_qrcode_page.dart';
import 'package:playtaiwan/pages/story_question_page.dart';
import 'package:playtaiwan/pages/wallet_page.dart';

/// 頁面參數用的劇本資料（test/fixtures/layout_audit/pages，取自資料庫裡 Demo 帳號的劇本）
Map<String, dynamic> _pageFixture(String name) =>
    jsonDecode(File('test/fixtures/layout_audit/pages/$name.json').readAsStringSync()) as Map<String, dynamic>;

/// 真實帳號模式（AUDIT_FIXTURES）的頁面參數：pages/live.json（劇本、站點、影片的 ID 等）；沒有就不掃這些頁
Map<String, dynamic>? _live() {
  final dir = Platform.environment['AUDIT_FIXTURES'];
  final file = File('$dir/pages/live.json');
  return dir != null && file.existsSync() ? jsonDecode(file.readAsStringSync()) as Map<String, dynamic> : null;
}

const Set<String> _merchantPages = {
  '商家首頁', '商家資訊', '商家優惠券', '商家檔案', '商家影片輸入', '商家任務', '商家影片',
};

/// 每一頁用哪個身分登入：遊客、商家、管理者
String auditRole(String page) =>
    page.startsWith('管理') ? 'admin' : (_merchantPages.contains(page) ? 'merchant' : 'tourist');

/// 商家身分的店家 ID（真實模式讀 pages/live.json 的 store_id）
int? auditStoreId() => (_live()?['store_id'] as num?)?.toInt();

/// 需要真實資料（ID）的頁面
Map<String, Widget Function()> _livePages() {
  final live = _live();
  if (live == null) return {};
  String id(String key) => '${live[key] ?? ''}';
  void noop() {}
  return {
    '劇本詳情（真實）': () => ScriptDetailPage(storyId: id('story_id')),
    '過往詳情（真實）': () => PastDetailPage(storyId: id('completed_story_id')),
    '過往影音': () => PastMediaPage(storyId: id('completed_story_id')),
    'VLOG 確認': () => VlogCheckPage(storyId: id('completed_story_id')),
    '劇本結束（真實）': () => StoryEndPage(storyId: id('completed_story_id')),
    '地圖': () => const StoryRouteMapPage(),
    '舊版地圖': () => const StoryMapPage(),
    '明信片拍照': () => StoryPostcardPage(
          storyId: (live['story_id'] as num?)?.toInt(),
          nodeId: (live['node_id'] as num?)?.toInt(),
          spotName: id('spot_name'),
        ),
    '任務彈窗': () => Scaffold(
          body: Center(
            child: StoryTaskPopup(
              title: id('spot_name'),
              onClose: noop,
              onReviewStory: noop,
              onBack: noop,
              onStartTask: noop,
            ),
          ),
        ),
    '地點彈窗': () => Scaffold(
          body: Center(
            child: StoryLocationPopup(
              title: id('spot_name'),
              description: id('spot_description'),
              onClose: noop,
              onReviewStory: noop,
              onAround: noop,
              onMission: noop,
              onNavigate: noop,
            ),
          ),
        ),
    'QR 商家資訊': () => NfcInformationPage(result: Map<String, dynamic>.from(live['qr_result'] as Map)),
    '商家影片': () => MerchantVideoPage(mmId: (live['mm_id'] as num).toInt()),
  };
}

Map<String, Widget Function()> auditPages() => {
      '登入': () => const LoginPage(),
      '註冊': () => const RegisterPage(),
      '首頁': () => const HomePage(),
      '收藏': () => const CollectionPage(),
      '過往': () => const PastPage(),
      '錢包': () => const WalletPage(),
      '附近': () => const NearbyPage(),
      '選擇玩法': () => const SelectionPage(),
      '遊你說了算': () => const PlayIdeaPage(),
      'AI 對話': () => const AiTalkPage(),
      '愛情故事': () => const LoveStoryPage(),
      '加入隊伍': () => const PairJoinPage(),
      '劇本結束': () => const StoryEndPage(),
      '掃描 QR': () => const StoryNfcPage(),
      '問答題': () => const StoryQuestionPage(),
      '選劇本': () => ChooseScriptPage(
            generatedScript: _pageFixture('choose_scripts'),
            cityName: '臺中市',
            townName: '西區',
            transportation: const ['步行', '公車'],
            partySize: 2,
          ),
      '劇本詳情': () => ScriptDetailPage(
            title: '珊瑚海的秘密',
            generatedScript: _pageFixture('story_394'),
            storyId: '394',
            cityName: '花蓮縣',
            townName: '花蓮市',
            transportation: const ['步行'],
          ),
      '遊玩中': () => StoryPage(generatedScript: _pageFixture('story_394')),
      '過往詳情': () => const PastDetailPage(storyId: '394', title: '珊瑚海的秘密', completedDate: '2026.10.09'),
      '旅遊資訊': () => const TravelInfoPage(cityName: '臺中市', townName: '西區'),
      '條款視窗': () => const Scaffold(body: Center(child: PolicyDialog())),
      '生成中畫面': () => const Scaffold(
            body: ScriptGeneratingOverlay(
              message: '劇本生成中，請稍候',
              progress: 0.45,
              detail: '正在挑選附近的景點與合作商家',
            ),
          ),
      '商家瀏覽': () => const MerchantBrowsePage(),
      '商家首頁': () => const MerchantHomePage(),
      '商家資訊': () => const MerchantInfoPage(),
      '商家優惠券': () => const MerchantCouponPage(),
      '商家檔案': () => const MerchantFilesPage(),
      '商家影片輸入': () => const MerchantInputPage(),
      '商家註冊': () => const StoryRegisterPage(),
      '商家任務': () => const MerchantTaskPage(),
      // 管理頁平常放在 AdminShell 的 Scaffold 裡
      '管理：外框': () => const AdminShell(),
      '管理：客群分析': () => const Scaffold(body: AudienceDashboardPage()),
      '管理：勳章': () => const Scaffold(body: BadgesPage()),
      '管理：劇本': () => const Scaffold(body: StoriesPage()),
      '管理：使用者': () => const Scaffold(body: UsersPage()),
      ..._livePages(),
    };
