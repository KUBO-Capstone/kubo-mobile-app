import 'package:flutter/material.dart';

import '../../../core/constants/app_assets.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/widgets/app_svg_icon.dart';
import '../../../shared/data/profile_records.dart';
import '../../../shared/data/profile_service.dart';

/// Profile header card that sits on top of the profile content.
class ProfileHeaderCard extends StatelessWidget {
  const ProfileHeaderCard({
    super.key,
    required this.profile,
    required this.isOwnProfile,
    required this.onEditProfile,
    required this.onShare,
    required this.onSettings,
    required this.onFollow,
    required this.onMessage,
    required this.onChangePhoto,
  });

  /// Shared profile record shown in the header.
  final SyntheticProfileRecord profile;

  /// Whether the header should render owner-specific actions.
  final bool isOwnProfile;

  /// Opens the edit profile flow.
  final VoidCallback onEditProfile;

  /// Opens the share action.
  final VoidCallback onShare;

  /// Opens settings for the profile owner.
  final VoidCallback onSettings;

  /// Follows the visitor profile.
  final VoidCallback onFollow;

  /// Sends a message to the visitor profile.
  final VoidCallback onMessage;
  final VoidCallback onChangePhoto;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.fromLTRB(16, 0, 16, 0),
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 18),
      decoration: BoxDecoration(
        color: AppColors.white,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: AppColors.border),
        boxShadow: const [
          BoxShadow(
            color: Color(0x12000000),
            blurRadius: 20,
            offset: Offset(0, 6),
          ),
        ],
      ),
      child: Column(
        children: [
          Row(
            children: [
              if (isOwnProfile)
                _HeaderActionButton(
                  label: 'Edit profile',
                  icon: Icons.edit_outlined,
                  onTap: onEditProfile,
                )
              else
                _HeaderActionButton(label: 'Follow', onTap: onFollow),
              const Spacer(),
              if (isOwnProfile) ...[
                _CircularIconButton(icon: Icons.share_outlined, onTap: onShare),
                const SizedBox(width: 8),
                _CircularIconButton(
                  icon: Icons.settings_outlined,
                  onTap: onSettings,
                ),
              ] else
                _HeaderActionButton(label: 'Message', onTap: onMessage),
            ],
          ),
          _ProfileAvatar(photoUrl: profile.photoUrl, onTap: isOwnProfile ? onChangePhoto : null),
          const SizedBox(height: 10),
          Text(
            profile.displayName,
            style: const TextStyle(
              color: AppColors.black,
              fontSize: 18,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            profile.username,
            style: const TextStyle(
              color: AppColors.black,
              fontSize: 14,
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: 22),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              _ProfileStatValue(
                value: profile.followingCount.toString(),
                label: 'Following',
              ),
              _ProfileStatValue(
                value: profile.followersCount.toString(),
                label: 'Followers',
              ),
              _ProfileStatValue(
                value: profile.listingCount.toString(),
                label: 'Listings',
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _ProfileAvatar extends StatelessWidget {
  const _ProfileAvatar({required this.photoUrl, this.onTap});

  final String photoUrl;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final avatar = Container(
      width: 104,
      height: 85,
      decoration: const BoxDecoration(
        shape: BoxShape.circle,
        color: Color(0xFFF3F3F3),
      ),
      child: photoUrl.isEmpty
          ? const Center(child: AppSvgIcon(assetPath: AppIcons.circleUserProfile, size: 76, color: AppColors.black))
          : ClipOval(child: Image.network(resolveProfilePhotoUrl(photoUrl), width: 104, height: 104, fit: BoxFit.cover, errorBuilder: (_, __, ___) => const AppSvgIcon(assetPath: AppIcons.circleUserProfile, size: 76, color: AppColors.black))),
    );
    return onTap == null ? avatar : GestureDetector(onTap: onTap, child: avatar);
  }
}

class _ProfileStatValue extends StatelessWidget {
  const _ProfileStatValue({required this.value, required this.label});

  final String value;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Text(
          value,
          style: const TextStyle(
            color: AppColors.black,
            fontSize: 14,
            fontWeight: FontWeight.w700,
          ),
        ),
        const SizedBox(height: 2),
        Text(
          label,
          style: const TextStyle(color: AppColors.gray, fontSize: 14),
        ),
      ],
    );
  }
}

class _HeaderActionButton extends StatelessWidget {
  const _HeaderActionButton({
    required this.label,
    required this.onTap,
    this.icon,
  });

  final String label;
  final IconData? icon;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return OutlinedButton(
      onPressed: onTap,
      style: OutlinedButton.styleFrom(
        foregroundColor: AppColors.gray,
        side: const BorderSide(color: AppColors.border),
        shape: const StadiumBorder(),
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 12),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icon != null) ...[Icon(icon, size: 16), const SizedBox(width: 8)],
          Text(label, style: const TextStyle(fontSize: 12)),
        ],
      ),
    );
  }
}

class _CircularIconButton extends StatelessWidget {
  const _CircularIconButton({required this.icon, required this.onTap});

  final IconData icon;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkResponse(
      onTap: onTap,
      radius: 20,
      child: Container(
        width: 40,
        height: 40,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          border: Border.all(color: AppColors.border),
        ),
        child: Center(child: Icon(icon, size: 18, color: AppColors.gray)),
      ),
    );
  }
}
