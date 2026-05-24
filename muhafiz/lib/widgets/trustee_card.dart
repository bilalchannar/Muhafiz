import 'package:flutter/material.dart';
import 'package:muhafiz/core/constants.dart';
import 'package:muhafiz/models/trustee_model.dart';

/// Displays a trusted contact with priority, relationship, alert permissions,
/// and optional actions.
class TrusteeCard extends StatelessWidget {
  final TrusteeModel? trustee;
  final String? name;
  final String? phone;
  final String? relationship;
  final String? priority;
  final bool? receivesEmergencyAlerts;
  final bool? receivesLocationUpdates;
  final bool? receivesVulnerableModeAlerts;
  final VoidCallback? onTap;
  final VoidCallback? onEdit;
  final VoidCallback? onDelete;
  final VoidCallback? onCall;
  final VoidCallback? onMessage;

  const TrusteeCard({
    super.key,
    this.trustee,
    this.name,
    this.phone,
    this.relationship,
    this.priority,
    this.receivesEmergencyAlerts,
    this.receivesLocationUpdates,
    this.receivesVulnerableModeAlerts,
    this.onTap,
    this.onEdit,
    this.onDelete,
    this.onCall,
    this.onMessage,
  });

  String _resolveName() {
    final raw = (name ?? trustee?.name ?? '').trim();
    return raw.isEmpty ? 'Trusted Contact' : raw;
  }

  String _resolvePhone() {
    final raw = (phone ?? trustee?.phone ?? '').trim();
    return raw.isEmpty ? 'No phone number' : raw;
  }

  String _resolveRelationship() {
    final raw = (relationship ?? '').trim();
    return raw.isEmpty ? 'Contact' : raw;
  }

  String _resolvePriority() {
    final raw = (priority ?? trustee?.tier ?? '').trim();
    return raw.isEmpty ? 'Secondary' : raw;
  }

  String _initialsFor(String value) {
    final parts = value.trim().split(RegExp(r'\s+'));
    if (parts.length >= 2) {
      return '${parts[0][0]}${parts[1][0]}'.toUpperCase();
    }
    return value.isNotEmpty ? value[0].toUpperCase() : '?';
  }

  Color _priorityBackground(String value) {
    switch (value.toLowerCase()) {
      case 'primary':
        return AppColors.primary;
      case 'backup':
        return const Color(0xFFE0E0E0);
      default:
        return AppColors.primary.withValues(alpha: 0.12);
    }
  }

  Color _priorityForeground(String value) {
    switch (value.toLowerCase()) {
      case 'primary':
        return AppColors.white;
      case 'backup':
        return AppColors.black;
      default:
        return AppColors.primary;
    }
  }

  List<Widget> _buildPermissionChips(TextStyle baseStyle) {
    final chips = <Widget>[];

    if (receivesEmergencyAlerts == true) {
      chips.add(_PermissionChip(
        label: 'Emergency Alerts',
        color: AppColors.primary,
      ));
    }
    if (receivesLocationUpdates == true) {
      chips.add(_PermissionChip(
        label: 'Location Updates',
        color: const Color(0xFF1565C0),
      ));
    }
    if (receivesVulnerableModeAlerts == true) {
      chips.add(_PermissionChip(
        label: 'Protective Mode',
        color: AppColors.vulnerable,
        foreground: AppColors.black,
      ));
    }

    if (chips.isEmpty) return const [];

    return [
      const SizedBox(height: 10),
      Wrap(
        spacing: 8,
        runSpacing: 8,
        children: chips,
      ),
    ];
  }

  List<Widget> _buildActions(TextStyle baseStyle) {
    final actions = <Widget>[];

    if (onCall != null) {
      actions.add(_ActionIconButton(
        tooltip: 'Call',
        icon: Icons.call_outlined,
        onPressed: onCall,
      ));
    }
    if (onMessage != null) {
      actions.add(_ActionIconButton(
        tooltip: 'Message',
        icon: Icons.message_outlined,
        onPressed: onMessage,
      ));
    }
    if (onEdit != null) {
      actions.add(_ActionIconButton(
        tooltip: 'Edit',
        icon: Icons.edit_outlined,
        onPressed: onEdit,
      ));
    }
    if (onDelete != null) {
      actions.add(_ActionIconButton(
        tooltip: 'Delete',
        icon: Icons.delete_outline,
        onPressed: onDelete,
        color: AppColors.primary,
      ));
    }

    if (actions.isEmpty) return const [];

    return [
      const SizedBox(height: 8),
      Wrap(
        spacing: 8,
        children: actions,
      ),
    ];
  }

  @override
  Widget build(BuildContext context) {
    final displayName = _resolveName();
    final displayPhone = _resolvePhone();
    final displayRelationship = _resolveRelationship();
    final displayPriority = _resolvePriority();

    final baseTextStyle = Theme.of(context).textTheme.bodyMedium ??
        const TextStyle(fontSize: 14, fontFamily: 'Inter');

    final cardContent = Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  color: AppColors.primary.withValues(alpha: 0.1),
                  shape: BoxShape.circle,
                ),
                alignment: Alignment.center,
                child: Text(
                  trustee?.initials ?? _initialsFor(displayName),
                  style: const TextStyle(
                    fontFamily: 'Inter',
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                    color: AppColors.primary,
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            displayName,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              fontFamily: 'Inter',
                              fontSize: 16,
                              fontWeight: FontWeight.w700,
                              color: AppColors.black,
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        _PriorityBadge(
                          label: displayPriority,
                          backgroundColor: _priorityBackground(displayPriority),
                          foregroundColor: _priorityForeground(displayPriority),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(
                      displayRelationship,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: baseTextStyle.copyWith(
                        color: AppColors.textHint,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      displayPhone,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: baseTextStyle.copyWith(
                        color: AppColors.textHint,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          ..._buildPermissionChips(baseTextStyle),
          ..._buildActions(baseTextStyle),
        ],
      ),
    );

    return Semantics(
      button: onTap != null,
      label: 'Trusted contact $displayName',
      child: Material(
        color: const Color(0xFFFAFAFA),
        borderRadius: BorderRadius.circular(16),
        child: InkWell(
          borderRadius: BorderRadius.circular(16),
          onTap: onTap,
          child: Container(
            margin: const EdgeInsets.only(bottom: 12),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: AppColors.divider),
            ),
            child: cardContent,
          ),
        ),
      ),
    );
  }
}

class _PriorityBadge extends StatelessWidget {
  final String label;
  final Color backgroundColor;
  final Color foregroundColor;

  const _PriorityBadge({
    required this.label,
    required this.backgroundColor,
    required this.foregroundColor,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: backgroundColor,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontFamily: 'Inter',
          fontSize: 11,
          fontWeight: FontWeight.w700,
          color: foregroundColor,
        ),
      ),
    );
  }
}

class _PermissionChip extends StatelessWidget {
  final String label;
  final Color color;
  final Color foreground;

  const _PermissionChip({
    required this.label,
    required this.color,
    this.foreground = AppColors.white,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: color.withValues(alpha: 0.35)),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontFamily: 'Inter',
          fontSize: 11,
          fontWeight: FontWeight.w600,
          color: foreground,
        ),
      ),
    );
  }
}

class _ActionIconButton extends StatelessWidget {
  final String tooltip;
  final IconData icon;
  final VoidCallback? onPressed;
  final Color? color;

  const _ActionIconButton({
    required this.tooltip,
    required this.icon,
    this.onPressed,
    this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: tooltip,
      child: InkResponse(
        radius: 20,
        onTap: onPressed,
        child: Container(
          padding: const EdgeInsets.all(6),
          decoration: BoxDecoration(
            color: AppColors.white,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: AppColors.divider),
          ),
          child: Icon(
            icon,
            size: 18,
            color: color ?? AppColors.black,
          ),
        ),
      ),
    );
  }
}
