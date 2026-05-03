import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:firebase_database/firebase_database.dart';
import '../Screens/CustomNotificationService.dart';
import '../main.dart';


class OrdersManagementScreen extends StatefulWidget {
  @override
  _OrdersManagementScreenState createState() => _OrdersManagementScreenState();
}

class _OrdersManagementScreenState extends State<OrdersManagementScreen> {
  List<String> selectedOrders = [];
  String _searchQuery = '';
  String _selectedView = 'All';
  Map<String, bool> _expandedOrders = {};
  Map<String, Map<String, dynamic>> _allOrders = {};
  bool _isAdmin = false;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _initializeScreen();
  }

  Future<void> _initializeScreen() async {
    await _checkAdminStatus();
    if (_isAdmin) {
      await _loadAllOrders();
      _setupRealtimeListener();
    }
    setState(() => _isLoading = false);
  }

  Future<void> _checkAdminStatus() async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user != null) {
        final userRef = FirebaseDatabase.instance.ref('users/${user.uid}/role');
        final snapshot = await userRef.get();
        setState(() {
          _isAdmin = snapshot.exists && snapshot.value == 'admin';
        });

        if (!_isAdmin) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text('Access denied: Admin privileges required'),
                backgroundColor: Colors.red,
              ),
            );
          });
        }
      }
    } catch (e) {
      print('❌ Error checking admin status: $e');
    }
  }

  void _setupRealtimeListener() {
    final ordersRef = FirebaseDatabase.instance.ref('all_orders');
    ordersRef.onValue.listen((event) {
      if (mounted && _isAdmin) {
        _loadAllOrders();
      }
    });
  }

  Future<void> _loadAllOrders() async {
    if (!_isAdmin) return;

    try {
      final ordersRef = FirebaseDatabase.instance.ref('all_orders');
      final snapshot = await ordersRef.get();

      Map<String, Map<String, dynamic>> allOrders = {};

      if (snapshot.exists) {
        final orders = Map<dynamic, dynamic>.from(snapshot.value as Map);

        orders.forEach((key, value) {
          try {
            final orderId = key.toString();
            final orderData = Map<String, dynamic>.from(value);
            allOrders[orderId] = orderData;
          } catch (e) {
            print('⚠️ Error parsing order $key: $e');
          }
        });
      }

      setState(() {
        _allOrders = allOrders;
      });

      print('✅ Loaded ${_allOrders.length} orders from database');
    } catch (e) {
      print('❌ Error loading orders: $e');
    }
  }

  Future<void> _loadFromLegacySystem() async {
    try {
      print('🔄 Loading from legacy system...');

      final usersRef = FirebaseDatabase.instance.ref('users');
      final usersSnapshot = await usersRef.get();

      if (usersSnapshot.exists) {
        final users = Map<dynamic, dynamic>.from(usersSnapshot.value as Map);
        Map<String, Map<String, dynamic>> allOrders = {};

        for (final userEntry in users.entries) {
          final userId = userEntry.key.toString();
          final userData = Map<dynamic, dynamic>.from(userEntry.value);

          if (userData['orders'] != null && userData['orders'] is Map) {
            final orders = Map<dynamic, dynamic>.from(userData['orders']);

            for (final orderEntry in orders.entries) {
              final orderId = orderEntry.key.toString();
              final orderData = Map<String, dynamic>.from(orderEntry.value);

              allOrders[orderId] = {
                ...orderData,
                'orderId': orderId,
                'userId': userId,
                'userName': userData['name'] ?? userData['email'] ?? 'Unknown User',
                'userEmail': userData['email'] ?? 'No Email',
              };
            }
          }
        }

        setState(() {
          _allOrders = allOrders;
        });

        print('✅ Loaded ${_allOrders.length} orders from legacy system');
      }
    } catch (e) {
      print('❌ Error loading from legacy system: $e');
    }
  }

  void _toggleOrderSelection(String orderId) {
    setState(() {
      if (selectedOrders.contains(orderId)) {
        selectedOrders.remove(orderId);
      } else {
        selectedOrders.add(orderId);
      }
    });
  }

  void _toggleOrderExpansion(String orderId) {
    setState(() {
      _expandedOrders[orderId] = !(_expandedOrders[orderId] ?? false);
    });
  }

  // ✅ الدالة الأساسية لتحديث حالة الطلب
  Future<void> _updateOrderStatus(String orderId, String newStatus) async {
    if (!_isAdmin) return;

    try {
      final order = _allOrders[orderId];
      if (order == null) return;

      final userId = order['userId'];
      if (userId == null) return;

      final String orderNumber = order['orderNumber'] ?? orderId;
      final String userName = order['userName'] ?? 'Customer';

      // 1. تحديث حالة الطلب في Firebase
      final updates = {
        'status': newStatus,
        'updatedAt': DateTime.now().millisecondsSinceEpoch,
      };

      await Future.wait([
        FirebaseDatabase.instance.ref('all_orders/$orderId').update(updates),
        if (userId.isNotEmpty)
          FirebaseDatabase.instance.ref('users/$userId/orders/$orderId').update(updates),
      ]);

      // 2. ✅ حفظ الإشعار في قاعدة البيانات للمستخدم فقط
      await _saveNotificationForUser(
        userId: userId,
        orderNumber: orderNumber,
        newStatus: newStatus,
        userName: userName,
      );

      // 3. ✅ عرض الإشعار المحلي للمستخدم فقط
      await CustomNotificationService.showOrderUpdateNotification(
        orderNumber: orderNumber,
        newStatus: newStatus,
        userName: userName,
      );

      setState(() {
        _allOrders[orderId]?['status'] = newStatus;
        _allOrders[orderId]?['updatedAt'] = DateTime.now().millisecondsSinceEpoch;
      });

      print('✅ Updated order $orderId to $newStatus - User $userId notified');

    } catch (e) {
      print('❌ Error updating order: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error updating order: $e')),
      );
    }
  }

// ✅ دالة حفظ الإشعار للمستخدم فقط
  Future<void> _saveNotificationForUser({
    required String userId,
    required String orderNumber,
    required String newStatus,
    required String userName,
  }) async {
    try {
      final notificationId = DateTime.now().millisecondsSinceEpoch.toString();

      final notificationData = {
        'id': notificationId,
        'title': '📦 Order #$orderNumber Update',
        'body': _getOrderStatusMessage(newStatus, userName),
        'type': 'order_update',
        'orderNumber': orderNumber,
        'status': newStatus,
        'timestamp': DateTime.now().millisecondsSinceEpoch,
        'isRead': false,
      };

      // حفظ الإشعار في مسار المستخدم فقط
      await FirebaseDatabase.instance
          .ref('users/$userId/notifications')
          .child(notificationId)
          .set(notificationData);

      print('✅ Notification saved for user $userId only');
    } catch (e) {
      print('❌ Error saving notification for user: $e');
    }
  }

  String _getOrderStatusMessage(String status, String userName) {
    switch (status) {
      case 'Pending': return 'Hello $userName, your order has been received and is being processed.';
      case 'Confirmed': return 'Hello $userName, your order has been confirmed!';
      case 'Processing': return 'Hello $userName, your order is now being processed.';
      case 'Shipped': return '🎉 Hello $userName, your order has been shipped! Track your package.';
      case 'Delivered': return '✅ Hello $userName, your order has been delivered! Thank you for shopping with us.';
      case 'Cancelled': return 'Hello $userName, your order has been cancelled. Contact support for more details.';
      default: return 'Hello $userName, your order status has been updated to: $status';
    }
  }

  // ✅ الحصول على تفضيلات إشعارات المستخدم
  Future<Map<String, bool>> _getUserNotificationPreferences(String userId) async {
    try {
      final snapshot = await FirebaseDatabase.instance
          .ref('users/$userId/notificationPreferences')
          .get();

      if (snapshot.exists) {
        final data = Map<String, dynamic>.from(snapshot.value as Map);
        return {
          'orderUpdates': data['orderUpdates'] ?? true,
          'discountsAndOffers': data['discountsAndOffers'] ?? true,
          'newProductArrival': data['newProductArrival'] ?? true,
        };
      }
    } catch (e) {
      print('❌ Error getting user notification preferences: $e');
    }

    // القيم الافتراضية إذا لم توجد تفضيلات
    return {
      'orderUpdates': true,
      'discountsAndOffers': true,
      'newProductArrival': true,
    };
  }

  // ✅ تحديث الطلبات المحددة
  Future<void> _updateSelectedOrdersStatus(String newStatus) async {
    try {
      for (String orderId in selectedOrders) {
        await _updateOrderStatus(orderId, newStatus);
      }

      setState(() {
        selectedOrders.clear();
      });

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Updated ${selectedOrders.length} orders to $newStatus and sent notifications'),
          backgroundColor: Colors.green,
        ),
      );
    } catch (e) {
      print('❌ Error updating orders: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error updating orders: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  List<MapEntry<String, Map<String, dynamic>>> _getFilteredOrders() {
    return _allOrders.entries.where((entry) {
      final order = entry.value;

      // فلترة بالبحث
      if (_searchQuery.isNotEmpty) {
        final userName = order['userName']?.toString().toLowerCase() ?? '';
        final orderNumber = order['orderNumber']?.toString().toLowerCase() ?? '';
        final orderId = entry.key.toLowerCase();

        if (!userName.contains(_searchQuery.toLowerCase()) &&
            !orderNumber.contains(_searchQuery.toLowerCase()) &&
            !orderId.contains(_searchQuery.toLowerCase())) {
          return false;
        }
      }

      // فلترة بالحالة
      if (_selectedView != 'All' && order['status'] != _selectedView) {
        return false;
      }

      return true;
    }).toList()
      ..sort((a, b) {
        final dateA = a.value['updatedAt'] ?? a.value['orderDate'] ?? a.value['createdAt'] ?? 0;
        final dateB = b.value['updatedAt'] ?? b.value['orderDate'] ?? b.value['createdAt'] ?? 0;
        return (dateB as num).compareTo(dateA as num);
      });
  }

  @override
  Widget build(BuildContext context) {
    final filteredOrders = _getFilteredOrders();

    return Scaffold(
      appBar: AppBar(
        title: Text('Orders Management'),
        backgroundColor: Color(0xFF914D74),
        actions: [
          IconButton(
            icon: Icon(Icons.refresh),
            onPressed: _loadAllOrders,
          ),
          if (selectedOrders.isNotEmpty) ...[
            PopupMenuButton<String>(
              onSelected: (value) {
                if (value == 'delete') {
                  _showDeleteConfirmationDialog();
                } else {
                  _updateSelectedOrdersStatus(value);
                }
              },
              itemBuilder: (BuildContext context) => [
                PopupMenuItem(
                  value: 'Pending',
                  child: Row(
                    children: [
                      Icon(Icons.pending, color: Colors.orange),
                      SizedBox(width: 8),
                      Text('Pending'),
                    ],
                  ),
                ),
                PopupMenuItem(
                  value: 'Confirmed',
                  child: Row(
                    children: [
                      Icon(Icons.check_circle, color: Colors.blue),
                      SizedBox(width: 8),
                      Text('Confirmed'),
                    ],
                  ),
                ),
                PopupMenuItem(
                  value: 'Processing',
                  child: Row(
                    children: [
                      Icon(Icons.build, color: Colors.indigo),
                      SizedBox(width: 8),
                      Text('Processing'),
                    ],
                  ),
                ),
                PopupMenuItem(
                  value: 'Shipped',
                  child: Row(
                    children: [
                      Icon(Icons.local_shipping, color: Colors.purple),
                      SizedBox(width: 8),
                      Text('Shipped'),
                    ],
                  ),
                ),
                PopupMenuItem(
                  value: 'Delivered',
                  child: Row(
                    children: [
                      Icon(Icons.done_all, color: Colors.green),
                      SizedBox(width: 8),
                      Text('Delivered'),
                    ],
                  ),
                ),
                PopupMenuItem(
                  value: 'Cancelled',
                  child: Row(
                    children: [
                      Icon(Icons.cancel, color: Colors.red),
                      SizedBox(width: 8),
                      Text('Cancelled'),
                    ],
                  ),
                ),
              ],
              icon: Icon(Icons.more_vert),
            ),
          ],
        ],
      ),
      body: _isLoading
          ? Center(child: CircularProgressIndicator())
          : Column(
        children: [
          _buildSearchFilterBar(),
          if (selectedOrders.isNotEmpty)
            Container(
              padding: EdgeInsets.all(12),
              color: Colors.blue[50],
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    '${selectedOrders.length} orders selected',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      color: Colors.blue[800],
                    ),
                  ),
                  TextButton(
                    onPressed: () => setState(() => selectedOrders.clear()),
                    child: Text('Clear Selection'),
                  ),
                ],
              ),
            ),
          Expanded(
            child: _allOrders.isEmpty
                ? Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  CircularProgressIndicator(),
                  SizedBox(height: 16),
                  Text('Loading orders from database...'),
                ],
              ),
            )
                : filteredOrders.isEmpty
                ? Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.shopping_bag_outlined, size: 64, color: Colors.grey),
                  SizedBox(height: 16),
                  Text('No orders found'),
                  SizedBox(height: 8),
                  Text(
                    'Total orders in system: ${_allOrders.length}',
                    style: TextStyle(fontSize: 12, color: Colors.grey),
                  ),
                ],
              ),
            )
                : ListView.builder(
              itemCount: filteredOrders.length,
              itemBuilder: (context, index) {
                final entry = filteredOrders[index];
                final orderId = entry.key;
                final order = entry.value;
                return _buildOrderCard(order, orderId);
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSearchFilterBar() {
    return Container(
      padding: EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.grey[50],
        border: Border(bottom: BorderSide(color: Colors.black38)),
      ),
      child: Column(
        children: [
          TextField(
            decoration: InputDecoration(
              hintText: 'Search by order number, user name...',
              prefixIcon: Icon(Icons.search),
              border: OutlineInputBorder(),
              contentPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            ),
            onChanged: (value) {
              setState(() {
                _searchQuery = value;
              });
            },
          ),
          SizedBox(height: 12),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: [
                _buildFilterChip('All', 'All'),
                _buildFilterChip('Pending', 'Pending'),
                _buildFilterChip('Confirmed', 'Confirmed'),
                _buildFilterChip('Processing', 'Processing'),
                _buildFilterChip('Shipped', 'Shipped'),
                _buildFilterChip('Delivered', 'Delivered'),
                _buildFilterChip('Cancelled', 'Cancelled'),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFilterChip(String label, String value) {
    return Container(
      margin: EdgeInsets.only(right: 8),
      child: FilterChip(
        label: Text(label),
        selected: _selectedView == value,
        onSelected: (bool selected) {
          setState(() {
            _selectedView = selected ? value : 'All';
          });
        },
        backgroundColor: Colors.grey[300],
        selectedColor: Color(0xFF914D74),
        labelStyle: TextStyle(
          color: _selectedView == value ? Colors.white : Colors.black,
        ),
      ),
    );
  }

  Widget _buildOrderCard(Map<String, dynamic> order, String orderId) {
    final isSelected = selectedOrders.contains(orderId);
    final isExpanded = _expandedOrders[orderId] ?? false;
    final userName = order['userName'] ?? 'Unknown User';
    final totalAmount = order['totalAmount'] ?? order['total'] ?? 0.0;
    final status = order['status'] ?? 'Pending';
    final orderNumber = order['orderNumber'] ?? orderId;

    return Card(
      margin: EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      color: isSelected ? Colors.blue[50] : null,
      elevation: 2,
      child: Column(
        children: [
          ListTile(
            title: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Expanded(
                      child: Text(
                        'Order #$orderNumber',
                        style: TextStyle(fontWeight: FontWeight.bold),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    Container(
                      padding: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: _getStatusColor(status),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Text(
                        status,
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ],
                ),
                SizedBox(height: 4),
                Text('User: $userName', style: TextStyle(fontSize: 14)),
                Text('Total: OMR ${totalAmount.toStringAsFixed(3)}', style: TextStyle(fontSize: 14)),
                Text('Date: ${_formatDate(order['orderDate'])}', style: TextStyle(fontSize: 12, color: Colors.grey)),
              ],
            ),
            trailing: IconButton(
              icon: Icon(isExpanded ? Icons.expand_less : Icons.expand_more),
              onPressed: () => _toggleOrderExpansion(orderId),
            ),
            onTap: () => _toggleOrderSelection(orderId),
          ),
          if (isExpanded) ...[
            Divider(height: 1),
            _buildOrderDetails(order, orderId),
          ],
        ],
      ),
    );
  }

  Widget _buildOrderDetails(Map<String, dynamic> order, String orderId) {
    return Padding(
      padding: EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildOrderInfoSection(order),
          SizedBox(height: 16),
          if (order['items'] != null) ...[
            Text(
                'Order Items (${_getItemsCount(order['items'])})',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18)
            ),
            SizedBox(height: 12),
            _buildOrderItems(order['items']),
            SizedBox(height: 16),
            _buildOrderTotal(order),
            SizedBox(height: 16),
          ],
          Card(
            elevation: 2,
            child: Padding(
              padding: EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(Icons.notifications_active, color: Colors.blue),
                      SizedBox(width: 8),
                      Text(
                          'Update Order Status',
                          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)
                      ),
                    ],
                  ),
                  SizedBox(height: 12),
                  Text(
                      'The user will receive a notification when the status changes',
                      style: TextStyle(color: Colors.grey[600], fontSize: 12)
                  ),
                  SizedBox(height: 12),
                  DropdownButtonFormField<String>(
                    value: order['status'] ?? 'Pending',
                    decoration: InputDecoration(
                      labelText: 'Select Status',
                      border: OutlineInputBorder(),
                      contentPadding: EdgeInsets.symmetric(horizontal: 12),
                    ),
                    onChanged: (String? newValue) {
                      if (newValue != null) {
                        _showStatusUpdateConfirmation(orderId, newValue, order);
                      }
                    },
                    items: <String>['Pending', 'Confirmed', 'Processing', 'Shipped', 'Delivered', 'Cancelled']
                        .map<DropdownMenuItem<String>>((String value) {
                      return DropdownMenuItem<String>(
                        value: value,
                        child: Row(
                          children: [
                            Icon(_getStatusIcon(value), color: _getStatusColor(value)),
                            SizedBox(width: 8),
                            Text(value),
                          ],
                        ),
                      );
                    }).toList(),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ✅ عرض تأكيد تحديث الحالة
  void _showStatusUpdateConfirmation(String orderId, String newStatus, Map<String, dynamic> order) {
    final String orderNumber = order['orderNumber'] ?? orderId;
    final String userName = order['userName'] ?? 'the user';

    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: Row(
              children: [
                Icon(Icons.notifications, color: Colors.blue),
                SizedBox(width: 8),
                Text('Update Order Status')
              ]
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Are you sure you want to update order #$orderNumber to "$newStatus"?'),
              SizedBox(height: 8),
              Container(
                padding: EdgeInsets.all(12),
                decoration: BoxDecoration(
                    color: Colors.blue[50],
                    borderRadius: BorderRadius.circular(8)
                ),
                child: Row(
                  children: [
                    Icon(Icons.notification_important, size: 16, color: Colors.blue),
                    SizedBox(width: 8),
                    Expanded(
                      child: Text(
                          '$userName will receive a notification about this update',
                          style: TextStyle(fontSize: 12, color: Colors.blue[800])
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
                child: Text('Cancel')
            ),
            ElevatedButton(
              onPressed: () {
                Navigator.of(context).pop();
                _updateOrderStatus(orderId, newStatus);
              },
              style: ElevatedButton.styleFrom(backgroundColor: Color(0xFF914D74)),
              child: Text('Update & Notify'),
            ),
          ],
        );
      },
    );
  }

  Widget _buildOrderInfoSection(Map<String, dynamic> order) {
    return Card(
      elevation: 2,
      child: Padding(
        padding: EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
                'Order Information',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18)
            ),
            SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('User: ${order['userName'] ?? 'Unknown'}'),
                      Text('Email: ${order['userEmail'] ?? 'No email'}'),
                    ],
                  ),
                ),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Order ID: ${order['orderId']}'),
                      Text('Date: ${_formatDate(order['orderDate'])}'),
                    ],
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  int _getItemsCount(dynamic items) {
    if (items is Map) return items.length;
    if (items is List) return items.length;
    return 0;
  }

  Widget _buildOrderTotal(Map<String, dynamic> order) {
    final totalAmount = order['totalAmount'] ?? order['total'] ?? 0.0;
    final itemsCount = _getItemsCount(order['items']);

    return Card(
      color: Colors.green[50],
      child: Padding(
        padding: EdgeInsets.all(16),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Total Amount', style: TextStyle(fontWeight: FontWeight.bold)),
                Text('$itemsCount items'),
              ],
            ),
            Text(
              'OMR ${totalAmount.toStringAsFixed(3)}',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: Colors.green[700],
              ),
            ),
          ],
        ),
      ),
    );
  }

  IconData _getStatusIcon(String status) {
    switch (status) {
      case 'Pending': return Icons.pending;
      case 'Confirmed': return Icons.check_circle;
      case 'Processing': return Icons.build;
      case 'Shipped': return Icons.local_shipping;
      case 'Delivered': return Icons.done_all;
      case 'Cancelled': return Icons.cancel;
      default: return Icons.help;
    }
  }

  Widget _buildOrderItems(dynamic items) {
    if (items is Map) {
      final itemList = items.entries.toList();
      return Column(
        children: itemList.map((entry) {
          final product = entry.value;
          final productName = product['productName'] ?? product['name'] ?? 'Unknown Product';
          final quantity = product['quantity'] ?? 1;
          final price = product['price'] ?? 0.0;

          return Card(
            margin: EdgeInsets.symmetric(vertical: 4),
            child: ListTile(
              contentPadding: EdgeInsets.all(8),
              leading: Icon(Icons.shopping_bag, color: Colors.grey[600]),
              title: Text(
                  productName,
                  style: TextStyle(fontWeight: FontWeight.bold)
              ),
              subtitle: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Quantity: $quantity'),
                  Text('Price: OMR ${price.toStringAsFixed(3)}'),
                ],
              ),
              trailing: Text(
                'OMR ${(price * quantity).toStringAsFixed(3)}',
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  color: Colors.green,
                ),
              ),
            ),
          );
        }).toList(),
      );
    }
    return Text('No items found');
  }

  Color _getStatusColor(String status) {
    switch (status) {
      case 'Pending': return Colors.orange;
      case 'Confirmed': return Colors.blue;
      case 'Processing': return Colors.indigo;
      case 'Shipped': return Colors.purple;
      case 'Delivered': return Colors.green;
      case 'Cancelled': return Colors.red;
      default: return Colors.grey;
    }
  }

  String _formatDate(dynamic timestamp) {
    if (timestamp == null) return 'Unknown date';
    try {
      if (timestamp is int) {
        DateTime date = DateTime.fromMillisecondsSinceEpoch(timestamp);
        return '${date.day}/${date.month}/${date.year}';
      }
      return 'Invalid date';
    } catch (e) {
      return 'Unknown date';
    }
  }

  void _showDeleteConfirmationDialog() {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: Text('Confirm Delete'),
          content: Text('Are you sure you want to delete ${selectedOrders.length} orders?'),
          actions: [
            TextButton(
                onPressed: () => Navigator.of(context).pop(),
                child: Text('Cancel')
            ),
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: Text('Delete', style: TextStyle(color: Colors.red)),
            ),
          ],
        );
      },
    );
  }
}