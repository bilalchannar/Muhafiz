import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:muhafiz/core/constants.dart';
import 'package:muhafiz/models/safety_mode_model.dart';
import 'package:muhafiz/providers/location_provider.dart';
import 'package:muhafiz/providers/mode_provider.dart';
import 'package:muhafiz/providers/trustees_provider.dart';
import 'package:muhafiz/providers/user_provider.dart';
import 'package:muhafiz/router.dart';

class ProfileScreen extends ConsumerWidget {
  const ProfileScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final user = ref.watch(userProvider);
    final modeState = ref.watch(modeProvider);
    final trustees = ref.watch(trusteesProvider);
    final location = ref.watch(locationProvider);

    final name = user?.name?.trim().isNotEmpty == true ? user!.name! : 'Muhafiz User';
    final phone = user?.phone?.trim().isNotEmpty == true ? user!.phone! : 'No phone number';
    final gender = user?.gender?.trim().isNotEmpty == true ? user!.gender! : 'Not specified';
    final bloodGroup = user?.bloodGroup?.trim().isNotEmpty == true ? user!.bloodGroup! : 'Not specified';
    final medicalNote = user?.medicalNote?.trim().isNotEmpty == true ? user!.medicalNote! : 'Not specified';
    
    final initials = _initialsFor(name);

    final modeLabel = switch (modeState.currentMode) {
      SafetyMode.vulnerable => 'Protective',
      SafetyMode.emergency => 'Emergency',
      SafetyMode.normal => 'Normal',
    };

    return Scaffold(
      backgroundColor: const Color(0xFFF8F9FB),
      appBar: AppBar(title: const Text('Profile')),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Profile',
                style: TextStyle(
                  fontFamily: 'Inter',
                  fontSize: 22,
                  fontWeight: FontWeight.w700,
                  color: AppColors.black,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                'View and manage your personal safety profile.',
                style: TextStyle(
                  fontFamily: 'Inter',
                  fontSize: 13,
                  color: AppColors.black.withValues(alpha: 0.6),
                ),
              ),
              const SizedBox(height: 16),
              _card(
                child: Row(
                  children: [
                    Container(
                      width: 64,
                      height: 64,
                      decoration: BoxDecoration(
                        color: AppColors.primary.withValues(alpha: 0.12),
                        shape: BoxShape.circle,
                      ),
                      alignment: Alignment.center,
                      child: Text(
                        initials,
                        style: const TextStyle(
                          fontFamily: 'Inter',
                          fontSize: 20,
                          fontWeight: FontWeight.w700,
                          color: AppColors.primary,
                        ),
                      ),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            name,
                            style: const TextStyle(
                              fontFamily: 'Inter',
                              fontSize: 16,
                              fontWeight: FontWeight.w700,
                              color: AppColors.black,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            phone,
                            style: TextStyle(
                              fontFamily: 'Inter',
                              fontSize: 13,
                              color: AppColors.black.withValues(alpha: 0.6),
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            gender,
                            style: TextStyle(
                              fontFamily: 'Inter',
                              fontSize: 12,
                              color: AppColors.black.withValues(alpha: 0.55),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              _sectionTitle('Profile information'),
              const SizedBox(height: 10),
              _card(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _infoRow('Full name', name),
                    const SizedBox(height: 8),
                    _infoRow('Phone number', phone),
                    const SizedBox(height: 8),
                    _infoRow('Gender', gender),
                    const SizedBox(height: 8),
                    _infoRow('Blood group', bloodGroup),
                    const SizedBox(height: 8),
                    _infoRow('Medical note', medicalNote),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              _sectionTitle('Safety summary'),
              const SizedBox(height: 10),
              _card(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _infoRow('Trusted contacts', '${trustees.length}'),
                    const SizedBox(height: 8),
                    _infoRow('Current safety mode', modeLabel),
                    const SizedBox(height: 8),
                    _infoRow('Last check-in', modeState.lastCheckInAt != null ? _formatDate(modeState.lastCheckInAt!) : 'Not available'),
                    const SizedBox(height: 8),
                    _infoRow('Location status', location.statusLabel),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              _sectionTitle('Quick actions'),
              const SizedBox(height: 10),
              _card(
                child: Column(
                  children: [
                    _actionTile(
                      label: 'Edit Profile',
                      icon: Icons.edit_outlined,
                      onTap: () => _showEditProfile(context, ref),
                    ),
                    const Divider(height: 1),
                    _actionTile(
                      label: 'Manage Trusted Contacts',
                      icon: Icons.people_outline,
                      onTap: () => Navigator.pushNamed(context, AppRoutes.contacts),
                    ),
                    const Divider(height: 1),
                    _actionTile(
                      label: 'View Alert History',
                      icon: Icons.notifications_active_outlined,
                      onTap: () => Navigator.pushNamed(context, AppRoutes.alertHistory),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  String _initialsFor(String value) {
    final parts = value.trim().split(RegExp(r'\s+'));
    if (parts.length >= 2) {
      return '${parts[0][0]}${parts[1][0]}'.toUpperCase();
    }
    return value.isNotEmpty ? value[0].toUpperCase() : 'U';
  }

  String _formatDate(DateTime date) {
    return '${date.day}/${date.month}/${date.year} ${date.hour}:${date.minute.toString().padLeft(2, '0')}';
  }

  void _showEditProfile(BuildContext context, WidgetRef ref) {
    final user = ref.read(userProvider);
    if (user == null) return;

    final nameController = TextEditingController(text: user.name);
    final bloodGroupController = TextEditingController(text: user.bloodGroup);
    final medicalNoteController = TextEditingController(text: user.medicalNote);
    String selectedGender = user.gender ?? 'Male';

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppColors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (_) => Padding(
        padding: EdgeInsets.only(
          bottom: MediaQuery.of(context).viewInsets.bottom,
          left: 20,
          right: 20,
          top: 20,
        ),
        child: StatefulBuilder(
          builder: (context, setModalState) {
            return SafeArea(
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Edit Profile',
                      style: TextStyle(
                        fontFamily: 'Inter',
                        fontSize: 18,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 16),
                    TextFormField(
                      controller: nameController,
                      decoration: const InputDecoration(labelText: 'Name'),
                    ),
                    const SizedBox(height: 12),
                    DropdownButtonFormField<String>(
                      initialValue: selectedGender,
                      items: ['Male', 'Female', 'Other']
                          .map((e) => DropdownMenuItem(value: e, child: Text(e)))
                          .toList(),
                      onChanged: (v) => setModalState(() => selectedGender = v!),
                      decoration: const InputDecoration(labelText: 'Gender'),
                    ),
                    const SizedBox(height: 12),
                    TextFormField(
                      controller: bloodGroupController,
                      decoration: const InputDecoration(labelText: 'Blood Group'),
                    ),
                    const SizedBox(height: 12),
                    TextFormField(
                      controller: medicalNoteController,
                      decoration: const InputDecoration(labelText: 'Medical Note'),
                      maxLines: 2,
                    ),
                    const SizedBox(height: 20),
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.primary,
                          foregroundColor: AppColors.white,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        ),
                        onPressed: () async {
                          await ref.read(userProvider.notifier).updateProfile(
                                name: nameController.text.trim(),
                                gender: selectedGender,
                                bloodGroup: bloodGroupController.text.trim(),
                                medicalNote: medicalNoteController.text.trim(),
                              );
                          if (context.mounted) Navigator.pop(context);
                        },
                        child: const Text('Save Changes'),
                      ),
                    ),
                    const SizedBox(height: 12),
                  ],
                ),
              ),
            );
          },
        ),
      ),
    );
  }

  Widget _card({required Widget child}) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.divider),
      ),
      child: child,
    );
  }

  Widget _sectionTitle(String title) {
    return Text(
      title,
      style: const TextStyle(
        fontFamily: 'Inter',
        fontSize: 16,
        fontWeight: FontWeight.w700,
        color: AppColors.black,
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
        Flexible(
          child: Text(
            value,
            textAlign: TextAlign.right,
            style: const TextStyle(
              fontFamily: 'Inter',
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: AppColors.black,
            ),
          ),
        ),
      ],
    );
  }

  Widget _actionTile({
    required String label,
    required IconData icon,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 10),
        child: Row(
          children: [
            Icon(icon, color: AppColors.primary, size: 20),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                label,
                style: const TextStyle(
                  fontFamily: 'Inter',
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
            const Icon(Icons.chevron_right, color: AppColors.textHint),
          ],
        ),
      ),
    );
  }
}
