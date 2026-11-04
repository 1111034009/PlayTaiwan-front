import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import '../core/app_text_styles.dart';

/// 地圖頁的字體大小。
/// 只影響地圖頁（route_map/ 底下）和「做任務」頁，不會動到其他頁面。
abstract final class MapText {
  static const double scale = 1.15;

  static const double micro = AppTextStyles.microSize * scale;
  static const double caption = AppTextStyles.captionSize * scale;
  static const double bodySmall = AppTextStyles.bodySmallSize * scale;
  static const double body = AppTextStyles.bodySize * scale;
  static const double sectionTitle = AppTextStyles.sectionTitleSize * scale;
  static const double title = AppTextStyles.titleSize * scale;
}

/// 藏寶圖配色
class Pal {
  static const parchment = Color(0xFFF3E4C1);
  static const parchmentDeep = Color(0xFFE7D3A4);
  static const ink = Color(0xFF3B2A1A);
  static const inkSoft = Color(0xFF6B5237);
  static const cinnabar = Color(0xFF9E2A17);
  static const gold = Color(0xFFB8862B);
  static const moss = Color(0xFF4F6B3A);
  static const plum = Color(0xFF5A3D78);
  static const disabled = Color(0xFFB9AE98);

  /// 選取中的底色（底部分頁、分段按鈕），取代主題自動產生的粉紅色
  static const selected = Color(0xFFD6B56E);

  /// 地圖迷霧
  static const fog = Color(0xFF2A1E14);
}

/// 地圖頁用的配色（羊皮紙、朱砂紅）。嵌進正式 App 時把地圖頁包在這個 Theme 裡，[fontFamily] 給那邊的字型
ThemeData buildTheme({String? fontFamily}) {
  final scheme = ColorScheme.fromSeed(
    seedColor: Pal.cinnabar,
    brightness: Brightness.light,
    surface: Pal.parchment,
    primary: Pal.cinnabar,
    secondary: Pal.gold,
    secondaryContainer: Pal.selected,
    onSecondaryContainer: Pal.ink,
  );
  return ThemeData(
    fontFamily: fontFamily,
    useMaterial3: true,
    colorScheme: scheme,
    scaffoldBackgroundColor: Pal.parchment,
    // 沒有特別指定字級的 Text 會吃這裡（原本這段寫在 ThemeData 外面，沒有生效）
    textTheme: TextTheme(
      bodyLarge: AppTextStyles.body.copyWith(fontSize: MapText.body),
      bodyMedium: AppTextStyles.bodySmall.copyWith(fontSize: MapText.bodySmall),
      bodySmall: AppTextStyles.caption.copyWith(fontSize: MapText.caption),
      titleLarge: AppTextStyles.title.copyWith(fontSize: MapText.title),
      titleMedium: AppTextStyles.sectionTitle.copyWith(
        fontSize: MapText.sectionTitle,
      ),
      labelLarge: AppTextStyles.button.copyWith(fontSize: MapText.body),
      labelMedium: AppTextStyles.label.copyWith(fontSize: MapText.caption),
    ),
    appBarTheme: const AppBarTheme(
      backgroundColor: Pal.ink,
      foregroundColor: Pal.parchment,
      centerTitle: false,
    ),
    cardTheme: CardThemeData(
      color: const Color(0xFFFBF3DF),
      elevation: 0,
      margin: const EdgeInsets.symmetric(vertical: 5),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(10),
        side: const BorderSide(color: Pal.parchmentDeep, width: 1.2),
      ),
    ),
    chipTheme: const ChipThemeData(backgroundColor: Color(0xFFFBF3DF)),
    navigationBarTheme: const NavigationBarThemeData(
      backgroundColor: Pal.parchmentDeep,
      indicatorColor: Pal.selected,
    ),
  );
}

/// 路線的白色外框（兩邊各一半寬）。每種交通方式都加：底圖是羊皮紙色，白邊把路線跟底下的道路分開，長輩也看得清楚
const routeCasingWidth = 4.0;

/// 各交通方式在地圖上的畫法：顏色、線型、圖示都不一樣，一眼就分得出來。
/// 給長輩看的配色：都是深色、線比較粗；最常一起出現的步行（藍）和公車（紅）不用綠配紅，色盲也分得出來
class ModeStyle {
  const ModeStyle({
    required this.icon,
    required this.color,
    required this.pattern,
    required this.width,
  });

  final IconData icon;
  final Color color;
  final StrokePattern pattern;
  final double width;
}

/// 公車是市區公車與客運；台灣好行是另外一個交通方式，可以單獨勾選
const allModes = ['步行', '腳踏車', '機車', '汽車', '公車', '台灣好行', '捷運'];

ModeStyle modeStyle(String mode, {Color? lineColor}) {
  switch (mode) {
    case '步行':
      return const ModeStyle(
        icon: Icons.directions_walk,
        color: Color(0xFF1A47A0),
        pattern: StrokePattern.dotted(spacingFactor: 1.8),
        width: 8,
      );
    case '腳踏車':
      return ModeStyle(
        icon: Icons.pedal_bike,
        color: const Color(0xFFB85300),
        pattern: StrokePattern.dashed(segments: const [18, 8]),
        width: 7,
      );
    case '機車':
      return ModeStyle(
        icon: Icons.two_wheeler,
        color: const Color(0xFF6A1B9A),
        pattern: StrokePattern.dashed(segments: const [24, 7, 5, 7]),
        width: 7,
      );
    case '汽車':
      return const ModeStyle(
        icon: Icons.directions_car,
        color: Color(0xFF263238),
        pattern: StrokePattern.solid(),
        width: 8,
      );
    case '公車':
      return const ModeStyle(
        icon: Icons.directions_bus,
        color: Color(0xFFB3261E),
        pattern: StrokePattern.solid(),
        width: 9,
      );
    case '台灣好行':
      return const ModeStyle(
        icon: Icons.airport_shuttle,
        color: Color(0xFF00695C),
        pattern: StrokePattern.solid(),
        width: 9,
      );
    case '捷運':
      return ModeStyle(
        icon: Icons.subway,
        color: lineColor ?? const Color(0xFF00897B),
        pattern: const StrokePattern.solid(),
        width: 9,
      );
    default: // 轉乘
      return const ModeStyle(
        icon: Icons.transfer_within_a_station,
        color: Color(0xFF616161),
        pattern: StrokePattern.dotted(),
        width: 6,
      );
  }
}
