/*import 'dart:convert';
import 'dart:io';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:skinglow/SkinAnalysis/skin_analysis.dart';
import 'package:tflite_flutter/tflite_flutter.dart';
import 'analysis_history_service.dart';
import 'skin_type_provider.dart';
import 'package:flutter/material.dart';
import 'package:camera/camera.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';

import 'skin_service.dart';

class SkinAnalysisScreen extends StatefulWidget {
  @override
  _SkinAnalysisScreenState createState() => _SkinAnalysisScreenState();
}

class _SkinAnalysisScreenState extends State<SkinAnalysisScreen> {
  late CameraController _cameraController;
  final ImagePicker _imagePicker = ImagePicker();
  bool _isLoading = false;
  bool _isCameraInitialized = false;
  int _selectedCameraIndex = 0;
  List<CameraDescription> _cameras = [];

  late Interpreter _interpreter;
  List<String> _targetAreas = ['Front', 'Right cheek', 'Left cheek', 'Nose', 'chin'];
  int _currentStep = 0;
  List<File> _capturedImages = [];
  final AnalysisHistoryService _historyService = AnalysisHistoryService();

  @override
  void initState() {
    super.initState();
    _loadModel();
  }

  // تحميل النموذج
  Future<void> _loadModel() async {
    try {
      _interpreter = await Interpreter.fromAsset('assets/skin_model.tflite');
      print("Model loaded successfully");
      await _initializeCamera();
    } catch (e) {
      print("Error loading model: $e");
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to load model')),
      );
    }
  }

  // تهيئة الكاميرا
  Future<void> _initializeCamera() async {
    try {
      _cameras = await availableCameras();

      if (_selectedCameraIndex >= _cameras.length) {
        _selectedCameraIndex = 0;
      }

      _cameraController = CameraController(
        _cameras[_selectedCameraIndex],
        ResolutionPreset.high,
      );

      await _cameraController.initialize();

      if (!mounted) return;

      setState(() {
        _isCameraInitialized = true;
      });
    } catch (e) {
      print('Error initializing camera: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to initialize camera')),
      );
    }
  }

  // دالة لتبديل الكاميرا
  Future<void> _switchCamera() async {
    if (_cameras.length < 2) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Only one camera available')),
      );
      return;
    }

    setState(() => _isLoading = true);

    try {
      await _cameraController.dispose();

      _selectedCameraIndex = (_selectedCameraIndex + 1) % _cameras.length;

      _cameraController = CameraController(
        _cameras[_selectedCameraIndex],
        ResolutionPreset.high,
      );

      await _cameraController.initialize();

      setState(() {
        _isCameraInitialized = true;
      });

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(_selectedCameraIndex == 0 ?
          'Switched to back camera' : 'Switched to front camera'),
          duration: Duration(seconds: 1),
        ),
      );
    } catch (e) {
      print('Error switching camera: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to switch camera')),
      );
    } finally {
      setState(() => _isLoading = false);
    }
  }

  // دالة لالتقاط صورة
  Future<void> _captureSkinImage() async {
    setState(() => _isLoading = true);
    try {
      final XFile image = await _cameraController.takePicture();
      setState(() {
        _capturedImages.add(File(image.path));
      });

      if (_currentStep < _targetAreas.length - 1) {
        setState(() => _currentStep++);
        _showNextStepDialog();
      } else {
        await _processAllImages();
      }
    } catch (e) {
      print('Error capturing image: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to capture image: $e')),
      );
    } finally {
      setState(() => _isLoading = false);
    }
  }

  @override
  void dispose() {
    _interpreter.close();
    _cameraController.dispose();
    super.dispose();
  }

  void _showNextStepDialog() {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('Next step'),
        content: Text('Please take a picture ${_targetAreas[_currentStep]}'),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.pop(ctx);
              _initializeCamera();
            },
            child: Text('OK'),
          ),
        ],
      ),
    );
  }

  // ✅ دالة جديدة: عرض رسالة تتطلب تسجيل الدخول
  void _showLoginRequiredDialog() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        title: Row(
          children: [
            Icon(Icons.warning, color: Colors.orange),
            SizedBox(width: 10),
            Text('Login Required'),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text('You need to log in to save your skin analysis results permanently.'),
            SizedBox(height: 15),
            Container(
              padding: EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: Colors.orange[50],
                borderRadius: BorderRadius.circular(8),
              ),
              child: Column(
                children: [
                  Row(
                    children: [
                      Icon(Icons.info, size: 16, color: Colors.orange),
                      SizedBox(width: 5),
                      Text('Without login:', style: TextStyle(fontWeight: FontWeight.bold)),
                    ],
                  ),
                  SizedBox(height: 5),
                  Text(
                    '• Results will be temporary\n'
                        '• Not saved to your account\n'
                        '• Not available on other devices',
                    style: TextStyle(fontSize: 12),
                  ),
                ],
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              // الاستمرار بدون تسجيل دخول
              _continueWithoutLogin();
            },
            child: Text('Continue Anyway'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              // يمكنك هنا توجيه المستخدم لصفحة تسجيل الدخول
              // Navigator.push(context, MaterialPageRoute(builder: (_) => LoginScreen()));
              _showLoginInstructions();
            },
            child: Text('Go to Login'),
            style: ElevatedButton.styleFrom(
              backgroundColor: Color(0xFF914D74),
            ),
          ),
        ],
      ),
    );
  }

  // ✅ دالة جديدة: الاستمرار بدون تسجيل دخول
  void _continueWithoutLogin() {
    // هنا يمكنك عرض النتائج بشكل مؤقت
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Showing temporary results. Log in to save permanently.'),
        backgroundColor: Colors.orange,
      ),
    );

    // يمكنك هنا عرض النتائج دون حفظها
    // _showTemporaryResults();
  }

  // ✅ دالة جديدة: عرض تعليمات تسجيل الدخول
  void _showLoginInstructions() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('How to Login'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text('To save your skin analysis:'),
            SizedBox(height: 10),
            Row(
              children: [
                Icon(Icons.exit_to_app, size: 16),
                SizedBox(width: 5),
                Text('1. Go back to Home page'),
              ],
            ),
            SizedBox(height: 5),
            Row(
              children: [
                Icon(Icons.person, size: 16),
                SizedBox(width: 5),
                Text('2. Tap Profile icon'),
              ],
            ),
            SizedBox(height: 5),
            Row(
              children: [
                Icon(Icons.login, size: 16),
                SizedBox(width: 5),
                Text('3. Login with your account'),
              ],
            ),
            SizedBox(height: 15),
            Text(
              'Then come back to continue your analysis.',
              style: TextStyle(fontStyle: FontStyle.italic),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('OK'),
          ),
        ],
      ),
    );
  }

  // ✅ دالة جديدة: عرض نتائج التحليل مع معلومات المستخدم
  void _showAnalysisResult(String skinType, String userId) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        title: Row(
          children: [
            Icon(Icons.celebration, color: Color(0xFF914D74)),
            SizedBox(width: 10),
            Text('Analysis Complete!'),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('🎉 Your skin analysis is ready!', style: TextStyle(fontSize: 16)),
            SizedBox(height: 15),
            Container(
              padding: EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Color(0xFFF8F0F5),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(Icons.face, color: Color(0xFF914D74), size: 20),
                      SizedBox(width: 8),
                      Text(
                        'Skin Type:',
                        style: TextStyle(fontWeight: FontWeight.w500),
                      ),
                    ],
                  ),
                  SizedBox(height: 5),
                  Text(
                    skinType,
                    style: TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF914D74),
                    ),
                  ),
                ],
              ),
            ),
            SizedBox(height: 10),
            Row(
              children: [
                Icon(Icons.check_circle, color: Colors.green, size: 16),
                SizedBox(width: 5),
                Expanded(
                  child: Text(
                    'Results saved to your account',
                    style: TextStyle(color: Colors.green, fontSize: 12),
                  ),
                ),
              ],
            ),
            Row(
              children: [
                Icon(Icons.check_circle, color: Colors.green, size: 16),
                SizedBox(width: 5),
                Expanded(
                  child: Text(
                    'Available on all your devices',
                    style: TextStyle(color: Colors.green, fontSize: 12),
                  ),
                ),
              ],
            ),
            SizedBox(height: 10),
            Divider(),
            SizedBox(height: 5),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Account:',
                  style: TextStyle(fontSize: 12, color: Colors.grey),
                ),
                Text(
                  '${userId.substring(0, 8)}...',
                  style: TextStyle(fontSize: 10, color: Colors.grey),
                ),
              ],
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.pop(context);
            },
            child: Text(
              'View Recommendations',
              style: TextStyle(color: Color(0xFF914D74), fontWeight: FontWeight.bold),
            ),
          ),
        ],
      ),
    );
  }

  // تعديل دالة _processAllImages لربط النتائج بالمستخدم
  Future<void> _processAllImages() async {
    try {
      setState(() => _isLoading = true);

      print('🔄 Processing ${_capturedImages.length} images...');

      // 1. تحليل كل صورة
      List<Map<String, dynamic>> results = [];
      for (var i = 0; i < _capturedImages.length; i++) {
        try {
          final image = _capturedImages[i];
          final result = await SkinService.analyzeSkin(image.path);

          results.add({
            'area': _targetAreas[i],
            'type': result,
            'imagePath': image.path,
          });

          print('✅ Analyzed ${_targetAreas[i]}: $result');
        } catch (e) {
          print('⚠️ Error analyzing ${_targetAreas[i]}: $e');
        }
      }

      // 2. تحديد النوع السائد
      final dominantType = _getDominantType(results.map((r) => r['type'].toString()).toList());
      print('🎯 Dominant skin type: $dominantType');

      // 3. إنشاء كائن التحليل
      final analysis = SkinAnalysis(
        id: 'analysis_${DateTime.now().millisecondsSinceEpoch}',
        date: DateTime.now(),
        skinType: dominantType,
        concerns: _extractConcernsFromResults(results),
        confidence: _calculateConfidence(results),
        problems: _extractProblemsFromType(dominantType),
        imageUrl: null,
        imageBase64: _convertFirstImageToBase64(),
        productRecommendations: _generateProductRecommendations(dominantType),
        metadata: {
          'numberOfImages': _capturedImages.length,
          'areasAnalyzed': _targetAreas,
          'analysisMethod': 'multi_area_capture',
          'cameraUsed': _cameras[_selectedCameraIndex].name,
          'userId': FirebaseAuth.instance.currentUser?.uid,
          'userEmail': FirebaseAuth.instance.currentUser?.email,
        },
        targetArea: 'Multiple',
      );

      // 4. ✅ التحقق من وجود مستخدم مسجل قبل الحفظ
      final currentUser = FirebaseAuth.instance.currentUser;
      if (currentUser != null) {
        print('👤 User logged in: ${currentUser.uid}');

        // حفظ في الـ Provider (مرتبط بالمستخدم الحالي)
        await context.read<SkinTypeProvider>().setSkinType(
          dominantType,
          problems: analysis.problems,
          confidence: analysis.confidence,
        );
        print('✅ Skin type saved to Provider for user: ${currentUser.uid}');

        // ✅ إضافة التحليل لتاريخ المستخدم
        await context.read<SkinTypeProvider>().addToHistory(analysis);
        print('✅ Analysis added to history for user: ${currentUser.uid}');
      } else {
        print('⚠️ No user logged in. Cannot save skin data permanently.');
        _showLoginRequiredDialog();
        setState(() => _isLoading = false);
        return;
      }

      // 5. حفظ في قاعدة البيانات
      try {
        await _historyService.saveAnalysis(analysis);
        print('✅ Analysis saved to database');
      } catch (e) {
        print('⚠️ Failed to save analysis to database: $e');
      }

      // 6. إظهار النتيجة مع معلومات المستخدم
      _showAnalysisResult(dominantType, currentUser!.uid);

      // 7. العودة إلى الصفحة الرئيسية بعد 4 ثواني
      Future.delayed(Duration(seconds: 4), () {
        if (mounted) {
          Navigator.pop(context, {
            'skinType': dominantType,
            'problems': analysis.problems,
            'confidence': analysis.confidence,
            'userId': currentUser.uid,
          });
        }
      });

    } catch (e) {
      print('❌ Error processing images: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error analyzing skin: ${e.toString()}'),
          backgroundColor: Colors.red,
        ),
      );
    } finally {
      setState(() => _isLoading = false);
    }
  }

  // إضافة دوال مساعدة جديدة
  Map<String, double> _extractConcernsFromResults(List<Map<String, dynamic>> results) {
    Map<String, int> typeCount = {};
    for (var result in results) {
      final type = result['type'].toString();
      typeCount[type] = (typeCount[type] ?? 0) + 1;
    }

    final total = results.length;
    return {
      for (var entry in typeCount.entries)
        entry.key.toLowerCase(): entry.value / total,
    };
  }

  double _calculateConfidence(List<Map<String, dynamic>> results) {
    if (results.isEmpty) return 0.0;

    Map<String, int> typeCount = {};
    for (var result in results) {
      final type = result['type'].toString();
      typeCount[type] = (typeCount[type] ?? 0) + 1;
    }

    final maxCount = typeCount.values.reduce((a, b) => a > b ? a : b);
    return maxCount / results.length;
  }

  List<String> _extractProblemsFromType(String skinType) {
    final Map<String, List<String>> skinTypeProblems = {
      'Oily': ['Oiliness', 'Shine', 'Large pores'],
      'Dry': ['Dryness', 'Flakiness', 'Tightness'],
      'Combination': ['Oiliness in T-zone', 'Dryness in cheeks', 'Uneven texture'],
      'Sensitive': ['Redness', 'Sensitivity', 'Irritation'],
      'Normal': ['None'],
    };

    return skinTypeProblems[skinType] ?? [];
  }

  String? _convertFirstImageToBase64() {
    try {
      if (_capturedImages.isNotEmpty) {
        final imageBytes = _capturedImages.first.readAsBytesSync();
        return base64Encode(imageBytes);
      }
    } catch (e) {
      print('❌ Error converting image to base64: $e');
    }
    return null;
  }

  List<String> _generateProductRecommendations(String skinType) {
    final recommendations = {
      'Oily': [
        'Oil-free cleanser',
        'Salicylic acid toner',
        'Non-comedogenic moisturizer',
        'Clay mask (2x weekly)',
      ],
      'Dry': [
        'Creamy hydrating cleanser',
        'Hyaluronic acid serum',
        'Ceramide-rich moisturizer',
        'Facial oil at night',
      ],
      'Combination': [
        'Gel cleanser for combination skin',
        'Balancing toner',
        'Lightweight moisturizer',
        'Different products for T-zone and cheeks',
      ],
      'Sensitive': [
        'Fragrance-free cleanser',
        'Soothing serum (centella asiatica)',
        'Hypoallergenic moisturizer',
        'Mineral sunscreen',
      ],
      'Normal': [
        'Gentle cleanser',
        'Antioxidant serum (Vitamin C)',
        'Light moisturizer',
        'Broad-spectrum sunscreen',
      ],
    };

    return recommendations[skinType] ?? [
      'Gentle cleanser',
      'Daily moisturizer',
      'SPF 30+ sunscreen',
    ];
  }

  String _getDominantType(List<String> types) {
    if (types.isEmpty) return 'Normal';

    Map<String, int> frequency = {};
    for (var type in types) {
      if (type.isNotEmpty) {
        frequency[type] = (frequency[type] ?? 0) + 1;
      }
    }

    if (frequency.isEmpty) return 'Normal';

    final dominant = frequency.entries.reduce((a, b) => a.value > b.value ? a : b);
    return dominant.key;
  }

  void _showTemporaryResult(String type) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Your skin type: $type'),
        duration: Duration(seconds: 3),
        backgroundColor: Colors.green,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (!_isCameraInitialized) {
      return Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: Text('Skin examination'),
        centerTitle: true,
        actions: [
          // ✅ إضافة زر للتحقق من المستخدم الحالي
          IconButton(
            icon: Icon(Icons.person, color: Colors.white),
            onPressed: () {
              final currentUser = FirebaseAuth.instance.currentUser;
              if (currentUser != null) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text('Logged in as: ${currentUser.email ?? currentUser.uid.substring(0, 8)}...'),
                    duration: Duration(seconds: 2),
                  ),
                );
              } else {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text('Not logged in. Results will not be saved.'),
                    backgroundColor: Colors.orange,
                    duration: Duration(seconds: 3),
                  ),
                );
              }
            },
            tooltip: 'Check login status',
          ),
          IconButton(
            icon: Icon(Icons.cameraswitch),
            onPressed: _switchCamera,
            tooltip: 'Switch camera',
          ),
        ],
      ),
      body: Stack(
        children: [
          Column(
            children: [
              Expanded(
                child: Center(
                  child: Container(
                    width: 350,
                    height: 700,
                    child: AspectRatio(
                      aspectRatio: _cameraController.value.aspectRatio,
                      child: CameraPreview(_cameraController),
                    ),
                  ),
                ),
              ),
              // ✅ إضافة مؤشر للمستخدم الحالي
              Container(
                padding: EdgeInsets.symmetric(vertical: 8),
                color: Colors.black.withOpacity(0.7),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      FirebaseAuth.instance.currentUser != null
                          ? Icons.check_circle
                          : Icons.warning,
                      color: FirebaseAuth.instance.currentUser != null
                          ? Colors.green
                          : Colors.orange,
                      size: 16,
                    ),
                    SizedBox(width: 8),
                    Text(
                      FirebaseAuth.instance.currentUser != null
                          ? 'Results will be saved to your account'
                          : 'Log in to save results',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
      floatingActionButton: _isLoading
          ? CircularProgressIndicator()
          : _buildCaptureButton(),
      floatingActionButtonLocation: FloatingActionButtonLocation.centerFloat,
    );
  }

  Widget _buildCaptureButton() {
    return Container(
      margin: EdgeInsets.only(bottom: 20),
      child: FloatingActionButton.large(
        onPressed: _captureSkinImage,
        child: Icon(Icons.camera_alt, size: 35),
        backgroundColor: Colors.blueAccent,
      ),
    );
  }
}

 */
