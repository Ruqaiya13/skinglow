// product_model.dart
class Product {
  final String id;
  final String name;
  final String brand;
  final double price;
  final double? originalPrice;
  final double? rating;
  final int? reviewCount;
  final String image;
  final List<String>? images;
  final String description;
  final String? detailedDescription;
  final List<String>? keyBenefits;
  final List<String>? ingredients;
  final String? ingredientsDescription;
  final List<String>? howToUse;
  final String? volume;
  final String? texture;
  final String? scent;
  final List<String> skinTypes;
  final List<String> skinProblems;
  final bool? crueltyFree;
  final bool? vegan;
  final bool? allergenFree;
  final bool? dermatologistTested;
  final String? countryOfOrigin;
  final String? availability;
  final String? shippingInfo;
  final String? returnPolicy;
  final DateTime createdAt;

  Product({
    required this.id,
    required this.name,
    required this.brand,
    required this.price,
    this.originalPrice,
    this.rating,
    this.reviewCount,
    required this.image,
    this.images,
    required this.description,
    this.detailedDescription,
    this.keyBenefits,
    this.ingredients,
    this.ingredientsDescription,
    this.howToUse,
    this.volume,
    this.texture,
    this.scent,
    required this.skinTypes,
    required this.skinProblems,
    this.crueltyFree,
    this.vegan,
    this.allergenFree,
    this.dermatologistTested,
    this.countryOfOrigin,
    this.availability,
    this.shippingInfo,
    this.returnPolicy,
    required this.createdAt,
  });

  // دالة مساعدة لتحويل التاريخ
  static DateTime _parseDateTime(dynamic dateString) {
    if (dateString == null) return DateTime.now();

    try {
      return DateTime.parse(dateString.toString());
    } catch (e) {
      print('Error parsing date: $dateString, using current time');
      return DateTime.now();
    }
  }

  // دالة مساعدة لتحويل القيم الرقمية
  static double _parseDouble(dynamic value) {
    if (value == null) return 0.0;
    if (value is double) return value;
    if (value is int) return value.toDouble();
    return double.tryParse(value.toString()) ?? 0.0;
  }

  // دالة مساعدة لتحويل الأعداد الصحيحة
  static int _parseInt(dynamic value) {
    if (value == null) return 0;
    if (value is int) return value;
    if (value is double) return value.toInt();
    return int.tryParse(value.toString()) ?? 0;
  }

  // دالة مساعدة لتحويل القيم المنطقية
  static bool _parseBool(dynamic value) {
    if (value == null) return false;
    if (value is bool) return value;
    if (value is int) return value == 1;
    if (value is String) return value.toLowerCase() == 'true';
    return false;
  }

  // دالة fromJson المفقودة - أضف هذا
  factory Product.fromJson(Map<String, dynamic> json) {
    return Product(
      id: json['id']?.toString() ?? '',
      name: json['name']?.toString() ?? '',
      brand: json['brand']?.toString() ?? '',
      price: _parseDouble(json['price']),
      originalPrice: _parseDouble(json['originalPrice']),
      rating: _parseDouble(json['rating']),
      reviewCount: _parseInt(json['reviewCount']),
      image: json['image']?.toString() ?? '',
      images: json['images'] != null ? List<String>.from(json['images']) : [],
      description: json['description']?.toString() ?? '',
      detailedDescription: json['detailedDescription']?.toString(),
      keyBenefits: json['keyBenefits'] != null ? List<String>.from(json['keyBenefits']) : [],
      ingredients: json['ingredients'] != null ? List<String>.from(json['ingredients']) : [],
      ingredientsDescription: json['ingredientsDescription']?.toString(),
      howToUse: json['howToUse'] != null ? List<String>.from(json['howToUse']) : [],
      volume: json['volume']?.toString(),
      texture: json['texture']?.toString(),
      scent: json['scent']?.toString(),
      skinTypes: json['skinTypes'] != null ? List<String>.from(json['skinTypes']) : [],
      skinProblems: json['skinProblems'] != null ? List<String>.from(json['skinProblems']) : [],
      crueltyFree: _parseBool(json['crueltyFree']),
      vegan: _parseBool(json['vegan']),
      allergenFree: _parseBool(json['allergenFree']),
      dermatologistTested: _parseBool(json['dermatologistTested']),
      countryOfOrigin: json['countryOfOrigin']?.toString(),
      availability: json['availability']?.toString(),
      shippingInfo: json['shippingInfo']?.toString(),
      returnPolicy: json['returnPolicy']?.toString(),
      createdAt: _parseDateTime(json['createdAt']),
    );
  }

  // دالة toJson
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'brand': brand,
      'price': price,
      'originalPrice': originalPrice ?? 0.0,
      'rating': rating ?? 0.0,
      'reviewCount': reviewCount ?? 0,
      'image': image,
      'images': images ?? [],
      'description': description,
      'detailedDescription': detailedDescription ?? '',
      'keyBenefits': keyBenefits ?? [],
      'ingredients': ingredients ?? [],
      'ingredientsDescription': ingredientsDescription ?? '',
      'howToUse': howToUse ?? [],
      'volume': volume ?? '',
      'texture': texture ?? '',
      'scent': scent ?? '',
      'skinTypes': skinTypes,
      'skinProblems': skinProblems,
      'crueltyFree': crueltyFree ?? false,
      'vegan': vegan ?? false,
      'allergenFree': allergenFree ?? false,
      'dermatologistTested': dermatologistTested ?? false,
      'countryOfOrigin': countryOfOrigin ?? 'South Korea',
      'availability': availability ?? 'In Stock',
      'shippingInfo': shippingInfo ?? 'Free shipping on orders over \$35',
      'returnPolicy': returnPolicy ?? '30-day return policy',
      'createdAt': createdAt.toIso8601String(),
    };
  }

  // دالة copyWith
  Product copyWith({
    String? id,
    String? name,
    String? brand,
    double? price,
    double? originalPrice,
    double? rating,
    int? reviewCount,
    String? image,
    List<String>? images,
    String? description,
    String? detailedDescription,
    List<String>? keyBenefits,
    List<String>? ingredients,
    String? ingredientsDescription,
    List<String>? howToUse,
    String? volume,
    String? texture,
    String? scent,
    List<String>? skinTypes,
    List<String>? skinProblems,
    bool? crueltyFree,
    bool? vegan,
    bool? allergenFree,
    bool? dermatologistTested,
    String? countryOfOrigin,
    String? availability,
    String? shippingInfo,
    String? returnPolicy,
    DateTime? createdAt,
  }) {
    return Product(
      id: id ?? this.id,
      name: name ?? this.name,
      brand: brand ?? this.brand,
      price: price ?? this.price,
      originalPrice: originalPrice ?? this.originalPrice,
      rating: rating ?? this.rating,
      reviewCount: reviewCount ?? this.reviewCount,
      image: image ?? this.image,
      images: images ?? this.images,
      description: description ?? this.description,
      detailedDescription: detailedDescription ?? this.detailedDescription,
      keyBenefits: keyBenefits ?? this.keyBenefits,
      ingredients: ingredients ?? this.ingredients,
      ingredientsDescription: ingredientsDescription ?? this.ingredientsDescription,
      howToUse: howToUse ?? this.howToUse,
      volume: volume ?? this.volume,
      texture: texture ?? this.texture,
      scent: scent ?? this.scent,
      skinTypes: skinTypes ?? this.skinTypes,
      skinProblems: skinProblems ?? this.skinProblems,
      crueltyFree: crueltyFree ?? this.crueltyFree,
      vegan: vegan ?? this.vegan,
      allergenFree: allergenFree ?? this.allergenFree,
      dermatologistTested: dermatologistTested ?? this.dermatologistTested,
      countryOfOrigin: countryOfOrigin ?? this.countryOfOrigin,
      availability: availability ?? this.availability,
      shippingInfo: shippingInfo ?? this.shippingInfo,
      returnPolicy: returnPolicy ?? this.returnPolicy,
      createdAt: createdAt ?? this.createdAt,
    );
  }
}
