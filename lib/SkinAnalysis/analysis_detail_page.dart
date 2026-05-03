
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:skinglow/SkinAnalysis/skin_analysis.dart';

import 'analysis_history_service.dart';

class AnalysisDetailPage extends StatelessWidget {
  final SkinAnalysis analysis;
  final AnalysisHistoryService _historyService = AnalysisHistoryService();

  AnalysisDetailPage({Key? key, required this.analysis}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Analysis Details'),
        actions: [
          IconButton(
            icon: Icon(Icons.delete_outline),
            onPressed: () => _confirmDelete(context),
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // الصورة
            if (analysis.imageBase64 != null)
              Center(
                child: Container(
                  width: 200,
                  height: 200,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(16),
                    image: DecorationImage(
                      image: MemoryImage(base64Decode(analysis.imageBase64!)),
                      fit: BoxFit.cover,
                    ),
                  ),
                ),
              ),
            SizedBox(height: 20),

            // المعلومات الأساسية
            Card(
              child: Padding(
                padding: EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildInfoRow(Icons.calendar_today, 'Date',
                        DateFormat('MMMM dd, yyyy - HH:mm').format(analysis.date)),
                    _buildInfoRow(Icons.face, 'Skin Type', analysis.skinType),
                    _buildInfoRow(Icons.location_on, 'Area', analysis.targetArea),
                    _buildInfoRow(Icons.verified, 'Confidence',
                        '${(analysis.confidence * 100).toStringAsFixed(1)}%'),
                  ],
                ),
              ),
            ),

            SizedBox(height: 20),

            // المشاكل
            if (analysis.problems.isNotEmpty)
              Card(
                child: Padding(
                  padding: EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Detected Issues',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      SizedBox(height: 12),
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: analysis.problems.map((problem) {
                          return Chip(
                            label: Text(problem),
                            backgroundColor: _getProblemColor(problem),
                          );
                        }).toList(),
                      ),
                    ],
                  ),
                ),
              ),

            SizedBox(height: 20),

            // التوصيات
            if (analysis.productRecommendations.isNotEmpty)
              Card(
                child: Padding(
                  padding: EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Recommended Products',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      SizedBox(height: 12),
                      ...analysis.productRecommendations.map((product) {
                        return ListTile(
                          leading: Icon(Icons.check_circle, color: Colors.green),
                          title: Text(product),
                        );
                      }).toList(),
                    ],
                  ),
                ),
              ),

            SizedBox(height: 20),

            // البيانات الوصفية
            if (analysis.metadata.isNotEmpty)
              Card(
                child: Padding(
                  padding: EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Analysis Details',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      SizedBox(height: 12),
                      ...analysis.metadata.entries.map((entry) {
                        return _buildInfoRow(
                          Icons.info_outline,
                          entry.key,
                          entry.value.toString(),
                        );
                      }).toList(),
                    ],
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildInfoRow(IconData icon, String label, String value) {
    return Padding(
      padding: EdgeInsets.symmetric(vertical: 8),
      child: Row(
        children: [
          Icon(icon, color: Colors.blue, size: 20),
          SizedBox(width: 12),
          Expanded(
            child: Text(
              label,
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
          ),
          Expanded(
            child: Text(
              value,
              textAlign: TextAlign.end,
            ),
          ),
        ],
      ),
    );
  }

  Color _getProblemColor(String problem) {
    final colors = {
      'acne': Colors.red[100]!,
      'dryness': Colors.blue[100]!,
      'oiliness': Colors.amber[100]!,
      'wrinkles': Colors.purple[100]!,
      'sensitivity': Colors.pink[100]!,
    };
    return colors[problem] ?? Colors.grey[100]!;
  }

  Future<void> _confirmDelete(BuildContext context) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('Delete Analysis'),
        content: Text('Are you sure you want to delete this analysis?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: Text(
              'Delete',
              style: TextStyle(color: Colors.red),
            ),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      try {
        await _historyService.deleteAnalysis(analysis.id);
        Navigator.pop(context);
      } catch (e) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to delete: $e')),
        );
      }
    }
  }
}