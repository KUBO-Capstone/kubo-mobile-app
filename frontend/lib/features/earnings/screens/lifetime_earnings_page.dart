import 'package:flutter/material.dart';

import '../../../core/constants/app_colors.dart';
import '../../../core/utils/formatters.dart';
import '../../../shared/data/earnings_service.dart';
import '../../../shared/data/listing_service.dart';
import '../../../shared/data/profile_service.dart';
import '../../chat/widgets/counter_offer_dialog.dart' show formatAmount;
import '../../listing/screens/create_listing_page.dart';
import '../../listing/screens/listing_page.dart';
import '../../login/services/auth_service.dart';
import '../widgets/earnings_illustration.dart';

/// The seller's own running total from completed orders, with the listings
/// that earned the most. Only ever shown to the account owner.
class LifetimeEarningsPage extends StatefulWidget {
  const LifetimeEarningsPage({super.key, this.loader});

  /// Injected in tests; fetches from the API otherwise.
  final Future<EarningsSummary> Function(int userId)? loader;

  @override
  State<LifetimeEarningsPage> createState() => _LifetimeEarningsPageState();
}

class _LifetimeEarningsPageState extends State<LifetimeEarningsPage> {
  final EarningsService _service = EarningsService();
  EarningsSummary? _summary;
  String? _error;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _service.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    final userId = AuthService.currentUserId;
    if (userId == null) {
      setState(() {
        _loading = false;
        _error = 'Log in to see your earnings.';
      });
      return;
    }
    setState(() => _loading = _summary == null);
    try {
      final summary = await (widget.loader ?? _service.fetchEarnings)(userId);
      if (!mounted) return;
      setState(() {
        _summary = summary;
        _error = null;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() => _error = error.toString().replaceFirst('Exception: ', ''));
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _createListing() async {
    await Navigator.of(context).push(MaterialPageRoute<void>(builder: (_) => const CreateListingPage()));
    if (mounted) _load();
  }

  Future<void> _openListing(TopEarningListing listing) async {
    final service = ListingService();
    try {
      final record = await service.fetchListing(listing.productId);
      if (!mounted) return;
      Navigator.of(context).push(MaterialPageRoute<void>(builder: (_) => ListingPage(listing: record)));
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(error.toString().replaceFirst('Exception: ', ''))),
      );
    } finally {
      service.dispose();
    }
  }

  @override
  Widget build(BuildContext context) {
    final photo = resolveProfilePhotoUrl(AuthService.currentUser?['profile_photo_url']?.toString());
    return Scaffold(
      backgroundColor: AppColors.white,
      appBar: AppBar(
        backgroundColor: AppColors.white,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        centerTitle: true,
        leading: IconButton(
          tooltip: 'Back',
          icon: const Icon(Icons.arrow_back, color: AppColors.black),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: const Text(
          'Lifetime earnings',
          style: TextStyle(color: AppColors.black, fontSize: 20, fontWeight: FontWeight.w800),
        ),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 16),
            child: CircleAvatar(
              radius: 18,
              backgroundColor: AppColors.softBackground,
              backgroundImage: photo.isEmpty ? null : NetworkImage(photo),
              child: photo.isEmpty ? const Icon(Icons.person, color: AppColors.gray, size: 20) : null,
            ),
          ),
        ],
      ),
      body: _buildBody(),
      bottomNavigationBar: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 8, 20, 12),
          child: SizedBox(
            height: 52,
            child: FilledButton(
              onPressed: _createListing,
              style: FilledButton.styleFrom(
                backgroundColor: AppColors.green,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              ),
              child: const Text('Create a listing', style: TextStyle(fontSize: 17, fontWeight: FontWeight.w800)),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildBody() {
    final summary = _summary;
    if (_loading && summary == null) {
      return const Center(child: CircularProgressIndicator(color: AppColors.green));
    }
    if (summary == null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(_error ?? 'Could not load your earnings.', textAlign: TextAlign.center, style: const TextStyle(color: AppColors.gray)),
              const SizedBox(height: 12),
              TextButton(onPressed: _load, child: const Text('Retry')),
            ],
          ),
        ),
      );
    }

    final since = summary.firstSaleAt;
    return RefreshIndicator(
      color: AppColors.green,
      onRefresh: _load,
      child: ListView(
        padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
        children: [
          const EarningsIllustration(),
          const SizedBox(height: 24),
          Text(
            formatPeso(summary.totalEarned),
            textAlign: TextAlign.center,
            style: const TextStyle(color: AppColors.black, fontSize: 44, fontWeight: FontWeight.w900, height: 1.1),
          ),
          if (summary.completedOrders > 0) ...[
            const SizedBox(height: 6),
            Text(
              'from ${summary.completedOrders} completed order${summary.completedOrders == 1 ? '' : 's'}'
              '${since == null ? '' : ' since ${monthYear(since)}'}',
              textAlign: TextAlign.center,
              style: const TextStyle(color: AppColors.gray, fontSize: 14, fontWeight: FontWeight.w600),
            ),
          ],
          const SizedBox(height: 16),
          const Text(
            'This is an estimate from orders buyers marked as received on Kubo. Deals still in progress '
            'are not counted until then. It is not valid for tax, invoicing, or financial reporting.',
            textAlign: TextAlign.center,
            style: TextStyle(color: AppColors.gray, fontSize: 14, height: 1.45),
          ),
          const SizedBox(height: 6),
          const Text(
            'Visible to you only.',
            textAlign: TextAlign.center,
            style: TextStyle(color: AppColors.black, fontSize: 14, fontWeight: FontWeight.w800),
          ),
          if (summary.inProgressDeals > 0) ...[
            const SizedBox(height: 20),
            _InProgressCard(total: summary.inProgressTotal, deals: summary.inProgressDeals),
          ],
          const SizedBox(height: 28),
          const Text(
            'Your top earning listings',
            style: TextStyle(color: AppColors.black, fontSize: 20, fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: 12),
          if (summary.topListings.isEmpty)
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(color: AppColors.softBackground, borderRadius: BorderRadius.circular(14)),
              child: const Column(
                children: [
                  Icon(Icons.storefront_outlined, color: AppColors.gray, size: 32),
                  SizedBox(height: 8),
                  Text(
                    'Your first sale will show up here once a buyer receives their order.',
                    textAlign: TextAlign.center,
                    style: TextStyle(color: AppColors.gray, fontSize: 13, height: 1.4),
                  ),
                ],
              ),
            )
          else
            GridView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: summary.topListings.length,
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 2,
                mainAxisSpacing: 14,
                crossAxisSpacing: 12,
                childAspectRatio: 0.74,
              ),
              itemBuilder: (_, index) {
                final listing = summary.topListings[index];
                return _TopListingCard(listing: listing, rank: index + 1, onTap: () => _openListing(listing));
              },
            ),
        ],
      ),
    );
  }
}

class _InProgressCard extends StatelessWidget {
  const _InProgressCard({required this.total, required this.deals});

  final double total;
  final int deals;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.green.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Row(
        children: [
          const Icon(Icons.local_shipping_outlined, color: AppColors.green),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '${formatPeso(total)} on the way',
                  style: const TextStyle(color: AppColors.black, fontSize: 15, fontWeight: FontWeight.w800),
                ),
                const SizedBox(height: 2),
                Text(
                  '$deals deal${deals == 1 ? '' : 's'} in progress: accepted offers and orders not yet received.',
                  style: const TextStyle(color: AppColors.gray, fontSize: 12, height: 1.35),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _TopListingCard extends StatelessWidget {
  const _TopListingCard({required this.listing, required this.rank, required this.onTap});

  final TopEarningListing listing;
  final int rank;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final image = listing.productImage;
    return Material(
      color: AppColors.white,
      borderRadius: BorderRadius.circular(12),
      child: InkWell(
        onTap: listing.status == 'delisted' ? null : onTap,
        borderRadius: BorderRadius.circular(12),
        child: Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: AppColors.border),
          ),
          clipBehavior: Clip.antiAlias,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    image == null
                        ? const ColoredBox(color: AppColors.softBackground, child: Icon(Icons.eco_outlined, color: AppColors.gray, size: 36))
                        : Image.network(
                            image,
                            fit: BoxFit.cover,
                            errorBuilder: (_, __, ___) =>
                                const ColoredBox(color: AppColors.softBackground, child: Icon(Icons.eco_outlined, color: AppColors.gray, size: 36)),
                          ),
                    Positioned(
                      top: 8,
                      left: 8,
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                        decoration: BoxDecoration(color: AppColors.black.withValues(alpha: 0.75), borderRadius: BorderRadius.circular(20)),
                        child: Text('#$rank', style: const TextStyle(color: AppColors.white, fontSize: 11, fontWeight: FontWeight.w800)),
                      ),
                    ),
                  ],
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(10, 8, 10, 10),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      listing.cropName,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(color: AppColors.black, fontSize: 14, fontWeight: FontWeight.w700),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      formatPeso(listing.earned),
                      style: const TextStyle(color: AppColors.green, fontSize: 16, fontWeight: FontWeight.w900),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      '${formatAmount(listing.quantitySold)} ${listing.unit} sold · ${listing.orders} order${listing.orders == 1 ? '' : 's'}',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(color: AppColors.gray, fontSize: 11),
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
}
