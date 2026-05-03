import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter/material.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_database/ui/firebase_animated_list.dart';

class NotificationHistoryScreen extends StatefulWidget {
  @override
  _NotificationHistoryScreenState createState() => _NotificationHistoryScreenState();
}

class _NotificationHistoryScreenState extends State<NotificationHistoryScreen> {
  List<Map<String, dynamic>> _notifications = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadNotifications();
  }

  Future<void> _loadNotifications() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final String? notificationsJson = prefs.getString('sent_notifications');

      List<Map<String, dynamic>> loadedNotifications = [];

      if (notificationsJson != null && notificationsJson.isNotEmpty) {
        final notificationsList = notificationsJson.split('||')
            .map((item) {
          try {
            final parts = item.split('|');
            if (parts.length >= 3) {
              return {
                'title': parts[0],
                'body': parts[1],
                'timestamp': DateTime.parse(parts[2]),
              };
            }
          } catch (e) {
            print('Error parsing notification: $e');
          }
          return null;
        }).where((item) => item != null).toList();

        loadedNotifications = notificationsList.cast<Map<String, dynamic>>();
      }

      setState(() {
        _notifications = loadedNotifications;
        _isLoading = false;
      });
    } catch (e) {
      print('Error loading notifications: $e');
      setState(() => _isLoading = false);
    }
  }

  Future<void> _clearAllNotifications() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Confirm Clear'),
        content: Text('Are you sure you want to clear all notification history?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: Text('Clear', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove('sent_notifications');
      setState(() => _notifications = []);

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Notification history cleared')),
      );
    }
  }

  String _getNotificationType(String title, String body) {
    final lowerTitle = title.toLowerCase();
    final lowerBody = body.toLowerCase();

    if (lowerTitle.contains('product') || lowerBody.contains('product')) {
      return 'product';
    } else if (lowerTitle.contains('discount') || lowerBody.contains('discount') || lowerBody.contains('code')) {
      return 'discount';
    } else if (lowerTitle.contains('order') || lowerBody.contains('order')) {
      return 'order';
    } else {
      return 'general';
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Notification History'),
        backgroundColor: Color(0xFF914D74),
        actions: [
          if (_notifications.isNotEmpty)
            IconButton(
              icon: Icon(Icons.delete_sweep),
              onPressed: _clearAllNotifications,
              tooltip: 'Clear All',
            ),
          IconButton(
            icon: Icon(Icons.refresh),
            onPressed: _loadNotifications,
            tooltip: 'Refresh',
          ),
        ],
      ),
      body: _isLoading
          ? Center(child: CircularProgressIndicator())
          : _notifications.isEmpty
          ? _buildEmptyState()
          : _buildNotificationsList(),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.notifications_none, size: 80, color: Colors.grey[400]),
          SizedBox(height: 16),
          Text(
            'No notifications yet',
            style: TextStyle(fontSize: 18, color: Colors.grey[600]),
          ),
          SizedBox(height: 8),
          Text(
            'Sent notifications will appear here',
            style: TextStyle(color: Colors.grey[500]),
          ),
        ],
      ),
    );
  }

  Widget _buildNotificationsList() {
    return ListView.builder(
      itemCount: _notifications.length,
      padding: EdgeInsets.all(16),
      itemBuilder: (context, index) {
        final notification = _notifications[index];
        return _buildNotificationCard(notification, index);
      },
    );
  }

  Widget _buildNotificationCard(Map<String, dynamic> notification, int index) {
    final type = _getNotificationType(
      notification['title'] ?? '',
      notification['body'] ?? '',
    );

    final typeInfo = _getNotificationTypeInfo(type);

    return Card(
      margin: EdgeInsets.only(bottom: 12),
      elevation: 3,
      child: ListTile(
        leading: Container(
          width: 40,
          height: 40,
          decoration: BoxDecoration(
            color: typeInfo.color.withOpacity(0.1),
            shape: BoxShape.circle,
          ),
          child: Icon(typeInfo.icon, color: typeInfo.color, size: 20),
        ),
        title: Text(
          notification['title'] ?? 'No Title',
          style: TextStyle(fontWeight: FontWeight.w600),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SizedBox(height: 4),
            Text(
              notification['body'] ?? 'No Message',
              style: TextStyle(fontSize: 14),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
            SizedBox(height: 8),
            Text(
              _formatDate(notification['timestamp']),
              style: TextStyle(fontSize: 12, color: Colors.grey[600]),
            ),
          ],
        ),
        trailing: Container(
          padding: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          decoration: BoxDecoration(
            color: typeInfo.color.withOpacity(0.1),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Text(
            typeInfo.name,
            style: TextStyle(fontSize: 10, color: typeInfo.color, fontWeight: FontWeight.w500),
          ),
        ),
      ),
    );
  }

  String _formatDate(DateTime date) {
    final now = DateTime.now();
    final difference = now.difference(date);

    if (difference.inDays > 0) {
      return '${difference.inDays} days ago';
    } else if (difference.inHours > 0) {
      return '${difference.inHours} hours ago';
    } else if (difference.inMinutes > 0) {
      return '${difference.inMinutes} minutes ago';
    } else {
      return 'Just now';
    }
  }

  _NotificationTypeInfo _getNotificationTypeInfo(String type) {
    switch (type) {
      case 'product':
        return _NotificationTypeInfo(Icons.shopping_bag, Colors.green, 'Product');
      case 'discount':
        return _NotificationTypeInfo(Icons.local_offer, Color(0xFF914D74), 'Discount');
      case 'order':
        return _NotificationTypeInfo(Icons.inventory_2, Colors.blue, 'Order');
      default:
        return _NotificationTypeInfo(Icons.notifications, Colors.orange, 'General');
    }
  }
}

class _NotificationTypeInfo {
  final IconData icon;
  final Color color;
  final String name;

  _NotificationTypeInfo(this.icon, this.color, this.name);
}
