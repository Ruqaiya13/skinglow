import 'dart:convert';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:shared_preferences/shared_preferences.dart';

class UserService {
  // ✅ الحصول على معرف المستخدم الحالي
  static String? get _userId {
    return FirebaseAuth.instance.currentUser?.uid;
  }

  // ✅ التحقق من وجود مستخدم مسجل
  static bool get isUserLoggedIn {
    return FirebaseAuth.instance.currentUser != null;
  }

  // ✅ الحصول على مفتاح مرتبط بالمستخدم
  static String getSkinDataKey() {
    final userId = _userId;
    if (userId == null) {
      throw Exception('No user logged in');
    }
    return 'skinData_$userId';
  }

  // ✅ حفظ بيانات البشرة (مرتبط بالمستخدم الحالي)
  static Future<void> saveSkinData(Map<String, dynamic> data) async {
    try {
      if (!isUserLoggedIn) {
        print('⚠️ Cannot save skin data: No user logged in');
        return;
      }

      final prefs = await SharedPreferences.getInstance();
      final key = getSkinDataKey();
      await prefs.setString(key, jsonEncode(data));

      // ✅ حفظ في Firebase أيضاً
      await _saveToFirebase(data);

      print('✅ UserService: Skin data saved for user $_userId: ${data['skinType']}');
    } catch (e) {
      print('❌ Error saving skin data: $e');
    }
  }

  // ✅ جلب البيانات من SharedPreferences (مرتبط بالمستخدم الحالي)
  static Future<Map<String, dynamic>?> getSkinData() async {
    try {
      if (!isUserLoggedIn) {
        print('⚠️ Cannot get skin data: No user logged in');
        return null;
      }

      final prefs = await SharedPreferences.getInstance();
      final key = getSkinDataKey();
      final dataString = prefs.getString(key);

      if (dataString != null) {
        final data = jsonDecode(dataString) as Map<String, dynamic>;
        print('✅ UserService: Skin data loaded for user $_userId: ${data['skinType']}');
        return data;
      } else {
        // ✅ إذا لم توجد بيانات محلية، جرب Firebase
        final fbData = await _loadFromFirebase();
        if (fbData != null) {
          print('✅ UserService: Loaded from Firebase for user $_userId: ${fbData['skinType']}');
          await saveSkinData(fbData); // حفظ محلياً للمرة القادمة
          return fbData;
        }
      }
    } catch (e) {
      print('❌ Error loading skin data: $e');
    }
    return null;
  }

  // ✅ مسح بيانات البشرة (للمستخدم الحالي فقط)
  static Future<void> clearSkinData() async {
    try {
      if (!isUserLoggedIn) {
        print('⚠️ Cannot clear skin data: No user logged in');
        return;
      }

      final prefs = await SharedPreferences.getInstance();
      final key = getSkinDataKey();
      await prefs.remove(key);

      // ✅ مسح من Firebase أيضاً
      await _clearFromFirebase();

      print('✅ UserService: Skin data cleared for user $_userId');
    } catch (e) {
      print('❌ Error clearing skin data: $e');
    }
  }

  // ✅ تحديث نوع البشرة فقط (مرتبط بالمستخدم الحالي)
  static Future<void> updateSkinType(String skinType) async {
    try {
      if (!isUserLoggedIn) {
        print('⚠️ Cannot update skin type: No user logged in');
        return;
      }

      final currentData = await getSkinData() ?? {};
      currentData['skinType'] = skinType;

      await saveSkinData(currentData);

      print('✅ UserService: Skin type updated for user $_userId: $skinType');
    } catch (e) {
      print('❌ Error updating skin type: $e');
    }
  }

  // ✅ جلب جميع تحليلات البشرة للمستخدم الحالي
  static Future<List<Map<String, dynamic>>> getAnalysisHistory() async {
    try {
      if (!isUserLoggedIn) {
        print('⚠️ Cannot get analysis history: No user logged in');
        return [];
      }

      final prefs = await SharedPreferences.getInstance();
      final key = 'analysisHistory_$_userId';
      final historyJson = prefs.getStringList(key) ?? [];

      final history = historyJson.map((json) {
        try {
          return jsonDecode(json) as Map<String, dynamic>;
        } catch (e) {
          print('❌ Error parsing history item: $e');
          return null;
        }
      }).whereType<Map<String, dynamic>>().toList();

      return history.reversed.toList(); // الأحدث أولاً

    } catch (e) {
      print('❌ Error getting analysis history: $e');
      return [];
    }
  }

  // ✅ إضافة تحليل جديد للتاريخ (مرتبط بالمستخدم الحالي)
  static Future<void> addToAnalysisHistory(Map<String, dynamic> analysis) async {
    try {
      if (!isUserLoggedIn) {
        print('⚠️ Cannot add to history: No user logged in');
        return;
      }

      final prefs = await SharedPreferences.getInstance();
      final key = 'analysisHistory_$_userId';
      final history = await getAnalysisHistory();

      // إضافة التاريخ للتحليل
      analysis['analysisDate'] = DateTime.now().toIso8601String();
      analysis['userId'] = _userId;

      history.add(analysis);

      // حفظ آخر 50 تحليل فقط
      if (history.length > 50) {
        history.removeAt(0);
      }

      // حفظ كـ JSON
      final historyJson = history.map((item) => jsonEncode(item)).toList();
      await prefs.setStringList(key, historyJson);

      print('✅ UserService: Analysis added to history for user $_userId');

    } catch (e) {
      print('❌ Error adding to analysis history: $e');
    }
  }

  // ✅ مسح تاريخ التحليلات (للمستخدم الحالي فقط)
  static Future<void> clearAnalysisHistory() async {
    try {
      if (!isUserLoggedIn) {
        print('⚠️ Cannot clear history: No user logged in');
        return;
      }

      final prefs = await SharedPreferences.getInstance();
      final key = 'analysisHistory_$_userId';
      await prefs.remove(key);

      print('✅ UserService: Analysis history cleared for user $_userId');

    } catch (e) {
      print('❌ Error clearing analysis history: $e');
    }
  }

  // ✅ دالة مساعدة: جلب بيانات البشرة من Firebase
  static Future<Map<String, dynamic>?> _loadFromFirebase() async {
    try {
      final userId = _userId;
      if (userId == null) return null;

      final userRef = FirebaseDatabase.instance.ref('users/$userId');
      final snapshot = await userRef.get();

      if (snapshot.exists && snapshot.value != null) {
        final userData = snapshot.value as Map<dynamic, dynamic>;

        // استخراج بيانات البشرة فقط
        final skinData = {
          'skinType': userData['skinType'],
          'problems': userData['skinProblems'] ?? [],
          'confidence': userData['skinConfidence'] ?? 0.0,
          'analysisDate': userData['skinAnalysisDate'],
        };

        return skinData;
      }
    } catch (e) {
      print('❌ Error loading from Firebase: $e');
    }
    return null;
  }

  // ✅ دالة مساعدة: حفظ بيانات البشرة إلى Firebase
  static Future<void> _saveToFirebase(Map<String, dynamic> data) async {
    try {
      final userId = _userId;
      if (userId == null) return;

      final userRef = FirebaseDatabase.instance.ref('users/$userId');
      await userRef.update({
        'skinType': data['skinType'],
        'skinProblems': data['problems'] ?? [],
        'skinConfidence': data['confidence'] ?? 0.0,
        'skinAnalysisDate': data['analysisDate'] ?? DateTime.now().millisecondsSinceEpoch,
      });

    } catch (e) {
      print('❌ Error saving to Firebase: $e');
    }
  }

  // ✅ دالة مساعدة: مسح بيانات البشرة من Firebase
  static Future<void> _clearFromFirebase() async {
    try {
      final userId = _userId;
      if (userId == null) return;

      final userRef = FirebaseDatabase.instance.ref('users/$userId');
      await userRef.update({
        'skinType': null,
        'skinProblems': [],
        'skinConfidence': 0.0,
        'skinAnalysisDate': null,
      });

    } catch (e) {
      print('❌ Error clearing from Firebase: $e');
    }
  }

  // ✅ جلب نوع البشرة الحالي للمستخدم (دالة سريعة)
  static Future<String?> getCurrentSkinType() async {
    try {
      final data = await getSkinData();
      return data?['skinType']?.toString();
    } catch (e) {
      print('❌ Error getting current skin type: $e');
      return null;
    }
  }

  // ✅ التحقق إذا كان للمستخدم بيانات بشرة محفوظة
  static Future<bool> hasSkinData() async {
    try {
      final data = await getSkinData();
      final skinType = data?['skinType'];
      return skinType != null &&
          skinType.toString().isNotEmpty &&
          skinType != 'Not analyzed yet' &&
          skinType != 'Not analyzed';
    } catch (e) {
      print('❌ Error checking skin data: $e');
      return false;
    }
  }

  // ✅ دالة لتحميل وإعادة تهيئة البيانات عند تسجيل الدخول
  static Future<void> reloadForCurrentUser() async {
    try {
      if (!isUserLoggedIn) return;

      // مسح أي بيانات قديمة (إذا كانت)
      final prefs = await SharedPreferences.getInstance();
      final oldKeys = prefs.getKeys().where((key) =>
      key.startsWith('skinData_') && !key.endsWith('_$_userId')).toList();

      for (final key in oldKeys) {
        await prefs.remove(key);
      }

      // تحميل بيانات المستخدم الجديد
      await getSkinData(); // سيحمل من Firebase إذا لم توجد محلياً

      print('✅ UserService: Data reloaded for user $_userId');

    } catch (e) {
      print('❌ Error reloading for current user: $e');
    }
  }
}