import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:firebase_database/firebase_database.dart';
import 'receipt_model.dart';
// models/receipt_model.dart
class Receipt {
  final String orderNumber;
  final DateTime orderDate;
  final String customerName;
  final String customerEmail;
  final double subtotal;
  final double tax;
  final double shipping;
  final double total;
  final List<ReceiptItem> items;
  final ShippingAddress shippingAddress;
  final BillingAddress billingAddress;
  final String paymentMethod;

  Receipt({
    required this.orderNumber,
    required this.orderDate,
    required this.customerName,
    required this.customerEmail,
    required this.subtotal,
    required this.tax,
    required this.shipping,
    required this.total,
    required this.items,
    required this.shippingAddress,
    required this.billingAddress,
    required this.paymentMethod,
  });

  Map<String, dynamic> toMap() {
    return {
      'orderNumber': orderNumber,
      'orderDate': orderDate.millisecondsSinceEpoch,
      'customerName': customerName,
      'customerEmail': customerEmail,
      'subtotal': subtotal,
      'tax': tax,
      'shipping': shipping,
      'total': total,
      'items': items.map((item) => item.toMap()).toList(),
      'shippingAddress': shippingAddress.toMap(),
      'billingAddress': billingAddress.toMap(),
      'paymentMethod': paymentMethod,
    };
  }
}

class ReceiptItem {
  final String productName;
  final int quantity;
  final double price;
  final String? imageUrl;
  final String? productId;

  ReceiptItem({
    required this.productName,
    required this.quantity,
    required this.price,
    this.imageUrl,
    this.productId,
  });

  Map<String, dynamic> toMap() {
    return {
      'productName': productName,
      'quantity': quantity,
      'price': price,
      'imageUrl': imageUrl,
      'productId': productId,
    };
  }
}

class ShippingAddress {
  final String fullName;
  final String address;
  final String city;
  final String state;
  final String zipCode;
  final String country;
  final String? phone;

  ShippingAddress({
    required this.fullName,
    required this.address,
    required this.city,
    required this.state,
    required this.zipCode,
    required this.country,
    this.phone,
  });

  Map<String, dynamic> toMap() {
    return {
      'fullName': fullName,
      'address': address,
      'city': city,
      'state': state,
      'zipCode': zipCode,
      'country': country,
      'phone': phone,
    };
  }
}

class BillingAddress {
  final String fullName;
  final String address;
  final String city;
  final String state;
  final String zipCode;
  final String country;

  BillingAddress({
    required this.fullName,
    required this.address,
    required this.city,
    required this.state,
    required this.zipCode,
    required this.country,
  });

  Map<String, dynamic> toMap() {
    return {
      'fullName': fullName,
      'address': address,
      'city': city,
      'state': state,
      'zipCode': zipCode,
      'country': country,
    };
  }
}
//------------------------------------------------------------
// services/receipt_service.dart


class ReceiptService {
  // استخدم EmailJS - خدمة مجانية لإرسال الإيميلات
  static const String _apiUrl = 'https://api.emailjs.com/api/v1.0/email/send';
  static const String _serviceId = 'service_qpzj0yd'; // احصل عليه من emailjs.com
  static const String _templateId = 'template_8ssktat'; // قم بإنشاء قالب
  static const String _userId = 'e6hlb3hGsHh55Z2jx'; // المفتاح العام من EmailJS

  static Future<bool> sendDigitalReceipt({
    required String customerName,
    required String customerEmail,
    required String orderNumber,
    required double subtotal,
    required double taxAmount,
    required double deliveryFee,
    required double discountAmount,
    required double totalAmount,
    required List<Map<String, dynamic>> items,
    required Map<String, dynamic> deliveryAddress,
    required Map<String, dynamic> billingAddress,
    required String paymentMethod,
  }) async {
    try {
      final response = await http.post(
        Uri.parse(_apiUrl),
        headers: {'Content-Type': 'application/json'},
        body: json.encode({
          'service_id': _serviceId,
          'template_id': _templateId,
          'user_id': _userId,
          'template_params': {
            // 🔴 **المتغيرات الأساسية - استخدم الباراميترات الصحيحة**
            'customer_name': customerName, // ← المتغير الصحيح من باراميترات الدالة
            'customer_email': customerEmail, // ← المتغير الصحيح من باراميترات الدالة
            'order_number': orderNumber, // ← المتغير الصحيح من باراميترات الدالة

            // 🔴 **التاريخ والوقت - استخدم الدوال المساعدة**
            'order_date': _formatDate(DateTime.now()), // ← استدعاء دالة _formatDate
            'order_time': _formatTime(DateTime.now()), // ← استدعاء دالة _formatTime

            // 🔴 **المبالغ المالية - استخدم الباراميترات الصحيحة مع format**
            'subtotal': 'OMR ${subtotal.toStringAsFixed(3)}',
            'tax': 'OMR ${taxAmount.toStringAsFixed(3)}', // ← المتغير الصحيح: taxAmount
            'delivery_fee': 'OMR ${deliveryFee.toStringAsFixed(3)}',
            'discount': 'OMR ${discountAmount.toStringAsFixed(3)}',
            'total': 'OMR ${totalAmount.toStringAsFixed(3)}',

            // 🔴 **الباقي صحيح**
            'payment_method': paymentMethod,
            'order_items': _buildOrderItemsHtml(items),
            'shipping_address': _buildAddressHtml(deliveryAddress),
            'billing_address': _buildAddressHtml(billingAddress),
            'to_email': customerEmail,
            'company_name': 'Skinglow',
            'company_email': 'noreply@skinglow.com',
            'support_email': 'support@skinglow.com',
            'website_url': 'https://skinglow.com',
          }
        }),
      );

      if (response.statusCode == 200) {
        print('✅ Receipt email sent successfully to $customerEmail');

        // احفظ سجل الإرسال في قاعدة البيانات
        await _saveReceiptToDatabase(
          orderNumber: orderNumber,
          customerEmail: customerEmail,
          totalAmount: totalAmount,
        );

        return true;
      } else {
        print('❌ Failed to send email: ${response.statusCode}');
        return false;
      }
    } catch (e) {
      print('❌ Error sending receipt: $e');
      return false;
    }
  }

  static String _buildOrderItemsHtml(List<Map<String, dynamic>> items) {
    String itemsHtml = '';

    for (int i = 0; i < items.length; i++) {
      final item = items[i];
      final total = (item['price'] as double) * (item['quantity'] as int);

      itemsHtml += '''
        <tr style="border-bottom: 1px solid #eee;">
          <td style="padding: 12px 0; vertical-align: top; width: 70%;">
            <strong>${item['name']}</strong>
            <br>
            <span style="color: #666; font-size: 12px;">
              Qty: ${item['quantity']} × OMR ${(item['price'] as double).toStringAsFixed(3)}
            </span>
          </td>
          <td style="padding: 12px 0; text-align: right; vertical-align: top; width: 30%;">
            OMR ${total.toStringAsFixed(3)}
          </td>
        </tr>
      ''';
    }

    return itemsHtml;
  }

  static String _buildAddressHtml(Map<String, dynamic> address) {
    return '''
      <div style="line-height: 1.6;">
        <strong>${address['fullName'] ?? address['customerName']}</strong><br>
        ${address['address'] ?? ''}<br>
        ${address['city'] ?? ''}, ${address['state'] ?? ''} ${address['zipCode'] ?? ''}<br>
        ${address['country'] ?? 'Oman'}<br>
        ${address['phone'] != null ? 'Phone: ${address['phone']}' : ''}
      </div>
    ''';
  }

  static String _formatDate(DateTime date) {
    return '${date.day}/${date.month}/${date.year}';
  }

  static String _formatTime(DateTime date) {
    return '${date.hour}:${date.minute.toString().padLeft(2, '0')}';
  }

  static Future<void> _saveReceiptToDatabase({
    required String orderNumber,
    required String customerEmail,
    required double totalAmount,
  }) async {
    try {
      final databaseRef = FirebaseDatabase.instance.ref();
      await databaseRef
          .child('receipts')
          .child(orderNumber)
          .set({
        'sentAt': DateTime.now().millisecondsSinceEpoch,
        'customerEmail': customerEmail,
        'totalAmount': totalAmount,
        'status': 'sent',
      });
    } catch (e) {
      print('Error saving receipt to database: $e');
    }
  }
}