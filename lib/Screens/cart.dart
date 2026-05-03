import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:skinglow/Screens/product_detail_screen.dart';
import 'package:skinglow/Screens/checkout_screen.dart';
import 'cart_model.dart';

class CartScreen extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final cart = Provider.of<Cart>(context);
    final cartItems = cart.items.values.toList();

    return Scaffold(
      appBar: AppBar(
        title: Text('Shopping Cart'),
        backgroundColor: Color(0xFFFFE4F3),
        foregroundColor: Color(0xFF914D74),
        actions: [
          if (cartItems.isNotEmpty)
            IconButton(
              icon: Icon(Icons.delete_sweep),
              onPressed: () {
                showDialog(
                  context: context,
                  builder: (BuildContext context) {
                    return AlertDialog(
                      title: Text('Clear Cart'),
                      content: Text('Are you sure you want to remove all items from the cart?'),
                      actions: [
                        TextButton(
                          onPressed: () => Navigator.of(context).pop(),
                          child: Text('Cancel'),
                        ),
                        TextButton(
                          onPressed: () {
                            cart.clear();
                            Navigator.of(context).pop();
                          },
                          child: Text('Yes', style: TextStyle(color: Colors.red)),
                        ),
                      ],
                    );
                  },
                );
              },
            ),
        ],
      ),
      body: cartItems.isEmpty
          ? Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.shopping_cart, size: 64, color: Colors.grey),
            SizedBox(height: 16),
            Text('Your cart is empty'),
            SizedBox(height: 8),
            Text('Add some products to see them here', style: TextStyle(color: Colors.grey)),
          ],
        ),
      )
          : Column(
        children: [
          Expanded(
            child: ListView.builder(
              itemCount: cartItems.length,
              itemBuilder: (ctx, index) {
                final item = cartItems[index];

                // ✅ التحقق من وجود خصم
                final hasDiscount = item.hasDiscount;
                final discountValue = hasDiscount ? item.discount!['discountValue']?.toDouble() : 0.0;
                final discountType = hasDiscount ? item.discount!['discountType'] : 'percentage';

                Map<String, dynamic> product = {
                  'id': item.id,
                  'name': item.name,
                  'price': item.price,
                  'image': item.imageUrl,
                  'brand': 'Unknown Brand',
                  'description': 'No description available',
                  // ✅ إضافة بيانات الخصم للمنتج
                  'discount': item.discount,
                  'originalPrice': item.originalPrice,
                };

                return InkWell(
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => ProductDetailScreen(product: product),
                      ),
                    );
                  },
                  child: Card(
                    margin: EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    child: Padding(
                      padding: EdgeInsets.all(12),
                      child: Row(
                        children: [
                          // Product Image
                          Container(
                            width: 60,
                            height: 60,
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(8),
                              color: Colors.grey[200],
                            ),
                            child: item.imageUrl.isNotEmpty
                                ? Image.network(
                              item.imageUrl,
                              fit: BoxFit.cover,
                              errorBuilder: (context, error, stackTrace) {
                                return Icon(Icons.shopping_bag, size: 30, color: Colors.grey);
                              },
                            )
                                : Icon(Icons.shopping_bag, size: 30, color: Colors.grey),
                          ),
                          SizedBox(width: 12),
                          // Product Details
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  item.name,
                                  style: TextStyle(fontWeight: FontWeight.bold),
                                  maxLines: 2,
                                  overflow: TextOverflow.ellipsis,
                                ),
                                SizedBox(height: 4),

                                // ✅ عرض الخصم إن وجد
                                if (hasDiscount)
                                  Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Row(
                                        children: [
                                          Container(
                                            padding: EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                            decoration: BoxDecoration(
                                              color: Colors.red,
                                              borderRadius: BorderRadius.circular(4),
                                            ),
                                            child: Text(
                                              discountType == 'percentage'
                                                  ? '${discountValue.toInt()}% OFF'
                                                  : 'DISCOUNT',
                                              style: TextStyle(
                                                color: Colors.white,
                                                fontSize: 10,
                                                fontWeight: FontWeight.bold,
                                              ),
                                            ),
                                          ),
                                          SizedBox(width: 6),
                                          Text(
                                            'OMR ${item.originalPrice.toStringAsFixed(3)}',
                                            style: TextStyle(
                                              color: Colors.grey,
                                              fontSize: 12,
                                              decoration: TextDecoration.lineThrough,
                                            ),
                                          ),
                                        ],
                                      ),
                                      SizedBox(height: 2),
                                    ],
                                  ),

                                Text(
                                  'OMR ${item.discountedPrice.toStringAsFixed(3)}',
                                  style: TextStyle(
                                    color: hasDiscount ? Colors.red : Color(0xFF914D74),
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),

                                // ✅ عرض التوفير
                                if (hasDiscount)
                                  Text(
                                    'Save OMR ${item.discountAmount.toStringAsFixed(3)}',
                                    style: TextStyle(
                                      color: Colors.green,
                                      fontSize: 11,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                              ],
                            ),
                          ),
                          // Quantity Controls and Delete
                          Column(
                            children: [
                              // Quantity Controls (+ and -)
                              Row(
                                children: [
                                  // Decrement Button (-)
                                  IconButton(
                                    icon: Icon(Icons.remove_circle_outline, color: Colors.grey),
                                    onPressed: () {
                                      if (item.quantity > 1) {
                                        cart.updateQuantity(item.id, item.quantity - 1);
                                      } else {
                                        // Show delete confirmation if quantity is 1
                                        showDialog(
                                          context: context,
                                          builder: (BuildContext context) {
                                            return AlertDialog(
                                              title: Text('Remove Product'),
                                              content: Text('Remove ${item.name} from cart?'),
                                              actions: [
                                                TextButton(
                                                  onPressed: () => Navigator.of(context).pop(),
                                                  child: Text('Cancel'),
                                                ),
                                                TextButton(
                                                  onPressed: () {
                                                    cart.removeItem(item.id);
                                                    Navigator.of(context).pop();
                                                  },
                                                  child: Text('Remove', style: TextStyle(color: Colors.red)),
                                                ),
                                              ],
                                            );
                                          },
                                        );
                                      }
                                    },
                                  ),
                                  // Quantity Display
                                  Container(
                                    padding: EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                                    decoration: BoxDecoration(
                                      border: Border.all(color: Colors.grey),
                                      borderRadius: BorderRadius.circular(4),
                                    ),
                                    child: Text(
                                      item.quantity.toString(),
                                      style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                                    ),
                                  ),
                                  // Increment Button (+)
                                  IconButton(
                                    icon: Icon(Icons.add_circle_outline, color: Color(0xFF914D74)),
                                    onPressed: () {
                                      cart.updateQuantity(item.id, item.quantity + 1);
                                    },
                                  ),
                                ],
                              ),
                              SizedBox(height: 8),
                              // Delete Icon
                              IconButton(
                                icon: Icon(Icons.delete, color: Colors.red, size: 24),
                                onPressed: () {
                                  showDialog(
                                    context: context,
                                    builder: (BuildContext context) {
                                      return AlertDialog(
                                        title: Text('Remove Product'),
                                        content: Text('Remove ${item.name} from cart?'),
                                        actions: [
                                          TextButton(
                                            onPressed: () => Navigator.of(context).pop(),
                                            child: Text('Cancel'),
                                          ),
                                          TextButton(
                                            onPressed: () {
                                              cart.removeItem(item.id);
                                              Navigator.of(context).pop();
                                            },
                                            child: Text('Remove', style: TextStyle(color: Colors.red)),
                                          ),
                                        ],
                                      );
                                    },
                                  );
                                },
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
          // ✅ Total Section مع تفاصيل الخصم
          Container(
            padding: EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white,
              boxShadow: [
                BoxShadow(
                  color: Colors.black12,
                  blurRadius: 4,
                  offset: Offset(0, -2),
                ),
              ],
            ),
            child: Column(
              children: [
                // ✅ تفاصيل الأسعار والخصومات
                Consumer<Cart>(
                  builder: (ctx, cart, child) {
                    return Column(
                      children: [
                        if (cart.totalDiscount > 0) ...[
                          _buildPriceRow('Subtotal', cart.totalAmountWithoutDiscount),
                          _buildPriceRow('Discount', -cart.totalDiscount, isDiscount: true),
                          Divider(),
                        ],
                        _buildPriceRow(
                          'Total',
                          cart.totalAmount,
                          isTotal: true,
                        ),

                        if (cart.totalDiscount > 0)
                          Padding(
                            padding: EdgeInsets.only(top: 8),
                            child: Text(
                              'You saved OMR ${cart.totalDiscount.toStringAsFixed(3)}! 🎉',
                              style: TextStyle(
                                color: Colors.green,
                                fontWeight: FontWeight.bold,
                                fontSize: 14,
                              ),
                            ),
                          ),
                      ],
                    );
                  },
                ),

                SizedBox(height: 16),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: () {
                      // الانتقال إلى صفحة الشيكاوت
                      Navigator.push(
                        context,
                        MaterialPageRoute(builder: (context) => CheckoutScreen()),
                      );
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Color(0xFF914D74),
                      padding: EdgeInsets.symmetric(vertical: 16),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                    child: Text(
                      'Complete Purchase',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ✅ دالة مساعدة لعرض صف السعر
  Widget _buildPriceRow(String label, double amount, {bool isDiscount = false, bool isTotal = false}) {
    return Padding(
      padding: EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: TextStyle(
              fontSize: isTotal ? 16 : 14,
              fontWeight: isTotal ? FontWeight.bold : FontWeight.normal,
              color: isDiscount ? Colors.green : Colors.grey[700],
            ),
          ),
          Text(
            '${isDiscount && amount > 0 ? '-' : ''}OMR ${amount.abs().toStringAsFixed(3)}',
            style: TextStyle(
              fontSize: isTotal ? 18 : 14,
              fontWeight: isTotal ? FontWeight.bold : FontWeight.normal,
              color: isTotal ? Color(0xFF914D74) : (isDiscount ? Colors.green : Colors.grey[700]),
            ),
          ),
        ],
      ),
    );
  }
}