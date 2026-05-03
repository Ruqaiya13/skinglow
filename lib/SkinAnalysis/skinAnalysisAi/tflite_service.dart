import 'dart:io';
import 'package:flutter/services.dart';
import 'package:tflite_flutter/tflite_flutter.dart';
import 'package:image/image.dart' as img;

class TFLiteService {
  static const String _modelPath = 'assets/models/skin_model_fixed.tflite';
  static const String _labelsPath = 'assets/models/labels.txt';

  Interpreter? _interpreter;
  List<String> _labels = [];
  bool _isModelLoaded = false;
  final int _inputSize = 224;

  Future<void> loadModel() async {
    try {
      print('🔄 [1] Loading model: $_modelPath');

      // Load labels
      try {
        final labelData = await rootBundle.loadString(_labelsPath);
        _labels = labelData.split('\n').where((label) => label.trim().isNotEmpty).toList();
        print('✅ Labels loaded: $_labels');
      } catch (e) {
        _labels = ['dry', 'normal', 'oily'];
        print('⚠️ Using default labels: $_labels');
      }

      // Simple interpreter options (without GPU delegate)
      final options = InterpreterOptions()
        ..threads = 2
        ..useNnApiForAndroid = false;  // Disable NNAPI temporarily

      print('🔄 [2] Creating interpreter...');
      _interpreter = await Interpreter.fromAsset(_modelPath, options: options);

      // Get model info
      final inputTensor = _interpreter!.getInputTensor(0);
      final outputTensor = _interpreter!.getOutputTensor(0);

      print('✅ Model loaded successfully!');
      print('📊 Input shape: ${inputTensor.shape}');
      print('📊 Output shape: ${outputTensor.shape}');
      print('📊 Input type: ${inputTensor.type}');
      print('📊 Output type: ${outputTensor.type}');

      _isModelLoaded = true;

    } catch (e) {
      print('❌ Error loading model: $e');
      print('❌ Error details: ${e.toString()}');
      _isModelLoaded = false;
      rethrow;
    }
  }

  Future<Map<String, dynamic>> classifyImage(File imageFile) async {
    try {
      print('🔄 Processing image: ${imageFile.path}');

      if (!_isModelLoaded || _interpreter == null) {
        throw Exception('Model not loaded. Please load model first.');
      }

      // Check if file exists
      if (!await imageFile.exists()) {
        throw Exception('Image file does not exist: ${imageFile.path}');
      }

      // Read and decode image
      final imageBytes = await imageFile.readAsBytes();
      if (imageBytes.isEmpty) {
        throw Exception('Image file is empty');
      }

      final image = img.decodeImage(imageBytes);
      if (image == null) {
        throw Exception('Failed to decode image');
      }

      print('📊 Original image: ${image.width}x${image.height}');

      // Resize image
      final resizedImage = img.copyResize(
        image,
        width: _inputSize,
        height: _inputSize,
        interpolation: img.Interpolation.cubic,
      );

      // Prepare input
      final input = _prepareInput(resizedImage);

      // Prepare output
      final outputShape = _interpreter!.getOutputTensor(0).shape;
      final output = List.filled(
        outputShape.reduce((a, b) => a * b),
        0.0,
      ).reshape(outputShape);

      // Run inference
      final stopwatch = Stopwatch()..start();
      _interpreter!.run(input, output);
      stopwatch.stop();

      print('✅ Inference completed in ${stopwatch.elapsedMilliseconds}ms');

      // Process results
      return _processOutput(output[0]);

    } catch (e) {
      print('❌ Classification error: $e');
      print('❌ Stack trace: ${e.toString()}');

      // Return fallback results for debugging
      return _getFallbackResult(e.toString());
    }
  }

  List<dynamic> _prepareInput(img.Image image) {
    final inputShape = _interpreter!.getInputTensor(0).shape;

    // Create 4D array: [1, 224, 224, 3]
    final input = List.generate(
      inputShape[0],
          (_) => List.generate(
        inputShape[1],
            (y) => List.generate(
          inputShape[2],
              (x) => List.generate(
            inputShape[3],
                (c) => 0.0,
          ),
        ),
      ),
    );

    // Fill with normalized pixel values
    for (int y = 0; y < _inputSize; y++) {
      for (int x = 0; x < _inputSize; x++) {
        final pixel = image.getPixel(x, y);

        // Normalize RGB values to [0, 1]
        input[0][y][x][0] = img.getRed(pixel) / 255.0;   // Red
        input[0][y][x][1] = img.getGreen(pixel) / 255.0; // Green
        input[0][y][x][2] = img.getBlue(pixel) / 255.0;  // Blue
      }
    }

    return input;
  }

  Map<String, dynamic> _processOutput(List<dynamic> output) {
    try {
      // Convert to List<double>
      final probabilities = output.map((value) {
        try {
          return value.toDouble();
        } catch (e) {
          return 0.0;
        }
      }).toList();

      print('📊 Raw output probabilities: $probabilities');

      // Find highest probability
      double maxProb = 0.0;
      int maxIndex = 0;

      for (int i = 0; i < probabilities.length; i++) {
        if (probabilities[i] > maxProb) {
          maxProb = probabilities[i];
          maxIndex = i;
        }
      }

      // Create results map
      final Map<String, double> allResults = {};
      for (int i = 0; i < _labels.length; i++) {
        final index = i < probabilities.length ? i : 0;
        allResults[_labels[i]] = probabilities[index];
      }

      // Sort results
      final sorted = allResults.entries.toList()
        ..sort((a, b) => b.value.compareTo(a.value));

      final result = {
        'predictedClass': _labels[maxIndex],
        'confidence': maxProb,
        'allResults': allResults,
        'sortedResults': sorted,
        'success': true,
      };

      print('📊 Final result: $result');
      return result;

    } catch (e) {
      print('❌ Output processing error: $e');
      return _getFallbackResult('Output processing error: $e');
    }
  }

  Map<String, dynamic> _getFallbackResult(String error) {
    return {
      'predictedClass': 'normal',
      'confidence': 0.85,
      'allResults': {'dry': 0.1, 'normal': 0.85, 'oily': 0.05},
      'sortedResults': [
        MapEntry('normal', 0.85),
        MapEntry('dry', 0.1),
        MapEntry('oily', 0.05),
      ],
      'success': false,
      'error': error,
    };
  }

  bool get isModelLoaded => _isModelLoaded;

  void dispose() {
    _interpreter?.close();
    print('✅ Interpreter disposed');
  }
}