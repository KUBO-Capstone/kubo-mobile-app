import 'package:flutter/material.dart';

import '../../../core/constants/app_colors.dart';
import '../../../shared/data/market_service.dart';
import '../../../shared/widgets/kubo_bottom_navigation_bar.dart';
import '../../../shared/widgets/kubo_search_field.dart';
import '../../explore/screens/explore_page.dart';
import '../../listing/screens/create_listing_page.dart';
import '../../profile/screens/profile_page.dart';
import '../../search/screens/search_page.dart';
import '../providers/market_watch_controller.dart';
import '../widgets/market_price_table.dart';
import '../widgets/market_view_pill.dart';
import 'market_product_page.dart';

/// Market tab: Market Watch. Reference prices per product, nationwide, so a
/// buyer can tell whether a farmer's asking price is above the market. Rows
/// open the product's price-per-area dashboard and map.
class MarketPage extends StatefulWidget {
  const MarketPage({super.key, this.initialLocationLabel = 'Caybiga'});

  /// Route name used by the app shell when opening the market tab.
  static const routeName = '/market';

  /// Current account location carried from onboarding and the home tab.
  final String initialLocationLabel;

  @override
  State<MarketPage> createState() => _MarketPageState();
}

class _MarketPageState extends State<MarketPage> {
  late final MarketWatchController _controller;
  final _searchController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _controller = MarketWatchController();
    _controller.load();
    _searchController.addListener(() => _controller.setQuery(_searchController.text));
  }

  @override
  void dispose() {
    _searchController.dispose();
    _controller.dispose();
    super.dispose();
  }

  void _navigateToTab(int index) {
    if (index == 2) {
      return;
    }

    Widget destination;
    switch (index) {
      case 0:
        destination = ExplorePage(initialLocationLabel: widget.initialLocationLabel);
      case 1:
        destination = SearchPage(initialLocationLabel: widget.initialLocationLabel);
      case 3:
        destination = ProfilePage(initialLocationLabel: widget.initialLocationLabel);
      default:
        destination = MarketPage(initialLocationLabel: widget.initialLocationLabel);
    }

    Navigator.of(
      context,
    ).pushReplacement(MaterialPageRoute<void>(builder: (_) => destination));
  }

  void _openCreateListing() {
    Navigator.of(context).push(
      MaterialPageRoute<void>(builder: (_) => const CreateListingPage()),
    );
  }

  void _openProduct(MarketProductSummary product) {
    Navigator.of(context).push(
      MaterialPageRoute<void>(builder: (_) => MarketProductPage(productId: product.id, productName: product.name)),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.white,
      appBar: AppBar(
        backgroundColor: AppColors.white,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        automaticallyImplyLeading: false,
        centerTitle: true,
        title: const Text(
          'MARKET',
          style: TextStyle(color: AppColors.black, fontSize: 14, fontWeight: FontWeight.w700, letterSpacing: 1.2),
        ),
      ),
      body: SafeArea(
        top: false,
        child: AnimatedBuilder(
          animation: _controller,
          builder: (context, _) {
            return Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 4, 16, 10),
                  child: Row(
                    children: [
                      Expanded(
                        child: KuboSearchField(
                          controller: _searchController,
                          hintText: 'Search something/one product',
                          onSubmitted: (_) {},
                          onClear: _searchController.clear,
                        ),
                      ),
                      const SizedBox(width: 10),
                      const MarketViewPill(label: 'Dashboard', selected: true),
                    ],
                  ),
                ),
                _ClassificationChips(
                  selected: _controller.classification,
                  onSelected: _controller.setClassification,
                ),
                const SizedBox(height: 6),
                const MarketTableHeader(labels: ['Market', 'Group', 'Avg. Price (Php)', 'Unit', '+/-']),
                const Divider(height: 1, color: AppColors.border),
                Expanded(child: _buildTable()),
              ],
            );
          },
        ),
      ),
      bottomNavigationBar: KuboBottomNavigationBar(
        currentIndex: 2,
        onDestinationSelected: _navigateToTab,
        onCenterActionPressed: _openCreateListing,
      ),
    );
  }

  Widget _buildTable() {
    if (_controller.isLoading && !_controller.hasData) {
      return const Center(child: CircularProgressIndicator(color: AppColors.green));
    }
    final error = _controller.errorMessage;
    if (error != null && !_controller.hasData) {
      return _Message(text: error, actionLabel: 'Retry', onAction: _controller.load);
    }
    final groups = _controller.grouped;
    if (groups.isEmpty) {
      return const _Message(text: 'No market products match that search.');
    }
    return RefreshIndicator(
      color: AppColors.green,
      onRefresh: _controller.load,
      child: ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.only(bottom: 16),
        children: [
          _SourceNote(
            realDataCount: _controller.realDataCount,
            latestRealAsOf: _controller.latestRealAsOf,
          ),
          for (final group in groups)
            _ClassificationSection(
              name: group.key,
              products: group.value,
              expanded: _controller.expanded.contains(group.key),
              onToggle: () => _controller.toggleExpanded(group.key),
              onOpen: _openProduct,
            ),
        ],
      ),
    );
  }
}

/// Where the numbers come from. Until the DA import has run everything is
/// the illustrative seed, and the tab should say so rather than pass it off.
class _SourceNote extends StatelessWidget {
  const _SourceNote({required this.realDataCount, required this.latestRealAsOf});

  final int realDataCount;
  final DateTime? latestRealAsOf;

  @override
  Widget build(BuildContext context) {
    final live = realDataCount > 0;
    final text = live
        ? 'Prices from DA Bantay Presyo, as of ${formatDate(latestRealAsOf)} '
            '($realDataCount ${realDataCount == 1 ? 'product' : 'products'}); the rest are illustrative.'
        : 'Illustrative prices — the DA Bantay Presyo import has not run yet.';
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 4, 16, 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(live ? Icons.verified_outlined : Icons.science_outlined, size: 13, color: AppColors.gray),
          const SizedBox(width: 6),
          Expanded(
            child: Text(text, style: const TextStyle(color: AppColors.gray, fontSize: 10, height: 1.4)),
          ),
        ],
      ),
    );
  }
}

/// One classification block: header row, up to three products, "See more".
class _ClassificationSection extends StatelessWidget {
  const _ClassificationSection({
    required this.name,
    required this.products,
    required this.expanded,
    required this.onToggle,
    required this.onOpen,
  });

  final String name;
  final List<MarketProductSummary> products;
  final bool expanded;
  final VoidCallback onToggle;
  final ValueChanged<MarketProductSummary> onOpen;

  @override
  Widget build(BuildContext context) {
    final limit = MarketWatchController.collapsedRowLimit;
    final visible = expanded ? products : products.take(limit).toList(growable: false);
    final hasMore = products.length > limit;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          color: AppColors.softBackground,
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 7),
          child: Row(
            children: [
              Expanded(
                child: Text(name, style: const TextStyle(color: AppColors.black, fontSize: 12, fontWeight: FontWeight.w700)),
              ),
              Text('${products.length}', style: const TextStyle(color: AppColors.gray, fontSize: 11)),
            ],
          ),
        ),
        for (final product in visible)
          MarketTableRow(
            leading: product.name,
            secondary: product.groups.join(', '),
            price: product.nationwideAvg,
            unit: product.unit,
            changePct: product.changePct,
            onTap: () => onOpen(product),
          ),
        if (hasMore)
          Center(
            child: TextButton(
              onPressed: onToggle,
              child: Text(
                expanded ? 'See less' : 'See more',
                style: const TextStyle(color: AppColors.green, fontSize: 11, fontWeight: FontWeight.w600),
              ),
            ),
          ),
      ],
    );
  }
}

class _ClassificationChips extends StatelessWidget {
  const _ClassificationChips({required this.selected, required this.onSelected});

  final String? selected;
  final ValueChanged<String?> onSelected;

  @override
  Widget build(BuildContext context) {
    final options = <String?>[null, ...marketClassifications];
    return SizedBox(
      height: 32,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 16),
        physics: const BouncingScrollPhysics(),
        itemCount: options.length,
        separatorBuilder: (_, __) => const SizedBox(width: 8),
        itemBuilder: (context, index) {
          final option = options[index];
          final isSelected = option == selected;
          return ChoiceChip(
            label: Text(
              option ?? 'All',
              style: TextStyle(
                color: isSelected ? AppColors.white : AppColors.black,
                fontSize: 11,
                fontWeight: FontWeight.w600,
              ),
            ),
            selected: isSelected,
            selectedColor: AppColors.green,
            backgroundColor: AppColors.white,
            side: BorderSide(color: isSelected ? AppColors.green : AppColors.border),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
            visualDensity: VisualDensity.compact,
            onSelected: (_) => onSelected(option),
          );
        },
      ),
    );
  }
}

class _Message extends StatelessWidget {
  const _Message({required this.text, this.actionLabel, this.onAction});

  final String text;
  final String? actionLabel;
  final Future<void> Function()? onAction;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(text, textAlign: TextAlign.center, style: const TextStyle(color: AppColors.gray, fontSize: 14)),
            if (actionLabel != null && onAction != null)
              TextButton(onPressed: onAction, child: Text(actionLabel!)),
          ],
        ),
      ),
    );
  }
}
