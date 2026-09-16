import 'package:flutter/material.dart';

import '../../../core/constants/app_colors.dart';
import '../../../shared/data/market_service.dart';
import '../providers/market_product_controller.dart';
import '../widgets/market_price_map.dart';
import '../widgets/market_price_table.dart';
import '../widgets/market_summary_card.dart';
import '../widgets/market_view_pill.dart';

/// One product's price per area (PPA 3–6): a summary card and a region /
/// province table in Dashboard view, or pins with a region picker in Map view.
class MarketProductPage extends StatefulWidget {
  const MarketProductPage({super.key, required this.productId, required this.productName});

  static const routeName = '/market/product';

  final int productId;

  /// Shown in the header while the detail is still loading.
  final String productName;

  @override
  State<MarketProductPage> createState() => _MarketProductPageState();
}

class _MarketProductPageState extends State<MarketProductPage> {
  late final MarketProductController _controller;

  @override
  void initState() {
    super.initState();
    _controller = MarketProductController(productId: widget.productId);
    _controller.load();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, _) {
        final product = _controller.product;
        final isMap = _controller.view == MarketDetailView.map;

        return Scaffold(
          backgroundColor: AppColors.white,
          appBar: AppBar(
            backgroundColor: AppColors.white,
            surfaceTintColor: Colors.transparent,
            elevation: 0,
            centerTitle: true,
            leading: IconButton(
              icon: const Icon(Icons.arrow_back_ios_new, size: 18, color: AppColors.black),
              onPressed: () => Navigator.of(context).pop(),
            ),
            title: Text(
              product?.name ?? widget.productName,
              style: const TextStyle(color: AppColors.black, fontSize: 14, fontWeight: FontWeight.w700),
            ),
          ),
          body: SafeArea(
            top: false,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 4, 16, 12),
                  child: Row(
                    children: [
                      // The wireframe keeps the search box here with the
                      // product name in it; tapping it goes back to search.
                      Expanded(
                        child: _SearchEcho(
                          text: product?.name ?? widget.productName,
                          onTap: () => Navigator.of(context).pop(),
                        ),
                      ),
                      const SizedBox(width: 8),
                      MarketViewPill(
                        label: 'Dashboard',
                        selected: !isMap,
                        onTap: () => _controller.showView(MarketDetailView.dashboard),
                      ),
                      const SizedBox(width: 6),
                      MarketViewPill(
                        label: 'Map',
                        selected: isMap,
                        onTap: () => _controller.showView(MarketDetailView.map),
                      ),
                    ],
                  ),
                ),
                Expanded(child: _buildBody(product, isMap)),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildBody(MarketProductDetail? product, bool isMap) {
    if (_controller.isLoading && product == null) {
      return const Center(child: CircularProgressIndicator(color: AppColors.green));
    }
    final error = _controller.errorMessage;
    if (product == null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(error ?? 'No data for this product.', textAlign: TextAlign.center, style: const TextStyle(color: AppColors.gray)),
              TextButton(onPressed: _controller.load, child: const Text('Retry')),
            ],
          ),
        ),
      );
    }
    return isMap ? _buildMap(product) : _buildDashboard(product);
  }

  Widget _buildDashboard(MarketProductDetail product) {
    return ListView(
      physics: const BouncingScrollPhysics(),
      padding: const EdgeInsets.only(bottom: 24),
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: MarketSummaryCard(product: product),
        ),
        const SizedBox(height: 8),
        const MarketTableHeader(labels: ['Region', 'Province/City', 'Avg. Price (Php)', 'Unit', '+/-']),
        const Divider(height: 1, color: AppColors.border),
        if (product.areas.isEmpty)
          const Padding(
            padding: EdgeInsets.all(24),
            child: Text('No area prices recorded yet.', textAlign: TextAlign.center, style: TextStyle(color: AppColors.gray)),
          ),
        for (final area in product.areas)
          MarketTableRow(
            leading: area.region,
            secondary: area.provinceCity,
            price: area.avgPrice,
            unit: area.unit,
            changePct: area.changePct,
          ),
      ],
    );
  }

  Widget _buildMap(MarketProductDetail product) {
    final selected = _controller.selectedArea;
    return MarketPriceMap(
      areas: _controller.visibleAreas,
      regionNames: product.regionNames,
      selectedRegionName: _controller.selectedRegionName,
      selectedArea: selected,
      onRegionChanged: _controller.selectRegion,
      onAreaSelected: _controller.selectArea,
      infoCard: selected == null ? null : MarketSummaryCard(product: product, area: selected),
    );
  }
}

/// Read-only search box echoing the product name, as in PPA 3–6.
class _SearchEcho extends StatelessWidget {
  const _SearchEcho({required this.text, required this.onTap});

  final String text;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(14),
      child: Container(
        height: 42,
        padding: const EdgeInsets.symmetric(horizontal: 14),
        decoration: BoxDecoration(
          color: AppColors.softBackground,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: AppColors.border),
        ),
        child: Row(
          children: [
            const Icon(Icons.search, size: 18, color: AppColors.gray),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                text,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(color: AppColors.black, fontSize: 13),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
