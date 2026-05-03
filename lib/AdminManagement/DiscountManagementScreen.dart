import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:intl/intl.dart';
import 'package:firebase_database/firebase_database.dart';
import '../main.dart';

class DiscountManagementScreen extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Discount Management'),
        backgroundColor: Colors.purple,
      ),
      body: Padding(
        padding: EdgeInsets.all(20.0),
        child: Column(
          children: [
            // Discount Coupons Card
            Card(
              elevation: 4,
              child: ListTile(
                leading: Icon(Icons.confirmation_number, color: Colors.blue, size: 40),
                title: Text(
                  'Discount Coupons',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
                subtitle: Text('Create and manage discount coupon codes'),
                trailing: Icon(Icons.arrow_forward_ios, color: Colors.blue),
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(builder: (context) => AddCouponPage()),
                  );
                },
              ),
            ),

            SizedBox(height: 20),

            // Least Sold Products Discounts Card
            Card(
              elevation: 4,
              child: ListTile(
                leading: Icon(Icons.trending_down, color: Colors.red, size: 40),
                title: Text(
                  'Least Sold Products',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
                subtitle: Text('Apply discounts to boost low-selling products'),
                trailing: Icon(Icons.arrow_forward_ios, color: Colors.red),
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(builder: (context) => LeastSoldProductsDiscountScreen()),
                  );
                },
              ),
            ),

            SizedBox(height: 20),

            // Active Discounts Card
            Card(
              elevation: 4,
              child: ListTile(
                leading: Icon(Icons.discount, color: Colors.green, size: 40),
                title: Text(
                  'View Active Discounts',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
                subtitle: Text('View and manage all active discounts'),
                trailing: Icon(Icons.arrow_forward_ios, color: Colors.green),
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(builder: (context) => ViewActiveDiscountsScreen()),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class DiscountCoupon {
  final String id;
  final String code;
  final String discountType;
  final double discountValue;
  final DateTime startDate;
  final DateTime endDate;
  final bool isActive;

  DiscountCoupon({
    required this.id,
    required this.code,
    required this.discountType,
    required this.discountValue,
    required this.startDate,
    required this.endDate,
    required this.isActive,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'code': code.toUpperCase(),
      'discountType': discountType,
      'discountValue': discountValue,
      'startDate': Timestamp.fromDate(startDate),
      'endDate': Timestamp.fromDate(endDate),
      'isActive': isActive,
    };
  }

  static DiscountCoupon fromMap(Map<String, dynamic> map) {
    return DiscountCoupon(
      id: map['id'],
      code: map['code'],
      discountType: map['discountType'],
      discountValue: map['discountValue'].toDouble(),
      startDate: (map['startDate'] as Timestamp).toDate(),
      endDate: (map['endDate'] as Timestamp).toDate(),
      isActive: map['isActive'],
    );
  }
}

class DiscountProvider with ChangeNotifier {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  List<DiscountCoupon> _coupons = [];
  List<DiscountCoupon> get coupons => _coupons;

  // Add new coupon
  Future<void> addCoupon(DiscountCoupon coupon) async {
    try {
      await _firestore
          .collection('discountCoupons')
          .doc(coupon.id)
          .set(coupon.toMap());

      _coupons.add(coupon);
      notifyListeners();
    } catch (e) {
      print('Error adding coupon: $e');
      throw e;
    }
  }

  // Fetch all coupons
  Future<void> fetchCoupons() async {
    try {
      final snapshot = await _firestore
          .collection('discountCoupons')
          .orderBy('startDate', descending: true)
          .get();

      _coupons = snapshot.docs
          .map((doc) => DiscountCoupon.fromMap(doc.data()))
          .toList();

      notifyListeners();
    } catch (e) {
      print('Error fetching coupons: $e');
    }
  }

  // Validate coupon
  Future<DiscountCoupon?> validateCoupon(String code) async {
    try {
      final snapshot = await _firestore
          .collection('discountCoupons')
          .where('code', isEqualTo: code.toUpperCase())
          .where('isActive', isEqualTo: true)
          .get();

      if (snapshot.docs.isEmpty) return null;

      final coupon = DiscountCoupon.fromMap(snapshot.docs.first.data());
      final now = DateTime.now();

      if (now.isAfter(coupon.endDate) || now.isBefore(coupon.startDate)) {
        return null;
      }

      return coupon;
    } catch (e) {
      print('Error validating coupon: $e');
      return null;
    }
  }
}

class AddCouponPage extends StatefulWidget {
  @override
  _AddCouponPageState createState() => _AddCouponPageState();
}

class _AddCouponPageState extends State<AddCouponPage> {
  final _formKey = GlobalKey<FormState>();
  final DatabaseReference _databaseRef = FirebaseDatabase.instance.ref();

  TextEditingController _codeController = TextEditingController();
  TextEditingController _discountController = TextEditingController();
  String _discountType = 'percentage';
  DateTime _startDate = DateTime.now();
  DateTime _endDate = DateTime.now().add(Duration(days: 30));

  void _saveCoupon() {
    if (_formKey.currentState!.validate()) {
      final String couponId = DateTime.now().millisecondsSinceEpoch.toString();

      Map<String, dynamic> couponData = {
        'id': couponId,
        'code': _codeController.text.toUpperCase(),
        'discountType': _discountType,
        'discountValue': double.parse(_discountController.text),
        'startDate': _startDate.millisecondsSinceEpoch,
        'endDate': _endDate.millisecondsSinceEpoch,
        'isActive': true,
        'createdAt': DateTime.now().millisecondsSinceEpoch,
      };

      _databaseRef.child('discountCoupons').child(couponId).set(couponData)
          .then((_) async {
        // ⬇️ ⬇️ ⬇️ التعديل هنا ⬇️ ⬇️ ⬇️
        await _sendDiscountNotificationToUsers(couponData); // إشعار للمستخدمين
        //_sendSimpleNotification(couponData); // إشعار محلي للمدير
        // ⬆️ ⬆️ ⬆️ نهاية التعديل ⬆️ ⬆️ ⬆️

        ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Coupon added successfully!'),
              backgroundColor: Colors.green,
            )
        );
        Navigator.pop(context);
      }).catchError((error) {
        ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Error: $error'),
              backgroundColor: Colors.red,
            )
        );
      });
    }
  }
// ✅ دالة لإرسال إشعار الخصم لجميع المستخدمين
  Future<void> _sendDiscountNotificationToUsers(Map<String, dynamic> coupon) async {
    try {
      final usersSnapshot = await FirebaseDatabase.instance
          .ref('users')
          .get();

      if (usersSnapshot.exists) {
        final users = Map<String, dynamic>.from(usersSnapshot.value as Map);
        final timestamp = DateTime.now().millisecondsSinceEpoch;
        final notificationId = 'discount_${timestamp}';

        final String code = coupon['code'];
        final double value = coupon['discountValue'];
        final String type = coupon['discountType'];

        final notificationData = {
          'title': '🎉 New Discount Available!',
          'body': type == 'percentage'
              ? 'Use code $code for $value% OFF on your next purchase!'
              : 'Use code $code for OMR $value OFF on your next purchase!',
          'type': 'new_discount',
          'couponCode': code,
          'discountValue': value,
          'discountType': type,
          'isRead': false,
          'timestamp': timestamp,
        };

        final currentUser = FirebaseAuth.instance.currentUser;

        for (final userId in users.keys) {
          if (currentUser != null && userId == currentUser.uid) continue;

          await FirebaseDatabase.instance
              .ref('users/$userId/notifications/$notificationId')
              .set(notificationData);
        }

        print('✅ Discount notifications sent to all users');
      }
    } catch (e) {
      print('❌ Error sending discount notifications: $e');
    }
  }
  // ✅ دالة مبسطة لإرسال الإشعار
  void _sendSimpleNotification(Map<String, dynamic> coupon) {
    final String code = coupon['code'];
    final double value = coupon['discountValue'];
    final String type = coupon['discountType'];
/*
    // استخدام الخدمة المبسطة التي تحفظ الإشعارات
    SimpleNotificationService.showNotification(
      title: '🎉 New Discount!',
      body: type == 'percentage'
          ? 'Use code $code for $value% OFF'
          : 'Use code $code for OMR $value OFF',
    );*/
  }

  Future<void> _selectDate(BuildContext context, bool isStartDate) async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: isStartDate ? _startDate : _endDate,
      firstDate: DateTime.now(),
      lastDate: DateTime(2100),
    );
    if (picked != null) {
      setState(() {
        if (isStartDate) {
          _startDate = picked;
        } else {
          _endDate = picked;
        }
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Add Discount Coupon'),
        backgroundColor: Colors.blue,
      ),
      body: Padding(
        padding: EdgeInsets.all(16.0),
        child: Form(
          key: _formKey,
          child: ListView(
            children: [
              // Coupon Code Field
              TextFormField(
                controller: _codeController,
                decoration: InputDecoration(
                  labelText: 'Coupon Code',
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(Icons.confirmation_number),
                ),
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return 'Please enter coupon code';
                  }
                  if (value.length < 4) {
                    return 'Coupon code must be at least 4 characters';
                  }
                  return null;
                },
              ),

              SizedBox(height: 20),

              // Discount Type
              DropdownButtonFormField<String>(
                value: _discountType,
                decoration: InputDecoration(
                  labelText: 'Discount Type',
                  border: OutlineInputBorder(),
                ),
                items: [
                  DropdownMenuItem(
                    value: 'percentage',
                    child: Text('Percentage %'),
                  ),
                  DropdownMenuItem(
                    value: 'fixed',
                    child: Text('Fixed Amount'),
                  ),
                ],
                onChanged: (value) {
                  setState(() {
                    _discountType = value!;
                  });
                },
              ),

              SizedBox(height: 20),

              // Discount Value
              TextFormField(
                controller: _discountController,
                keyboardType: TextInputType.number,
                decoration: InputDecoration(
                  labelText: _discountType == 'percentage'
                      ? 'Discount Percentage %'
                      : 'Discount Amount (OMR)',
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(Icons.discount),
                ),
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return 'Please enter discount value';
                  }
                  if (double.tryParse(value) == null) {
                    return 'Please enter valid number';
                  }
                  final discountValue = double.parse(value);
                  if (_discountType == 'percentage' && (discountValue <= 0 || discountValue > 100)) {
                    return 'Percentage must be between 1 and 100';
                  }
                  if (_discountType == 'fixed' && discountValue <= 0) {
                    return 'Amount must be greater than 0';
                  }
                  return null;
                },
              ),

              SizedBox(height: 20),

              // Start Date
              ListTile(
                title: Text('Start Date'),
                subtitle: Text(DateFormat('yyyy-MM-dd').format(_startDate)),
                trailing: Icon(Icons.calendar_today),
                onTap: () => _selectDate(context, true),
              ),

              // End Date
              ListTile(
                title: Text('End Date'),
                subtitle: Text(DateFormat('yyyy-MM-dd').format(_endDate)),
                trailing: Icon(Icons.calendar_today),
                onTap: () => _selectDate(context, false),
              ),

              // Date validation
              if (_endDate.isBefore(_startDate))
                Padding(
                  padding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  child: Text(
                    'End date must be after start date',
                    style: TextStyle(color: Colors.red, fontSize: 12),
                  ),
                ),

              SizedBox(height: 30),

              // Save Button
              ElevatedButton(
                onPressed: _endDate.isBefore(_startDate) ? null : _saveCoupon,
                child: Text(
                  'Save Coupon',
                  style: TextStyle(fontSize: 18),
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.green,
                  minimumSize: Size(double.infinity, 50),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class ViewActiveDiscountsScreen extends StatefulWidget {
  @override
  _ViewActiveDiscountsScreenState createState() => _ViewActiveDiscountsScreenState();
}

class _ViewActiveDiscountsScreenState extends State<ViewActiveDiscountsScreen> {
  List<Map<String, dynamic>> _allCoupons = [];
  List<Map<String, dynamic>> _activeCoupons = [];
  bool _isLoading = true;
  final DatabaseReference _databaseRef = FirebaseDatabase.instance.ref();

  @override
  void initState() {
    super.initState();
    _loadAllCoupons();
    _deleteExpiredCoupons();
  }

  // دالة لتحميل الكوبونات
  Future<void> _loadAllCoupons() async {
    try {
      final dbRef = FirebaseDatabase.instance.ref().child("discountCoupons");
      final snapshot = await dbRef.get();

      print("🔍 Loading coupons for admin view...");

      if (snapshot.exists && snapshot.value != null) {
        final Map<dynamic, dynamic> values = snapshot.value as Map;
        final now = DateTime.now();

        List<Map<String, dynamic>> loadedCoupons = [];
        List<Map<String, dynamic>> activeCoupons = [];

        values.forEach((key, value) {
          try {
            final coupon = Map<String, dynamic>.from(value);
            coupon['id'] = key;

            print("🎫 Processing coupon: ${coupon['code']} - Type: ${coupon['type'] ?? 'coupon'}");

            // Convert timestamp to DateTime
            DateTime startDate;
            DateTime endDate;

            if (coupon['startDate'] is int) {
              startDate = DateTime.fromMillisecondsSinceEpoch(coupon['startDate']);
              endDate = DateTime.fromMillisecondsSinceEpoch(coupon['endDate']);
            } else {
              startDate = DateTime.now().subtract(Duration(days: 1));
              endDate = DateTime.now().add(Duration(days: 30));
            }

            coupon['startDate'] = startDate;
            coupon['endDate'] = endDate;

            // Check if coupon is active and valid
            final bool isActive = coupon['isActive'] == true;
            final bool isValidDate = now.isAfter(startDate) && now.isBefore(endDate);
            final bool isActiveResult = isActive && isValidDate;

            coupon['isCurrentlyActive'] = isActiveResult;
            loadedCoupons.add(coupon);

            if (isActiveResult) {
              activeCoupons.add(coupon);
            }

            print("   Code: ${coupon['code']}, Active: $isActiveResult, Type: ${coupon['type'] ?? 'coupon'}");

          } catch (e) {
            print("❌ Error processing coupon $key: $e");
          }
        });

        // Sort by creation date (newest first)
        loadedCoupons.sort((a, b) => (b['createdAt'] ?? 0).compareTo(a['createdAt'] ?? 0));

        setState(() {
          _allCoupons = loadedCoupons;
          _activeCoupons = activeCoupons;
          _isLoading = false;
        });

        print("✅ Loaded ${_allCoupons.length} total coupons, ${_activeCoupons.length} active");
      } else {
        print("⚠️ No coupons found in database");
        setState(() {
          _isLoading = false;
        });
      }
    } catch (e) {
      print("❌ Error loading coupons: $e");
      setState(() {
        _isLoading = false;
      });
    }
  }

  // دالة لحذف الكوبونات القديمة تلقائياً بعد شهر
  Future<void> _deleteExpiredCoupons() async {
    try {
      final snapshot = await _databaseRef.child("discountCoupons").get();
      final now = DateTime.now();
      final oneMonthAgo = now.subtract(Duration(days: 30));

      if (snapshot.exists && snapshot.value != null) {
        final Map<dynamic, dynamic> values = snapshot.value as Map;
        int deletedCount = 0;

        for (var entry in values.entries) {
          try {
            final coupon = Map<String, dynamic>.from(entry.value);

            final int? createdAt = coupon['createdAt'];
            if (createdAt != null) {
              final DateTime creationDate = DateTime.fromMillisecondsSinceEpoch(createdAt);

              if (creationDate.isBefore(oneMonthAgo)) {
                await _databaseRef.child("discountCoupons").child(entry.key).remove();
                deletedCount++;
                print("🗑️ Deleted old coupon: ${coupon['code']} (Created: $creationDate)");
              }
            }
          } catch (e) {
            print("❌ Error checking coupon age: $e");
          }
        }

        if (deletedCount > 0) {
          print("✅ Deleted $deletedCount old coupons");
          _loadAllCoupons();
        }
      }
    } catch (e) {
      print("❌ Error deleting expired coupons: $e");
    }
  }

  void _deleteCoupon(String couponId, String couponCode) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Delete Coupon'),
        content: Text('Are you sure you want to delete coupon "$couponCode"?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('Cancel'),
          ),
          TextButton(
            onPressed: () {
              _performDelete(couponId);
              Navigator.pop(context);
            },
            child: Text('Delete', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
  }

  void _performDelete(String couponId) async {
    try {
      await _databaseRef.child("discountCoupons").child(couponId).remove();

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Coupon deleted successfully'),
          backgroundColor: Colors.green,
        ),
      );

      await _loadAllCoupons();
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error deleting coupon: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  void _toggleCouponStatus(String couponId, bool currentStatus) async {
    try {
      await _databaseRef.child("discountCoupons").child(couponId).update({
        'isActive': !currentStatus
      });

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Coupon ${!currentStatus ? 'activated' : 'deactivated'} successfully'),
          backgroundColor: Colors.green,
        ),
      );

      await _loadAllCoupons();
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error updating coupon: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  // تصميم الكارت بنفس شكل الـ Home
  Widget _buildCouponCard(Map<String, dynamic> coupon) {
    final String code = coupon['code'] ?? 'N/A';
    final String discountType = coupon['discountType'] ?? 'percentage';
    final double discountValue = (coupon['discountValue'] ?? 0).toDouble();
    final DateTime startDate = coupon['startDate'];
    final DateTime endDate = coupon['endDate'];
    final bool isActive = coupon['isActive'] == true;
    final bool isCurrentlyActive = coupon['isCurrentlyActive'] == true;
    final String type = coupon['type'] ?? 'coupon';
    final String name = coupon['name'] ?? '';

    final startDateStr = DateFormat('dd/MM/yyyy').format(startDate);
    final endDateStr = DateFormat('dd/MM/yyyy').format(endDate);

    return Container(
      margin: EdgeInsets.symmetric(vertical: 8, horizontal: 16),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            type == 'seasonal' ? Colors.orange.withOpacity(0.9) : Color(0xFF914D74).withOpacity(0.9),
            type == 'seasonal' ? Colors.deepOrange.withOpacity(0.8) : Color(0xFF6A1B9A).withOpacity(0.8),
          ],
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withOpacity(0.5),
            spreadRadius: 2,
            blurRadius: 7,
            offset: Offset(0, 3),
          ),
        ],
      ),
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(16),
          color: Colors.white.withOpacity(0.95),
        ),
        child: Padding(
          padding: EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header Row
              Row(
                children: [
                  // Status Badge
                  Container(
                    padding: EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    decoration: BoxDecoration(
                      color: isCurrentlyActive ?
                      (type == 'seasonal' ? Colors.orange : Colors.green) : Colors.grey,
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text(
                      type == 'seasonal' ? 'SEASONAL' :
                      isCurrentlyActive ? 'ACTIVE' : 'INACTIVE',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  SizedBox(width: 8),
                  // Coupon Code
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          code,
                          style: TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                            color: type == 'seasonal' ? Colors.orange : Color(0xFF914D74),
                          ),
                        ),
                        if (name.isNotEmpty) ...[
                          SizedBox(height: 4),
                          Text(
                            name,
                            style: TextStyle(
                              fontSize: 14,
                              color: Colors.grey[600],
                              fontStyle: FontStyle.italic,
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                  // Actions
                  PopupMenuButton<String>(
                    icon: Icon(Icons.more_vert, color: type == 'seasonal' ? Colors.orange : Color(0xFF914D74)),
                    onSelected: (value) {
                      if (value == 'delete') {
                        _deleteCoupon(coupon['id'], code);
                      } else if (value == 'toggle') {
                        _toggleCouponStatus(coupon['id'], isActive);
                      } else if (value == 'copy') {
                        _copyCouponCode(code);
                      }
                    },
                    itemBuilder: (context) => [
                      PopupMenuItem(
                        value: 'copy',
                        child: Row(
                          children: [
                            Icon(Icons.content_copy, size: 20, color: type == 'seasonal' ? Colors.orange : Color(0xFF914D74)),
                            SizedBox(width: 8),
                            Text('Copy Code'),
                          ],
                        ),
                      ),
                      PopupMenuItem(
                        value: 'toggle',
                        child: Row(
                          children: [
                            Icon(isActive ? Icons.toggle_off : Icons.toggle_on,
                                size: 20, color: type == 'seasonal' ? Colors.orange : Color(0xFF914D74)),
                            SizedBox(width: 8),
                            Text(isActive ? 'Deactivate' : 'Activate'),
                          ],
                        ),
                      ),
                      PopupMenuItem(
                        value: 'delete',
                        child: Row(
                          children: [
                            Icon(Icons.delete, color: Colors.red, size: 20),
                            SizedBox(width: 8),
                            Text('Delete', style: TextStyle(color: Colors.red)),
                          ],
                        ),
                      ),
                    ],
                  ),
                ],
              ),

              SizedBox(height: 16),

              // Discount Info (بنفس شكل الـ Home)
              Row(
                children: [
                  Container(
                    padding: EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: type == 'seasonal' ? Colors.orange : Color(0xFF914D74),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(
                      type == 'seasonal' ? Icons.local_offer : Icons.discount,
                      color: Colors.white,
                      size: 20,
                    ),
                  ),
                  SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // الكود ونسبة الخصم
                        Row(
                          children: [
                            Text(
                              type == 'seasonal' ? 'Offer: ' : 'Code: ',
                              style: TextStyle(
                                color: Colors.black87,
                                fontSize: 14,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                            Text(
                              type == 'seasonal' ? name : code,
                              style: TextStyle(
                                color: type == 'seasonal' ? Colors.orange : Color(0xFF914D74),
                                fontSize: 14,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            Spacer(),
                            Text(
                              discountType == 'percentage'
                                  ? '${discountValue.toInt()}% OFF'
                                  : 'OMR ${discountValue.toStringAsFixed(2)} OFF',
                              style: TextStyle(
                                color: Colors.green,
                                fontSize: 14,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ],
                        ),

                        SizedBox(height: 8),

                        // تاريخ الصلاحية
                        Row(
                          children: [
                            Icon(Icons.calendar_today, size: 14, color: Colors.grey),
                            SizedBox(width: 4),
                            Text(
                              'Valid: $startDateStr - $endDateStr',
                              style: TextStyle(
                                color: Colors.grey[600],
                                fontSize: 12,
                              ),
                            ),
                          ],
                        ),

                        SizedBox(height: 4),

                        // نوع الخصم
                        Row(
                          children: [
                            Icon(Icons.info, size: 14, color: Colors.grey),
                            SizedBox(width: 4),
                            Text(
                              'Type: ${type == 'seasonal' ? 'Seasonal Offer' : (discountType == 'percentage' ? 'Percentage' : 'Fixed Amount')}',
                              style: TextStyle(
                                color: Colors.grey[600],
                                fontSize: 12,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ],
              ),

              // Expired Warning
              if (endDate.isBefore(DateTime.now()))
                Container(
                  margin: EdgeInsets.only(top: 12),
                  padding: EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: Colors.orange[50],
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Row(
                    children: [
                      Icon(Icons.warning, color: Colors.orange, size: 16),
                      SizedBox(width: 8),
                      Text(
                        'This ${type == 'seasonal' ? 'offer' : 'coupon'} has expired',
                        style: TextStyle(
                          color: Colors.orange[800],
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                ),

              // Inactive Warning
              if (!isActive && endDate.isAfter(DateTime.now()))
                Container(
                  margin: EdgeInsets.only(top: 12),
                  padding: EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: Colors.blue[50],
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Row(
                    children: [
                      Icon(Icons.info, color: Colors.blue, size: 16),
                      SizedBox(width: 8),
                      Text(
                        '${type == 'seasonal' ? 'Offer' : 'Coupon'} is deactivated',
                        style: TextStyle(
                          color: Colors.blue[800],
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  void _copyCouponCode(String code) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Coupon code "$code" copied to clipboard!'),
        backgroundColor: Colors.green,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('All Discount Coupons'),
        backgroundColor: Colors.purple,
        actions: [
          IconButton(
            icon: Icon(Icons.refresh),
            onPressed: _loadAllCoupons,
            tooltip: 'Refresh',
          ),
          IconButton(
            icon: Icon(Icons.add),
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => AddCouponPage()),
              ).then((_) => _loadAllCoupons());
            },
            tooltip: 'Add New Coupon',
          ),
        ],
      ),
      body: _isLoading
          ? Center(child: CircularProgressIndicator())
          : _allCoupons.isEmpty
          ? Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.local_offer, size: 64, color: Colors.grey),
            SizedBox(height: 16),
            Text(
              'No coupons found',
              style: TextStyle(fontSize: 18, color: Colors.grey),
            ),
            SizedBox(height: 8),
            Text(
              'Create your first coupon to get started',
              style: TextStyle(color: Colors.grey),
              textAlign: TextAlign.center,
            ),
            SizedBox(height: 20),
            ElevatedButton.icon(
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (context) => AddCouponPage()),
                );
              },
              icon: Icon(Icons.add),
              label: Text('Create First Coupon'),
              style: ElevatedButton.styleFrom(
                backgroundColor: Color(0xFF914D74),
              ),
            ),
          ],
        ),
      )
          : Column(
        children: [
          // Stats Header
          Container(
            width: double.infinity,
            padding: EdgeInsets.all(16),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  Color(0xFFFFE4F3),
                  Color(0xFF914D74).withOpacity(0.1),
                ],
              ),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                _buildStatCard('Total', _allCoupons.length.toString(), Colors.blue),
                _buildStatCard('Active', _activeCoupons.length.toString(), Colors.green),
                _buildStatCard('Inactive', (_allCoupons.length - _activeCoupons.length).toString(), Colors.orange),
              ],
            ),
          ),

          // Coupons List
          Expanded(
            child: ListView.builder(
              itemCount: _allCoupons.length,
              itemBuilder: (context, index) {
                return _buildCouponCard(_allCoupons[index]);
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatCard(String title, String value, Color color) {
    return Column(
      children: [
        Container(
          padding: EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: color.withOpacity(0.1),
            shape: BoxShape.circle,
            border: Border.all(color: color.withOpacity(0.3), width: 2),
          ),
          child: Text(
            value,
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: color,
            ),
          ),
        ),
        SizedBox(height: 4),
        Text(
          title,
          style: TextStyle(
            fontSize: 12,
            color: Colors.grey[600],
            fontWeight: FontWeight.w500,
          ),
        ),
      ],
    );
  }
}

class LeastSoldProductsDiscountScreen extends StatefulWidget {
  @override
  _LeastSoldProductsDiscountScreenState createState() => _LeastSoldProductsDiscountScreenState();
}

class _LeastSoldProductsDiscountScreenState extends State<LeastSoldProductsDiscountScreen> {
  final DatabaseReference _databaseRef = FirebaseDatabase.instance.ref();
  final Color _primaryColor = Color(0xFF914D74);

  List<Map<String, dynamic>> _leastSoldProducts = [];
  List<Map<String, dynamic>> _allProducts = [];
  bool _isLoading = true;
  Map<String, int> _productSales = {};

  @override
  void initState() {
    super.initState();
    _loadLeastSoldProducts();
  }

  // دالة لجلب إحصائيات المبيعات
  Future<Map<String, int>> _getProductSalesData() async {
    try {
      final ordersRef = _databaseRef.child("all_orders");
      final snapshot = await ordersRef.get();

      Map<String, int> productSales = {};

      if (snapshot.exists && snapshot.value != null) {
        final Map<dynamic, dynamic> orders = snapshot.value as Map;

        orders.forEach((orderKey, orderValue) {
          try {
            final order = Map<String, dynamic>.from(orderValue);
            dynamic items = order['items'] ?? order['products'] ?? order['cartItems'];

            if (items != null) {
              if (items is Map) {
                items.forEach((key, item) {
                  if (item is Map) {
                    final productId = item['productId'] ?? item['id'] ?? key.toString();
                    final quantity = item['quantity'] ?? 1;
                    final normalizedProductId = productId.toString().trim();
                    productSales[normalizedProductId] = (productSales[normalizedProductId] ?? 0) + (quantity is int ? quantity : 1);
                  }
                });
              } else if (items is List) {
                for (var item in items) {
                  if (item is Map) {
                    final productId = item['productId'] ?? item['id'] ?? 'unknown';
                    final quantity = item['quantity'] ?? 1;
                    final normalizedProductId = productId.toString().trim();
                    productSales[normalizedProductId] = (productSales[normalizedProductId] ?? 0) + (quantity is int ? quantity : 1);
                  }
                }
              }
            }
          } catch (e) {
            print('❌ Error processing order $orderKey: $e');
          }
        });
      }

      print('📊 Product sales data loaded: ${productSales.length} products');
      return productSales;
    } catch (e) {
      print('❌ Error loading product sales: $e');
      return {};
    }
  }

  // دالة لتحميل المنتجات الأقل مبيعاً
  Future<void> _loadLeastSoldProducts() async {
    try {
      setState(() {
        _isLoading = true;
      });

      final salesData = await _getProductSalesData();
      final productsSnapshot = await _databaseRef.child("products").get();

      if (productsSnapshot.exists && productsSnapshot.value != null) {
        final Map<dynamic, dynamic> products = productsSnapshot.value as Map;
        List<Map<String, dynamic>> allProducts = [];

        products.forEach((key, value) {
          try {
            final product = Map<String, dynamic>.from(value);
            product['id'] = key.toString();
            final productId = product['id'];
            final salesCount = salesData[productId] ?? 0;
            product['salesCount'] = salesCount;
            allProducts.add(product);
          } catch (e) {
            print('❌ Error processing product $key: $e');
          }
        });

        allProducts.sort((a, b) => (a['salesCount'] ?? 0).compareTo(b['salesCount'] ?? 0));
        final leastSold = allProducts.take(10).toList();

        setState(() {
          _allProducts = allProducts;
          _leastSoldProducts = leastSold;
          _productSales = salesData;
          _isLoading = false;
        });

        print('✅ Loaded ${_leastSoldProducts.length} least sold products');
      }
    } catch (e) {
      print('❌ Error loading least sold products: $e');
      setState(() {
        _isLoading = false;
      });
    }
  }

  // دالة لتطبيق خصم على منتج
  void _applyDiscountToProduct(Map<String, dynamic> product) {
    showDialog(
      context: context,
      builder: (context) => ProductDiscountDialog(
        product: product,
        onDiscountApplied: _loadLeastSoldProducts,
      ),
    );
  }

  // ✅ دالة جديدة: إزالة الخصم من المنتج
  void _removeDiscountFromProduct(String productId) async {
    try {
      await _databaseRef.child('products').child(productId).update({
        'discount': null,
      });

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Discount removed successfully'),
          backgroundColor: Colors.green,
        ),
      );

      _loadLeastSoldProducts();
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error removing discount: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Least Sold Products'),
        backgroundColor: Colors.red,
        actions: [
          IconButton(
            icon: Icon(Icons.refresh),
            onPressed: _loadLeastSoldProducts,
            tooltip: 'Refresh',
          ),
        ],
      ),
      body: _isLoading
          ? Center(child: CircularProgressIndicator())
          : _leastSoldProducts.isEmpty
          ? Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.trending_down, size: 64, color: Colors.grey),
            SizedBox(height: 16),
            Text(
              'No products found',
              style: TextStyle(fontSize: 18, color: Colors.grey),
            ),
            SizedBox(height: 8),
            Text(
              'Or all products have good sales',
              style: TextStyle(color: Colors.grey),
            ),
          ],
        ),
      )
          : Column(
        children: [
          // إحصائيات سريعة
          Container(
            padding: EdgeInsets.all(16),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  Colors.red.withOpacity(0.1),
                  Colors.orange.withOpacity(0.1),
                ],
              ),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                _buildStatItem('Total Products', _allProducts.length.toString(), Icons.shopping_bag),
                _buildStatItem('Low Sales', _leastSoldProducts.length.toString(), Icons.trending_down),
                _buildStatItem('Avg Sales', '${_calculateAverageSales().toStringAsFixed(1)}', Icons.analytics),
              ],
            ),
          ),

          // نص توجيهي
          Container(
            padding: EdgeInsets.all(16),
            color: Colors.orange[50],
            child: Row(
              children: [
                Icon(Icons.lightbulb_outline, color: Colors.orange),
                SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Apply discounts to these low-selling products to boost their visibility and sales',
                    style: TextStyle(
                      color: Colors.orange[800],
                      fontSize: 14,
                    ),
                  ),
                ),
              ],
            ),
          ),

          // قائمة المنتجات الأقل مبيعاً
          Expanded(
            child: ListView.builder(
              padding: EdgeInsets.all(16),
              itemCount: _leastSoldProducts.length,
              itemBuilder: (context, index) {
                return _buildProductCard(_leastSoldProducts[index], index + 1);
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatItem(String title, String value, IconData icon) {
    return Column(
      children: [
        Container(
          padding: EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: Colors.red.withOpacity(0.1),
            shape: BoxShape.circle,
          ),
          child: Icon(icon, color: Colors.red, size: 20),
        ),
        SizedBox(height: 4),
        Text(
          value,
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.bold,
            color: Colors.red,
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

  Widget _buildProductCard(Map<String, dynamic> product, int rank) {
    double price = (product['price'] ?? 0).toDouble();
    int salesCount = product['salesCount'] ?? 0;
    String productName = product['name'] ?? 'Unknown Product';
    String brand = product['brand'] ?? 'Unknown Brand';
    String? imageUrl = product['image'];

    // ✅ التحقق من وجود خصم
    bool hasDiscount = product['discount'] != null;
    Map<String, dynamic>? discountData = hasDiscount
        ? Map<String, dynamic>.from(product['discount'])
        : null;

    double? discountValue = discountData?['discountValue']?.toDouble();
    String? discountType = discountData?['discountType'];

    // حساب السعر بعد الخصم
    double finalPrice = price;
    if (hasDiscount && discountValue != null) {
      if (discountType == 'percentage') {
        finalPrice = price * (1 - discountValue / 100);
      } else if (discountType == 'fixed') {
        finalPrice = price - discountValue;
        if (finalPrice < 0) finalPrice = 0;
      }
    }

    return Card(
      elevation: 3,
      margin: EdgeInsets.only(bottom: 12),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: EdgeInsets.all(16),
        child: Row(
          children: [
            // صورة المنتج مع شارة الخصم
            Stack(
              children: [
                Container(
                  width: 80,
                  height: 80,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(8),
                    color: Colors.grey[200],
                  ),
                  child: imageUrl != null && imageUrl.isNotEmpty
                      ? ClipRRect(
                    borderRadius: BorderRadius.circular(8),
                    child: Image.network(
                      imageUrl,
                      fit: BoxFit.cover,
                      errorBuilder: (context, error, stackTrace) {
                        return _buildPlaceholderImage();
                      },
                    ),
                  )
                      : _buildPlaceholderImage(),
                ),

                // شارة الخصم
                if (hasDiscount)
                  Positioned(
                    top: 0,
                    right: 0,
                    child: Container(
                      padding: EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        color: Colors.red,
                        borderRadius: BorderRadius.only(
                          topRight: Radius.circular(8),
                          bottomLeft: Radius.circular(8),
                        ),
                      ),
                      child: Text(
                        'OFF',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 10,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ),
              ],
            ),

            SizedBox(width: 16),

            // معلومات المنتج
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // الترتيب واسم المنتج
                  Row(
                    children: [
                      Container(
                        padding: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color: _getRankColor(rank),
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Text(
                          '#$rank',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                      SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          productName,
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 16,
                          ),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),

                  SizedBox(height: 4),

                  Text(
                    brand,
                    style: TextStyle(
                      color: Colors.grey[600],
                      fontSize: 14,
                    ),
                  ),

                  SizedBox(height: 8),

                  // السعر والمبيعات
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // السعر الأصلي (مشطوب إذا كان هناك خصم)
                      Row(
                        children: [
                          Text(
                            'OMR ${price.toStringAsFixed(2)}',
                            style: TextStyle(
                              color: hasDiscount ? Colors.grey : _primaryColor,
                              fontWeight: FontWeight.bold,
                              fontSize: hasDiscount ? 14 : 16,
                              decoration: hasDiscount ? TextDecoration.lineThrough : TextDecoration.none,
                            ),
                          ),

                          if (hasDiscount) SizedBox(width: 8),

                          // السعر بعد الخصم
                          if (hasDiscount)
                            Text(
                              'OMR ${finalPrice.toStringAsFixed(2)}',
                              style: TextStyle(
                                color: Colors.green,
                                fontWeight: FontWeight.bold,
                                fontSize: 16,
                              ),
                            ),
                        ],
                      ),

                      // نسبة الخصم
                      if (hasDiscount && discountValue != null)
                        Padding(
                          padding: EdgeInsets.only(top: 4),
                          child: Text(
                            discountType == 'percentage'
                                ? '${discountValue.toInt()}% OFF'
                                : 'OMR ${discountValue.toStringAsFixed(2)} OFF',
                            style: TextStyle(
                              color: Colors.red,
                              fontSize: 12,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                    ],
                  ),

                  SizedBox(height: 4),

                  // المبيعات
                  Row(
                    children: [
                      Icon(Icons.shopping_cart, size: 14, color: Colors.grey),
                      SizedBox(width: 4),
                      Text(
                        '$salesCount ${salesCount == 1 ? 'sale' : 'sales'}',
                        style: TextStyle(
                          color: Colors.grey[600],
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),

            SizedBox(width: 16),

            // أزرار التحكم
            Column(
              children: [
                // زر تطبيق/تعديل الخصم
                ElevatedButton.icon(
                  onPressed: () => _applyDiscountToProduct(product),
                  icon: Icon(
                      hasDiscount ? Icons.edit : Icons.discount,
                      size: 18
                  ),
                  label: Text(hasDiscount ? 'Edit' : 'Discount'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: hasDiscount ? Colors.orange : Colors.red,
                    foregroundColor: Colors.white,
                    padding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  ),
                ),

                SizedBox(height: 8),

                // زر إزالة الخصم (يظهر فقط إذا كان هناك خصم)
                if (hasDiscount)
                  OutlinedButton.icon(
                    onPressed: () => _removeDiscountFromProduct(product['id']),
                    icon: Icon(Icons.close, size: 16),
                    label: Text('Remove'),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: Colors.red,
                      side: BorderSide(color: Colors.red),
                      padding: EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    ),
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPlaceholderImage() {
    return Container(
      color: Colors.grey[200],
      child: Center(
        child: Icon(Icons.shopping_bag, color: Colors.grey, size: 30),
      ),
    );
  }

  Color _getRankColor(int rank) {
    switch (rank) {
      case 1: return Colors.red;
      case 2: return Colors.orange;
      case 3: return Colors.amber;
      default: return Colors.grey;
    }
  }

  double _calculateAverageSales() {
    if (_leastSoldProducts.isEmpty) return 0;
    final totalSales = _leastSoldProducts.fold(0, (sum, product) {
      final sales = product['salesCount'] ?? 0;
      final salesInt = sales is int ? sales : (sales as num).toInt();
      return sum + salesInt;
    });
    return totalSales / _leastSoldProducts.length;
  }
}

// دايالوج تطبيق الخصم
class ProductDiscountDialog extends StatefulWidget {
  final Map<String, dynamic> product;
  final VoidCallback onDiscountApplied;

  const ProductDiscountDialog({
    Key? key,
    required this.product,
    required this.onDiscountApplied,
  }) : super(key: key);

  @override
  _ProductDiscountDialogState createState() => _ProductDiscountDialogState();
}

class _ProductDiscountDialogState extends State<ProductDiscountDialog> {
  final DatabaseReference _databaseRef = FirebaseDatabase.instance.ref();
  final TextEditingController _discountController = TextEditingController();
  String _discountType = 'percentage';
  DateTime _endDate = DateTime.now().add(Duration(days: 7));

  void _applyDiscount() async {
    if (_discountController.text.isEmpty) return;

    final discountValue = double.tryParse(_discountController.text);
    if (discountValue == null) return;

    try {
      final String productId = widget.product['id'];
      final String productName = widget.product['name'] ?? 'Unknown Product';

      Map<String, dynamic> productDiscountData = {
        'hasDiscount': true,
        'discountType': _discountType,
        'discountValue': discountValue,
        'discountEndDate': _endDate.millisecondsSinceEpoch,
        'originalPrice': widget.product['price'],
        'lastUpdated': DateTime.now().millisecondsSinceEpoch,
      };

      await _databaseRef.child('products').child(productId).update({
        'discount': productDiscountData,
      });

      final String couponId = DateTime.now().millisecondsSinceEpoch.toString();

      Map<String, dynamic> couponData = {
        'id': couponId,
        'code': 'BOOST${productId.substring(0, 6)}'.toUpperCase(),
        'discountType': _discountType,
        'discountValue': discountValue,
        'startDate': DateTime.now().millisecondsSinceEpoch,
        'endDate': _endDate.millisecondsSinceEpoch,
        'isActive': true,
        'type': 'product_boost',
        'targetProduct': productId,
        'productName': productName,
        'description': 'Special discount for $productName',
        'createdAt': DateTime.now().millisecondsSinceEpoch,
      };

      await _databaseRef.child('discountCoupons').child(couponId).set(couponData);


      await _sendProductDiscountToUsers(productName, discountValue, _discountType, productId);
      _sendProductDiscountNotification(productName, discountValue, _discountType);

      Navigator.pop(context);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('✅ Discount applied to $productName!'),
          backgroundColor: Colors.green,
        ),
      );

      //Navigator.pop(context);
      widget.onDiscountApplied();

    } catch (error) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('❌ Error: $error'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }
// ✅ دالة جديدة لإرسال إشعار خصم المنتج
  void _sendProductDiscountNotification(String productName, double discountValue, String discountType) {
    try {
      final String title = '🔥 Hot Deal! $productName';
      final String body = discountType == 'percentage'
          ? 'Get ${discountValue.toInt()}% OFF on $productName! Limited time offer.'
          : 'Get OMR ${discountValue.toStringAsFixed(2)} OFF on $productName! Limited time offer.';

      // استخدام خدمة الإشعارات البسيطة
      SimpleNotificationService.showNotification(
        title: title,
        body: body,
      );

      print('📢 Product discount notification sent for: $productName');
    } catch (e) {
      print('❌ Error sending product discount notification: $e');
    }
  }
  // ✅ دالة لإرسال إشعار خصم المنتج لجميع المستخدمين
  Future<void> _sendProductDiscountToUsers(String productName, double discountValue, String discountType, String? productId) async {
    try {
      final usersSnapshot = await FirebaseDatabase.instance
          .ref('users')
          .get();

      if (usersSnapshot.exists) {
        final users = Map<String, dynamic>.from(usersSnapshot.value as Map);
        final timestamp = DateTime.now().millisecondsSinceEpoch;
        final notificationId = 'product_discount_${timestamp}';

        final notificationData = {
          'title': '🔥 Hot Deal! $productName',
          'body': discountType == 'percentage'
              ? 'Get ${discountValue.toInt()}% OFF on $productName! Limited time offer.'
              : 'Get OMR ${discountValue.toStringAsFixed(2)} OFF on $productName! Limited time offer.',
          'type': 'product_discount',
          'productName': productName,
          'discountValue': discountValue,
          'discountType': discountType,
          'productId': productId,
          'isRead': false,
          'timestamp': timestamp,
        };

        final currentUser = FirebaseAuth.instance.currentUser;

        for (final userId in users.keys) {
          if (currentUser != null && userId == currentUser.uid) continue;

          await FirebaseDatabase.instance
              .ref('users/$userId/notifications/$notificationId')
              .set(notificationData);
        }

        print('✅ Product discount notifications sent to all users');
      }
    } catch (e) {
      print('❌ Error sending product discount notifications: $e');
    }
  }
  Future<void> _selectEndDate() async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: _endDate,
      firstDate: DateTime.now(),
      lastDate: DateTime(2100),
    );
    if (picked != null) {
      setState(() {
        _endDate = picked;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final productName = widget.product['name'] ?? 'Unknown Product';
    final currentPrice = (widget.product['price'] ?? 0).toDouble();
    final salesCount = widget.product['salesCount'] ?? 0;

    return AlertDialog(
      title: Row(
        children: [
          Icon(Icons.discount, color: Colors.red),
          SizedBox(width: 8),
          Text('Apply Discount'),
        ],
      ),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              productName,
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
            ),
            SizedBox(height: 8),
            Text('Current Price: OMR ${currentPrice.toStringAsFixed(2)}'),
            Text('Total Sales: $salesCount'),

            SizedBox(height: 20),

            // نوع الخصم
            DropdownButtonFormField<String>(
              value: _discountType,
              decoration: InputDecoration(
                labelText: 'Discount Type',
                border: OutlineInputBorder(),
              ),
              items: [
                DropdownMenuItem(value: 'percentage', child: Text('Percentage %')),
                DropdownMenuItem(value: 'fixed', child: Text('Fixed Amount')),
              ],
              onChanged: (value) {
                setState(() {
                  _discountType = value!;
                });
              },
            ),

            SizedBox(height: 16),

            // قيمة الخصم
            TextFormField(
              controller: _discountController,
              keyboardType: TextInputType.number,
              decoration: InputDecoration(
                labelText: _discountType == 'percentage' ? 'Discount %' : 'Discount Amount (OMR)',
                border: OutlineInputBorder(),
                prefixIcon: Icon(Icons.percent),
              ),
            ),

            SizedBox(height: 16),

            // تاريخ الانتهاء
            ListTile(
              title: Text('Valid Until'),
              subtitle: Text(DateFormat('yyyy-MM-dd').format(_endDate)),
              trailing: Icon(Icons.calendar_today),
              onTap: _selectEndDate,
            ),

            // معاينة الخصم
            if (_discountController.text.isNotEmpty)
              Container(
                margin: EdgeInsets.only(top: 16),
                padding: EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.green[50],
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Discount Preview:',
                      style: TextStyle(fontWeight: FontWeight.bold),
                    ),
                    SizedBox(height: 4),
                    Text(
                      _discountType == 'percentage'
                          ? '${_discountController.text}% OFF - New Price: OMR ${(currentPrice * (1 - double.parse(_discountController.text) / 100)).toStringAsFixed(2)}'
                          : 'OMR ${_discountController.text} OFF - New Price: OMR ${(currentPrice - double.parse(_discountController.text)).toStringAsFixed(2)}',
                    ),
                  ],
                ),
              ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: Text('Cancel'),
        ),
        ElevatedButton(
          onPressed: _applyDiscount,
          style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
          child: Text('Apply Discount'),
        ),
      ],
    );
  }
}