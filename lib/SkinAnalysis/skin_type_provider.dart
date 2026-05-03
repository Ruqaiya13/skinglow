import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:skinglow/SkinAnalysis/skin_analysis.dart';

class SkinTypeProvider extends ChangeNotifier {
  String? _skinType;
  List<String> _problems = [];
  double? _confidence;
  bool _isLoading = false;

  // ✅ متغير لحفظ معرف المستخدم الحالي
  String? _currentUserId;

  SkinTypeProvider() {
    print('🔄 SkinTypeProvider: Initializing...');
    _initialize();
  }

  // ✅ دالة للتحقق من تغير المستخدم
  void _checkUserChange() {
    final currentUser = FirebaseAuth.instance.currentUser;

    // إذا تغير المستخدم أو كان أول مرة
    if (currentUser?.uid != _currentUserId) {
      print('👤 User changed or first time. Old: $_currentUserId, New: ${currentUser?.uid}');
      _currentUserId = currentUser?.uid;
      _clearCurrentData(); // مسح البيانات القديمة
    }
  }

  // ✅ مسح البيانات الحالية (عند تغيير المستخدم)
  void _clearCurrentData() {
    _skinType = null;
    _problems = [];
    _confidence = null;
    _isLoading = false;
  }

  // ✅ Getters - مع التحقق من المستخدم
  String? get skinType {
    _checkUserChange();
    return _skinType;
  }

  List<String> get problems {
    _checkUserChange();
    return _problems;
  }

  double? get confidence {
    _checkUserChange();
    return _confidence;
  }

  bool get isLoading => _isLoading;

  // ✅ التحقق إذا كان لدى المستخدم بشرة محفوظة
  bool get hasSkinType {
    _checkUserChange();
    return _skinType != null &&
        _skinType!.isNotEmpty &&
        _skinType != 'Not analyzed yet' &&
        _skinType != 'Not analyzed';
  }

  // ✅ تهيئة الـ Provider مع تحميل البيانات
  Future<void> _initialize() async {
    try {
      _isLoading = true;
      notifyListeners();

      // التحقق من المستخدم الحالي
      _checkUserChange();

      // تحميل البيانات للمستخدم الحالي
      await _loadFromSharedPreferences();

      // إذا لم توجد بيانات في SharedPreferences، جرب Firebase
      if (_skinType == null || _skinType!.isEmpty) {
        await _loadFromFirebase();
      }

      _isLoading = false;
      notifyListeners();
      print('✅ SkinTypeProvider: Initialization complete for user: $_currentUserId. Skin type: $_skinType');

    } catch (e) {
      print('❌ SkinTypeProvider: Error initializing: $e');
      _isLoading = false;
      _clearCurrentData();
      notifyListeners();
    }
  }

  // ✅ جلب البيانات من SharedPreferences (مرتبط بالمستخدم)
  Future<void> _loadFromSharedPreferences() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final user = FirebaseAuth.instance.currentUser;

      if (user == null) {
        print('⚠️ SkinTypeProvider: No user logged in');
        return;
      }

      // ✅ المفتاح مرتبط بمعرف المستخدم
      final String skinTypeKey = 'skinType_${user.uid}';
      final String problemsKey = 'skinProblems_${user.uid}';
      final String confidenceKey = 'skinConfidence_${user.uid}';

      final savedSkinType = prefs.getString(skinTypeKey);
      final savedProblems = prefs.getStringList(problemsKey);
      final savedConfidence = prefs.getDouble(confidenceKey);

      if (savedSkinType != null && savedSkinType.isNotEmpty) {
        print('✅ SkinTypeProvider: Loaded from SharedPreferences for user ${user.uid}: $savedSkinType');
        _skinType = savedSkinType;
        _problems = savedProblems ?? [];
        _confidence = savedConfidence ?? 0.0;
        _currentUserId = user.uid; // حفظ معرف المستخدم الحالي
      } else {
        print('⚠️ SkinTypeProvider: No data in SharedPreferences for user ${user.uid}');
      }
    } catch (e) {
      print('❌ SkinTypeProvider: Error loading from SharedPreferences: $e');
    }
  }

  // ✅ جلب البيانات من Firebase (مرتبط بالمستخدم)
  Future<void> _loadFromFirebase() async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) {
        print('⚠️ SkinTypeProvider: No user logged in for Firebase load');
        return;
      }

      final userRef = FirebaseDatabase.instance.ref('users/${user.uid}');
      final snapshot = await userRef.get();

      if (snapshot.exists && snapshot.value != null) {
        final userData = snapshot.value as Map<dynamic, dynamic>;
        final firebaseSkinType = userData['skinType']?.toString();

        if (firebaseSkinType != null && firebaseSkinType.isNotEmpty) {
          print('✅ SkinTypeProvider: Loaded from Firebase for user ${user.uid}: $firebaseSkinType');

          // حفظ في SharedPreferences للمستخدم الحالي
          final prefs = await SharedPreferences.getInstance();
          final String skinTypeKey = 'skinType_${user.uid}';
          final String problemsKey = 'skinProblems_${user.uid}';
          final String confidenceKey = 'skinConfidence_${user.uid}';

          await prefs.setString(skinTypeKey, firebaseSkinType);

          // تحديث الـ Provider
          _skinType = firebaseSkinType;
          _problems = (userData['skinProblems'] as List<dynamic>?)?.map((e) => e.toString()).toList() ?? [];
          _confidence = (userData['skinConfidence'] as num?)?.toDouble() ?? 0.0;
          _currentUserId = user.uid; // حفظ معرف المستخدم الحالي

          // حفظ المشاكل والثقة
          await prefs.setStringList(problemsKey, _problems);
          if (_confidence != null) {
            await prefs.setDouble(confidenceKey, _confidence!);
          }
        } else {
          print('⚠️ SkinTypeProvider: No skin type in Firebase for user ${user.uid}');
        }
      }
    } catch (e) {
      print('❌ SkinTypeProvider: Error loading from Firebase: $e');
    }
  }

  // ✅ تحميل التحليلات (مرتبط بالمستخدم)
  Future<List<SkinAnalysis>> getAnalysisHistory() async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) return [];

      final prefs = await SharedPreferences.getInstance();
      final String historyKey = 'analysisHistory_${user.uid}';
      final analysesJson = prefs.getStringList(historyKey) ?? [];

      return analysesJson.map((json) {
        try {
          return SkinAnalysis.fromJson(jsonDecode(json));
        } catch (e) {
          print('❌ Error parsing analysis from history: $e');
          return null;
        }
      }).whereType<SkinAnalysis>().toList();
    } catch (e) {
      print('❌ Error getting analysis history: $e');
      return [];
    }
  }

  // ✅ حفظ في التاريخ (مرتبط بالمستخدم)
  Future<void> addToHistory(SkinAnalysis analysis) async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) return;

      final prefs = await SharedPreferences.getInstance();
      final String historyKey = 'analysisHistory_${user.uid}';
      final analysesJson = prefs.getStringList(historyKey) ?? [];

      // تحويل SkinAnalysis إلى JSON
      analysesJson.add(jsonEncode(analysis.toJson()));

      // حفظ آخر 50 تحليل فقط
      if (analysesJson.length > 50) {
        analysesJson.removeAt(0);
      }

      await prefs.setStringList(historyKey, analysesJson);

      print('✅ Added to history: ${analysis.skinType}');
    } catch (e) {
      print('❌ Error adding to history: $e');
    }
  }

  // ✅ دالة جديدة: تحميل من Firebase فقط (مرتبط بالمستخدم)
  Future<void> loadSkinTypeFromFirebase() async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) {
        print('⚠️ SkinTypeProvider: No user logged in');
        return;
      }

      final dbRef = FirebaseDatabase.instance.ref('users/${user.uid}');
      final snapshot = await dbRef.get();

      if (snapshot.exists && snapshot.value != null) {
        final Map<dynamic, dynamic> userData = snapshot.value as Map;
        final newSkinType = userData['skinType']?.toString();

        if (newSkinType != null && newSkinType.isNotEmpty) {
          _skinType = newSkinType;
          _problems = (userData['skinProblems'] as List<dynamic>?)?.map((e) => e.toString()).toList() ?? [];
          _confidence = (userData['skinConfidence'] as num?)?.toDouble() ?? 0.0;
          _currentUserId = user.uid;

          // ✅ تحديث SharedPreferences بالمفاتيح المرتبطة بالمستخدم
          final prefs = await SharedPreferences.getInstance();
          final String skinTypeKey = 'skinType_${user.uid}';
          final String problemsKey = 'skinProblems_${user.uid}';
          final String confidenceKey = 'skinConfidence_${user.uid}';

          await prefs.setString(skinTypeKey, _skinType!);
          await prefs.setStringList(problemsKey, _problems);
          if (_confidence != null) {
            await prefs.setDouble(confidenceKey, _confidence!);
          }

          print('🔥 Skin type loaded from Firebase for user ${user.uid}: $_skinType');
          notifyListeners();
        }
      }
    } catch (e) {
      print('❌ SkinTypeProvider: Error loading skin type from Firebase: $e');
    }
  }

  // ✅ حفظ نوع البشرة (مرتبط بالمستخدم الحالي)
  Future<void> setSkinType(
      String skinType, {
        List<String> problems = const [],
        double confidence = 0.0,
      }) async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) {
        print('⚠️ Cannot save skin type: No user logged in');
        return;
      }

      print('💾 SkinTypeProvider: Saving skin type for user ${user.uid}: $skinType');

      // تحديث القيم في الـ Provider
      _skinType = skinType;
      _problems = problems;
      _confidence = confidence;
      _currentUserId = user.uid;

      // 1. حفظ في SharedPreferences (مربوط بالمستخدم)
      final prefs = await SharedPreferences.getInstance();
      final String skinTypeKey = 'skinType_${user.uid}';
      final String problemsKey = 'skinProblems_${user.uid}';
      final String confidenceKey = 'skinConfidence_${user.uid}';

      await prefs.setString(skinTypeKey, skinType);
      await prefs.setStringList(problemsKey, problems);
      await prefs.setDouble(confidenceKey, confidence);

      print('✅ Saved to SharedPreferences for user ${user.uid}');

      // 2. حفظ في Firebase (مربوط بالمستخدم)
      await _saveToFirebase(skinType, problems, confidence);
      print('✅ Saved to Firebase for user ${user.uid}');

      // 3. إشعار جميع الصفحات بالتحديث
      notifyListeners();

      print('🎉 SkinTypeProvider: Successfully saved for user ${user.uid}: $skinType');

    } catch (e) {
      print('❌ SkinTypeProvider: Error setting skin type: $e');
    }
  }

  // ✅ حفظ في Firebase (مرتبط بالمستخدم)
  Future<void> _saveToFirebase(String skinType, List<String> problems, double confidence) async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user != null) {
        final userRef = FirebaseDatabase.instance.ref('users/${user.uid}');
        await userRef.update({
          'skinType': skinType,
          'skinProblems': problems,
          'skinConfidence': confidence,
          'skinAnalysisDate': DateTime.now().millisecondsSinceEpoch,
        });
      }
    } catch (e) {
      print('❌ SkinTypeProvider: Error saving to Firebase: $e');
      // لا نوقف العملية إذا فشل حفظ Firebase
    }
  }

  // ✅ جلب آخر بيانات من Firebase (مرتبط بالمستخدم)
  Future<void> refreshFromFirebase() async {
    try {
      print('🔄 SkinTypeProvider: Refreshing from Firebase...');
      await _loadFromFirebase();
      notifyListeners();
    } catch (e) {
      print('❌ SkinTypeProvider: Error refreshing from Firebase: $e');
    }
  }

  // ✅ مسح البيانات الكامل (للمستخدم الحالي فقط)
  Future<void> clearSkinData() async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) return;

      _skinType = null;
      _problems = [];
      _confidence = 0.0;
      _currentUserId = null;

      // 1. مسح من SharedPreferences (للمستخدم الحالي فقط)
      final prefs = await SharedPreferences.getInstance();
      final String skinTypeKey = 'skinType_${user.uid}';
      final String problemsKey = 'skinProblems_${user.uid}';
      final String confidenceKey = 'skinConfidence_${user.uid}';

      await prefs.remove(skinTypeKey);
      await prefs.remove(problemsKey);
      await prefs.remove(confidenceKey);

      // 2. مسح من Firebase (للمستخدم الحالي فقط)
      final userRef = FirebaseDatabase.instance.ref('users/${user.uid}');
      await userRef.update({
        'skinType': null,
        'skinProblems': [],
        'skinConfidence': 0.0,
      });

      notifyListeners();
      print('✅ SkinTypeProvider: Cleared skin data for user ${user.uid}');
    } catch (e) {
      print('❌ SkinTypeProvider: Error clearing skin data: $e');
    }
  }

  // ✅ مسح نوع البشرة من Provider فقط (دون مسح التخزين)
  Future<void> clearSkinType() async {
    _skinType = null;
    _problems = [];
    _confidence = null;
    _currentUserId = null;
    print('✅ SkinTypeProvider: Cleared skin type from Provider');
    notifyListeners();
  }

  // ✅ دالة جديدة: التحميل عند تسجيل الدخول أو تغيير المستخدم
  Future<void> loadForCurrentUser() async {
    try {
      _isLoading = true;
      notifyListeners();

      // التحقق من المستخدم الحالي
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) {
        _clearCurrentData();
        _isLoading = false;
        notifyListeners();
        return;
      }

      // إذا كان نفس المستخدم ولا يزال لديه بيانات، لا نحتاج لإعادة التحميل
      if (_currentUserId == user.uid && _skinType != null) {
        _isLoading = false;
        notifyListeners();
        return;
      }

      // إعادة تعيين وبدء التحميل للمستخدم الجديد
      _currentUserId = user.uid;
      await _loadFromSharedPreferences();

      // إذا لم توجد بيانات محلية، جرب Firebase
      if (_skinType == null || _skinType!.isEmpty) {
        await _loadFromFirebase();
      }

      _isLoading = false;
      notifyListeners();

    } catch (e) {
      print('❌ Error loading for current user: $e');
      _isLoading = false;
      notifyListeners();
    }
  }
}