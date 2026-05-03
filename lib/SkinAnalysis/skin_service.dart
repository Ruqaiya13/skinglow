import 'dart:convert';
import 'dart:io';
import 'package:flutter/services.dart';
import 'package:image/image.dart' as img;

class SkinService {
  Future<Map<String, dynamic>> loadSkinData() async {
    try {
      String jsonString = await rootBundle.loadString('assets/skin_images.json');
      return jsonDecode(jsonString);
    } catch (e) {
      throw Exception('Failed to load skin data: $e');
    }
  }

  static Future<String> analyzeSkin(String imagePath) async {
    try {
      final imageBytes = await File(imagePath).readAsBytes();
      final image = img.decodeImage(imageBytes);

      if (image == null) {
        throw Exception('Failed to decode image');
      }

      final features = _getImageFeatures(image);
      return _determineSkinType(features);
    } catch (e) {
      throw Exception('Skin analysis failed: ${e.toString()}');
    }
  }

  static Map<String, int> _getImageFeatures(img.Image image) {
    int r = 0, g = 0, b = 0;
    for (int x = 0; x < image.width; x++) {
      for (int y = 0; y < image.height; y++) {
        final pixel = image.getPixel(x, y);
        r += img.getRed(pixel);
        g += img.getGreen(pixel);
        b += img.getBlue(pixel);
      }
    }
    final total = image.width * image.height;
    return {
      'avgR': r ~/ total,
      'avgG': g ~/ total,
      'avgB': b ~/ total
    };
  }

  static String _determineSkinType(Map<String, int> features) {
    final avgR = features['avgR'] ?? 0;
    final avgG = features['avgG'] ?? 0;
    final avgB = features['avgB'] ?? 0;

    // تحديد البشرة الدهنية
    if (avgR > 180 && avgG > 100 && avgB < 100) {
      return 'Oily';
    }
    // تحديد البشرة الجافة
    if (avgR < 120 && avgG < 100 && avgB < 80) {
      return 'Dry';
    }
    // تحديد البشرة المختلطة
    if (avgR > 150 && avgG > 120 && avgB > 100) {
      return 'Combination';
    }
    // إذا لم تنطبق أي من الحالات السابقة، ستكون البشرة طبيعية
    return 'Normal';
  }
  static Future<bool> validateSkinImage(String imagePath) async {
    try {
      final imageBytes = await File(imagePath).readAsBytes();
      final image = img.decodeImage(imageBytes);

      if (image == null) return false;

      int skinPixels = 0;
      int totalPixels = image.width * image.height;

      for (int x = 0; x < image.width; x += 2) {
        for (int y = 0; y < image.height; y += 2) {
          final pixel = image.getPixel(x, y);
          final r = img.getRed(pixel);
          final g = img.getGreen(pixel);
          final b = img.getBlue(pixel);

          // استخدام نفس خوارزمية كشف البشرة
          final yVal = 0.299 * r + 0.587 * g + 0.114 * b;
          final cb = 128 - 0.168736 * r - 0.331264 * g + 0.5 * b;
          final cr = 128 + 0.5 * r - 0.418688 * g - 0.081312 * b;

          if (yVal > 80 && cb >= 85 && cb <= 135 && cr >= 135 && cr <= 180) {
            skinPixels++;
          }
        }
      }

      return (skinPixels / (totalPixels / 4)) > 0.15;
    } catch (e) {
      return false;
    }
  }
}
