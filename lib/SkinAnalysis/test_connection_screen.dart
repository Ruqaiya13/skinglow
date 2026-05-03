// إنشاء ملف جديد: test_connection_screen.dart
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:skinglow/SkinAnalysis/analysis_history_service.dart';
import 'package:skinglow/SkinAnalysis/skin_analysis.dart';

class TestConnectionScreen extends StatefulWidget {
  @override
  _TestConnectionScreenState createState() => _TestConnectionScreenState();
}

class _TestConnectionScreenState extends State<TestConnectionScreen> {
  final AnalysisHistoryService _historyService = AnalysisHistoryService();
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseDatabase _database = FirebaseDatabase.instance;

  String _status = 'Testing...';
  List<String> _logs = [];
  bool _isTesting = false;

  void _log(String message) {
    print('🔍 $message');
    setState(() {
      _logs.add('${DateTime.now().toString().substring(11, 19)}: $message');
    });
  }

  Future<void> _runTests() async {
    setState(() {
      _isTesting = true;
      _logs.clear();
    });

    _log('Starting connection tests...');

    try {
      // 1. اختبار الاتصال بـ Firebase Auth
      _log('1. Testing Firebase Auth...');
      final user = _auth.currentUser;
      if (user != null) {
        _log('✅ User logged in: ${user.email} (${user.uid})');
      } else {
        _log('❌ No user logged in');
        setState(() => _status = 'Please log in first');
        return;
      }

      // 2. اختبار الاتصال بـ Firebase Database
      _log('2. Testing Firebase Database...');
      try {
        await _database.ref('.info/connected').get();
        _log('✅ Firebase Database connected');
      } catch (e) {
        _log('❌ Firebase Database error: $e');
      }

      // 3. اختبار AnalysisHistoryService
      _log('3. Testing AnalysisHistoryService...');
      try {
        await _historyService.testFirebaseConnection();
        _log('✅ AnalysisHistoryService connected');
      } catch (e) {
        _log('❌ AnalysisHistoryService error: $e');
      }

      // 4. اختبار التخزين المحلي
      _log('4. Testing local storage...');
      try {
        final prefs = await SharedPreferences.getInstance();
        await prefs.setString('test_key', 'test_value');
        final value = prefs.getString('test_key');
        if (value == 'test_value') {
          _log('✅ Local storage working');
          await prefs.remove('test_key');
        }
      } catch (e) {
        _log('❌ Local storage error: $e');
      }

      // 5. اختبار جلب التحليلات
      _log('5. Testing get analyses...');
      try {
        final analyses = await _historyService.getAllAnalyses();
        _log('✅ Found ${analyses.length} analyses');

        if (analyses.isNotEmpty) {
          for (var analysis in analyses.take(3)) {
            _log('   - ${analysis.date}: ${analysis.skinType} (${analysis.targetArea})');
          }
        }
      } catch (e) {
        _log('❌ Get analyses error: $e');
      }

      // 6. اختبار حفظ تحليل جديد
      _log('6. Testing save analysis...');
      try {
        final testAnalysis = SkinAnalysis(
          id: 'test_${DateTime.now().millisecondsSinceEpoch}',
          date: DateTime.now(),
          skinType: 'Normal',
          concerns: {'test': 0.5},
          confidence: 0.9,
          problems: ['Test problem'],
          imageUrl: null,
          imageBase64: null,
          productRecommendations: ['Test product'],
          metadata: {'test': true},
          targetArea: 'Test area',
        );

        await _historyService.saveAnalysis(testAnalysis);
        _log('✅ Test analysis saved successfully');

        // حذف التحليل التجريبي بعد التأكد من حفظه
        await Future.delayed(Duration(seconds: 2));
        await _historyService.deleteAnalysis(testAnalysis.id);
        _log('✅ Test analysis cleaned up');

      } catch (e) {
        _log('❌ Save analysis error: $e');
      }

      _log('All tests completed!');
      setState(() => _status = 'Tests completed successfully');

    } catch (e) {
      _log('❌ Test suite failed: $e');
      setState(() => _status = 'Tests failed: ${e.toString()}');
    } finally {
      setState(() => _isTesting = false);
    }
  }

  Future<void> _clearAllData() async {
    try {
      setState(() => _isTesting = true);
      _log('Clearing all data...');

      final user = _auth.currentUser;
      if (user != null) {
        await _database.ref('users/${user.uid}/skinAnalyses').remove();
        _log('✅ Cleared Firebase data');
      }

      final prefs = await SharedPreferences.getInstance();
      await prefs.remove('localAnalyses');
      await prefs.remove('skinType');
      await prefs.remove('skinProblems');
      await prefs.remove('skinConfidence');
      await prefs.remove('analysisHistory');
      _log('✅ Cleared local storage');

      _log('Data cleared successfully');
    } catch (e) {
      _log('❌ Error clearing data: $e');
    } finally {
      setState(() => _isTesting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Connection Test'),
        actions: [
          IconButton(
            icon: Icon(Icons.refresh),
            onPressed: _runTests,
          ),
        ],
      ),
      body: Column(
        children: [
          Padding(
            padding: EdgeInsets.all(16),
            child: Card(
              child: Padding(
                padding: EdgeInsets.all(16),
                child: Column(
                  children: [
                    Text(
                      'Status: $_status',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        color: _status.contains('✅') ? Colors.green :
                        _status.contains('❌') ? Colors.red : Colors.blue,
                      ),
                    ),
                    SizedBox(height: 20),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                      children: [
                        ElevatedButton.icon(
                          onPressed: _isTesting ? null : _runTests,
                          icon: Icon(Icons.play_arrow),
                          label: Text('Run Tests'),
                        ),
                        ElevatedButton.icon(
                          onPressed: _isTesting ? null : _clearAllData,
                          icon: Icon(Icons.delete),
                          label: Text('Clear Data'),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.red,
                            foregroundColor: Colors.white,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ),
          Expanded(
            child: ListView.builder(
              itemCount: _logs.length,
              itemBuilder: (context, index) {
                final log = _logs[index];
                return ListTile(
                  title: Text(log),
                  tileColor: log.contains('✅') ? Colors.green[50] :
                  log.contains('❌') ? Colors.red[50] :
                  log.contains('⚠️') ? Colors.orange[50] : null,
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}