import 'dart:convert';
import 'dart:io';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';
import 'package:skinglow/SkinAnalysis/skin_type_provider.dart';
import 'package:skinglow/Screens/user_service.dart';
import '../AdminManagement/admin_panel.dart';
import '../SkinAnalysis/skinAnalysisAi/skin_analysis_py.dart';
import '../SkinAnalysis/skin_history_screen.dart';
import 'Account_Information.dart';
import 'Home.dart';
import 'MyOrder.dart';
import 'NotificationPreferencesPage.dart';
import 'favorite.dart';
import '../SkinAnalysis/skinAnalysis.dart';

class ProfilePage extends StatefulWidget {
  @override
  _ProfilePageState createState() => _ProfilePageState();
}

class _ProfilePageState extends State<ProfilePage> {
  File? _image;
  String? _profileImageBase64;
  String _name = 'Loading...';
  bool _isAdmin = false;

  @override
  void initState() {
    super.initState();
    _loadProfileImage();
    _loadUserData();
    _checkAdminStatus();
    // ✅ تحميل نوع البشرة للمستخدم الحالي
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final skinProvider = context.read<SkinTypeProvider>();
      skinProvider.loadForCurrentUser();
    });
  }

  Future<void> _checkAdminStatus() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user != null) {
      final userRef = FirebaseDatabase.instance.ref('users/${user.uid}');
      final snapshot = await userRef.get();

      if (snapshot.exists && mounted) {
        final userData = snapshot.value as Map<dynamic, dynamic>;
        setState(() {
          _isAdmin = userData['role']?.toString() == 'admin';
        });
      }
    }
  }

  Future<void> _loadUserData() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user != null) {
      final userRef = FirebaseDatabase.instance.ref('users/${user.uid}');
      final snapshot = await userRef.get();

      if (snapshot.exists && mounted) {
        final userData = snapshot.value as Map<dynamic, dynamic>;
        setState(() {
          _name = userData['name'] ?? user.displayName ?? user.email ?? 'User';
        });
      }
    }
  }

  Future<void> _pickImage() async {
    final pickedFile = await ImagePicker().pickImage(source: ImageSource.gallery);
    if (pickedFile != null) {
      final bytes = await File(pickedFile.path).readAsBytes();
      final base64String = base64Encode(bytes);

      if (mounted) {
        setState(() {
          _profileImageBase64 = base64String;
          _image = File(pickedFile.path);
        });
      }

      await _saveImageToDatabase(base64String);
    }
  }

  Future<void> _saveImageToDatabase(String base64String) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user != null) {
      await FirebaseDatabase.instance.ref('users/${user.uid}').update({
        'profileImageBase64': base64String,
      });
    }
  }

  Future<void> _loadProfileImage() async {
    final User? user = FirebaseAuth.instance.currentUser;
    if (user != null) {
      final snapshot = await FirebaseDatabase.instance
          .ref('users/${user.uid}/profileImageBase64')
          .get();

      if (snapshot.exists && mounted) {
        setState(() {
          _profileImageBase64 = snapshot.value.toString();
        });
      }
    }
  }

  Future<void> _showDeleteSkinDataDialog(BuildContext context) async {
    return showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('Delete Skin Data'),
        content: Text('Are you sure you want to delete your skin analysis data?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text('Cancel'),
          ),
          TextButton(
            onPressed: () async {
              final skinProvider = Provider.of<SkinTypeProvider>(context, listen: false);
              final user = FirebaseAuth.instance.currentUser;

              if (user != null) {
                try {
                  // 1. مسح من Firebase
                  await FirebaseDatabase.instance
                      .ref('users/${user.uid}')
                      .update({
                    'skinType': null,
                    'skinProblems': [],
                  });

                  // 2. مسح من SharedPreferences
                  await UserService.clearSkinData();

                  // 3. مسح من Provider
                  await skinProvider.clearSkinData();

                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('Skin data deleted successfully')),
                  );
                } catch (e) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('Error deleting skin data: $e')),
                  );
                }
              }

              Navigator.pop(ctx);
            },
            child: Text(
              'Delete',
              style: TextStyle(color: Colors.red),
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final skinProvider = context.watch<SkinTypeProvider>();
    final user = FirebaseAuth.instance.currentUser;

    return Scaffold(
      appBar: AppBar(
        title: Text('Profile'),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            // ✅ صورة البروفايل والمعلومات
            Row(
              children: [
                GestureDetector(
                  onTap: _pickImage,
                  child: CircleAvatar(
                    radius: 80,
                    backgroundImage: _profileImageBase64 != null
                        ? MemoryImage(base64Decode(_profileImageBase64!))
                        : AssetImage('assets/profile_icon.png') as ImageProvider,
                  ),
                ),
                SizedBox(width: 10),
                Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        _name,
                        style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                      ),
                      SizedBox(height: 10),
                      Text(
                        skinProvider.skinType ?? 'Not analyzed yet',
                        style: TextStyle(
                          fontSize: 20,
                          color: Color(0xFF914D74),
                        ),
                      ),
                      if (_isAdmin)
                        Text(
                          'Admin',
                          style: TextStyle(
                            fontSize: 16,
                            color: Colors.red,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                    ]
                )
              ],
            ),
            SizedBox(height: 20),

            // ✅ قسم معلومات البشرة
            // ✅ قسم معلومات البشرة - مصغّر
            Card(
              child: Padding(
                padding: EdgeInsets.all(12), // تقليل من 16 إلى 12
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          'Skin Information',
                          style: TextStyle(
                            fontSize: 16, // تقليل من 18 إلى 16
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        Icon(Icons.spa, color: Color(0xFF914D74), size: 20), // تصغير الأيقونة
                      ],
                    ),

                    SizedBox(height: 12), // تقليل من 16 إلى 12

                    if (skinProvider.hasSkinType)
                      Column(
                        children: [
                          Row(
                            children: [
                              Icon(Icons.face, color: Color(0xFF914D74), size: 18),
                              SizedBox(width: 6), // تقليل من 8 إلى 6
                              Expanded(
                                child: Text(
                                  'Skin Type: ${skinProvider.skinType}',
                                  style: TextStyle(fontSize: 15), // تقليل من 16 إلى 15
                                ),
                              ),
                            ],
                          ),

                          SizedBox(height: 12), // تقليل من 16 إلى 12

                          // زر حذف بيانات البشرة - مصغّر
                          SizedBox(
                            width: double.infinity, // يجعل الزر يأخذ العرض بالكامل
                            child: ElevatedButton.icon(
                              onPressed: () async {
                                await _showDeleteSkinDataDialog(context);
                              },
                              icon: Icon(Icons.delete_outline, size: 18),
                              label: Text(
                                'Delete Skin Data',
                                style: TextStyle(fontSize: 14),
                              ),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: Colors.red[50],
                                foregroundColor: Colors.red,
                                side: BorderSide(color: Colors.red),
                                padding: EdgeInsets.symmetric(vertical: 10, horizontal: 16),
                                minimumSize: Size(0, 40), // تقليل ارتفاع الزر
                              ),
                            ),
                          ),
                        ],
                      )
                    else
                      Column(
                        children: [
                          SizedBox(height: 8),
                          SizedBox(
                            width: double.infinity,
                            child: ElevatedButton.icon(
                              onPressed: () {
                                Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder: (context) => SkinAnalysisPy(),
                                  ),
                                );
                              },
                              icon: Icon(Icons.camera_alt, size: 18),
                              label: Text(
                                'Analyze Your Skin',
                                style: TextStyle(fontSize: 14),
                              ),
                              style: ElevatedButton.styleFrom(
                                padding: EdgeInsets.symmetric(vertical: 10, horizontal: 16),
                                minimumSize: Size(0, 40), // تقليل ارتفاع الزر
                              ),
                            ),
                          ),
                        ],
                      ),
                  ],
                ),
              ),
            ),

            SizedBox(height: 20),

            // ✅ قائمة الأزرار
            Expanded(
              child: ListView(
                children: [
                  // زر Face Analysis
                  ElevatedButton.icon(
                    onPressed: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => SkinHistoryScreen(),
                        ),
                      );
                    },
                    icon: Icon(Icons.face),
                    label: Text('Face Analysis History'),
                    style: ElevatedButton.styleFrom(
                      foregroundColor: Color(0xFF914D74),
                      minimumSize: Size(400, 100),
                    ),
                  ),
                  SizedBox(height: 10),

                  // زر My Orders
                  ElevatedButton.icon(
                    onPressed: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => MyOrdersPage(),
                        ),
                      );
                    },
                    icon: Icon(Icons.shopping_bag),
                    label: Text('My Orders'),
                    style: ElevatedButton.styleFrom(
                      foregroundColor: Color(0xFF914D74),
                      minimumSize: Size(400, 100),
                    ),
                  ),
                  SizedBox(height: 10),

                  // زر Notification Preferences
                  ElevatedButton.icon(
                    onPressed: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => NotificationPreferencesPage(),
                        ),
                      );
                    },
                    icon: Icon(Icons.notifications),
                    label: Text('Notification Preferences'),
                    style: ElevatedButton.styleFrom(
                      foregroundColor: Color(0xFF914D74),
                      minimumSize: Size(400, 100),
                    ),
                  ),
                  SizedBox(height: 10),

                  // زر Account Information
                  ElevatedButton.icon(
                    onPressed: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => AccountInformationPage(),
                        ),
                      );
                    },
                    icon: Icon(Icons.person),
                    label: Text('Account Information'),
                    style: ElevatedButton.styleFrom(
                      foregroundColor: Color(0xFF914D74),
                      minimumSize: Size(400, 100),
                    ),
                  ),
                  SizedBox(height: 10),

                  // زر Contact Us
                  ElevatedButton.icon(
                    onPressed: () {
                      // TODO: إضافة صفحة التواصل
                    },
                    icon: Icon(Icons.contact_support),
                    label: Text('Contact Us'),
                    style: ElevatedButton.styleFrom(
                      foregroundColor: Color(0xFF914D74),
                      minimumSize: Size(400, 100),
                    ),
                  ),

                  // ✅ زر Admin Panel - يظهر فقط للأدمن
                  if (_isAdmin) ...[
                    SizedBox(height: 10),
                    ElevatedButton.icon(
                      onPressed: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) => AdminPanel(),
                          ),
                        );
                      },
                      icon: Icon(Icons.admin_panel_settings, color: Colors.white),
                      label: Text('Admin Panel'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.red,
                        foregroundColor: Colors.white,
                        minimumSize: Size(400, 100),
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}