import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:muhafiz/core/constants.dart';
import 'package:muhafiz/models/alert_model.dart';
import 'package:muhafiz/models/trustee_model.dart';
import 'package:muhafiz/providers/alerts_provider.dart';
import 'package:muhafiz/providers/trustees_provider.dart';

class AlertHistoryScreen extends ConsumerStatefulWidget {
  const AlertHistoryScreen({super.key});

  @override
  ConsumerState<AlertHistoryScreen> createState() => _AlertHistoryScreenState();
}

class _AlertHistoryScreenState extends ConsumerState<AlertHistoryScreen> {
  AlertFilter _activeFilter = AlertFilter.all;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(alertsProvider.notifier).load();
    });
  }

  @override
  Widget build(BuildContext context) {
    final alerts = ref.watch(alertsProvider);
    final filteredAlerts = _filterAlerts(alerts);

    final totalAlerts = alerts.length;
    final emergencyAlerts = alerts
        .where((a) => a.type == AlertType.emergency)
        .length;
    final vulnerableAlerts = alerts
        .where((a) => a.type == AlertType.vulnerable)
        .length;
    final lastAlert = alerts.isEmpty
        ? 'No alerts'
        : _formatTime(alerts.first.createdAt);

    return Scaffold(
      backgroundColor: const Color(0xFFF8F9FB),
      appBar: AppBar(title: const Text('Alert History')),
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 12, 20, 12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Alert History',
                    style: TextStyle(
                      fontFamily: 'Inter',
                      fontSize: 22,
                      fontWeight: FontWeight.w700,
                      color: AppColors.black,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    'Review your previous safety alerts and activity.',
                    style: TextStyle(
                      fontFamily: 'Inter',
                      fontSize: 13,
                      color: AppColors.black.withValues(alpha: 0.6),
                    ),
                  ),
                  const SizedBox(height: 14),
                  _summaryCard(
                    totalAlerts: totalAlerts,
                    emergencyAlerts: emergencyAlerts,
                    vulnerableAlerts: vulnerableAlerts,
                    lastAlertTime: lastAlert,
                  ),
                  const SizedBox(height: 12),
                  Wrap(
                    spacing: 8,
                    children: [
                      _filterChip(AlertFilter.all, 'All'),
                      _filterChip(AlertFilter.emergency, 'Emergency'),
                      _filterChip(AlertFilter.vulnerable, 'Vulnerable'),
                      _filterChip(AlertFilter.cancelled, 'Cancelled'),
                    ],
                  ),
                ],
              ),
            ),
            Expanded(
              child: RefreshIndicator(
                onRefresh: () => ref.read(alertsProvider.notifier).load(),
                color: AppColors.primary,
                child: filteredAlerts.isEmpty
                    ? _buildEmptyState()
                    : _buildList(filteredAlerts),
              ),
            ),
          ],
        ),
      ),
    );
  }

  List<AlertModel> _filterAlerts(List<AlertModel> alerts) {
    if (_activeFilter == AlertFilter.all) return alerts;
    return alerts.where((alert) {
      switch (_activeFilter) {
        case AlertFilter.emergency:
          return alert.type == AlertType.emergency;
        case AlertFilter.vulnerable:
          return alert.type == AlertType.vulnerable;
        case AlertFilter.cancelled:
          return alert.status == AlertStatus.cancelled;
        case AlertFilter.all:
          return true;
      }
    }).toList();
  }

  Widget _summaryCard({
    required int totalAlerts,
    required int emergencyAlerts,
    required int vulnerableAlerts,
    required String lastAlertTime,
  }) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.divider),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '$totalAlerts total alerts',
            style: const TextStyle(
              fontFamily: 'Inter',
              fontSize: 14,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 8),
          _infoRow('Emergency alerts', '$emergencyAlerts'),
          const SizedBox(height: 6),
          _infoRow('Vulnerable alerts', '$vulnerableAlerts'),
          const SizedBox(height: 6),
          _infoRow('Last alert', lastAlertTime),
        ],
      ),
    );
  }

  Widget _infoRow(String label, String value) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          label,
          style: TextStyle(
            fontFamily: 'Inter',
            fontSize: 12,
            color: AppColors.black.withValues(alpha: 0.6),
          ),
        ),
        Text(
          value,
          style: const TextStyle(
            fontFamily: 'Inter',
            fontSize: 12,
            fontWeight: FontWeight.w600,
            color: AppColors.black,
          ),
        ),
      ],
    );
  }

  Widget _filterChip(AlertFilter filter, String label) {
    final isSelected = _activeFilter == filter;
    return ChoiceChip(
      label: Text(label),
      selected: isSelected,
      selectedColor: AppColors.primary.withValues(alpha: 0.15),
      onSelected: (_) => setState(() => _activeFilter = filter),
      labelStyle: TextStyle(
        fontFamily: 'Inter',
        fontSize: 12,
        fontWeight: FontWeight.w600,
        color: isSelected ? AppColors.primary : AppColors.black,
      ),
      side: BorderSide(
        color: isSelected ? AppColors.primary : AppColors.divider,
      ),
      backgroundColor: AppColors.white,
    );
  }

  Widget _buildList(List<AlertModel> alerts) {
    return ListView.builder(
      padding: const EdgeInsets.fromLTRB(20, 4, 20, 24),
      itemCount: alerts.length,
      itemBuilder: (context, index) {
        final alert = alerts[index];
        return _alertCard(alert);
      },
    );
  }

  Color _colorForStatus(AlertStatus status) {
    switch (status) {
      case AlertStatus.delivered:
      case AlertStatus.sent:
        return AppColors.safe;
      case AlertStatus.pending:
        return Colors.orange;
      case AlertStatus.failed:
        return AppColors.primary;
      case AlertStatus.cancelled:
        return Colors.grey;
    }
  }

  Widget _alertCard(AlertModel alert) {
    final accent = _accentForAlert(alert);
    return InkWell(
      borderRadius: BorderRadius.circular(16),
      onTap: () => _showDetails(alert),
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: AppColors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: accent.withValues(alpha: 0.25)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  width: 10,
                  height: 10,
                  decoration: BoxDecoration(color: accent, shape: BoxShape.circle),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    _labelForType(alert.type),
                    style: TextStyle(
                      fontFamily: 'Inter',
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                      color: accent,
                    ),
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: _colorForStatus(alert.status).withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Text(
                    _labelForStatus(alert.status),
                    style: TextStyle(
                      fontFamily: 'Inter',
                      fontSize: 10,
                      fontWeight: FontWeight.w800,
                      color: _colorForStatus(alert.status),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 6),
            Text(
              _formatTime(alert.createdAt),
              style: TextStyle(
                fontFamily: 'Inter',
                fontSize: 12,
                color: AppColors.black.withValues(alpha: 0.6),
              ),
            ),
            const SizedBox(height: 8),
            Text(
              alert.message,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                fontFamily: 'Inter',
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: AppColors.black,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Contacts notified: ${alert.sentToTrusteeIds.length}',
              style: TextStyle(
                fontFamily: 'Inter',
                fontSize: 11,
                color: AppColors.black.withValues(alpha: 0.6),
              ),
            ),
            const SizedBox(height: 4),
            Text(
              'Location: ${alert.address ?? "Location sharing will be added soon."}',
              style: TextStyle(
                fontFamily: 'Inter',
                fontSize: 11,
                color: AppColors.black.withValues(alpha: 0.6),
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showDetails(AlertModel alert) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppColors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (_) => Container(
        constraints: BoxConstraints(maxHeight: MediaQuery.of(context).size.height * 0.8),
        padding: const EdgeInsets.fromLTRB(20, 20, 20, 30),
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                _labelForType(alert.type),
                style: const TextStyle(
                  fontFamily: 'Inter',
                  fontSize: 18,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                _formatTime(alert.createdAt),
                style: TextStyle(
                  fontFamily: 'Inter',
                  fontSize: 12,
                  color: AppColors.black.withValues(alpha: 0.6),
                ),
              ),
              const SizedBox(height: 12),
              Text(
                alert.message,
                style: const TextStyle(
                  fontFamily: 'Inter',
                  fontSize: 12,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                'Location: ${alert.address ?? "Location details saved to safety logs."}',
                style: const TextStyle(
                  fontFamily: 'Inter',
                  fontSize: 12,
                ),
              ),
              const SizedBox(height: 16),
              const Text(
                'Trustee Dispatch Status',
                style: TextStyle(
                  fontFamily: 'Inter',
                  fontSize: 13,
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: 6),
              if (alert.sentToTrusteeIds.isEmpty)
                const Text('No trustees notified.', style: TextStyle(fontSize: 11, color: Colors.grey))
              else
                ...alert.sentToTrusteeIds.map((id) {
                  final trustees = ref.read(trusteesProvider);
                  final trustee = trustees.firstWhere(
                    (t) => t.id == id,
                    orElse: () => TrusteeModel(id: id, name: 'Trustee', phone: '', userId: '', relationship: 'Contact', priority: 'secondary'),
                  );
                  return Padding(
                    padding: const EdgeInsets.symmetric(vertical: 4),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          trustee.name,
                          style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
                        ),
                        Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                              decoration: BoxDecoration(
                                color: Colors.green.shade50,
                                borderRadius: BorderRadius.circular(4),
                              ),
                              child: const Text(
                                'WhatsApp: Sent',
                                style: TextStyle(fontSize: 9, color: Colors.green, fontWeight: FontWeight.w700),
                              ),
                            ),
                            const SizedBox(width: 6),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                              decoration: BoxDecoration(
                                color: alert.status == AlertStatus.failed ? Colors.red.shade50 : Colors.orange.shade50,
                                borderRadius: BorderRadius.circular(4),
                              ),
                              child: Text(
                                alert.status == AlertStatus.failed ? 'Failed' : 'Pending Check-in',
                                style: TextStyle(
                                  fontSize: 9, 
                                  color: alert.status == AlertStatus.failed ? Colors.red : Colors.orange.shade800,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  );
                }),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildEmptyState() {
    return ListView(
      physics: const AlwaysScrollableScrollPhysics(),
      children: [
        SizedBox(height: MediaQuery.of(context).size.height * 0.18),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 40),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 80,
                height: 80,
                decoration: BoxDecoration(
                  color: AppColors.primary.withValues(alpha: 0.08),
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.notifications_none_rounded,
                  size: 40,
                  color: AppColors.primary,
                ),
              ),
              const SizedBox(height: 20),
              const Text(
                'No Alerts Logged',
                style: TextStyle(
                  fontFamily: 'Inter',
                  fontSize: 18,
                  fontWeight: FontWeight.w800,
                  color: AppColors.black,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'All your emergency transmissions and safety check-ins will be recorded here for review.',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontFamily: 'Inter',
                  fontSize: 13,
                  color: AppColors.black.withValues(alpha: 0.55),
                  height: 1.4,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Color _accentForAlert(AlertModel alert) {
    switch (alert.type) {
      case AlertType.emergency:
        return AppColors.primary;
      case AlertType.vulnerable:
        return AppColors.vulnerable;
    }
  }

  String _labelForType(AlertType type) {
    return type == AlertType.emergency ? 'Emergency Alert' : 'Vulnerable Alert';
  }

  String _labelForStatus(AlertStatus status) {
    switch (status) {
      case AlertStatus.sent:
        return 'Sent';
      case AlertStatus.cancelled:
        return 'Cancelled';
      case AlertStatus.failed:
        return 'Failed';
      case AlertStatus.pending:
        return 'Pending';
      case AlertStatus.delivered:
        return 'Delivered';
    }
  }

  String _formatTime(DateTime timestamp) {
    final date = '${timestamp.day}/${timestamp.month}/${timestamp.year}';
    final hour = timestamp.hour.toString().padLeft(2, '0');
    final minute = timestamp.minute.toString().padLeft(2, '0');
    return '$date • $hour:$minute';
  }
}

enum AlertFilter { all, emergency, vulnerable, cancelled }
