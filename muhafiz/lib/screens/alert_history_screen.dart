import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:muhafiz/core/constants.dart';
import 'package:muhafiz/models/alert_model.dart';
import 'package:muhafiz/providers/alerts_provider.dart';

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
    final emergencyAlerts = alerts.where((a) => a.type == AlertType.emergency).length;
    final vulnerableAlerts = alerts.where((a) => a.type == AlertType.vulnerable).length;
    final lastAlert = alerts.isEmpty ? 'No alerts' : _formatTime(alerts.first.createdAt);

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
                child: filteredAlerts.isEmpty ? _buildEmptyState() : _buildList(filteredAlerts),
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
                Text(
                  _labelForStatus(alert.status),
                  style: TextStyle(
                    fontFamily: 'Inter',
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    color: AppColors.black.withValues(alpha: 0.6),
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
      backgroundColor: AppColors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (_) => Padding(
        padding: const EdgeInsets.fromLTRB(20, 20, 20, 30),
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
              'Status: ${_labelForStatus(alert.status)}',
              style: const TextStyle(
                fontFamily: 'Inter',
                fontSize: 12,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              alert.message,
              style: const TextStyle(
                fontFamily: 'Inter',
                fontSize: 12,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Contacts notified: ${alert.sentToTrusteeIds.length}',
              style: const TextStyle(
                fontFamily: 'Inter',
                fontSize: 12,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              'Location: ${alert.address ?? "Location sharing will be added soon."}',
              style: const TextStyle(
                fontFamily: 'Inter',
                fontSize: 12,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEmptyState() {
    return ListView(
      physics: const AlwaysScrollableScrollPhysics(),
      children: [
        SizedBox(height: MediaQuery.of(context).size.height * 0.2),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 40),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                Icons.notifications_none,
                size: 72,
                color: AppColors.black.withValues(alpha: 0.2),
              ),
              const SizedBox(height: 16),
              const Text(
                'No alerts yet',
                style: TextStyle(
                  fontFamily: 'Inter',
                  fontSize: 18,
                  fontWeight: FontWeight.w600,
                  color: AppColors.black,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'Your emergency and protective mode activity will appear here.',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontFamily: 'Inter',
                  fontSize: 13,
                  color: AppColors.black.withValues(alpha: 0.6),
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
