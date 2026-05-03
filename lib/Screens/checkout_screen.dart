import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:skinglow/Screens/payment.dart';
import 'package:skinglow/Screens/payment_model.dart';
import 'package:skinglow/Screens/receipt_model.dart';
import 'Account_Information.dart';
import 'cart_model.dart';
import 'deliveryDelails.dart';
import 'order_confirmation.dart';
import 'dart:async';

class CheckoutScreen extends StatefulWidget {
  @override
  _CheckoutScreenState createState() => _CheckoutScreenState();
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
}

class _CheckoutScreenState extends State<CheckoutScreen> {
  final User? user = FirebaseAuth.instance.currentUser;
  final DatabaseReference _databaseRef = FirebaseDatabase.instance.ref().child('users');

  String _userName = '';
  String _userPhone = '';
  String _userAddress = '';
  String _userCity = '';
  String _userState = '';
  String _userZipCode = '';
  bool _isLoading = true;

  String _cardNumber = '**** **** **** 1234';
  Map<String, dynamic>? _savedCardData;

  TextEditingController _promoCodeController = TextEditingController();
  DiscountCoupon? _appliedCoupon;
  double _discountAmount = 0.0;
  bool _isApplyingCoupon = false;

  // Delivery time estimates based on location
  final Map<String, DeliveryEstimate> _deliveryEstimates = {
    'muscat': DeliveryEstimate(minDays: 2, maxDays: 4, baseFee: 1.0),
    'seeb': DeliveryEstimate(minDays: 2, maxDays: 4, baseFee: 1.0),
    'bawshar': DeliveryEstimate(minDays: 2, maxDays: 4, baseFee: 1.0),
    'salalah': DeliveryEstimate(minDays: 4, maxDays: 7, baseFee: 3.0),
    'sohar': DeliveryEstimate(minDays: 3, maxDays: 5, baseFee: 2.0),
    'nizwa': DeliveryEstimate(minDays: 3, maxDays: 6, baseFee: 2.5),
    'sur': DeliveryEstimate(minDays: 4, maxDays: 7, baseFee: 3.0),
    'ibri': DeliveryEstimate(minDays: 4, maxDays: 8, baseFee: 3.5),
    'rustaq': DeliveryEstimate(minDays: 3, maxDays: 6, baseFee: 2.5),
    'bahla': DeliveryEstimate(minDays: 4, maxDays: 7, baseFee: 3.0),
    // Other cities
    'default': DeliveryEstimate(minDays: 5, maxDays: 10, baseFee: 2.0),
  };

  DeliveryEstimate get _currentDeliveryEstimate {
    if (_userCity.isEmpty) return _deliveryEstimates['default']!;

    String cityKey = _userCity.toLowerCase().trim();
    String stateKey = _userState.toLowerCase().trim();

    // Muscat - Fastest delivery
    if (_userCity.contains('Muscat') || _userState.contains('Muscat')) {
      return DeliveryEstimate(minDays: 1, maxDays: 2, baseFee: 1.0);
    }

    // Nearby governorates
    else if (['North Al Batinah', 'South Al Batinah', 'North Al Sharqiyah']
        .any((state) => _userState.contains(state))) {
      return DeliveryEstimate(minDays: 2, maxDays: 4, baseFee: 1.5);
    }

    // Medium distance governorates
    else if (['Al Dakhiliyah', 'Al Dhahirah', 'South Al Sharqiyah']
        .any((state) => _userState.contains(state))) {
      return DeliveryEstimate(minDays: 3, maxDays: 5, baseFee: 2.0);
    }

    // Far governorates
    else if (['Dhofar', 'Al Wusta', 'Musandam']
        .any((state) => _userState.contains(state))) {
      return DeliveryEstimate(minDays: 4, maxDays: 7, baseFee: 3.0);
    }

    return _deliveryEstimates['default']!;
  }

  double get _deliveryFee => _currentDeliveryEstimate.baseFee;

  List<String> get _estimatedDeliveryDates {
    final DateTime now = DateTime.now();
    final DateTime minDate = now.add(Duration(days: _currentDeliveryEstimate.minDays));
    final DateTime maxDate = now.add(Duration(days: _currentDeliveryEstimate.maxDays));

    return [
      "${minDate.day}/${minDate.month}/${minDate.year}",
      "${maxDate.day}/${maxDate.month}/${maxDate.year}" // ✅ تصحيح هنا
    ];
  }

  String get _deliveryTimeRange {
    final estimate = _currentDeliveryEstimate;
    if (estimate.minDays == estimate.maxDays) {
      return '${estimate.minDays} day';
    } else {
      return '${estimate.minDays}-${estimate.maxDays} days';
    }
  }

  String get _deliveryAreaInfo {
    if (_userCity.isEmpty) return 'Location not set';

    final estimate = _currentDeliveryEstimate;
    String cityName = _userCity;

    if (estimate.minDays <= 2) {
      return 'Fast delivery area ($cityName)';
    } else if (estimate.minDays <= 3) {
      return 'Medium delivery area ($cityName)';
    } else {
      return 'Remote area ($cityName)';
    }
  }

  // Calculate total amounts with discount
  double get _subtotal {
    final cart = Provider.of<Cart>(context, listen: false);
    return cart.totalAmount;
  }

  double get _taxAmount => _subtotal * 0.05;

  double get _totalBeforeDiscount => _subtotal + _taxAmount + _deliveryFee;

  double get _finalTotal {
    return _totalBeforeDiscount - _discountAmount;
  }

  // ✅ الحصول على الخصم من السلة
  double get _cartDiscount {
    final cart = Provider.of<Cart>(context, listen: false);
    return cart.totalDiscount;
  }

  // ✅ الحصول على السعر الأصلي بدون خصم
  double get _originalSubtotal {
    final cart = Provider.of<Cart>(context, listen: false);
    return cart.totalAmountWithoutDiscount;
  }

  // دالة لتحديث الخصم وإعادة بناء الواجهة
  void _updateDiscount() {
    if (_appliedCoupon != null) {
      _calculateDiscount();
    } else {
      setState(() {
        _discountAmount = 0.0;
      });
    }
  }

  Future<void> _applyCoupon() async {
    if (_promoCodeController.text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Please enter a promo code'))
      );
      return;
    }

    setState(() {
      _isApplyingCoupon = true;
    });

    try {
      final snapshot = await FirebaseDatabase.instance
          .ref('discountCoupons')
          .orderByChild('code')
          .equalTo(_promoCodeController.text.toUpperCase())
          .once();

      if (snapshot.snapshot.value != null) {
        final Map<dynamic, dynamic> values = snapshot.snapshot.value as Map;
        final couponData = values.values.first as Map<dynamic, dynamic>;

        final now = DateTime.now();
        final startDate = DateTime.fromMillisecondsSinceEpoch(couponData['startDate']);
        final endDate = DateTime.fromMillisecondsSinceEpoch(couponData['endDate']);
        final bool isActive = couponData['isActive'] == true;
        final bool isValidDate = now.isAfter(startDate) && now.isBefore(endDate);

        if (isActive && isValidDate) {
          setState(() {
            _appliedCoupon = DiscountCoupon(
              id: couponData['id'],
              code: couponData['code'],
              discountType: couponData['discountType'],
              discountValue: (couponData['discountValue'] as num).toDouble(),
              startDate: startDate,
              endDate: endDate,
              isActive: isActive,
            );
          });

          _updateDiscount();

          ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text('Discount applied successfully!'),
                backgroundColor: Colors.green,
              )
          );
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text('Invalid or expired promo code'),
                backgroundColor: Colors.red,
              )
          );
        }
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Invalid promo code'),
              backgroundColor: Colors.red,
            )
        );
      }
    } catch (e) {
      print('Error applying coupon: $e');
      ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error validating code: $e'))
      );
    } finally {
      setState(() {
        _isApplyingCoupon = false;
      });
    }
  }

  void _calculateDiscount() {
    if (_appliedCoupon == null) {
      setState(() {
        _discountAmount = 0.0;
      });
      return;
    }

    final cart = Provider.of<Cart>(context, listen: false);
    double subtotal = cart.totalAmount;

    if (_appliedCoupon!.discountType == 'percentage') {
      _discountAmount = subtotal * (_appliedCoupon!.discountValue / 100);
    } else {
      _discountAmount = _appliedCoupon!.discountValue;
    }

    if (_discountAmount > subtotal) {
      _discountAmount = subtotal;
    }

    setState(() {});
  }

  void _removeCoupon() {
    setState(() {
      _appliedCoupon = null;
      _discountAmount = 0.0;
      _promoCodeController.clear();
    });

    ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Discount removed'))
    );
  }

  Future<bool> _checkCardBalance() async {
    try {
      if (_cardNumber.isEmpty || _cardNumber == 'No card saved') {
        return false;
      }

      final lastFourDigits = _cardNumber.split(' ').last;

      final paymentProvider = Provider.of<Payment>(context, listen: false);
      final balanceCheck = await paymentProvider.checkCardBalance(lastFourDigits);

      if (balanceCheck['error'] != null) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error checking card balance: ${balanceCheck['error']}'),
            backgroundColor: Colors.red,
          ),
        );
        return false;
      }

      final double balance = (balanceCheck['assignedBalance'] as num?)?.toDouble() ?? 0;
      final bool isActive = balanceCheck['isActive'] as bool? ?? false;

      if (!isActive) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Your saved card is inactive. Please update your payment method.'),
            backgroundColor: Colors.red,
            duration: Duration(seconds: 3),
          ),
        );
        return false;
      }

      if (balance < _finalTotal) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Insufficient balance. '),
            backgroundColor: Colors.red,
            duration: Duration(seconds: 3),
          ),
        );
        return false;
      }

      return true;
    } catch (e) {
      print('Error checking card balance: $e');
      return false;
    }
  }

  Future<void> _saveOrderToCentralSystem(
      Map<String, dynamic> orderData,
      String orderId,
      String userName,
      String userEmail
      ) async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) {
        print('❌ User is null, cannot save order');
        return;
      }

      print('💾 Starting to save order $orderId to both systems...');

      try {
        await FirebaseDatabase.instance
            .ref('users/${user.uid}/orders/$orderId')
            .set(orderData);
        print('✅ Successfully saved to users/${user.uid}/orders/$orderId');
      } catch (e) {
        print('❌ Failed to save to user path: $e');
      }

      try {
        final centralOrderData = {
          ...orderData,
          'userId': user.uid,
          'userName': userName,
          'userEmail': user.email ?? '',
          'createdAt': ServerValue.timestamp,
          'adminVisible': true
        };

        await FirebaseDatabase.instance
            .ref('all_orders/$orderId')
            .set(centralOrderData);
        print('✅ Successfully saved to all_orders/$orderId');

      } catch (e) {
        print('❌ Failed to save to central system: $e');
        try {
          final simpleOrderData = {
            ...orderData,
            'userId': user.uid,
            'userName': userName,
            'userEmail': user.email ?? '',
            'createdAt': DateTime.now().millisecondsSinceEpoch,
          };

          await FirebaseDatabase.instance
              .ref('all_orders/$orderId')
              .set(simpleOrderData);
          print('✅ Successfully saved simplified version to all_orders');
        } catch (e2) {
          print('❌ Failed to save simplified version: $e2');
        }
      }

      print('🎉 Order saved successfully to both systems');
    } catch (e) {
      print('💥 CRITICAL ERROR in _saveOrderToCentralSystem: $e');
      throw e;
    }
  }

  @override
  void initState() {
    super.initState();
    _checkFirebaseConnection();
    _loadUserData();
  }

  Future<void> _checkFirebaseConnection() async {
    try {
      await FirebaseDatabase.instance.ref().child('.info/connected').once();
      print('✅ Firebase connection successful');
    } catch (e) {
      print('❌ Firebase connection failed: $e');
    }
  }

  Future<void> _loadUserData() async {
    if (user == null) {
      setState(() => _isLoading = false);
      return;
    }

    try {
      final userFuture = _databaseRef.child(user!.uid).get();
      final deliveryFuture = _databaseRef.child(user!.uid).child('deliveryDetails').get();
      final cardFuture = _databaseRef.child(user!.uid).child('paymentMethods').child('primary').get();

      final results = await Future.wait([userFuture, deliveryFuture, cardFuture]);

      if (results[0].exists) {
        final userData = results[0].value as Map<dynamic, dynamic>;
        setState(() {
          _userName = userData['name'] ?? '';
        });
      }

      if (results[1].exists) {
        final deliveryData = results[1].value as Map<dynamic, dynamic>;
        setState(() {
          _userPhone = deliveryData['phone'] ?? '';
          _userAddress = deliveryData['address'] ?? '';
          _userCity = deliveryData['city'] ?? '';
          _userState = deliveryData['state'] ?? '';
          _userZipCode = deliveryData['zipCode'] ?? '';
        });
      }

      if (results[2].exists) {
        final cardData = results[2].value as Map<dynamic, dynamic>;
        setState(() {
          _cardNumber = cardData['displayCardNumber'] ?? '**** **** **** 1234';
          _savedCardData = Map<String, dynamic>.from(cardData);
        });
      } else {
        setState(() {
          _cardNumber = '';
          _savedCardData = null;
        });
      }

    } catch (e) {
      print("Error loading user data: $e");
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  bool _isOrderDataComplete() {
    if (_userName.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Please complete your profile information'),
          backgroundColor: Colors.orange,
        ),
      );
      return false;
    }

    if (_userPhone.isEmpty || _userAddress.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Please complete your delivery information'),
          backgroundColor: Colors.orange,
        ),
      );
      return false;
    }

    if (_cardNumber.isEmpty || _cardNumber.contains('No card')) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Please add a payment method'),
          backgroundColor: Colors.orange,
        ),
      );
      return false;
    }

    return true;
  }

  @override
  Widget build(BuildContext context) {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_appliedCoupon != null && _discountAmount == 0) {
        _calculateDiscount();
      }
    });

    final cart = Provider.of<Cart>(context);
    final cartItems = cart.items.values.toList();

    final double taxAmount = _subtotal * 0.05;
    final List<String> deliveryDates = _estimatedDeliveryDates;

    return Scaffold(
      appBar: AppBar(
        title: Text('Checkout'),
        backgroundColor: Color(0xFFFFE4F3),
        foregroundColor: Color(0xFF914D74),
      ),
      body: _isLoading
          ? Center(child: CircularProgressIndicator())
          : cartItems.isEmpty
          ? Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.shopping_cart_outlined, size: 64, color: Colors.grey),
            SizedBox(height: 16),
            Text('Your cart is empty'),
            SizedBox(height: 8),
            Text('Add some products to checkout', style: TextStyle(color: Colors.grey)),
          ],
        ),
      )
          : SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildSectionHeader('Delivery Information'),
            Card(
              margin: EdgeInsets.only(bottom: 16),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    ListTile(
                      leading: Icon(Icons.person, color: Color(0xFF914D74)),
                      title: Text('Customer Name'),
                      subtitle: Text(_userName.isNotEmpty ? _userName : 'Not provided'),
                    ),
                    InkWell(
                      onTap: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(builder: (context) => AccountInformationPage()),
                        ).then((_) {
                          _loadUserData();
                        });
                      },
                      child: ListTile(
                        leading: Icon(Icons.phone, color: Color(0xFF914D74)),
                        title: Text('Phone Number'),
                        subtitle: Text(_userPhone.isNotEmpty ? _userPhone : 'Not provided'),
                        trailing: Icon(Icons.edit, color: Colors.grey, size: 18),
                      ),
                    ),
                    InkWell(
                      onTap: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(builder: (context) => DeliveryDetailsPage()),
                        ).then((_) {
                          _loadUserData();
                        });
                      },
                      child: ListTile(
                        leading: Icon(Icons.location_on, color: Color(0xFF914D74)),
                        title: Text('Delivery Address'),
                        subtitle: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            if (_userAddress.isNotEmpty) Text(_userAddress),
                            if (_userCity.isNotEmpty || _userState.isNotEmpty || _userZipCode.isNotEmpty)
                              Text(
                                '${_userCity}${_userCity.isNotEmpty && _userState.isNotEmpty ? ', ' : ''}${_userState}${(_userCity.isNotEmpty || _userState.isNotEmpty) && _userZipCode.isNotEmpty ? ', ' : ''}${_userZipCode}',
                                style: TextStyle(color: Colors.grey[600]),
                              ),
                          ],
                        ),
                        trailing: Icon(Icons.edit, color: Colors.grey, size: 18),
                      ),
                    ),
                  ],
                ),
              ),
            ),

            _buildSectionHeader('Order Summary'),
            Card(
              margin: EdgeInsets.only(bottom: 16),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  children: [
                    ...cartItems.map((item) => _buildCheckoutItem(item)).toList(),
                    SizedBox(height: 16),
                    Divider(),
                    if (_cartDiscount > 0) ...[
                      _buildTotalRow(
                        'Product Discounts',
                        '- OMR ${_cartDiscount.toStringAsFixed(3)}',
                        isDiscount: true,
                      ),
                      SizedBox(height: 8),
                    ],
                    _buildTotalRow('Subtotal', 'OMR ${_subtotal.toStringAsFixed(3)}'),
                    _buildTotalRow('Delivery Fee', 'OMR ${_deliveryFee.toStringAsFixed(3)}'),
                    _buildTotalRow('Tax (5%)', 'OMR ${taxAmount.toStringAsFixed(3)}'),

                    if (_discountAmount > 0) ...[
                      _buildTotalRow(
                        'Discount',
                        '- OMR ${_discountAmount.toStringAsFixed(3)}',
                        isDiscount: true,
                      ),
                      Divider(),
                    ],
                    if (_cartDiscount > 0 || _discountAmount > 0) ...[
                      _buildTotalRow(
                        'Total Discount',
                        '- OMR ${(_cartDiscount + _discountAmount).toStringAsFixed(3)}',
                        isDiscount: true,
                        isBold: true,
                      ),
                      SizedBox(height: 8),
                    ],
                    _buildTotalRow(
                      'Total Amount',
                      'OMR ${_finalTotal.toStringAsFixed(3)}',
                      isBold: true,
                      isMain: true,
                    ),
                    if (_cartDiscount > 0 || _discountAmount > 0)
                      Container(
                        width: double.infinity,
                        margin: EdgeInsets.only(top: 8),
                        padding: EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: Colors.green[50],
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: Colors.green),
                        ),
                        child: Row(
                          children: [
                            Icon(Icons.discount, color: Colors.green, size: 20),
                            SizedBox(width: 8),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    'You saved OMR ${(_cartDiscount + _discountAmount).toStringAsFixed(3)}! 🎉',
                                    style: TextStyle(
                                      fontWeight: FontWeight.bold,
                                      color: Colors.green[800],
                                    ),
                                  ),
                                  if (_cartDiscount > 0 && _discountAmount > 0)
                                    Text(
                                      'Including OMR ${_cartDiscount.toStringAsFixed(3)} from products + OMR ${_discountAmount.toStringAsFixed(3)} from promo code',
                                      style: TextStyle(
                                        color: Colors.green[600],
                                        fontSize: 12,
                                      ),
                                    ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                  ],
                ),
              ),
            ),

            _buildSectionHeader('Payment Method'),
            InkWell(
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (context) => PaymentPage()),
                ).then((_) => _loadUserData());
              },
              child: Card(
                margin: EdgeInsets.only(bottom: 16),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      ListTile(
                        leading: Icon(Icons.credit_card, color: Color(0xFF914D74)),
                        title: Text('Credit/Debit Card'),
                        subtitle: _cardNumber.isNotEmpty
                            ? Text(_cardNumber)
                            : Text('Tap to add payment method'),
                        trailing: Icon(Icons.arrow_forward_ios, color: Colors.grey, size: 18),
                      ),
                    ],
                  ),
                ),
              ),
            ),

            _buildSectionHeader('Estimated Delivery Time'),
            Card(
              margin: EdgeInsets.only(bottom: 16),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  children: [
                    Row(
                      children: [
                        Icon(Icons.location_on, color: Color(0xFF914D74)),
                        SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                _userCity.isNotEmpty ? _userCity : 'Location not set',
                                style: TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 16,
                                ),
                              ),
                              SizedBox(height: 2),
                              Text(
                                _deliveryAreaInfo,
                                style: TextStyle(
                                  color: Colors.green,
                                  fontSize: 12,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    SizedBox(height: 12),
                    Divider(),
                    SizedBox(height: 8),
                    Row(
                      children: [
                        Icon(Icons.access_time, color: Color(0xFF914D74)),
                        SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                '$_deliveryTimeRange business days',
                                style: TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 16,
                                ),
                              ),
                              SizedBox(height: 4),
                              Text(
                                'Estimated delivery: ${deliveryDates[0]} - ${deliveryDates[1]}',
                                style: TextStyle(color: Colors.grey[600]),
                              ),
                              SizedBox(height: 4),
                              Text(
                                'Delivery to: ${_userCity.isNotEmpty ? _userCity : 'your location'}',
                                style: TextStyle(
                                  color: Color(0xFF914D74),
                                  fontSize: 12,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    SizedBox(height: 8),
                    if (_userCity.isEmpty)
                      Container(
                        width: double.infinity,
                        padding: EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: Colors.orange[50],
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Row(
                          children: [
                            Icon(Icons.info, color: Colors.orange, size: 16),
                            SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                'Set your location to get accurate delivery time',
                                style: TextStyle(
                                  color: Colors.orange[800],
                                  fontSize: 12,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                  ],
                ),
              ),
            ),

            _buildSectionHeader('Promo Code'),
            Card(
              margin: EdgeInsets.only(bottom: 24),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  children: [
                    if (_appliedCoupon != null) ...[
                      Container(
                        width: double.infinity,
                        padding: EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: Colors.green[50],
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: Colors.green),
                        ),
                        child: Row(
                          children: [
                            Icon(Icons.check_circle, color: Colors.green, size: 20),
                            SizedBox(width: 8),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    'Coupon Applied: ${_appliedCoupon!.code}',
                                    style: TextStyle(fontWeight: FontWeight.bold, color: Colors.green[800]),
                                  ),
                                  Text(
                                    _appliedCoupon!.discountType == 'percentage'
                                        ? '${_appliedCoupon!.discountValue}% discount'
                                        : 'OMR ${_appliedCoupon!.discountValue.toStringAsFixed(3)} discount',
                                    style: TextStyle(color: Colors.green[600], fontSize: 12),
                                  ),
                                ],
                              ),
                            ),
                            IconButton(
                              icon: Icon(Icons.close, color: Colors.green),
                              onPressed: _removeCoupon,
                            ),
                          ],
                        ),
                      ),
                      SizedBox(height: 12),
                    ],
                    Row(
                      children: [
                        Expanded(
                          child: TextField(
                            controller: _promoCodeController,
                            decoration: InputDecoration(
                              hintText: 'Enter promo code',
                              border: OutlineInputBorder(),
                            ),
                            enabled: _appliedCoupon == null,
                          ),
                        ),
                        SizedBox(width: 12),
                        Container(
                          decoration: BoxDecoration(
                            color: _appliedCoupon == null ? Color(0xFF914D74) : Colors.grey,
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: TextButton(
                            onPressed: _appliedCoupon == null ? _applyCoupon : null,
                            child: _isApplyingCoupon
                                ? SizedBox(
                              width: 16,
                              height: 16,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                              ),
                            )
                                : Text(
                              _appliedCoupon == null ? 'Apply' : 'Applied',
                              style: TextStyle(color: Colors.white),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),

            Row(
              children: [
                Icon(Icons.check_circle, color: Color(0xFF914D74), size: 16),
                SizedBox(width: 8),
                Expanded(
                  child: Text.rich(
                    TextSpan(
                      children: [
                        TextSpan(
                          text: 'I agree to the ',
                          style: TextStyle(color: Colors.grey[600]),
                        ),
                        TextSpan(
                          text: 'Terms & Conditions',
                          style: TextStyle(
                            color: Color(0xFF914D74),
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        TextSpan(
                          text: ' and ',
                          style: TextStyle(color: Colors.grey[600]),
                        ),
                        TextSpan(
                          text: 'Privacy Policy',
                          style: TextStyle(
                            color: Color(0xFF914D74),
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),

            SizedBox(height: 32),

            Container(
              width: double.infinity,
              height: 56,
              child: ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: Color(0xFF914D74),
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  elevation: 2,
                ),
                onPressed: () {
                  if (_isOrderDataComplete()) {
                    _showOrderConfirmation(context, _finalTotal);
                  }
                },
                child: Text(
                  'CONFIRM ORDER - OMR ${_finalTotal.toStringAsFixed(3)}',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                ),
              ),
            ),

            SizedBox(height: 16),
            Center(
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.lock, color: Colors.grey, size: 16),
                  SizedBox(width: 4),
                  Text(
                    'Secure payment encrypted',
                    style: TextStyle(
                      color: Colors.grey,
                      fontSize: 12,
                    ),
                  ),
                ],
              ),
            ),
            SizedBox(height: 20),
          ],
        ),
      ),
    );
  }

  Widget _buildSectionHeader(String title) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12.0, top: 8.0),
      child: Text(
        title,
        style: TextStyle(
          fontSize: 18,
          fontWeight: FontWeight.bold,
          color: Color(0xFF914D74),
        ),
      ),
    );
  }

  Widget _buildCheckoutItem(CartItem item) {
    final double itemTax = (item.price * item.quantity) * 0.05;
    final bool hasDiscount = item.hasDiscount;
    final double originalPrice = item.originalPrice;
    final double discountAmount = item.discountAmount;
    final double totalDiscount = discountAmount * item.quantity;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8.0),
      child: Column(
        children: [
          Row(
            children: [
              Stack(
                children: [
                  Container(
                    width: 50,
                    height: 50,
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(8),
                      color: Colors.grey[200],
                    ),
                    child: item.imageUrl.isNotEmpty
                        ? Image.network(
                      item.imageUrl,
                      fit: BoxFit.cover,
                      errorBuilder: (context, error, stackTrace) {
                        return Icon(Icons.shopping_bag, color: Color(0xFF914D74));
                      },
                    )
                        : Icon(Icons.shopping_bag, color: Color(0xFF914D74)),
                  ),
                  if (hasDiscount)
                    Positioned(
                      top: -4,
                      right: -4,
                      child: Container(
                        padding: EdgeInsets.symmetric(horizontal: 4, vertical: 2),
                        decoration: BoxDecoration(
                          color: Colors.red,
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Text(
                          'OFF',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 8,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ),
                ],
              ),
              SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      item.name,
                      style: TextStyle(fontWeight: FontWeight.w500),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                    SizedBox(height: 4),
                    Text(
                      'Qty: ${item.quantity}',
                      style: TextStyle(color: Colors.grey[600]),
                    ),
                    if (hasDiscount)
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          SizedBox(height: 4),
                          Row(
                            children: [
                              Text(
                                'OMR ${(originalPrice * item.quantity).toStringAsFixed(3)}',
                                style: TextStyle(
                                  color: Colors.grey,
                                  fontSize: 12,
                                  decoration: TextDecoration.lineThrough,
                                ),
                              ),
                              SizedBox(width: 8),
                              Container(
                                padding: EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                decoration: BoxDecoration(
                                  color: Colors.red[50],
                                  borderRadius: BorderRadius.circular(4),
                                  border: Border.all(color: Colors.red),
                                ),
                                child: Text(
                                  'Save OMR ${totalDiscount.toStringAsFixed(3)}',
                                  style: TextStyle(
                                    color: Colors.red,
                                    fontSize: 10,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    SizedBox(height: 2),
                    Text(
                      'Tax: OMR ${itemTax.toStringAsFixed(3)}',
                      style: TextStyle(
                        color: Colors.green,
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    'OMR ${(item.price * item.quantity).toStringAsFixed(3)}',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      color: hasDiscount ? Colors.red : Color(0xFF914D74),
                      fontSize: hasDiscount ? 16 : 14,
                    ),
                  ),
                  SizedBox(height: 2),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      if (hasDiscount)
                        Text(
                          'OMR ${originalPrice.toStringAsFixed(3)}',
                          style: TextStyle(
                            color: Colors.grey,
                            fontSize: 10,
                            decoration: TextDecoration.lineThrough,
                          ),
                        ),
                      Text(
                        'OMR ${item.price.toStringAsFixed(3)} each',
                        style: TextStyle(
                          color: hasDiscount ? Colors.red : Colors.grey[600],
                          fontSize: hasDiscount ? 12 : 10,
                          fontWeight: hasDiscount ? FontWeight.bold : FontWeight.normal,
                        ),
                      ),
                    ],
                  ),
                  if (hasDiscount && item.discount != null)
                    Container(
                      margin: EdgeInsets.only(top: 4),
                      padding: EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        color: Colors.green[50],
                        borderRadius: BorderRadius.circular(4),
                        border: Border.all(color: Colors.green),
                      ),
                      child: Text(
                        _getDiscountText(item.discount!),
                        style: TextStyle(
                          color: Colors.green,
                          fontSize: 10,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                ],
              ),
            ],
          ),
          Divider(height: 16),
        ],
      ),
    );
  }

  String _getDiscountText(Map<String, dynamic> discount) {
    final discountType = discount['discountType'];
    final discountValue = discount['discountValue']?.toDouble();

    if (discountType == 'percentage') {
      return '${discountValue?.toInt()}% OFF';
    } else if (discountType == 'fixed') {
      return 'OMR ${discountValue?.toStringAsFixed(2)} OFF';
    }
    return 'DISCOUNT';
  }

  Widget _buildTotalRow(String label, String value, {bool isBold = false, bool isMain = false, bool isDiscount = false}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6.0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: TextStyle(
              fontWeight: isBold ? FontWeight.bold : FontWeight.normal,
              color: isDiscount ? Colors.green : (isMain ? Color(0xFF914D74) : Colors.black),
              fontSize: isMain ? 16 : 14,
            ),
          ),
          Text(
            value,
            style: TextStyle(
              fontWeight: isBold ? FontWeight.bold : FontWeight.normal,
              color: isDiscount ? Colors.green : (isMain ? Color(0xFF914D74) : Colors.black),
              fontSize: isMain ? 18 : 14,
            ),
          ),
        ],
      ),
    );
  }

  void _showOrderConfirmation(BuildContext context, double totalAmount) async {
    if (!_isOrderDataComplete()) {
      return;
    }

    final hasSufficientBalance = await _checkCardBalance();
    if (!hasSufficientBalance) {
      return;
    }

    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          title: Text(
            'Confirm Payment',
            style: TextStyle(
              color: Color(0xFF914D74),
              fontWeight: FontWeight.bold,
            ),
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildConfirmationRow('Total Amount', 'OMR ${totalAmount.toStringAsFixed(3)}'),
              _buildConfirmationRow('Payment Method', _cardNumber),
              _buildConfirmationRow('Card Status', '✓ Active with sufficient balance'),
              _buildConfirmationRow('Delivery Location', _userCity.isNotEmpty ? _userCity : 'Not set'),
              _buildConfirmationRow('Delivery Time', _deliveryTimeRange),
              SizedBox(height: 16),
              Container(
                padding: EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.green[50],
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.green),
                ),
                child: Row(
                  children: [
                    Icon(Icons.credit_card, color: Colors.green, size: 16),
                    SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'Card validated ✓\nSufficient balance available',
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.green[800],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: Text('Cancel'),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: Color(0xFF914D74),
                foregroundColor: Colors.white,
              ),
              onPressed: () {
                Navigator.of(context).pop();
                _processOrder(context, totalAmount);
              },
              child: Text('Confirm & Pay'),
            ),
          ],
        );
      },
    );
  }

  Widget _buildConfirmationRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6.0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: TextStyle(fontWeight: FontWeight.w500),
          ),
          Text(
            value,
            style: TextStyle(fontWeight: FontWeight.w400),
          ),
        ],
      ),
    );
  }

  // ✅ أضف هذه الدالة لعرض فشل الدفع
  void _showPaymentFailedDialog(BuildContext context, String title, String message) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: Text(title, style: TextStyle(color: Colors.red)),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.error_outline, color: Colors.red, size: 50),
              SizedBox(height: 16),
              Text(message, textAlign: TextAlign.center),
              SizedBox(height: 16),
              Text(
                'You can:',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
              SizedBox(height: 8),
              ListTile(
                leading: Icon(Icons.credit_card, color: Color(0xFF914D74)),
                title: Text('Try another card'),
                onTap: () {
                  Navigator.of(context).pop();
                  Navigator.push(
                    context,
                    MaterialPageRoute(builder: (context) => PaymentPage()),
                  ).then((_) => _loadUserData());
                },
              ),
              ListTile(
                leading: Icon(Icons.account_balance_wallet, color: Color(0xFF914D74)),
                title: Text('Use wallet balance'),
                onTap: () {
                  Navigator.of(context).pop();
                  // انتقل لصفحة المحفظة
                },
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: Text('Cancel Order'),
            ),
          ],
        );
      },
    );
  }

  void _processOrder(BuildContext context, double totalAmount) {
    final cart = Provider.of<Cart>(context, listen: false);

    // ✅ استخراج تفاصيل البطاقة المحفوظة
    String? fullCardNumber;
    String? cvv;
    String? expiryDate;
    String? cardHolderName;

    if (_savedCardData != null) {
      fullCardNumber = _savedCardData!['fullCardNumber'];
      cvv = _savedCardData!['cvv'];
      expiryDate = _savedCardData!['expiryDate'];
      cardHolderName = _savedCardData!['cardHolderName'];
    }

    print('🔍 === STARTING ORDER PROCESS ===');

    // Save current data copy
    final String currentUserName = _userName;
    final String currentUserPhone = _userPhone;
    final String currentUserAddress = _userAddress;
    final String currentUserCity = _userCity;
    final String currentUserState = _userState;
    final String currentUserZipCode = _userZipCode;
    final String currentCardNumber = _cardNumber;

    // Create order number
    final String orderNumber = 'ORD-${DateTime.now().millisecondsSinceEpoch}';
    final String orderId = DateTime.now().millisecondsSinceEpoch.toString();

    // Navigate to confirmation page first
    Navigator.of(context, rootNavigator: true).pushAndRemoveUntil(
      MaterialPageRoute(
        builder: (context) => OrderConfirmationScreen(
          orderNumber: orderNumber,
          totalAmount: totalAmount,
        ),
      ),
          (route) => false,
    );

    // Process data after navigation
    Future.microtask(() async {
      try {
        print('🔄 Starting async order processing...');

        // Prepare order items WITH originalPrice
        List<Map<String, dynamic>> orderItems = [];
        cart.items.forEach((key, item) {
          orderItems.add({
            'id': item.id,
            'name': item.name,
            'price': item.price,
            'originalPrice': item.originalPrice,
            'quantity': item.quantity,
            'imageUrl': item.imageUrl,
          });
        });

        final double taxAmount = _subtotal * 0.05;
        final double finalTotal = _finalTotal;

        // Prepare basic order data
        Map<String, dynamic> orderData = {
          'orderId': orderId,
          'orderNumber': orderNumber,
          'userId': user!.uid,
          'userName': currentUserName,
          'userEmail': user!.email ?? 'No email',
          'items': orderItems,
          'subtotal': cart.totalAmount,
          'taxAmount': taxAmount,
          'deliveryFee': _deliveryFee,
          'discountAmount': _discountAmount,
          'totalAmount': finalTotal,
          'customerName': currentUserName,
          'customerPhone': currentUserPhone,
          'deliveryAddress': {
            'address': currentUserAddress,
            'city': currentUserCity,
            'state': currentUserState,
            'zipCode': currentUserZipCode,
          },
          'deliveryEstimate': {
            'city': currentUserCity,
            'minDays': _currentDeliveryEstimate.minDays,
            'maxDays': _currentDeliveryEstimate.maxDays,
            'timeRange': _deliveryTimeRange,
            'fee': _deliveryFee,
          },
          'paymentMethod': currentCardNumber,
          'orderDate': DateTime.now().millisecondsSinceEpoch,
          'status': 'Pending',
          'paymentStatus': 'paid',
          'createdAt': DateTime.now().millisecondsSinceEpoch,
          'updatedAt': DateTime.now().millisecondsSinceEpoch,
        };

        if (_appliedCoupon != null) {
          orderData['appliedCoupon'] = {
            'code': _appliedCoupon!.code,
            'discountType': _appliedCoupon!.discountType,
            'discountValue': _appliedCoupon!.discountValue,
          };
        }

        print('💾 Attempting to save order data...');

        // Save to central system
        await _saveOrderToCentralSystem(
            orderData,
            orderId,
            currentUserName,
            user!.email ?? ''
        );

        print('📧 Sending digital receipt...');
        try {
          bool receiptSent = await ReceiptService.sendDigitalReceipt(
            customerName: currentUserName,
            customerEmail: user!.email ?? '',
            orderNumber: orderNumber,
            subtotal: cart.totalAmount,
            taxAmount: taxAmount,
            deliveryFee: _deliveryFee,
            discountAmount: _discountAmount,
            totalAmount: finalTotal,
            items: orderItems,
            deliveryAddress: {
              'fullName': currentUserName,
              'address': currentUserAddress,
              'city': currentUserCity,
              'state': currentUserState,
              'zipCode': currentUserZipCode,
              'country': 'Oman',
              'phone': currentUserPhone,
            },
            billingAddress: {
              'fullName': currentUserName,
              'address': currentUserAddress,
              'city': currentUserCity,
              'state': currentUserState,
              'zipCode': currentUserZipCode,
              'country': 'Oman',
            },
            paymentMethod: currentCardNumber,
          );

          if (receiptSent) {
            print('✅ Digital receipt sent successfully');
          } else {
            print('⚠️ Could not send receipt. Check EmailJS dashboard for details.');
          }
        } catch (e) {
          print('❌ Email sending failed (non-critical): $e');
        }

        print('🎉 Order processing completed successfully');

        // Clear cart after everything is done
        cart.clear();
        print('🧹 Cart cleared');

      } catch (e) {
        print('💥 CRITICAL ERROR in order processing: $e');

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to save order details: $e'),
            backgroundColor: Colors.red,
            duration: Duration(seconds: 5),
          ),
        );
      }
    });
  }
}

class DeliveryEstimate {
  final int minDays;
  final int maxDays;
  final double baseFee;

  DeliveryEstimate({
    required this.minDays,
    required this.maxDays,
    required this.baseFee,
  });
}
