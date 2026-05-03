// screens/user_provider.dart
import 'package:flutter/material.dart';

class UserProvider with ChangeNotifier {
  String? _userId;
  String? _userRole='user';

  String? get userId => _userId;
  String? get userRole => _userRole;

  void setUser(String userId, String userRole) {
    _userId = userId;
    _userRole = userRole;
    notifyListeners();
  }

  void clearUser() {
    _userId = null;
    _userRole = 'user';
    notifyListeners();
  }

  // دالة مساعدة للتحقق إذا كان المستخدم أدمن
  bool get isAdmin => _userRole == 'admin';
}