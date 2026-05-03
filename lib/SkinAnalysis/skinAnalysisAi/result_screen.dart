import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:skinglow/SkinAnalysis/skin_type_provider.dart';
import 'package:skinglow/SkinAnalysis/skin_analysis.dart';
import '../analysis_history_service.dart';
import '../skin_history_screen.dart';

class ResultScreen extends StatelessWidget {
  final Map<String, dynamic> prediction;
  final String imagePath;
  final SkinAnalysis? _cachedAnalysis;

  ResultScreen({
    required this.prediction,
    required this.imagePath,
  }) : _cachedAnalysis = null;

  ResultScreen._withCachedAnalysis({
    required this.prediction,
    required this.imagePath,
    required SkinAnalysis? cachedAnalysis,
  }) : _cachedAnalysis = cachedAnalysis;

  // Function to get recommendations based on skin type
  String _getRecommendation(String skinType) {
    switch (skinType.toLowerCase()) {
      case 'dry':
        return '• Use rich moisturizers\n• Drink plenty of water\n• Avoid harsh soaps';
      case 'oily':
        return '• Use gentle cleansers\n• Avoid oily products\n• Use oil-free sunscreen';
      case 'normal':
        return '• Maintain a simple routine\n• Use daily moisturizer\n• Use sunscreen';
      default:
        return 'Consult a dermatologist';
    }
  }

  // Function to get icon
  IconData _getIcon(String skinType) {
    switch (skinType.toLowerCase()) {
      case 'dry':
        return Icons.water_drop;
      case 'oily':
        return Icons.opacity;
      case 'normal':
        return Icons.thumb_up;
      default:
        return Icons.help;
    }
  }

  // Function to get color
  Color _getColor(String skinType) {
    switch (skinType.toLowerCase()) {
      case 'dry':
        return Colors.orange;
      case 'oily':
        return Colors.green;
      case 'normal':
        return Colors.blue;
      default:
        return Colors.grey;
    }
  }

  // دالة لاستخراج المشاكل
  List<String> _extractProblems(String skinType, Map<String, dynamic> prediction) {
    final problems = <String>{};
    final skinTypeLower = skinType.toLowerCase();

    if (skinTypeLower.contains('oily')) problems.add('Oiliness');
    if (skinTypeLower.contains('dry')) problems.add('Dryness');
    if (skinTypeLower.contains('sensitive')) problems.add('Sensitivity');
    if (skinTypeLower.contains('combination')) {
      problems.add('Combination Skin');
      problems.add('Oily T-zone');
    }

    // إضافة مشاكل بناءً على الثقة
    final confidence = prediction['confidence'] ?? 0.0;
    if (confidence < 0.7) {
      problems.add('Low Confidence Analysis');
    }

    return problems.toList();
  }

  // دالة لاستخراج المخاوف
  Map<String, double> _extractConcerns(Map<String, dynamic> prediction) {
    final Map<String, double> concerns = {};
    final allResults = prediction['allResults'] as Map<String, double>?;

    if (allResults != null) {
      allResults.forEach((key, value) {
        if (value > 0.2) {
          concerns[key.toLowerCase()] = value;
        }
      });
    }

    return concerns;
  }

  // دالة لتحويل الصورة إلى Base64
  String? _convertImageToBase64() {
    try {
      final imageFile = File(imagePath);
      if (!imageFile.existsSync()) return null;

      final imageBytes = imageFile.readAsBytesSync();
      // تحقق من حجم الصورة
      if (imageBytes.length > 5 * 1024 * 1024) { // أكبر من 5MB
        print('⚠️ Image is too large, skipping base64 encoding');
        return null;
      }
      return base64Encode(imageBytes);
    } catch (e) {
      print('❌ Error converting image to base64: $e');
      return null;
    }
  }

  // دالة لتوليد توصيات المنتجات
  List<String> _generateProductRecommendations(String skinType) {
    switch (skinType.toLowerCase()) {
      case 'dry':
        return [
          'Rich moisturizer with ceramides',
          'Hyaluronic acid serum',
          'Gentle cream cleanser',
          'SPF 30+ sunscreen'
        ];
      case 'oily':
        return [
          'Oil-free cleanser with salicylic acid',
          'Non-comedogenic moisturizer',
          'Matte sunscreen',
          'Clay mask for oil control'
        ];
      case 'normal':
        return [
          'Gentle pH-balanced cleanser',
          'Lightweight moisturizer',
          'Antioxidant serum',
          'Broad-spectrum SPF'
        ];
      default:
        return ['Gentle cleanser', 'Daily moisturizer', 'Sunscreen SPF 30+'];
    }
  }

  // دالة واحدة لحفظ التحليل
  Future<SkinAnalysis> _saveAnalysis(BuildContext context) async {
    final predictedClass = prediction['predictedClass'];
    final confidence = prediction['confidence'];

    // إنشاء كائن SkinAnalysis
    final analysis = SkinAnalysis(
      id: 'analysis_${DateTime.now().millisecondsSinceEpoch}',
      date: DateTime.now(),
      skinType: predictedClass,
      concerns: _extractConcerns(prediction),
      confidence: confidence,
      problems: _extractProblems(predictedClass, prediction),
      imageUrl: null,
      imageBase64: _convertImageToBase64(),
      productRecommendations: _generateProductRecommendations(predictedClass),
      metadata: {
        'analysisMethod': 'face_analysis',
        'confidenceScore': confidence,
        'timestamp': DateTime.now().millisecondsSinceEpoch,
      },
      targetArea: 'Face',
    );

    try {
      final skinProvider = Provider.of<SkinTypeProvider>(context, listen: false);

      // 1. حفظ في Provider (للبروفايل)
      await skinProvider.setSkinType(
        predictedClass,
        problems: analysis.problems,
        confidence: confidence,
      );

      // 2. حفظ في AnalysisHistoryService
      final historyService = AnalysisHistoryService();
      await historyService.saveAnalysis(analysis);

      print('✅ Analysis saved successfully: $predictedClass');
      return analysis;
    } catch (e) {
      print('❌ Error saving analysis: $e');
      rethrow;
    }
  }

  @override
  Widget build(BuildContext context) {
    final predictedClass = prediction['predictedClass'];
    final confidence = prediction['confidence'];
    final sortedResults = prediction['sortedResults'];

    // حفظ التحليل مرة واحدة فقط
    bool isSaved = false;

    WidgetsBinding.instance.addPostFrameCallback((_) async {
      if (!isSaved && _cachedAnalysis == null) {
        try {
          await _saveAnalysis(context);
          isSaved = true;
        } catch (e) {
          // يمكن إضافة رسالة خطأ للمستخدم
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Failed to save analysis'),
              backgroundColor: Colors.red,
            ),
          );
        }
      }
    });

    return Scaffold(
      appBar: AppBar(
        title: Text('Analysis Results'),
        centerTitle: true,
        actions: [
          IconButton(
            icon: Icon(Icons.history),
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => SkinHistoryScreen(),
                ),
              );
            },
            tooltip: 'View History',
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // رسالة تأكيد الحفظ
            if (_cachedAnalysis == null)
              Container(
                padding: EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: Colors.green[50],
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.green.shade100),
                ),
                child: Row(
                  children: [
                    Icon(Icons.check_circle, color: Colors.green, size: 16),
                    SizedBox(width: 8),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Results saved to your profile',
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.bold,
                              color: Colors.green[800],
                            ),
                          ),
                          SizedBox(height: 2),
                          Text(
                            'View your history in Profile → Face Analysis History',
                            style: TextStyle(
                              fontSize: 10,
                              color: Colors.green[600],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            if (_cachedAnalysis == null) SizedBox(height: 20),

            // Image
            if (File(imagePath).existsSync())
              Container(
                height: 200,
                width: double.infinity,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(15),
                  image: DecorationImage(
                    image: FileImage(File(imagePath)),
                    fit: BoxFit.cover,
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black26,
                      blurRadius: 10,
                      offset: Offset(0, 5),
                    ),
                  ],
                ),
              ),
            SizedBox(height: 30),

            // Main Result
            Card(
              color: _getColor(predictedClass).withOpacity(0.1),
              child: Padding(
                padding: EdgeInsets.all(20),
                child: Row(
                  children: [
                    Icon(
                      _getIcon(predictedClass),
                      size: 50,
                      color: _getColor(predictedClass),
                    ),
                    SizedBox(width: 20),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Your skin type is:',
                            style: TextStyle(
                              fontSize: 16,
                              color: Colors.grey,
                            ),
                          ),
                          Text(
                            predictedClass.toUpperCase(),
                            style: TextStyle(
                              fontSize: 28,
                              fontWeight: FontWeight.bold,
                              color: _getColor(predictedClass),
                            ),
                          ),
                          SizedBox(height: 5),
                          Text(
                            'Confidence ${(confidence * 100).toStringAsFixed(1)}%',
                            style: TextStyle(
                              fontSize: 16,
                              color: Colors.grey[700],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
            SizedBox(height: 20),

            // Confidence Bar
            Container(
              height: 20,
              width: double.infinity,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(10),
                color: Colors.grey[200],
              ),
              child: FractionallySizedBox(
                alignment: Alignment.centerLeft,
                widthFactor: confidence,
                child: Container(
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(10),
                    color: _getColor(predictedClass),
                  ),
                ),
              ),
            ),
            SizedBox(height: 10),
            Align(
              alignment: Alignment.center,
              child: Text(
                'Confidence level: ${(confidence * 100).toStringAsFixed(1)}%',
                style: TextStyle(fontSize: 14, color: Colors.grey),
              ),
            ),
            SizedBox(height: 30),

            // All Results
            Text(
              'All Probabilities:',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
            SizedBox(height: 10),
            ...sortedResults.map((entry) => Padding(
              padding: EdgeInsets.symmetric(vertical: 8),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      entry.key,
                      style: TextStyle(fontSize: 16),
                    ),
                  ),
                  Container(
                    width: 100,
                    height: 10,
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(5),
                      color: Colors.grey[200],
                    ),
                    child: FractionallySizedBox(
                      alignment: Alignment.centerLeft,
                      widthFactor: entry.value,
                      child: Container(
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(5),
                          color: _getColor(entry.key),
                        ),
                      ),
                    ),
                  ),
                  SizedBox(width: 10),
                  Text(
                    '${(entry.value * 100).toStringAsFixed(1)}%',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
            )),
            SizedBox(height: 30),

            // Recommendations
            Card(
              child: Padding(
                padding: EdgeInsets.all(20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(Icons.lightbulb, color: Colors.amber),
                        SizedBox(width: 10),
                        Text(
                          'Recommendations:',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                    SizedBox(height: 15),
                    Text(
                      _getRecommendation(predictedClass),
                      style: TextStyle(fontSize: 16, height: 1.5),
                    ),
                  ],
                ),
              ),
            ),

            // زر للذهاب إلى التاريخ
            SizedBox(height: 20),
            ElevatedButton.icon(
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => SkinHistoryScreen(),
                  ),
                );
              },
              icon: Icon(Icons.history),
              label: Text('View Analysis History'),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.purple,
                foregroundColor: Colors.white,
                minimumSize: Size(double.infinity, 50),
              ),
            ),
            SizedBox(height: 20),
          ],
        ),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => Navigator.pop(context),
        icon: Icon(Icons.refresh),
        label: Text('New Analysis'),
        backgroundColor: Colors.blue,
      ),
    );
  }
}