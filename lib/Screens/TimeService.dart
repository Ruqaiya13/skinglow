import 'package:intl/intl.dart';

class TimeService {
  /// Convert any date string to UTC for proper comparison
  static DateTime parseToUtc(String dateString) {
    try {
      // If it already has Z (ISO 8601 format)
      if (dateString.contains('Z')) {
        return DateTime.parse(dateString);
      }

      // If it's in European format: "2025-12-12 23:24:41.756"
      if (dateString.contains('-') && dateString.contains(':')) {
        // Replace space with T to make it ISO-like
        String isoString = dateString.replaceFirst(' ', 'T');
        // Add Z for UTC
        if (!isoString.endsWith('Z')) {
          isoString += 'Z';
        }
        return DateTime.parse(isoString);
      }

      // Try other common formats
      List<String> patterns = [
        'yyyy-MM-dd HH:mm:ss',
        'yyyy-MM-dd HH:mm:ss.SSS',
        'dd/MM/yyyy HH:mm:ss',
        'yyyy/MM/dd HH:mm:ss',
        'MM/dd/yyyy HH:mm:ss',
      ];

      for (String pattern in patterns) {
        try {
          DateFormat format = DateFormat(pattern);
          DateTime parsed = format.parse(dateString);
          return DateTime.utc(
            parsed.year,
            parsed.month,
            parsed.day,
            parsed.hour,
            parsed.minute,
            parsed.second,
            parsed.millisecond,
          );
        } catch (_) {}
      }

      // Last resort
      return DateTime.parse(dateString).toUtc();
    } catch (e) {
      print('⚠️ Error parsing date: $e');
      return DateTime.now().toUtc();
    }
  }

  /// Check if a code is valid based on expiry date
  static bool isCodeValid(String expiryDateString) {
    try {
      DateTime expiresAt = parseToUtc(expiryDateString);
      DateTime now = DateTime.now().toUtc();

      print('🕒 Expiry Time (UTC): $expiresAt');
      print('🕒 Current Time (UTC): $now');
      print('⏳ Time Remaining: ${expiresAt.difference(now)}');

      return now.isBefore(expiresAt);
    } catch (e) {
      print('❌ Validation error: $e');
      return false;
    }
  }

  /// Diagnostic function to debug date issues
  static void debugDate(String dateString) {
    print('=== 🔍 Date Debug ===');
    print('📥 Received string: "$dateString"');
    print('📥 String length: ${dateString.length}');
    print('📥 Contains Z: ${dateString.contains('Z')}');

    try {
      DateTime parsed = parseToUtc(dateString);
      print('✅ Parsed as: $parsed');
      print('🌍 Timezone: ${parsed.timeZoneName}');
      print('🔄 As local: ${parsed.toLocal()}');
      print('⏰ Current (UTC): ${DateTime.now().toUtc()}');
      print('⏰ Current (Local): ${DateTime.now()}');
    } catch (e) {
      print('❌ Parse error: $e');
    }

    print('=====================');
  }

  /// Get current time in ISO format
  static String getCurrentIsoTime() {
    return DateTime.now().toUtc().toIso8601String();
  }

  /// Add safety margin to expiry (e.g., 5 minutes)
  static DateTime addSafetyMargin(DateTime expiry, {int minutes = 5}) {
    return expiry.add(Duration(minutes: minutes));
  }
}
class CodeService {
  /// Main validation function - NOW SYNCHRONOUS
  static Map<String, dynamic> validateCode(
      String code,
      String expiryDateString,
      ) {
    // 1. First, debug the date string
    TimeService.debugDate(expiryDateString);

    // 2. Check validity
    bool isValid = TimeService.isCodeValid(expiryDateString);

    // 3. Prepare result
    Map<String, dynamic> result = {
      'code': code,
      'isValid': isValid,
      'message': isValid ? '✅ Code is valid' : '❌ Code has expired',
      'expiryDate': expiryDateString,
      'validatedAt': TimeService.getCurrentIsoTime(),
      'timestamp': DateTime.now().millisecondsSinceEpoch,
    };

    print('🎯 Validation Result:');
    print('   Code: ${result['code']}');
    print('   Valid: ${result['isValid']}');
    print('   Message: ${result['message']}');

    return result; // ✅ Now returns directly, not Future
  }

  /// Process code from API response
  static void processApiResponse(Map<String, dynamic> response) {
    String code = response['code']?.toString() ?? '';
    String expiry = response['expires']?.toString() ?? '';

    if (code.isEmpty || expiry.isEmpty) {
      print('❌ Invalid API response');
      return;
    }

    // ✅ No more await needed
    Map<String, dynamic> validation = validateCode(code, expiry);

    if (validation['isValid'] == true) {
      print('✅ Code $code is ACCEPTED');
    } else {
      print('❌ Code $code is REJECTED');
    }
  }

// Keep other functions as they are...
}