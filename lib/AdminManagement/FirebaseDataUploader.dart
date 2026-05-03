import 'dart:convert';
import 'package:flutter/services.dart' show rootBundle;
import 'package:firebase_database/firebase_database.dart';

class FirebaseDataUploader {
  // Function to read JSON file and convert it
  Future<Map<String, dynamic>> loadJsonFromAssets() async {
    try {
      String jsonString = await rootBundle.loadString('assets/virtual_cards.json');
      return json.decode(jsonString);
    } catch (e) {
      print('Error loading JSON: $e');
      return {};
    }
  }

  // Function to save data to Firebase
  Future<void> uploadVirtualCardsToFirebase() async {
    try {
      Map<String, dynamic> jsonData = await loadJsonFromAssets();

      if (jsonData.containsKey('virtualCards')) {
        DatabaseReference virtualCardsRef =
        FirebaseDatabase.instance.ref().child('virtualCards');

        // Delete old data first (optional)
        await virtualCardsRef.remove();

        // Save new data
        await virtualCardsRef.set(jsonData['virtualCards']);

        print('✅ Virtual cards data uploaded to Firebase successfully!');
      }
    } catch (e) {
      print('❌ Error uploading to Firebase: $e');
    }
  }
}