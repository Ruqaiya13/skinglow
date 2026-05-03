import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:skinglow/Screens/payment_model.dart';
import 'package:skinglow/Screens/payment_model.dart' as paymentProvider;

import 'checkout_screen.dart';

class PaymentPage extends StatefulWidget {
  @override
  _PaymentPageState createState() => _PaymentPageState();
}

class _PaymentPageState extends State<PaymentPage> {
  final User? user = FirebaseAuth.instance.currentUser;
  final DatabaseReference _databaseRef =
  FirebaseDatabase.instance.ref().child('users');

  final _formKey = GlobalKey<FormState>();

  final TextEditingController _cardNumberController = TextEditingController();
  final TextEditingController _expiryDateController = TextEditingController();
  final TextEditingController _cvvController = TextEditingController();
  final TextEditingController _cardHolderController = TextEditingController();

  bool _isLoading = false;
  bool _cardExists = false;
  Map<String, dynamic>? _savedCardData;

  @override
  void initState() {
    super.initState();
    _loadSavedCard();
  }

  @override
  void dispose() {
    _cardNumberController.dispose();
    _expiryDateController.dispose();
    _cvvController.dispose();
    _cardHolderController.dispose();
    super.dispose();
  }

  // دالة تحميل البطاقة المحفوظة مع التحقق من الرصيد
  Future<void> _loadSavedCard() async {
    if (user == null) return;
    try {
      final cardSnapshot = await _databaseRef
          .child(user!.uid)
          .child('paymentMethods')
          .child('primary')
          .get();

      if (cardSnapshot.exists) {
        final cardData = Map<String, dynamic>.from(
            cardSnapshot.value as Map<dynamic, dynamic>
        );

        // التحقق من رصيد البطاقة المحفوظة
        final paymentProvider = Provider.of<Payment>(context, listen: false);
        final lastFourDigits = cardData['displayCardNumber']?.split(' ').last ?? '';
        final balanceCheck = await paymentProvider.checkCardBalance(lastFourDigits);

        setState(() {
          _savedCardData = cardData;
          _cardExists = true;
          // إضافة معلومات الرصيد للبيانات المحفوظة
          if (balanceCheck['hasSufficientBalance'] != null) {
            _savedCardData!['hasSufficientBalance'] = balanceCheck['hasSufficientBalance'];
            _savedCardData!['availableBalance'] = balanceCheck['assignedBalance'];
          }
        });
      }
    } catch (e) {
      print("Error loading card: $e");
    }
  }

  Future<void> _saveCardDetails() async {
    if (_formKey.currentState!.validate()) {
      _formKey.currentState!.save();

      setState(() => _isLoading = true);

      try {
        String cleanCardNumber = _cardNumberController.text.replaceAll(' ', '');

        await _databaseRef
            .child(user!.uid)
            .child('paymentMethods')
            .child('primary')
            .set({
          'displayCardNumber':
          '**** **** **** ${cleanCardNumber.substring(cleanCardNumber.length - 4)}',
          'expiryDate': _expiryDateController.text,
          'cardHolderName': _cardHolderController.text,
          'lastUpdated': ServerValue.timestamp,
        });

        setState(() {
          _cardExists = true;
          _savedCardData = {
            'displayCardNumber':
            '**** **** **** ${cleanCardNumber.substring(cleanCardNumber.length - 4)}',
            'expiryDate': _expiryDateController.text,
            'cardHolderName': _cardHolderController.text,
          };
        });

        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Card details saved successfully!'),
            backgroundColor: Color(0xFF914D74),
          ),
        );
      } catch (e) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to save card details: $e'),
            backgroundColor: Colors.red,
          ),
        );
      } finally {
        setState(() => _isLoading = false);
      }
    }
  }
  // تعديل PaymentPage - دالة _validateAndSaveCard
  Future<void> _validateAndSaveCard() async {
    if (_formKey.currentState!.validate()) {
      _formKey.currentState!.save();

      setState(() => _isLoading = true);

      try {
        String cleanCardNumber = _cardNumberController.text.replaceAll(' ', '');
        String expiryDate = _expiryDateController.text;
        String cvv = _cvvController.text;
        String cardHolderName = _cardHolderController.text;

        // ✅ **استخدام validateCardPayment مع مبلغ اختبار صغير (1 ريال)**
        final paymentProvider = Provider.of<Payment>(context, listen: false);
        final validation = await paymentProvider.validateCardPayment(
          cleanCardNumber,
          expiryDate,
          cvv,
          cardHolderName,
          1.0, // مبلغ اختبار صغير
        );

        if (!validation['isValid']) {
          // ✅ **التعديل المهم: نسمح بالحفظ حتى لو بدون رصيد**
          final String message = validation['message'] ?? '';

          // إذا كان الخطأ بسبب الرصيد فقط، نسمح بالحفظ مع تحذير
          if (message.contains('Insufficient balance') ||
              validation['availableBalance'] != null) {

            final double balance = validation['availableBalance'] as double? ?? 0;



            // ✅ **نستمر في حفظ البطاقة حتى بدون رصيد**
            await _saveCardAnyway(cleanCardNumber, expiryDate, cvv, cardHolderName, balance);
            return;
          }

          // إذا كان الخطأ لأسباب أخرى (بطاقة منتهية، غير نشطة، بيانات خاطئة)
          else {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(validation['message']),
                backgroundColor: Colors.red,
                duration: Duration(seconds: 3),
              ),
            );
            return;
          }
        }

        // إذا كانت البطاقة صالحة تماماً
        final double balance = validation['availableBalance'] as double? ?? 0;
        final bool hasBalance = balance > 0;

        await _saveCardAnyway(cleanCardNumber, expiryDate, cvv, cardHolderName, balance);

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(hasBalance
                ? 'Card saved successfully'
                : 'Card saved successfully'
            ),
            backgroundColor: hasBalance ? Colors.green : Colors.orange,
          ),
        );

      } catch (e) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to save card: $e'),
            backgroundColor: Colors.red,
          ),
        );
      } finally {
        setState(() => _isLoading = false);
      }
    }
  }

// ✅ **دالة مساعدة لحفظ البطاقة في جميع الحالات**
  Future<void> _saveCardAnyway(
      String cleanCardNumber,
      String expiryDate,
      String cvv,
      String cardHolderName,
      double balance
      ) async {
    await _databaseRef
        .child(user!.uid)
        .child('paymentMethods')
        .child('primary')
        .set({
      'displayCardNumber': '**** **** **** ${cleanCardNumber.substring(cleanCardNumber.length - 4)}',
      'fullCardNumber': cleanCardNumber,
      'expiryDate': expiryDate,
      'cardHolderName': cardHolderName,
      'cvv': cvv,
      'lastUpdated': ServerValue.timestamp,
      'isCardSaved': true,
      'needsBalanceCheck': true,
      'lastKnownBalance': balance,
    });

    setState(() {
      _cardExists = true;
      _savedCardData = {
        'displayCardNumber': '**** **** **** ${cleanCardNumber.substring(cleanCardNumber.length - 4)}',
        'fullCardNumber': cleanCardNumber,
        'expiryDate': expiryDate,
        'cardHolderName': cardHolderName,
        'cvv': cvv,
        'isCardSaved': true,
        'hasSufficientBalance': balance > 0,
        'availableBalance': balance,
      };
    });
  }
  Future<void> _deleteSavedCard() async {
    if (user == null) return;
    await _databaseRef
        .child(user!.uid)
        .child('paymentMethods')
        .child('primary')
        .remove();

    setState(() {
      _cardExists = false;
      _savedCardData = null;
    });

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Card deleted successfully'),
        backgroundColor: Color(0xFF914D74),
      ),
    );
  }

  String? _validateCardNumber(String? value) {
    if (value == null || value.isEmpty) return 'Please enter card number';
    String cleaned = value.replaceAll(' ', '');
    if (cleaned.length != 16) return 'Card number must be 16 digits';
    return null;
  }

  String? _validateExpiryDate(String? value) {
    if (value == null || value.isEmpty) return 'Enter expiry date';

    // التأكد من الصيغة MM/YY
    if (!RegExp(r'^(0[1-9]|1[0-2])\/\d{2}$').hasMatch(value)) {
      return 'Invalid format (MM/YY)';
    }

    // استخراج الشهر والسنة من القيمة المدخلة
    final parts = value.split('/');
    final int enteredMonth = int.tryParse(parts[0]) ?? 0;
    final int enteredYear = 2000 + (int.tryParse(parts[1]) ?? 0);

    // التاريخ الحالي
    final now = DateTime.now();
    final int currentMonth = now.month;
    final int currentYear = now.year;

    // التحقق من انتهاء البطاقة
    if (enteredYear < currentYear ||
        (enteredYear == currentYear && enteredMonth < currentMonth)) {
      return 'This card has expired';
    }

    return null;
  }


  String? _validateCVV(String? value) {
    if (value == null || value.isEmpty) return 'Enter CVV';
    if (value.length != 3) return 'CVV must be 3 digits';
    return null;
  }

  String? _validateName(String? value) {
    if (value == null || value.isEmpty) return 'Enter card holder name';
    return null;
  }

  // Formatter to add spaces every 4 digits
  TextInputFormatter cardNumberFormatter() {
    return TextInputFormatter.withFunction((oldValue, newValue) {
      String digitsOnly = newValue.text.replaceAll(' ', '');
      String newString = '';
      for (int i = 0; i < digitsOnly.length; i++) {
        newString += digitsOnly[i];
        if ((i + 1) % 4 == 0 && i + 1 != digitsOnly.length) {
          newString += ' ';
        }
      }
      return TextEditingValue(
        text: newString,
        selection: TextSelection.collapsed(offset: newString.length),
      );
    });
  }

  // Formatter to auto-insert "/" after 2 digits
  TextInputFormatter expiryDateFormatter() {
    return TextInputFormatter.withFunction((oldValue, newValue) {
      String digitsOnly = newValue.text.replaceAll('/', '');
      if (digitsOnly.length > 2) {
        digitsOnly =
            digitsOnly.substring(0, 2) + '/' + digitsOnly.substring(2);
      }
      return TextEditingValue(
        text: digitsOnly,
        selection: TextSelection.collapsed(offset: digitsOnly.length),
      );
    });
  }

  Widget _buildCardForm() {
    return SingleChildScrollView(
      child: Column(
        children: [
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(20),
            margin: const EdgeInsets.only(top: 10),
            decoration: BoxDecoration(
              color: Colors.pink.shade50,
              borderRadius: BorderRadius.circular(18),
              boxShadow: [
                BoxShadow(
                  color: Colors.pink.shade100.withOpacity(0.4),
                  blurRadius: 8,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: Form(
              key: _formKey,
              child: Column(
                children: [
                  const Text(
                    'Add New Card',
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF914D74),
                    ),
                  ),
                  const SizedBox(height: 20),

                  // Card Number
                  TextFormField(
                    controller: _cardNumberController,
                    decoration: const InputDecoration(
                      labelText: 'Card Number',
                      border: OutlineInputBorder(),
                      hintText: '1234 5678 9012 3456',
                    ),
                    keyboardType: TextInputType.number,
                    maxLength: 19,
                    validator: _validateCardNumber,
                    inputFormatters: [
                      FilteringTextInputFormatter.digitsOnly,
                      cardNumberFormatter(),
                    ],
                  ),
                  const SizedBox(height: 16),

                  Row(
                    children: [
                      Expanded(
                        child: TextFormField(
                          controller: _expiryDateController,
                          decoration: const InputDecoration(
                            labelText: 'Expiry (MM/YY)',
                            border: OutlineInputBorder(),
                            counterText: "",
                          ),
                          keyboardType: TextInputType.number,
                          maxLength: 5,
                          validator: _validateExpiryDate,
                          inputFormatters: [
                            FilteringTextInputFormatter.digitsOnly,
                            expiryDateFormatter(),
                          ],
                        ),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: TextFormField(
                          controller: _cvvController,
                          decoration: const InputDecoration(
                            labelText: 'CVV',
                            border: OutlineInputBorder(),
                          ),
                          keyboardType: TextInputType.number,
                          obscureText: true,
                          inputFormatters: [
                            FilteringTextInputFormatter.digitsOnly,
                            LengthLimitingTextInputFormatter(3),
                          ],
                          validator: _validateCVV,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),

                  TextFormField(
                    controller: _cardHolderController,
                    decoration: const InputDecoration(
                      labelText: 'Card Holder Name',
                      border: OutlineInputBorder(),
                    ),
                    validator: _validateName,
                  ),
                  const SizedBox(height: 24),

                  ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Color(0xFF914D74),
                      foregroundColor: Colors.white,
                      minimumSize: const Size(double.infinity, 50),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(30),
                      ),
                    ),
                    onPressed: _isLoading ? null : _validateAndSaveCard, // تم التغيير هنا
                    child: _isLoading
                        ? const CircularProgressIndicator(color: Colors.white)
                        : const Text(
                      'Save & Validate Card',
                      style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                    ),
                  ),

                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSavedCardView() {
    final bool hasBalance = _savedCardData?['hasSufficientBalance'] == true;
    final double balance = (_savedCardData?['availableBalance'] as num?)?.toDouble() ?? 0;

    return Column(
      children: [
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(20),
          margin: const EdgeInsets.only(top: 20),
          decoration: BoxDecoration(
            color: hasBalance ? Colors.green[50] : Colors.red[50],
            borderRadius: BorderRadius.circular(18),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'Saved Card',
                    style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF914D74)
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              Text(
                'Card: ${_savedCardData?['displayCardNumber'] ?? '**** **** **** ****'}',
                style: TextStyle(fontWeight: FontWeight.w500),
              ),
              Text('Expiry: ${_savedCardData?['expiryDate'] ?? '--/--'}'),
              Text('Name: ${_savedCardData?['cardHolderName'] ?? 'Unknown'}'),

              const SizedBox(height: 24),
              Row(
                children: [
                  Expanded(
                    child: ElevatedButton.icon(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Color(0xFF914D74),
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(25)
                        ),
                      ),
                      icon: const Icon(Icons.delete),
                      label: const Text('Delete Card'),
                      onPressed: _deleteSavedCard,
                    ),
                  ),

                ],
              ),
            ],
          ),
        ),
      ],
    );
  }
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Color(0xFFFFE4F3),
      appBar: AppBar(
        title: const Text('Payment Method'),
        backgroundColor: Color(0xFFFFE4F3),
        foregroundColor: Color(0xFF914D74),
        elevation: 0,
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: _cardExists ? _buildSavedCardView() : _buildCardForm(),
      ),
    );
  }
}
