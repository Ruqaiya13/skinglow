import 'dart:convert';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:intl/intl.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:skinglow/SkinAnalysis/skin_analysis.dart';

class AnalysisHistoryService {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseDatabase _database = FirebaseDatabase.instance;
  SkinAnalysis? _lastSavedAnalysis;
  // Save new analysis
  Future<void> saveAnalysis(SkinAnalysis analysis) async {
    try {
      print('💾 Starting to save analysis: ${analysis.id}');

      final user = _auth.currentUser;
      if (user == null) throw Exception('User not logged in');

      // 1. التحقق من وجود ID
      String analysisId = analysis.id;
      if (analysisId.isEmpty) {
        analysisId = 'analysis_${DateTime.now().millisecondsSinceEpoch}';
        print('📝 Generated new ID: $analysisId');
      }

      // 2. تحديث الـ SkinAnalysis مع الـ ID الجديد
      final updatedAnalysis = SkinAnalysis(
        id: analysisId,
        date: analysis.date,
        skinType: analysis.skinType,
        concerns: analysis.concerns,
        confidence: analysis.confidence,
        problems: analysis.problems,
        imageUrl: analysis.imageUrl,
        imageBase64: analysis.imageBase64,
        productRecommendations: analysis.productRecommendations,
        metadata: {
          ...analysis.metadata,
          'savedAt': DateTime.now().toIso8601String(),
          'userId': user.uid,
        },
        targetArea: analysis.targetArea,
      );

      // 3. حفظ في Firebase
      final analysesRef = _database.ref('users/${user.uid}/skinAnalyses');
      await analysesRef.child(analysisId).set(updatedAnalysis.toJson());
      print('✅ Saved to Firebase: users/${user.uid}/skinAnalyses/$analysisId');

      // 4. تحديث آخر تحليل في المستخدم
      await _database.ref('users/${user.uid}').update({
        'lastAnalysis': updatedAnalysis.toJson(),
        'lastAnalysisDate': DateTime.now().millisecondsSinceEpoch,
        'updatedAt': ServerValue.timestamp,
      });
      print('✅ Updated last analysis reference');

      // 5. حفظ محلياً
      await _saveLocally(updatedAnalysis);
      print('✅ Saved locally');

      // 6. تحديث الإحصائيات
      await _updateUserStatistics(user.uid, updatedAnalysis);
      print('✅ Updated statistics');

      // 7. تحديث المتغير المحلي
      _lastSavedAnalysis = updatedAnalysis;

      print('🎉 Analysis saved successfully: $analysisId');

    } catch (e) {
      print('❌ Error in saveAnalysis: $e');
      print('Stack trace: ${e.toString()}');

      // محاولة الحفظ المحلي فقط في حالة الفشل
      try {
        await _saveLocally(analysis);
        print('✅ Saved locally as backup');
      } catch (localError) {
        print('❌ Failed to save locally too: $localError');
      }
      rethrow;
    }
  }

// تعديل دالة _saveLocally
  Future<void> _saveLocally(SkinAnalysis analysis) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      List<String> analysesJson = prefs.getStringList('localAnalyses') ?? [];

      // إزالة التحليلات القديمة بنفس الـ ID إن وجدت
      analysesJson = analysesJson.where((json) {
        try {
          final existing = SkinAnalysis.fromJson(jsonDecode(json));
          return existing.id != analysis.id;
        } catch (e) {
          return true; // إبقاء الـ JSON التالف للتحقيق
        }
      }).toList();

      // إضافة التحليل الجديد
      analysesJson.insert(0, jsonEncode(analysis.toJson()));

      // حفظ آخر 100 تحليل فقط
      if (analysesJson.length > 100) {
        analysesJson = analysesJson.sublist(0, 100);
      }

      await prefs.setStringList('localAnalyses', analysesJson);
      print('📱 Saved locally. Total local analyses: ${analysesJson.length}');

    } catch (e) {
      print('❌ Error in _saveLocally: $e');
      rethrow;
    }
  }

// دالة جديدة: اختبار الاتصال بـ Firebase
  Future<bool> testFirebaseConnection() async {
    try {
      final user = _auth.currentUser;
      if (user == null) {
        print('❌ No user logged in');
        return false;
      }

      final testRef = _database.ref('connectionTest');
      await testRef.set({
        'timestamp': DateTime.now().millisecondsSinceEpoch,
        'userId': user.uid,
      });

      await testRef.remove();
      print('✅ Firebase connection test passed');
      return true;

    } catch (e) {
      print('❌ Firebase connection test failed: $e');
      return false;
    }
  }

// دالة جديدة: جلب التحليلات مع تحسين الأداء
  Future<List<SkinAnalysis>> getAllAnalyses({bool forceRefresh = false}) async {
    try {
      print('🔄 Getting all analyses...');

      final user = _auth.currentUser;
      if (user == null) {
        print('⚠️ No user logged in, returning local analyses only');
        return await getLocalAnalyses();
      }

      List<SkinAnalysis> allAnalyses = [];

      // محاولة Firebase أولاً
      try {
        final analysesRef = _database.ref('users/${user.uid}/skinAnalyses');
        final snapshot = await analysesRef.orderByChild('date').get();

        if (snapshot.exists) {
          print('🔥 Found ${snapshot.children.length} analyses in Firebase');

          for (final child in snapshot.children) {
            try {
              final data = child.value as Map<dynamic, dynamic>;
              final analysis = SkinAnalysis.fromJson(Map<String, dynamic>.from(data));
              allAnalyses.add(analysis);
            } catch (e) {
              print('⚠️ Error parsing analysis ${child.key}: $e');
            }
          }

          // ترتيب من الأحدث إلى الأقدم
          allAnalyses.sort((a, b) => b.date.compareTo(a.date));

          // مزامنة مع التخزين المحلي
          await _syncLocalWithFirebase(allAnalyses);

        } else {
          print('ℹ️ No analyses in Firebase, checking local storage');
        }

      } catch (firebaseError) {
        print('⚠️ Firebase error: $firebaseError, using local storage');
      }

      // إذا لم توجد تحليلات في Firebase، جلب المحلية
      if (allAnalyses.isEmpty) {
        final localAnalyses = await getLocalAnalyses();
        allAnalyses.addAll(localAnalyses);
        print('📱 Loaded ${localAnalyses.length} analyses from local storage');
      }

      print('✅ Total analyses loaded: ${allAnalyses.length}');
      return allAnalyses;

    } catch (e) {
      print('❌ Error in getAllAnalyses: $e');
      return await getLocalAnalyses();
    }
  }

  Future<void> _updateUserStatistics(String userId, SkinAnalysis analysis) async {
    try {
      final userRef = _database.ref('users/$userId');
      final statsRef = userRef.child('statistics');

      // Get current statistics
      final snapshot = await statsRef.get();
      Map<String, dynamic> stats = {};

      if (snapshot.exists) {
        stats = Map<String, dynamic>.from(snapshot.value as Map);
      }

      // Update statistics
      final today = DateFormat('yyyy-MM-dd').format(DateTime.now());

      stats['totalAnalyses'] = (stats['totalAnalyses'] ?? 0) + 1;
      stats['lastUpdated'] = ServerValue.timestamp;

      // Update skin type distribution
      final skinTypeKey = analysis.skinType.toLowerCase().replaceAll(' ', '_');
      stats['skinTypeDistribution'] ??= {};
      final distribution = Map<String, dynamic>.from(stats['skinTypeDistribution'] ?? {});
      distribution[skinTypeKey] = (distribution[skinTypeKey] ?? 0) + 1;
      stats['skinTypeDistribution'] = distribution;

      // Update daily analyses count
      stats['dailyAnalyses'] ??= {};
      final daily = Map<String, dynamic>.from(stats['dailyAnalyses'] ?? {});
      daily[today] = (daily[today] ?? 0) + 1;
      stats['dailyAnalyses'] = daily;

      await statsRef.set(stats);

      print('📊 Statistics updated');
    } catch (e) {
      print('⚠️ Error updating statistics: $e');
    }
  }


  Future<void> _syncLocalWithFirebase(List<SkinAnalysis> firebaseAnalyses) async {
    try {
      final localAnalyses = await getLocalAnalyses();

      // Add local analyses not in Firebase
      for (var local in localAnalyses) {
        if (!firebaseAnalyses.any((fb) => fb.id == local.id)) {
          print('🔄 Found local analysis not in Firebase: ${local.id}');
        }
      }

      // Update local storage with latest data
      await _updateLocalStorage(firebaseAnalyses);

    } catch (e) {
      print('⚠️ Sync error: $e');
    }
  }

  Future<void> _updateLocalStorage(List<SkinAnalysis> analyses) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final analysesJson = analyses.map((a) => jsonEncode(a.toJson())).toList();

      // Keep only last 50 analyses locally
      if (analysesJson.length > 50) {
        analysesJson.removeRange(50, analysesJson.length);
      }

      await prefs.setStringList('localAnalyses', analysesJson);
      print('🔄 Updated local storage with ${analyses.length} analyses');
    } catch (e) {
      print('❌ Error updating local storage: $e');
    }
  }

  // Get personalized recommendations
  Future<List<String>> getPersonalizedRecommendations() async {
    try {
      final analyses = await getAllAnalyses();

      if (analyses.isEmpty) {
        return _getDefaultRecommendations();
      }

      // Calculate recommendations based on history
      final recentAnalyses = analyses.take(5).toList(); // Last 5 analyses
      final skinTypeTrend = _analyzeSkinTypeTrend(recentAnalyses);
      final concernsTrend = _analyzeConcernsTrend(recentAnalyses);

      return _generateDynamicRecommendations(
        recentAnalyses.first, // Latest analysis
        skinTypeTrend,
        concernsTrend,
        analyses.length,
      );

    } catch (e) {
      print('❌ Error getting recommendations: $e');
      return _getDefaultRecommendations();
    }
  }

  List<String> _getDefaultRecommendations() {
    return [
      'Start with a gentle cleanser suitable for your skin type',
      'Apply SPF 30+ sunscreen daily',
      'Drink plenty of water and maintain a healthy diet',
      'Consult a dermatologist for personalized advice',
    ];
  }

  Map<String, dynamic> _analyzeSkinTypeTrend(List<SkinAnalysis> analyses) {
    if (analyses.length < 2) return {'trend': 'stable', 'change': 0};

    final firstType = analyses.last.skinType;
    final lastType = analyses.first.skinType;

    return {
      'trend': firstType == lastType ? 'stable' : 'changing',
      'from': firstType,
      'to': lastType,
      'change': firstType == lastType ? 0 : 1,
    };
  }

  Map<String, double> _analyzeConcernsTrend(List<SkinAnalysis> analyses) {
    final trend = <String, double>{};

    if (analyses.length < 2) return trend;

    final firstAnalysis = analyses.last;
    final lastAnalysis = analyses.first;

    // Check all concerns from both analyses
    final allConcerns = {...firstAnalysis.concerns.keys, ...lastAnalysis.concerns.keys};

    for (final concern in allConcerns) {
      final current = lastAnalysis.concerns[concern] ?? 0;
      final previous = firstAnalysis.concerns[concern] ?? 0;
      trend[concern] = previous - current; // Positive = improvement
    }

    return trend;
  }

  List<String> _generateDynamicRecommendations(
      SkinAnalysis latestAnalysis,
      Map<String, dynamic> skinTypeTrend,
      Map<String, double> concernsTrend,
      int totalAnalysesCount,
      ) {
    final recommendations = <String>[];
    final skinType = latestAnalysis.skinType.toLowerCase();

    // Basic recommendations based on skin type
    if (skinType.contains('oily')) {
      recommendations.addAll([
        'Use oil-free cleanser with salicylic acid',
        'Apply non-comedogenic sunscreen SPF 30+ daily',
        'Use clay mask twice weekly to control shine',
      ]);
    } else if (skinType.contains('dry')) {
      recommendations.addAll([
        'Use creamy hydrating cleanser instead of foaming cleanser',
        'Apply ceramide-rich moisturizer immediately after showering',
        'Use hyaluronic acid serum for deep hydration',
      ]);
    } else if (skinType.contains('combination')) {
      recommendations.addAll([
        'Use balancing gel cleanser for combination skin',
        'Apply different products for T-zone and cheeks',
        'Use niacinamide serum for oil control in T-zone',
      ]);
    } else {
      recommendations.addAll([
        'Use gentle pH-balanced cleanser',
        'Apply lightweight moisturizer daily',
        'Use antioxidant serum (Vitamin C) in the morning',
      ]);
    }

    // Dynamic recommendations based on trends
    if (skinTypeTrend['trend'] == 'changing') {
      recommendations.add(
        'Your skin type changed from ${skinTypeTrend['from']} to ${skinTypeTrend['to']}. You may need to adjust your products',
      );
    }

    // Recommendations based on concerns improvement/worsening
    for (final entry in concernsTrend.entries) {
      if (entry.value > 0.2) {
        recommendations.add(
          '${_translateConcern(entry.key)} has improved. Continue with your current routine',
        );
      } else if (entry.value < -0.1) {
        recommendations.add(
          '${_translateConcern(entry.key)} has worsened. Consider changing products',
        );
      }
    }

    // Recommendations based on frequency
    if (totalAnalysesCount >= 3) {
      recommendations.add(
        'You have completed $totalAnalysesCount analyses. Continue tracking your skin every two weeks',
      );
    }

    // General advice
    recommendations.add('Drink 8 glasses of water daily for skin health');
    recommendations.add('Get 7-8 hours of sleep nightly');
    recommendations.add('Change pillowcases twice weekly');
    recommendations.add('Avoid touching your face frequently');

    return recommendations;
  }

  String _translateConcern(String concern) {
    const translations = {
      'oiliness': 'Oiliness',
      'dryness': 'Dryness',
      'acne': 'Acne',
      'sensitivity': 'Sensitivity',
      'wrinkles': 'Wrinkles',
      'pores': 'Large pores',
      'redness': 'Redness',
      'dark_spots': 'Dark spots',
    };
    return translations[concern] ?? concern;
  }

  // Get latest analysis
  Future<SkinAnalysis?> getLatestAnalysis() async {
    try {
      final analyses = await getAllAnalyses();
      return analyses.isNotEmpty ? analyses.first : null;
    } catch (e) {
      print('❌ Error getting latest analysis: $e');
      return null;
    }
  }

  // Get analyses by area
  Future<List<SkinAnalysis>> getAnalysesByArea(String area) async {
    try {
      final allAnalyses = await getAllAnalyses();
      return allAnalyses
          .where((analysis) => analysis.targetArea.toLowerCase() == area.toLowerCase())
          .toList();
    } catch (e) {
      print('❌ Error getting analyses by area: $e');
      return [];
    }
  }

  // Compare two analyses
  Future<AnalysisComparison> compareAnalyses(
      SkinAnalysis current,
      SkinAnalysis? previous,
      ) async {
    try {
      if (previous == null) {
        return AnalysisComparison(
          currentAnalysis: current,
          previousAnalysis: null,
          improvements: {},
          summary: 'First analysis - baseline established',
          hasImproved: true,
          recommendedActions: _generateInitialRecommendations(current),
        );
      }

      final improvements = <String, double>{};
      var hasImproved = false;

      // Calculate improvements for each concern
      final allConcerns = {...current.concerns.keys, ...previous.concerns.keys};

      for (final concern in allConcerns) {
        final currentValue = current.concerns[concern] ?? 0;
        final previousValue = previous.concerns[concern] ?? 0;
        final improvement = previousValue - currentValue; // Positive = improvement

        improvements[concern] = improvement;

        if (improvement > 0.1) {
          hasImproved = true;
        }
      }

      final summary = _generateSummary(current, previous, improvements);
      final recommendedActions = _generateRecommendations(current, previous, improvements);

      return AnalysisComparison(
        currentAnalysis: current,
        previousAnalysis: previous,
        improvements: improvements,
        summary: summary,
        hasImproved: hasImproved,
        recommendedActions: recommendedActions,
      );
    } catch (e) {
      print('❌ Error comparing analyses: $e');
      rethrow;
    }
  }

  // Generate summary
  String _generateSummary(
      SkinAnalysis current,
      SkinAnalysis previous,
      Map<String, double> improvements,
      ) {
    final positiveChanges = improvements.values.where((v) => v > 0.1).length;
    final negativeChanges = improvements.values.where((v) => v < -0.1).length;

    if (positiveChanges > negativeChanges) {
      return 'Your skin is showing improvement! $positiveChanges areas improved.';
    } else if (negativeChanges > positiveChanges) {
      return 'Your skin needs attention. $negativeChanges areas worsened.';
    } else {
      return 'Your skin condition is stable.';
    }
  }

  // Generate recommendations
  List<String> _generateRecommendations(
      SkinAnalysis current,
      SkinAnalysis? previous,
      Map<String, double> improvements,
      ) {
    final recommendations = <String>[];

    if (previous == null) {
      return _generateInitialRecommendations(current);
    }

    // Positive improvements
    for (final entry in improvements.entries) {
      if (entry.value > 0.2) {
        recommendations.add('Continue your routine for ${_translateConcern(entry.key)} - it\'s working!');
      }
    }

    // Worsening
    for (final entry in improvements.entries) {
      if (entry.value < -0.1) {
        recommendations.add('Consider adjusting your approach to ${_translateConcern(entry.key)}');
      }
    }

    // Recommendations based on skin type
    if (current.skinType.toLowerCase().contains('dry')) {
      recommendations.add('Use hydrating products daily');
    }
    if (current.skinType.toLowerCase().contains('oily')) {
      recommendations.add('Use oil-free, non-comedogenic products');
    }
    if (current.skinType.toLowerCase().contains('sensitive')) {
      recommendations.add('Use fragrance-free and hypoallergenic products');
    }

    return recommendations;
  }

  List<String> _generateInitialRecommendations(SkinAnalysis analysis) {
    final recommendations = <String>[];

    recommendations.add('Start with gentle cleanser suitable for ${analysis.skinType} skin');
    recommendations.add('Use SPF 30+ sunscreen daily');

    if (analysis.problems.contains('acne')) {
      recommendations.add('Consider salicylic acid or benzoyl peroxide products');
    }
    if (analysis.problems.contains('dryness')) {
      recommendations.add('Incorporate hyaluronic acid and ceramides');
    }
    if (analysis.problems.contains('wrinkles')) {
      recommendations.add('Consider retinol products (start with low concentration)');
    }

    return recommendations;
  }
  // Get local analyses
  Future<List<SkinAnalysis>> getLocalAnalyses() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final analysesJson = prefs.getStringList('localAnalyses') ?? [];

      final analyses = <SkinAnalysis>[];

      for (final json in analysesJson) {
        try {
          final analysis = SkinAnalysis.fromJson(jsonDecode(json));
          analyses.add(analysis);
        } catch (e) {
          print('❌ Error parsing local analysis: $e');
        }
      }

      // Sort by date (newest first)
      analyses.sort((a, b) => b.date.compareTo(a.date));

      print('📱 Retrieved ${analyses.length} local analyses');
      return analyses;
    } catch (e) {
      print('❌ Error getting local analyses: $e');
      return [];
    }
  }

  // Delete analysis
  Future<void> deleteAnalysis(String analysisId) async {
    try {
      final user = _auth.currentUser;
      if (user == null) return;

      await _database.ref('users/${user.uid}/skinAnalyses/$analysisId').remove();

      // Update local
      await _removeLocalAnalysis(analysisId);

      print('✅ Analysis deleted: $analysisId');
    } catch (e) {
      print('❌ Error deleting analysis: $e');
      rethrow;
    }
  }

  Future<void> _removeLocalAnalysis(String analysisId) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final analysesJson = prefs.getStringList('localAnalyses') ?? [];

      final updated = analysesJson.where((json) {
        try {
          final analysis = SkinAnalysis.fromJson(jsonDecode(json));
          return analysis.id != analysisId;
        } catch (e) {
          return true;
        }
      }).toList();

      await prefs.setStringList('localAnalyses', updated);
      print('📱 Removed analysis locally: $analysisId');
    } catch (e) {
      print('❌ Error removing local analysis: $e');
    }
  }
}