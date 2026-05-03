// smart_recommendations_screen.dart
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:skinglow/SkinAnalysis/skin_analysis.dart';
import '../SkinAnalysis/analysis_history_service.dart';

class SmartRecommendationsScreen extends StatefulWidget {
  @override
  _SmartRecommendationsScreenState createState() => _SmartRecommendationsScreenState();
}

class _SmartRecommendationsScreenState extends State<SmartRecommendationsScreen> {
  final AnalysisHistoryService _historyService = AnalysisHistoryService();
  List<String> _recommendations = [];
  List<SkinAnalysis> _recentAnalyses = [];
  bool _isLoading = true;
  String _skinTypeTrend = 'stable';

  @override
  void initState() {
    super.initState();
    _loadRecommendations();
  }

  Future<void> _loadRecommendations() async {
    setState(() => _isLoading = true);
    try {
      // Get smart recommendations
      _recommendations = await _historyService.getPersonalizedRecommendations();

      // Get recent analyses
      final allAnalyses = await _historyService.getAllAnalyses();
      _recentAnalyses = allAnalyses.take(3).toList();

      // Analyze trend
      if (_recentAnalyses.length >= 2) {
        final firstType = _recentAnalyses.last.skinType;
        final lastType = _recentAnalyses.first.skinType;
        _skinTypeTrend = firstType == lastType ? 'stable' : 'changing';
      }

    } catch (e) {
      print('❌ Error loading recommendations: $e');
      _recommendations = [
        'Use a gentle cleanser suitable for your skin type',
        'Apply sunscreen daily',
        'Consult a dermatologist for accurate assessment',
      ];
    } finally {
      setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Smart Recommendations'),
        actions: [
          IconButton(
            icon: Icon(Icons.refresh),
            onPressed: _loadRecommendations,
            tooltip: 'Update Recommendations',
          ),
        ],
      ),
      body: _isLoading
          ? Center(child: CircularProgressIndicator())
          : _buildRecommendations(),
    );
  }

  Widget _buildRecommendations() {
    return SingleChildScrollView(
      padding: EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Progress Summary
          _buildProgressSummary(),

          SizedBox(height: 24),

          // Main Recommendations
          Text(
            '🎯 Personalized Recommendations For You',
            style: TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.bold,
              color: Colors.blue[800],
            ),
          ),

          SizedBox(height: 16),

          // Recommendations List
          ..._recommendations.asMap().entries.map((entry) {
            final index = entry.key;
            final recommendation = entry.value;

            return Card(
              margin: EdgeInsets.only(bottom: 12),
              child: ListTile(
                leading: CircleAvatar(
                  backgroundColor: _getPriorityColor(index),
                  child: Text('${index + 1}'),
                ),
                title: Text(recommendation),
                subtitle: _getRecommendationSubtitle(index),
                trailing: Icon(_getRecommendationIcon(index)),
              ),
            );
          }).toList(),

          SizedBox(height: 24),

          // General Tips
          _buildGeneralTips(),

          SizedBox(height: 24),

          // New Analysis Button
          ElevatedButton.icon(
            onPressed: () {
              Navigator.pop(context);
              // Return to analysis screen
            },
            icon: Icon(Icons.camera_alt),
            label: Text('New Analysis to Update Recommendations'),
            style: ElevatedButton.styleFrom(
              minimumSize: Size(double.infinity, 50),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildProgressSummary() {
    if (_recentAnalyses.isEmpty) return SizedBox();

    final latest = _recentAnalyses.first;
    final total = _recentAnalyses.length;

    return Card(
      child: Padding(
        padding: EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                CircleAvatar(
                  backgroundColor: _getSkinTypeColor(latest.skinType),
                  child: Text(latest.skinType[0]),
                ),
                SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Latest Analysis',
                        style: TextStyle(color: Colors.grey),
                      ),
                      Text(
                        latest.skinType,
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                ),
                Chip(
                  label: Text('$total analyses'),
                  backgroundColor: Colors.blue[50],
                ),
              ],
            ),

            SizedBox(height: 12),

            if (_skinTypeTrend == 'changing' && _recentAnalyses.length >= 2)
              Container(
                padding: EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.amber[50],
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  children: [
                    Icon(Icons.trending_up, color: Colors.amber),
                    SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'Your skin type is changing! From ${_recentAnalyses.last.skinType} to ${_recentAnalyses.first.skinType}',
                        style: TextStyle(color: Colors.amber[800]),
                      ),
                    ),
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildGeneralTips() {
    return Card(
      child: Padding(
        padding: EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '💡 Tips for Continuous Care',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
            SizedBox(height: 12),
            _buildTipItem('Regular Analysis', 'Analyze your skin every two weeks to track changes'),
            _buildTipItem('Reference Photos', 'Keep photos with same angles and lighting'),
            _buildTipItem('Product Logging', 'Record products you use and their effects'),
            _buildTipItem('Environmental Conditions', 'Notice weather and climate impact on your skin'),
          ],
        ),
      ),
    );
  }

  Widget _buildTipItem(String title, String description) {
    return Padding(
      padding: EdgeInsets.symmetric(vertical: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Icons.check_circle, size: 20, color: Colors.green),
          SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: TextStyle(fontWeight: FontWeight.bold),
                ),
                SizedBox(height: 4),
                Text(
                  description,
                  style: TextStyle(color: Colors.grey[600]),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Color _getPriorityColor(int index) {
    if (index == 0) return Colors.red;
    if (index == 1) return Colors.orange;
    if (index == 2) return Colors.blue;
    return Colors.grey;
  }

  Widget? _getRecommendationSubtitle(int index) {
    if (index == 0) {
      return Text('High priority - Start with this');
    } else if (index == 1) {
      return Text('Medium priority - Important for improvement');
    }
    return null;
  }

  IconData _getRecommendationIcon(int index) {
    if (index == 0) return Icons.priority_high;
    if (index == 1) return Icons.schedule;
    return Icons.check_circle_outline;
  }

  Color _getSkinTypeColor(String skinType) {
    switch (skinType.toLowerCase()) {
      case 'oily': return Colors.blue;
      case 'dry': return Colors.amber;
      case 'combination': return Colors.green;
      default: return Colors.grey;
    }
  }
}