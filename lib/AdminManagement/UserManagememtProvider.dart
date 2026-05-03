// providers/user_management_provider.dart
import 'package:flutter/foundation.dart';
import 'package:firebase_database/firebase_database.dart';

import '../Screens/user_model.dart';

class UserManagementProvider with ChangeNotifier {
  List<UserModel> _users = [];
  List<UserModel> _filteredUsers = [];
  bool _isLoading = false;
  String _searchQuery = '';
  String _currentFilter = 'all';

  List<UserModel> get users => _users;
  List<UserModel> get filteredUsers => _filteredUsers;
  bool get isLoading => _isLoading;
  String get currentFilter => _currentFilter;

  int get totalUsers => _users.length;
  int get activeUsers => _users.where((user) => user.isActive).length;
  int get adminUsers => _users.where((user) => user.role == 'admin').length;

  UserManagementProvider() {
    print('🔄 UserManagementProvider initialized');
    fetchAllUsers();
  }

  Future<void> fetchAllUsers() async {
    _isLoading = true;
    notifyListeners();

    try {
      print('📡 Fetching users from Firebase...');
      DatabaseReference usersRef = FirebaseDatabase.instance.ref("users");
      DatabaseEvent snapshot = await usersRef.once();

      print('📊 Firebase response: ${snapshot.snapshot.value}');

      if (snapshot.snapshot.value != null) {
        Map<dynamic, dynamic> usersData = snapshot.snapshot.value as Map<dynamic, dynamic>;

        print('👥 Found ${usersData.length} users in database');

        _users = usersData.entries.map((entry) {
          print('📝 Processing user: ${entry.key} - ${entry.value}');
          return UserModel.fromFirebase(
            Map<String, dynamic>.from(entry.value),
            entry.key.toString(),
          );
        }).toList();

        print('✅ Successfully loaded ${_users.length} users');
        _applyFilters();
      } else {
        print('❌ No users found in database');
        _users = [];
        _filteredUsers = [];
      }
    } catch (e) {
      print('❌ Error fetching users: $e');
      _users = [];
      _filteredUsers = [];
    } finally {
      _isLoading = false;
      notifyListeners();
      print('🏁 Fetch completed. Total users: ${_users.length}');
    }
  }

  // ... rest of your provider methods remain the same
  void searchUsers(String query) {
    _searchQuery = query.toLowerCase();
    _applyFilters();
  }

  void filterUsers(String filter) {
    _currentFilter = filter;
    _applyFilters();
  }

  void _applyFilters() {
    List<UserModel> result = _users;

    if (_searchQuery.isNotEmpty) {
      result = result.where((user) =>
      user.name.toLowerCase().contains(_searchQuery) ||
          user.email.toLowerCase().contains(_searchQuery) ||
          user.mobilePhoneNumber.contains(_searchQuery)
      ).toList();
    }

    switch (_currentFilter) {
      case 'admins':
        result = result.where((user) => user.role == 'admin').toList();
        break;
      case 'active':
        result = result.where((user) => user.isActive).toList();
        break;
      case 'inactive':
        result = result.where((user) => !user.isActive).toList();
        break;
      case 'all':
      default:
        break;
    }

    _filteredUsers = result;
    print('🔍 Filters applied. Showing ${_filteredUsers.length} users');
    notifyListeners();
  }

  Future<void> updateUserRole(String uid, String newRole) async {
    try {
      DatabaseReference userRef = FirebaseDatabase.instance.ref("users/$uid");
      await userRef.update({
        'role': newRole,
        'lastLogin': DateTime.now().toString(),
      });

      final index = _users.indexWhere((user) => user.uid == uid);
      if (index != -1) {
        _users[index] = _users[index].copyWith(role: newRole);
        _applyFilters();
      }
    } catch (e) {
      print('Error updating user role: $e');
      rethrow;
    }
  }

  Future<void> toggleUserStatus(String uid, bool isActive) async {
    try {
      DatabaseReference userRef = FirebaseDatabase.instance.ref("users/$uid");
      await userRef.update({
        'isActive': isActive,
      });

      final index = _users.indexWhere((user) => user.uid == uid);
      if (index != -1) {
        _users[index] = _users[index].copyWith(isActive: isActive);
        _applyFilters();
      }
    } catch (e) {
      print('Error toggling user status: $e');
      rethrow;
    }
  }

  Future<void> deleteUser(String uid) async {
    try {
      DatabaseReference userRef = FirebaseDatabase.instance.ref("users/$uid");
      await userRef.remove();

      _users.removeWhere((user) => user.uid == uid);
      _applyFilters();
    } catch (e) {
      print('Error deleting user: $e');
      rethrow;
    }
  }
}