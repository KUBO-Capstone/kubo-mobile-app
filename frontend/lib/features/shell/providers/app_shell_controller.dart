import 'dart:async';

import 'package:flutter/material.dart';

import '../../../shared/data/synthetic_records.dart';
import '../../listing/screens/create_listing_page.dart';

/// Top-level destinations of the bottom bar, left to right. The "+" in the
/// middle is an action (create a listing), not a destination.
enum AppTab { home, search, market, profile }

/// Drives the bottom-navigation shell from anywhere in the app.
///
/// One app-wide instance, like `SavedListingsController.instance`: pages
/// pushed above the shell (another user's profile, search results) draw the
/// same bar, and a tap there has to reach back down into the shell.
class AppShellController extends ChangeNotifier {
  AppShellController._();

  static final AppShellController instance = AppShellController._();

  AppTab _current = AppTab.home;
  Route<dynamic>? _shellRoute;
  GlobalKey<ScaffoldState>? _scaffoldKey;

  final StreamController<AppTab> _reselected = StreamController<AppTab>.broadcast();
  final StreamController<void> _listingsChanged = StreamController<void>.broadcast();

  /// The tab the shell is showing. A page pushed above the shell highlights
  /// this one, since it is where the user came from.
  AppTab get current => _current;

  /// Whether a shell is mounted for taps to go to.
  bool get hasShell => _shellRoute != null;

  /// A listing was posted, edited or removed; feeds that show it reload.
  Stream<void> get listingsChanged => _listingsChanged.stream;

  void notifyListingsChanged() => _listingsChanged.add(null);

  /// Calls [onReselect] whenever [tab] is tapped while it is already showing
  /// with nothing pushed above the shell. Tabs answer by scrolling back to
  /// the top, or refreshing once they are there.
  StreamSubscription<AppTab> onReselect(AppTab tab, VoidCallback onReselect) {
    return _reselected.stream.where((selected) => selected == tab).listen((_) => onReselect());
  }

  /// Called by the shell once it sits in a route.
  void attach(Route<dynamic> route, GlobalKey<ScaffoldState> scaffoldKey, AppTab initialTab) {
    _shellRoute = route;
    _scaffoldKey = scaffoldKey;
    _current = initialTab;
  }

  /// Called by the shell as it goes away (logout), so the next session
  /// starts on Home.
  void detach(Route<dynamic>? route) {
    if (route == null || route != _shellRoute) return;
    _shellRoute = null;
    _scaffoldKey = null;
    _current = AppTab.home;
  }

  /// A tap on the shell's own bar: switch tabs, or tell the current tab it
  /// was tapped again.
  void select(AppTab tab) {
    if (tab == _current) {
      _reselected.add(tab);
      return;
    }
    _current = tab;
    notifyListeners();
  }

  /// Sends the user to [tab] from anywhere. Whatever is pushed above the
  /// shell is popped first, so Profile always lands on the signed-in user's
  /// own profile even from someone else's.
  void goTo(AppTab tab) {
    final route = _shellRoute;
    if (route == null) return;
    if (!route.isActive) {
      detach(route);
      return;
    }
    if (route.isCurrent) {
      select(tab);
      return;
    }
    route.navigator?.popUntil((candidate) => candidate == route);
    if (tab != _current) {
      _current = tab;
      notifyListeners();
    }
  }

  /// Opens the app drawer over the whole shell, bar included.
  void openDrawer(BuildContext context) {
    final scaffold = _scaffoldKey?.currentState;
    if (scaffold != null && scaffold.hasDrawer) {
      scaffold.openDrawer();
    } else {
      Scaffold.maybeOf(context)?.openDrawer();
    }
  }

  /// Opens the create form (the "+" in the bar, or any "Create listing"
  /// button) as a full-screen task above the bar. Feeds reload once
  /// something was posted.
  Future<SyntheticListingRecord?> createListing(BuildContext context) async {
    final created = await Navigator.of(context, rootNavigator: true).push<SyntheticListingRecord>(
      MaterialPageRoute<SyntheticListingRecord>(
        fullscreenDialog: true,
        builder: (_) => const CreateListingPage(),
      ),
    );
    if (created != null) notifyListingsChanged();
    return created;
  }
}

/// Scrolls [controller] back to the top, or runs [atTop] (usually a refresh)
/// when it is already there.
void scrollToTopOr(ScrollController controller, VoidCallback atTop) {
  if (!controller.hasClients || controller.offset <= 1) {
    atTop();
    return;
  }
  controller.animateTo(
    0,
    duration: const Duration(milliseconds: 380),
    curve: Curves.easeOutCubic,
  );
}
