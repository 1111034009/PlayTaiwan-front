import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';

import '../block/navigationbar.dart';
import '../core/app_colors.dart';

const Color _pageColor = AppColors.background;
const Color _darkBrown = Color(0xFF473737);
const Color _backColor = Color(0xFF7E1616);
const Color _titleColor = Color(0xFF841D0B);
const Color _addressColor = Color(0xFF871E0C);
const Color _tagText = Color(0xFF483425);
const Color _tagBorder = Color(0xFF8D7B6E);
const Color _selectedTagColor = Color(0xFF6B4537);
const Color _selectedTagText = Colors.white;
const Color _bottomPanelColor = Color(0xFFE2D8BD);

class NearbyPage extends StatefulWidget {
  const NearbyPage({super.key});

  @override
  State<NearbyPage> createState() => _NearbyPageState();
}

class _NearbyPageState extends State<NearbyPage> {
  static const double designWidth = 360;
  static const double designHeight = 640;
  static const double panelTop = 35;
  static const double categoryBarHeight = 50;
  static const double ticketHorizontalPadding = 15;
  static const double ticketSpacing = 12;
  static const double listBottomPadding = 90;

  int selectedCategory = 0;

  final categories = const ['飲食', '景點', '休閒'];

  static const places = [
    _NearbyPlace(
      title: '福記肉圓（府前路215）',
      time: '06:30–18:00',
      images: [
        'img/home_trip.png',
        'img/home_gogo.png',
        'img/background_papper.png',
      ],
      tags: ['飲食', '小吃'],
      address: '前往地址',
    ),
    _NearbyPlace(
      title: '府城老街散步',
      time: '09:00–18:00',
      images: ['img/home_gogo.png'],
      tags: ['景點', '散步'],
      address: '前往地址',
    ),
    _NearbyPlace(
      title: '孔廟文化園區',
      time: '08:00–21:00',
      images: ['img/home_trip.png'],
      tags: ['景點', '文化'],
      address: '前往地址',
    ),
    _NearbyPlace(
      title: '府城夜間漫遊',
      time: '18:00–22:00',
      images: ['img/home_gogo.png'],
      tags: ['休閒', '夜遊'],
      address: '前往地址',
    ),
  ];

  @override
  void initState() {
    super.initState();

    SystemChrome.setSystemUIOverlayStyle(
      const SystemUiOverlayStyle(
        statusBarColor: Colors.transparent,
        statusBarIconBrightness: Brightness.dark,
        statusBarBrightness: Brightness.light,
        systemNavigationBarColor: _pageColor,
        systemNavigationBarIconBrightness: Brightness.dark,
      ),
    );
  }

  TextStyle kaisei({
    double size = 16,
    FontWeight weight = FontWeight.w400,
    Color color = _darkBrown,
  }) {
    return GoogleFonts.kaiseiHarunoUmi(
      fontSize: size,
      fontWeight: weight,
      color: color,
    );
  }

  List<_NearbyPlace> get filteredPlaces {
    if (selectedCategory == 0) return places;

    final category = categories[selectedCategory];
    return places.where((e) => e.tags.contains(category)).toList();
  }

  void openAddress(_NearbyPlace place) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: Text(
            '前往：${place.title}',
            textAlign: TextAlign.center,
            style: kaisei(
              size: 14,
              weight: FontWeight.w700,
              color: Colors.white,
            ),
          ),
          backgroundColor: _titleColor,
          behavior: SnackBarBehavior.floating,
          duration: const Duration(seconds: 2),
        ),
      );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _pageColor,
      extendBody: true,
      body: Stack(
        children: [
          const Positioned.fill(child: ColoredBox(color: _pageColor)),
          Positioned(
            left: 0,
            right: 0,
            top: panelTop,
            bottom: 0,
            child: const DecoratedBox(
              decoration: BoxDecoration(
                color: _bottomPanelColor,
                borderRadius: BorderRadius.only(
                  topLeft: Radius.circular(28),
                  topRight: Radius.circular(28),
                ),
              ),
            ),
          ),
          Center(
            child: FittedBox(
              fit: BoxFit.contain,
              alignment: Alignment.center,
              child: SizedBox(
                width: designWidth,
                height: designHeight,
                child: Stack(
                  children: [
                    Positioned(
                      left: 0,
                      right: 0,
                      top: panelTop + categoryBarHeight,
                      bottom: 0,
                      child: ScrollConfiguration(
                        behavior: const _NoScrollbarBehavior(),
                        child: ListView.builder(
                          physics: const BouncingScrollPhysics(),
                          padding: const EdgeInsets.only(
                            left: ticketHorizontalPadding,
                            right: ticketHorizontalPadding,
                            top: 0,
                            bottom: listBottomPadding,
                          ),
                          itemCount: filteredPlaces.length,
                          itemBuilder: (context, index) {
                            final place = filteredPlaces[index];

                            return Padding(
                              padding: EdgeInsets.only(
                                bottom: index == filteredPlaces.length - 1
                                    ? 0
                                    : ticketSpacing,
                              ),
                              child: _NearbyTicket(
                                place: place,
                                kaisei: kaisei,
                                onAddressTap: () => openAddress(place),
                              ),
                            );
                          },
                        ),
                      ),
                    ),
                    Positioned(
                      left: 0,
                      right: 0,
                      top: panelTop,
                      height: categoryBarHeight,
                      child: _TopCategoryBar(
                        categories: categories,
                        selectedIndex: selectedCategory,
                        onCategoryChanged: (index) {
                          setState(() => selectedCategory = index);
                        },
                        onBack: () => Navigator.pop(context),
                        kaisei: kaisei,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
      bottomNavigationBar: const AppNavigationBar(currentIndex: 1),
    );
  }
}

class _TopCategoryBar extends StatelessWidget {
  final List<String> categories;
  final int selectedIndex;
  final ValueChanged<int> onCategoryChanged;
  final VoidCallback onBack;
  final TextStyle Function({double size, FontWeight weight, Color color})
  kaisei;

  const _TopCategoryBar({
    required this.categories,
    required this.selectedIndex,
    required this.onCategoryChanged,
    required this.onBack,
    required this.kaisei,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 7, left: 18, right: 24),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _BackTextButton(onTap: onBack, kaisei: kaisei),
          const SizedBox(width: 14),
          Expanded(
            child: Row(
              children: List.generate(
                categories.length,
                (index) => Expanded(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 5),
                    child: _CategoryButton(
                      text: categories[index],
                      selected: selectedIndex == index,
                      onTap: () => onCategoryChanged(index),
                      kaisei: kaisei,
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _BackTextButton extends StatefulWidget {
  final VoidCallback onTap;
  final TextStyle Function({double size, FontWeight weight, Color color})
  kaisei;

  const _BackTextButton({required this.onTap, required this.kaisei});

  @override
  State<_BackTextButton> createState() => _BackTextButtonState();
}

class _BackTextButtonState extends State<_BackTextButton> {
  bool pressing = false;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: widget.onTap,
      onTapDown: (_) => setState(() => pressing = true),
      onTapUp: (_) => setState(() => pressing = false),
      onTapCancel: () => setState(() => pressing = false),
      child: AnimatedScale(
        scale: pressing ? .95 : 1,
        duration: const Duration(milliseconds: 160),
        curve: Curves.easeOutBack,
        child: Padding(
          padding: const EdgeInsets.only(top: 7),
          child: Text(
            '<< 返回',
            style: widget.kaisei(
              size: 12,
              weight: FontWeight.w900,
              color: _backColor,
            ),
          ),
        ),
      ),
    );
  }
}

class _CategoryButton extends StatefulWidget {
  final String text;
  final bool selected;
  final VoidCallback onTap;
  final TextStyle Function({double size, FontWeight weight, Color color})
  kaisei;

  const _CategoryButton({
    required this.text,
    required this.selected,
    required this.onTap,
    required this.kaisei,
  });

  @override
  State<_CategoryButton> createState() => _CategoryButtonState();
}

class _CategoryButtonState extends State<_CategoryButton> {
  bool pressing = false;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: widget.onTap,
      onTapDown: (_) => setState(() => pressing = true),
      onTapUp: (_) => setState(() => pressing = false),
      onTapCancel: () => setState(() => pressing = false),
      child: AnimatedScale(
        scale: pressing ? .96 : 1,
        duration: const Duration(milliseconds: 150),
        curve: Curves.easeOutBack,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 160),
          height: 31,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: widget.selected ? _selectedTagColor : Colors.transparent,
            borderRadius: BorderRadius.circular(5),
            border: Border.all(
              color: widget.selected ? _selectedTagColor : _tagText,
              width: 1.5,
            ),
          ),
          child: Text(
            widget.text,
            style: widget.kaisei(
              size: 13,
              weight: FontWeight.w700,
              color: widget.selected ? _selectedTagText : _tagText,
            ),
          ),
        ),
      ),
    );
  }
}

class _NearbyTicket extends StatelessWidget {
  final _NearbyPlace place;
  final TextStyle Function({double size, FontWeight weight, Color color})
  kaisei;
  final VoidCallback onAddressTap;

  const _NearbyTicket({
    required this.place,
    required this.kaisei,
    required this.onAddressTap,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 330,
      height: 166,
      child: Stack(
        children: [
          Positioned.fill(
            child: Image.asset(
              'img/ticket.png',
              fit: BoxFit.fill,
              filterQuality: FilterQuality.high,
            ),
          ),
          Positioned(
            top: 12,
            left: 14,
            right: 58,
            child: Text(
              place.title,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: kaisei(
                size: 18,
                weight: FontWeight.w700,
                color: _titleColor,
              ),
            ),
          ),
          Positioned(
            top: 38,
            left: 14,
            right: 58,
            child: Text(
              place.time,
              style: kaisei(
                size: 11,
                weight: FontWeight.w700,
                color: Colors.black,
              ),
            ),
          ),
          Positioned(
            left: 14,
            top: 58,
            width: 205,
            height: 69,
            child: _PhotoRow(images: place.images),
          ),
          Positioned(
            left: 14,
            bottom: 13,
            child: Row(
              children: place.tags
                  .map(
                    (tag) => Padding(
                      padding: const EdgeInsets.only(right: 7),
                      child: _Tag(text: tag, kaisei: kaisei),
                    ),
                  )
                  .toList(),
            ),
          ),
          Positioned(
            right: 66,
            bottom: 14,
            child: _AddressButton(
              text: place.address,
              kaisei: kaisei,
              onTap: onAddressTap,
            ),
          ),
        ],
      ),
    );
  }
}

class _PhotoRow extends StatelessWidget {
  final List<String> images;

  const _PhotoRow({required this.images});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: List.generate(
        images.length,
        (index) => Expanded(
          child: Padding(
            padding: EdgeInsets.only(right: index == images.length - 1 ? 0 : 5),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(2),
              child: Image.asset(
                images[index],
                fit: BoxFit.cover,
                filterQuality: FilterQuality.high,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _Tag extends StatelessWidget {
  final String text;
  final TextStyle Function({double size, FontWeight weight, Color color})
  kaisei;

  const _Tag({required this.text, required this.kaisei});

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 22,
      constraints: const BoxConstraints(minWidth: 76),
      padding: const EdgeInsets.symmetric(horizontal: 9),
      alignment: Alignment.center,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: _tagBorder),
      ),
      child: Text(
        text,
        style: kaisei(size: 10, weight: FontWeight.w700, color: _tagText),
      ),
    );
  }
}

class _AddressButton extends StatefulWidget {
  final String text;
  final VoidCallback onTap;
  final TextStyle Function({double size, FontWeight weight, Color color})
  kaisei;

  const _AddressButton({
    required this.text,
    required this.onTap,
    required this.kaisei,
  });

  @override
  State<_AddressButton> createState() => _AddressButtonState();
}

class _AddressButtonState extends State<_AddressButton> {
  bool pressing = false;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: widget.onTap,
      onTapDown: (_) => setState(() => pressing = true),
      onTapUp: (_) => setState(() => pressing = false),
      onTapCancel: () => setState(() => pressing = false),
      child: AnimatedScale(
        scale: pressing ? .95 : 1,
        duration: const Duration(milliseconds: 160),
        curve: Curves.easeOutBack,
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              widget.text,
              style: widget.kaisei(
                size: 11,
                weight: FontWeight.w700,
                color: _addressColor,
              ),
            ),
            const SizedBox(width: 2),
            Image.asset(
              'img/see_more.png',
              width: 15,
              height: 15,
              fit: BoxFit.contain,
            ),
          ],
        ),
      ),
    );
  }
}

class _NoScrollbarBehavior extends ScrollBehavior {
  const _NoScrollbarBehavior();

  @override
  Widget buildScrollbar(
    BuildContext context,
    Widget child,
    ScrollableDetails details,
  ) => child;

  @override
  Widget buildOverscrollIndicator(
    BuildContext context,
    Widget child,
    ScrollableDetails details,
  ) => child;
}

class _NearbyPlace {
  final String title;
  final String time;
  final List<String> images;
  final List<String> tags;
  final String address;

  const _NearbyPlace({
    required this.title,
    required this.time,
    required this.images,
    required this.tags,
    required this.address,
  });
}
