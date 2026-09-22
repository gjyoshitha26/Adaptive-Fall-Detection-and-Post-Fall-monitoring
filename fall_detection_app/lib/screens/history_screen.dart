import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import '../services/fall_detection_provider.dart';
import 'alert_detail_screen.dart';

class HistoryScreen extends StatefulWidget {
  const HistoryScreen({super.key});

  @override
  State<HistoryScreen> createState() => _HistoryScreenState();
}

class _HistoryScreenState extends State<HistoryScreen> {
  String _filter = 'All'; // 'All', 'CRITICAL', 'HIGH', 'WATCH'

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<FallDetectionProvider>();
    final allFalls = provider.fallHistory;

    final filteredFalls = allFalls.where((fall) {
      if (_filter == 'All') return true;
      return fall.triage.toUpperCase() == _filter.toUpperCase();
    }).toList();

    final timeFormat = DateFormat('hh:mm a');
    final dateFormat = DateFormat('EEE, dd MMM yyyy');

    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(
        title: const Text('Clinical Fall History', style: TextStyle(fontWeight: FontWeight.bold)),
        backgroundColor: const Color(0xFF1E293B),
        elevation: 0,
      ),
      body: Column(
        children: [
          // Filter Chips
          Container(
            color: Colors.white,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: [
                  const Text('Triage: ', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                  const SizedBox(width: 8),
                  _filterChip('All'),
                  const SizedBox(width: 6),
                  _filterChip('CRITICAL'),
                  const SizedBox(width: 6),
                  _filterChip('HIGH'),
                  const SizedBox(width: 6),
                  _filterChip('WATCH'),
                ],
              ),
            ),
          ),
          const Divider(height: 1),

          // Incident List
          Expanded(
            child: filteredFalls.isEmpty
                ? Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.history_toggle_off, size: 60, color: Colors.grey.shade400),
                        const SizedBox(height: 12),
                        Text(
                          'No ${_filter == "All" ? "" : _filter} triage incidents recorded',
                          style: const TextStyle(fontSize: 16, color: Colors.grey, fontWeight: FontWeight.w600),
                        ),
                      ],
                    ),
                  )
                : ListView.builder(
                    padding: const EdgeInsets.all(16),
                    itemCount: filteredFalls.length,
                    itemBuilder: (context, index) {
                      final fall = filteredFalls[index];
                      return Container(
                        margin: const EdgeInsets.only(bottom: 12),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(
                            color: fall.isCritical ? Colors.red.shade200 : Colors.grey.shade200,
                            width: fall.isCritical ? 1.5 : 1.0,
                          ),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withValues(alpha: 0.02),
                              blurRadius: 6,
                              offset: const Offset(0, 2),
                            ),
                          ],
                        ),
                        child: ListTile(
                          contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                          leading: CircleAvatar(
                            backgroundColor: fall.triageColor.withValues(alpha: 0.15),
                            radius: 24,
                            child: Icon(fall.triageIcon, color: fall.triageColor, size: 24),
                          ),
                          title: Row(
                            children: [
                              Text(
                                '${fall.triage} (${fall.activity})',
                                style: TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 15,
                                  color: fall.triageColor,
                                ),
                              ),
                              const SizedBox(width: 8),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                decoration: BoxDecoration(
                                  color: fall.still ? Colors.red.shade50 : Colors.green.shade50,
                                  borderRadius: BorderRadius.circular(6),
                                  border: Border.all(
                                    color: fall.still ? Colors.red.shade300 : Colors.green.shade300,
                                  ),
                                ),
                                child: Text(
                                  fall.still ? 'Still' : 'Recovered',
                                  style: TextStyle(
                                    fontSize: 10,
                                    fontWeight: FontWeight.bold,
                                    color: fall.still ? Colors.red.shade800 : Colors.green.shade800,
                                  ),
                                ),
                              ),
                            ],
                          ),
                          subtitle: Padding(
                            padding: const EdgeInsets.only(top: 4.0),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  '${timeFormat.format(fall.timestamp)} • ${dateFormat.format(fall.timestamp)}',
                                  style: TextStyle(fontSize: 12, color: Colors.blueGrey.shade700),
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  'Height: ${fall.fallHeightM.toStringAsFixed(2)}m • Impact: ${fall.peakG.toStringAsFixed(1)}g • FRA: ${fall.fraLevel}',
                                  style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Colors.blueGrey.shade900),
                                ),
                                Text(
                                  'Location: ${fall.location} | Device: ${fall.deviceId}',
                                  style: TextStyle(fontSize: 11, color: Colors.grey.shade600),
                                ),
                              ],
                            ),
                          ),
                          trailing: const Icon(Icons.arrow_forward_ios, size: 14, color: Colors.grey),
                          onTap: () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (_) => AlertDetailScreen(fallEvent: fall),
                              ),
                            );
                          },
                        ),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }

  Widget _filterChip(String label) {
    final isSelected = _filter == label;
    return ChoiceChip(
      label: Text(label),
      selected: isSelected,
      selectedColor: const Color(0xFF1E293B),
      labelStyle: TextStyle(
        color: isSelected ? Colors.white : Colors.black87,
        fontSize: 12,
        fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
      ),
      onSelected: (selected) {
        if (selected) {
          setState(() {
            _filter = label;
          });
        }
      },
    );
  }
}
