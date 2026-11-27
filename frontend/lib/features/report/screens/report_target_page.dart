import 'package:flutter/material.dart';

import '../../../core/constants/app_colors.dart';
import '../../../shared/data/profile_records.dart';
import '../../../shared/data/profile_service.dart';
import '../../../shared/data/synthetic_records.dart';
import '../../../shared/widgets/kubo_image.dart';
import '../../login/services/auth_service.dart';
import '../providers/report_provider.dart';

/// Reporting a listing or a profile: what is being reported at the top, the
/// user's reason under it, and Submit at the bottom. Reached from the kebab
/// menu on the listing page and on a profile.
///
/// Pops with `true` once the report is filed.
class ReportTargetPage extends StatefulWidget {
  const ReportTargetPage.listing({super.key, required SyntheticListingRecord this.listing})
      : userId = null,
        profile = null;

  const ReportTargetPage.profile({super.key, required int this.userId, required SyntheticProfileRecord this.profile})
      : listing = null;

  final SyntheticListingRecord? listing;
  final int? userId;
  final SyntheticProfileRecord? profile;

  bool get isListing => listing != null;

  /// Opens [page] and, once a report is filed, thanks the user. Asks them to
  /// log in first when they are not.
  static Future<void> open(BuildContext context, ReportTargetPage page) async {
    final messenger = ScaffoldMessenger.of(context);
    if (AuthService.currentUserId == null) {
      messenger.showSnackBar(
        SnackBar(content: Text('Log in to report ${page.isListing ? 'a listing' : 'a profile'}.')),
      );
      return;
    }
    final filed = await Navigator.of(context).push<bool>(MaterialPageRoute<bool>(builder: (_) => page));
    if (filed == true) {
      messenger.showSnackBar(
        const SnackBar(content: Text('Thanks for your report. We will look into it.')),
      );
    }
  }

  @override
  State<ReportTargetPage> createState() => _ReportTargetPageState();
}

class _ReportTargetPageState extends State<ReportTargetPage> {
  static const _reasonMax = 1000;

  final _reason = TextEditingController();
  final _service = ReportService();
  bool _submitting = false;

  /// Under the reason field: nothing written yet when Submit was tapped.
  String? _reasonError;

  /// Above the button: the server refused it (already reported, say).
  String? _error;

  @override
  void dispose() {
    _reason.dispose();
    _service.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final reason = _reason.text.trim();
    if (reason.isEmpty) {
      setState(() => _reasonError = 'Tell us why you are reporting this.');
      return;
    }
    setState(() {
      _submitting = true;
      _error = null;
    });
    try {
      if (widget.isListing) {
        await _service.reportListing(productId: widget.listing!.productId!, reason: reason);
      } else {
        await _service.reportUser(userId: widget.userId!, reason: reason);
      }
      if (mounted) Navigator.of(context).pop(true);
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _submitting = false;
        _error = error.toString().replaceFirst('Exception: ', '');
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final what = widget.isListing ? 'listing' : 'profile';
    return Scaffold(
      backgroundColor: AppColors.white,
      appBar: AppBar(
        backgroundColor: AppColors.white,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        centerTitle: true,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new, size: 18, color: AppColors.black),
          tooltip: 'Back',
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: Text(
          'REPORT ${what.toUpperCase()}',
          style: const TextStyle(color: AppColors.black, fontSize: 14, fontWeight: FontWeight.w700, letterSpacing: 1.2),
        ),
      ),
      // The button is part of the body, not a bottom bar, so it rides up
      // above the keyboard while the reason is being typed.
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: ListView(
                padding: const EdgeInsets.fromLTRB(20, 8, 20, 16),
                children: [
                  const Text(
                    'You are reporting',
                    style: TextStyle(color: AppColors.gray, fontSize: 13, fontWeight: FontWeight.w600),
                  ),
                  const SizedBox(height: 8),
                  widget.isListing ? _ListingSummary(listing: widget.listing!) : _ProfileSummary(profile: widget.profile!),
                  const SizedBox(height: 24),
                  Text(
                    'Why are you reporting this $what?',
                    style: const TextStyle(color: AppColors.black, fontSize: 16, fontWeight: FontWeight.w800),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    widget.isListing
                        ? 'For example: misleading photos or details, a price that is not real, or produce that is not allowed.'
                        : 'For example: a scam, asking to be paid outside the app, harassment, or a fake account.',
                    style: const TextStyle(color: AppColors.gray, fontSize: 13, height: 1.4),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: _reason,
                    enabled: !_submitting,
                    minLines: 5,
                    maxLines: 8,
                    maxLength: _reasonMax,
                    textCapitalization: TextCapitalization.sentences,
                    onChanged: (_) {
                      if (_reasonError != null || _error != null) {
                        setState(() {
                          _reasonError = null;
                          _error = null;
                        });
                      }
                    },
                    style: const TextStyle(color: AppColors.black, fontSize: 15, height: 1.4),
                    decoration: InputDecoration(
                      hintText: 'Write your reason',
                      hintStyle: const TextStyle(color: AppColors.gray, fontSize: 15),
                      filled: true,
                      fillColor: AppColors.softBackground,
                      contentPadding: const EdgeInsets.all(16),
                      errorText: _reasonError,
                      errorStyle: const TextStyle(color: Colors.redAccent, fontSize: 13, fontWeight: FontWeight.w600),
                      border: _border(null),
                      enabledBorder: _border(null),
                      focusedBorder: _border(AppColors.green),
                      errorBorder: _border(Colors.redAccent),
                      focusedErrorBorder: _border(Colors.redAccent),
                    ),
                  ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 4, 20, 12),
              child: Column(
                children: [
                  if (_error != null) ...[
                    Text(
                      _error!,
                      textAlign: TextAlign.center,
                      style: const TextStyle(color: Colors.redAccent, fontSize: 13, height: 1.4),
                    ),
                    const SizedBox(height: 10),
                  ],
                  SizedBox(
                    width: double.infinity,
                    height: 52,
                    child: ElevatedButton(
                      onPressed: _submitting ? null : _submit,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.green,
                        foregroundColor: AppColors.white,
                        disabledBackgroundColor: AppColors.green.withValues(alpha: 0.6),
                        elevation: 0,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                      child: _submitting
                          ? const SizedBox(
                              width: 20,
                              height: 20,
                              child: CircularProgressIndicator(strokeWidth: 2, color: AppColors.white),
                            )
                          : const Text('Submit Report', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700)),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  static OutlineInputBorder _border(Color? color) => OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: color == null ? BorderSide.none : BorderSide(color: color, width: 1.5),
      );
}

/// The card at the top of the page saying what is being reported.
class _SummaryCard extends StatelessWidget {
  const _SummaryCard({required this.picture, required this.title, required this.lines});

  final Widget picture;
  final String title;
  final List<(IconData, String)> lines;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.border),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          picture,
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(color: AppColors.black, fontSize: 16, fontWeight: FontWeight.w800, height: 1.25),
                ),
                for (final (icon, text) in lines)
                  if (text.isNotEmpty)
                    Padding(
                      padding: const EdgeInsets.only(top: 6),
                      child: Row(
                        children: [
                          Icon(icon, size: 15, color: AppColors.gray),
                          const SizedBox(width: 6),
                          Expanded(
                            child: Text(
                              text,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(color: AppColors.gray, fontSize: 13),
                            ),
                          ),
                        ],
                      ),
                    ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _ListingSummary extends StatelessWidget {
  const _ListingSummary({required this.listing});

  final SyntheticListingRecord listing;

  @override
  Widget build(BuildContext context) {
    return _SummaryCard(
      picture: ClipRRect(
        borderRadius: BorderRadius.circular(12),
        child: KuboImage(
          listing.imageAssetPath,
          width: 72,
          height: 72,
          decodeWidth: kuboDecodeWidthFor(context, width: 72, height: 72),
        ),
      ),
      title: listing.title,
      lines: [
        (Icons.sell_outlined, listing.price),
        (Icons.person_outline, 'Sold by ${listing.sellerLabel}'),
        (Icons.location_on_outlined, listing.locationLabel),
      ],
    );
  }
}

class _ProfileSummary extends StatelessWidget {
  const _ProfileSummary({required this.profile});

  final SyntheticProfileRecord profile;

  @override
  Widget build(BuildContext context) {
    final photo = profile.photoUrl.isEmpty ? '' : resolveProfilePhotoUrl(profile.photoUrl);
    return _SummaryCard(
      picture: ClipOval(
        child: photo.isEmpty
            ? Container(
                width: 56,
                height: 56,
                color: AppColors.softBackground,
                child: const Icon(Icons.person_outline, color: AppColors.gray, size: 30),
              )
            : KuboImage(
                photo,
                width: 56,
                height: 56,
                decodeWidth: kuboDecodeWidthFor(context, width: 56, height: 56),
                errorIcon: Icons.person_outline,
              ),
      ),
      title: profile.displayName,
      lines: [
        // The account's email, when the profile shows it.
        (Icons.mail_outline, profile.username),
        (Icons.location_on_outlined, profile.locationLabel),
        (Icons.calendar_today_outlined, profile.joinedLabel.isEmpty ? '' : 'Member since ${profile.joinedLabel}'),
        (Icons.inventory_2_outlined, '${profile.listingCount} listing${profile.listingCount == 1 ? '' : 's'}'),
      ],
    );
  }
}
