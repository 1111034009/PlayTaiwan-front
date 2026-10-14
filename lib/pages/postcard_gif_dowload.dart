import 'dart:io';
import 'dart:math' as math;
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:gal/gal.dart';
import 'package:http/http.dart' as http;
import 'package:image/image.dart' as img;
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';

class PostcardGifDownload {
  const PostcardGifDownload._();

  static final Map<String, Future<File>> _exports = {};

  static Future<File> prepare({
    required String imageUrl,
    required String name,
    required bool isSpecial,
  }) {
    final String key = '${imageUrl.hashCode}_${isSpecial ? 'g' : 'p'}_v2';

    return _exports.putIfAbsent(key, () async {
      try {
        return await _build(imageUrl, isSpecial, key);
      } catch (_) {
        _exports.remove(key);
        rethrow;
      }
    });
  }

  static Future<void> warmUp({
    required String imageUrl,
    required String name,
    required bool isSpecial,
  }) async {
    try {
      await prepare(imageUrl: imageUrl, name: name, isSpecial: isSpecial);
    } catch (_) {}
  }

  static Future<String?> download({
    required String imageUrl,
    required String name,
    required bool isSpecial,
  }) async {
    try {
      final File file = await prepare(
        imageUrl: imageUrl,
        name: name,
        isSpecial: isSpecial,
      );

      bool hasAccess = await Gal.hasAccess();

      if (!hasAccess) {
        hasAccess = await Gal.requestAccess();
      }

      if (!hasAccess) {
        return '沒有相簿權限，無法儲存圖片';
      }

      await Gal.putImage(file.path, album: '回憶明信片');

      return null;
    } on GalException catch (e) {
      return '儲存到相簿失敗：${e.type.message}';
    } catch (e) {
      debugPrint('明信片下載失敗：$e');
      return '明信片製作失敗，請稍後再試';
    }
  }

  static Future<String?> share({
    required String imageUrl,
    required String name,
    required bool isSpecial,
  }) async {
    try {
      final File file = await prepare(
        imageUrl: imageUrl,
        name: name,
        isSpecial: isSpecial,
      );

      await SharePlus.instance.share(
        ShareParams(
          files: [
            XFile(file.path, mimeType: isSpecial ? 'image/gif' : 'image/png'),
          ],
          text: name.isEmpty ? '回憶明信片' : name,
        ),
      );

      return null;
    } catch (e) {
      debugPrint('明信片分享失敗：$e');
      return '分享明信片失敗';
    }
  }

  static Future<String?> downloadPostcard({
    required String imageUrl,
    required bool isSpecial,
    String name = '',
  }) {
    return download(imageUrl: imageUrl, name: name, isSpecial: isSpecial);
  }

  static Future<Directory> _cacheDir() async {
    final Directory base = await getTemporaryDirectory();
    final Directory dir = Directory('${base.path}/postcard_export');

    if (!await dir.exists()) {
      await dir.create(recursive: true);
    }

    return dir;
  }

  static Future<File> _fetchSource(String url, Directory dir) async {
    final File file = File('${dir.path}/src_${url.hashCode}');

    if (await file.exists() && await file.length() > 0) {
      return file;
    }

    final http.Response response = await http.get(Uri.parse(url));

    if (response.statusCode < 200 ||
        response.statusCode >= 300 ||
        response.bodyBytes.isEmpty) {
      throw Exception('圖片下載失敗');
    }

    await file.writeAsBytes(response.bodyBytes, flush: true);

    return file;
  }

  static Future<File> _build(String url, bool special, String key) async {
    if (url.isEmpty) {
      throw Exception('沒有明信片圖片');
    }

    final Directory dir = await _cacheDir();

    final File out = File('${dir.path}/out_$key.${special ? 'gif' : 'png'}');

    if (await out.exists() && await out.length() > 0) {
      return out;
    }

    final File sourceFile = await _fetchSource(url, dir);
    final Uint8List sourceBytes = await sourceFile.readAsBytes();
    final ui.Codec codec = await ui.instantiateImageCodec(sourceBytes);
    final ui.Image source = (await codec.getNextFrame()).image;

    try {
      final Uint8List bytes = special
          ? await _buildGif(source)
          : await _buildPng(source);

      await out.writeAsBytes(bytes, flush: true);

      return out;
    } finally {
      source.dispose();
    }
  }

  static Future<Uint8List> _buildPng(ui.Image source) async {
    final ui.Image image = await _renderFrame(
      source: source,
      special: false,
      progress: 0,
      width: 2160,
    );

    final ByteData? data = await image.toByteData(
      format: ui.ImageByteFormat.png,
    );

    image.dispose();

    if (data == null) {
      throw Exception('明信片輸出失敗');
    }

    return data.buffer.asUint8List();
  }

  static Future<Uint8List> _buildGif(ui.Image source) async {
    const int count = 24;

    final List<Uint8List> frames = [];
    int w = 0;
    int h = 0;

    for (int i = 0; i < count; i++) {
      final ui.Image image = await _renderFrame(
        source: source,
        special: true,
        progress: i / count,
        width: 720,
      );

      w = image.width;
      h = image.height;

      final ByteData? data = await image.toByteData(
        format: ui.ImageByteFormat.rawRgba,
      );

      image.dispose();

      if (data == null) {
        throw Exception('明信片輸出失敗');
      }

      frames.add(Uint8List.fromList(data.buffer.asUint8List()));
    }

    final Uint8List encoded = await compute(_encodeGif, {
      'frames': frames,
      'w': w,
      'h': h,
    });

    if (encoded.isEmpty) {
      throw Exception('GIF 產生失敗');
    }

    return encoded;
  }

  static Future<ui.Image> _renderFrame({
    required ui.Image source,
    required bool special,
    required double progress,
    required double width,
  }) async {
    final double height = width * 133 / 180;
    final double border = width * 0.0125;

    final ui.PictureRecorder recorder = ui.PictureRecorder();
    final Canvas canvas = Canvas(recorder);

    final Rect card = Rect.fromLTWH(0, 0, width, height);
    final RRect cardR = RRect.fromRectAndRadius(
      card,
      Radius.circular(width * 0.0175),
    );

    canvas.drawRRect(cardR, Paint()..color = Colors.white);

    final Rect inner = card.deflate(border);
    final RRect innerR = RRect.fromRectAndRadius(
      inner,
      Radius.circular(width * 0.01),
    );

    canvas.save();
    canvas.clipRRect(innerR, doAntiAlias: true);

    final double srcW = source.width.toDouble();
    final double srcH = source.height.toDouble();
    final double scale = math.max(inner.width / srcW, inner.height / srcH);
    final double cropW = inner.width / scale;
    final double cropH = inner.height / scale;

    canvas.drawImageRect(
      source,
      Rect.fromLTWH((srcW - cropW) / 2, (srcH - cropH) / 2, cropW, cropH),
      inner,
      Paint()
        ..filterQuality = FilterQuality.high
        ..isAntiAlias = true,
    );

    if (special) {
      final double s = inner.width / 460;

      canvas.translate(inner.left, inner.top);
      canvas.scale(s);

      _NightPainter(
        progress: progress,
      ).paint(canvas, Size(inner.width / s, inner.height / s));
    }

    canvas.restore();

    return recorder.endRecording().toImage(width.round(), height.round());
  }
}

Uint8List _encodeGif(Map<String, dynamic> args) {
  final List<Uint8List> frames = args['frames'] as List<Uint8List>;
  final int w = args['w'] as int;
  final int h = args['h'] as int;

  final img.GifEncoder encoder = img.GifEncoder(
    repeat: 0,
    samplingFactor: 1,
    dither: img.DitherKernel.floydSteinberg,
  );

  for (final Uint8List bytes in frames) {
    final img.Image frame = img.Image.fromBytes(
      width: w,
      height: h,
      bytes: bytes.buffer,
      numChannels: 4,
    );

    encoder.addFrame(frame, duration: 8);
  }

  return encoder.finish() ?? Uint8List(0);
}

class _StarData {
  final double x;
  final double y;
  final double radius;
  final double phase;

  const _StarData(this.x, this.y, this.radius, this.phase);
}

class _NightPainter {
  final double progress;

  const _NightPainter({required this.progress});

  static const List<_StarData> stars = [
    _StarData(0.12, 0.20, 1.5, 0.00),
    _StarData(0.30, 0.38, 1.1, 0.24),
    _StarData(0.76, 0.18, 1.7, 0.46),
    _StarData(0.88, 0.48, 1.1, 0.68),
    _StarData(0.20, 0.78, 1.3, 0.35),
    _StarData(0.78, 0.80, 1.6, 0.58),
  ];

  void paint(Canvas canvas, Size size) {
    final Rect rect = Offset.zero & size;

    canvas.drawRect(
      rect,
      Paint()
        ..shader = const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            Color(0x30342B91),
            Color(0x08101845),
            Color(0x3A3C247D),
            Color(0x08101845),
          ],
        ).createShader(rect),
    );

    for (final _StarData star in stars) {
      final double wave = (progress + star.phase) % 1.0;

      final double floatX =
          math.sin(progress * math.pi * 2 + star.phase * math.pi * 2) * 1.8;

      final double floatY =
          math.cos(progress * math.pi * 2 + star.phase * math.pi * 2) * 1.5;

      final double glow = 0.5 + 0.5 * math.sin(wave * math.pi * 2);
      final double opacity = (0.18 + glow * 0.42).clamp(0.12, 0.6);

      canvas.drawCircle(
        Offset(size.width * star.x + floatX, size.height * star.y + floatY),
        star.radius,
        Paint()..color = Colors.white.withValues(alpha: opacity),
      );
    }

    final double moonX = -size.width * 0.35 + progress * size.width * 1.7;

    final Rect moonRect = Rect.fromCenter(
      center: Offset(moonX, size.height * 0.42),
      width: size.width * 0.36,
      height: size.height * 1.5,
    );

    canvas.save();
    canvas.rotate(-0.18);
    canvas.drawRect(
      moonRect,
      Paint()
        ..shader = const LinearGradient(
          begin: Alignment.centerLeft,
          end: Alignment.centerRight,
          colors: [
            Colors.transparent,
            Color(0x107D6CFF),
            Color(0x35FFFFFF),
            Color(0x107D6CFF),
            Colors.transparent,
          ],
          stops: [0.0, 0.30, 0.50, 0.70, 1.0],
        ).createShader(moonRect),
    );
    canvas.restore();

    final RRect border = RRect.fromRectAndRadius(
      rect.deflate(2),
      const Radius.circular(5),
    );

    canvas.drawRRect(
      border,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 4
        ..color = const Color(0x287D6CFF),
    );

    canvas.drawRRect(
      border,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.7
        ..shader = SweepGradient(
          transform: GradientRotation(progress * math.pi * 2),
          colors: const [
            Color(0x227D6CFF),
            Color(0x88FFFFFF),
            Color(0xFFFFFFFF),
            Color(0x88756BFF),
            Color(0x227D6CFF),
          ],
        ).createShader(rect),
    );
  }
}
