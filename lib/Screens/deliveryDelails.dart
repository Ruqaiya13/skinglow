import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_database/firebase_database.dart';
import 'Account_Information.dart';

class DeliveryDetailsPage extends StatefulWidget {
  @override
  _DeliveryDetailsPageState createState() => _DeliveryDetailsPageState();
}

class _DeliveryDetailsPageState extends State<DeliveryDetailsPage> {
  final User? user = FirebaseAuth.instance.currentUser;
  final DatabaseReference _databaseRef =
  FirebaseDatabase.instance.ref().child('users');

  final _formKey = GlobalKey<FormState>();

  TextEditingController _addressController = TextEditingController();
  TextEditingController _zipCodeController = TextEditingController();
  bool _isLoading = true;
  String _userName = '';
  String _userPhone = '';

  final List<String> _omanStates = [
    'Muscat',
    'Dhofar',
    'North Al Batinah',
    'South Al Batinah',
    'Al Dhahirah',
    'Al Dakhiliyah',
    'South Al Sharqiyah',
    'North Al Sharqiyah',
    'Al Wusta',
    'Musandam',
    'Al Buraimi'
  ];

  final Map<String, List<String>> _citiesByState = {
    'Muscat': ['Muscat', 'Mutrah', 'Al Seeb', 'Bausher', 'Al Amerat', 'Qurayyat'],
    'Dhofar': ['Salalah', 'Taqah', 'Mirbat', 'Thumrait', 'Dalkut', 'Muqshin'],
    'North Al Batinah': ['Sohar', 'Shinas', 'Liwa', 'Saham', 'Al Suwaiq', 'Al Khaburah'],
    'South Al Batinah': ['Rustaq', 'Al Awabi', 'Nakhl', 'Wadi Al Maawil', 'Barka', 'Al Musannah'],
    'Al Dhahirah': ['Ibri', 'Yanqul', 'Dhank', 'Al Buraimi'],
    'Al Dakhiliyah': ['Nizwa', 'Bahla', 'Manah', 'Al Hamra', 'Adam', 'Samail', 'Bidbid'],
    'South Al Sharqiyah': ['Sur', 'Jaalan Bani Bu Hassan', 'Jaalan Bani Bu Ali', 'Al Kamil WAl Wafi', 'Masirah'],
    'North Al Sharqiyah': ['Ibra', 'Al Mudhaibi', 'Bidiyah', 'Al Qabil', 'Wadi Bani Khalid'],
    'Al Wusta': ['Haima', 'Mahout', 'Al Duqm', 'Al Jazer'],
    'Musandam': ['Khasab', 'Bukha', 'Diba', 'Madha'],
    'Al Buraimi': ['Al Buraimi', 'Mahdah', 'Al Sunaynah'],
  };

  String? _selectedState;
  String? _selectedCity;
  List<String> _availableCities = [];

  @override
  void initState() {
    super.initState();
    _loadUserData();
  }

  Future<void> _loadUserData() async {
    if (user == null) {
      setState(() => _isLoading = false);
      return;
    }

    try {
      final userSnapshot = await _databaseRef.child(user!.uid).get();

      if (userSnapshot.exists) {
        final userData = userSnapshot.value as Map<dynamic, dynamic>;
        setState(() {
          _userName = userData['name']?.toString() ?? 'No Name';
          _userPhone = _findPhoneNumber(userData);
        });
      }

      final deliverySnapshot =
      await _databaseRef.child(user!.uid).child('deliveryDetails').get();

      if (deliverySnapshot.exists) {
        final data = deliverySnapshot.value as Map<dynamic, dynamic>;
        setState(() {
          _addressController.text = data['address']?.toString() ?? '';
          _selectedState = data['state']?.toString();
          _selectedCity = data['city']?.toString();
          _zipCodeController.text = data['zipCode']?.toString() ?? '';

          if (_selectedState != null &&
              _citiesByState.containsKey(_selectedState)) {
            _availableCities = _citiesByState[_selectedState]!;
          } else {
            _availableCities = [];
          }

          // ✅ Fix: validate selected values to prevent dropdown errors
          if (!_omanStates.contains(_selectedState)) _selectedState = null;
          if (!_availableCities.contains(_selectedCity)) _selectedCity = null;
        });
      } else {
        setState(() => _availableCities = []);
      }
    } catch (e) {
      setState(() => _availableCities = []);
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  String _findPhoneNumber(Map<dynamic, dynamic> userData) {
    List<String> fields = [
      'phone',
      'mobilePhoneNumber',
      'phoneNumber',
      'mobile',
      'contact',
      'telephone',
      'number'
    ];
    for (String f in fields) {
      if (userData.containsKey(f) &&
          userData[f] != null &&
          userData[f].toString().isNotEmpty) return userData[f].toString();
    }
    return '';
  }

  void _updateCities(String? state) {
    setState(() {
      _selectedState = state;
      _selectedCity = null;
      _availableCities = state != null ? (_citiesByState[state] ?? []) : [];
    });
  }

  Future<void> _saveDeliveryDetails() async {
    if (_formKey.currentState!.validate()) {
      if (user == null) return;
      if (_userPhone.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
              content: Text('Please add phone number to your profile first'),
              backgroundColor: Colors.orange),
        );
        return;
      }
      if (_selectedState == null || _selectedCity == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
              content: Text('Please select both state and city'),
              backgroundColor: Colors.orange),
        );
        return;
      }

      setState(() => _isLoading = true);
      try {
        await _databaseRef.child(user!.uid).child('deliveryDetails').set({
          'fullName': _userName,
          'phone': _userPhone,
          'address': _addressController.text,
          'state': _selectedState,
          'city': _selectedCity,
          'zipCode': _zipCodeController.text,
          'lastUpdated': ServerValue.timestamp,
        });

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(SnackBar(
            content: Text('Delivery details saved successfully!'),
            backgroundColor: Colors.green,
          ));
          Navigator.pop(context);
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(SnackBar(
            content: Text('Failed to save delivery details: $e'),
            backgroundColor: Colors.red,
          ));
        }
      } finally {
        if (mounted) setState(() => _isLoading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Delivery Details',
            style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
        backgroundColor: Color(0xFF914D74),
        iconTheme: IconThemeData(color: Colors.white),
      ),
      body: _isLoading
          ? Center(
        child: CircularProgressIndicator(
            valueColor:
            AlwaysStoppedAnimation<Color>(Color(0xFF914D74))),
      )
          : Padding(
        padding: const EdgeInsets.all(16.0),
        child: Form(
            key: _formKey,
            child: ListView(children: [
              // User info
              Card(
                  elevation: 2,
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12)),
                  child: ListTile(
                    leading: Icon(Icons.person, color: Color(0xFF914D74)),
                    title: Text('Full Name',
                        style:
                        TextStyle(fontSize: 12, color: Colors.grey)),
                    subtitle: Text(_userName,
                        style: TextStyle(
                            fontSize: 16, fontWeight: FontWeight.w500)),
                  )),
              SizedBox(height: 16),
              Card(
                  elevation: 2,
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12)),
                  child: ListTile(
                      leading: Icon(Icons.phone, color: Color(0xFF914D74)),
                      title: Text('Phone Number',
                          style: TextStyle(
                              fontSize: 12, color: Colors.grey)),
                      subtitle: Text(
                          _userPhone.isNotEmpty
                              ? _userPhone
                              : 'Not set',
                          style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w500,
                              color: _userPhone.isEmpty
                                  ? Colors.red
                                  : Colors.black)),
                      trailing: _userPhone.isEmpty
                          ? IconButton(
                          icon: Icon(Icons.edit, color: Colors.orange),
                          onPressed: () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                  builder: (context) =>
                                      AccountInformationPage()),
                            ).then((_) => _loadUserData());
                          })
                          : null)),
              SizedBox(height: 16),

              TextFormField(
                  controller: _addressController,
                  decoration: InputDecoration(
                    labelText: 'Address',
                    border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8)),
                    prefixIcon:
                    Icon(Icons.location_on, color: Color(0xFF914D74)),
                  ),
                  maxLines: 2,
                  validator: (v) =>
                  (v == null || v.isEmpty) ? 'Please enter address' : null),
              SizedBox(height: 16),

              // ✅ Fixed Dropdowns
              DropdownButtonFormField<String>(
                value: _omanStates.contains(_selectedState)
                    ? _selectedState
                    : null,
                decoration: InputDecoration(
                  labelText: 'State',
                  border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8)),
                  prefixIcon: Icon(Icons.map, color: Color(0xFF914D74)),
                ),
                items: _omanStates
                    .map((s) =>
                    DropdownMenuItem<String>(value: s, child: Text(s)))
                    .toList(),
                onChanged: _updateCities,
                validator: (v) =>
                (v == null || v.isEmpty) ? 'Please select state' : null,
              ),
              SizedBox(height: 16),

              DropdownButtonFormField<String>(
                value: _availableCities.contains(_selectedCity)
                    ? _selectedCity
                    : null,
                decoration: InputDecoration(
                  labelText: 'City',
                  border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8)),
                  prefixIcon:
                  Icon(Icons.location_city, color: Color(0xFF914D74)),
                  hintText:
                  _availableCities.isEmpty ? 'Select state first' : null,
                ),
                items: _availableCities
                    .map((c) =>
                    DropdownMenuItem<String>(value: c, child: Text(c)))
                    .toList(),
                onChanged: _availableCities.isNotEmpty
                    ? (String? newValue) {
                  setState(() => _selectedCity = newValue);
                }
                    : null,
                validator: (v) => (_availableCities.isNotEmpty &&
                    (v == null || v.isEmpty))
                    ? 'Please select your city'
                    : null,
              ),
              SizedBox(height: 16),

              TextFormField(
                  controller: _zipCodeController,
                  decoration: InputDecoration(
                      labelText: 'ZIP Code',
                      border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(8)),
                      prefixIcon:
                      Icon(Icons.numbers, color: Color(0xFF914D74))),
                  keyboardType: TextInputType.number,
                  validator: (v) =>
                  (v == null || v.isEmpty) ? 'Please enter ZIP code' : null),
              SizedBox(height: 24),

              ElevatedButton(
                  onPressed:
                  (_isLoading || _userPhone.isEmpty) ? null : _saveDeliveryDetails,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Color(0xFF914D74),
                    foregroundColor: Colors.white,
                    minimumSize: Size(double.infinity, 50),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12)),
                  ),
                  child: Text('Save Delivery Details',
                      style: TextStyle(
                          fontSize: 16, fontWeight: FontWeight.bold)))
            ])),
      ),
    );
  }

  @override
  void dispose() {
    _addressController.dispose();
    _zipCodeController.dispose();
    super.dispose();
  }
}
