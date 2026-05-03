import 'package:flutter/foundation.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_database/firebase_database.dart';

class Payment with ChangeNotifier {
  String _selectedPaymentMethod = 'Credit Card';
  String _transactionId = '';
  bool _isProcessing = false;
  String _errorMessage = '';

  final User? user = FirebaseAuth.instance.currentUser;
  final DatabaseReference _databaseRef = FirebaseDatabase.instance.ref().child('users');

  String get selectedPaymentMethod => _selectedPaymentMethod;
  String get transactionId => _transactionId;
  bool get isProcessing => _isProcessing;
  String get errorMessage => _errorMessage;

  void setPaymentMethod(String method) {
    _selectedPaymentMethod = method;
    notifyListeners();
  }
  Future<Map<String, dynamic>> checkCardBalance(String lastFourDigits) async {
    try {
      // البحث في قاعدة بيانات البطاقات الافتراضية
      final defaultCardsSnapshot = await FirebaseDatabase.instance
          .ref('virtualCards')
          .once();

      if (defaultCardsSnapshot.snapshot.value != null) {
        final Map<dynamic, dynamic> cards = defaultCardsSnapshot.snapshot.value as Map;

        // البحث عن البطاقة التي تنتهي بالأرقام الأخيرة
        for (var cardEntry in cards.entries) {
          final cardData = cardEntry.value as Map<dynamic, dynamic>;
          final cardNumber = cardData['cardNumber'].toString();

          if (cardNumber.endsWith(lastFourDigits)) {
            return {
              'cardNumber': cardData['cardNumber'],
              'expiryDate': cardData['expiryDate'],
              'cardHolderName': cardData['cardHolderName'],
              'assignedBalance': (cardData['assignedBalance'] as num).toDouble(),
              'isActive': cardData['isActive'] ?? true,
              'cardId': cardEntry.key,
              'hasSufficientBalance': (cardData['assignedBalance'] as num).toDouble() > 0,
            };
          }
        }
      }

      return {'error': 'Card not found in system'};
    } catch (e) {
      return {'error': 'Error checking balance: $e'};
    }
  }
  // دالة لتحديث رصيد البطاقة بعد عملية الدفع
  Future<bool> updateCardBalance(String cardId, double amount) async {
    try {
      final cardRef = FirebaseDatabase.instance.ref('virtualCards/$cardId');
      final snapshot = await cardRef.get();

      if (snapshot.exists) {
        final cardData = snapshot.value as Map<dynamic, dynamic>;
        final currentBalance = (cardData['assignedBalance'] as num).toDouble();

        if (currentBalance >= amount) {
          final newBalance = currentBalance - amount;
          await cardRef.update({
            'assignedBalance': newBalance,
            'lastTransaction': ServerValue.timestamp,
            'lastTransactionAmount': amount,
          });
          return true;
        }
      }
      return false;
    } catch (e) {
      print("Error updating card balance: $e");
      return false;
    }
  }

// دالة للتحقق من صحة جميع بيانات البطاقة
  Future<Map<String, dynamic>> validateCardPayment(
      String cardNumber,
      String expiryDate,
      String cvv,
      String cardHolderName,
      double requiredAmount
      ) async {
    try {
      final defaultCardsSnapshot = await FirebaseDatabase.instance
          .ref('virtualCards')
          .once();

      if (defaultCardsSnapshot.snapshot.value != null) {
        final Map<dynamic, dynamic> cards = defaultCardsSnapshot.snapshot.value as Map;

        // البحث عن البطاقة بالمطابقة الكاملة
        for (var cardEntry in cards.entries) {
          final cardData = cardEntry.value as Map<dynamic, dynamic>;
          final storedCardNumber = cardData['cardNumber'].toString();
          final storedExpiryDate = cardData['expiryDate'].toString();
          final storedCVV = cardData['cvv'].toString();
          final storedHolderName = cardData['cardHolderName'].toString();
          final storedBalance = (cardData['assignedBalance'] as num).toDouble();
          final isActive = cardData['isActive'] ?? true;

          // التحقق من المطابقة
          if (storedCardNumber == cardNumber.replaceAll(' ', '') &&
              storedExpiryDate == expiryDate &&
              storedCVV == cvv &&
              storedHolderName.toLowerCase() == cardHolderName.toLowerCase()) {

            // التحقق من حالة البطاقة
            if (!isActive) {
              return {
                'isValid': false,
                'message': 'Card is inactive. Please use another card.',
              };
            }

            // التحقق من الرصيد
            if (storedBalance < requiredAmount) {
              return {
                'isValid': false,
                'message': 'Insufficient balance. Available: OMR ${storedBalance.toStringAsFixed(3)}, Required: OMR ${requiredAmount.toStringAsFixed(3)}',
                'availableBalance': storedBalance,
              };
            }

            // التحقق من تاريخ الانتهاء
            final now = DateTime.now();
            final expParts = expiryDate.split('/');
            if (expParts.length == 2) {
              final expMonth = int.tryParse(expParts[0]) ?? 0;
              final expYear = 2000 + (int.tryParse(expParts[1]) ?? 0);

              if (expYear < now.year || (expYear == now.year && expMonth < now.month)) {
                return {
                  'isValid': false,
                  'message': 'Card has expired',
                };
              }
            }

            // كل شيء صحيح
            return {
              'isValid': true,
              'message': 'Card is valid and has sufficient balance',
              'availableBalance': storedBalance,
              'cardId': cardEntry.key,
              'cardData': cardData,
            };
          }
        }
      }

      return {
        'isValid': false,
        'message': 'Card not found in system. Please check your details.',
      };
    } catch (e) {
      return {
        'isValid': false,
        'message': 'Error validating card: $e',
      };
    }
  }

  // دالة معالجة الدفع مع التحقق من البطاقة
  Future<Map<String, dynamic>> processPaymentWithValidation(
      double amount,
      List<Map<String, dynamic>> cartItems,
      Map<String, dynamic>? cardDetails
      ) async {
    _isProcessing = true;
    _errorMessage = '';
    notifyListeners();

    try {
      // التحقق من البطاقة إذا تم تقديم تفاصيلها
      if (cardDetails != null) {
        final validation = await validateCardPayment(
            cardDetails['cardNumber'],
            cardDetails['expiryDate'],
            cardDetails['cvv'],
            cardDetails['cardHolderName'],
            amount
        );

        if (!validation['isValid']) {
          _isProcessing = false;
          _errorMessage = validation['message'];
          notifyListeners();
          return {
            'success': false,
            'message': validation['message'],
          };
        }

        // تحديث رصيد البطاقة
        final updateSuccess = await updateCardBalance(
            validation['cardId'],
            amount
        );

        if (!updateSuccess) {
          _isProcessing = false;
          _errorMessage = 'Failed to process payment';
          notifyListeners();
          return {
            'success': false,
            'message': 'Failed to process payment',
          };
        }

        // إنشاء معرف المعاملة
        _transactionId = 'TXN-${DateTime.now().millisecondsSinceEpoch}';

        _isProcessing = false;
        notifyListeners();

        return {
          'success': true,
          'transactionId': _transactionId,
          'message': 'Payment successful',
          'remainingBalance': (validation['availableBalance'] as double) - amount,
        };
      }

      // Simulate API call delay
      await Future.delayed(Duration(seconds: 2));
      _transactionId = 'TXN-${DateTime.now().millisecondsSinceEpoch}';

      _isProcessing = false;
      notifyListeners();

      return {
        'success': true,
        'transactionId': _transactionId,
        'message': 'Payment processed successfully',
      };
    } catch (e) {
      _isProcessing = false;
      _errorMessage = 'Payment failed: ${e.toString()}';
      notifyListeners();

      return {
        'success': false,
        'message': 'Payment failed: ${e.toString()}',
      };
    }
  }
  Future<bool> processPayment(double amount, List<Map<String, dynamic>> cartItems) async {
    _isProcessing = true;
    _errorMessage = '';
    notifyListeners();

    try {
      // Simulate API call delay
      await Future.delayed(Duration(seconds: 2));

      // In a real app, integrate with payment gateway here
      _transactionId = 'TXN-${DateTime.now().millisecondsSinceEpoch}';

      _isProcessing = false;
      notifyListeners();
      return true;
    } catch (e) {
      _isProcessing = false;
      _errorMessage = 'Payment failed: ${e.toString()}';
      notifyListeners();
      return false;
    }
  }

  // دالة لحفظ بيانات البطاقة في Firebase
  Future<bool> saveCardDetails(Map<String, dynamic> cardDetails) async {
    if (user == null) return false;

    try {
      await _databaseRef.child(user!.uid).child('paymentMethods').child('primary').set({
        'cardNumber': '**** **** **** ${cardDetails['cardNumber'].substring(cardDetails['cardNumber'].length - 4)}',
        'expiryDate': cardDetails['expiryDate'],
        'cardHolderName': cardDetails['cardHolderName'],
        'lastUpdated': ServerValue.timestamp,
      });
      return true;
    } catch (e) {
      print("Error saving card details: $e");
      return false;
    }
  }

  // دالة للتحقق من وجود بيانات البطاقة
  Future<bool> hasSavedCard() async {
    if (user == null) return false;

    try {
      final snapshot = await _databaseRef.child(user!.uid).child('paymentMethods').child('primary').get();
      return snapshot.exists;
    } catch (e) {
      return false;
    }
  }

  // دالة لجلب بيانات البطاقة المحفوظة
  Future<Map<String, dynamic>?> getSavedCard() async {
    if (user == null) return null;

    try {
      final snapshot = await _databaseRef.child(user!.uid).child('paymentMethods').child('primary').get();
      if (snapshot.exists) {
        return Map<String, dynamic>.from(snapshot.value as Map);
      }
      return null;
    } catch (e) {
      return null;
    }
  }

}
// في class Payment
Future<Map<String, dynamic>> basicCardValidation(
    String cardNumber,
    String expiryDate,
    String cvv,
    String cardHolderName,
    ) async {
  try {
    final defaultCardsSnapshot = await FirebaseDatabase.instance
        .ref('virtualCards')
        .once();

    if (defaultCardsSnapshot.snapshot.value != null) {
      final Map<dynamic, dynamic> cards = defaultCardsSnapshot.snapshot.value as Map;

      // البحث عن البطاقة بالمطابقة الكاملة
      for (var cardEntry in cards.entries) {
        final cardData = cardEntry.value as Map<dynamic, dynamic>;
        final storedCardNumber = cardData['cardNumber'].toString();
        final storedExpiryDate = cardData['expiryDate'].toString();
        final storedCVV = cardData['cvv'].toString();
        final storedHolderName = cardData['cardHolderName'].toString();
        final isActive = cardData['isActive'] ?? true;

        // التحقق من المطابقة فقط (بدون رصيد)
        if (storedCardNumber == cardNumber.replaceAll(' ', '') &&
            storedExpiryDate == expiryDate &&
            storedCVV == cvv &&
            storedHolderName.toLowerCase() == cardHolderName.toLowerCase()) {

          // التحقق من حالة البطاقة فقط
          if (!isActive) {
            return {
              'isValid': false,
              'message': 'Card is inactive. Please use another card.',
            };
          }

          // التحقق من تاريخ الانتهاء فقط
          final now = DateTime.now();
          final expParts = expiryDate.split('/');
          if (expParts.length == 2) {
            final expMonth = int.tryParse(expParts[0]) ?? 0;
            final expYear = 2000 + (int.tryParse(expParts[1]) ?? 0);

            if (expYear < now.year || (expYear == now.year && expMonth < now.month)) {
              return {
                'isValid': false,
                'message': 'Card has expired',
              };
            }
          }

          // ✅ **تقبل البطاقة حتى لو بدون رصيد**
          final double balance = (cardData['assignedBalance'] as num).toDouble();
          return {
            'isValid': true,
            'message': 'Card is valid',
            'cardId': cardEntry.key,
            'cardData': cardData,
            'hasBalance': balance > 0,
            'balance': balance,
          };
        }
      }
    }

    return {
      'isValid': false,
      'message': 'Card not found in system. Please check your details.',
    };
  } catch (e) {
    return {
      'isValid': false,
      'message': 'Error validating card: $e',
    };
  }
}