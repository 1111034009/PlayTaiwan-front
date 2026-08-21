import 'package:flutter/material.dart';
import 'package:curved_navigation_bar/curved_navigation_bar.dart';
import '../core/app_colors.dart';
import '../core/app_text_styles.dart';

class AppNavigationBar extends StatefulWidget {
  final int currentIndex;

  const AppNavigationBar({super.key, required this.currentIndex});

  @override
  State<AppNavigationBar> createState() => _AppNavigationBarState();
}

class _AppNavigationBarState extends State<AppNavigationBar> {
  late int _selectedIndex;
  bool _isNavigating = false;

  @override
  void initState() {
    super.initState();
    _selectedIndex = widget.currentIndex;
  }

  @override
  void didUpdateWidget(covariant AppNavigationBar oldWidget) {
    super.didUpdateWidget(oldWidget);

    if (oldWidget.currentIndex != widget.currentIndex) {
      _selectedIndex = widget.currentIndex;
    }
  }

  Future<void> _handleNavigation(int index) async {
    if (_isNavigating) {
      return;
    }

    if (index == _selectedIndex) {
      return;
    }

    setState(() {
      _selectedIndex = index;
      _isNavigating = true;
    });

    await Future.delayed(const Duration(milliseconds: 180));

    if (!mounted) {
      return;
    }

    switch (index) {
      case 0:
        Navigator.pushReplacementNamed(context, '/home');
        break;

      case 1:
        Navigator.pushReplacementNamed(context, '/story-map');
        break;

      case 2:
        Navigator.pushReplacementNamed(context, '/collection');
        break;

      case 3:
        Navigator.pushReplacementNamed(context, '/past');
        break;
    }
  }

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 82,
      child: CurvedNavigationBar(
        index: _selectedIndex,

        backgroundColor: Colors.transparent,

        color: AppColors.navigationBackground,

        buttonBackgroundColor: AppColors.navigationButton,

        height: 62,

        animationDuration: const Duration(milliseconds: 260),

        animationCurve: Curves.easeOutCubic,

        letIndexChange: (index) {
          if (_isNavigating) {
            return false;
          }

          return index != _selectedIndex;
        },

        items: [
          _NavigationItem(
            icon: 'img/Guide_home.png',
            label: '首頁',
            selected: _selectedIndex == 0,
          ),

          _NavigationItem(
            icon: 'img/Guide_map.png',
            label: '地圖',
            selected: _selectedIndex == 1,
          ),

          _NavigationItem(
            icon: 'img/Guide_bag.png',
            label: '收藏',
            selected: _selectedIndex == 2,
          ),

          _NavigationItem(
            icon: 'img/Guide_past.png',
            label: '過往',
            selected: _selectedIndex == 3,
          ),
        ],

        onTap: _handleNavigation,
      ),
    );
  }
}

class _NavigationItem extends StatelessWidget {
  final String icon;
  final String label;
  final bool selected;

  const _NavigationItem({
    required this.icon,
    required this.label,
    required this.selected,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 58,
      height: 52,
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          AnimatedContainer(
            duration: const Duration(milliseconds: 180),
            curve: Curves.easeOutCubic,
            width: selected ? 23 : 25,
            height: selected ? 23 : 25,
            child: Image.asset(icon, fit: BoxFit.contain),
          ),
          const SizedBox(height: 2),
          AnimatedDefaultTextStyle(
            duration: const Duration(milliseconds: 180),
            curve: Curves.easeOutCubic,
            style: TextStyle(
              fontFamily: 'sans',
              fontSize: selected
                  ? AppTextStyles.microSize
                  : AppTextStyles.captionSize,
              fontWeight: selected ? FontWeight.w800 : FontWeight.w700,
              color: AppColors.textPrimary,
              height: 1.0,
            ),
            child: Text(label, textAlign: TextAlign.center),
          ),
        ],
      ),
    );
  }
}
