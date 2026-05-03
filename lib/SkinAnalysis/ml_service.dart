import 'dart:typed_data';
import 'dart:io';
import 'package:tflite_flutter/tflite_flutter.dart';
import 'package:image/image.dart' as img;

class MLService {
  late Interpreter _interpreter;
  bool _modelLoaded = false;

  Future<void> loadModel() async {
    try {
      _interpreter = await Interpreter.fromAsset('assets/skin_model.tflite');
      _modelLoaded = true;
    } catch (e) {
      print("❌ Error loading model: $e");
      _modelLoaded = false;
    }
  }

  Future<Map<String, dynamic>> predict(File imageFile) async {
    try {
      if (!_modelLoaded) {
        await loadModel();
      }

      // تحميل الصورة وتحويلها
      final imageBytes = await imageFile.readAsBytes();
      final image = img.decodeImage(imageBytes);

      if (image == null) {
        throw Exception('Failed to decode image');
      }

      final resizedImage = img.copyResize(image, width: 128, height: 128);
      final input = _imageToByteListFloat32(resizedImage);
      final output = List.filled(1 * 5, 0.0).reshape([1, 5]);

      // تشغيل النموذج
      _interpreter.run(input, output);

      final resultList = List<double>.from(output[0]);
      final skinType = _getSkinType(resultList);
      final problems = _detectProblems(resultList);
      final confidence = resultList.reduce((a, b) => a > b ? a : b);

      return {
        'skinType': skinType,
        'problems': problems,
        'confidence': confidence,
        'error': null,
      };
    } catch (e) {
      return {
        'skinType': 'Normal',
        'problems': ['Unknown'],
        'confidence': 0.5,
        'error': e.toString(),
      };
    }
  }

  Float32List _imageToByteListFloat32(img.Image image) {
    final convertedBytes = Float32List(1 * 128 * 128 * 3);
    final buffer = Float32List.view(convertedBytes.buffer);
    int pixelIndex = 0;

    for (var y = 0; y < 128; y++) {
      for (var x = 0; x < 128; x++) {
        final pixel = image.getPixel(x, y);
        buffer[pixelIndex++] = img.getRed(pixel) / 255.0;
        buffer[pixelIndex++] = img.getGreen(pixel) / 255.0;
        buffer[pixelIndex++] = img.getBlue(pixel) / 255.0;
      }
    }

    return convertedBytes;
  }

  String _getSkinType(List<double> output) {
    if (output.isEmpty) return 'Normal';

    final types = ['Dry', 'Oily', 'Combination', 'Normal', 'Sensitive'];
    final maxIndex = output.indexOf(output.reduce((a, b) => a > b ? a : b));

    if (maxIndex >= 0 && maxIndex < types.length) {
      return types[maxIndex];
    }

    return 'Normal';
  }

  List<String> _detectProblems(List<double> output) {
    final problems = <String>[];

    if (output.length > 0 && output[0] > 0.4) problems.add('Dryness');
    if (output.length > 1 && output[1] > 0.6) problems.add('Oiliness');
    if (output.length > 2 && output[2] > 0.5) problems.add('Combination');
    if (output.length > 4 && output[4] > 0.4) problems.add('Sensitivity');

    return problems;
  }

  bool get isModelLoaded => _modelLoaded;
}