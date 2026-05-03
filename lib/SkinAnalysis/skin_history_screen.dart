
import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:skinglow/SkinAnalysis/skin_analysis.dart';
import 'package:skinglow/SkinAnalysis/analysis_history_service.dart';
import 'package:skinglow/SkinAnalysis/analysis_detail_page.dart';


class SkinHistoryScreen extends StatefulWidget {
  @override
  _SkinHistoryScreenState createState() => _SkinHistoryScreenState();
}

class _SkinHistoryScreenState extends State<SkinHistoryScreen> {
  final AnalysisHistoryService _historyService = AnalysisHistoryService();
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseDatabase _database = FirebaseDatabase.instance;
  // استخدم var بدلاً من النوع المحدد
  List<SkinAnalysis> _allAnalyses = [];
  List<SkinAnalysis> _filteredAnalyses = [];
  bool _isLoading = true;
  String _selectedPeriod = 'All';
  String _selectedSkinType = 'All';
  String _selectedArea = 'All';
  Map<String, dynamic> _trendData = {};
  List<Map<String, dynamic>> _timelineEvents = [];

  // الفترات الزمنية
  final List<String> _periods = [
    'Last 7 days',
    'Last 30 days',
    'Last 3 months',
    'Last 6 months',
    'All'
  ];

  @override
  void initState() {
    super.initState();
    _loadAnalyses();
  }

  Future<void> _loadAnalyses() async {
    setState(() => _isLoading = true);
    try {
      final analyses = await _historyService.getAllAnalyses();

      setState(() {
        _allAnalyses = analyses;
        _filteredAnalyses = analyses;
      });

      await _calculateTrends();
      await _generateTimelineEvents();
    } catch (e) {
      print('❌ Error loading analyses: $e');
    } finally {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _calculateTrends() async {
    if (_allAnalyses.isEmpty) return;

    final Map<String, dynamic> trends = {
      'total': _allAnalyses.length,
      'firstDate': _allAnalyses.last.date,
      'lastDate': _allAnalyses.first.date,
      'skinTypeChanges': 0,
      'improvements': 0,
      'concernFrequency': {},
      'monthlyAverage': 0,
    };

    // حساب تغيرات نوع البشرة
    String previousType = '';
    for (int i = _allAnalyses.length - 1; i >= 0; i--) {
      if (i < _allAnalyses.length - 1) {
        if (_allAnalyses[i].skinType != previousType) {
          trends['skinTypeChanges']++;
        }
      }
      previousType = _allAnalyses[i].skinType;
    }

    // حساب تواتر المشكلات
    final Map<String, int> problemCount = {};
    for (var analysis in _allAnalyses) {
      for (var problem in analysis.problems) {
        problemCount[problem] = (problemCount[problem] ?? 0) + 1;
      }
    }
    trends['concernFrequency'] = problemCount;

    // حساب المتوسط الشهري
    if (_allAnalyses.length > 1) {
      final daysDiff = trends['lastDate'].difference(trends['firstDate']).inDays;
      final monthsDiff = daysDiff / 30.0;
      trends['monthlyAverage'] = _allAnalyses.length / (monthsDiff > 0 ? monthsDiff : 1);
    }

    setState(() {
      _trendData = trends;
    });
  }

  Future<void> _generateTimelineEvents() async {
    final List<Map<String, dynamic>> events = [];

    if (_allAnalyses.isEmpty) {
      _timelineEvents = events;
      return;
    }

    // ترتيب التحليلات من الأقدم إلى الأحدث للجداول الزمنية
    final sortedAnalyses = List<SkinAnalysis>.from(_allAnalyses);
    sortedAnalyses.sort((a, b) => a.date.compareTo(b.date));

    for (int i = 0; i < sortedAnalyses.length; i++) {
      final analysis = sortedAnalyses[i];

      // حدث التحليل
      events.add({
        'date': analysis.date,
        'title': 'Skin Analysis',
        'description': '${analysis.skinType} skin detected',
        'icon': Icons.face_retouching_natural,
        'color': _getSkinTypeColor(analysis.skinType),
        'analysis': analysis,
      });

      // إذا كان هناك تغيير في نوع البشرة
      if (i > 0 && sortedAnalyses[i].skinType != sortedAnalyses[i-1].skinType) {
        events.add({
          'date': analysis.date,
          'title': 'Skin Type Change',
          'description': 'Changed from ${sortedAnalyses[i-1].skinType} to ${analysis.skinType}',
          'icon': Icons.change_circle,
          'color': Colors.amber,
          'type': 'change',
        });
      }

      // إذا ظهرت مشكلة جديدة
      if (i > 0) {
        final newProblems = analysis.problems
            .where((problem) => !sortedAnalyses[i-1].problems.contains(problem))
            .toList();

        for (var problem in newProblems) {
          events.add({
            'date': analysis.date,
            'title': 'New Concern',
            'description': 'Started experiencing $problem',
            'icon': Icons.warning,
            'color': Colors.orange,
            'type': 'concern',
          });
        }

        // إذا اختفت مشكلة
        final resolvedProblems = sortedAnalyses[i-1].problems
            .where((problem) => !analysis.problems.contains(problem))
            .toList();

        for (var problem in resolvedProblems) {
          events.add({
            'date': analysis.date,
            'title': 'Concern Resolved',
            'description': '$problem has improved',
            'icon': Icons.check_circle,
            'color': Colors.green,
            'type': 'resolution',
          });
        }
      }
    }

    // إضافة حدث أول تحليل
    if (sortedAnalyses.isNotEmpty) {
      final firstAnalysis = sortedAnalyses.first;
      events.insert(0, {
        'date': firstAnalysis.date,
        'title': 'First Analysis',
        'description': 'Started tracking skin health',
        'icon': Icons.star,
        'color': Colors.blue,
        'type': 'milestone',
      });
    }

    setState(() {
      _timelineEvents = events;
    });
  }

  void _applyFilters() {
    List<SkinAnalysis> filtered = _allAnalyses;

    // فلترة حسب الفترة الزمنية
    final now = DateTime.now();
    if (_selectedPeriod != 'All') {
      Duration duration;
      switch (_selectedPeriod) {
        case 'Last 7 days':
          duration = Duration(days: 7);
          break;
        case 'Last 30 days':
          duration = Duration(days: 30);
          break;
        case 'Last 3 months':
          duration = Duration(days: 90);
          break;
        case 'Last 6 months':
          duration = Duration(days: 180);
          break;
        default:
          duration = Duration(days: 36500); // ~100 years
      }

      final cutoffDate = now.subtract(duration);
      filtered = filtered.where((a) => a.date.isAfter(cutoffDate)).toList();
    }

    // فلترة حسب نوع البشرة
    if (_selectedSkinType != 'All') {
      filtered = filtered.where((a) =>
      a.skinType.toLowerCase() == _selectedSkinType.toLowerCase()).toList();
    }

    // فلترة حسب المنطقة
    if (_selectedArea != 'All') {
      filtered = filtered.where((a) =>
      a.targetArea == _selectedArea).toList();
    }

    setState(() {
      _filteredAnalyses = filtered;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Skin History Timeline'),
        actions: [
          IconButton(
            icon: Icon(Icons.refresh),
            onPressed: _loadAnalyses,
            tooltip: 'Refresh',
          ),
          IconButton(
            icon: Icon(Icons.filter_alt),
            onPressed: _showFilters,
            tooltip: 'Filter',
          ),
        ],
      ),
      body: _isLoading
          ? Center(child: CircularProgressIndicator())
          : _allAnalyses.isEmpty
          ? _buildEmptyState()
          : _buildHistoryContent(),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.history_toggle_off, size: 100, color: Colors.grey[300]),
          SizedBox(height: 20),
          Text(
            'No History Yet',
            style: TextStyle(fontSize: 24, color: Colors.grey),
          ),
          SizedBox(height: 10),
          Text(
            'Start analyzing your skin to build your history',
            textAlign: TextAlign.center,
            style: TextStyle(color: Colors.grey[600]),
          ),
          SizedBox(height: 30),
          ElevatedButton.icon(
            onPressed: () {
              Navigator.pop(context);
            },
            icon: Icon(Icons.camera_alt),
            label: Text('Start First Analysis'),
          ),
        ],
      ),
    );
  }

  Widget _buildHistoryContent() {
    return SingleChildScrollView(
      padding: EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // إحصائيات سريعة
          _buildQuickStats(),

          SizedBox(height: 20),

          // فلاتر سريعة
          _buildQuickFilters(),

          SizedBox(height: 20),

          // الجدول الزمني الرئيسي
          _buildTimeline(),

          SizedBox(height: 20),

          // تحليل الاتجاهات
          _buildTrendsAnalysis(),

          SizedBox(height: 20),

          // قائمة التحليلات المفصلة
          _buildAnalysesList(),
        ],
      ),
    );
  }

  Widget _buildQuickStats() {
    return Card(
      child: Padding(
        padding: EdgeInsets.all(16),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceAround,
          children: [
            _buildStatItem(
              Icons.analytics,
              'Total Analyses',
              '${_allAnalyses.length}',
              Colors.blue,
            ),
            _buildStatItem(
              Icons.timeline,
              'Monthly Avg',
              '${(_trendData['monthlyAverage'] ?? 0).toStringAsFixed(1)}',
              Colors.green,
            ),
            _buildStatItem(
              Icons.change_circle,
              'Type Changes',
              '${_trendData['skinTypeChanges'] ?? 0}',
              Colors.amber,
            ),
            _buildStatItem(
              Icons.calendar_today,
              'Tracking Since',
              DateFormat('MMM yyyy').format(
                  _trendData['firstDate'] ?? DateTime.now()
              ),
              Colors.purple,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStatItem(IconData icon, String label, String value, Color color) {
    return Column(
      children: [
        Icon(icon, color: color, size: 24),
        SizedBox(height: 8),
        Text(
          value,
          style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
        ),
        SizedBox(height: 4),
        Text(
          label,
          style: TextStyle(fontSize: 12, color: Colors.grey),
          textAlign: TextAlign.center,
        ),
      ],
    );
  }

  Widget _buildQuickFilters() {
    final skinTypes = _allAnalyses.map((a) => a.skinType).toSet().toList();
    final areas = _allAnalyses.map((a) => a.targetArea).toSet().toList();

    return Card(
      child: Padding(
        padding: EdgeInsets.all(12),
        child: Column(
          children: [
            // فلترة الفترة
            Row(
              children: [
                Icon(Icons.calendar_today, size: 20),
                SizedBox(width: 8),
                Text('Period:'),
                SizedBox(width: 12),
                Expanded(
                  child: DropdownButton<String>(
                    value: _selectedPeriod,
                    isExpanded: true,
                    items: _periods.map((period) {
                      return DropdownMenuItem(
                        value: period,
                        child: Text(period),
                      );
                    }).toList(),
                    onChanged: (value) {
                      setState(() => _selectedPeriod = value!);
                      _applyFilters();
                    },
                  ),
                ),
              ],
            ),

            SizedBox(height: 12),

            // فلترة نوع البشرة والمنطقة
            Row(
              children: [
                Expanded(
                  child: DropdownButtonFormField<String>(
                    value: _selectedSkinType,
                    decoration: InputDecoration(
                      labelText: 'Skin Type',
                      border: OutlineInputBorder(),
                      contentPadding: EdgeInsets.symmetric(horizontal: 12),
                    ),
                    items: ['All', ...skinTypes].map((type) {
                      return DropdownMenuItem(
                        value: type,
                        child: Text(type),
                      );
                    }).toList(),
                    onChanged: (value) {
                      setState(() => _selectedSkinType = value!);
                      _applyFilters();
                    },
                  ),
                ),
                SizedBox(width: 12),
                Expanded(
                  child: DropdownButtonFormField<String>(
                    value: _selectedArea,
                    decoration: InputDecoration(
                      labelText: 'Area',
                      border: OutlineInputBorder(),
                      contentPadding: EdgeInsets.symmetric(horizontal: 12),
                    ),
                    items: ['All', ...areas].map((area) {
                      return DropdownMenuItem(
                        value: area,
                        child: Text(area),
                      );
                    }).toList(),
                    onChanged: (value) {
                      setState(() => _selectedArea = value!);
                      _applyFilters();
                    },
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTimeline() {
    if (_timelineEvents.isEmpty) return SizedBox();

    return Card(
      child: Padding(
        padding: EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.timeline, color: Colors.blue),
                SizedBox(width: 8),
                Text(
                  'Skin History Timeline',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
              ],
            ),
            SizedBox(height: 16),

            ..._timelineEvents.take(5).map((event) {
              return _buildTimelineEvent(event);
            }).toList(),

            if (_timelineEvents.length > 5)
              TextButton(
                onPressed: _showFullTimeline,
                child: Text('Show All ${_timelineEvents.length} Events'),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildTimelineEvent(Map<String, dynamic> event) {
    return Container(
      margin: EdgeInsets.only(bottom: 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: event['color'].withOpacity(0.2),
              shape: BoxShape.circle,
            ),
            child: Icon(event['icon'], color: event['color'], size: 20),
          ),
          SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  event['title'],
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                  ),
                ),
                SizedBox(height: 4),
                Text(
                  event['description'],
                  style: TextStyle(color: Colors.grey[600]),
                ),
                SizedBox(height: 4),
                Text(
                  DateFormat('MMM dd, yyyy - HH:mm').format(event['date']),
                  style: TextStyle(fontSize: 12, color: Colors.grey),
                ),
              ],
            ),
          ),
          if (event['analysis'] != null)
            IconButton(
              icon: Icon(Icons.visibility, size: 18),
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => AnalysisDetailPage(
                      analysis: event['analysis'],
                    ),
                  ),
                );
              },
            ),
        ],
      ),
    );
  }

  Widget _buildTrendsAnalysis() {
    if (_allAnalyses.length < 2) return SizedBox();

    return Card(
      child: Padding(
        padding: EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.trending_up, color: Colors.green),
                SizedBox(width: 8),
                Text(
                  'Trends Analysis',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
              ],
            ),
            SizedBox(height: 16),

            // مشاكل متكررة
            if ((_trendData['concernFrequency'] as Map).isNotEmpty)
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Frequent Concerns:',
                    style: TextStyle(fontWeight: FontWeight.bold),
                  ),
                  SizedBox(height: 8),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: (_trendData['concernFrequency'] as Map).entries
                        .take(5)
                        .map((entry) {
                      return Chip(
                        label: Text('${entry.key} (${entry.value}x)'),
                        backgroundColor: _getProblemColor(entry.key),
                      );
                    }).toList(),
                  ),
                  SizedBox(height: 16),
                ],
              ),

            // توصيات بناءً على التاريخ
            Text(
              'Based on your history:',
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
            SizedBox(height: 8),
            _generateHistoryBasedRecommendations(),
          ],
        ),
      ),
    );
  }

  Widget _generateHistoryBasedRecommendations() {
    final recommendations = <String>[];

    if (_allAnalyses.length >= 3) {
      recommendations.add('You\'ve completed ${_allAnalyses.length} analyses. Great consistency!');
    }

    if (_trendData['skinTypeChanges'] > 0) {
      recommendations.add('Your skin type changed ${_trendData['skinTypeChanges']} times. Consider seasonal adjustments.');
    }

    final currentSkinType = _allAnalyses.isNotEmpty
        ? _allAnalyses.first.skinType
        : 'Normal';

    if (currentSkinType.toLowerCase().contains('dry')) {
      recommendations.add('Stay consistent with hydrating routines, especially in winter months.');
    } else if (currentSkinType.toLowerCase().contains('oily')) {
      recommendations.add('Monitor oil production and adjust cleanser frequency as needed.');
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: recommendations.map((rec) {
        return Padding(
          padding: EdgeInsets.symmetric(vertical: 4),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(Icons.check_circle, color: Colors.green, size: 16),
              SizedBox(width: 8),
              Expanded(child: Text(rec)),
            ],
          ),
        );
      }).toList(),
    );
  }

  Widget _buildAnalysesList() {
    return Card(
      child: Padding(
        padding: EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.list_alt, color: Colors.blue),
                SizedBox(width: 8),
                Text(
                  'Detailed Analyses (${_filteredAnalyses.length})',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
              ],
            ),
            SizedBox(height: 16),

            ..._filteredAnalyses.take(10).map((analysis) {
              return _buildAnalysisListItem(analysis);
            }).toList(),

            if (_filteredAnalyses.length > 10)
              TextButton(
                onPressed: _showAllAnalyses,
                child: Text('Show All ${_filteredAnalyses.length} Analyses'),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildAnalysisListItem(SkinAnalysis analysis) {
    return Container(
      margin: EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        border: Border(
          left: BorderSide(
            color: _getSkinTypeColor(analysis.skinType),
            width: 4,
          ),
        ),
      ),
      child: ListTile(
        contentPadding: EdgeInsets.symmetric(horizontal: 12),
        leading: analysis.imageBase64 != null
            ? CircleAvatar(
          backgroundImage: MemoryImage(
            base64Decode(analysis.imageBase64!),
          ),
        )
            : CircleAvatar(
          child: Icon(Icons.face),
          backgroundColor: _getSkinTypeColor(analysis.skinType),
        ),
        title: Text(
          '${analysis.skinType} - ${analysis.targetArea}',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              DateFormat('MMM dd, yyyy - HH:mm').format(analysis.date),
              style: TextStyle(fontSize: 12),
            ),
            if (analysis.problems.isNotEmpty)
              Wrap(
                spacing: 4,
                children: analysis.problems
                    .take(2)
                    .map((problem) => Chip(
                  label: Text(problem),
                  padding: EdgeInsets.zero,
                  labelPadding: EdgeInsets.symmetric(horizontal: 4),
                ))
                    .toList(),
              ),
          ],
        ),
        trailing: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              '${(analysis.confidence * 100).toStringAsFixed(0)}%',
              style: TextStyle(
                fontWeight: FontWeight.bold,
                color: analysis.confidence > 0.7
                    ? Colors.green
                    : Colors.orange,
              ),
            ),
            Text(
              'Confidence',
              style: TextStyle(fontSize: 10, color: Colors.grey),
            ),
          ],
        ),
        onTap: () {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => AnalysisDetailPage(analysis: analysis),
            ),
          );
        },
      ),
    );
  }

  void _showFilters() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (context) {
        return _buildFilterSheet();
      },
    );
  }

  Widget _buildFilterSheet() {
    final skinTypes = _allAnalyses.map((a) => a.skinType).toSet().toList();
    final areas = _allAnalyses.map((a) => a.targetArea).toSet().toList();

    return Container(
      padding: EdgeInsets.all(20),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Filter Analyses',
            style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
          ),
          SizedBox(height: 20),

          DropdownButtonFormField<String>(
            value: _selectedPeriod,
            decoration: InputDecoration(
              labelText: 'Time Period',
              border: OutlineInputBorder(),
            ),
            items: _periods.map((period) {
              return DropdownMenuItem(
                value: period,
                child: Text(period),
              );
            }).toList(),
            onChanged: (value) {
              setState(() => _selectedPeriod = value!);
            },
          ),

          SizedBox(height: 16),

          DropdownButtonFormField<String>(
            value: _selectedSkinType,
            decoration: InputDecoration(
              labelText: 'Skin Type',
              border: OutlineInputBorder(),
            ),
            items: ['All', ...skinTypes].map((type) {
              return DropdownMenuItem(
                value: type,
                child: Text(type),
              );
            }).toList(),
            onChanged: (value) {
              setState(() => _selectedSkinType = value!);
            },
          ),

          SizedBox(height: 16),

          DropdownButtonFormField<String>(
            value: _selectedArea,
            decoration: InputDecoration(
              labelText: 'Target Area',
              border: OutlineInputBorder(),
            ),
            items: ['All', ...areas].map((area) {
              return DropdownMenuItem(
                value: area,
                child: Text(area),
              );
            }).toList(),
            onChanged: (value) {
              setState(() => _selectedArea = value!);
            },
          ),

          SizedBox(height: 30),

          Row(
            children: [
              Expanded(
                child: ElevatedButton(
                  onPressed: () {
                    Navigator.pop(context);
                  },
                  child: Text('Cancel'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.grey[200],
                    foregroundColor: Colors.black,
                  ),
                ),
              ),
              SizedBox(width: 16),
              Expanded(
                child: ElevatedButton(
                  onPressed: () {
                    _applyFilters();
                    Navigator.pop(context);
                  },
                  child: Text('Apply Filters'),
                ),
              ),
            ],
          ),

          SizedBox(height: 20),
        ],
      ),
    );
  }

  void _showFullTimeline() {
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: Text('Complete Timeline'),
          content: Container(
            width: double.maxFinite,
            height: 400,
            child: ListView.builder(
              itemCount: _timelineEvents.length,
              itemBuilder: (context, index) {
                return _buildTimelineEvent(_timelineEvents[index]);
              },
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: Text('Close'),
            ),
          ],
        );
      },
    );
  }

  void _showAllAnalyses() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => Scaffold(
          appBar: AppBar(
            title: Text('All Analyses (${_filteredAnalyses.length})'),
          ),
          body: ListView.builder(
            itemCount: _filteredAnalyses.length,
            itemBuilder: (context, index) {
              return _buildAnalysisListItem(_filteredAnalyses[index]);
            },
          ),
        ),
      ),
    );
  }

  Color _getSkinTypeColor(String skinType) {
    switch (skinType.toLowerCase()) {
      case 'oily':
        return Colors.blue;
      case 'dry':
        return Colors.amber;
      case 'combination':
        return Colors.green;
      case 'sensitive':
        return Colors.pink;
      case 'normal':
        return Colors.teal;
      default:
        return Colors.grey;
    }
  }

  Color _getProblemColor(String problem) {
    final colors = {
      'acne': Colors.red[100]!,
      'dryness': Colors.blue[100]!,
      'oiliness': Colors.amber[100]!,
      'wrinkles': Colors.purple[100]!,
      'sensitivity': Colors.pink[100]!,
      'pores': Colors.green[100]!,
      'redness': Colors.red[100]!,
      'dark_spots': Colors.brown[100]!,
    };
    return colors[problem] ?? Colors.grey[100]!;
  }
}


