import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_database/firebase_database.dart';
import 'User.dart';

class DatabaseHelper {
  static final FirebaseAuth _auth = FirebaseAuth.instance;
  static final DatabaseReference _dbRef = FirebaseDatabase.instance.ref('users');

  static Future<void> createUserWithEmailAndPassword({
    required String email,
    required String password,
    required UserData userData,
  }) async {
    try {
      final UserCredential userCredential =
      await _auth.createUserWithEmailAndPassword(
        email: email,
        password: password,
      );

      // تأكد من أن UID غير null قبل الكتابة
      if (userCredential.user != null) {
        await _dbRef.child(userCredential.user!.uid).set({
          ...userData.toJson(),
          'uid': userCredential.user!.uid, // إضافة UID للتوثيق
          'createdAt': ServerValue.timestamp,
        }).then((_) => print('Data written successfully'))
            .catchError((e) => print('Error writing data: $e'));
      }
    } on FirebaseException catch (e) {
      print('Firebase Error: ${e.code} - ${e.message}');
      rethrow;
    }
  }

  static Future<void> signInWithEmailAndPassword({
    required String email,
    required String password,
  }) async {
    try {
      await _auth.signInWithEmailAndPassword(
        email: email,
        password: password,
      );
    } on FirebaseAuthException catch (e) {
      throw _handleAuthError(e.code);
    }
  }

  static String _handleAuthError(String code) {
    switch (code) {
      case 'user-not-found':
        return 'User not found';
      case 'wrong-password':
        return 'Incorrect password';
      case 'email-already-in-use':
        return 'Email already in use';
      case 'weak-password':
        return 'Password is too weak';
      default:
        return 'An unexpected error occurred';
    }
  }
}



class Database {
  final DatabaseReference databaseReference = FirebaseDatabase.instance.ref().child("products");

  Future<List<Map<String, dynamic>>> fetchProducts() async {
    DataSnapshot snapshot = await databaseReference.get();
    if (snapshot.value != null) {
      Map<String, dynamic> productsMap = Map<String, dynamic>.from(snapshot.value as Map);
      return productsMap.entries.map((entry) {
        var product = Map<String, dynamic>.from(entry.value);
        product['key'] = entry.key; // Include the unique key
        return product;
      }).toList();
    } else {
      return [];
    }
  }
}
