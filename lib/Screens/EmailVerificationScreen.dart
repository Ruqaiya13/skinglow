import 'dart:math';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:skinglow/Screens/verification_email_service.dart';

import 'TimeService.dart';

class EmailVerificationScreen extends StatefulWidget {
  final String userId;
  final String email;
  final VoidCallback onVerificationSuccess;

  const EmailVerificationScreen({
    Key? key,
    required this.userId,
    required this.email,
    required this.onVerificationSuccess,
  }) : super(key: key);

  @override
  _EmailVerificationScreenState createState() => _EmailVerificationScreenState();
}

class _EmailVerificationScreenState extends State<EmailVerificationScreen> {
  // 🔴 Changed from 4 to 6 digits
  final List<TextEditingController> _controllers = List.generate(6, (index) => TextEditingController());
  final List<FocusNode> _focusNodes = List.generate(6, (index) => FocusNode());
  bool _isLoading = false;
  bool _isResending = false;
  String _errorMessage = '';

  @override
  void initState() {
    super.initState();
    _setupFocusNodes();
    _checkCodeImmediately();
  }

  void _checkCodeImmediately() {
    print('🔍 Checking verification code:');
    print('   User ID: ${widget.userId}');

    FirebaseDatabase.instance.ref("verifications/${widget.userId}").get().then((snapshot) {
      if (snapshot.exists) {
        final data = snapshot.value as Map<dynamic, dynamic>;
        print('✅ Code exists: ${data['code']}');
        print('✅ Expires at: ${DateTime.fromMillisecondsSinceEpoch(data['expiresAt'])}');
      } else {
        print('❌ No code found - login page issue');
      }
    });
  }

  void _setupFocusNodes() {
    for (int i = 0; i < _focusNodes.length; i++) {
      _focusNodes[i].addListener(() {
        if (!_focusNodes[i].hasFocus && i < _focusNodes.length - 1) {
          _focusNodes[i + 1].requestFocus();
        }
      });
    }
  }

  Future<bool> _verifyCode() async {
    try {
      String enteredCode = _controllers.map((controller) => controller.text).join();
      print('🔍 Verifying code: $enteredCode');

      DatabaseReference ref = FirebaseDatabase.instance.ref("verifications/${widget.userId}");
      DatabaseEvent snapshot = await ref.once();

      if (!snapshot.snapshot.exists) {
        print('❌ No code found');
        return false;
      }

      Map<dynamic, dynamic> data = snapshot.snapshot.value as Map<dynamic, dynamic>;
      String storedCode = data['code']?.toString() ?? '';
      int expiresAt = data['expiresAt'] ?? 0;

      // 1. Check code match
      if (enteredCode != storedCode) {
        print('❌ Code mismatch');
        return false;
      }

      print('✅ Code matches');

      // 2. Check expiry
      int currentTime = DateTime.now().millisecondsSinceEpoch;
      int safetyMargin = 120000; // 2 minutes

      if (currentTime < (expiresAt + safetyMargin)) {
        print('✅ Code is valid');
        return true;
      } else {
        print('❌ Code expired');
        return false;
      }

    } catch (e) {
      print('❌ Error: $e');
      return false;
    }
  }

  Future<void> _verifyAndProceed() async {
    setState(() {
      _isLoading = true;
      _errorMessage = '';
    });

    try {
      bool isValid = await _verifyCode();

      if (isValid) {
        print('✅ Verification successful!');

        // 1. حذف الكود من Firebase
        await FirebaseDatabase.instance
            .ref("verifications/${widget.userId}")
            .remove();

        // 2. تأخير قصير للسماح بالمعالجة
        await Future.delayed(Duration(milliseconds: 500));

        // 3. تنفيذ callback النجاح - هام جداً!
        print('🚀 Calling verification success callback...');

        if (mounted) {
          Navigator.pushNamedAndRemoveUntil(
            context,
            '/home', // تأكد أن لديك route باسم home
                (route) => false,
          );
        }

      } else {
        setState(() {
          _errorMessage = 'Verification code is incorrect or has expired';
        });
      }
    } catch (e) {
      setState(() {
        _errorMessage = 'Verification failed: $e';
      });
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  Future<void> _resendCode() async {
    setState(() {
      _isResending = true;
      _errorMessage = '';
    });

    try {
      final random = Random();
      final newCode = (100000 + random.nextInt(900000)).toString();

      DatabaseReference verificationRef = FirebaseDatabase.instance.ref("verifications/${widget.userId}");

      // ✅ FIX: Use proper time calculation
      int createdAt = DateTime.now().millisecondsSinceEpoch;
      int expiresAt = createdAt + (10 * 60 * 1000); // 10 minutes in milliseconds

      await verificationRef.set({
        'code': newCode,
        'email': widget.email,
        'createdAt': createdAt,
        'expiresAt': expiresAt, // ✅ Fixed: مستقبلي وليس مضبوط بشكل خاطئ
      });

      // Send code via email service
      bool emailSent = await VerificationEmailService.sendVerificationCode(
        userEmail: widget.email,
        code: newCode,
      );

      if (!emailSent) {
        setState(() { _errorMessage = 'Failed to send email. Please try again.'; });
        return;
      }

      print('✅ Code sent via email service!');
      print('📝 Code: $newCode');
      print('⏰ Created at: ${DateTime.fromMillisecondsSinceEpoch(createdAt)}');
      print('⏰ Expires at: ${DateTime.fromMillisecondsSinceEpoch(expiresAt)}');

      // Clear fields
      for (var controller in _controllers) {
        controller.clear();
      }
      if (_focusNodes.isNotEmpty) {
        _focusNodes[0].requestFocus();
      }

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('New verification code sent!'),
          backgroundColor: Colors.green,
        ),
      );

    } catch (e) {
      setState(() {
        _errorMessage = 'Failed to resend code: $e';
      });
    } finally {
      setState(() {
        _isResending = false;
      });
    }
  }

  void _onFieldChanged(int index, String value) {
    if (value.length == 1 && index < _controllers.length - 1) {
      _focusNodes[index + 1].requestFocus();
    } else if (value.isEmpty && index > 0) {
      _focusNodes[index - 1].requestFocus();
    }

    // Auto-verify when all fields are filled
    if (_controllers.every((controller) => controller.text.isNotEmpty)) {
      _verifyAndProceed();
    }
  }

  @override
  Widget build(BuildContext context) {
    print('🏗️ Building EmailVerificationScreen');
    print('📧 Email: ${widget.email}');
    print('👤 UserId: ${widget.userId}');
    return Scaffold(
      appBar: AppBar(
        title: Text('Email Verification'),
        backgroundColor: Color(0xFF914D74),
      ),
      body: Padding(
        padding: EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Verify Your Email',
              style: TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.bold,
                color: Color(0xFF914D74),
              ),
            ),
            SizedBox(height: 16),
            // 🔴 Changed text from 4 to 6 digits
            Text(
              'A 6-digit verification code has been sent to:',
              style: TextStyle(fontSize: 16, color: Colors.grey[700]),
            ),
            SizedBox(height: 8),
            Text(
              widget.email,
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: Color(0xFF914D74),
              ),
            ),

            SizedBox(height: 32),

            // 🔴 Code input fields - 6 fields instead of 4
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: List.generate(6, (index) {
                return SizedBox(
                  width: 45,
                  child: TextField(
                    controller: _controllers[index],
                    focusNode: _focusNodes[index],
                    textAlign: TextAlign.center,
                    keyboardType: TextInputType.number,
                    maxLength: 1,
                    decoration: InputDecoration(
                      counterText: '',
                      border: OutlineInputBorder(),
                      focusedBorder: OutlineInputBorder(
                        borderSide: BorderSide(color: Color(0xFF914D74), width: 2),
                      ),
                    ),
                    onChanged: (value) => _onFieldChanged(index, value),
                  ),
                );
              }),
            ),

            SizedBox(height: 16),

            if (_errorMessage.isNotEmpty)
              Container(
                padding: EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.red[50],
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.red),
                ),
                child: Row(
                  children: [
                    Icon(Icons.error, color: Colors.red),
                    SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        _errorMessage,
                        style: TextStyle(color: Colors.red),
                      ),
                    ),
                  ],
                ),
              ),

            SizedBox(height: 24),

            // Verify Button
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: _isLoading ? null : _verifyAndProceed,
                style: ElevatedButton.styleFrom(
                  backgroundColor: Color(0xFF914D74),
                  foregroundColor: Colors.white,
                  padding: EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                child: _isLoading
                    ? SizedBox(
                  height: 20,
                  width: 20,
                  child: CircularProgressIndicator(
                    color: Colors.white,
                    strokeWidth: 2,
                  ),
                )
                    : Text(
                  'Verify',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                ),
              ),
            ),

            SizedBox(height: 16),

            // Resend Button
            Center(
              child: TextButton(
                onPressed: _isResending ? null : _resendCode,
                child: _isResending
                    ? CircularProgressIndicator()
                    : Text(
                  "Didn't receive code? Resend",
                  style: TextStyle(
                    color: Color(0xFF914D74),
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  void dispose() {
    for (var controller in _controllers) {
      controller.dispose();
    }
    for (var focusNode in _focusNodes) {
      focusNode.dispose();
    }
    super.dispose();
  }
}