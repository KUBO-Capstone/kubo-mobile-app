import 'package:flutter/material.dart';

import '../../../core/constants/app_colors.dart';
import '../../../shared/widgets/kubo_bottom_navigation_bar.dart';
import '../../explore/screens/explore_page.dart';
import '../../market/screens/market_page.dart';
import '../../profile/screens/profile_page.dart';
import '../../search/screens/search_page.dart';
import '../providers/app_shell_controller.dart';

/// The signed-in app: the four tabs under one persistent bottom bar.
///
/// Tabs are built the first time they are opened and then kept alive, so
/// switching back to one keeps its scroll position, filters and loaded data
/// instead of rebuilding and refetching it. Pages opened from a tab (a
/// listing, a chat, another user's profile) are pushed above the shell.
class AppShell extends StatefulWidget {
  const AppShell({
    super.key,
    this.initialTab = AppTab.home,
    this.initialLocationLabel = ExplorePage.defaultLocationLabel,
  });

  static const routeName = '/home';

  /// Where sign-in and sign-up land. Use with `pushAndRemoveUntil` so Back
  /// cannot return to the login screens.
  static Route<void> route({
    AppTab initialTab = AppTab.home,
    String initialLocationLabel = ExplorePage.defaultLocationLabel,
  }) {
    return MaterialPageRoute<void>(
      settings: const RouteSettings(name: routeName),
      builder: (_) => AppShell(initialTab: initialTab, initialLocationLabel: initialLocationLabel),
    );
  }

  final AppTab initialTab;

  /// Location from onboarding, shown in the home and search headers.
  final String initialLocationLabel;

  @override
  State<AppShell> createState() => _AppShellState();
}

class _AppShellState extends State<AppShell> {
  final AppShellController _controller = AppShellController.instance;
  final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();

  /// Pages of the tabs opened so far; the rest are not built until first
  /// visited. Reusing the same widget means a rebuild of the shell (every
  /// push above it rebuilds it) does not rebuild every tab.
  final Map<AppTab, Widget> _pages = <AppTab, Widget>{};
  Route<dynamic>? _route;

  @override
  void initState() {
    super.initState();
    _controller.addListener(_handleTabChanged);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final route = ModalRoute.of(context);
    if (route != null && route != _route) {
      _route = route;
      _controller.attach(route, _scaffoldKey, widget.initialTab);
    }
  }

  @override
  void dispose() {
    _controller.removeListener(_handleTabChanged);
    _controller.detach(_route);
    super.dispose();
  }

  @override
  void reassemble() {
    super.reassemble();
    // Hot reload: rebuild the cached pages so edits to _buildTab show up.
    for (final tab in _pages.keys.toList()) {
      _pages[tab] = _buildTab(tab);
    }
  }

  void _handleTabChanged() {
    // A field focused on the tab being left would keep the keyboard up.
    FocusManager.instance.primaryFocus?.unfocus();
    setState(() {});
  }

  Widget _buildTab(AppTab tab) {
    switch (tab) {
      case AppTab.home:
        return ExplorePage(initialLocationLabel: widget.initialLocationLabel);
      case AppTab.search:
        return SearchPage(initialLocationLabel: widget.initialLocationLabel);
      case AppTab.market:
        return const MarketPage();
      case AppTab.profile:
        return ProfilePage(initialLocationLabel: widget.initialLocationLabel, isTabRoot: true);
    }
  }

  @override
  Widget build(BuildContext context) {
    final current = _controller.current;
    _pages.putIfAbsent(current, () => _buildTab(current));
    return PopScope(
      // Back from another tab goes Home first; only Home leaves the app.
      canPop: current == AppTab.home,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) _controller.select(AppTab.home);
      },
      child: Scaffold(
        key: _scaffoldKey,
        backgroundColor: AppColors.white,
        drawer: const ExploreDrawer(),
        drawerEnableOpenDragGesture: current == AppTab.home,
        body: IndexedStack(
          index: current.index,
          children: [
            for (final tab in AppTab.values)
              _TabSlot(
                isActive: tab == current,
                child: _pages[tab] ?? const SizedBox.shrink(),
              ),
          ],
        ),
        bottomNavigationBar: KuboBottomNavigationBar(
          currentTab: current,
          onTabSelected: _controller.select,
          onCreatePressed: () => _controller.createListing(context),
        ),
      ),
    );
  }
}

/// Keeps a hidden tab alive but idle: no animations ticking, no hero flights
/// (two tabs can show the same photo), and no focus.
class _TabSlot extends StatelessWidget {
  const _TabSlot({required this.isActive, required this.child});

  final bool isActive;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return HeroMode(
      enabled: isActive,
      child: TickerMode(
        enabled: isActive,
        child: ExcludeFocus(excluding: !isActive, child: child),
      ),
    );
  }
}
