import 'dart:math' as math;
import 'dart:typed_data';

import 'package:flutter/foundation.dart';
import 'package:gal/gal.dart';
import 'package:http/http.dart' as http;
import 'package:image/image.dart' as img;

class PostcardGifDownload {
  const PostcardGifDownload._();

  static Future<String?> downloadPostcard({
    required String imageUrl,
    required bool isSpecial,
  }) async {
    try {
      debugPrint('開始下載：$imageUrl');

      final http.Response response = await http.get(Uri.parse(imageUrl));

      debugPrint('下載結果：HTTP ${response.statusCode}');
      debugPrint('圖片大小：${response.bodyBytes.length} bytes');

      if (response.statusCode < 200 || response.statusCode >= 300) {
        throw Exception('HTTP ${response.statusCode}');
      }

      if (response.bodyBytes.isEmpty) {
        throw Exception('圖片內容為空');
      }

      final Uint8List originalBytes = response.bodyBytes;

      final Uint8List gifBytes = await compute(
        _buildGif,
        _GifParams(imageBytes: originalBytes, isSpecial: isSpecial),
      );

      debugPrint('GIF 大小：${gifBytes.length} bytes');

      if (gifBytes.isEmpty) {
        throw Exception('GIF 產生失敗');
      }

      // ----------------------------------------------------------
      // 相簿權限
      // ----------------------------------------------------------

      bool hasAccess = await Gal.hasAccess();

      if (!hasAccess) {
        hasAccess = await Gal.requestAccess();
      }

      if (!hasAccess) {
        return '沒有相簿權限，無法儲存圖片';
      }

      // ----------------------------------------------------------
      // 儲存 GIF
      //
      // 注意：
      // name 不要自己加 .gif。
      // Gal 會根據圖片格式處理副檔名。
      // ----------------------------------------------------------

      final String fileName =
          'postcard_${DateTime.now().millisecondsSinceEpoch}';

      await Gal.putImageBytes(gifBytes, album: '回憶明信片', name: fileName);

      debugPrint('GIF 已成功儲存到手機相簿');

      return null;
    } on GalException catch (e) {
      debugPrint('相簿錯誤：${e.type.message}');
      return '儲存到相簿失敗：${e.type.message}';
    } catch (e, stackTrace) {
      debugPrint('GIF 下載失敗：$e');
      debugPrint('$stackTrace');

      return 'GIF 產生失敗：$e';
    }
  }
}

// ============================================================
// GIF Parameters
// ============================================================

class _GifParams {
  final Uint8List imageBytes;
  final bool isSpecial;

  const _GifParams({required this.imageBytes, required this.isSpecial});
}

// ============================================================
// Build GIF
// ============================================================

Uint8List _buildGif(_GifParams params) {
  final img.Image? source = img.decodeImage(params.imageBytes);

  if (source == null) {
    throw Exception('無法解析 JPG');
  }

  // ------------------------------------------------------------
  // Resize
  // ------------------------------------------------------------

  const int maxWidth = 600;

  img.Image baseImage = source;

  if (baseImage.width > maxWidth) {
    final int targetHeight = (baseImage.height * maxWidth / baseImage.width)
        .round();

    baseImage = img.copyResize(
      baseImage,
      width: maxWidth,
      height: targetHeight,
      interpolation: img.Interpolation.linear,
    );
  }

  // ------------------------------------------------------------
  // Animation settings
  //
  // 10 FPS
  // 2 seconds
  // 20 frames
  // ------------------------------------------------------------

  const int fps = 10;
  const int durationMs = 2000;

  final int frameCount = fps * durationMs ~/ 1000;

  // GIF duration 使用 1/100 秒。
  //
  // 10 FPS
  // = 100ms/frame
  // = 10/100 秒
  const int frameDuration = 10;

  // ------------------------------------------------------------
  // GIF encoder
  // ------------------------------------------------------------

  final img.GifEncoder encoder = img.GifEncoder(samplingFactor: 10);

  // ------------------------------------------------------------
  // Frames
  // ------------------------------------------------------------

  for (int i = 0; i < frameCount; i++) {
    final double progress = i / frameCount;

    final img.Image frame = baseImage.clone();

    if (params.isSpecial) {
      _drawNightEffect(frame, progress);
    } else {
      _drawNormalEffect(frame, progress);
    }

    encoder.addFrame(frame, duration: frameDuration);
  }

  // ------------------------------------------------------------
  // Finish GIF
  // ------------------------------------------------------------

  final Uint8List? encoded = encoder.finish();

  if (encoded == null || encoded.isEmpty) {
    throw Exception('GIF encoding 失敗');
  }

  return encoded;
}

// ============================================================
// Normal animation
//
// 非特殊明信片也要有動畫。
// 做非常輕微的亮度呼吸，不會破壞原圖。
// ============================================================

void _drawNormalEffect(img.Image image, double progress) {
  final double wave = (math.sin(progress * math.pi * 2) + 1) / 2;

  // 非常輕微的白色呼吸效果
  final double opacity = 0.025 + wave * 0.035;

  _drawTint(image, _Color(255, 255, 255, (opacity * 255).round()));

  _drawAnimatedBorder(image, progress);
}

// ============================================================
// Special / Night animation
// ============================================================

void _drawNightEffect(img.Image image, double progress) {
  final int width = image.width;
  final int height = image.height;

  // ------------------------------------------------------------
  // 紫色半透明氣氛
  // ------------------------------------------------------------

  _drawTint(image, const _Color(55, 40, 130, 45));

  // ------------------------------------------------------------
  // Stars
  // ------------------------------------------------------------

  const List<_StarData> stars = [
    _StarData(0.10, 0.18, 3.0, 0.00),
    _StarData(0.27, 0.34, 2.0, 0.22),
    _StarData(0.75, 0.17, 2.7, 0.42),
    _StarData(0.87, 0.40, 2.0, 0.64),
    _StarData(0.18, 0.78, 2.3, 0.34),
    _StarData(0.79, 0.78, 3.0, 0.58),
    _StarData(0.52, 0.12, 1.7, 0.82),
  ];

  for (final star in stars) {
    final double wave = (progress + star.phase) % 1.0;

    // 星星由暗 → 亮 → 暗
    final double triangle = 1.0 - ((wave - 0.5).abs() * 2.0);

    final double opacity = (0.15 + 0.85 * triangle).clamp(0.1, 1.0);

    final int x = (width * star.x).round();

    final int y = (height * star.y).round();

    _drawGlowCircle(image, x, y, star.radius, opacity);
  }

  // ------------------------------------------------------------
  // Meteor
  // ------------------------------------------------------------

  final double meteor = (progress * 1.7) % 1.0;

  if (meteor > 0.68) {
    final double t = (meteor - 0.68) / 0.32;

    final int endX = (width * (0.22 + t * 0.63)).round();

    final int endY = (height * (0.06 + t * 0.44)).round();

    final int startX = endX - (width * 0.15).round();

    final int startY = endY - (height * 0.11).round();

    final double alpha = (1.0 - t).clamp(0.0, 1.0);

    _drawLine(
      image,
      startX,
      startY,
      endX,
      endY,
      const _Color(255, 255, 255, 180),
      alpha,
      3,
    );

    _drawGlowCircle(image, endX, endY, 3.0, alpha);
  }

  // ------------------------------------------------------------
  // Animated border
  // ------------------------------------------------------------

  _drawAnimatedBorder(image, progress);
}

// ============================================================
// Glow circle
// ============================================================

void _drawGlowCircle(
  img.Image image,
  int cx,
  int cy,
  double radius,
  double opacity,
) {
  final int r = math.max(1, radius.round());

  final int glowRadius = r * 3;

  for (int y = -glowRadius; y <= glowRadius; y++) {
    for (int x = -glowRadius; x <= glowRadius; x++) {
      final double distance = math.sqrt(x * x + y * y);

      if (distance > glowRadius) {
        continue;
      }

      final double glow = (1 - distance / glowRadius).clamp(0.0, 1.0);

      final double alpha = glow * opacity;

      if (alpha <= 0) {
        continue;
      }

      final int px = cx + x;
      final int py = cy + y;

      if (px < 0 || py < 0 || px >= image.width || py >= image.height) {
        continue;
      }

      final img.Pixel pixel = image.getPixel(px, py);

      pixel.r = (pixel.r * (1 - alpha) + 255 * alpha).round();

      pixel.g = (pixel.g * (1 - alpha) + 255 * alpha).round();

      pixel.b = (pixel.b * (1 - alpha) + 255 * alpha).round();
    }
  }
}

// ============================================================
// Animated border
// ============================================================

void _drawAnimatedBorder(img.Image image, double progress) {
  final int width = image.width;
  final int height = image.height;

  if (width < 5 || height < 5) {
    return;
  }

  final int position = (progress * (width + height) * 2).round();

  // ------------------------------------------------------------
  // Top / Bottom
  // ------------------------------------------------------------

  for (int x = 0; x < width; x++) {
    final double phase = ((x + position) % width) / width;

    final double brightness =
        0.25 + 0.75 * ((math.sin(phase * math.pi * 2) + 1) / 2);

    _setPixel(image, x, 1, brightness);

    _setPixel(image, x, height - 2, brightness);
  }

  // ------------------------------------------------------------
  // Left / Right
  // ------------------------------------------------------------

  for (int y = 0; y < height; y++) {
    final double phase = ((y + position) % height) / height;

    final double brightness =
        0.25 + 0.75 * ((math.sin(phase * math.pi * 2) + 1) / 2);

    _setPixel(image, 1, y, brightness);

    _setPixel(image, width - 2, y, brightness);
  }

  // ------------------------------------------------------------
  // Purple highlights
  // ------------------------------------------------------------

  _setPixel(image, 1, 1, 0.8, purple: true);

  _setPixel(image, width - 2, 1, 0.8, purple: true);

  _setPixel(image, 1, height - 2, 0.8, purple: true);

  _setPixel(image, width - 2, height - 2, 0.8, purple: true);
}

// ============================================================
// Tint
// ============================================================

void _drawTint(img.Image image, _Color color) {
  final double alpha = color.a / 255.0;

  for (int y = 0; y < image.height; y++) {
    for (int x = 0; x < image.width; x++) {
      final img.Pixel pixel = image.getPixel(x, y);

      pixel.r = (pixel.r * (1 - alpha) + color.r * alpha).round();

      pixel.g = (pixel.g * (1 - alpha) + color.g * alpha).round();

      pixel.b = (pixel.b * (1 - alpha) + color.b * alpha).round();
    }
  }
}

// ============================================================
// Line
// ============================================================

void _drawLine(
  img.Image image,
  int x1,
  int y1,
  int x2,
  int y2,
  _Color color,
  double alpha,
  int thickness,
) {
  final int dx = (x2 - x1).abs();

  final int dy = (y2 - y1).abs();

  final int steps = math.max(dx, dy);

  if (steps == 0) {
    return;
  }

  for (int i = 0; i <= steps; i++) {
    final double t = i / steps;

    final int x = (x1 + (x2 - x1) * t).round();

    final int y = (y1 + (y2 - y1) * t).round();

    for (int ox = -thickness; ox <= thickness; ox++) {
      for (int oy = -thickness; oy <= thickness; oy++) {
        _blendPixel(image, x + ox, y + oy, color, alpha);
      }
    }
  }
}

// ============================================================
// Blend Pixel
// ============================================================

void _blendPixel(img.Image image, int x, int y, _Color color, double alpha) {
  if (x < 0 || y < 0 || x >= image.width || y >= image.height) {
    return;
  }

  final img.Pixel pixel = image.getPixel(x, y);

  pixel.r = (pixel.r * (1 - alpha) + color.r * alpha).round();

  pixel.g = (pixel.g * (1 - alpha) + color.g * alpha).round();

  pixel.b = (pixel.b * (1 - alpha) + color.b * alpha).round();
}

// ============================================================
// Set Pixel
// ============================================================

void _setPixel(
  img.Image image,
  int x,
  int y,
  double brightness, {
  bool purple = false,
}) {
  if (x < 0 || y < 0 || x >= image.width || y >= image.height) {
    return;
  }

  final img.Pixel pixel = image.getPixel(x, y);

  if (purple) {
    pixel.r = (pixel.r * 0.4 + 125 * brightness * 0.6).round();

    pixel.g = (pixel.g * 0.4 + 108 * brightness * 0.6).round();

    pixel.b = (pixel.b * 0.4 + 255 * brightness * 0.6).round();
  } else {
    pixel.r = 255;
    pixel.g = 255;
    pixel.b = 255;
  }
}

// ============================================================
// Star data
// ============================================================

class _StarData {
  final double x;
  final double y;
  final double radius;
  final double phase;

  const _StarData(this.x, this.y, this.radius, this.phase);
}

// ============================================================
// Color
// ============================================================

class _Color {
  final int r;
  final int g;
  final int b;
  final int a;

  const _Color(this.r, this.g, this.b, this.a);
}
