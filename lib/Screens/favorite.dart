
// في ملف lib/models/favorite_model.dart
import 'package:flutter/foundation.dart';
// في ملف lib/screens/favorites_screen.dart
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:skinglow/Screens/product_detail_screen.dart';
import 'favorites_model.dart';

class FavoritesScreen extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final favorites = Provider.of<Favorites>(context);

    return Scaffold(
      appBar: AppBar(
        title: Text('Favorites'),
      ),
      body: favorites.items.isEmpty
          ? Center(
        child: Text('There are no products in the favorites'),
      )
          : ListView.builder(
        itemCount: favorites.items.length,
        itemBuilder: (ctx, index) {
          final productId = favorites.items.keys.elementAt(index);
          final item = favorites.items[productId]!;

          // إنشاء كائن منتج من البيانات المتوفرة في المفضلة
          Map<String, dynamic> product = {
            'id': item.id,
            'name': item.name,
            'price': item.price,
            'image': item.imageUrl,
            'brand': 'Unknown Brand', // إذا لم يكن متوفرًا
            'description': 'No description available', // إذا لم يكن متوفرًا
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
            child: ListTile(
              leading: Image.network(
                item.imageUrl,
                width: 50,
                height: 50,
                fit: BoxFit.cover,
                errorBuilder: (context, error, stackTrace) {
                  return Icon(Icons.shopping_bag);
                },
              ),
              title: Text(item.name),
              subtitle: Text('OMR ${item.price.toStringAsFixed(3)}'),
              trailing: IconButton(
                icon: Icon(Icons.delete, color: Colors.red),
                onPressed: () => favorites.removeItem(item.id),
              ),
            ),
          );
        },
      ),
    );
  }
}