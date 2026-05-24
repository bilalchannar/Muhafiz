import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:muhafiz/core/constants.dart';
import 'package:muhafiz/providers/trustees_provider.dart';
import 'package:muhafiz/widgets/primary_button.dart';
import 'package:muhafiz/widgets/trustee_card.dart';
import 'package:muhafiz/models/trustee_model.dart';

class ContactsScreen extends ConsumerStatefulWidget {
  const ContactsScreen({super.key});

  @override
  ConsumerState<ContactsScreen> createState() => _ContactsScreenState();
}

class _ContactsScreenState extends ConsumerState<ContactsScreen> {
  final _searchController = TextEditingController();

  @override
  void initState() {
    super.initState();
    Future.microtask(() => ref.read(trusteesProvider.notifier).fetchTrustees());
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  void _showAddForm() {
    final formKey = GlobalKey<FormState>();
    final nameController = TextEditingController();
    final phoneController = TextEditingController(text: '+92');
    String selectedRelationship = 'Friend';
    String selectedPriority = 'Secondary';
    bool isFormValid = false;

    void updateFormState(StateSetter setModalState) {
      final nameOk = nameController.text.trim().isNotEmpty;
      final cleaned = phoneController.text.replaceAll(RegExp(r'[\s\-]'), '');
      final phoneOk = RegExp(r'^\+92\d{10}$').hasMatch(cleaned);
      final nextValid = nameOk && phoneOk;
      if (nextValid != isFormValid) {
        setModalState(() => isFormValid = nextValid);
      }
    }

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
                child: Form(
                  key: formKey,
                  onChanged: () => updateFormState(setModalState),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Add Trusted Contact',
                        style: TextStyle(
                          fontFamily: 'Inter',
                          fontSize: 18,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        'This contact will receive your safety alerts.',
                        style: TextStyle(
                          fontFamily: 'Inter',
                          fontSize: 12,
                          color: AppColors.black.withValues(alpha: 0.6),
                        ),
                      ),
                      const SizedBox(height: 16),
                      TextFormField(
                        controller: nameController,
                        validator: (v) => v == null || v.trim().isEmpty
                            ? 'Name is required'
                            : null,
                        decoration: const InputDecoration(
                          labelText: 'Name',
                          prefixIcon: Icon(Icons.person_outline),
                        ),
                      ),
                      const SizedBox(height: 12),
                      TextFormField(
                        controller: phoneController,
                        keyboardType: TextInputType.phone,
                        validator: (v) {
                          if (v == null || v.trim().isEmpty) {
                            return 'WhatsApp number is required';
                          }
                          final cleaned = v.replaceAll(RegExp(r'[\s\-]'), '');
                          if (!RegExp(r'^\+92\d{10}$').hasMatch(cleaned)) {
                            return 'Enter valid number like +923001234567';
                          }
                          return null;
                        },
                        decoration: const InputDecoration(
                          labelText: 'WhatsApp Number',
                          hintText: '+923001234567',
                          prefixIcon: Icon(Icons.phone_outlined),
                        ),
                      ),
                      const SizedBox(height: 12),
                      DropdownButtonFormField<String>(
                        initialValue: selectedRelationship,
                        items:
                            const [
                                  'Father',
                                  'Mother',
                                  'Brother',
                                  'Sister',
                                  'Friend',
                                  'Guardian',
                                  'Other',
                                ]
                                .map(
                                  (relation) => DropdownMenuItem<String>(
                                    value: relation,
                                    child: Text(relation),
                                  ),
                                )
                                .toList(),
                        onChanged: (value) {
                          if (value != null) {
                            setModalState(() => selectedRelationship = value);
                          }
                        },
                        decoration: const InputDecoration(
                          labelText: 'Relationship',
                        ),
                      ),
                      const SizedBox(height: 12),
                      DropdownButtonFormField<String>(
                        initialValue: selectedPriority,
                        items: const ['Primary', 'Secondary', 'Backup']
                            .map(
                              (priority) => DropdownMenuItem<String>(
                                value: priority,
                                child: Text(priority),
                              ),
                            )
                            .toList(),
                        onChanged: (value) {
                          if (value != null) {
                            setModalState(() => selectedPriority = value);
                          }
                        },
                        decoration: const InputDecoration(
                          labelText: 'Priority',
                        ),
                      ),
                      const SizedBox(height: 18),
                      PrimaryButton(
                        text: 'Add Contact',
                        isDisabled: !isFormValid,
                        onPressed: () async {
                          final navigator = Navigator.of(context);
                          final messenger = ScaffoldMessenger.of(context);
                          if (!formKey.currentState!.validate()) return;
                          try {
                            await ref
                                .read(trusteesProvider.notifier)
                                .addTrustee(
                                  name: nameController.text.trim(),
                                  phone: phoneController.text.trim(),
                                  tier: selectedPriority,
                                );
                          } catch (e) {
                            if (!context.mounted) return;
                            final message = e.toString().contains('own number')
                                ? 'You cannot add your own number as a trustee.'
                                : 'This phone number is already added.';
                            messenger.showSnackBar(
                              SnackBar(content: Text(message)),
                            );
                            return;
                          }
                          if (!context.mounted) return;
                          messenger.showSnackBar(
                            const SnackBar(content: Text('Contact added')),
                          );
                          navigator.pop();
                        },
                      ),
                      const SizedBox(height: 12),
                    ],
                  ),
                ),
              ),
            );
          },
        ),
      ),
    );
  }

  void _showEditForm(TrusteeModel trustee) {
    final formKey = GlobalKey<FormState>();
    final nameController = TextEditingController(text: trustee.name);
    final phoneController = TextEditingController(text: trustee.phone);
    String selectedRelationship = trustee.relationship;

    // Ensure the initial relationship value exists in the dropdown items
    const validRelationships = [
      'Father',
      'Mother',
      'Brother',
      'Sister',
      'Friend',
      'Guardian',
      'Contact',
      'Other',
    ];
    if (!validRelationships.contains(selectedRelationship)) {
      selectedRelationship = 'Contact';
    }

    // Capitalize priority since the dropdown items are capitalized
    String selectedPriority = trustee.priority.isNotEmpty
        ? trustee.priority[0].toUpperCase() +
              trustee.priority.substring(1).toLowerCase()
        : 'Secondary';

    bool isFormValid = true;

    void updateFormState(StateSetter setModalState) {
      final nameOk = nameController.text.trim().isNotEmpty;
      final cleaned = phoneController.text.replaceAll(RegExp(r'[\s\-]'), '');
      final phoneOk = RegExp(r'^\+92\d{10}$').hasMatch(cleaned);
      final nextValid = nameOk && phoneOk;
      if (nextValid != isFormValid) {
        setModalState(() => isFormValid = nextValid);
      }
    }

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
                child: Form(
                  key: formKey,
                  onChanged: () => updateFormState(setModalState),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Edit Trusted Contact',
                        style: TextStyle(
                          fontFamily: 'Inter',
                          fontSize: 18,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(height: 16),
                      TextFormField(
                        controller: nameController,
                        validator: (v) => v == null || v.trim().isEmpty
                            ? 'Name is required'
                            : null,
                        decoration: const InputDecoration(
                          labelText: 'Name',
                          prefixIcon: Icon(Icons.person_outline),
                        ),
                      ),
                      const SizedBox(height: 12),
                      TextFormField(
                        controller: phoneController,
                        keyboardType: TextInputType.phone,
                        validator: (v) {
                          if (v == null || v.trim().isEmpty) {
                            return 'WhatsApp number is required';
                          }
                          final cleaned = v.replaceAll(RegExp(r'[\s\-]'), '');
                          if (!RegExp(r'^\+92\d{10}$').hasMatch(cleaned)) {
                            return 'Enter valid number like +923001234567';
                          }
                          return null;
                        },
                        decoration: const InputDecoration(
                          labelText: 'WhatsApp Number',
                          hintText: '+923001234567',
                          prefixIcon: Icon(Icons.phone_outlined),
                        ),
                      ),
                      const SizedBox(height: 12),
                      DropdownButtonFormField<String>(
                        initialValue: selectedRelationship,
                        items: validRelationships
                            .map(
                              (relation) => DropdownMenuItem<String>(
                                value: relation,
                                child: Text(relation),
                              ),
                            )
                            .toList(),
                        onChanged: (value) {
                          if (value != null) {
                            setModalState(() => selectedRelationship = value);
                          }
                        },
                        decoration: const InputDecoration(
                          labelText: 'Relationship',
                        ),
                      ),
                      const SizedBox(height: 12),
                      DropdownButtonFormField<String>(
                        initialValue: selectedPriority,
                        items: const ['Primary', 'Secondary', 'Backup']
                            .map(
                              (priority) => DropdownMenuItem<String>(
                                value: priority,
                                child: Text(priority),
                              ),
                            )
                            .toList(),
                        onChanged: (value) {
                          if (value != null) {
                            setModalState(() => selectedPriority = value);
                          }
                        },
                        decoration: const InputDecoration(
                          labelText: 'Priority',
                        ),
                      ),
                      const SizedBox(height: 18),
                      PrimaryButton(
                        text: 'Save Changes',
                        isDisabled: !isFormValid,
                        onPressed: () async {
                          final navigator = Navigator.of(context);
                          final messenger = ScaffoldMessenger.of(context);
                          if (!formKey.currentState!.validate()) return;
                          try {
                            final updated = trustee.copyWith(
                              name: nameController.text.trim(),
                              phone: phoneController.text.trim(),
                              priority: selectedPriority.toLowerCase(),
                              relationship: selectedRelationship,
                            );
                            await ref
                                .read(trusteesProvider.notifier)
                                .updateTrustee(updated);
                          } catch (e) {
                            if (!context.mounted) return;
                            messenger.showSnackBar(
                              SnackBar(content: Text(e.toString())),
                            );
                            return;
                          }
                          if (!context.mounted) return;
                          messenger.showSnackBar(
                            const SnackBar(content: Text('Contact updated')),
                          );
                          navigator.pop();
                        },
                      ),
                      const SizedBox(height: 12),
                    ],
                  ),
                ),
              ),
            );
          },
        ),
      ),
    );
  }

  Future<void> _confirmDelete(String id, String name) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Remove trusted contact?'),
        content: const Text(
          'This person will no longer receive your emergency alerts.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text(
              'Remove',
              style: TextStyle(color: AppColors.primary),
            ),
          ),
        ],
      ),
    );

    if (confirmed != true) return;
    await ref.read(trusteesProvider.notifier).deleteTrustee(id);
    if (!mounted) return;
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text('$name removed')));
  }

  @override
  Widget build(BuildContext context) {
    final trustees = ref.watch(trusteesProvider);
    final hasContacts = trustees.isNotEmpty;
    final query = _searchController.text.trim().toLowerCase();
    final filteredTrustees = query.isEmpty
        ? trustees
        : trustees
              .where(
                (t) =>
                    t.name.toLowerCase().contains(query) ||
                    t.phone.toLowerCase().contains(query),
              )
              .toList();

    return Scaffold(
      backgroundColor: const Color(0xFFF8F9FB),
      appBar: AppBar(
        title: const Text(
          'Trusted Contacts',
          style: TextStyle(
            fontFamily: 'Inter',
            fontSize: 18,
            fontWeight: FontWeight.w700,
            color: AppColors.black,
          ),
        ),
        centerTitle: false,
        backgroundColor: AppColors.white,
        elevation: 0,
        scrolledUnderElevation: 0,
        actions: [
          IconButton(
            onPressed: _showAddForm,
            icon: const Icon(Icons.add, color: AppColors.primary, size: 26),
            tooltip: 'Add contact',
          ),
          const SizedBox(width: 4),
        ],
      ),
      body: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 12, 20, 12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'These people will be notified during emergency or protective mode.',
                    style: TextStyle(
                      fontFamily: 'Inter',
                      fontSize: 12,
                      color: AppColors.black.withValues(alpha: 0.6),
                    ),
                  ),
                  const SizedBox(height: 12),
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: AppColors.white,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: AppColors.divider),
                    ),
                    child: Row(
                      children: [
                        Container(
                          width: 42,
                          height: 42,
                          decoration: BoxDecoration(
                            color: AppColors.primary.withValues(alpha: 0.12),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          alignment: Alignment.center,
                          child: Icon(
                            Icons.people_outline,
                            color: AppColors.primary,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                '${trustees.length} trusted contact${trustees.length == 1 ? '' : 's'}',
                                style: const TextStyle(
                                  fontFamily: 'Inter',
                                  fontSize: 14,
                                  fontWeight: FontWeight.w700,
                                  color: AppColors.black,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                'Add at least 2 trusted contacts for better safety.',
                                style: TextStyle(
                                  fontFamily: 'Inter',
                                  fontSize: 12,
                                  color: hasContacts
                                      ? AppColors.black.withValues(alpha: 0.6)
                                      : AppColors.primary,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: _searchController,
                    onChanged: (_) => setState(() {}),
                    decoration: const InputDecoration(
                      labelText: 'Search contacts',
                      prefixIcon: Icon(Icons.search),
                    ),
                  ),
                ],
              ),
            ),
            Expanded(
              child: trustees.isEmpty
                  ? _buildEmptyState()
                  : filteredTrustees.isEmpty
                  ? _buildSearchEmpty()
                  : ListView.builder(
                      padding: const EdgeInsets.fromLTRB(20, 4, 20, 24),
                      itemCount: filteredTrustees.length,
                      itemBuilder: (_, i) {
                        final trustee = filteredTrustees[i];
                        return Dismissible(
                          key: ValueKey(trustee.id),
                          direction: DismissDirection.endToStart,
                          background: Container(
                            margin: const EdgeInsets.only(bottom: 12),
                            alignment: Alignment.centerRight,
                            padding: const EdgeInsets.only(right: 20),
                            decoration: BoxDecoration(
                              color: AppColors.primary,
                              borderRadius: BorderRadius.circular(14),
                            ),
                            child: const Icon(
                              Icons.delete,
                              color: AppColors.white,
                            ),
                          ),
                          confirmDismiss: (_) async {
                            await _confirmDelete(trustee.id, trustee.name);
                            return false;
                          },
                          child: TrusteeCard(
                            trustee: trustee,
                            relationship: trustee.relationship,
                            priority: trustee.tier,
                            receivesEmergencyAlerts: true,
                            receivesLocationUpdates: false,
                            receivesVulnerableModeAlerts: true,
                            onEdit: () => _showEditForm(trustee),
                            onDelete: () =>
                                _confirmDelete(trustee.id, trustee.name),
                          ),
                        );
                      },
                    ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 40),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.shield_outlined,
              size: 72,
              color: AppColors.black.withValues(alpha: 0.15),
            ),
            const SizedBox(height: 20),
            const Text(
              'No trusted contacts added yet.',
              style: TextStyle(
                fontFamily: 'Inter',
                fontSize: 18,
                fontWeight: FontWeight.w600,
                color: AppColors.black,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Add someone you trust so Muhafiz can notify them during emergencies.',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontFamily: 'Inter',
                fontSize: 14,
                color: AppColors.black.withValues(alpha: 0.5),
              ),
            ),
            const SizedBox(height: 28),
            SizedBox(
              width: 200,
              child: PrimaryButton(
                text: 'Add Contact',
                onPressed: _showAddForm,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSearchEmpty() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 40),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.search_off,
              size: 64,
              color: AppColors.black.withValues(alpha: 0.2),
            ),
            const SizedBox(height: 12),
            const Text(
              'No contacts found.',
              style: TextStyle(
                fontFamily: 'Inter',
                fontSize: 16,
                fontWeight: FontWeight.w600,
                color: AppColors.black,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
