import 'package:firebase_database/firebase_database.dart';

class UserData {
  final String name;
  final String email;
  final String mobilePhoneNumber;
  final bool agreeToTerms;
  final String? profileImageBase64;

  UserData({
    required this.name,
    required this.email,
    required this.mobilePhoneNumber,
    required this.agreeToTerms,
    this.profileImageBase64,
  });

  Map<String, dynamic> toJson() => {
    'name': name,
    'email': email.toLowerCase(),
    'mobilePhoneNumber': mobilePhoneNumber,
    'agreeToTerms': agreeToTerms,
    'createdAt': ServerValue.timestamp,
    'profileImageBase64': profileImageBase64,
  };

  factory UserData.fromJson(Map<String, dynamic> json) => UserData(
    name: json['name'],
    email: json['email'],
    mobilePhoneNumber: json['mobilePhoneNumber'],
    agreeToTerms: json['agreeToTerms'],
    profileImageBase64: json['profileImageBase64'],
  );
}