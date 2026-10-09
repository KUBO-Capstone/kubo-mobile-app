import 'package:flutter/material.dart';

import '../../../core/constants/app_colors.dart';
import 'edit_profile_page.dart';
import 'change_password_page.dart';

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

  @override
  void initState() {
    super.initState();
    _user = Map<String, dynamic>.from(widget.user);
  }

  Future<void> _editProfile() async {
    final updated = await Navigator.of(context).push<Map<String, dynamic>>(
      MaterialPageRoute<Map<String, dynamic>>(
        builder: (_) => EditProfilePage(user: _user),
      ),
    );
    if (updated != null && mounted) setState(() => _user = updated);
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
          const Text('Security', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800, color: AppColors.black)),
          const SizedBox(height: 8),
          _SettingsTile(
            icon: Icons.lock_outline,
            title: 'Change password',
            subtitle: 'Update your sign-in password',
            onTap: () => Navigator.of(context).push(
              MaterialPageRoute<void>(
                builder: (_) => ChangePasswordPage(userId: int.parse(_user['user_id'].toString())),
              ),
            ),
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
