import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:provider/provider.dart';

import 'cart_model.dart';

class MyOrdersPage extends StatefulWidget {
  @override
  _MyOrdersPageState createState() => _MyOrdersPageState();
}

class _MyOrdersPageState extends State<MyOrdersPage> {
  final User? user = FirebaseAuth.instance.currentUser;
  List<Map<dynamic, dynamic>> _orders = [];
  bool _isLoading = true;
  String _errorMessage = '';

  // الألوان الوردية الفاتحة الجميلة
  final Color _primaryColor = Color(0xFF914D74); // وردي جميل
  //جديد
  final Color _primaryColor1 = Color(0xFFA56289);
  final Color _primaryColor2 = Color(0xFFB5719E);
  final Color _primaryColor3 = Color(0xFFC585B3);
  final Color _primaryColor4 = Color(0xFFD59AC8);
  final Color _primaryColor5 = Color(0xFFE5AFDD);
  //---------------------
  final Color _secondaryColor = Color(0xFFFFE4F3); // وردي فاتح جداً
  final Color _accentColor = Color(0xFFFFF0F8); // وردي شفاف جميل
  final Color _backgroundColor = Color(0xFFFDF2F6); // خلفية وردية فاتحة


  @override
  void initState() {
    super.initState();
    _debugCheckData();
    _loadUserOrders();
    _setupRealtimeListener();
  }

  void _debugCheckData() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    print('🔍 === DEBUGGING MY ORDERS DATA ===');

    try {
      final userRef = FirebaseDatabase.instance.ref('users/${user.uid}');
      final userSnapshot = await userRef.get();

      if (userSnapshot.exists) {
        final userData = userSnapshot.value as Map<dynamic, dynamic>;
        print('✅ User data exists');
        print('📁 User keys: ${userData.keys}');

        if (userData.containsKey('orders')) {
          final orders = userData['orders'] as Map<dynamic, dynamic>;
          print('🎯 ORDERS FOUND: ${orders.length} orders');

          orders.forEach((key, value) {
            print('   📦 Order $key: ${value}');
          });
        } else {
          print('❌ NO ORDERS KEY FOUND in user data');

          final potentialOrders = userData.entries.where((entry) {
            final key = entry.key.toString();
            return key.length == 13 || key.startsWith('order') || key.startsWith('ORD');
          });

          print('🔍 Potential orders: ${potentialOrders.length}');
        }
      } else {
        print('❌ User data not found');
      }
    } catch (e) {
      print('❌ Debug error: $e');
    }
  }

  void _setupRealtimeListener() {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    final userRef = FirebaseDatabase.instance.ref('users/${user.uid}');
    userRef.onValue.listen((event) {
      print('🔄 Real-time update received');
      _loadUserOrders();
    });
  }

  Future<void> _loadUserOrders() async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) {
        setState(() {
          _isLoading = false;
          _errorMessage = 'Please login to view your orders';
        });
        return;
      }

      print('🔍 Loading orders for user: ${user.uid}');

      final userRef = FirebaseDatabase.instance.ref('users/${user.uid}');
      final snapshot = await userRef.get();

      if (snapshot.exists) {
        final userData = snapshot.value as Map<dynamic, dynamic>;
        print(' User data loaded, keys: ${userData.keys}');

        List<Map<dynamic, dynamic>> foundOrders = [];

        if (userData['orders'] != null && userData['orders'] is Map) {
          final ordersMap = userData['orders'] as Map<dynamic, dynamic>;
          print('✅ Found orders folder with ${ordersMap.length} orders');

          foundOrders = ordersMap.entries.map((entry) {
            final orderData = entry.value;
            Map<dynamic, dynamic> order;

            if (orderData is Map) {
              order = Map<dynamic, dynamic>.from(orderData);
            } else {
              order = {'rawData': orderData};
            }

            order['orderId'] = entry.key.toString();
            print(' Processing order: ${entry.key}');
            return order;
          }).toList();
        } else {
          print('🔍 Searching for direct orders in user data');
          final potentialOrders = userData.entries.where((entry) {
            final key = entry.key.toString();
            final value = entry.value;

            return (key.length == 13 ||
                key.startsWith('order') ||
                key.startsWith('ORD') ||
                (value is Map &&
                    (value.containsKey('orderNumber') ||
                        value.containsKey('totalAmount'))));
          });

          foundOrders = potentialOrders.map((entry) {
            final orderData = entry.value;
            Map<dynamic, dynamic> order;

            if (orderData is Map) {
              order = Map<dynamic, dynamic>.from(orderData);
            } else {
              order = {'rawData': orderData};
            }

            order['orderId'] = entry.key.toString();
            print('🛒 Found direct order: ${entry.key}');
            return order;
          }).toList();
        }

        // ترتيب الطلبيات من الأحدث للأقدم
        foundOrders.sort((a, b) {
          final dateA = a['orderDate'] ?? a['createdAt'] ?? a['timestamp'] ?? 0;
          final dateB = b['orderDate'] ?? b['createdAt'] ?? b['timestamp'] ?? 0;
          return (dateB as num).compareTo(dateA as num);
        });

        setState(() {
          _orders = foundOrders;
          _isLoading = false;
        });

        print('🎯 Total orders loaded: ${_orders.length}');

        // طباعة تفاصيل الطلبيات
        for (final order in _orders) {
          print('📋 Order ${order['orderId']}: ${order['orderNumber']} - OMR ${order['totalAmount']}');
        }
      } else {
        print('❌ No user data found');
        setState(() {
          _isLoading = false;
          _orders = [];
        });
      }
    } catch (e) {
      print('❌ Error loading orders: $e');
      setState(() {
        _isLoading = false;
        _errorMessage = 'Error loading orders: $e';
      });
    }
  }

  String _formatTimestamp(dynamic timestamp) {
    if (timestamp == null) return 'Unknown date';

    try {
      if (timestamp is int) {
        final date = DateTime.fromMillisecondsSinceEpoch(timestamp);
        return '${date.day}/${date.month}/${date.year} ${date.hour}:${date.minute.toString().padLeft(2, '0')}';
      } else if (timestamp is String) {
        return timestamp;
      }
      return 'Invalid date';
    } catch (e) {
      return 'Unknown date';
    }
  }

  Widget _buildOrderCard(Map<dynamic, dynamic> order, int index) {
    final orderId = order['orderId']?.toString() ?? 'Unknown';
    final orderNumber = order['orderNumber'] ?? orderId;
    final totalAmount = order['totalAmount'] ?? _calculateTotal(order);
    final status = order['status']?.toString() ?? 'Pending';
    final timestamp = order['orderDate'] ?? order['createdAt'] ?? order['timestamp'];

    final bool canCancel = _canCancelOrder(status);

    // التحقق إذا كان الطلب مكتمل ويمكن تقييمه
    final bool canRate = true; // جعل جميع الطلبات قابلة للتقييم للتجربة
    final bool hasRated = order['hasRated'] == true;

    return Card(
      margin: EdgeInsets.symmetric(vertical: 8, horizontal: 16),
      elevation: 3,
      color: Colors.white,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
      ),
      child: InkWell(
        onTap: () {
          _navigateToOrderDetails(order);
        },
        child: Padding(
          padding: EdgeInsets.all(16),
          child: Column(
            children: [
              Row(
                children: [
                  // أيقونة الحالة
                  Container(
                    padding: EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: _getStatusColor(status).withOpacity(0.15),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Icon(
                      _getStatusIcon(status),
                      color: _getStatusColor(status),
                      size: 28,
                    ),
                  ),
                  SizedBox(width: 12),
                  // معلومات الطلب
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Order #$orderNumber',
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 16,
                            color: _primaryColor,
                          ),
                        ),
                        SizedBox(height: 6),
                        Text(
                          '${_formatTimestamp(timestamp)}',
                          style: TextStyle(
                            color: Colors.grey.shade600,
                            fontSize: 13,
                          ),
                        ),
                        SizedBox(height: 6),
                        Text(
                          'OMR ${totalAmount.toStringAsFixed(3)}',
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 16,
                            color: _primaryColor,
                          ),
                        ),
                      ],
                    ),
                  ),
                  // الحالة وزر التقييم في نفس الخط
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      // الحالة
                      Container(
                        padding: EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                        decoration: BoxDecoration(
                          color: _getStatusColor(status),
                          borderRadius: BorderRadius.circular(15),
                        ),
                        child: Text(
                          status.toUpperCase(),
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 11,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                      SizedBox(height: 8),
                      // زر التقييم
                      if (canRate && !hasRated)
                        ElevatedButton(
                          onPressed: () {
                            _navigateToRatingPage(order);
                          },
                          style: ElevatedButton.styleFrom(
                            backgroundColor: _primaryColor2,
                            foregroundColor: Colors.white,
                            minimumSize: Size(40, 20),
                            padding: EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(8),
                            ),
                            elevation: 2,
                          ),
                          child: Text(
                            'Rate',
                            style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
                          ),
                        ),
                    ],
                  ),
                ],
              ),
              // رسالة "Ready for Rating"
              if (canRate && !hasRated) ...[
                SizedBox(height: 6),
                Container(
                  width: double.infinity,
                  padding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  decoration: BoxDecoration(
                    color: _primaryColor.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: _primaryColor.withOpacity(0.3)),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.star, color: _primaryColor, size: 16),
                      SizedBox(width: 6),
                      Text(
                        'Ready for Rating',
                        style: TextStyle(
                          color: _primaryColor,
                          fontSize: 13,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
  Future<void> _cancelOrder(Map<dynamic, dynamic> order) async {
    final orderId = order['orderId']?.toString();
    if (orderId == null) return;

    bool? confirm = await showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Cancel Order'),
        content: Text('Are you sure you want to cancel this order? This action cannot be undone.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text('No', style: TextStyle(color: _primaryColor)),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            child: Text('Yes, Cancel'),
          ),
        ],
      ),
    );

    if (confirm == true) {
      try {
        final user = FirebaseAuth.instance.currentUser;
        if (user == null) return;

        final orderRef = FirebaseDatabase.instance.ref('users/${user.uid}/orders/$orderId');

        // تحديث حالة الطلب إلى "cancelled_by_user"
        await orderRef.update({
          'status': 'cancelled_by_user',
          'cancelledAt': ServerValue.timestamp,
          'cancelledBy': user.uid,
          'cancelledReason': 'Cancelled by user',
          'updatedAt': ServerValue.timestamp,
        });

        // تحديث في النظام المركزي أيضاً
        final centralOrderRef = FirebaseDatabase.instance.ref('all_orders/$orderId');
        await centralOrderRef.update({
          'status': 'cancelled_by_user',
          'cancelledAt': ServerValue.timestamp,
          'cancelledBy': user.uid,
          'cancelledReason': 'Cancelled by user',
          'updatedAt': ServerValue.timestamp,
        });

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Order cancelled successfully'),
            backgroundColor: Colors.green,
          ),
        );

        // تحديث القائمة
        _loadUserOrders();
      } catch (e) {
        print('Error cancelling order: $e');
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error cancelling order: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  bool _canCancelOrder(String status) {
    final lowerStatus = status.toLowerCase();
    // يمكن الإلغاء فقط في الحالات التي لم يتم فيها شحن الطلب بعد
    return lowerStatus == 'pending' ||
        lowerStatus == 'confirmed' ||
        lowerStatus == 'processing';
  }
  void _navigateToOrderDetails(Map<dynamic, dynamic> order) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => OrderDetailsPage(order: order),
      ),
    );
  }

  void _navigateToRatingPage(Map<dynamic, dynamic> order) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => OrderRatingPage(order: order),
      ),
    );
  }

  double _calculateTotal(Map<dynamic, dynamic> order) {
    try {
      return (order['totalAmount'] ?? order['total'] ?? 0.0).toDouble();
    } catch (e) {
      return 0.0;
    }
  }

  Color _getStatusColor(String status) {
    switch (status.toLowerCase()) {
      case 'delivered': return Colors.green;
      case 'completed': return Colors.green;
      case 'shipped': return Colors.purple;
      case 'processing': return Colors.indigo;
      case 'confirmed': return Colors.blue;
      case 'pending': return Colors.orange;
      case 'cancelled': return Colors.red;
      case 'cancelled_by_user': return Colors.red;
      default: return _primaryColor;
    }
  }

  IconData _getStatusIcon(String status) {
    switch (status.toLowerCase()) {
      case 'pending': return Icons.pending_actions;
      case 'confirmed': return Icons.check_circle;
      case 'processing': return Icons.build_circle;
      case 'shipped': return Icons.local_shipping;
      case 'delivered': return Icons.done_all;
      case 'cancelled': return Icons.cancel;
      case 'cancelled_by_user': return Icons.cancel;
      default: return Icons.shopping_bag;
    }
  }

  @override
  Widget build(BuildContext context) {

    if (user == null) {
      return Scaffold(
        appBar: AppBar(
          title: Text('My Orders'),
          backgroundColor: _primaryColor,
          foregroundColor: Colors.white,
          elevation: 0,
        ),
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.shopping_bag_outlined, size: 80, color: _secondaryColor),
              SizedBox(height: 20),
              Text(
                'Please login to view your orders',
                style: TextStyle(fontSize: 18, color: _primaryColor),
              ),
            ],
          ),
        ),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: Text('My Orders'),
        backgroundColor: _primaryColor,
        foregroundColor: Colors.white,
        elevation: 0,
        centerTitle: true,
      ),
      backgroundColor: _backgroundColor,
      body: _isLoading
          ? Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            CircularProgressIndicator(color: _primaryColor),
            SizedBox(height: 16),
            Text(
              'Loading your orders...',
              style: TextStyle(color: _primaryColor, fontSize: 16),
            ),
          ],
        ),
      )
          : _orders.isEmpty
          ? Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.shopping_bag_outlined, size: 100, color: _secondaryColor),
            SizedBox(height: 20),
            Text(
              'No orders yet',
              style: TextStyle(fontSize: 20, color: _primaryColor, fontWeight: FontWeight.bold),
            ),
            SizedBox(height: 10),
            if (_errorMessage.isNotEmpty)
              Padding(
                padding: EdgeInsets.symmetric(horizontal: 40),
                child: Text(
                  _errorMessage,
                  style: TextStyle(color: Colors.red, fontSize: 14),
                  textAlign: TextAlign.center,
                ),
              ),
            SizedBox(height: 20),
            ElevatedButton(
              onPressed: _loadUserOrders,
              style: ElevatedButton.styleFrom(
                backgroundColor: _primaryColor,
                foregroundColor: Colors.white,
                padding: EdgeInsets.symmetric(horizontal: 30, vertical: 12),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
              child: Text('Refresh', style: TextStyle(fontSize: 16)),
            ),
          ],
        ),
      )
          : RefreshIndicator(
        onRefresh: _loadUserOrders,
        color: _primaryColor,
        backgroundColor: _backgroundColor,
        child: ListView.builder(
          itemCount: _orders.length,
          itemBuilder: (context, index) {
            return _buildOrderCard(_orders[index], index);
          },
        ),
      ),
    );
  }
}

class OrderDetailsPage extends StatefulWidget {
  final Map<dynamic, dynamic> order;

  const OrderDetailsPage({Key? key, required this.order}) : super(key: key);

  @override
  _OrderDetailsPageState createState() => _OrderDetailsPageState();
}

class _OrderDetailsPageState extends State<OrderDetailsPage> {
  final Color _primaryColor = Color(0xFF914D74);
  final Color _secondaryColor = Color(0xFFFFE4F3);
  final Color _accentColor = Color(0xFFFFF0F8);
  final Color _backgroundColor = Color(0xFFFDF2F6);

  late Map<dynamic, dynamic> _order;

  @override
  void initState() {
    super.initState();
    _order = widget.order;
    _setupRealtimeListener();
  }

  void _setupRealtimeListener() {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    final orderId = _order['orderId'];
    if (orderId == null) return;

    final orderRef = FirebaseDatabase.instance.ref('users/${user.uid}/orders/$orderId');
    orderRef.onValue.listen((event) {
      if (event.snapshot.exists) {
        final updatedOrder = Map<dynamic, dynamic>.from(event.snapshot.value as Map);
        setState(() {
          _order = updatedOrder;
          _order['orderId'] = orderId;
        });
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final orderId = _order['orderId']?.toString() ?? 'Unknown';
    final orderNumber = _order['orderNumber'] ?? orderId;
    final totalAmount = _order['totalAmount'] ?? 0.0;
    final status = _order['status']?.toString() ?? 'Pending';
    final timestamp = _order['orderDate'] ?? _order['createdAt'] ?? _order['timestamp'];

    bool _canCancelOrder(String status) {
      final lowerStatus = status.toLowerCase();
      return lowerStatus == 'pending' ||
          lowerStatus == 'confirmed' ||
          lowerStatus == 'processing';
    }

    Future<void> _cancelOrder(Map<dynamic, dynamic> order) async {
      final orderId = order['orderId']?.toString();
      if (orderId == null) return;

      bool? confirm = await showDialog(
        context: context,
        builder: (context) => AlertDialog(
          title: Text('Cancel Order'),
          content: Text('Are you sure you want to cancel order #${order['orderNumber'] ?? orderId}? This action cannot be undone.'),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: Text('Keep Order', style: TextStyle(color: _primaryColor)),
            ),
            ElevatedButton(
              onPressed: () => Navigator.pop(context, true),
              style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
              child: Text('Cancel Order'),
            ),
          ],
        ),
      );

      if (confirm == true) {
        try {
          final user = FirebaseAuth.instance.currentUser;
          if (user == null) return;

          final orderRef = FirebaseDatabase.instance.ref('users/${user.uid}/orders/$orderId');

          await orderRef.update({
            'status': 'cancelled_by_user',
            'cancelledAt': ServerValue.timestamp,
            'cancelledBy': user.uid,
            'cancelledReason': 'Cancelled by user',
            'updatedAt': ServerValue.timestamp,
          });

          // تحديث في النظام المركزي أيضاً
          final centralOrderRef = FirebaseDatabase.instance.ref('all_orders/$orderId');
          await centralOrderRef.update({
            'status': 'cancelled_by_user',
            'cancelledAt': ServerValue.timestamp,
            'cancelledBy': user.uid,
            'cancelledReason': 'Cancelled by user',
            'updatedAt': ServerValue.timestamp,
          });

          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Order cancelled successfully'),
              backgroundColor: Colors.green,
            ),
          );

          // تحديث البيانات المحلية
          setState(() {
            _order['status'] = 'cancelled_by_user';
            _order['cancelledAt'] = DateTime.now().millisecondsSinceEpoch;
          });

        } catch (e) {
          print('Error cancelling order: $e');
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Error cancelling order: $e'),
              backgroundColor: Colors.red,
            ),
          );
        }
      }
    }

    // استخراج المنتجات من الطلب
    List<Map<dynamic, dynamic>> orderItems = _extractOrderItems(_order);

    return Scaffold(
      appBar: AppBar(
        title: Text('Order #$orderNumber'),
        backgroundColor: _primaryColor,
        foregroundColor: Colors.white,
        elevation: 0,
        actions: [
          if (_canCancelOrder(status))
            IconButton(
              icon: Icon(Icons.cancel, color: Colors.white),
              onPressed: () => _cancelOrder(_order),
              tooltip: 'Cancel Order',
            ),
          if (_order['hasRated'] != true)
            IconButton(
              icon: Icon(Icons.star, color: Colors.white),
              onPressed: () {
                _navigateToRatingPage(_order);
              },
            ),
        ],
      ),
      backgroundColor: _backgroundColor,
      body: SingleChildScrollView(
        padding: EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // معلومات الطلب الأساسية
            _buildInfoCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'Order Status',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: _primaryColor,
                        ),
                      ),
                      Container(
                        padding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                        decoration: BoxDecoration(
                          color: _getStatusColor(status),
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Text(
                          status.toUpperCase(),
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ],
                  ),
                  SizedBox(height: 16),
                  _buildDetailRow('Order Date', _formatTimestamp(timestamp)),
                  _buildDetailRow('Order Number', orderNumber),
                  _buildDetailRow('Total Amount', 'OMR ${totalAmount.toStringAsFixed(3)}'),
                ],
              ),
            ),

            SizedBox(height: 16),

            // عنوان التوصيل
            if (_order['deliveryAddress'] != null) ...[
              _buildInfoCard(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '📦 Delivery Address',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: _primaryColor,
                      ),
                    ),
                    SizedBox(height: 12),
                    _buildAddress(_order['deliveryAddress']),
                  ],
                ),
              ),
              SizedBox(height: 16),
            ],

            // المنتجات
            _buildInfoCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        '🛍️ Order Items (${orderItems.length})',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: _primaryColor,
                        ),
                      ),
                      if (_order['hasRated'] != true)
                        ElevatedButton(
                          onPressed: () {
                            _navigateToRatingPage(_order);
                          },
                          style: ElevatedButton.styleFrom(
                            backgroundColor: _primaryColor,
                            foregroundColor: Colors.white,
                            padding: EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(8),
                            ),
                          ),
                          child: Text('Rate Order'),
                        ),
                    ],
                  ),
                  SizedBox(height: 16),
                  ...orderItems.map((item) => _buildOrderItem(item, _order)).toList(),
                ],
              ),
            ),

            // التقييمات الحالية - تظهر بعد التقييم
            if (_order['hasRated'] == true && _order['ratings'] != null) ...[
              SizedBox(height: 16),
              _buildInfoCard(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(Icons.star, color: Colors.amber, size: 24),
                        SizedBox(width: 8),
                        Text(
                          'Your Ratings',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            color: _primaryColor,
                          ),
                        ),
                      ],
                    ),
                    SizedBox(height: 12),
                    ..._buildOrderRatings(_order),
                  ],
                ),
              ),
            ],

            // ملخص الطلب
            SizedBox(height: 16),
            _buildInfoCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '💰 Order Summary',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: _primaryColor,
                    ),
                  ),
                  SizedBox(height: 16),
                  _buildSummaryRow('Subtotal', _order['subtotal'] ?? totalAmount),
                  _buildSummaryRow('Shipping', _order['shippingFee'] ?? 0.0),
                  _buildSummaryRow('Tax', _order['tax'] ?? 0.0),
                  Divider(color: _primaryColor.withOpacity(0.3)),
                  _buildSummaryRow(
                    'Total',
                    totalAmount,
                    isTotal: true,
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

  void _navigateToRatingPage(Map<dynamic, dynamic> order) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => OrderRatingPage(order: order),
      ),
    ).then((_) {
      // عند العودة من صفحة التقييم، تحديث البيانات
      _loadOrderData();
    });
  }

  Future<void> _loadOrderData() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    final orderId = _order['orderId'];
    if (orderId == null) return;

    try {
      final orderRef = FirebaseDatabase.instance.ref('users/${user.uid}/orders/$orderId');
      final snapshot = await orderRef.get();

      if (snapshot.exists) {
        final updatedOrder = Map<dynamic, dynamic>.from(snapshot.value as Map);
        setState(() {
          _order = updatedOrder;
          _order['orderId'] = orderId;
        });
      }
    } catch (e) {
      print('Error loading updated order: $e');
    }
  }

  Widget _buildInfoCard({required Widget child}) {
    return Card(
      elevation: 4,
      color: Colors.white,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
      ),
      child: Padding(
        padding: EdgeInsets.all(20),
        child: child,
      ),
    );
  }

  List<Map<dynamic, dynamic>> _extractOrderItems(Map<dynamic, dynamic> order) {
    List<Map<dynamic, dynamic>> items = [];

    if (order['items'] != null && order['items'] is List) {
      items = List<Map<dynamic, dynamic>>.from(order['items']);
    } else if (order['products'] != null && order['products'] is List) {
      items = List<Map<dynamic, dynamic>>.from(order['products']);
    } else if (order['cartItems'] != null && order['cartItems'] is List) {
      items = List<Map<dynamic, dynamic>>.from(order['cartItems']);
    } else {
      order.forEach((key, value) {
        if (value is Map && value.containsKey('productName')) {
          items.add(Map<dynamic, dynamic>.from(value));
        }
      });
    }

    return items;
  }

  Widget _buildOrderItem(Map<dynamic, dynamic> item, Map<dynamic, dynamic> order) {
    final productName = item['productName'] ?? item['name'] ?? 'Unknown Product';
    final price = item['price'] ?? item['productPrice'] ?? 0.0;
    final quantity = item['quantity'] ?? 1;
    final imageUrl = item['imageUrl'] ?? item['productImage'] ?? item['image'];
    final total = (price * quantity).toDouble();
    final productId = item['productId'] ?? item['id'];

    final bool hasRating = order['ratings'] != null &&
        order['ratings'] is Map &&
        order['ratings'].containsKey(productId);

    return Container(
      margin: EdgeInsets.only(bottom: 16),
      padding: EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: _accentColor,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: _primaryColor.withOpacity(0.2)),
      ),
      child: Column(
        children: [
          Row(
            children: [
              Container(
                width: 70,
                height: 70,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(10),
                  color: Colors.white,
                ),
                child: imageUrl != null && imageUrl.toString().isNotEmpty
                    ? ClipRRect(
                  borderRadius: BorderRadius.circular(10),
                  child: CachedNetworkImage(
                    imageUrl: imageUrl.toString(),
                    fit: BoxFit.cover,
                    placeholder: (context, url) => Center(
                      child: CircularProgressIndicator(color: _primaryColor),
                    ),
                    errorWidget: (context, url, error) => Icon(
                      Icons.shopping_bag,
                      color: _secondaryColor,
                      size: 30,
                    ),
                  ),
                )
                    : Icon(
                  Icons.shopping_bag,
                  color: _secondaryColor,
                  size: 30,
                ),
              ),
              SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      productName.toString(),
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 15,
                        color: _primaryColor,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                    SizedBox(height: 6),
                    Text(
                      'OMR ${price.toStringAsFixed(3)}',
                      style: TextStyle(
                        color: Colors.grey.shade700,
                        fontSize: 13,
                      ),
                    ),
                    SizedBox(height: 4),
                    Text(
                      'Quantity: $quantity',
                      style: TextStyle(
                        color: Colors.grey.shade700,
                        fontSize: 13,
                      ),
                    ),
                    if (hasRating) ...[
                      SizedBox(height: 6),
                      _buildProductRating(order['ratings'][productId]),
                    ],
                  ],
                ),
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    'OMR ${total.toStringAsFixed(3)}',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                      color: _primaryColor,
                    ),
                  ),
                  if (hasRating) ...[
                    SizedBox(height: 6),
                    Container(
                      padding: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: Colors.green,
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text(
                        'Rated',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 10,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            ],
          ),
          SizedBox(height: 12),
          // زر Buy Again
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: () => _addToCartAgain(item),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.green,
                foregroundColor: Colors.white,
                padding: EdgeInsets.symmetric(vertical: 12, horizontal: 16),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
                elevation: 2,
              ),
              icon: Icon(Icons.shopping_cart, size: 18),
              label: Text(
                'Buy Again',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _addToCartAgain(Map<dynamic, dynamic> product) async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Please login to add items to cart'),
            backgroundColor: Colors.red,
          ),
        );
        return;
      }

      final productId = (product['productId'] ?? product['id']).toString();
      final productName = product['productName'] ?? product['name'] ?? 'Product';
      final price = product['price'] ?? product['productPrice'] ?? 0.0;
      final imageUrl = product['imageUrl'] ?? product['productImage'] ?? product['image'];
      final quantity = 1;

      // 🔥 استخدام Provider للحصول على كائن السلة
      final cart = Provider.of<Cart>(context, listen: false);

      // 🔥 التأكد من أن السلة مرتبطة باليوزر الحالي
      if (cart.currentUserId == null) {
        cart.setUserId(user.uid);
      }

      // 🔥 استخدام دالة addItem من الـ Provider
      cart.addItem(
        productId,
        productName,
        price,
        imageUrl?.toString() ?? '',
      );

      // إظهار رسالة نجاح
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('$productName added to cart successfully!'),
          backgroundColor: Colors.green,
          duration: Duration(seconds: 2),
          behavior: SnackBarBehavior.floating,
        ),
      );

      print('✅ Product added to cart: $productName');

    } catch (e) {
      print('❌ Error adding product to cart: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error adding product to cart: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  Widget _buildProductRating(Map<dynamic, dynamic> ratingData) {
    final rating = ratingData['rating'] ?? 0;
    final comment = ratingData['comment'] ?? '';

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            _buildRatingStars(rating),
            SizedBox(width: 8),
            Text(
              '$rating/5',
              style: TextStyle(
                fontWeight: FontWeight.bold,
                color: Colors.amber,
              ),
            ),
          ],
        ),
        if (comment.isNotEmpty) ...[
          SizedBox(height: 4),
          Text(
            'Comment: $comment',
            style: TextStyle(
              fontSize: 12,
              color: Colors.grey.shade700,
              fontStyle: FontStyle.italic,
            ),
          ),
        ],
      ],
    );
  }

  List<Widget> _buildOrderRatings(Map<dynamic, dynamic> order) {
    if (order['ratings'] == null || order['ratings'] is! Map) {
      return [Text('No ratings yet', style: TextStyle(color: Colors.grey))];
    }

    final ratings = Map<dynamic, dynamic>.from(order['ratings']);
    final orderItems = _extractOrderItems(order);

    return ratings.entries.map((entry) {
      final productId = entry.key;
      final ratingData = Map<dynamic, dynamic>.from(entry.value);

      final product = orderItems.firstWhere(
            (item) => (item['productId'] ?? item['id']).toString() == productId.toString(),
        orElse: () => {},
      );

      if (product.isEmpty) return SizedBox();

      final productName = product['productName'] ?? product['name'] ?? 'Unknown Product';
      final rating = ratingData['rating'] ?? 0;
      final comment = ratingData['comment'] ?? '';

      return Container(
        margin: EdgeInsets.only(bottom: 12),
        padding: EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: _accentColor,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: _primaryColor.withOpacity(0.2)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              productName.toString(),
              style: TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 16,
                color: _primaryColor,
              ),
            ),
            SizedBox(height: 8),
            Row(
              children: [
                _buildRatingStars(rating),
                SizedBox(width: 8),
                Text(
                  '$rating/5 Stars',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    color: Colors.amber,
                  ),
                ),
              ],
            ),
            if (comment.isNotEmpty) ...[
              SizedBox(height: 8),
              Text(
                'Comment: $comment',
                style: TextStyle(
                  fontSize: 14,
                  color: Colors.grey.shade700,
                ),
              ),
            ],
          ],
        ),
      );
    }).toList();
  }

  Widget _buildDetailRow(String label, String value) {
    return Padding(
      padding: EdgeInsets.symmetric(vertical: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '$label: ',
            style: TextStyle(fontWeight: FontWeight.bold, color: _primaryColor, fontSize: 15),
          ),
          Expanded(
            child: Text(value, style: TextStyle(fontSize: 15)),
          ),
        ],
      ),
    );
  }

  Widget _buildSummaryRow(String label, dynamic amount, {bool isTotal = false}) {
    final value = amount is double ? amount : (double.tryParse(amount.toString()) ?? 0.0);

    return Padding(
      padding: EdgeInsets.symmetric(vertical: 6),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: TextStyle(
              fontWeight: isTotal ? FontWeight.bold : FontWeight.normal,
              fontSize: isTotal ? 18 : 16,
              color: isTotal ? _primaryColor : Colors.black,
            ),
          ),
          Text(
            'OMR ${value.toStringAsFixed(3)}',
            style: TextStyle(
              fontWeight: isTotal ? FontWeight.bold : FontWeight.normal,
              fontSize: isTotal ? 18 : 16,
              color: isTotal ? _primaryColor : Colors.black,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAddress(dynamic addressData) {
    if (addressData is Map) {
      final address = Map<dynamic, dynamic>.from(addressData);
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (address['address'] != null)
            Text(
              address['address'].toString(),
              style: TextStyle(fontSize: 15, color: Colors.grey.shade700),
            ),
          if (address['city'] != null || address['state'] != null)
            Text(
              '${address['city'] ?? ''}${address['city'] != null && address['state'] != null ? ', ' : ''}${address['state'] ?? ''}',
              style: TextStyle(fontSize: 15, color: Colors.grey.shade700),
            ),
          if (address['zipCode'] != null)
            Text(
              'Zip: ${address['zipCode']}',
              style: TextStyle(fontSize: 15, color: Colors.grey.shade700),
            ),
        ],
      );
    }
    return Text('Address not available', style: TextStyle(color: Colors.grey));
  }

  Widget _buildRatingStars(int rating) {
    return Row(
      children: List.generate(5, (index) {
        return Icon(
          index < rating ? Icons.star : Icons.star_border,
          color: Colors.amber,
          size: 20,
        );
      }),
    );
  }

  Color _getStatusColor(String status) {
    switch (status.toLowerCase()) {
      case 'delivered': return Colors.green;
      case 'completed': return Colors.green;
      case 'shipped': return Colors.purple;
      case 'processing': return Colors.indigo;
      case 'confirmed': return Colors.blue;
      case 'pending': return Colors.orange;
      case 'cancelled': return Colors.red;
      default: return _primaryColor;
    }
  }
}

// OrderRatingPage يبقى كما هو بدون تغييرات
class OrderRatingPage extends StatefulWidget {
  final Map<dynamic, dynamic> order;

  const OrderRatingPage({Key? key, required this.order}) : super(key: key);

  @override
  _OrderRatingPageState createState() => _OrderRatingPageState();
}

class _OrderRatingPageState extends State<OrderRatingPage> {
  final Map<String, int> _ratings = {};
  final Map<String, TextEditingController> _commentControllers = {};
  bool _isSubmitting = false;

  // الألوان الوردية الفاتحة الجميلة
  final Color _primaryColor = Color(0xFF914D74);
  final Color _secondaryColor = Color(0xFFFFE4F3);
  final Color _accentColor = Color(0xFFFFF0F8);
  final Color _backgroundColor = Color(0xFFFDF2F6);

  @override
  void initState() {
    super.initState();
    final items = _extractOrderItems(widget.order);
    for (final item in items) {
      final productId = (item['productId'] ?? item['id']).toString();
      _ratings[productId] = 0;
      _commentControllers[productId] = TextEditingController();
    }
  }

  @override
  void dispose() {
    _commentControllers.forEach((key, controller) {
      controller.dispose();
    });
    super.dispose();
  }

  List<Map<dynamic, dynamic>> _extractOrderItems(Map<dynamic, dynamic> order) {
    List<Map<dynamic, dynamic>> items = [];

    if (order['items'] != null && order['items'] is List) {
      items = List<Map<dynamic, dynamic>>.from(order['items']);
    } else if (order['products'] != null && order['products'] is List) {
      items = List<Map<dynamic, dynamic>>.from(order['products']);
    } else if (order['cartItems'] != null && order['cartItems'] is List) {
      items = List<Map<dynamic, dynamic>>.from(order['cartItems']);
    } else {
      order.forEach((key, value) {
        if (value is Map && value.containsKey('productName')) {
          items.add(Map<dynamic, dynamic>.from(value));
        }
      });
    }

    return items;
  }

  Future<void> _submitRatings() async {
    if (_ratings.values.any((rating) => rating == 0)) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Please rate all products before submitting'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    setState(() {
      _isSubmitting = true;
    });

    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) throw Exception('User not logged in');

      final orderId = widget.order['orderId'];
      final orderRef = FirebaseDatabase.instance.ref('users/${user.uid}/orders/$orderId');

      Map<String, dynamic> ratingsData = {};
      _ratings.forEach((productId, rating) {
        ratingsData[productId] = {
          'rating': rating,
          'comment': _commentControllers[productId]?.text ?? '',
          'ratedAt': ServerValue.timestamp,
          'userId': user.uid,
          'userName': user.displayName ?? 'User',
          'userEmail': user.email ?? '',
          'orderId': orderId,
        };
      });

      await orderRef.update({
        'ratings': ratingsData,
        'hasRated': true,
      });

      await _saveRatingsToProducts(ratingsData);

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Thank you for your rating!'),
          backgroundColor: _primaryColor,
        ),
      );

      Navigator.pop(context);

    } catch (e) {
      print('Error submitting ratings: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error submitting ratings: $e'),
          backgroundColor: Colors.red,
        ),
      );
    } finally {
      setState(() {
        _isSubmitting = false;
      });
    }
  }

  Future<void> _saveRatingsToProducts(Map<String, dynamic> ratingsData) async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) return;

      final productsRef = FirebaseDatabase.instance.ref('products');

      for (final entry in ratingsData.entries) {
        final productId = entry.key;
        final ratingData = entry.value;

        final productRatingRef = productsRef.child('$productId/ratings/${user.uid}');
        await productRatingRef.set({
          'rating': ratingData['rating'],
          'comment': ratingData['comment'],
          'ratedAt': ServerValue.timestamp,
          'userName': user.displayName ?? 'User',
          'userEmail': user.email ?? '',
          'orderId': widget.order['orderId'],
        });

        await _updateProductAverageRating(productId);
      }
    } catch (e) {
      print('Error saving ratings to products: $e');
    }
  }

  Future<void> _updateProductAverageRating(String productId) async {
    try {
      final ratingsRef = FirebaseDatabase.instance.ref('products/$productId/ratings');
      final snapshot = await ratingsRef.get();

      if (snapshot.exists) {
        final ratings = Map<dynamic, dynamic>.from(snapshot.value as Map);
        final totalRatings = ratings.length;

        double sumRatings = 0;
        List<String> allComments = [];

        ratings.forEach((key, value) {
          final ratingMap = Map<dynamic, dynamic>.from(value);
          final ratingValue = ratingMap['rating'];

          if (ratingValue is int) {
            sumRatings += ratingValue.toDouble();
          } else if (ratingValue is String) {
            sumRatings += double.tryParse(ratingValue) ?? 0;
          } else if (ratingValue is double) {
            sumRatings += ratingValue;
          }

          if (ratingMap['comment'] != null && ratingMap['comment'].toString().isNotEmpty) {
            allComments.add(ratingMap['comment'].toString());
          }
        });

        final averageRating = totalRatings > 0 ? sumRatings / totalRatings : 0;

        await FirebaseDatabase.instance.ref('products/$productId').update({
          'averageRating': double.parse(averageRating.toStringAsFixed(1)),
          'totalRatings': totalRatings,
          'recentComments': allComments.take(5).toList(),
        });

        print('✅ Updated product $productId - Average: $averageRating, Total: $totalRatings');
      }
    } catch (e) {
      print('❌ Error updating average rating: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    final orderNumber = widget.order['orderNumber'] ?? widget.order['orderId'];
    final items = _extractOrderItems(widget.order);

    return Scaffold(
      appBar: AppBar(
        title: Text('Rate Order #$orderNumber'),
        backgroundColor: _primaryColor,
        foregroundColor: Colors.white,
        elevation: 0,
      ),
      backgroundColor: _backgroundColor,
      body: Column(
        children: [
          Expanded(
            child: SingleChildScrollView(
              padding: EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Card(
                    elevation: 4,
                    color: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: Padding(
                      padding: EdgeInsets.all(20),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            '⭐ Rate Your Products',
                            style: TextStyle(
                              fontSize: 20,
                              fontWeight: FontWeight.bold,
                              color: _primaryColor,
                            ),
                          ),
                          SizedBox(height: 8),
                          Text(
                            'Please rate each product from 1 to 5 stars and add your comments',
                            style: TextStyle(
                              color: Colors.grey.shade600,
                              fontSize: 14,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  SizedBox(height: 16),
                  ...items.map((item) => _buildRatingItem(item)).toList(),
                  SizedBox(height: 20),
                ],
              ),
            ),
          ),
          Container(
            padding: EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white,
              boxShadow: [
                BoxShadow(
                  color: Colors.black12,
                  blurRadius: 10,
                  offset: Offset(0, -2),
                ),
              ],
            ),
            child: SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: _isSubmitting ? null : _submitRatings,
                style: ElevatedButton.styleFrom(
                  backgroundColor: _primaryColor,
                  foregroundColor: Colors.white,
                  padding: EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                child: _isSubmitting
                    ? Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    CircularProgressIndicator(color: Colors.white),
                    SizedBox(width: 8),
                    Text('Submitting...', style: TextStyle(fontSize: 16)),
                  ],
                )
                    : Text(
                  'Submit Ratings',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildRatingItem(Map<dynamic, dynamic> item) {
    final productName = item['productName'] ?? item['name'] ?? 'Unknown Product';
    final imageUrl = item['imageUrl'] ?? item['productImage'] ?? item['image'];
    final productId = (item['productId'] ?? item['id']).toString();
    final currentRating = _ratings[productId] ?? 0;

    return Card(
      margin: EdgeInsets.only(bottom: 16),
      elevation: 4,
      color: Colors.white,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
      ),
      child: Padding(
        padding: EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  width: 60,
                  height: 60,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(12),
                    color: _accentColor,
                  ),
                  child: imageUrl != null && imageUrl.toString().isNotEmpty
                      ? ClipRRect(
                    borderRadius: BorderRadius.circular(12),
                    child: CachedNetworkImage(
                      imageUrl: imageUrl.toString(),
                      fit: BoxFit.cover,
                      placeholder: (context, url) => Center(
                        child: CircularProgressIndicator(color: _primaryColor),
                      ),
                      errorWidget: (context, url, error) => Icon(
                        Icons.shopping_bag,
                        color: _secondaryColor,
                        size: 30,
                      ),
                    ),
                  )
                      : Icon(
                    Icons.shopping_bag,
                    color: _secondaryColor,
                    size: 30,
                  ),
                ),
                SizedBox(width: 16),
                Expanded(
                  child: Text(
                    productName.toString(),
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 18,
                      color: _primaryColor,
                    ),
                  ),
                ),
              ],
            ),
            SizedBox(height: 20),
            Center(
              child: Column(
                children: [
                  Text(
                    'How would you rate this product?',
                    style: TextStyle(
                      fontSize: 16,
                      color: Colors.grey.shade700,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  SizedBox(height: 12),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: List.generate(5, (index) {
                      return IconButton(
                        onPressed: () {
                          setState(() {
                            _ratings[productId] = index + 1;
                          });
                        },
                        icon: Icon(
                          index < currentRating ? Icons.star : Icons.star_border,
                          color: Colors.amber,
                          size: 40,
                        ),
                      );
                    }),
                  ),
                  SizedBox(height: 8),
                  Text(
                    currentRating == 0 ? 'Select rating' : '$currentRating/5 Stars',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                      color: currentRating == 0 ? Colors.grey : Colors.amber,
                    ),
                  ),
                ],
              ),
            ),
            SizedBox(height: 20),
            TextField(
              controller: _commentControllers[productId],
              maxLines: 3,
              decoration: InputDecoration(
                labelText: 'Add your comment (optional)',
                labelStyle: TextStyle(color: _primaryColor),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide(color: _primaryColor),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide(color: _primaryColor, width: 2),
                ),
                contentPadding: EdgeInsets.all(16),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// الدوال المساعدة
String _formatTimestamp(dynamic timestamp) {
  if (timestamp == null) return 'Unknown date';
  try {
    if (timestamp is int) {
      final date = DateTime.fromMillisecondsSinceEpoch(timestamp);
      return '${date.day}/${date.month}/${date.year} ${date.hour}:${date.minute.toString().padLeft(2, '0')}';
    } else if (timestamp is String) {
      return timestamp;
    }
    return 'Invalid date';
  } catch (e) {
    return 'Unknown date';
  }
}