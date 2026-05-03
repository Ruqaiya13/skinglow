import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:firebase_database/firebase_database.dart';

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