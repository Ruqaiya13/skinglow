import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:skinglow/Screens/Home.dart';
import 'package:skinglow/Screens/search.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:barcode_scan2/barcode_scan2.dart';

import '../SkinAnalysis/skinAnalysis.dart';
import '../SkinAnalysis/skinAnalysisAi/skin_analysis_py.dart';

class BarcodeScannerScreen extends StatefulWidget {
  @override
  _BarcodeScannerScreenState createState() => _BarcodeScannerScreenState();
}

class _BarcodeScannerScreenState extends State<BarcodeScannerScreen> {
  String scannedCode = "Not scanned yet";
  bool _hasPermission = false;
  bool _isLoading = true;
  bool _isProcessing = false;

  @override
  void initState() {
    super.initState();
    _checkPermissions();
  }

  Future<void> _checkPermissions() async {
    try {
      var status = await Permission.camera.status;
      if (!status.isGranted) {
        status = await Permission.camera.request();
      }

      setState(() {
        _hasPermission = status.isGranted;
        _isLoading = false;
      });
    } catch (e) {
      print("Error checking permissions: $e");
      setState(() => _isLoading = false);
    }
  }

  Future<void> _openScanner() async {
    if (!_hasPermission) {
      await _checkPermissions();
      if (!_hasPermission) return;
    }

    setState(() {
      scannedCode = "Scanning...";
      _isProcessing = true;
    });

    try {
      final ScanResult result = await BarcodeScanner.scan();

      if (result.rawContent.isNotEmpty) {
        setState(() {
          scannedCode = result.rawContent;
          _isProcessing = false;
        });
        await _searchProduct(result.rawContent);
      } else {
        setState(() {
          scannedCode = "Scan cancelled";
          _isProcessing = false;
        });
      }
    } catch (e) {
      setState(() {
        scannedCode = "Error: ${e.toString()}";
        _isProcessing = false;
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text("Scanner error: ${e.toString()}"),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  void _manualBarcodeInput() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text("Enter Barcode"),
        content: TextField(
          decoration: InputDecoration(
            hintText: "Enter barcode number here",
            border: OutlineInputBorder(),
          ),
          onChanged: (value) => setState(() => scannedCode = value),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text("Cancel"),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              if (scannedCode.isNotEmpty && scannedCode != "Not scanned yet") {
                _searchProduct(scannedCode);
              }
            },
            child: Text("Search"),
          ),
        ],
      ),
    );
  }

  Future<void> _searchProduct(String barcode) async {
    if (barcode.isEmpty || barcode == "Scan cancelled") return;

    try {
      setState(() => _isProcessing = true);
      List<Map<String, dynamic>> foundProducts = await _searchInFirebase(barcode);

      // Get user skin type
      String? userSkinType = await _getUserSkinType();

      // Navigate to search page immediately
      if (mounted) {
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(
            builder: (context) => SearchPage(
              products: foundProducts,
              searchQuery: barcode,
              isFromBarcode: true,
              userSkinType: userSkinType,
            ),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Search error: ${e.toString()}")),
        );
        setState(() => _isProcessing = false);
      }
    }
  }

  Map<String, dynamic> _checkProductSuitability(
      Map<String, dynamic> product, String? userSkinType) {
    final skinTypes = (product['skinTypes'] as List<dynamic>? ?? [])
        .map((e) => e.toString().toLowerCase())
        .toList();

    bool isSuitable = false;
    bool isPerfectMatch = false;
    String recommendation = "";
    Color color = Colors.grey;
    IconData icon = Icons.help_outline;
    String message = "";

    // التحقق من مطابقة المنتج مع نوع بشرة المستخدم الحقيقي
    if (skinTypes.contains(userSkinType)) {
      isSuitable = true;
      isPerfectMatch = true;
      recommendation = '✅ Perfect for your ${userSkinType} skin';
      color = Colors.green;
      icon = Icons.check_circle;
      message = 'Excellent! This product is specifically designed for ${userSkinType} skin.';
    }
// إذا كان المنتج غير مناسب لنوع بشرة المستخدم
    else {
      isSuitable = false;
      recommendation = '⚠️ May not be suitable for your ${userSkinType} skin';
      color = Colors.orange;
      icon = Icons.warning;
      message = 'This product is designed for: ${skinTypes.join(", ")} skin types. It may not be ideal for your ${userSkinType} skin.';
    }

    // Check if product is suitable for all skin types
    if (skinTypes.contains('all') ||
        skinTypes.contains('all-skin-type') ||
        skinTypes.contains('normal')) {
      isSuitable = true;
      isPerfectMatch = userSkinType == 'normal';
      recommendation = '✅ Suitable for all skin types';
      color = Colors.green;
      icon = Icons.check_circle;
      message = 'This product is suitable for all skin types, including your ${userSkinType} skin.';
    }
    // Check if product is suitable for specific skin type
    else if (skinTypes.contains(userSkinType)) {
      isSuitable = true;
      isPerfectMatch = true;
      recommendation = '✅ Perfect for your ${userSkinType} skin';
      color = Colors.green;
      icon = Icons.check_circle;
      message = 'Excellent! This product is specifically designed for ${userSkinType} skin.';
    }
    // Check if product is not suitable
    else {
      isSuitable = false;
      recommendation = '⚠️ May not be suitable for your ${userSkinType} skin';
      color = Colors.orange;
      icon = Icons.warning;
      message = 'This product is designed for: ${skinTypes.join(", ")} skin types. It may not be ideal for your ${userSkinType} skin.';
    }

    return {
      'isSuitable': isSuitable,
      'isPerfectMatch': isPerfectMatch,
      'recommendation': recommendation,
      'color': color,
      'icon': icon,
      'message': message,
      'skinTypes': skinTypes,
    };
  }


  Future<List<Map<String, dynamic>>> _searchInFirebase(String barcode) async {
    List<Map<String, dynamic>> foundProducts = [];

    try {
      DatabaseReference ref = FirebaseDatabase.instance.ref('products');
      DataSnapshot snapshot = await ref.get();

      if (snapshot.exists) {
        Map<dynamic, dynamic> products = snapshot.value as Map;
        String searchBarcode = barcode.trim();

        products.forEach((key, value) {
          try {
            Map<String, dynamic> product = Map<String, dynamic>.from(value);
            String? productId = product['id']?.toString().trim();

            if (productId == searchBarcode) {
              product['firebaseKey'] = key.toString();
              foundProducts.add(product);
            }
          } catch (e) {
            print("⚠️ Error processing product: $e");
          }
        });
      }
    } catch (e) {
      print("🔥 Firebase error: $e");
    }

    return foundProducts;
  }

  void _resetScanner() {
    setState(() {
      scannedCode = "Not scanned yet";
      _isProcessing = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return _buildLoadingScreen();
    }

    if (!_hasPermission) {
      return _buildPermissionScreen();
    }

    return Scaffold(
      appBar: AppBar(
        title: Text(
          'Barcode Scanner',
          style: TextStyle(
            fontWeight: FontWeight.w600,
            fontSize: 18,
          ),
        ),
        backgroundColor: Colors.white,
        foregroundColor: Colors.black,
        elevation: 1,
        leading: IconButton(
          icon: Icon(Icons.arrow_back_ios_new, size: 20),
          onPressed: () {
            Navigator.pushReplacement(
              context,
              MaterialPageRoute(builder: (context) => Home()),
            );
          },
        ),
        actions: [
          IconButton(
            icon: Icon(Icons.face, size: 22),
            onPressed: _goToSkinAnalysis,
            tooltip: "Set Skin Type",
          ),
          IconButton(
            icon: Icon(Icons.keyboard, size: 22),
            onPressed: _manualBarcodeInput,
            tooltip: "Manual Input",
          ),
        ],
      ),
      body: _buildMainContent(),
    );
  }

  Widget _buildLoadingScreen() {
    return Scaffold(
      appBar: AppBar(
        title: Text('Barcode Scanner'),
        leading: IconButton(
          icon: Icon(Icons.arrow_back_ios_new, size: 20),
          onPressed: () {
            Navigator.pushReplacement(
              context,
              MaterialPageRoute(builder: (context) => Home()),
            );
          },
        ),
      ),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            CircularProgressIndicator(),
            SizedBox(height: 16),
            Text(
              "Initializing...",
              style: TextStyle(color: Colors.grey[600]),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPermissionScreen() {
    return Scaffold(
      appBar: AppBar(
        title: Text('Barcode Scanner'),
        leading: IconButton(
          icon: Icon(Icons.arrow_back_ios_new, size: 20),
          onPressed: () {
            Navigator.pushReplacement(
              context,
              MaterialPageRoute(builder: (context) => Home()),
            );
          },
        ),
      ),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.camera_alt_outlined, size: 72, color: Colors.orange),
              SizedBox(height: 24),
              Text(
                "Camera Permission Required",
                style: TextStyle(fontSize: 20, fontWeight: FontWeight.w600),
              ),
              SizedBox(height: 12),
              Text(
                "This app needs camera permission to scan barcodes",
                textAlign: TextAlign.center,
                style: TextStyle(color: Colors.grey[600]),
              ),
              SizedBox(height: 32),
              ElevatedButton(
                onPressed: _checkPermissions,
                style: ElevatedButton.styleFrom(
                  padding: EdgeInsets.symmetric(horizontal: 32, vertical: 14),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                child: Text("Grant Permission"),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildMainContent() {
    return SingleChildScrollView(
      child: Column(
        children: [
          // Hero Section
          Container(
            height: 320,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [Colors.blue.shade50, Colors.white],
              ),
            ),
            child: Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Container(
                    width: 100,
                    height: 100,
                    decoration: BoxDecoration(
                      color: Colors.blue,
                      shape: BoxShape.circle,
                      boxShadow: [
                        BoxShadow(
                          color: Colors.blue.withOpacity(0.2),
                          blurRadius: 12,
                          spreadRadius: 2,
                        ),
                      ],
                    ),
                    child: Icon(
                      Icons.qr_code_scanner,
                      size: 50,
                      color: Colors.white,
                    ),
                  ),
                  SizedBox(height: 24),
                  Text(
                    "Scan Barcode",
                    style: TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.w700,
                      color: Colors.blue[800],
                    ),
                  ),
                  SizedBox(height: 8),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 40.0),
                    child: Text(
                      "Scan a product barcode to search in our database",
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 14,
                        color: Colors.grey[600],
                      ),
                    ),
                  ),

                  // Add skin type indicator if known
                  SizedBox(height: 16),
                  FutureBuilder<String?>(
                    future: _getUserSkinType(),
                    builder: (context, snapshot) {
                      if (snapshot.connectionState == ConnectionState.waiting) {
                        return Container();
                      }

                      if (snapshot.hasData && snapshot.data!.isNotEmpty) {
                        return Padding(
                          padding: EdgeInsets.only(bottom: 8),
                          child: GestureDetector(
                            onTap: _goToSkinAnalysis,
                            child: Container(
                              padding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                              decoration: BoxDecoration(
                                color: Colors.blue[100],
                                borderRadius: BorderRadius.circular(20),
                                border: Border.all(color: Colors.blue, width: 1),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(Icons.face, size: 16, color: Colors.blue[800]),
                                  SizedBox(width: 8),
                                  Text(
                                    'Your Skin: ${snapshot.data!.toUpperCase()}',
                                    style: TextStyle(
                                      fontSize: 12,
                                      fontWeight: FontWeight.bold,
                                      color: Colors.blue[800],
                                    ),
                                  ),
                                  SizedBox(width: 4),
                                  Icon(Icons.edit, size: 12, color: Colors.blue[600]),
                                ],
                              ),
                            ),
                          ),
                        );
                      } else {
                        return Padding(
                          padding: EdgeInsets.only(bottom: 8),
                          child: GestureDetector(
                            onTap: _goToSkinAnalysis,
                            child: Container(
                              padding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                              decoration: BoxDecoration(
                                color: Colors.orange[100],
                                borderRadius: BorderRadius.circular(20),
                                border: Border.all(color: Colors.orangeAccent, width: 1),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(Icons.warning, size: 16, color: Colors.orange[800]),
                                  SizedBox(width: 8),
                                  Text(
                                    'Set your skin type',
                                    style: TextStyle(
                                      fontSize: 12,
                                      fontWeight: FontWeight.bold,
                                      color: Colors.orange[800],
                                    ),
                                  ),
                                  SizedBox(width: 4),
                                  Icon(Icons.arrow_forward, size: 12, color: Colors.orange[600]),
                                ],
                              ),
                            ),
                          ),
                        );
                      }
                    },
                  ),

                  SizedBox(height: 8),
                  if (_isProcessing)
                    Column(
                      children: [
                        CircularProgressIndicator(),
                        SizedBox(height: 16),
                        Text(
                          "Opening scanner...",
                          style: TextStyle(color: Colors.blue),
                        ),
                      ],
                    )
                  else
                    ElevatedButton.icon(
                      onPressed: _openScanner,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.blue,
                        foregroundColor: Colors.white,
                        padding: EdgeInsets.symmetric(horizontal: 32, vertical: 16),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        elevation: 2,
                      ),
                      icon: Icon(Icons.qr_code_scanner, size: 22),
                      label: Text(
                        "Scan Barcode",
                        style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
                      ),
                    ),
                ],
              ),
            ),
          ),

          // Results Section
          Padding(
            padding: const EdgeInsets.all(20.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  "Scan Result",
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    color: Colors.grey[800],
                  ),
                ),
                SizedBox(height: 12),
                Container(
                  width: double.infinity,
                  padding: EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: _getBarcodeColor().withOpacity(0.1),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: _getBarcodeColor(),
                      width: 1.5,
                    ),
                  ),
                  child: Column(
                    children: [
                      Text(
                        scannedCode,
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w700,
                          color: _getBarcodeColor(),
                        ),
                      ),
                      if (_isProcessing) ...[
                        SizedBox(height: 12),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            SizedBox(
                              width: 16,
                              height: 16,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            ),
                            SizedBox(width: 8),
                            Text(
                              "Processing...",
                              style: TextStyle(
                                fontSize: 12,
                                color: Colors.orange,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ],
                  ),
                ),
                SizedBox(height: 20),

                // Quick Actions
                Text(
                  "Quick Actions",
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    color: Colors.grey[800],
                  ),
                ),
                SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: _isProcessing ? null : _openScanner,
                        style: OutlinedButton.styleFrom(
                          padding: EdgeInsets.symmetric(vertical: 14),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(10),
                          ),
                          side: BorderSide(color: Colors.blue),
                        ),
                        icon: Icon(Icons.refresh, size: 18, color: Colors.blue),
                        label: Text(
                          "Scan Again",
                          style: TextStyle(color: Colors.blue),
                        ),
                      ),
                    ),
                    SizedBox(width: 12),
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: _isProcessing ? null : _manualBarcodeInput,
                        style: OutlinedButton.styleFrom(
                          padding: EdgeInsets.symmetric(vertical: 14),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(10),
                          ),
                          side: BorderSide(color: Colors.orange),
                        ),
                        icon: Icon(Icons.keyboard, size: 18, color: Colors.orange),
                        label: Text(
                          "Manual Input",
                          style: TextStyle(color: Colors.orange),
                        ),
                      ),
                    ),
                  ],
                ),
                SizedBox(height: 8),
                SizedBox(
                  width: double.infinity,
                  child: OutlinedButton.icon(
                    onPressed: _isProcessing ? null : _resetScanner,
                    style: OutlinedButton.styleFrom(
                      padding: EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                      side: BorderSide(color: Colors.grey),
                    ),
                    icon: Icon(Icons.restart_alt, size: 18, color: Colors.grey),
                    label: Text(
                      "Reset Scanner",
                      style: TextStyle(color: Colors.grey),
                    ),
                  ),
                ),

                // Tips Section
                SizedBox(height: 24),
                Container(
                  padding: EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.blue.shade50,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Row(
                    children: [
                      Icon(Icons.lightbulb_outline, color: Colors.blue, size: 20),
                      SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              "Scanning Tips",
                              style: TextStyle(
                                fontWeight: FontWeight.w600,
                                color: Colors.blue[800],
                              ),
                            ),
                            SizedBox(height: 4),
                            Text(
                              "Ensure good lighting and hold the phone steady",
                              style: TextStyle(
                                fontSize: 12,
                                color: Colors.blue[700],
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),

                // Skin Type Info Section
                SizedBox(height: 16),
                Container(
                  padding: EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.purple.shade50,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Row(
                    children: [
                      Icon(Icons.face_retouching_natural, color: Colors.purple, size: 20),
                      SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              "Skin Type Detection",
                              style: TextStyle(
                                fontWeight: FontWeight.w600,
                                color: Colors.purple[800],
                              ),
                            ),
                            SizedBox(height: 4),
                            Text(
                              "After scanning, we'll check if the product is suitable for your skin type",
                              style: TextStyle(
                                fontSize: 12,
                                color: Colors.purple[700],
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
// Add this method to go to skin analysis
  void _goToSkinAnalysis() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => SkinAnalysisPy(), // Make sure to import this
      ),
    ).then((value) {
      // When returning, update skin type
      if (value != null) {
        setState(() {});
      }
    });
  }

// Update _getUserSkinType to handle errors better
  Future<String?> _getUserSkinType() async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) return null;

      // مسار جديد: يتوافق مع مكان حفظ SkinTypeProvider للبيانات
      final ref = FirebaseDatabase.instance.ref('users/${user.uid}');
      final snapshot = await ref.get();

      if (snapshot.exists) {
        final data = Map<String, dynamic>.from(snapshot.value as Map);
        // جلب نوع البشرة من نفس المكان الذي يحفظ فيه SkinTypeProvider
        return data['skinType']?.toString().toLowerCase();
      }
      return null;
    } catch (e) {
      print("Error getting user skin type: $e");
      return null;
    }
  }

  Color _getBarcodeColor() {
    if (_isProcessing) return Colors.orange;
    if (scannedCode == "Not scanned yet") return Colors.grey;
    if (scannedCode == "Scan cancelled" || scannedCode.contains("Error")) return Colors.amber;
    return Colors.green;
  }
}