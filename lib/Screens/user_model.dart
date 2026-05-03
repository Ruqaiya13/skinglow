// models/user_model.dart
class UserModel {
  final String uid;
  final String name;
  final String email;
  final String mobilePhoneNumber;
  final String role;
  final bool isActive;
  final DateTime createdAt;
  final DateTime? lastLogin;
  final bool agreeToTerms;

  UserModel({
    required this.uid,
    required this.name,
    required this.email,
    required this.mobilePhoneNumber,
    required this.role,
    required this.isActive,
    required this.createdAt,
    this.lastLogin,
    required this.agreeToTerms,
  });

  factory UserModel.fromFirebase(Map<dynamic, dynamic> data, String uid) {
    print('🛠️ Creating UserModel from data: $data');

    // Handle different date formats
    DateTime parseDate(dynamic date) {
      if (date == null) return DateTime.now();
      if (date is int) return DateTime.fromMillisecondsSinceEpoch(date);
      if (date is String) {
        try {
          return DateTime.parse(date);
        } catch (e) {
          print('❌ Error parsing date: $date');
          return DateTime.now();
        }
      }
      return DateTime.now();
    }

    return UserModel(
      uid: uid,
      name: data['name']?.toString() ?? 'No Name',
      email: data['email']?.toString() ?? 'No Email',
      mobilePhoneNumber: data['mobilePhoneNumber']?.toString() ?? 'No Phone',
      role: data['role']?.toString() ?? 'user',
      isActive: data['isActive']?.toString() == 'true' || data['isActive'] == true,
      createdAt: parseDate(data['createdAt']),
      lastLogin: data['lastLogin'] != null ? parseDate(data['lastLogin']) : null,
      agreeToTerms: data['agreeToTerms']?.toString() == 'true' || data['agreeToTerms'] == true,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'uid': uid,
      'name': name,
      'email': email,
      'mobilePhoneNumber': mobilePhoneNumber,
      'role': role,
      'isActive': isActive,
      'createdAt': createdAt.toString(),
      'lastLogin': lastLogin?.toString(),
      'agreeToTerms': agreeToTerms,
    };
  }

  UserModel copyWith({
    String? name,
    String? email,
    String? mobilePhoneNumber,
    String? role,
    bool? isActive,
    DateTime? lastLogin,
  }) {
    return UserModel(
      uid: uid,
      name: name ?? this.name,
      email: email ?? this.email,
      mobilePhoneNumber: mobilePhoneNumber ?? this.mobilePhoneNumber,
      role: role ?? this.role,
      isActive: isActive ?? this.isActive,
      createdAt: createdAt,
      lastLogin: lastLogin ?? this.lastLogin,
      agreeToTerms: agreeToTerms,
    );
  }

  @override
  String toString() {
    return 'UserModel(uid: $uid, name: $name, email: $email, role: $role)';
  }
}