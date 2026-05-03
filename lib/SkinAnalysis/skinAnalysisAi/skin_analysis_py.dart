import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:skinglow/SkinAnalysis/skinAnalysisAi/result_screen.dart';
import 'package:skinglow/SkinAnalysis/skinAnalysisAi/SmartSkinClassifier.dart';

import 'EnhancedResultScreen.dart';

class SkinAnalysisPy extends StatefulWidget {
  @override
  _SkinAnalysisPyState createState() => _SkinAnalysisPyState();
}

class _SkinAnalysisPyState extends State<SkinAnalysisPy> {
  final SmartSkinClassifier _classifier = SmartSkinClassifier(); // تغيير الاسم
  final ImagePicker _picker = ImagePicker();
  bool _isLoading = false;
  String _status = 'Ready';
  String _debugInfo = '';

  @override
  void initState() {
    super.initState();
    _initializeClassifier(); // تغيير اسم الدالة
  }

  Future<void> _initializeClassifier() async { // دالة جديدة
    setState(() {
      _status = 'Initializing AI...';
      _debugInfo = 'Starting initialization...';
    });

    try {
      await _classifier.initialize(); // ✅ استخدم initialize() بدلاً من loadModel()
      setState(() {
        _status = 'AI Ready ✓';
        _debugInfo = 'Smart skin classifier initialized successfully';
      });
    } catch (e) {
      setState(() {
        _status = 'Error initializing AI';
        _debugInfo = 'Error: $e\n\nPossible issues:\n1. Model file not found\n2. Labels file missing\n3. TensorFlow Lite compatibility issue';
      });
      print('❌ Initialize error: $e');
    }
  }

  Future<void> _pickImage(ImageSource source) async {
    setState(() {
      _isLoading = true;
      _status = 'Selecting image...';
      _debugInfo = 'Opening image picker...';
    });

    try {
      final pickedFile = await _picker.pickImage(
        source: source,
        maxWidth: 1000,
        maxHeight: 1000,
        imageQuality: 85,
      );

      if (pickedFile != null) {
        setState(() {
          _status = 'Processing image...';
          _debugInfo = 'Image selected: ${pickedFile.path}\nFile size: ${File(pickedFile.path).lengthSync()} bytes';
        });

        final imageFile = File(pickedFile.path);

        // التحقق من الملف
        if (!await imageFile.exists()) {
          setState(() {
            _status = 'File not found';
            _debugInfo = 'The image file does not exist';
          });
          return;
        }

        final fileSize = await imageFile.length();
        if (fileSize == 0) {
          setState(() {
            _status = 'Empty file';
            _debugInfo = 'The image file is empty (0 bytes)';
          });
          return;
        }

        try {
          setState(() {
            _status = 'Analyzing skin...';
            _debugInfo = 'Running smart skin analysis...';
          });

          final result = await _classifier.classifyImage(imageFile); // ✅ هذه تعمل

          setState(() {
            _debugInfo = 'Analysis complete!\nResult: ${result['predictedClass']} '
                '(${(result['confidence'] * 100).toStringAsFixed(1)}% confidence)';
          });

          // الانتقال لشاشة النتائج
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => ResultScreen(
                prediction: result,
                imagePath: pickedFile.path,
              ),
            ),
          );

        } catch (e) {
          setState(() {
            _status = 'Analysis failed';
            _debugInfo = 'Error during analysis: $e\n\nPlease try another image or check camera permissions';
          });
          print('❌ Analysis error: $e');
        }
      } else {
        setState(() {
          _status = 'No image selected';
          _debugInfo = 'User cancelled or no image selected';
        });
      }
    } catch (e) {
      setState(() {
        _status = 'Error selecting image';
        _debugInfo = 'Picker error: $e\n\nCheck camera/gallery permissions';
      });
      print('❌ Picker error: $e');
    } finally {
      setState(() {
        _isLoading = false;
        _status = 'Ready';
      });
    }
  }

  // ✅ أضف دالة retrainModel هنا
  Future<void> _retrainModel() async {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Help Improve AI'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text('Contribute to make skin analysis better!'),
            SizedBox(height: 15),
            ListTile(
              leading: Icon(Icons.photo_camera, color: Colors.blue),
              title: Text('Take diverse photos'),
              subtitle: Text('Different angles & lighting'),
            ),
            ListTile(
              leading: Icon(Icons.feedback, color: Colors.green),
              title: Text('Provide accuracy feedback'),
              subtitle: Text('Help train the AI'),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('Later'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              _startContribution();
            },
            child: Text('Start Contributing'),
          ),
        ],
      ),
    );
  }

  void _startContribution() {
    // يمكنك إضافة منطق المساهمة هنا
    print('Starting contribution process...');
    // مثال: فتح صفحة المساهمة
    // Navigator.pushNamed(context, '/contribution');
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Skin Type Classifier'),
        centerTitle: true,
        actions: [
          /*IconButton(
            icon: Icon(Icons.info),
            onPressed: () {
              showDialog(
                context: context,
                builder: (context) => AlertDialog(
                  title: Text('Debug Information'),
                  content: SingleChildScrollView(
                    child: Text(_debugInfo),
                  ),
                  actions: [
                    TextButton(
                      onPressed: () => Navigator.pop(context),
                      child: Text('Close'),
                    ),
                  ],
                ),
              );
            },
          ),*/
        ],
      ),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(20.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.face, size: 100, color: Colors.blue),
              SizedBox(height: 20),
              Text(
                'Discover Your Skin Type',
                style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
              ),
              SizedBox(height: 10),
              /*Container(
                padding: EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: _status.contains('Error') ? Colors.red[50] : Colors.green[50],
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(
                    color: _status.contains('Error') ? Colors.red : Colors.green,
                  ),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      _status.contains('Error') ? Icons.error : Icons.check_circle,
                      color: _status.contains('Error') ? Colors.red : Colors.green,
                    ),
                    SizedBox(width: 10),
                    Text(
                      _status,
                      style: TextStyle(
                        fontSize: 16,
                        color: _status.contains('Error') ? Colors.red : Colors.green,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
              ),*/
              /*
              SizedBox(height: 20),

              if (_debugInfo.isNotEmpty && _debugInfo.contains('Error'))
                Container(
                  padding: EdgeInsets.all(12),
                  margin: EdgeInsets.only(bottom: 20),
                  decoration: BoxDecoration(
                    color: Colors.orange[50],
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: Colors.orange),
                  ),
                  child: Column(
                    children: [
                      Text(
                        '⚠️ Troubleshooting',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          color: Colors.orange[800],
                        ),
                      ),
                      SizedBox(height: 5),
                      Text(
                        'Tap the info button in app bar for details',
                        style: TextStyle(fontSize: 12),
                      ),
                    ],
                  ),
                ),
*/
              SizedBox(height: 20),

              if (_isLoading)
                Column(
                  children: [
                    CircularProgressIndicator(),
                    SizedBox(height: 20),
                    Text(
                      'Please wait...',
                      style: TextStyle(color: Colors.grey),
                    ),
                  ],
                )
              else
                Column(
                  children: [
                    ElevatedButton.icon(
                      onPressed: () => _pickImage(ImageSource.camera),
                      icon: Icon(Icons.camera_alt),
                      label: Text('Take Photo'),
                      style: ElevatedButton.styleFrom(
                        padding: EdgeInsets.symmetric(horizontal: 30, vertical: 15),
                        minimumSize: Size(250, 50),
                      ),
                    ),
                    SizedBox(height: 20),
                    OutlinedButton.icon(
                      onPressed: () => _pickImage(ImageSource.gallery),
                      icon: Icon(Icons.photo_library),
                      label: Text('Choose from Gallery'),
                      style: OutlinedButton.styleFrom(
                        padding: EdgeInsets.symmetric(horizontal: 30, vertical: 15),
                        minimumSize: Size(250, 50),
                      ),
                    ),
                    SizedBox(height: 30),
/*
                    // زر المساعدة في تحسين النموذج
                    Card(
                      child: ListTile(
                        leading: Icon(Icons.refresh, color: Colors.orange),
                        title: Text('Help Improve AI'),
                        subtitle: Text('Contribute photos to make model smarter'),
                        trailing: Icon(Icons.arrow_forward),
                        onTap: _retrainModel,
                      ),
                    ),
                    SizedBox(height: 10),

                    // زر Debug (احتفظ به)
                    TextButton.icon(
                      onPressed: () {
                        showDialog(
                          context: context,
                          builder: (context) => AlertDialog(
                            title: Text('Debug Info'),
                            content: SingleChildScrollView(
                              child: Text(_debugInfo),
                            ),
                            actions: [
                              TextButton(
                                onPressed: () => Navigator.pop(context),
                                child: Text('Close'),
                              ),
                              TextButton(
                                onPressed: () {
                                  _initializeClassifier(); // ✅ تغيير هنا أيضاً
                                  Navigator.pop(context);
                                },
                                child: Text('Re-initialize AI'),
                              ),
                            ],
                          ),
                        );
                      },
                      icon: Icon(Icons.bug_report, size: 16),
                      label: Text('Show Debug Info'),
                    ),*/
                  ],
                ),
            ],
          ),
        ),
      ));
/*
      // ✅ أو أضف FAB هكذا (اختياري)
      floatingActionButton: FloatingActionButton(
        onPressed: _retrainModel,
        child: Icon(Icons.refresh),
        tooltip: 'Help improve AI',
        backgroundColor: Colors.orange,
      ),
      floatingActionButtonLocation: FloatingActionButtonLocation.endFloat,
    );*/
  }

  @override
  void dispose() {
    _classifier.dispose();
    super.dispose();
  }
}