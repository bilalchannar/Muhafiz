import 'package:flutter/material.dart';
import 'package:muhafiz/core/constants.dart';
import 'package:muhafiz/models/alert_model.dart';
import 'package:muhafiz/services/firestore_service.dart';

class AdminDashboardScreen extends StatefulWidget {
  const AdminDashboardScreen({super.key});

  @override
  State<AdminDashboardScreen> createState() => _AdminDashboardScreenState();
}

class _AdminDashboardScreenState extends State<AdminDashboardScreen> {
  final _firestoreService = FirestoreService();

  Future<Map<String, dynamic>> _loadDashboard() async {
    final users = await _firestoreService.countCollection('users', ownerField: 'id');
    final trustees = await _firestoreService.countCollection('trustees');
    final alerts = await _firestoreService.countCollection('alerts');
    final settings = await _firestoreService.countCollection('settings', ownerField: 'id');
    final logs = await _firestoreService.countCollection('notification_logs');
    final recentAlerts = await _firestoreService.queryCollection(
      'alerts',
      limit: 8,
    );
    recentAlerts.sort((a, b) {
      final aTime = DateTime.tryParse(a['createdAt']?.toString() ?? '') ?? DateTime.fromMillisecondsSinceEpoch(0);
      final bTime = DateTime.tryParse(b['createdAt']?.toString() ?? '') ?? DateTime.fromMillisecondsSinceEpoch(0);
      return bTime.compareTo(aTime);
    });

    return {
      'users': users,
      'trustees': trustees,
      'alerts': alerts,
      'settings': settings,
      'logs': logs,
      'recentAlerts': recentAlerts,
    };
  }

  Widget _metricCard(String label, int value, IconData icon, Color color) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.divider),
      ),
      child: Row(
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(icon, color: color),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  value.toString(),
                  style: const TextStyle(
                    fontFamily: 'Inter',
                    fontSize: 20,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  label,
                  style: TextStyle(
                    fontFamily: 'Inter',
                    fontSize: 12,
                    color: AppColors.black.withValues(alpha: 0.65),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8F9FB),
      appBar: AppBar(title: const Text('Admin Dashboard')),
      body: SafeArea(
        child: FutureBuilder<Map<String, dynamic>>(
          future: _loadDashboard(),
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const Center(child: CircularProgressIndicator());
            }
            if (snapshot.hasError) {
              return Center(
                child: Text('Unable to load dashboard: ${snapshot.error}'),
              );
            }

            final data = snapshot.data ?? const {};
            final recentAlerts = (data['recentAlerts'] as List<dynamic>? ?? const [])
                .map((e) => AlertModel.fromJson(Map<String, dynamic>.from(e as Map)))
                .toList();

            return SingleChildScrollView(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Backend overview',
                    style: TextStyle(
                      fontFamily: 'Inter',
                      fontSize: 22,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    'Monitor Firestore records, alerts, and notification logs.',
                    style: TextStyle(
                      fontFamily: 'Inter',
                      fontSize: 13,
                      color: AppColors.black.withValues(alpha: 0.6),
                    ),
                  ),
                  const SizedBox(height: 16),
                  GridView.count(
                    crossAxisCount: 2,
                    crossAxisSpacing: 12,
                    mainAxisSpacing: 12,
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    childAspectRatio: 1.6,
                    children: [
                      _metricCard('Users', data['users'] as int? ?? 0, Icons.people_alt_outlined, AppColors.primary),
                      _metricCard('Trustees', data['trustees'] as int? ?? 0, Icons.groups_rounded, AppColors.vulnerable),
                      _metricCard('Alerts', data['alerts'] as int? ?? 0, Icons.warning_amber_rounded, const Color(0xFFEF5350)),
                      _metricCard('Notification logs', data['logs'] as int? ?? 0, Icons.notifications_active_outlined, const Color(0xFF1976D2)),
                    ],
                  ),
                  const SizedBox(height: 16),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: AppColors.white,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: AppColors.divider),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Recent alerts',
                          style: TextStyle(
                            fontFamily: 'Inter',
                            fontSize: 16,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        const SizedBox(height: 12),
                        if (recentAlerts.isEmpty)
                          Text(
                            'No alerts yet.',
                            style: TextStyle(
                              fontFamily: 'Inter',
                              fontSize: 12,
                              color: AppColors.black.withValues(alpha: 0.6),
                            ),
                          )
                        else
                          ...recentAlerts.map(
                            (alert) => Padding(
                              padding: const EdgeInsets.only(bottom: 12),
                              child: Row(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Icon(
                                    alert.type == AlertType.emergency
                                        ? Icons.warning_amber_rounded
                                        : Icons.shield_outlined,
                                    color: alert.type == AlertType.emergency
                                        ? AppColors.primary
                                        : AppColors.vulnerable,
                                  ),
                                  const SizedBox(width: 10),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          alert.message,
                                          style: const TextStyle(
                                            fontFamily: 'Inter',
                                            fontSize: 13,
                                            fontWeight: FontWeight.w600,
                                          ),
                                        ),
                                        const SizedBox(height: 4),
                                        Text(
                                          '${alert.type.name} • ${alert.status.name} • ${alert.createdAt}',
                                          style: TextStyle(
                                            fontFamily: 'Inter',
                                            fontSize: 11,
                                            color: AppColors.black.withValues(alpha: 0.6),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                      ],
                    ),
                  ),
                ],
              ),
            );
          },
        ),
      ),
    );
  }
}
