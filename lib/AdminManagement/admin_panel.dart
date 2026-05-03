// screens/admin/admin_panel.dart
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../Screens/profile.dart';
import 'DiscountManagementScreen.dart';
import 'FirebaseDataUploader.dart';
import 'OrdersManagement.dart';
import 'SalesReports.dart';
import 'UserManagement.dart';
import 'VirtualCardsUploadPage.dart';
import 'add_product_screen.dart';

class AdminPanel extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Admin Control Panel'),
        backgroundColor: Color(0xFF914D74),
        actions: [
          IconButton(
            icon: Icon(Icons.person),
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => ProfilePage()),
              );
            },
            tooltip: 'Personal Profile',
          ),
          IconButton(
            icon: Icon(Icons.logout),
            onPressed: () {
              _showLogoutDialog(context);
            },
            tooltip: 'Logout',
          ),
        ],
      ),
      body: Padding(
        padding: EdgeInsets.all(16),
        child: GridView.count(
          crossAxisCount: 2,
          crossAxisSpacing: 16,
          mainAxisSpacing: 16,
          children: [
            _buildAdminCard(
              icon: Icons.add_box,
              title: 'Add Product',
              color: Colors.green,
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (context) => AddProductScreen()),
                );
              },
            ),
            _buildAdminCard(
              icon: Icons.shopping_cart,
              title: 'Orders Management',
              color: Colors.blue,
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (context) => OrdersManagementScreen()),
                );
              },
            ),
            _buildAdminCard(
              icon: Icons.edit,
              title: 'User Management',
              color: Colors.orange,
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (context) => UserManagementScreen()),
                );
              },
            ),
            _buildAdminCard(
              icon: Icons.analytics,
              title: 'Sales Reports',
              color: Colors.purple,
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (context) => SalesReportsScreen()),
                );
              },
            ),
            _buildAdminCard(
              icon: Icons.discount,
              title: 'Discount Management',
              color: Colors.red,
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (context) => DiscountManagementScreen()),
                );
              },
            ),
            _buildAdminCard(
              icon: Icons.cloud_upload,
              title: 'Upload Cards',
              color: Colors.teal,
              onTap: () async {
                // Show loading message
                showDialog(
                  context: context,
                  barrierDismissible: false,
                  builder: (context) => AlertDialog(
                    title: Row(
                      children: [
                        CircularProgressIndicator(),
                        SizedBox(width: 15),
                        Text('Loading...'),
                      ],
                    ),
                    content: Text('Please wait while cards are being uploaded from JSON file'),
                  ),
                );

                // Execute upload process
                try {
                  await FirebaseDataUploader().uploadVirtualCardsToFirebase();
                  Navigator.of(context).pop(); // Close loading dialog

                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text('✅ Virtual cards uploaded successfully'),
                      backgroundColor: Colors.green,
                    ),
                  );
                } catch (e) {
                  Navigator.of(context).pop(); // Close loading dialog

                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text('❌ Error: $e'),
                      backgroundColor: Colors.red,
                    ),
                  );
                }
              },
            ),/*
            _buildAdminCard(
              icon: Icons.logout,
              title: 'Logout',
              color: Colors.red,
              onTap: () {
                _showLogoutDialog(context);
              },
            ),*/
          ],
        ),
      ),
    );
  }

  void _showLogoutDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: Row(
            children: [
              Icon(Icons.logout, color: Colors.red),
              SizedBox(width: 8),
              Text('Logout'),
            ],
          ),
          content: Text('Are you sure you want to logout from the admin panel?'),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.of(context).pop();
              },
              child: Text('Cancel'),
            ),

            ElevatedButton(
              onPressed: () async {
                Navigator.of(context).pop();
                await _performLogout(context);
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.red,
              ),
              child: Text('Logout'),
            ),
          ],
        );
      },
    );
  }

  Future<void> _performLogout(BuildContext context) async {
    try {
      // إظهار دائرة تحميل
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (BuildContext context) {
          return Dialog(
            child: Padding(
              padding: EdgeInsets.all(20),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  CircularProgressIndicator(),
                  SizedBox(width: 20),
                  Text('Logging out...'),
                ],
              ),
            ),
          );
        },
      );

      // تسجيل الخروج من Firebase
      await FirebaseAuth.instance.signOut();

      // إغلاق dialog التحميل
      Navigator.of(context).pop();

      // العودة لشاشة Login
      Navigator.pushNamedAndRemoveUntil(
        context,
        '/login', // تأكد من تغيير هذا ليتناسب مع routes تطبيقك
            (route) => false,
      );


    } catch (e) {
      // إغلاق dialog التحميل في حالة الخطأ
      if (Navigator.of(context).canPop()) {
        Navigator.of(context).pop();
      }

      // إظهار رسالة خطأ
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error logging out: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  Widget _buildAdminCard({
    required IconData icon,
    required String title,
    required Color color,
    required VoidCallback onTap,
  }) {
    return Card(
      elevation: 4,
      child: InkWell(
        onTap: onTap,
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, size: 50, color: color),
            SizedBox(height: 8),
            Text(
              title,
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}
