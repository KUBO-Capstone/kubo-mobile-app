import 'package:flutter/material.dart';

import '../../../core/constants/app_colors.dart';
import '../../../shared/data/profile_service.dart';
import '../../login/services/auth_service.dart';
import 'edit_profile_page.dart';
import 'change_password_page.dart';
import 'fulfillment_settings_page.dart';

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

  bool _isSignedInUser(Map<String, dynamic>? user) =>
      user != null && user['user_id']?.toString() == _user['user_id']?.toString();

  // What goes back to the profile page on the way out: the signed-in user as
  // it is now, not the copy this page opened with. A session refresh may have
  // updated it meanwhile, and the profile edit and privacy save above both
  // write their results to it.
  Map<String, dynamic> _latestUser() {
    final current = AuthService.currentUser;
    return _isSignedInUser(current) ? Map<String, dynamic>.of(current!) : _user;
  }

  Future<void> _editProfile() async {
    final updated = await Navigator.of(context).push<Map<String, dynamic>>(
      MaterialPageRoute<Map<String, dynamic>>(
        builder: (_) => EditProfilePage(user: _user),
      ),
    );
    if (updated == null) return;
    // The app's copy of the signed-in user too: a contact number and
    // address saved here are what let the account make offers and list.
    AuthService.updateCurrentUser(updated);
    if (mounted) setState(() => _user = updated);
  }

  bool _savingPrivacy = false;

  // Each switch saves as soon as it is flipped, and flips back if the save
  // fails, so what the switches show is always what visitors get.
  Future<void> _setPrivacy(String key, bool value) async {
    final before = Map<String, bool>.of(_privacy);
    setState(() => _privacy[key] = value);
    final saved = await _savePrivacy();
    if (!saved && mounted) setState(() => _privacy = before);
  }

  Future<bool> _savePrivacy() async {
    setState(() => _savingPrivacy = true);
    // The rest of the profile goes along as it is now, not as this page
    // opened with it: a contact number saved from elsewhere meanwhile must
    // not be put back to the old one.
    final current = _latestUser();
    try {
      final updated = await _service.updateProfile(
        userId: int.parse(current['user_id'].toString()),
        firstName: (current['first_name'] ?? '').toString().trim(),
        lastName: (current['last_name'] ?? '').toString().trim(),
        contactNumber: (current['contact_number'] ?? '').toString().trim(),
        bio: (current['bio'] ?? '').toString().trim(),
        location: (current['location'] ?? '').toString().trim(),
        businessName: (current['business_name'] ?? '').toString().trim(),
        businessType: (current['business_type'] ?? '').toString().trim(),
        profilePrivacy: _privacy,
      );
      // Only the privacy goes onto the signed-in user, so _latestUser hands
      // it back. The rest of this answer is the profile as this page sent it
      // and could be older than what the signed-in user holds by now.
      final privacy = updated['profile_privacy'];
      if (privacy != null && _isSignedInUser(AuthService.currentUser)) {
        AuthService.updateCurrentUser({'profile_privacy': privacy});
      }
      if (!mounted) return true;
      setState(() => _user = updated);
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(const SnackBar(content: Text('Privacy saved.'), duration: Duration(seconds: 2)));
      return true;
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(error.toString().replaceFirst('Exception: ', ''))),
        );
      }
      return false;
    } finally {
      if (mounted) setState(() => _savingPrivacy = false);
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
        Navigator.of(context).pop(_latestUser());
      },
      child: Scaffold(
      appBar: AppBar(title: const Text('Account Settings')),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 28),
        children: [
          const Text('Account', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800, color: AppColors.black)),
          const SizedBox(height: 8),
          _SettingsTile(
            icon: Icons.person_outline,
            title: name.isEmpty ? 'Edit Profile' : name,
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
          const Text(
            'Changes save as soon as you flip a switch. Your listings stay visible in search either way.',
            style: TextStyle(color: AppColors.gray, fontSize: 12),
          ),
          SwitchListTile(
            value: _privacy['public_profile'] ?? true,
            contentPadding: const EdgeInsets.symmetric(horizontal: 4),
            title: const Text('Public Profile'),
            subtitle: const Text(
              'Off: others see only your name and photo, with a note that your profile is private.',
            ),
            onChanged: _savingPrivacy ? null : (value) => _setPrivacy('public_profile', value),
          ),
          // Only matter while the profile is public; greyed out otherwise.
          for (final (key, title, subtitle) in const [
            ('show_bio', 'Show Bio', 'Your bio in the About tab.'),
            ('show_contact_number', 'Show Contact Number', 'Your number in the About tab, so buyers can call or text you.'),
            ('show_location', 'Show Location', 'Your town and addresses on your profile.'),
          ])
            SwitchListTile(
              value: _privacy[key] ?? true,
              contentPadding: const EdgeInsets.symmetric(horizontal: 4),
              title: Text(title),
              subtitle: Text(subtitle),
              onChanged: _savingPrivacy || _privacy['public_profile'] == false
                  ? null
                  : (value) => _setPrivacy(key, value),
            ),
          const SizedBox(height: 24),
          const Text('Selling', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800, color: AppColors.black)),
          const SizedBox(height: 8),
          _SettingsTile(
            icon: Icons.local_shipping_outlined,
            title: 'Pickup & Delivery',
            subtitle: 'Bagsakan centers and couriers buyers can choose',
            onTap: () => Navigator.of(context).push(
              MaterialPageRoute<void>(
                builder: (_) => FulfillmentSettingsPage.profile(userId: int.parse(_user['user_id'].toString())),
              ),
            ),
          ),
          const SizedBox(height: 24),
          const Text('Security', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800, color: AppColors.black)),
          const SizedBox(height: 8),
          _SettingsTile(
            icon: Icons.lock_outline,
            title: 'Change Password',
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
            title: 'Log Out',
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
