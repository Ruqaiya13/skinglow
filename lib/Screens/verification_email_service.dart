import 'dart:convert';
import 'dart:math';
import 'package:firebase_database/firebase_database.dart';
import 'package:http/http.dart' as http;

class VerificationEmailService {
  static const String _apiUrl = 'https://api.emailjs.com/api/v1.0/email/send';
  static const String _serviceId = 'service_qpzj0yd'; // خاصتك
  static const String _userId = 'e6hlb3hGsHh55Z2jx'; // خاصتك

  // 🔴 ضع Template ID الجديد هنا
  static const String _verificationTemplateId = 'template_dqbovco'; // ← استبدل هذا الرمز

  static Future<bool> sendVerificationCode({
    required String userEmail,
    required String code,
  }) async {
    try {
      final response = await http.post(
        Uri.parse(_apiUrl),
        headers: {'Content-Type': 'application/json'},
        body: json.encode({
          'service_id': _serviceId,
          'template_id': _verificationTemplateId, // يستخدم القالب الجديد
          'user_id': _userId,
          'template_params': {
            'user_email': userEmail,
            'code': code,
          },
        }),
      );

      if (response.statusCode == 200) {
        print('✅ [Verification] Email sent to $userEmail');
        return true;
      } else {
        print('❌ [Verification] EmailJS Error: ${response.statusCode}');
        return false;
      }
    } catch (error) {
      print('💥 [Verification] Network Error: $error');
      return false;
    }
  }
}
class VerificationCodeService {
  /// Generate and save verification code with proper expiry
  static Future<Map<String, dynamic>> createVerificationCode({
    required String userId,
    required String email,
    int expiryMinutes = 3, // 3 دقائق افتراضياً
  }) async {
    try {
      final random = Random();
      final code = (100000 + random.nextInt(900000)).toString();

      final now = DateTime.now();
      final expiresAt = now.add(Duration(minutes: expiryMinutes));

      DatabaseReference ref = FirebaseDatabase.instance.ref("verifications/$userId");

      await ref.set({
        'code': code,
        'email': email,
        'createdAt': now.millisecondsSinceEpoch,
        'expiresAt': expiresAt.millisecondsSinceEpoch, // ✅ وقت انتهاء صحيح
      });

      print('✅ Code generated: $code');
      print('⏰ Created at: $now');
      print('⏰ Expires at: $expiresAt (${expiryMinutes} minutes)');
      print('⏳ Will expire in: ${expiresAt.difference(now)}');

      return {
        'success': true,
        'code': code,
        'expiresAt': expiresAt,
      };
    } catch (e) {
      print('❌ Error creating verification code: $e');
      return {'success': false, 'error': e.toString()};
    }
  }

  /// Check code validity
  static Future<bool> checkCodeValidity(String userId) async {
    try {
      DatabaseReference ref = FirebaseDatabase.instance.ref("verifications/$userId");
      DatabaseEvent snapshot = await ref.once();

      if (!snapshot.snapshot.exists) return false;

      final data = snapshot.snapshot.value as Map<dynamic, dynamic>;
      final expiresAt = data['expiresAt'] ?? 0;
      final code = data['code'] ?? '';

      final now = DateTime.now().millisecondsSinceEpoch;
      final timeLeft = expiresAt - now;

      print('🔍 Code Check:');
      print('   Code: $code');
      print('   Expires at: ${DateTime.fromMillisecondsSinceEpoch(expiresAt)}');
      print('   Time left: ${timeLeft ~/ 1000} seconds');
      print('   Valid: ${timeLeft > 0}');

      return timeLeft > 0;
    } catch (e) {
      print('❌ Error checking code: $e');
      return false;
    }
  }
}