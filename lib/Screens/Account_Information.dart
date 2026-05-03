import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:skinglow/Screens/payment.dart';
import 'Login.dart';
import 'deliveryDelails.dart';

class AccountInformationPage extends StatefulWidget {
  const AccountInformationPage({Key? key}) : super(key: key);

  @override
  _AccountInformationPageState createState() => _AccountInformationPageState();
}

class _AccountInformationPageState extends State<AccountInformationPage> {
  final User? user = FirebaseAuth.instance.currentUser;
  final DatabaseReference _databaseRef = FirebaseDatabase.instance.ref().child('users');

  // Personal Information
  String _fullName = '';
  String _phoneNumber = '';
  String _email = '';

  // Delivery Details
  String _countryLanguage = '';
  String _shippingAddress = '';
  String _paymentMethod = '';
  String _billingAddress = '';

  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadUserData();
  }

  Future<void> _loadUserData() async {
    if (user == null) {
      setState(() => _isLoading = false);
      return;
    }

    try {
      // Load basic user data
      final userSnapshot = await _databaseRef.child(user!.uid).get();

      if (userSnapshot.exists) {
        final userData = userSnapshot.value as Map<dynamic, dynamic>;
        setState(() {
          _fullName = userData['name'] ?? 'Not set';
          _phoneNumber = userData['mobilePhoneNumber'] ?? 'Not set';
          _email = userData['email'] ?? user?.email ?? 'Not set';
        });
      }

      // Load delivery details
      final deliverySnapshot = await _databaseRef
          .child(user!.uid)
          .child('deliveryDetails')
          .get();

      if (deliverySnapshot.exists) {
        final data = deliverySnapshot.value as Map<dynamic, dynamic>;
        setState(() {
          _shippingAddress = data['address'] ?? 'Not set';
          _billingAddress = data['billingAddress'] ?? 'Not set';
        });
      }
    } catch (e) {
      print("Error loading data: $e");
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  Widget _buildInfoSection(String title, String value, {bool isPassword = false, VoidCallback? onEdit}) {
    return Container(
      width: double.infinity,
      padding: EdgeInsets.all(16),
      decoration: BoxDecoration(
        border: Border(bottom: BorderSide(color: Colors.grey[300]!)),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: TextStyle(
                    fontSize: 14,
                    color: Colors.grey[600],
                    fontWeight: FontWeight.w500,
                  ),
                ),
                SizedBox(height: 4),
                Text(
                  isPassword ? '••••••••' : value.isEmpty ? 'Not set' : value,
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w400,
                    color: Colors.black87,
                  ),
                ),
              ],
            ),
          ),
          if (onEdit != null)
            IconButton(
              icon: Icon(Icons.edit, size: 20, color: Colors.grey[600]),
              onPressed: onEdit,
              padding: EdgeInsets.zero,
              constraints: BoxConstraints(),
            ),
        ],
      ),
    );
  }

  // دالة تسجيل الخروج
  void _showLogoutConfirmation(BuildContext context) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: Text('Sign out'),
          content: Text('Are you sure you want to log out?'),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: Text('Cancel'),
            ),
            TextButton(
              onPressed: () async {
                Navigator.of(context).pop();
                await _logout(context);
              },
              child: Text(
                'Logout',
                style: TextStyle(color: Colors.red),
              ),
            ),
          ],
        );
      },
    );
  }

  Future<void> _logout(BuildContext context) async {
    try {
      await FirebaseAuth.instance.signOut();

      // الانتقال لصفحة تسجيل الدخول وإزالة كل الصفحات السابقة
      Navigator.pushAndRemoveUntil(
        context,
        MaterialPageRoute(builder: (context) => LoginPage()),
            (Route<dynamic> route) => false,
      );
    } catch (e) {
      print("Error logging out: $e");
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('An error occurred while logging out'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(
          'Account Information',
          style: TextStyle(
            fontWeight: FontWeight.bold,
            color: Colors.black87,
          ),
        ),
        backgroundColor: Colors.white,
        elevation: 0,
        iconTheme: IconThemeData(color: Colors.black87),
      ),
      body: _isLoading
          ? Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Personal Information Section
            _buildInfoSection(
              'Full Name',
              _fullName,
              onEdit: () => _showEditDialog('Full Name', _fullName, (value) {
                _updateUserData('name', value);
                setState(() => _fullName = value);
              }),
            ),
            _buildInfoSection(
              'Mobile Phone Number',
              _phoneNumber,
              onEdit: () => _showEditPhoneDialog('Phone Number', _phoneNumber, (value) { // غير هنا
                _updateUserData('mobilePhoneNumber', value);
                setState(() => _phoneNumber = value);
              }),
            ),
            _buildInfoSection(
              'Email',
              _email,
              onEdit: null,
            ),
            _buildInfoSection(
              'Password',
              'password',
              isPassword: true,
              onEdit: () => _showChangePasswordDialog(),
            ),

            _buildInfoSection(
              'Shipping Address',
              _shippingAddress,
              onEdit: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => DeliveryDetailsPage(),
                  ),
                ).then((_) => _loadUserData()); // Reload data when returning
              },
            ),
            _buildInfoSection(
              'Payment Method',
              _paymentMethod,
              onEdit: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (context) => PaymentPage()),
                );
              },
            ),

            // Logout Section - أضف هذا القسم
            SizedBox(height: 20),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16.0),
              child: Card(
                color: Colors.red[50],
                child: ListTile(
                  leading: Icon(Icons.logout, color: Colors.red),
                  title: Text(
                    'Logout',
                    style: TextStyle(color: Colors.red, fontWeight: FontWeight.bold),
                  ),
                  onTap: () => _showLogoutConfirmation(context),
                ),
              ),
            ),
            SizedBox(height: 20),
          ],
        ),
      ),
    );
  }

  void _showEditDialog(String field, String currentValue, Function(String) onSave, {bool isAddress = false}) {
    TextEditingController controller = TextEditingController(text: currentValue);

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Edit $field'),
        content: TextField(
          controller: controller,
          maxLines: isAddress ? 3 : 1,
          decoration: InputDecoration(
            hintText: 'Enter your $field',
            border: OutlineInputBorder(),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('Cancel', style: TextStyle(color: Colors.grey[600])),
          ),
          ElevatedButton(
            onPressed: () {
              if (controller.text.isNotEmpty) {
                onSave(controller.text);
                Navigator.pop(context);
              }
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Color(0xFF914D74),
            ),
            child: Text('Save'),
          ),
        ],
      ),
    );
  }
  void _showEditPhoneDialog(String field, String currentValue, Function(String) onSave) {
    TextEditingController controller = TextEditingController(text: currentValue);
    final GlobalKey<FormState> _formKey = GlobalKey<FormState>();

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Edit $field'),
        content: Form(
          key: _formKey,
          child: TextFormField(
            controller: controller,
            keyboardType: TextInputType.phone,
            decoration: InputDecoration(
              hintText: 'Enter your $field',
              border: OutlineInputBorder(),
            ),
            validator: (value) {
              if (value == null || value.isEmpty) {
                return 'Please enter your phone number';
              }
              if (value.length != 8) {
                return 'Phone number must be 8 digits';
              }
              if (!value.startsWith('9') && !value.startsWith('7')) {
                return 'Phone number must start with 9 or 7';
              }
              return null;
            },
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('Cancel', style: TextStyle(color: Colors.grey[600])),
          ),
          ElevatedButton(
            onPressed: () {
              if (_formKey.currentState!.validate()) {
                onSave(controller.text);
                Navigator.pop(context);
              }
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Color(0xFF914D74),
            ),
            child: Text('Save'),
          ),
        ],
      ),
    );
  }


  // دالة جديدة لتغيير كلمة المرور
  void _showChangePasswordDialog() {
    TextEditingController currentPasswordController = TextEditingController();
    TextEditingController newPasswordController = TextEditingController();
    TextEditingController confirmPasswordController = TextEditingController();

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Change Password'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: currentPasswordController,
                obscureText: true,
                decoration: InputDecoration(
                  labelText: 'Current Password',
                  border: OutlineInputBorder(),
                ),
              ),
              SizedBox(height: 16),
              TextField(
                controller: newPasswordController,
                obscureText: true,
                decoration: InputDecoration(
                  labelText: 'New Password',
                  border: OutlineInputBorder(),
                ),
              ),
              SizedBox(height: 16),
              TextField(
                controller: confirmPasswordController,
                obscureText: true,
                decoration: InputDecoration(
                  labelText: 'Confirm New Password',
                  border: OutlineInputBorder(),
                ),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('Cancel', style: TextStyle(color: Colors.grey[600])),
          ),
          ElevatedButton(
            onPressed: () async {
              await _changePassword(
                currentPasswordController.text,
                newPasswordController.text,
                confirmPasswordController.text,
              );
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Color(0xFF914D74),
            ),
            child: Text('Change Password'),
          ),
        ],
      ),
    );
  }

  // دالة تغيير كلمة المرور في Firebase
  Future<void> _changePassword(String currentPassword, String newPassword, String confirmPassword) async {
    if (user == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('User not found')),
      );
      return;
    }

    try {
      // التحقق من أن كلمات المرور الجديدة متطابقة
      if (newPassword != confirmPassword) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('New passwords do not match')),
        );
        return;
      }

      // التحقق من أن كلمة المرور الجديدة ليست قصيرة جداً
      if (newPassword.length < 6) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Password should be at least 6 characters')),
        );
        return;
      }

      // إعادة المصادقة بالمستخدم الحالي
      AuthCredential credential = EmailAuthProvider.credential(
        email: user!.email!,
        password: currentPassword,
      );

      await user!.reauthenticateWithCredential(credential);

      // تغيير كلمة المرور
      await user!.updatePassword(newPassword);

      // إغلاق ال dialog
      Navigator.pop(context);

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Password changed successfully!')),
      );

    } on FirebaseAuthException catch (e) {
      String errorMessage = 'Failed to change password';

      if (e.code == 'wrong-password') {
        errorMessage = 'Current password is incorrect';
      } else if (e.code == 'weak-password') {
        errorMessage = 'New password is too weak';
      } else if (e.code == 'requires-recent-login') {
        errorMessage = 'Please log in again to change your password';
      }

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(errorMessage)),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('An error occurred: $e')),
      );
    }
  }

  // في AccountInformationPage - تحديث دالة _updateUserData
  Future<void> _updateUserData(String field, String value) async {
    if (user == null) return;

    try {

      if (field == 'mobilePhoneNumber') {
        await _databaseRef.child(user!.uid).update({
          'phone': value,
          'mobilePhoneNumber': value,
        });
      } else {
        await _databaseRef.child(user!.uid).update({
          field: value,
        });
      }

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('$field updated successfully!')),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to update $field: $e')),
      );
    }
  }
/*
  Future<void> _updateDeliveryData(String field, String value) async {
    if (user == null) return;

    try {
      await _databaseRef.child(user!.uid).child('deliveryDetails').update({
        field: value,
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('$field updated successfully!')),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to update $field: $e')),
      );}}*/
}