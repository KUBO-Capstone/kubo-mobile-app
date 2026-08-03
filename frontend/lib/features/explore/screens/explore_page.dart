import 'package:flutter/material.dart';

import '../../../core/constants/app_assets.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/widgets/app_svg_icon.dart';
import '../models/explore_listing.dart';
import '../widgets/explore_bottom_nav.dart';
import '../widgets/explore_listing_card.dart';
import '../widgets/explore_section_page.dart';

enum ExploreViewMode { list, map }

class ExplorePage extends StatefulWidget {
  const ExplorePage({super.key, this.initialLocationLabel = 'Caybiga'});

  static const routeName = '/explore';

  final String initialLocationLabel;

  @override
  State<ExplorePage> createState() => _ExplorePageState();
}

class _ExplorePageState extends State<ExplorePage> {
  static const List<String> _regionFilters = <String>[
    'All',
    'Region I',
    'Region II',
    'Region III',
    'Region IV-A',
    'Region IV-B',
    'Region V',
    'Region VI',
    'Region VII',
    'Region VIII',
    'Region IX',
    'Region X',
    'Region XI',
    'Region XII',
    'Region XIII',
    'NCR',
    'CAR',
    'BARMM',
  ];

  static final List<ExploreListing> _allListings = List<ExploreListing>.unmodifiable(
    List<ExploreListing>.generate(
      10,
      (index) {
        const titles = <String>[
          'Fresh harvested tomatoes bundle',
          'Organic eggplant basket',
          'Sweet mango harvest box',
          'Leafy greens weekly pack',
          'Farm eggs tray set',
          'Red onion kilo pack',
          'Coconut vinegar set',
          'Native rice premium sack',
          'Banana blossoms harvest',
          'Seasonal vegetable mix',
        ];
        const locations = <String>[
          'Caloocan',
          'Bulacan',
          'Pampanga',
          'Laguna',
          'Rizal',
          'Quezon',
          'Cavite',
          'Batangas',
          'Nueva Ecija',
          'Bataan',
        ];
        const regions = <String>[
          'NCR',
          'Region III',
          'Region III',
          'Region IV-A',
          'NCR',
          'Region IV-A',
          'Region IV-A',
          'Region IV-A',
          'Region III',
          'Region III',
        ];

        final price = 120 + (index * 35);

        return ExploreListing(
          id: 'listing-$index',
          title: titles[index],
          price: 'PHP ${price.toStringAsFixed(0)}',
          locationLabel: locations[index],
          regionLabel: regions[index],
          sellerLabel: 'Kubo Grower ${index + 1}',
          imageAssetPath: AppAssets.placeholderImage,
        );
      },
    ),
  );

  late String _accountLocationLabel;
  String _selectedRegionFilter = 'All';
  ExploreViewMode _viewMode = ExploreViewMode.list;
  int _currentBottomNavIndex = 0;

  @override
  void initState() {
    super.initState();
    _accountLocationLabel = widget.initialLocationLabel.trim().isEmpty
        ? 'Caybiga'
        : widget.initialLocationLabel;
  }

  List<ExploreListing> get _visibleListings {
    if (_selectedRegionFilter == 'All') {
      return _allListings;
    }

    return _allListings
        .where((listing) => listing.regionLabel == _selectedRegionFilter)
        .toList(growable: false);
  }

  String get _locationLabel {
    return _selectedRegionFilter == 'All' ? _accountLocationLabel : _selectedRegionFilter;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.white,
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: SingleChildScrollView(
                physics: const BouncingScrollPhysics(),
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _TopBar(
                      locationLabel: _locationLabel,
                      viewMode: _viewMode,
                      onViewModeChanged: (value) => setState(() => _viewMode = value),
                      onMenuTap: () => _openSection(
                        context,
                        'Menu',
                        'Menu shortcuts and quick actions will be added here.',
                      ),
                      onNotificationTap: () => _openSection(
                        context,
                        'Notifications',
                        'Notifications will appear here.',
                      ),
                      onSavedTap: () => _openSection(
                        context,
                        'Saved',
                        'Your saved listings will appear here.',
                      ),
                      onChatTap: () => _openSection(
                        context,
                        'Messages',
                        'Your chats will appear here.',
                      ),
                    ),
                    const SizedBox(height: 14),
                    SizedBox(
                      height: 34,
                      child: ListView.separated(
                        scrollDirection: Axis.horizontal,
                        physics: const BouncingScrollPhysics(),
                        itemCount: _regionFilters.length,
                        separatorBuilder: (_, __) => const SizedBox(width: 8),
                        itemBuilder: (context, index) {
                          final region = _regionFilters[index];
                          final isSelected = region == _selectedRegionFilter;
                          return ChoiceChip(
                            label: Text(
                              region,
                              style: TextStyle(
                                color: isSelected ? AppColors.white : AppColors.black,
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            selected: isSelected,
                            selectedColor: AppColors.green,
                            backgroundColor: AppColors.white,
                            side: BorderSide(
                              color: isSelected ? AppColors.green : AppColors.border,
                              width: 1,
                            ),
                            shape: const StadiumBorder(),
                            onSelected: (_) {
                              setState(() {
                                _selectedRegionFilter = region;
                              });
                            },
                          );
                        },
                      ),
                    ),
                    const SizedBox(height: 16),
                    if (_viewMode == ExploreViewMode.list) ...[
                      _ListingsGrid(listings: _visibleListings),
                    ] else ...[
                      _MapPlaceholder(locationLabel: _locationLabel),
                    ],
                  ],
                ),
              ),
            ),
            ExploreBottomNav(
              currentIndex: _currentBottomNavIndex,
              onIndexSelected: (index) {
                setState(() {
                  _currentBottomNavIndex = index;
                });
              },
            ),
          ],
        ),
      ),
    );
  }

  void _openSection(BuildContext context, String title, String message) {
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => ExploreSectionPage(title: title, message: message),
      ),
    );
  }
}

class _TopBar extends StatelessWidget {
  const _TopBar({
    required this.locationLabel,
    required this.viewMode,
    required this.onViewModeChanged,
    required this.onMenuTap,
    required this.onNotificationTap,
    required this.onSavedTap,
    required this.onChatTap,
  });

  final String locationLabel;
  final ExploreViewMode viewMode;
  final ValueChanged<ExploreViewMode> onViewModeChanged;
  final VoidCallback onMenuTap;
  final VoidCallback onNotificationTap;
  final VoidCallback onSavedTap;
  final VoidCallback onChatTap;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            _CircleIconButton(assetPath: AppIcons.barsMore, onTap: onMenuTap),
            const Spacer(),
            _CircleIconButton(assetPath: AppIcons.bellNotification, onTap: onNotificationTap),
            const SizedBox(width: 10),
            _CircleIconButton(assetPath: AppIcons.heartSaved, onTap: onSavedTap),
            const SizedBox(width: 10),
            _CircleIconButton(assetPath: AppIcons.chat, onTap: onChatTap),
          ],
        ),
        const SizedBox(height: 20),
        Row(
          children: [
            _ViewToggleButton(
              assetPath: AppIcons.listView,
              label: 'List View',
              selected: viewMode == ExploreViewMode.list,
              onTap: () => onViewModeChanged(ExploreViewMode.list),
            ),
            const SizedBox(width: 14),
            _ViewToggleButton(
              assetPath: AppIcons.locationDot,
              label: 'Map View',
              selected: viewMode == ExploreViewMode.map,
              onTap: () => onViewModeChanged(ExploreViewMode.map),
            ),
            const Spacer(),
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const AppSvgIcon(assetPath: AppIcons.locationDot, size: 16, color: AppColors.green),
                const SizedBox(width: 4),
                Text(
                  locationLabel,
                  style: const TextStyle(
                    color: AppColors.green,
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
          ],
        ),
      ],
    );
  }
}

class _CircleIconButton extends StatelessWidget {
  const _CircleIconButton({required this.assetPath, required this.onTap});

  final String assetPath;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkResponse(
      onTap: onTap,
      radius: 24,
      child: Container(
        width: 34,
        height: 34,
        decoration: const BoxDecoration(
          color: AppColors.white,
          shape: BoxShape.circle,
        ),
        child: Center(
          child: AppSvgIcon(assetPath: assetPath, size: 22, color: AppColors.black),
        ),
      ),
    );
  }
}

class _ViewToggleButton extends StatelessWidget {
  const _ViewToggleButton({
    required this.assetPath,
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final String assetPath;
  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final color = selected ? AppColors.green : AppColors.gray;

    return InkWell(
      onTap: onTap,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              AppSvgIcon(assetPath: assetPath, size: 15, color: color),
              const SizedBox(width: 4),
              Text(
                label,
                style: TextStyle(
                  color: color,
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
          const SizedBox(height: 2),
          Container(
            width: 62,
            height: 2,
            color: selected ? AppColors.green : Colors.transparent,
          ),
        ],
      ),
    );
  }
}

class _ListingsGrid extends StatelessWidget {
  const _ListingsGrid({required this.listings});

  final List<ExploreListing> listings;

  @override
  Widget build(BuildContext context) {
    if (listings.isEmpty) {
      return const Padding(
        padding: EdgeInsets.only(top: 36),
        child: Center(
          child: Text(
            'No listings available for this region yet.',
            style: TextStyle(color: AppColors.gray, fontSize: 14),
          ),
        ),
      );
    }

    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: listings.length,
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        mainAxisSpacing: 18,
        crossAxisSpacing: 12,
        childAspectRatio: 0.72,
      ),
      itemBuilder: (context, index) {
        return ExploreListingCard(listing: listings[index]);
      },
    );
  }
}

class _MapPlaceholder extends StatelessWidget {
  const _MapPlaceholder({required this.locationLabel});

  final String locationLabel;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(top: 12),
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: AppColors.softBackground,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        children: [
          const SizedBox(height: 12),
          const Icon(Icons.map_outlined, size: 72, color: AppColors.green),
          const SizedBox(height: 18),
          const Text(
            'Map View',
            style: TextStyle(
              color: AppColors.black,
              fontSize: 20,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Map instructions will be added later. Current location: $locationLabel',
            textAlign: TextAlign.center,
            style: const TextStyle(
              color: AppColors.gray,
              fontSize: 14,
              height: 1.45,
            ),
          ),
          const SizedBox(height: 12),
        ],
      ),
    );
  }
}