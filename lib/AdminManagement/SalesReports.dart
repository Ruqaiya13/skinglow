// screens/admin/sales_reports_screen.dart
import 'package:flutter/material.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:intl/intl.dart';

// أضيفي هذه الكلاسات قبل كلاس _SalesReportsScreenState
class SalesData {
  final String day;
  final double amount;

  SalesData(this.day, this.amount);
}

class CategoryData {
  final String category;
  final double amount;

  CategoryData(this.category, this.amount);
}

class SalesReportsScreen extends StatefulWidget {
  @override
  _SalesReportsScreenState createState() => _SalesReportsScreenState();
}

class _SalesReportsScreenState extends State<SalesReportsScreen> {
  final Color _primaryColor = Color(0xFF914D74); // اللون الأساسي الوردي
  final Color _secondaryColor = Color(0xFFFFE4F3); // وردي فاتح
  final Color _accentColor = Color(0xFFFFF0F8); // وردي شفاف
  final Color _backgroundColor = Color(0xFFFDF2F6); // خلفية وردية فاتحة
  final Color _textColor = Color(0xFF333333); // نص داكن

  List<Map<String, dynamic>> _allOrders = [];
  List<Map<String, dynamic>> _filteredOrders = []; // الطلبات بعد التصفية
  bool _isLoading = true;
  String _selectedPeriod = 'daily'; // daily, weekly, monthly

  @override
  void initState() {
    super.initState();
    _loadSalesData();
  }

  Future<void> _loadSalesData() async {
    try {
      final ordersRef = FirebaseDatabase.instance.ref('all_orders');
      final snapshot = await ordersRef.get();

      print('🔍 Loading sales data from all_orders...');

      if (snapshot.exists) {
        final orders = Map<dynamic, dynamic>.from(snapshot.value as Map);
        List<Map<String, dynamic>> allOrders = [];

        orders.forEach((key, value) {
          try {
            final orderData = Map<String, dynamic>.from(value);
            orderData['orderId'] = key.toString();
            allOrders.add(orderData);
          } catch (e) {
            print('❌ Error parsing order $key: $e');
          }
        });

        print('✅ Loaded ${allOrders.length} orders from database');

        setState(() {
          _allOrders = allOrders;
          _filteredOrders = _filterOrdersByPeriod(_allOrders, _selectedPeriod);
          _isLoading = false;
        });

        print('🎯 Filtered to ${_filteredOrders.length} orders for $_selectedPeriod');

      } else {
        print('❌ No data found in all_orders');
        setState(() => _isLoading = false);
      }
    } catch (e) {
      print('❌ Error loading sales data: $e');
      setState(() => _isLoading = false);
    }
  }

  List<Map<String, dynamic>> _filterOrdersByPeriod(List<Map<String, dynamic>> orders, String period) {
    final now = DateTime.now();

    if (period == 'all') {
      return List.from(orders); // return copy of all orders
    }

    return orders.where((order) {
      final orderDate = _getOrderDateTime(order);
      if (orderDate == null) return false;

      switch (period) {
        case 'daily':
        // طلبات اليوم فقط
          return orderDate.year == now.year &&
              orderDate.month == now.month &&
              orderDate.day == now.day;

        case 'weekly':
        // طلبات هذا الأسبوع (من الإثنين إلى الأحد)
          final startOfWeek = now.subtract(Duration(days: now.weekday - 1));
          final endOfWeek = startOfWeek.add(Duration(days: 6));
          return orderDate.isAfter(startOfWeek.subtract(Duration(days: 1))) &&
              orderDate.isBefore(endOfWeek.add(Duration(days: 1)));

        case 'monthly':
        // طلبات هذا الشهر
          return orderDate.year == now.year &&
              orderDate.month == now.month;

        default:
          return true;
      }
    }).toList();
  }

  DateTime? _getOrderDateTime(Map<String, dynamic> order) {
    try {
      final timestamp = order['orderDate'] ?? order['createdAt'] ?? order['timestamp'];
      if (timestamp == null) {
        print('⚠️ No timestamp found for order ${order['orderId']}');
        return null;
      }

      if (timestamp is int) {
        return DateTime.fromMillisecondsSinceEpoch(timestamp);
      } else if (timestamp is String) {
        return DateTime.tryParse(timestamp);
      }
      return null;
    } catch (e) {
      print('❌ Error parsing order date for ${order['orderId']}: $e');
      return null;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _backgroundColor,
      appBar: AppBar(
        title: Text(
          '📊 Sales Reports',
          style: TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.bold,
          ),
        ),
        backgroundColor: _primaryColor,
        elevation: 0,
        centerTitle: true,
        actions: [
          IconButton(
            icon: Icon(Icons.refresh, color: Colors.white),
            onPressed: _loadSalesData,
          ),
        ],
      ),
      body: _isLoading
          ? Center(child: CircularProgressIndicator(color: _primaryColor))
          : _allOrders.isEmpty
          ? Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.shopping_bag_outlined, size: 80, color: Colors.grey),
            SizedBox(height: 16),
            Text(
              'No orders found',
              style: TextStyle(fontSize: 18, color: Colors.grey),
            ),
            SizedBox(height: 8),
            ElevatedButton(
              onPressed: _loadSalesData,
              style: ElevatedButton.styleFrom(
                backgroundColor: _primaryColor,
                foregroundColor: Colors.white,
              ),
              child: Text('Retry'),
            ),
          ],
        ),
      )
          : SingleChildScrollView(
        padding: EdgeInsets.all(16),
        child: Column(
          children: [
            // فلاتر الفترة
            _buildPeriodFilter(),
            SizedBox(height: 20),

            // مؤشر الفترة والإحصائيات السريعة
            _buildPeriodIndicator(),
            SizedBox(height: 16),

            // الإحصائيات السريعة
            _buildQuickStats(),
            SizedBox(height: 20),

            // الرسوم البيانية البديلة
            _buildChartsSection(),
            SizedBox(height: 20),

            // أفضل المنتجات
            _buildTopProducts(),
            SizedBox(height: 20),

            // المنتجات الأقل مبيعاً
            _buildLeastSoldProducts(),
            SizedBox(height: 20),

            // تحليل الطلبات
            _buildOrdersAnalysis(),
            SizedBox(height: 20),
          ],
        ),
      ),
    );
  }

  Widget _buildPeriodFilter() {
    return Card(
      elevation: 3,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '📅 Select Period',
              style: TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 16,
                color: _primaryColor,
              ),
            ),
            SizedBox(height: 12),
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: [
                  _buildPeriodChip('Today', 'daily'),
                  SizedBox(width: 8),
                  _buildPeriodChip('This Week', 'weekly'),
                  SizedBox(width: 8),
                  _buildPeriodChip('This Month', 'monthly'),
                  SizedBox(width: 8),
                  _buildPeriodChip('All Time', 'all'),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPeriodChip(String label, String value) {
    final isSelected = _selectedPeriod == value;
    return ChoiceChip(
      label: Text(label),
      selected: isSelected,
      onSelected: (selected) {
        setState(() {
          _selectedPeriod = value;
          _filteredOrders = _filterOrdersByPeriod(_allOrders, value);
        });
      },
      backgroundColor: Colors.white,
      selectedColor: _primaryColor,
      labelStyle: TextStyle(
        color: isSelected ? Colors.white : _primaryColor,
        fontWeight: FontWeight.bold,
      ),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20),
        side: BorderSide(color: _primaryColor),
      ),
    );
  }

  Widget _buildPeriodIndicator() {
    String periodText = '';
    switch (_selectedPeriod) {
      case 'daily': periodText = 'Today'; break;
      case 'weekly': periodText = 'This Week'; break;
      case 'monthly': periodText = 'This Month'; break;
      case 'all': periodText = 'All Time'; break;
    }

    return Container(
      width: double.infinity,
      padding: EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: _primaryColor.withOpacity(0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: _primaryColor.withOpacity(0.3)),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.calendar_today, size: 18, color: _primaryColor),
          SizedBox(width: 8),
          Text(
            'Showing: $periodText • ',
            style: TextStyle(
              color: _primaryColor,
              fontWeight: FontWeight.w500,
            ),
          ),
          Text(
            '${_filteredOrders.length} orders',
            style: TextStyle(
              color: _primaryColor,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildQuickStats() {
    final totalSales = _calculateTotalSales();
    final totalOrders = _filteredOrders.length;
    final avgOrderValue = totalOrders > 0 ? totalSales / totalOrders : 0;
    final completedOrders = _filteredOrders.where((order) =>
    order['status'] == 'Delivered' || order['status'] == 'Completed').length;

    final pendingOrders = _filteredOrders.where((order) =>
    order['status'] == 'Pending').length;

    final processingOrders = _filteredOrders.where((order) =>
    order['status'] == 'Processing' || order['status'] == 'Confirmed').length;

    final shippedOrders = _filteredOrders.where((order) =>
    order['status'] == 'Shipped').length;

    final cancelledOrders = _filteredOrders.where((order) =>
    order['status'] == 'Cancelled' || order['status'] == 'Cancelled_by_user').length;

    if (_filteredOrders.isEmpty) {
      return Container(
        padding: EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Colors.grey.shade300),
        ),
        child: Column(
          children: [
            Icon(Icons.shopping_bag_outlined, size: 60, color: Colors.grey),
            SizedBox(height: 10),
            Text(
              'No orders in selected period',
              style: TextStyle(color: Colors.grey, fontSize: 16),
            ),
            SizedBox(height: 8),
            Text(
              'Try selecting a different time period',
              style: TextStyle(color: Colors.grey, fontSize: 12),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      );
    }

    return GridView.count(
      shrinkWrap: true,
      physics: NeverScrollableScrollPhysics(),
      crossAxisCount: 2,
      crossAxisSpacing: 12,
      mainAxisSpacing: 12,
      children: [
        _buildStatCard(
          'Total Sales',
          'OMR ${totalSales.toStringAsFixed(3)}',
          Icons.attach_money,
          Colors.green,
        ),
        _buildStatCard(
          'Total Orders',
          totalOrders.toString(),
          Icons.shopping_cart,
          Colors.blue,
        ),
        _buildStatCard(
          'Avg. Order',
          'OMR ${avgOrderValue.toStringAsFixed(3)}',
          Icons.analytics,
          Colors.orange,
        ),
        _buildStatCard(
          'Completed',
          '$completedOrders',
          Icons.check_circle,
          Colors.purple,
        ),
      ],
    );
  }

  Widget _buildStatCard(String title, String value, IconData icon, Color color) {
    return Card(
      elevation: 4,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [color.withOpacity(0.1), color.withOpacity(0.05)],
          ),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Padding(
          padding: EdgeInsets.all(16),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, color: color, size: 30),
              SizedBox(height: 8),
              Text(
                value,
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: _textColor,
                ),
              ),
              SizedBox(height: 4),
              Text(
                title,
                style: TextStyle(
                  fontSize: 12,
                  color: _textColor.withOpacity(0.7),
                ),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildChartsSection() {
    if (_filteredOrders.isEmpty) return SizedBox();

    final totalSales = _calculateTotalSales();
    final totalOrders = _filteredOrders.length;
    final completedOrders = _filteredOrders.where((order) =>
    order['status'] == 'Delivered' || order['status'] == 'Completed').length;
    final pendingOrders = _filteredOrders.where((order) =>
    order['status'] == 'Pending').length;

    return Card(
      elevation: 3,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.analytics, color: _primaryColor),
                SizedBox(width: 8),
                Text(
                  '📈 Sales Analytics',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                    color: _primaryColor,
                  ),
                ),
              ],
            ),
            SizedBox(height: 16),

            // إحصائيات مكملة
            Row(
              children: [
                Expanded(
                  child: _buildMiniStatCard(
                    'Completed',
                    '$completedOrders',
                    Icons.check_circle,
                    Colors.green,
                  ),
                ),
                SizedBox(width: 12),
                Expanded(
                  child: _buildMiniStatCard(
                    'Pending',
                    '$pendingOrders',
                    Icons.pending,
                    Colors.orange,
                  ),
                ),
              ],
            ),
            SizedBox(height: 12),

            // ملخص المبيعات
            Container(
              padding: EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: _primaryColor.withOpacity(0.05),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: _primaryColor.withOpacity(0.2)),
              ),
              child: Column(
                children: [
                  Text(
                    '📅 Period Summary',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      color: _primaryColor,
                    ),
                  ),
                  SizedBox(height: 8),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text('Total Sales:', style: TextStyle(fontWeight: FontWeight.w500)),
                      Text(
                        'OMR ${totalSales.toStringAsFixed(3)}',
                        style: TextStyle(fontWeight: FontWeight.bold, color: _primaryColor),
                      ),
                    ],
                  ),
                  SizedBox(height: 4),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text('Total Orders:', style: TextStyle(fontWeight: FontWeight.w500)),
                      Text(
                        '$totalOrders',
                        style: TextStyle(fontWeight: FontWeight.bold, color: _primaryColor),
                      ),
                    ],
                  ),
                  SizedBox(height: 4),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text('Completion Rate:', style: TextStyle(fontWeight: FontWeight.w500)),
                      Text(
                        '${totalOrders > 0 ? ((completedOrders / totalOrders) * 100).toStringAsFixed(1) : 0}%',
                        style: TextStyle(fontWeight: FontWeight.bold, color: Colors.green),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  // كارد صغيرة للإحصائيات
  Widget _buildMiniStatCard(String title, String value, IconData icon, Color color) {
    return Container(
      padding: EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withOpacity(0.3)),
      ),
      child: Column(
        children: [
          Icon(icon, size: 20, color: color),
          SizedBox(height: 4),
          Text(
            value,
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: color,
            ),
          ),
          Text(
            title,
            style: TextStyle(
              fontSize: 10,
              color: _textColor.withOpacity(0.7),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTopProducts() {
    final topProducts = _getTopProducts();

    if (topProducts.isEmpty) {
      return SizedBox(); // لا تظهر إذا لا توجد منتجات
    }

    return Card(
      elevation: 3,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.star, color: Colors.amber),
                SizedBox(width: 8),
                Text(
                  '🏆 Top Products',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                    color: _primaryColor,
                  ),
                ),
              ],
            ),
            SizedBox(height: 12),
            ...topProducts.entries.take(5).map((entry) {
              return _buildProductItem(entry.key, entry.value, true);
            }).toList(),
          ],
        ),
      ),
    );
  }

  Widget _buildLeastSoldProducts() {
    final leastSoldProducts = _getLeastSoldProducts();

    if (leastSoldProducts.isEmpty) {
      return SizedBox(); // لا تظهر إذا لا توجد منتجات
    }

    return Card(
      elevation: 3,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.warning, color: Colors.orange),
                SizedBox(width: 8),
                Text(
                  '📉 Least Sold Products',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                    color: Colors.orange,
                  ),
                ),
              ],
            ),
            SizedBox(height: 12),
            ...leastSoldProducts.entries.take(5).map((entry) {
              return _buildProductItem(entry.key, entry.value, false);
            }).toList(),

            // ملاحظة إضافية
            if (leastSoldProducts.isNotEmpty)
              Container(
                margin: EdgeInsets.only(top: 12),
                padding: EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.orange.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  children: [
                    Icon(Icons.info, size: 16, color: Colors.orange),
                    SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'These products may need marketing attention',
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.orange[700],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildProductItem(String productName, int salesCount, bool isTopProduct) {
    return ListTile(
      contentPadding: EdgeInsets.symmetric(vertical: 4),
      leading: CircleAvatar(
        backgroundColor: isTopProduct
            ? _primaryColor.withOpacity(0.1)
            : Colors.orange.withOpacity(0.1),
        child: Icon(
          isTopProduct ? Icons.shopping_bag : Icons.warning,
          color: isTopProduct ? _primaryColor : Colors.orange,
          size: 20,
        ),
      ),
      title: Text(
        productName,
        style: TextStyle(fontWeight: FontWeight.w500),
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
      ),
      trailing: Container(
        padding: EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: isTopProduct
              ? _primaryColor.withOpacity(0.1)
              : Colors.orange.withOpacity(0.1),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Text(
          '$salesCount ${salesCount == 1 ? 'sale' : 'sales'}',
          style: TextStyle(
            color: isTopProduct ? _primaryColor : Colors.orange,
            fontWeight: FontWeight.bold,
            fontSize: 12,
          ),
        ),
      ),
    );
  }

  // حساب إجمالي المبيعات
  double _calculateTotalSales() {
    double total = 0;
    for (var order in _filteredOrders) {
      total += (order['totalAmount'] ?? 0).toDouble();
    }
    return total;
  }

  // أفضل المنتجات مبيعاً
  Map<String, int> _getTopProducts() {
    Map<String, int> productCount = {};

    for (var order in _filteredOrders) {
      dynamic items = order['items'] ?? order['products'] ?? order['cartItems'];

      if (items != null) {
        if (items is Map) {
          items.forEach((key, item) {
            if (item is Map) {
              final productName = item['productName'] ?? item['name'] ?? 'Unknown Product';
              final quantity = item['quantity'] ?? 1;
              productCount[productName] = (productCount[productName] ?? 0) + (quantity is int ? quantity : 1);
            }
          });
        } else if (items is List) {
          for (var item in items) {
            if (item is Map) {
              final productName = item['productName'] ?? item['name'] ?? 'Unknown Product';
              final quantity = item['quantity'] ?? 1;
              productCount[productName] = (productCount[productName] ?? 0) + (quantity is int ? quantity : 1);
            }
          }
        }
      }
    }

    // ترتيب تنازلي حسب المبيعات
    final sortedEntries = productCount.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));

    return Map.fromEntries(sortedEntries);
  }

  // المنتجات الأقل مبيعاً
  Map<String, int> _getLeastSoldProducts() {
    Map<String, int> productCount = _getTopProducts(); // نستخدم نفس الدالة للحصول على جميع المنتجات

    // ترتيب تصاعدي حسب المبيعات (الأقل مبيعاً أولاً)
    final sortedEntries = productCount.entries.toList()
      ..sort((a, b) => a.value.compareTo(b.value));

    // تصفية المنتجات التي لديها مبيعات قليلة (أقل من أو يساوي 5 مبيعات)
    final lowSalesProducts = sortedEntries.where((entry) => entry.value <= 5).toList();

    return Map.fromEntries(lowSalesProducts);
  }

  // تحليل الطلبات
  Widget _buildOrdersAnalysis() {
    final statusAnalysis = _getOrdersByStatus();

    if (statusAnalysis.isEmpty) {
      return SizedBox();
    }

    return Card(
      elevation: 3,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.analytics, color: _primaryColor),
                SizedBox(width: 8),
                Text(
                  '📋 Orders Analysis',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                    color: _primaryColor,
                  ),
                ),
              ],
            ),
            SizedBox(height: 12),
            ...statusAnalysis.entries.map((entry) {
              return _buildStatusItem(entry.key, entry.value);
            }).toList(),
          ],
        ),
      ),
    );
  }

  Widget _buildStatusItem(String status, int count) {
    return ListTile(
      contentPadding: EdgeInsets.symmetric(vertical: 2),
      leading: Container(
        width: 12,
        height: 12,
        decoration: BoxDecoration(
          color: _getStatusColor(status),
          shape: BoxShape.circle,
        ),
      ),
      title: Text(status),
      trailing: Text(
        '$count orders',
        style: TextStyle(fontWeight: FontWeight.bold),
      ),
    );
  }

  Map<String, int> _getOrdersByStatus() {
    Map<String, int> statusCount = {};
    for (var order in _filteredOrders) {
      final status = order['status']?.toString() ?? 'Pending';
      statusCount[status] = (statusCount[status] ?? 0) + 1;
    }
    return statusCount;
  }

  Color _getStatusColor(String status) {
    switch (status.toLowerCase()) {
      case 'delivered': return Colors.green;
      case 'completed': return Colors.green;
      case 'shipped': return Colors.purple;
      case 'processing': return Colors.blue;
      case 'confirmed': return Colors.blue;
      case 'pending': return Colors.orange;
      case 'cancelled': return Colors.red;
      case 'cancelled_by_user': return Colors.red[700]!;
      default: return _primaryColor;
    }
  }
}