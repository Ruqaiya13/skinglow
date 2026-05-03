import 'package:json_annotation/json_annotation.dart';

@JsonSerializable()
class SkinAnalysis {
  final String id;
  final DateTime date;
  final String skinType;
  final Map<String, double> concerns; // {acne: 0.8, dryness: 0.6, wrinkles: 0.3}
  final double confidence;
  final List<String> problems;
  final String? imageUrl;
  final String? imageBase64;
  final List<String> productRecommendations;
  final Map<String, dynamic> metadata;
  final String targetArea; // Front, Right cheek, Left cheek, Nose, Chin

  SkinAnalysis({
    required this.id,
    required this.date,
    required this.skinType,
    required this.concerns,
    required this.confidence,
    required this.problems,
    this.imageUrl,
    this.imageBase64,
    required this.productRecommendations,
    this.metadata = const {},
    required this.targetArea,
  });

  factory SkinAnalysis.fromJson(Map<String, dynamic> json) =>
      _$SkinAnalysisFromJson(json);

  Map<String, dynamic> toJson() => _$SkinAnalysisToJson(this);
}

@JsonSerializable()
class AnalysisComparison {
  final SkinAnalysis currentAnalysis;
  final SkinAnalysis? previousAnalysis;
  final Map<String, double> improvements; // {acne: 0.2, dryness: -0.1}
  final String summary;
  final bool hasImproved;
  final List<String> recommendedActions;

  AnalysisComparison({
    required this.currentAnalysis,
    this.previousAnalysis,
    required this.improvements,
    required this.summary,
    required this.hasImproved,
    required this.recommendedActions,
  });

  factory AnalysisComparison.fromJson(Map<String, dynamic> json) =>
      _$AnalysisComparisonFromJson(json);

  Map<String, dynamic> toJson() => _$AnalysisComparisonToJson(this);
}

@JsonSerializable()
class SkinAnalysisHistory {
  final List<SkinAnalysis> analyses;
  final Map<String, List<double>> trendData; // {acne: [0.8, 0.7, 0.6]}
  final String dominantSkinType;
  final DateTime firstAnalysis;
  final DateTime lastAnalysis;
  final int totalAnalyses;

  SkinAnalysisHistory({
    required this.analyses,
    required this.trendData,
    required this.dominantSkinType,
    required this.firstAnalysis,
    required this.lastAnalysis,
    required this.totalAnalyses,
  });

  factory SkinAnalysisHistory.fromJson(Map<String, dynamic> json) =>
      _$SkinAnalysisHistoryFromJson(json);

  Map<String, dynamic> toJson() => _$SkinAnalysisHistoryToJson(this);
}
// GENERATED CODE - DO NOT MODIFY BY HAND



// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

SkinAnalysis _$SkinAnalysisFromJson(Map<String, dynamic> json) => SkinAnalysis(
  id: json['id'] as String,
  date: DateTime.parse(json['date'] as String),
  skinType: json['skinType'] as String,
  concerns: (json['concerns'] as Map<String, dynamic>).map(
        (k, e) => MapEntry(k, (e as num).toDouble()),
  ),
  confidence: (json['confidence'] as num).toDouble(),
  problems: (json['problems'] as List<dynamic>)
      .map((e) => e as String)
      .toList(),
  imageUrl: json['imageUrl'] as String?,
  imageBase64: json['imageBase64'] as String?,
  productRecommendations: (json['productRecommendations'] as List<dynamic>)
      .map((e) => e as String)
      .toList(),
  metadata: Map<String, dynamic>.from(json['metadata'] as Map),
  targetArea: json['targetArea'] as String,
);

Map<String, dynamic> _$SkinAnalysisToJson(SkinAnalysis instance) =>
    <String, dynamic>{
      'id': instance.id,
      'date': instance.date.toIso8601String(),
      'skinType': instance.skinType,
      'concerns': instance.concerns,
      'confidence': instance.confidence,
      'problems': instance.problems,
      'imageUrl': instance.imageUrl,
      'imageBase64': instance.imageBase64,
      'productRecommendations': instance.productRecommendations,
      'metadata': instance.metadata,
      'targetArea': instance.targetArea,
    };

AnalysisComparison _$AnalysisComparisonFromJson(Map<String, dynamic> json) =>
    AnalysisComparison(
      currentAnalysis:
      SkinAnalysis.fromJson(json['currentAnalysis'] as Map<String, dynamic>),
      previousAnalysis: json['previousAnalysis'] == null
          ? null
          : SkinAnalysis.fromJson(
          json['previousAnalysis'] as Map<String, dynamic>),
      improvements: (json['improvements'] as Map<String, dynamic>).map(
            (k, e) => MapEntry(k, (e as num).toDouble()),
      ),
      summary: json['summary'] as String,
      hasImproved: json['hasImproved'] as bool,
      recommendedActions: (json['recommendedActions'] as List<dynamic>)
          .map((e) => e as String)
          .toList(),
    );

Map<String, dynamic> _$AnalysisComparisonToJson(AnalysisComparison instance) =>
    <String, dynamic>{
      'currentAnalysis': instance.currentAnalysis.toJson(),
      'previousAnalysis': instance.previousAnalysis?.toJson(),
      'improvements': instance.improvements,
      'summary': instance.summary,
      'hasImproved': instance.hasImproved,
      'recommendedActions': instance.recommendedActions,
    };

SkinAnalysisHistory _$SkinAnalysisHistoryFromJson(Map<String, dynamic> json) =>
    SkinAnalysisHistory(
      analyses: (json['analyses'] as List<dynamic>)
          .map((e) => SkinAnalysis.fromJson(e as Map<String, dynamic>))
          .toList(),
      trendData: (json['trendData'] as Map<String, dynamic>).map(
            (k, e) => MapEntry(
            k,
            (e as List<dynamic>)
                .map((e) => (e as num).toDouble())
                .toList()),
      ),
      dominantSkinType: json['dominantSkinType'] as String,
      firstAnalysis: DateTime.parse(json['firstAnalysis'] as String),
      lastAnalysis: DateTime.parse(json['lastAnalysis'] as String),
      totalAnalyses: json['totalAnalyses'] as int,
    );

Map<String, dynamic> _$SkinAnalysisHistoryToJson(
    SkinAnalysisHistory instance) =>
    <String, dynamic>{
      'analyses': instance.analyses.map((e) => e.toJson()).toList(),
      'trendData': instance.trendData,
      'dominantSkinType': instance.dominantSkinType,
      'firstAnalysis': instance.firstAnalysis.toIso8601String(),
      'lastAnalysis': instance.lastAnalysis.toIso8601String(),
      'totalAnalyses': instance.totalAnalyses,
    };