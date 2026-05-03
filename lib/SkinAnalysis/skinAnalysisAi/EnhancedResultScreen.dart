/*import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:skinglow/SkinAnalysis/skin_type_provider.dart';
import 'package:skinglow/Screens/Home.dart';

class EnhancedResultScreen extends StatefulWidget {
  final Map<String, dynamic> prediction;
  final String imagePath;
  final List<File>? additionalImages;

  EnhancedResultScreen({
    required this.prediction,
    required this.imagePath,
    this.additionalImages,
  });

  @override
  _EnhancedResultScreenState createState() => _EnhancedResultScreenState();
}

class _EnhancedResultScreenState extends State<EnhancedResultScreen> {
  bool _isSaving = false;
  bool _savedToProfile = false;
  String? _savedSkinType;

  @override
  void initState() {
    super.initState();
    // حفظ النتائج عند فتح الصفحة
    _saveToProfile();
  }

  Future<void> _saveToProfile() async {
    if (_isSaving || _savedToProfile) return;

    setState(() => _isSaving = true);

    try {
      final skinProvider = context.read<SkinTypeProvider>();
      final predictedClass = widget.prediction['predictedClass'];
      final confidence = widget.prediction['confidence'] ?? 0.0;

      // استخراج المشاكل من النتائج
      List<String> problems = _extractProblems(predictedClass, widget.prediction);

      // حفظ في Provider
      await skinProvider.setSkinType(
        predictedClass,
        problems: problems,
        confidence: confidence,
      );

      setState(() {
        _savedToProfile = true;
        _savedSkinType = predictedClass;
        _isSaving = false;
      });

      print('✅ Analysis saved to profile: $predictedClass');

    } catch (e) {
      print('❌ Error saving to profile: $e');
      setState(() => _isSaving = false);
    }
  }

  List<String> _extractProblems(String skinType, Map<String, dynamic> prediction) {
    final problems = <String>[];
    final skinTypeLower = skinType.toLowerCase();

    // إضافة مشاكل بناءً على نوع البشرة
    if (skinTypeLower.contains('oily')) problems.add('Oiliness');
    if (skinTypeLower.contains('dry')) problems.add('Dryness');
    if (skinTypeLower.contains('sensitive')) problems.add('Sensitivity');
    if (skinTypeLower.contains('combination')) {
      problems.add('Combination Skin');
      problems.add('Oily T-zone');
    }

    // يمكن إضافة مزيد من المنطق بناءً على الثقة أو النتائج الأخرى
    final allResults = widget.prediction['allResults'] as Map<String, double>?;
    if (allResults != null) {
      // إضافة مشاكل إذا كانت احتمالية عالية
      allResults.forEach((key, value) {
        if (value > 0.3 && !key.toLowerCase().contains('normal')) {
          problems.add(key);
        }
      });
    }

    // إزالة التكرارات
    return problems.toSet().toList();
  }

  // Function to get recommendations based on skin type
  String _getRecommendation(String skinType) {
    switch (skinType.toLowerCase()) {
      case 'dry':
        return '• Use rich moisturizers\n• Drink plenty of water\n• Avoid harsh soaps';
      case 'oily':
        return '• Use gentle cleansers\n• Avoid oily products\n• Use oil-free sunscreen';
      case 'normal':
        return '• Maintain a simple routine\n• Use daily moisturizer\n• Use sunscreen';
      case 'combination':
        return '• Use different products for T-zone and cheeks\n• Balance oil production\n• Hydrate dry areas';
      case 'sensitive':
        return '• Use fragrance-free products\n• Patch test new products\n• Avoid harsh chemicals';
      default:
        return 'Consult a dermatologist for personalized advice';
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
      case 'combination':
        return Icons.merge;
      case 'sensitive':
        return Icons.health_and_safety;
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
      case 'combination':
        return Colors.purple;
      case 'sensitive':
        return Colors.pink;
      default:
        return Colors.grey;
    }
  }

  Widget _buildSaveStatus() {
    if (_isSaving) {
      return Container(
        padding: EdgeInsets.all(16),
        margin: EdgeInsets.only(bottom: 16),
        decoration: BoxDecoration(
          color: Colors.blue[50],
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Colors.lightBlueAccent),
        ),
        child: Row(
          children: [
            CircularProgressIndicator(strokeWidth: 2, valueColor: AlwaysStoppedAnimation<Color>(Colors.blue)),
            SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Saving to Your Profile...',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      color: Colors.blue[800],
                    ),
                  ),
                  SizedBox(height: 4),
                  Text(
                    'Your results will be available in your profile',
                    style: TextStyle(
                      fontSize: 12,
                      color: Colors.blue[600],
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      );
    }

    if (_savedToProfile) {
      return Container(
        padding: EdgeInsets.all(16),
        margin: EdgeInsets.only(bottom: 16),
        decoration: BoxDecoration(
          color: Colors.green[50],
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Colors.greenAccent),
        ),
        child: Row(
          children: [
            Icon(Icons.check_circle, color: Colors.green, size: 24),
            SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Saved to Your Profile!',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      color: Colors.green[800],
                    ),
                  ),
                  SizedBox(height: 4),
                  Text(
                    'Your skin type ($_savedSkinType) is now available in your profile',
                    style: TextStyle(
                      fontSize: 12,
                      color: Colors.green[600],
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      );
    }

    return SizedBox();
  }

  Widget _buildGoToProfileButton() {
    return Container(
      margin: EdgeInsets.symmetric(vertical: 16),
      child: ElevatedButton.icon(
        onPressed: () {
          Navigator.pushAndRemoveUntil(
            context,
            MaterialPageRoute(builder: (context) => Home()),
                (route) => false,
          );
        },
        icon: Icon(Icons.person),
        label: Text('View in Profile'),
        style: ElevatedButton.styleFrom(
          backgroundColor: _getColor(widget.prediction['predictedClass']),
          foregroundColor: Colors.white,
          padding: EdgeInsets.symmetric(vertical: 16, horizontal: 24),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final predictedClass = widget.prediction['predictedClass'];
    final confidence = widget.prediction['confidence'];
    final allResults = widget.prediction['allResults'] as Map<String, double>?;
    final sortedResults = widget.prediction['sortedResults'];

    return Scaffold(
      appBar: AppBar(
        title: Text('Analysis Results'),
        centerTitle: true,
        actions: [
          IconButton(
            icon: Icon(Icons.person),
            onPressed: () {
              Navigator.pushAndRemoveUntil(
                context,
                MaterialPageRoute(builder: (context) => Home()),
                    (route) => false,
              );
            },
            tooltip: 'Go to Profile',
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // حالة الحفظ
            _buildSaveStatus(),

            // Image
            Container(
              height: 200,
              width: double.infinity,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(15),
                image: DecorationImage(
                  image: FileImage(File(widget.imagePath)),
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
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
              elevation: 4,
              child: Padding(
                padding: EdgeInsets.all(20),
                child: Row(
                  children: [
                    Container(
                      padding: EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: _getColor(predictedClass),
                        shape: BoxShape.circle,
                      ),
                      child: Icon(
                        _getIcon(predictedClass),
                        size: 40,
                        color: Colors.white,
                      ),
                    ),
                    SizedBox(width: 20),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Your Skin Type',
                            style: TextStyle(
                              fontSize: 14,
                              color: Colors.grey[600],
                            ),
                          ),
                          Text(
                            predictedClass.toUpperCase(),
                            style: TextStyle(
                              fontSize: 32,
                              fontWeight: FontWeight.bold,
                              color: _getColor(predictedClass),
                            ),
                          ),
                          SizedBox(height: 8),
                          Text(
                            'Confidence: ${(confidence * 100).toStringAsFixed(1)}%',
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
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'Confidence Level',
                      style: TextStyle(
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    Text(
                      '${(confidence * 100).toStringAsFixed(1)}%',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        color: confidence > 0.7 ? Colors.green : Colors.orange,
                      ),
                    ),
                  ],
                ),
                SizedBox(height: 8),
                Container(
                  height: 10,
                  width: double.infinity,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(5),
                    color: Colors.grey[200],
                  ),
                  child: FractionallySizedBox(
                    alignment: Alignment.centerLeft,
                    widthFactor: confidence,
                    child: Container(
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(5),
                        gradient: LinearGradient(
                          colors: confidence > 0.7
                              ? [Colors.green, Colors.greenAccent]
                              : [Colors.orange, Colors.orangeAccent],
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
            SizedBox(height: 30),

            // All Results
            if (allResults != null && allResults.isNotEmpty)
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Detailed Analysis:',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  SizedBox(height: 12),
                  ...allResults.entries.map((entry) {
                    final probability = entry.value;
                    return Padding(
                      padding: EdgeInsets.symmetric(vertical: 6),
                      child: Row(
                        children: [
                          Expanded(
                            child: Text(
                              entry.key,
                              style: TextStyle(fontSize: 15),
                            ),
                          ),
                          Container(
                            width: 100,
                            height: 8,
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(4),
                              color: Colors.grey[200],
                            ),
                            child: FractionallySizedBox(
                              alignment: Alignment.centerLeft,
                              widthFactor: probability,
                              child: Container(
                                decoration: BoxDecoration(
                                  borderRadius: BorderRadius.circular(4),
                                  color: entry.key == predictedClass
                                      ? _getColor(entry.key)
                                      : Colors.grey[400],
                                ),
                              ),
                            ),
                          ),
                          SizedBox(width: 12),
                          Text(
                            '${(probability * 100).toStringAsFixed(1)}%',
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight: entry.key == predictedClass
                                  ? FontWeight.bold
                                  : FontWeight.normal,
                            ),
                          ),
                        ],
                      ),
                    );
                  }).toList(),
                  SizedBox(height: 30),
                ],
              ),

            // Recommendations
            Card(
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
              elevation: 3,
              child: Padding(
                padding: EdgeInsets.all(20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(Icons.spa, color: _getColor(predictedClass)),
                        SizedBox(width: 10),
                        Text(
                          'Care Recommendations:',
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
                      style: TextStyle(
                        fontSize: 16,
                        height: 1.6,
                        color: Colors.grey[700],
                      ),
                    ),
                  ],
                ),
              ),
            ),

            // زر الذهاب إلى البروفايل
            _buildGoToProfileButton(),

            SizedBox(height: 20),
          ],
        ),
      ),
      bottomNavigationBar: Container(
        padding: EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          boxShadow: [
            BoxShadow(
              color: Colors.black12,
              blurRadius: 10,
              offset: Offset(0, -5),
            ),
          ],
        ),
        child: Row(
          children: [
            Expanded(
              child: OutlinedButton.icon(
                onPressed: () {
                  Navigator.pop(context);
                },
                icon: Icon(Icons.refresh),
                label: Text('New Analysis'),
                style: OutlinedButton.styleFrom(
                  padding: EdgeInsets.symmetric(vertical: 14),
                  side: BorderSide(color: _getColor(predictedClass)),
                ),
              ),
            ),
            SizedBox(width: 12),
            Expanded(
              child: ElevatedButton.icon(
                onPressed: () {
                  Navigator.pushAndRemoveUntil(
                    context,
                    MaterialPageRoute(builder: (context) => Home()),
                        (route) => false,
                  );
                },
                icon: Icon(Icons.home),
                label: Text('Go to Home'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: _getColor(predictedClass),
                  foregroundColor: Colors.white,
                  padding: EdgeInsets.symmetric(vertical: 14),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

 */
