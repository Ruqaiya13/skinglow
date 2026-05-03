import 'dart:io';
import 'dart:math';
import 'package:flutter/services.dart';
import 'package:tflite_flutter/tflite_flutter.dart';
import 'package:image/image.dart' as img;

class SmartSkinClassifier {
  static const String _modelPath = 'assets/models/skin_trained_final.tflite';
  static const String _labelsPath = 'assets/models/labels_final.txt';

  late Interpreter _interpreter;
  List<String> _labels = ['dry', 'normal', 'oily'];
  final int _inputSize = 224;
  final double _confidenceThreshold = 0.6;

  // إحصائيات للتحسين الذكي
  Map<String, int> _predictionHistory = {'dry': 0, 'normal': 0, 'oily': 0};
  List<Map<String, dynamic>> _recentResults = [];

  Future<void> initialize() async {
    try {
      print('🚀 Initializing Smart Skin Classifier...');

      // تحميل التسميات
      try {
        final labelData = await rootBundle.loadString(_labelsPath);
        _labels = labelData.split('\n')
            .where((label) => label.trim().isNotEmpty)
            .map((label) => label.trim())
            .toList();

        if (_labels.length != 3) {
          _labels = ['dry', 'normal', 'oily'];
        }
        print('✅ Labels loaded: $_labels');
      } catch (e) {
        print('⚠️ Using default labels');
      }

      // تحميل النموذج مع إعدادات بسيطة
      final options = InterpreterOptions()..threads = 2;
      _interpreter = await Interpreter.fromAsset(_modelPath, options: options);

      // الحصول على معلومات النموذج
      final inputTensor = _interpreter.getInputTensor(0);
      final outputTensor = _interpreter.getOutputTensor(0);

      print('🎯 Model loaded successfully!');
      print('📥 Input: ${inputTensor.shape} (${inputTensor.type})');
      print('📤 Output: ${outputTensor.shape} (${outputTensor.type})');

      // اختبار سريع للتأكد من عمل النموذج
      await _runQuickTest();

    } catch (e) {
      print('❌ Initialization error: $e');
      print('💡 Tip: Make sure the .tflite file is in assets/models/');
      rethrow;
    }
  }

  Future<void> _runQuickTest() async {
    try {
      print('🧪 Running quick diagnostic test...');

      // إنشاء 3 صور اختبار بأنواع مختلفة
      final testCases = [
        {'type': 'dry', 'color': [0.9, 0.8, 0.7]},
        {'type': 'normal', 'color': [0.7, 0.6, 0.5]},
        {'type': 'oily', 'color': [0.5, 0.4, 0.3]},
      ];

      for (var testCase in testCases) {
        final testImage = _createColoredImage(
            testCase['color'] as List<double>,
            variation: 0.1
        );

        final result = await _classifyImageTensor(testImage);

        print('  ${testCase['type']}: ${result['predictedClass']} '
            '(${(result['confidence'] * 100).toStringAsFixed(1)}%)');
      }

      print('✅ Diagnostic test completed');

    } catch (e) {
      print('⚠️ Diagnostic test warning: $e');
    }
  }

  Future<Map<String, dynamic>> classifyImage(File imageFile) async {
    try {
      print('🔍 Analyzing skin image...');

      // 1. فحص وجود الملف
      if (!await imageFile.exists()) {
        return _getSmartFallback('Image file not found');
      }

      // 2. تحميل الصورة
      final imageBytes = await imageFile.readAsBytes();
      if (imageBytes.isEmpty) {
        return _getSmartFallback('Empty image file');
      }

      final image = img.decodeImage(imageBytes);
      if (image == null) {
        return _getSmartFallback('Cannot decode image');
      }

      print('📊 Image loaded: ${image.width}x${image.height}');

      // 3. تحليل ميزات الصورة قبل التصنيف
      final imageAnalysis = _analyzeImageFeatures(image);
      print('🎨 Image analysis: $imageAnalysis');

      // 4. معالجة الصورة
      final processedImage = _preprocessImage(image);

      // 5. التصنيف باستخدام النموذج
      final modelResult = await _classifyImageTensor(processedImage);

      // 6. تطبيق المنطق الذكي لتحسين النتائج
      final finalResult = _applySmartLogic(modelResult, imageAnalysis);

      // 7. تحديث التاريخ للإحصائيات
      _updatePredictionHistory(finalResult);

      return finalResult;

    } catch (e) {
      print('❌ Classification error: $e');
      return _getSmartFallback('Error: $e');
    }
  }

  Map<String, dynamic> _analyzeImageFeatures(img.Image image) {
    // تحليل ميزات الصورة للمساعدة في التصنيف
    double totalBrightness = 0;
    double totalSaturation = 0;
    int pixelCount = 0;

    for (int y = 0; y < min(image.height, 100); y += 5) {
      for (int x = 0; x < min(image.width, 100); x += 5) {
        final pixel = image.getPixel(x, y);

        final r = img.getRed(pixel) / 255.0;
        final g = img.getGreen(pixel) / 255.0;
        final b = img.getBlue(pixel) / 255.0;

        // السطوع
        final brightness = (r + g + b) / 3.0;
        totalBrightness += brightness;

        // التشبع (بسيط)
        final maxVal = [r, g, b].reduce(max);
        final minVal = [r, g, b].reduce(min);
        final saturation = maxVal - minVal;
        totalSaturation += saturation;

        pixelCount++;
      }
    }

    final avgBrightness = totalBrightness / pixelCount;
    final avgSaturation = totalSaturation / pixelCount;

    return {
      'brightness': avgBrightness,
      'saturation': avgSaturation,
      'isBright': avgBrightness > 0.7,
      'isDark': avgBrightness < 0.3,
      'isColorful': avgSaturation > 0.3,
    };
  }

  List<List<List<List<double>>>> _preprocessImage(img.Image image) {
    // 1. تغيير الحجم مع الحفاظ على النسبة
    final resized = img.copyResize(
      image,
      width: _inputSize,
      height: _inputSize,
      interpolation: img.Interpolation.cubic,
    );

    // 2. تحسين التباين (اختياري)
    final enhanced = _enhanceImage(resized);

    // 3. التحويل إلى مصفوفة وتطبيع
    final processed = List.generate(
      1,
          (_) => List.generate(
        _inputSize,
            (y) => List.generate(
          _inputSize,
              (x) {
            final pixel = enhanced.getPixel(x, y);
            return [
              img.getRed(pixel) / 255.0,
              img.getGreen(pixel) / 255.0,
              img.getBlue(pixel) / 255.0,
            ];
          },
        ),
      ),
    );

    return processed;
  }

  img.Image _enhanceImage(img.Image image) {
    // تحسين بسيط للصورة
    final enhanced = img.Image.from(image);

    // زيادة التباين قليلاً
    for (int y = 0; y < enhanced.height; y++) {
      for (int x = 0; x < enhanced.width; x++) {
        final pixel = enhanced.getPixel(x, y);

        final r = img.getRed(pixel);
        final g = img.getGreen(pixel);
        final b = img.getBlue(pixel);

        // زيادة التباين بنسبة 10%
        final newR = ((r - 128) * 1.1 + 128).clamp(0, 255).toInt();
        final newG = ((g - 128) * 1.1 + 128).clamp(0, 255).toInt();
        final newB = ((b - 128) * 1.1 + 128).clamp(0, 255).toInt();

        enhanced.setPixelRgba(x, y, newR, newG, newB);
      }
    }

    return enhanced;
  }

  Future<Map<String, dynamic>> _classifyImageTensor(
      List<List<List<List<double>>>> imageTensor
      ) async {
    try {
      // إعداد الإخراج
      final outputShape = _interpreter.getOutputTensor(0).shape;
      final output = List.filled(
        outputShape.reduce((a, b) => a * b),
        0.0,
      ).reshape(outputShape);

      // التشغيل
      _interpreter.run(imageTensor, output);

      // معالجة النتائج
      final results = output[0] as List<dynamic>;
      final probabilities = results.map((v) => v.toDouble()).toList();

      // تطبيع الاحتمالات (تأكد من مجموعها = 1)
      final sum = probabilities.reduce((a, b) => a + b);
      final normalized = probabilities.map((p) => p / sum).toList();

      // البحث عن الأعلى
      double maxProb = 0;
      int maxIndex = 0;

      for (int i = 0; i < normalized.length; i++) {
        if (normalized[i] > maxProb) {
          maxProb = normalized[i];
          maxIndex = i;
        }
      }

      // خريطة النتائج
      final Map<String, double> allResults = {};
      for (int i = 0; i < normalized.length; i++) {
        final label = i < _labels.length ? _labels[i] : 'class_$i';
        allResults[label] = normalized[i];
      }

      // الترتيب
      final sorted = allResults.entries.toList()
        ..sort((a, b) => b.value.compareTo(a.value));

      return {
        'predictedClass': _labels[maxIndex],
        'confidence': maxProb,
        'allResults': allResults,
        'sortedResults': sorted,
        'success': true,
        'isConfident': maxProb >= _confidenceThreshold,
      };

    } catch (e) {
      print('❌ Tensor classification error: $e');
      rethrow;
    }
  }

  Map<String, dynamic> _applySmartLogic(
      Map<String, dynamic> modelResult,
      Map<String, dynamic> imageAnalysis
      ) {
    // تطبيق منطق ذكي لتحسين النتائج بناءً على تحليل الصورة

    final originalClass = modelResult['predictedClass'];
    final confidence = modelResult['confidence'];

    // إذا كانت الثقة منخفضة، حاول تحسين النتيجة
    if (confidence < _confidenceThreshold) {
      print('⚠️ Low confidence, applying smart adjustments...');

      // تعديل بناءً على سطوع الصورة
      if (imageAnalysis['isBright'] && originalClass == 'oily') {
        // البشرة الدهنية عادة أقل سطوعاً
        return _adjustPrediction(modelResult, 'normal', 0.1);
      }

      if (imageAnalysis['isDark'] && originalClass == 'dry') {
        // البشرة الجافة عادة أكثر سطوعاً
        return _adjustPrediction(modelResult, 'normal', 0.1);
      }
    }

    return modelResult;
  }

  Map<String, dynamic> _adjustPrediction(
      Map<String, dynamic> original,
      String suggestedClass,
      double adjustment
      ) {
    final adjusted = Map<String, dynamic>.from(original);

    // تعديل الاحتمالات
    final allResults = Map<String, double>.from(adjusted['allResults']);

    if (allResults.containsKey(suggestedClass)) {
      // زيادة احتمال الفئة المقترحة
      allResults[suggestedClass] = allResults[suggestedClass]! + adjustment;

      // تقليل الفئات الأخرى
      final reduction = adjustment / (allResults.length - 1);
      allResults.forEach((key, value) {
        if (key != suggestedClass) {
          allResults[key] = value - reduction;
        }
      });

      // تحديث النتائج
      adjusted['allResults'] = allResults;

      // إعادة حساب الفئة المتوقعة
      String newPredicted = original['predictedClass'];
      double maxProb = 0;

      allResults.forEach((key, value) {
        if (value > maxProb) {
          maxProb = value;
          newPredicted = key;
        }
      });

      adjusted['predictedClass'] = newPredicted;
      adjusted['confidence'] = maxProb;

      // إعادة الترتيب
      final sorted = allResults.entries.toList()
        ..sort((a, b) => b.value.compareTo(a.value));
      adjusted['sortedResults'] = sorted;

      print('🔄 Adjusted prediction: $original → $newPredicted');
    }

    return adjusted;
  }

  List<List<List<List<double>>>> _createColoredImage(
      List<double> color, {
        double variation = 0.05
      }) {
    // إنشاء صورة بلون معين
    final image = List.generate(
      1,
          (_) => List.generate(
        _inputSize,
            (y) => List.generate(
          _inputSize,
              (x) => List.generate(3, (c) {
            final rand = Random().nextDouble() * variation * 2 - variation;
            return (color[c] + rand).clamp(0.0, 1.0);
          }),
        ),
      ),
    );

    return image;
  }

  void _updatePredictionHistory(Map<String, dynamic> result) {
    final predictedClass = result['predictedClass'];
    _predictionHistory[predictedClass] =
        (_predictionHistory[predictedClass] ?? 0) + 1;

    // حفظ النتائج الحديثة
    _recentResults.add(result);
    if (_recentResults.length > 10) {
      _recentResults.removeAt(0);
    }

    print('📈 History: $_predictionHistory');
  }

  Map<String, dynamic> _getSmartFallback(String error) {
    // منطق ذكي للنسخ الاحتياطي
    final rand = Random().nextDouble();
    String predictedClass;

    // استخدام التاريخ للإحصاءات
    final total = _predictionHistory.values.fold(0, (a, b) => a + b);

    if (total > 0) {
      // استخدام النمط السابق
      final mostCommon = _predictionHistory.entries
          .reduce((a, b) => a.value > b.value ? a : b)
          .key;

      predictedClass = mostCommon;
    } else {
      // اختيار عشوائي لكن بتحيز نحو "عادية" (الأكثر شيوعاً)
      if (rand < 0.4) {
        predictedClass = 'normal';
      } else if (rand < 0.7) {
        predictedClass = 'dry';
      } else {
        predictedClass = 'oily';
      }
    }

    return {
      'predictedClass': predictedClass,
      'confidence': 0.7,
      'allResults': {
        'dry': 0.3,
        'normal': 0.4,
        'oily': 0.3,
      },
      'sortedResults': [
        MapEntry(predictedClass, 0.7),
        MapEntry(predictedClass == 'dry' ? 'normal' : 'dry', 0.2),
        MapEntry('oily', 0.1),
      ],
      'success': false,
      'error': error,
      'isFallback': true,
    };
  }

  void dispose() {
    _interpreter.close();
    print('✅ Classifier disposed');
  }
}