// screens/admin/user_management_screen.dart
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../Screens/user_model.dart';
import 'UserManagememtProvider.dart';

class UserManagementScreen extends StatefulWidget {
  const UserManagementScreen({super.key});

  @override
  State<UserManagementScreen> createState() => _UserManagementScreenState();
}

class _UserManagementScreenState extends State<UserManagementScreen> {
  final TextEditingController _searchController = TextEditingController();

  @override
  void initState() {
    super.initState();
    print('🚀 UserManagementScreen initialized');

    // Load data when screen is created
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final provider = Provider.of<UserManagementProvider>(context, listen: false);
      print('📥 Loading users...');
      provider.fetchAllUsers();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('User Management'),
        backgroundColor: Color(0xFF914D74),
        actions: [
          IconButton(
            icon: Icon(Icons.refresh),
            onPressed: () {
              print('🔄 Manual refresh triggered');
              Provider.of<UserManagementProvider>(context, listen: false).fetchAllUsers();
            },
          ),
        ],
      ),
      body: Consumer<UserManagementProvider>(
        builder: (context, userProvider, child) {
          print('🔄 Consumer rebuilt. isLoading: ${userProvider.isLoading}, users: ${userProvider.filteredUsers.length}');

          return Column(
            children: [
              // Search and Filter Bar
              _buildSearchFilterBar(userProvider),

              // Statistics Card
              _buildStatsCard(userProvider),

              // Users List
              Expanded(
                child: _buildUsersList(userProvider),
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _buildSearchFilterBar(UserManagementProvider userProvider) {
    return Padding(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        children: [
          TextField(
            controller: _searchController,
            decoration: InputDecoration(
              hintText: 'Search by name, email or phone...',
              prefixIcon: Icon(Icons.search),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              filled: true,
              fillColor: Colors.grey[50],
            ),
            onChanged: (value) {
              userProvider.searchUsers(value);
            },
          ),
          const SizedBox(height: 12),

          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: [
                _buildFilterChip('All', 'all', userProvider),
                _buildFilterChip('Admins', 'admins', userProvider),
                _buildFilterChip('Users', 'users', userProvider),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFilterChip(String label, String value, UserManagementProvider userProvider) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 4.0),
      child: FilterChip(
        label: Text(label),
        selected: userProvider.currentFilter == value,
        onSelected: (selected) {
          userProvider.filterUsers(value);
        },
        backgroundColor: Colors.grey[300],
        selectedColor: Color(0xFF914D74).withOpacity(0.2),
        checkmarkColor: Color(0xFF914D74),
      ),
    );
  }

  Widget _buildStatsCard(UserManagementProvider userProvider) {
    return Container(
      margin: EdgeInsets.symmetric(horizontal: 16),
      padding: EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withOpacity(0.1),
            blurRadius: 10,
            spreadRadius: 2,
          ),
        ],
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: [
          _buildStatItem('Total', userProvider.totalUsers.toString(), Icons.people),
          _buildStatItem('Admins', userProvider.adminUsers.toString(), Icons.admin_panel_settings, color: Colors.red),
          _buildStatItem('Users', (userProvider.totalUsers - userProvider.adminUsers).toString(), Icons.person, color: Colors.blue),
        ],
      ),
    );
  }

  Widget _buildStatItem(String title, String value, IconData icon, {Color color = Colors.blue}) {
    return Column(
      children: [
        Icon(icon, color: color, size: 24),
        SizedBox(height: 4),
        Text(
          value,
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.bold,
            color: color,
          ),
        ),
        Text(
          title,
          style: TextStyle(
            fontSize: 12,
            color: Colors.grey[600],
          ),
        ),
      ],
    );
  }

  Widget _buildUsersList(UserManagementProvider userProvider) {
    print('📋 Building users list. isLoading: ${userProvider.isLoading}, filteredUsers: ${userProvider.filteredUsers.length}');

    if (userProvider.isLoading) {
      print('⏳ Showing loading indicator');
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            CircularProgressIndicator(),
            SizedBox(height: 16),
            Text('Loading users...'),
          ],
        ),
      );
    }

    if (userProvider.filteredUsers.isEmpty) {
      print('📭 No users to display');
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.people_outline, size: 64, color: Colors.grey[400]),
            SizedBox(height: 16),
            Text(
              userProvider.users.isEmpty ? 'No users found in database' : 'No users match your search',
              style: TextStyle(fontSize: 18, color: Colors.grey[600]),
              textAlign: TextAlign.center,
            ),
            SizedBox(height: 16),
            if (userProvider.users.isEmpty)
              ElevatedButton(
                onPressed: () {
                  userProvider.fetchAllUsers();
                },
                child: Text('Retry'),
              ),
          ],
        ),
      );
    }

    print('✅ Displaying ${userProvider.filteredUsers.length} users');
    return RefreshIndicator(
      onRefresh: () => userProvider.fetchAllUsers(),
      child: ListView.builder(
        itemCount: userProvider.filteredUsers.length,
        itemBuilder: (context, index) {
          final user = userProvider.filteredUsers[index];
          return _buildUserCard(user, userProvider);
        },
      ),
    );
  }

  Widget _buildUserCard(UserModel user, UserManagementProvider userProvider) {
    return Card(
      margin: EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      elevation: 2,
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: _getUserColor(user.role),
          child: Text(
            user.name[0].toUpperCase(),
            style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
          ),
        ),
        title: Text(
          user.name,
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(user.email),
            SizedBox(height: 4),
            Row(
              children: [
                Icon(Icons.phone, size: 12, color: Colors.grey),
                SizedBox(width: 4),
                Text(user.mobilePhoneNumber),
              ],
            ),
          ],
        ),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            _buildRoleBadge(user.role),
            SizedBox(width: 8),
            PopupMenuButton<String>(
              onSelected: (value) => _handleMenuAction(value, user, userProvider),
              itemBuilder: (BuildContext context) => [
                // إزالة عنصر Edit من هنا
                // Only show Remove Admin for admins, no Make Admin option
                if (user.role == 'admin')
                  PopupMenuItem(
                    value: 'remove_admin',
                    child: Row(
                      children: [
                        Icon(Icons.person_remove, color: Colors.orange),
                        SizedBox(width: 8),
                        Text('Remove Admin'),
                      ],
                    ),
                  ),
                PopupMenuItem(
                  value: 'delete',
                  child: Row(
                    children: [
                      Icon(Icons.delete, color: Colors.red),
                      SizedBox(width: 8),
                      Text('Delete'),
                    ],
                  ),
                ),
              ],
            ),
          ],
        ),
        onTap: () {
          _showUserDetails(user);
        },
      ),
    );
  }

  Widget _buildRoleBadge(String role) {
    return Container(
      padding: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: role == 'admin' ? Colors.red : Colors.blue,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(
        role == 'admin' ? 'Admin' : 'User',
        style: TextStyle(color: Colors.white, fontSize: 10),
      ),
    );
  }

  Color _getUserColor(String role) {
    switch (role) {
      case 'admin':
        return Colors.red;
      default:
        return Color(0xFF914D74);
    }
  }

  void _handleMenuAction(String action, UserModel user, UserManagementProvider userProvider) {
    switch (action) {
      case 'remove_admin':
        userProvider.updateUserRole(user.uid, 'user');
        break;
      case 'delete':
        _showDeleteDialog(user, userProvider);
        break;
    }
  }

  void _showUserDetails(UserModel user) {
    showModalBottomSheet(
      context: context,
      builder: (context) => UserDetailsBottomSheet(user: user),
    );
  }

  // إزالة دالة _showEditUserDialog بالكامل

  void _showDeleteDialog(UserModel user, UserManagementProvider userProvider) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Confirm Delete'),
        content: Text('Are you sure you want to delete user ${user.name}?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('Cancel'),
          ),
          TextButton(
            onPressed: () {
              userProvider.deleteUser(user.uid);
              Navigator.pop(context);
            },
            child: Text('Delete', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
  }
}

// User Details Bottom Sheet
class UserDetailsBottomSheet extends StatelessWidget {
  final UserModel user;

  const UserDetailsBottomSheet({super.key, required this.user});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.all(24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          CircleAvatar(
            radius: 40,
            backgroundColor: _getUserColor(user.role),
            child: Text(
              user.name[0].toUpperCase(),
              style: TextStyle(color: Colors.white, fontSize: 24, fontWeight: FontWeight.bold),
            ),
          ),
          SizedBox(height: 16),
          Text(user.name, style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
          Text(user.email, style: TextStyle(color: Colors.grey)),
          SizedBox(height: 16),
          Divider(),
          _buildDetailRow('Phone Number', user.mobilePhoneNumber, Icons.phone),
          _buildDetailRow('Role', _getRoleName(user.role), Icons.admin_panel_settings),
          _buildDetailRow('Created Date', _formatDate(user.createdAt), Icons.calendar_today),
          SizedBox(height: 20),
        ],
      ),
    );
  }

  Widget _buildDetailRow(String title, String value, IconData icon) {
    return Padding(
      padding: EdgeInsets.symmetric(vertical: 8),
      child: Row(
        children: [
          Icon(icon, size: 20, color: Colors.grey),
          SizedBox(width: 12),
          Expanded(
            child: Text(title, style: TextStyle(fontWeight: FontWeight.bold)),
          ),
          Text(value, style: TextStyle(color: Colors.grey[600])),
        ],
      ),
    );
  }

  String _getRoleName(String role) {
    return role == 'admin' ? 'Admin' : 'User';
  }

  String _formatDate(DateTime date) {
    return '${date.day}/${date.month}/${date.year}';
  }

  Color _getUserColor(String role) {
    return role == 'admin' ? Colors.red : Color(0xFF914D74);
  }
}