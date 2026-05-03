import 'dart:convert';
import 'dart:math';

import 'package:firebase_database/firebase_database.dart';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:provider/provider.dart';
import 'package:skinglow/Screens/EmailVerificationScreen.dart';
import 'package:skinglow/Screens/verification_email_service.dart';
import 'DatabaseHelper.dart';

import 'Home.dart';
import 'Registration.dart';
import 'cart_model.dart';
import 'favorites_model.dart';
import 'forgot_password.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:firebase_auth/firebase_auth.dart';


class LoginPage extends StatefulWidget {
  const LoginPage({super.key});

  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  final _formKey = GlobalKey<FormState>();
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();
  bool _obscurePassword = true;
  bool _isLoading = false;

  // دالة لعرض السناك بار مع تصميم محسن
  void _showSnackBar(String message, {bool isError = true}) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          message,
          style: TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.w500,
          ),
        ),
        backgroundColor: isError ? Colors.red.shade600 : Colors.green.shade600,
        duration: Duration(seconds: 4),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
        ),
        margin: EdgeInsets.all(16),
        elevation: 6,
      ),
    );
  }

  bool _isAdminEmail(String email) {
    List<String> adminEmails = [
      'oorro137@gmail.com',
      'admin@skinglow.com',
    ];
    return adminEmails.contains(email);
  }

  String _encodeEmail(String email) {
    return base64Url.encode(utf8.encode(email))
        .replaceAll('=', '')
        .replaceAll('/', '_')
        .replaceAll('+', '-');
  }

  String _decodeEmail(String encodedEmail) {
    try {
      String padded = encodedEmail;
      int mod = padded.length % 4;
      if (mod != 0) {
        padded += '=' * (4 - mod);
      }
      return utf8.decode(base64Url.decode(padded));
    } catch (e) {
      print('Error decoding email: $e');
      return encodedEmail;
    }
  }

  Future<String> getUserRole(String uid) async {
    try {
      DatabaseReference userRef = FirebaseDatabase.instance.ref("users/$uid");
      DatabaseEvent snapshot = await userRef.once();

      if (snapshot.snapshot.value != null) {
        Map<dynamic, dynamic> userData = snapshot.snapshot.value as Map<dynamic, dynamic>;
        return userData['role'] ?? 'user';
      }
      return 'user';
    } catch (e) {
      print('Error getting user role: $e');
      return 'user';
    }
  }

  Future<void> _updateUserRole(String uid, String email) async {
    try {
      DatabaseReference userRef = FirebaseDatabase.instance.ref("users/$uid");
      String role = _isAdminEmail(email) ? 'admin' : 'user';

      await userRef.update({
        'role': role,
        'lastLogin': DateTime.now().toString(),
      });
      print('✅ User role updated to: $role');
    } catch (e) {
      print('❌ Error updating user role: $e');
    }
  }

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _login() async {
    if (!_formKey.currentState!.validate()) {
      _showSnackBar('Please check your information and try again');
      return;
    }

    setState(() => _isLoading = true);

    try {
      // محاولة تسجيل الدخول
      await DatabaseHelper.signInWithEmailAndPassword(
        email: _emailController.text.trim(),
        password: _passwordController.text.trim(),
      );

      final user = FirebaseAuth.instance.currentUser;
      if (user != null) {
        await _updateUserRole(user.uid, user.email!);

        // تحديث بيانات المستخدم في قاعدة البيانات إذا لم يكن موجوداً
        DatabaseReference userRef = FirebaseDatabase.instance.ref("users/${user.uid}");
        DatabaseEvent snapshot = await userRef.once();

        if (snapshot.snapshot.value == null) {
          String role = _isAdminEmail(user.email!) ? 'admin' : 'user';
          await userRef.set({
            "email": user.email,
            "uid": user.uid,
            "role": role,
            "createdAt": DateTime.now().toString(),
          });
        }

        // إعداد بيانات السلة والمفضلة
        final cart = Provider.of<Cart>(context, listen: false);
        final favorites = Provider.of<Favorites>(context, listen: false);
        cart.setUserId(user.uid);
        favorites.setUserId(user.uid);

        // عرض رسالة نجاح
        _showSnackBar('Welcome back! Login successful', isError: false);

        // الانتقال بعد عرض رسالة النجاح
        await Future.delayed(Duration(milliseconds: 1500));

        if (!mounted) return;
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (context) => const Home()),
        );
      }
    } on FirebaseAuthException catch (e) {
      String errorMessage;
      switch (e.code) {
        case 'user-not-found':
          errorMessage = 'This email is not registered. Please sign up first.';
          break;
        case 'wrong-password':
          errorMessage = 'Incorrect password. Please try again.';
          break;
        case 'invalid-email':
          errorMessage = 'Please enter a valid email address.';
          break;
        case 'user-disabled':
          errorMessage = 'This account has been disabled. Contact support.';
          break;
        case 'too-many-requests':
          errorMessage = 'Too many login attempts. Please try again later.';
          break;
        case 'network-request-failed':
          errorMessage = 'Network error. Please check your internet connection.';
          break;
        default:
          errorMessage = 'Login failed. Please check your information.';
      }
      _showSnackBar(errorMessage);
    } catch (e) {
      // التعامل مع الأخطاء العامة بشكل أكثر تحديداً
      print('Login error: $e');
      String errorMessage = 'An unexpected error occurred. Please try again.';

      // تحويل الخطأ إلى سلسلة نصية للتحقق من محتواه
      String errorString = e.toString();

      if (errorString.contains('user-not-found') ||
          errorString.contains('no user record')) {
        errorMessage = 'This email is not registered. Please sign up first.';
      } else if (errorString.contains('wrong-password') ||
          errorString.contains('password is invalid')) {
        errorMessage = 'Incorrect password. Please try again.';
      } else if (errorString.contains('network') ||
          errorString.contains('connection')) {
        errorMessage = 'Network error. Please check your internet connection.';
      }

      _showSnackBar(errorMessage);
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  Future<void> _loginImproved() async {
    if (!_formKey.currentState!.validate()) {
      _showSnackBar('Please check your information and try again');
      return;
    }

    setState(() => _isLoading = true);

    try {
      final email = _emailController.text.trim();
      final password = _passwordController.text.trim();

      // أولاً: التحقق من تنسيق الإيميل
      if (!RegExp(r'^[\w-\.]+@([\w-]+\.)+[\w-]{2,4}$').hasMatch(email)) {
        _showSnackBar('Please enter a valid email address');
        setState(() => _isLoading = false);
        return;
      }

      // 1. محاولة تسجيل الدخول مع Firebase Authentication
      UserCredential userCredential = await FirebaseAuth.instance
          .signInWithEmailAndPassword(email: email, password: password);

      final User? user = userCredential.user;
      if (user != null) {
        // ✅ **بداية نظام التحقق (2FA)**
        // 2. توليد كود تحقق عشوائي مكون من 6 أرقام
        final String verificationCode = (100000 + Random().nextInt(900000)).toString();
        print('✅ [2FA] Generated code for $email: $verificationCode');

        // 3. حفظ الكود في Firebase
        await FirebaseDatabase.instance.ref("verifications/${user.uid}").set({
          'code': verificationCode,
          'email': email,
          'createdAt': DateTime.now().millisecondsSinceEpoch,
          'expiresAt': DateTime.now().add(Duration(minutes: 3)).millisecondsSinceEpoch,
        });

        // 4. إرسال الكود عبر البريد باستخدام خدمة التحقق الجديدة
        // 🔴 تأكد من وجود هذا الاستيراد في الأعلى: import 'services/verification_email_service.dart';
        bool codeSent = await VerificationEmailService.sendVerificationCode(
          userEmail: email,
          code: verificationCode,
        );

        if (codeSent && mounted) {
          // 5. أوقف مؤشر التحميل أولاً
          setState(() => _isLoading = false);
          print('✅ [2FA] Email sent. Going to verification screen.');

          // 6. الانتقال إلى شاشة إدخال الكود
          Navigator.of(context).pushReplacement(
            MaterialPageRoute(
              builder: (context) => EmailVerificationScreen(
                userId: user.uid,
                email: email,
                onVerificationSuccess: () async {
                  // 🔥 هذا الـ callback هو الذي سينفذ بعد التحقق الناجح

                  print('🎉 Verification callback called!');

                  // تحديث دور المستخدم
                  await _updateUserRole(user.uid, user.email!);

                  // التحقق من وجود بيانات المستخدم
                  DatabaseReference userRef = FirebaseDatabase.instance.ref("users/${user.uid}");
                  DatabaseEvent snapshot = await userRef.once();

                  if (snapshot.snapshot.value == null) {
                    String role = _isAdminEmail(user.email!) ? 'admin' : 'user';
                    await userRef.set({
                      "email": user.email,
                      "uid": user.uid,
                      "role": role,
                      "createdAt": DateTime.now().toString(),
                    });
                  }

                  // إعداد السلة والمفضلة
                  final cart = Provider.of<Cart>(context, listen: false);
                  final favorites = Provider.of<Favorites>(context, listen: false);
                  cart.setUserId(user.uid);
                  favorites.setUserId(user.uid);

                  // الانتقال للهوم
                  if (!mounted) return;
                  Navigator.pushReplacement(
                    context,
                    MaterialPageRoute(builder: (context) => const Home()),
                  );
                },
              ),
            ),
          );
        } else {
          // إذا فشل إرسال البريد
          if (mounted) {
            print('❌ [2FA] Failed to send verification email.');
            _showSnackBar('Failed to send verification code. Please try again.');
            setState(() => _isLoading = false);
          }
        }
      }
    } on FirebaseAuthException catch (e) {
      // معالجة أخطاء Firebase Auth الأصلية
      String errorMessage;
      switch (e.code) {
        case 'user-not-found':
          errorMessage = 'This email is not registered. Please sign up first.';
          break;
        case 'wrong-password':
          errorMessage = 'Incorrect password. Please try again.';
          break;
        default:
          errorMessage = 'Login failed: ${e.message}';
      }
      _showSnackBar(errorMessage);
      if (mounted) {
        setState(() => _isLoading = false);
      }
    } catch (e) {
      print('❌ [2FA] Unexpected error: $e');
      _showSnackBar('An unexpected error occurred. Please try again.');
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  void _handleAuthError(FirebaseAuthException e) {
    String errorMessage;
    switch (e.code) {
      case 'user-not-found':
        errorMessage = 'This email is not registered. Please sign up first.';
        break;
      case 'wrong-password':
        errorMessage = 'Incorrect password. Please try again.';
        break;
      case 'invalid-email':
        errorMessage = 'Please enter a valid email address.';
        break;
      case 'user-disabled':
        errorMessage = 'This account has been disabled. Contact support.';
        break;
      case 'too-many-requests':
        errorMessage = 'Too many login attempts. Please try again later.';
        break;
      case 'network-request-failed':
        errorMessage = 'Network error. Please check your internet connection.';
        break;
      case 'invalid-credential':
        errorMessage = 'Invalid email or password. Please try again.';
        break;
      default:
        errorMessage = 'Login failed. Please check your information.';
    }
    _showSnackBar(errorMessage);
  }


  Future<void> _sendVerificationCode(String userId, String email) async {
    final random = Random();
    final verificationCode = (1000 + random.nextInt(9000)).toString();

    // 1. عرض الكود في الـ Logs
    print('🎯 Verification code for $email is: $verificationCode');

    // 2. حفظ في Firebase محلي
    await FirebaseDatabase.instance.ref("verifications/$userId").set({
      'code': verificationCode,
      'email': email,
    });

    // 3. عرض تنبيه للمستخدم
    _showSnackBar('Verification code for $verificationCode (It was shown in logs)');
  }
// ✅ دالة إرسال الإيميل
  Future<void> _sendEmailVerification(String email, String code) async {
    try {
      // استخدم EmailJS أو أي خدمة إيميلات
      print('📧 Sending verification email to: $email');
      print('🔐 Verification Code: $code');

      // حفظ في Firebase للاختبار
      await FirebaseDatabase.instance.ref("email_logs").push().set({
        'email': email,
        'code': code,
        'type': 'verification',
        'sentAt': DateTime.now().millisecondsSinceEpoch,
      });

    } catch (e) {
      print('❌ Error sending email: $e');
    }
  }

// ✅ بعد التحقق الناجح
  void _onVerificationSuccess(User user) async {
    try {
      await _updateUserRole(user.uid, user.email!);

      // تحديث بيانات المستخدم في قاعدة البيانات إذا لم يكن موجوداً
      DatabaseReference userRef = FirebaseDatabase.instance.ref("users/${user.uid}");
      DatabaseEvent snapshot = await userRef.once();

      if (snapshot.snapshot.value == null) {
        String role = _isAdminEmail(user.email!) ? 'admin' : 'user';
        await userRef.set({
          "email": user.email,
          "uid": user.uid,
          "role": role,
          "createdAt": DateTime.now().toString(),
        });
      }

      // إعداد بيانات السلة والمفضلة
      final cart = Provider.of<Cart>(context, listen: false);
      final favorites = Provider.of<Favorites>(context, listen: false);
      cart.setUserId(user.uid);
      favorites.setUserId(user.uid);

      // عرض رسالة نجاح
      _showSnackBar('Welcome back! Login successful', isError: false);

      // الانتقال للهوم
      if (!mounted) return;
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (context) => const Home()),
      );

    } catch (e) {
      print('❌ Error in verification success: $e');
    }
  }

  Future<void> signInWithGoogle(BuildContext context) async {
    try {
      await GoogleSignIn().signOut();
      final GoogleSignInAccount? googleUser = await GoogleSignIn().signIn();
      if (googleUser == null) return;

      final GoogleSignInAuthentication googleAuth = await googleUser.authentication;
      final credential = GoogleAuthProvider.credential(
        accessToken: googleAuth.accessToken,
        idToken: googleAuth.idToken,
      );

      UserCredential userCredential = await FirebaseAuth.instance.signInWithCredential(credential);
      User? user = userCredential.user;
      if (user == null) return;

      print("✅ Google login successful");

      // تحديث بيانات المستخدم
      await _updateUserRole(user.uid, user.email!);

      final cart = Provider.of<Cart>(context, listen: false);
      final favorites = Provider.of<Favorites>(context, listen: false);
      cart.setUserId(user.uid);
      favorites.setUserId(user.uid);

      // التحقق من وجود المستخدم في قاعدة البيانات
      DatabaseReference userRef = FirebaseDatabase.instance.ref("users/${user.uid}");
      DatabaseEvent snapshot = await userRef.once();

      if (snapshot.snapshot.value == null) {
        String role = _isAdminEmail(user.email!) ? 'admin' : 'user';
        await userRef.set({
          "email": user.email,
          "uid": user.uid,
          "role": role,
          "createdAt": DateTime.now().toString(),
        });
        print("✅ Google user data saved to database");
      }

      // عرض رسالة نجاح
      _showSnackBar('Google sign-in successful!', isError: false);

      // الانتقال بعد عرض رسالة النجاح
      await Future.delayed(Duration(milliseconds: 1500));

      // الانتقال مباشرة للهوم
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (context) => Home()),
      );

    } catch (e) {
      print("❌ Google sign in error: $e");
      _showSnackBar('Google sign-in failed. Please try again.');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              Color(0xFFFFF0F8),
              Color(0xFFFFE4F3),
              Colors.white,
            ],
          ),
        ),
        child: SingleChildScrollView(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              children: [
                SizedBox(height: 60),
                Container(
                  padding: EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    shape: BoxShape.circle,
                    boxShadow: [
                      BoxShadow(
                        color: Colors.pink.withOpacity(0.1),
                        blurRadius: 10,
                        spreadRadius: 2,
                      ),
                    ],
                  ),
                  child: CircleAvatar(
                    radius: 40,
                    backgroundImage: AssetImage('images/logoskinglow.jpg'),
                  ),
                ),
                SizedBox(height: 20),
                Text(
                  "Skinglow",
                  style: TextStyle(
                    fontSize: 32,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF914D74),
                    fontStyle: FontStyle.italic,
                  ),
                ),
                SizedBox(height: 40),
                Container(
                  padding: EdgeInsets.all(24),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(16),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.grey.withOpacity(0.1),
                        blurRadius: 10,
                        spreadRadius: 2,
                      ),
                    ],
                  ),
                  child: Form(
                    key: _formKey,
                    child: Column(
                      children: [
                        Text(
                          "Sign In",
                          style: TextStyle(
                            fontSize: 24,
                            fontWeight: FontWeight.bold,
                            color: Color(0xFF914D74),
                          ),
                        ),
                        SizedBox(height: 24),
                        TextFormField(
                          controller: _emailController,
                          keyboardType: TextInputType.emailAddress,
                          decoration: InputDecoration(
                            labelText: 'Email Address',
                            labelStyle: TextStyle(color: Color(0xFF914D74)),
                            prefixIcon: Icon(Icons.email, color: Color(0xFF914D74)),
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                              borderSide: BorderSide(color: Color(0xFF914D74)),
                            ),
                            focusedBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                              borderSide: BorderSide(color: Color(0xFF914D74), width: 2),
                            ),
                            hintText: 'Enter your email',
                          ),
                          validator: (value) {
                            if (value == null || value.trim().isEmpty) {
                              return 'Please enter your email address';
                            }
                            if (!RegExp(r'^[\w-\.]+@([\w-]+\.)+[\w-]{2,4}$').hasMatch(value.trim())) {
                              return 'Please enter a valid email address';
                            }
                            return null;
                          },
                        ),
                        SizedBox(height: 16),
                        TextFormField(
                          controller: _passwordController,
                          obscureText: _obscurePassword,
                          decoration: InputDecoration(
                            labelText: 'Password',
                            labelStyle: TextStyle(color: Color(0xFF914D74)),
                            prefixIcon: Icon(Icons.lock, color: Color(0xFF914D74)),
                            suffixIcon: IconButton(
                              icon: Icon(
                                _obscurePassword ? Icons.visibility_off : Icons.visibility,
                                color: Color(0xFF914D74),
                              ),
                              onPressed: () {
                                setState(() => _obscurePassword = !_obscurePassword);
                              },
                            ),
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                              borderSide: BorderSide(color: Color(0xFF914D74)),
                            ),
                            focusedBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                              borderSide: BorderSide(color: Color(0xFF914D74), width: 2),
                            ),
                            hintText: 'Enter your password',
                          ),
                          validator: (value) {
                            if (value == null || value.isEmpty) {
                              return 'Please enter your password';
                            }
                            if (value.length < 6) {
                              return 'Password must be at least 6 characters';
                            }
                            return null;
                          },
                        ),
                        SizedBox(height: 16),
                        Align(
                          alignment: Alignment.centerRight,
                          child: TextButton(
                            onPressed: () => Navigator.push(
                              context,
                              MaterialPageRoute(builder: (context) => const ForgotPassword()),
                            ),
                            child: Text(
                              "Forgot Password?",
                              style: TextStyle(
                                color: Color(0xFF914D74),
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                        ),
                        SizedBox(height: 16),
                        SizedBox(
                          width: double.infinity,
                          child: ElevatedButton(
                            onPressed: _isLoading ? null : _loginImproved, // استخدم الدالة المحسنة
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Color(0xFF914D74),
                              foregroundColor: Colors.white,
                              padding: EdgeInsets.symmetric(vertical: 16),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                              elevation: 3,
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
                              'Sign In',
                              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                            ),
                          ),
                        ),
                        SizedBox(height: 24),
                        Row(
                          children: [
                            Expanded(
                              child: Divider(
                                color: Colors.grey[400],
                                thickness: 1,
                              ),
                            ),
                            Padding(
                              padding: const EdgeInsets.symmetric(horizontal: 15),
                              child: Text(
                                "Or continue with",
                                style: TextStyle(
                                  color: Colors.grey[700],
                                ),
                              ),
                            ),
                            Expanded(
                              child: Divider(
                                color: Colors.grey[400],
                                thickness: 1,
                              ),
                            ),
                          ],
                        ),
                        SizedBox(height: 24),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            InkWell(
                              onTap: () => signInWithGoogle(context),
                              child: Container(
                                padding: EdgeInsets.all(12),
                                decoration: BoxDecoration(
                                  color: Colors.white,
                                  shape: BoxShape.circle,
                                  boxShadow: [
                                    BoxShadow(
                                      color: Colors.black12,
                                      blurRadius: 4,
                                      offset: Offset(0, 2),
                                    ),
                                  ],
                                ),
                                child: Image.asset(
                                  'images/google.png',
                                  height: 24,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
                SizedBox(height: 24),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      "Don't have an account? ",
                      style: TextStyle(color: Colors.grey[700]),
                    ),
                    TextButton(
                      onPressed: () => Navigator.push(
                        context,
                        MaterialPageRoute(builder: (context) => const SignUpPage()),
                      ),
                      child: Text(
                        "Sign Up",
                        style: TextStyle(
                          color: Color(0xFF914D74),
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
