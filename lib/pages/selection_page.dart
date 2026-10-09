import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:geolocator/geolocator.dart';
import 'package:http/http.dart' as http;

import '../core/app_session.dart';
import '../core/app_colors.dart';
import '../core/app_text_styles.dart';

import '../block/navigationbar.dart';
import 'home_page.dart';
import 'play_idea_page.dart';
import 'travel_info_page.dart';

class SelectionPage extends StatefulWidget {
  const SelectionPage({super.key});

  @override
  State<SelectionPage> createState() => _SelectionPageState();
}

class _SelectionPageState extends State<SelectionPage> {
  // ==================================================================
  // Colors
  // ==================================================================

  static const Color pageColor = AppColors.background;

  static const Color red = AppColors.primaryAccent;

  static const double designWidth = 360;

  static const double designHeight = 600;

  // Navigation Index

  int currentIndex = 0;

  // 地區

  String fakeLocation = '';
  bool isLoadingLocation = false;

  // 地區輸入框

  final TextEditingController locationController = TextEditingController();

  // 一句話輸入框

  final TextEditingController ideaController = TextEditingController();
  //防呆
  static const Set<String> _validCities = {
    '臺北市',
    '新北市',
    '桃園市',
    '臺中市',
    '臺南市',
    '高雄市',
    '基隆市',
    '新竹市',
    '嘉義市',
    '新竹縣',
    '苗栗縣',
    '彰化縣',
    '南投縣',
    '雲林縣',
    '嘉義縣',
    '屏東縣',
    '宜蘭縣',
    '花蓮縣',
    '臺東縣',
    '澎湖縣',
    '金門縣',
    '連江縣',
  };

  static const int _maxIdeaLength = 100;

  String _normalizeCity(String city) {
    return city.trim().replaceAll('台', '臺');
  }

  bool _isValidCity(String city) {
    return _validCities.contains(_normalizeCity(city));
  }

  String? _validateIdea(String idea) {
    final String text = idea.trim();

    if (text.isEmpty) return '先說點什麼吧！';

    if (text.runes.length > _maxIdeaLength) {
      return '內容請在 $_maxIdeaLength 字以內';
    }

    if (RegExp(r'^[\s0-9０-９]+$').hasMatch(text)) {
      return '請輸入文字描述，不能只有數字';
    }

    if (!RegExp(r'\p{L}', unicode: true).hasMatch(text)) {
      return '請輸入文字描述，不能只有符號';
    }

    return null;
  }
  // System UI

  @override
  void initState() {
    super.initState();

    SystemChrome.setSystemUIOverlayStyle(
      const SystemUiOverlayStyle(
        statusBarColor: pageColor,
        statusBarIconBrightness: Brightness.dark,
        statusBarBrightness: Brightness.light,
        systemNavigationBarColor: pageColor,
        systemNavigationBarIconBrightness: Brightness.dark,
      ),
    );
  }

  // ==================================================================
  // Dispose
  // ==================================================================

  @override
  void dispose() {
    locationController.dispose();
    ideaController.dispose();
    super.dispose();
  }

  // ==================================================================
  // 使用當前定位
  // ==================================================================
  Future<void> useCurrentLocation() async {
    if (isLoadingLocation) return;

    setState(() {
      isLoadingLocation = true;
    });

    try {
      final bool serviceEnabled = await Geolocator.isLocationServiceEnabled();

      if (!serviceEnabled) {
        _showLocationMessage('請先開啟手機的定位服務');
        return;
      }

      LocationPermission permission = await Geolocator.checkPermission();

      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();

        if (permission == LocationPermission.denied) {
          _showLocationMessage('需要定位權限才能取得目前位置');
          return;
        }
      }

      if (permission == LocationPermission.deniedForever) {
        _showLocationMessage('定位權限已被永久拒絕，請到手機設定開啟');
        return;
      }

      final Position position = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.high,
        ),
      );

      final String baseUrl = (dotenv.env['API_BASE_URL'] ?? '')
          .trim()
          .replaceFirst(RegExp(r'/$'), '');

      final String url = '$baseUrl/api/Map/Location';

      final String? token = AppSession.token;

      if (token == null || token.isEmpty) {
        _showLocationMessage('登入資訊已失效，請重新登入');
        return;
      }

      final response = await http.post(
        Uri.parse(url),
        headers: {
          'accept': 'text/plain',
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
        body: jsonEncode({
          'lat': position.latitude,
          'lng': position.longitude,
          'accuracy': 10,
        }),
      );

      if (response.statusCode >= 200 && response.statusCode < 300) {
        final Map<String, dynamic> data = jsonDecode(response.body);

        if (data['isSuccess'] == true) {
          final result = data['Result'];

          if (result is Map<String, dynamic>) {
            final String cityName =
                result['city_name']?.toString().trim() ?? '';

            final String districtName =
                result['district_name']?.toString().trim() ?? '';

            final String location = [
              cityName,
              districtName,
            ].where((value) => value.isNotEmpty).join(' ');

            if (location.isEmpty) {
              _showLocationMessage('伺服器運行中，請稍後嘗試');
              return;
            }

            if (!mounted) return;

            setState(() {
              fakeLocation = location;
              locationController.text = location;

              locationController.selection = TextSelection.fromPosition(
                TextPosition(offset: locationController.text.length),
              );
            });

            return;
          }
        }
      }

      _showLocationMessage('定位錯誤，請稍後再試');
    } catch (e) {
      print('Location Error: $e');

      if (!mounted) return;

      _showLocationMessage('無法取得目前定位，請稍後再試');
    } finally {
      if (mounted) {
        setState(() {
          isLoadingLocation = false;
        });
      }
    }
  }

  void _showLocationMessage(String message) {
    if (!mounted) return;

    ScaffoldMessenger.of(context).hideCurrentSnackBar();

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          message,
          textAlign: TextAlign.center,
          style: AppTextStyles.bodySmallBold.copyWith(color: Colors.white),
        ),
        backgroundColor: red,
        behavior: SnackBarBehavior.floating,
        duration: const Duration(seconds: 2),
      ),
    );
  }

  // ==================================================================
  // 解析地區
  // ==================================================================

  Map<String, String> _parseLocation(String input) {
    final String text = input.trim().replaceAll(RegExp(r'\s+'), ' ');

    if (text.isEmpty) {
      return {'cityName': '', 'townName': ''};
    }

    final RegExp pattern = RegExp(r'^(.+?[縣市])(?:\s*(.*))?$');

    final Match? match = pattern.firstMatch(text);

    if (match == null) {
      return {'cityName': text, 'townName': ''};
    }

    final String cityName = match.group(1)?.trim() ?? '';
    final String townName = match.group(2)?.trim() ?? '';

    return {'cityName': cityName, 'townName': townName};
  }

  // ==================================================================
  // 現在揪出發
  // ==================================================================

  void startAdventure() {
    fakeLocation = locationController.text.trim();

    if (fakeLocation.isEmpty) {
      _showLocationMessage('請先輸入地區');
      return;
    }

    final Map<String, String> location = _parseLocation(fakeLocation);

    final String rawCity = location['cityName']?.trim() ?? '';
    final String townName = location['townName']?.trim() ?? '';

    if (rawCity.isEmpty || !_isValidCity(rawCity)) {
      _showLocationMessage('請輸入正確的縣市名稱，例如：台中市');
      return;
    }

    final String cityName = _normalizeCity(rawCity);

    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) =>
            TravelInfoPage(cityName: cityName, townName: townName),
      ),
    );
  }
  // ==================================================================
  // 來點遊意思
  // ==================================================================

  void randomAdventure() {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => const PlayIdeaPage()),
    );
  }

  // ==================================================================
  // 遊你說了算
  // ==================================================================
  void customAdventure() {
    final String idea = ideaController.text.trim();

    final String? error = _validateIdea(idea);

    if (error != null) {
      _showLocationMessage(error);
      return;
    }

    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => TravelInfoPage(cityName: '', townName: ''),
      ),
    );
  }
  // ==================================================================
  // 回首頁
  // ==================================================================

  void goToHome() {
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(builder: (context) => const HomePage()),
    );
  }

  // ==================================================================
  // Build
  // ==================================================================

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: pageColor,
      extendBody: true,

      // ================================================================
      // Body
      // ================================================================
      body: Center(
        child: FittedBox(
          fit: BoxFit.contain,
          alignment: Alignment.center,
          child: SizedBox(
            width: designWidth,
            height: designHeight,
            child: Stack(
              clipBehavior: Clip.none,
              children: [
                // ======================================================
                // 背景
                // ======================================================

                Positioned.fill(child: Container(color: pageColor)),

                // ======================================================
                // 第一張紙
                //
                // 遊你說了算
                // ======================================================
                Positioned(
                  left: 0,
                  right: 0,
                  child: Center(
                    child: SizedBox(
                      width: 324,
                      height: 180,
                      child: _AdventurePaper(
                        child: _CustomAdventureContent(
                          ideaController: ideaController,
                          onPressed: customAdventure,
                        ),
                      ),
                    ),
                  ),
                ),

                // ======================================================
                // 第二張紙
                //
                // 現在揪出發
                // ======================================================
                Positioned(
                  top: 190,
                  left: 0,
                  right: 0,
                  child: Center(
                    child: SizedBox(
                      width: 324,
                      height: 210,
                      child: _AdventurePaper(
                        child: _StartAdventureContent(
                          locationController: locationController,
                          onLocationChanged: (value) {
                            fakeLocation = value;
                          },
                          onLocationPressed: useCurrentLocation,
                          onPressed: startAdventure,
                          loading: isLoadingLocation,
                        ),
                      ),
                    ),
                  ),
                ),

                // ======================================================
                // 第三張紙
                //
                // 來點遊意思
                // ======================================================
                Positioned(
                  top: 410,
                  left: 0,
                  right: 0,
                  child: Center(
                    child: SizedBox(
                      width: 324,
                      height: 180,
                      child: _AdventurePaper(
                        child: _RandomAdventureContent(
                          onPressed: randomAdventure,
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),

      // ================================================================
      // Navigation Bar
      // ================================================================
      bottomNavigationBar: AppNavigationBar(currentIndex: currentIndex),
    );
  }
}

// ======================================================================
// 紙張外框
// ======================================================================

class _AdventurePaper extends StatelessWidget {
  final Widget child;

  const _AdventurePaper({required this.child});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(7),
        boxShadow: const [
          BoxShadow(
            color: Color(0x45000000),
            blurRadius: 6,
            offset: Offset(2, 3),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(7),
        child: Stack(
          children: [
            // ==========================================================
            // 紙張
            // ==========================================================

            Positioned.fill(
              child: Image.asset('img/set_papper.png', fit: BoxFit.fill),
            ),

            // ==========================================================
            // 內容
            // ==========================================================
            Positioned.fill(child: child),
          ],
        ),
      ),
    );
  }
}

// ======================================================================
// 現在揪出發
// ======================================================================

class _StartAdventureContent extends StatelessWidget {
  final TextEditingController locationController;

  final ValueChanged<String> onLocationChanged;

  final VoidCallback onLocationPressed;

  final VoidCallback onPressed;

  final bool loading;

  const _StartAdventureContent({
    required this.locationController,
    required this.onLocationChanged,
    required this.onLocationPressed,
    required this.onPressed,
    required this.loading,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(26, 14, 26, 14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // ============================================================
          // 標題
          // ============================================================

          Row(
            mainAxisAlignment: MainAxisAlignment.start,
            children: [
              Image.asset(
                'img/quill_pen.png',
                width: 30,
                height: 30,
                fit: BoxFit.contain,
              ),

              const SizedBox(width: 7),

              Text(
                '現在揪出發',
                textAlign: TextAlign.left,
                style: AppTextStyles.title.copyWith(
                  color: AppColors.textPrimary,
                ),
              ),
            ],
          ),

          const SizedBox(height: 8),

          // ============================================================
          // 地區標題
          // ============================================================
          Text(
            '輸入指定的地區，現在揪出發',
            textAlign: TextAlign.left,
            style: AppTextStyles.bodySmallBold.copyWith(
              color: AppColors.mutedText,
            ),
          ),

          const SizedBox(height: 15),

          // ============================================================
          // 地區輸入框
          // ============================================================
          SizedBox(
            height: 22,
            child: TextField(
              controller: locationController,
              onChanged: onLocationChanged,
              textInputAction: TextInputAction.done,
              maxLines: 1,
              cursorColor: AppColors.primaryAccent,
              style: AppTextStyles.bodyEmphasisBold.copyWith(
                color: AppColors.textPrimary,
              ),
              decoration: InputDecoration(
                isDense: true,
                contentPadding: EdgeInsets.zero,
                border: InputBorder.none,
                enabledBorder: InputBorder.none,
                focusedBorder: InputBorder.none,
                hintText: '例如：臺中市 西屯區',
                hintStyle: AppTextStyles.bodyCompact.copyWith(
                  color: AppColors.mutedText,
                ),
              ),
            ),
          ),

          // ============================================================
          // 底線
          // ============================================================
          Container(
            height: 1,
            width: double.infinity,
            color: const Color(0xFF514A44),
          ),

          const SizedBox(height: 5),

          // ============================================================
          // 使用當前定位
          // ============================================================
          Align(
            alignment: Alignment.centerLeft,
            child: _LocationButton(onTap: onLocationPressed, loading: loading),
          ),

          const Spacer(),

          // ============================================================
          // 開始
          // ============================================================
          Align(
            alignment: Alignment.centerRight,
            child: _RedStartButton(text: '開始', onPressed: onPressed),
          ),
        ],
      ),
    );
  }
}

// ======================================================================
// 使用當前定位
// ======================================================================

class _LocationButton extends StatefulWidget {
  final VoidCallback onTap;
  final bool loading;

  const _LocationButton({required this.onTap, required this.loading});

  @override
  State<_LocationButton> createState() => _LocationButtonState();
}

class _LocationButtonState extends State<_LocationButton> {
  bool hovering = false;
  bool pressing = false;

  @override
  Widget build(BuildContext context) {
    double scale = 1.0;

    if (hovering) {
      scale = 1.08;
    }

    if (pressing) {
      scale = 0.96;
    }

    return MouseRegion(
      onEnter: (_) {
        if (widget.loading) return;

        setState(() {
          hovering = true;
        });
      },
      onExit: (_) {
        setState(() {
          hovering = false;
        });
      },
      child: GestureDetector(
        onTap: widget.loading ? null : widget.onTap,

        onTapDown: widget.loading
            ? null
            : (_) {
                setState(() {
                  pressing = true;
                });
              },

        onTapUp: widget.loading
            ? null
            : (_) {
                setState(() {
                  pressing = false;
                });
              },

        onTapCancel: widget.loading
            ? null
            : () {
                setState(() {
                  pressing = false;
                });
              },

        child: AnimatedScale(
          scale: scale,
          duration: const Duration(milliseconds: 180),
          curve: Curves.easeOutBack,
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                widget.loading ? '正在定位...' : '使用當前定位',
                textAlign: TextAlign.left,
                style: AppTextStyles.bodyEmphasisBold.copyWith(
                  color: AppColors.primaryAccent,
                ),
              ),

              const SizedBox(width: 6),

              if (widget.loading)
                const SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(
                    strokeWidth: 2.5,
                    color: AppColors.primaryAccent,
                  ),
                )
              else
                Image.asset(
                  'img/gps.png',
                  width: 35,
                  height: 25,
                  fit: BoxFit.contain,
                ),
            ],
          ),
        ),
      ),
    );
  }
}

// ======================================================================
// 來點遊意思
// ======================================================================

class _RandomAdventureContent extends StatelessWidget {
  final VoidCallback onPressed;

  const _RandomAdventureContent({required this.onPressed});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(26, 28, 26, 22),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // ============================================================
          // 標題
          // ============================================================

          Row(
            mainAxisAlignment: MainAxisAlignment.start,
            children: [
              Image.asset(
                'img/user_icon.png',
                width: 28,
                height: 28,
                fit: BoxFit.contain,
              ),

              const SizedBox(width: 7),

              Text(
                '來點遊意思',
                textAlign: TextAlign.left,
                style: AppTextStyles.title.copyWith(
                  color: AppColors.textPrimary,
                ),
              ),
            ],
          ),

          const SizedBox(height: 13),

          // ============================================================
          // 說明
          // ============================================================
          Text(
            '轉動命運的轉盤，來點遊意思',
            textAlign: TextAlign.left,
            style: AppTextStyles.bodySmallBold.copyWith(
              color: AppColors.mutedText,
            ),
          ),

          const Spacer(),

          // ============================================================
          // 開始
          // ============================================================
          Align(
            alignment: Alignment.centerRight,
            child: _RedStartButton(text: '開始', onPressed: onPressed),
          ),
        ],
      ),
    );
  }
}

// ======================================================================
// 遊你說了算
// ======================================================================

class _CustomAdventureContent extends StatelessWidget {
  final TextEditingController ideaController;

  final VoidCallback onPressed;

  const _CustomAdventureContent({
    required this.ideaController,
    required this.onPressed,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(26, 18, 26, 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // ============================================================
          // 標題
          // ============================================================

          Row(
            mainAxisAlignment: MainAxisAlignment.start,
            children: [
              Image.asset(
                'img/talk_play.png',
                width: 30,
                height: 30,
                fit: BoxFit.contain,
              ),

              const SizedBox(width: 7),

              Text(
                '遊你說了算',
                textAlign: TextAlign.left,
                style: AppTextStyles.title.copyWith(
                  color: AppColors.textPrimary,
                ),
              ),
            ],
          ),

          const SizedBox(height: 7),

          // ============================================================
          // 副標題
          // ============================================================
          Text(
            '你說出口的旅行，遊你說了算',
            textAlign: TextAlign.left,
            style: AppTextStyles.bodySmallBold.copyWith(
              color: AppColors.mutedText,
            ),
          ),

          const SizedBox(height: 10),

          // ============================================================
          // 輸入框
          // ============================================================
          SizedBox(
            height: 24,
            child: TextField(
              controller: ideaController,
              textInputAction: TextInputAction.done,
              maxLines: 1,
              cursorColor: AppColors.primaryAccent,
              style: AppTextStyles.bodyEmphasisBold.copyWith(
                color: AppColors.textPrimary,
              ),
              decoration: InputDecoration(
                isDense: true,
                contentPadding: EdgeInsets.zero,
                border: InputBorder.none,
                enabledBorder: InputBorder.none,
                focusedBorder: InputBorder.none,
                hintText: '例如：想來一趟美食之旅',
                hintStyle: AppTextStyles.bodyCompact.copyWith(
                  color: AppColors.mutedText,
                ),
              ),
            ),
          ),

          Container(
            height: 1,
            width: double.infinity,
            color: const Color(0xFF514A44),
          ),

          const Spacer(),

          // ============================================================
          // 開始
          // ============================================================
          Align(
            alignment: Alignment.centerRight,
            child: _RedStartButton(text: '開始', onPressed: onPressed),
          ),
        ],
      ),
    );
  }
}
// ======================================================================
// 紅色按鈕
// ======================================================================

class _RedStartButton extends StatefulWidget {
  final String text;

  final VoidCallback onPressed;

  final double? width;

  const _RedStartButton({
    required this.text,
    required this.onPressed,
    this.width,
  });

  @override
  State<_RedStartButton> createState() => _RedStartButtonState();
}

class _RedStartButtonState extends State<_RedStartButton> {
  bool hovering = false;

  bool pressing = false;

  @override
  Widget build(BuildContext context) {
    double scale = 1.0;

    if (hovering) {
      scale = 1.07;
    }

    if (pressing) {
      scale = 0.96;
    }

    return MouseRegion(
      onEnter: (_) {
        setState(() {
          hovering = true;
        });
      },
      onExit: (_) {
        setState(() {
          hovering = false;
        });
      },
      child: GestureDetector(
        onTap: widget.onPressed,
        onTapDown: (_) {
          setState(() {
            pressing = true;
          });
        },
        onTapUp: (_) {
          setState(() {
            pressing = false;
          });
        },
        onTapCancel: () {
          setState(() {
            pressing = false;
          });
        },
        child: AnimatedScale(
          scale: scale,
          duration: const Duration(milliseconds: 180),
          curve: Curves.easeOutBack,
          child: Container(
            width: widget.width ?? 70,
            height: 43,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(25),
              gradient: const LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [AppColors.primaryLight, AppColors.primary],
              ),
              border: Border.all(color: AppColors.primaryDark, width: 2),
              boxShadow: const [
                BoxShadow(
                  color: Color(0x70000000),
                  blurRadius: 4,
                  offset: Offset(0, 2),
                ),
              ],
            ),
            child: Text(
              widget.text,
              textAlign: TextAlign.center,
              style: AppTextStyles.button.copyWith(color: Colors.white),
            ),
          ),
        ),
      ),
    );
  }
}
