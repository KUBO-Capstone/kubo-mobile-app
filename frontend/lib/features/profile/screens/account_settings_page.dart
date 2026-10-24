import 'package:flutter/material.dart';

import '../../../core/constants/app_colors.dart';
import '../../../shared/data/profile_service.dart';
import 'edit_profile_page.dart';

class AccountSettingsPage extends StatefulWidget {
  const AccountSettingsPage({
    super.key,
    required this.user,
    required this.onLogout,
  });

  final Map<String, dynamic> user;
  final Future<void> Function() onLogout;

  @override
  State<AccountSettingsPage> createState() => _AccountSettingsPageState();
}

class _AccountSettingsPageState extends State<AccountSettingsPage> {
  late Map<String, dynamic> _user;
  final ProfileService _service = ProfileService();
  late Map<String, bool> _privacy;

  @override
  void initState() {
    super.initState();
    _user = Map<String, dynamic>.from(widget.user);
    _privacy = _parsePrivacy(_user['profile_privacy'] ?? const {
      'public_profile': true,
      'show_bio': true,
      'show_contact_number': true,
      'show_location': true,
    });
  }

  @override
  void dispose() {
    _service.dispose();
    super.dispose();
  }

  Map<String, bool> _parsePrivacy(dynamic value) {
    final defaults = <String, bool>{
      'public_profile': true,
      'show_bio': true,
      'show_contact_number': true,
      'show_location': true,
    };
    if (value is Map) {
      final source = Map<String, dynamic>.from(value);
      for (final entry in defaults.entries) {
        if (source[entry.key] is bool) {
          defaults[entry.key] = source[entry.key] as bool;
        }
      }
      return defaults;
    }
    return defaults;
  }

  Future<void> _editProfile() async {
    final updated = await Navigator.of(context).push<Map<String, dynamic>>(
      MaterialPageRoute<Map<String, dynamic>>(
        builder: (_) => EditProfilePage(user: _user),
      ),
    );
    if (updated != null && mounted) setState(() => _user = updated);
  }

  Future<void> _savePrivacy() async {
    try {
      final updated = await _service.updateProfile(
        userId: int.parse(_user['user_id'].toString()),
        firstName: (_user['first_name'] ?? '').toString().trim(),
        lastName: (_user['last_name'] ?? '').toString().trim(),
        contactNumber: (_user['contact_number'] ?? '').toString().trim(),
        bio: (_user['bio'] ?? '').toString().trim(),
        location: (_user['location'] ?? '').toString().trim(),
        businessName: (_user['business_name'] ?? '').toString().trim(),
        businessType: (_user['business_type'] ?? '').toString().trim(),
        profilePrivacy: _privacy,
      );
      if (!mounted) return;
      setState(() => _user = updated);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Profile privacy updated.')),
      );
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(error.toString().replaceFirst('Exception: ', ''))),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final name = '${_user['first_name'] ?? ''} ${_user['last_name'] ?? ''}'.trim();
    final email = _user['email']?.toString() ?? '';

    return PopScope<Map<String, dynamic>>(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (didPop) return;
        Navigator.of(context).pop(_user);
      },
      child: Scaffold(
      appBar: AppBar(title: const Text('Account settings')),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 28),
        children: [
          const Text('Account', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800, color: AppColors.black)),
          const SizedBox(height: 8),
          _SettingsTile(
            icon: Icons.person_outline,
            title: name.isEmpty ? 'Edit profile' : name,
            subtitle: 'Update your name, contact number, bio, or photo',
            onTap: _editProfile,
          ),
          _SettingsTile(
            icon: Icons.email_outlined,
            title: email,
            subtitle: 'Email address',
          ),
          const SizedBox(height: 24),
          const Text('Privacy', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800, color: AppColors.black)),
          const SizedBox(height: 8),
          SwitchListTile(
            value: _privacy['public_profile'] ?? true,
            contentPadding: const EdgeInsets.symmetric(horizontal: 4),
            title: const Text('Public profile'),
            subtitle: const Text('Allow other growers and shoppers to view your profile.'),
            onChanged: (value) => setState(() => _privacy['public_profile'] = value),
          ),
          SwitchListTile(
            value: _privacy['show_bio'] ?? true,
            contentPadding: const EdgeInsets.symmetric(horizontal: 4),
            title: const Text('Show bio'),
            subtitle: const Text('Display your bio on the About section.'),
            onChanged: (value) => setState(() => _privacy['show_bio'] = value),
          ),
          SwitchListTile(
            value: _privacy['show_contact_number'] ?? true,
            contentPadding: const EdgeInsets.symmetric(horizontal: 4),
            title: const Text('Show contact number'),
            subtitle: const Text('Make direct contact details visible to profile viewers.'),
            onChanged: (value) => setState(() => _privacy['show_contact_number'] = value),
          ),
          SwitchListTile(
            value: _privacy['show_location'] ?? true,
            contentPadding: const EdgeInsets.symmetric(horizontal: 4),
            title: const Text('Show location'),
            subtitle: const Text('Share your city and business location on your profile.'),
            onChanged: (value) => setState(() => _privacy['show_location'] = value),
          ),
          const SizedBox(height: 8),
          FilledButton.icon(
            onPressed: _savePrivacy,
            icon: const Icon(Icons.save_outlined),
            label: const Text('Save privacy'),
          ),
          const SizedBox(height: 24),
          const Text('Session', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800, color: AppColors.black)),
          const SizedBox(height: 8),
          _SettingsTile(
            icon: Icons.logout,
            title: 'Log out',
            subtitle: 'End this session on this device',
            onTap: widget.onLogout,
            destructive: true,
          ),
          const SizedBox(height: 24),
          const Text(
            'Your account settings are protected by your sign-in session. Contact support before changing account ownership or email details.',
            style: TextStyle(color: AppColors.gray, fontSize: 13, height: 1.4),
          ),
        ],
      ),
      ),
    );
  }
}

class _SettingsTile extends StatelessWidget {
  const _SettingsTile({
    required this.icon,
    required this.title,
    required this.subtitle,
    this.onTap,
    this.destructive = false,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback? onTap;
  final bool destructive;

  @override
  Widget build(BuildContext context) {
    final color = destructive ? Colors.red.shade700 : AppColors.black;
    return ListTile(
      contentPadding: const EdgeInsets.symmetric(horizontal: 4, vertical: 4),
      leading: Icon(icon, color: color),
      title: Text(title, style: TextStyle(color: color, fontWeight: FontWeight.w700)),
      subtitle: Text(subtitle),
      trailing: onTap == null ? null : const Icon(Icons.chevron_right),
      onTap: onTap,
    );
  }
}
