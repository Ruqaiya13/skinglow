// admin/virtual_cards_upload_page.dart
import 'package:flutter/material.dart';
import 'FirebaseDataUploader.dart';

class VirtualCardsUploadPage extends StatelessWidget {
  final FirebaseDataUploader uploader = FirebaseDataUploader();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Virtual Cards Management'),
        backgroundColor: Color(0xFF914D74),
      ),
      body: Center(
        child: Padding(
          padding: EdgeInsets.all(20),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.credit_card, size: 80, color: Colors.blue),
              SizedBox(height: 20),
              Text(
                'Upload Virtual Cards',
                style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
              ),
              SizedBox(height: 10),
              Text(
                'Cards will be uploaded from JSON file to the database',
                textAlign: TextAlign.center,
                style: TextStyle(color: Colors.grey),
              ),
              SizedBox(height: 30),
              ElevatedButton.icon(
                icon: Icon(Icons.cloud_upload),
                label: Text('Upload Cards from JSON File'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.blue,
                  foregroundColor: Colors.white,
                  padding: EdgeInsets.symmetric(horizontal: 30, vertical: 15),
                  textStyle: TextStyle(fontSize: 16),
                ),
                onPressed: () async {
                  await uploader.uploadVirtualCardsToFirebase();
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text('✅ Cards uploaded to Firebase successfully'),
                      backgroundColor: Colors.green,
                      duration: Duration(seconds: 3),
                    ),
                  );
                },
              ),
            ],
          ),
        ),
      ),
    );
  }
}