import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'core/constants/app_colors.dart';
import 'features/chat/screens/messages_page.dart';
import 'features/explore/screens/explore_page.dart';
import 'features/login/screens/create_account_page.dart';
import 'features/login/screens/get_started_page.dart';
import 'features/login/screens/login_page.dart';
import 'features/login/services/auth_service.dart';
import 'features/market/screens/market_page.dart';
import 'features/notification/screens/notification_page.dart';
import 'features/profile/screens/profile_page.dart';
import 'features/report/screens/report_page.dart';
import 'features/saved/providers/saved_listings_controller.dart';
import 'features/saved/screens/saved_listings_page.dart';
import 'features/search/screens/search_page.dart';
import 'features/shell/providers/app_shell_controller.dart';
import 'features/shell/screens/app_shell.dart';
import 'shared/data/api_request.dart';

/// Status and navigation bar look for the app's white screens. Pages with an
/// app bar set their own; this covers the rest (the listing page, profiles)
/// and is what returns after the dark photo viewer closes.
const SystemUiOverlayStyle _systemBars = SystemUiOverlayStyle(
  statusBarColor: Colors.transparent,
  statusBarIconBrightness: Brightness.dark,
  statusBarBrightness: Brightness.light,
  systemNavigationBarColor: AppColors.white,
  systemNavigationBarIconBrightness: Brightness.dark,
);

/// Root application widget that defines the theme and named routes for Kubo.
///
/// It also looks after the session across the app's life: it opens on the
/// shell when `main` restored a saved session, checks that session with the
/// server on launch and when the app returns to the foreground, and sends
/// the user back to the login screen if the server stops accepting it.
class KuboApp extends StatefulWidget {
  const KuboApp({super.key});

  @override
  State<KuboApp> createState() => _KuboAppState();
}

class _KuboAppState extends State<KuboApp> with WidgetsBindingObserver {
  final GlobalKey<NavigatorState> _navigatorKey = GlobalKey<NavigatorState>();
  final GlobalKey<ScaffoldMessengerState> _messengerKey = GlobalKey<ScaffoldMessengerState>();
  late final StreamSubscription<void> _sessionExpired;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _sessionExpired = ApiSession.expired.listen((_) => _handleSessionExpired());
    // A restored session is shown at once; this swaps in the server's copy.
    if (AuthService.currentUser != null) AuthService.refreshSession();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _sessionExpired.cancel();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) AuthService.refreshSessionIfStale();
  }

  // The server refused the token (it ran out, or the account is gone): end
  // the session here too and drop every screen of it.
  void _handleSessionExpired() {
    AuthService.logout();
    SavedListingsController.instance.clear();
    _navigatorKey.currentState?.pushNamedAndRemoveUntil(LoginPage.routeName, (_) => false);
    _messengerKey.currentState
      ?..hideCurrentSnackBar()
      ..showSnackBar(const SnackBar(content: Text('Your session has expired. Please log in again.')));
  }

  /// Named route map that keeps the app shell and feature screens wired together.
  @override
  // Builds the MaterialApp shell that wires the whole navigation flow together.
  Widget build(BuildContext context) {
    // Derive a shared color scheme from the brand green so every screen stays consistent.
    final colorScheme = ColorScheme.fromSeed(
      seedColor: AppColors.green,
      brightness: Brightness.light,
      primary: AppColors.green,
      secondary: AppColors.black,
      surface: AppColors.white,
    );

    return MaterialApp(
      navigatorKey: _navigatorKey,
      scaffoldMessengerKey: _messengerKey,
      debugShowCheckedModeBanner: false,
      title: 'Kubo',
      theme: ThemeData(
        useMaterial3: true,
        colorScheme: colorScheme,
        scaffoldBackgroundColor: AppColors.white,
        // Floating snackbars sit above the bottom bar and action bars instead
        // of covering them.
        snackBarTheme: SnackBarThemeData(
          behavior: SnackBarBehavior.floating,
          backgroundColor: AppColors.black,
          contentTextStyle: const TextStyle(color: AppColors.white, fontSize: 14),
          actionTextColor: AppColors.greenLight,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        ),
        textTheme: const TextTheme(
          headlineLarge: TextStyle(
            color: AppColors.black,
            fontSize: 32,
            fontWeight: FontWeight.w800,
          ),
          headlineMedium: TextStyle(
            color: AppColors.black,
            fontSize: 24,
            fontWeight: FontWeight.w700,
          ),
          bodyLarge: TextStyle(
            color: AppColors.black,
            fontSize: 16,
            height: 1.45,
          ),
          bodyMedium: TextStyle(
            color: AppColors.gray,
            fontSize: 14,
            height: 1.4,
          ),
        ),
      ),
      builder: (context, child) => AnnotatedRegion<SystemUiOverlayStyle>(
        value: _systemBars,
        child: child ?? const SizedBox.shrink(),
      ),
      routes: {
        LoginPage.routeName: (_) => const LoginPage(),
        CreateAccountPage.routeName: (_) => const CreateAccountPage(),
        GetStartedPage.routeName: (_) => const GetStartedPage(),
        AppShell.routeName: (_) => const AppShell(),
        // The tabs live in the shell; their old route names open it on them.
        ExplorePage.routeName: (_) => const AppShell(),
        SearchPage.routeName: (_) => const AppShell(initialTab: AppTab.search),
        MarketPage.routeName: (_) => const AppShell(initialTab: AppTab.market),
        ProfilePage.routeName: (_) => const AppShell(initialTab: AppTab.profile),
        NotificationPage.routeName: (_) => const NotificationPage(),
        MessagesPage.routeName: (_) => const MessagesPage(),
        SavedListingsPage.routeName: (_) => const SavedListingsPage(),
        ReportPage.routeName: (_) => const ReportPage(),
      },
      initialRoute: LoginPage.routeName,
      // Exactly one first screen: the shell for a restored session, the
      // login screen otherwise. (An initial route of '/home' would stack the
      // shell on top of the login screen, and Back would lead to it.)
      onGenerateInitialRoutes: (_) => <Route<dynamic>>[
        AuthService.currentUser != null
            ? AppShell.route()
            : MaterialPageRoute<void>(
                settings: const RouteSettings(name: LoginPage.routeName),
                builder: (_) => const LoginPage(),
              ),
      ],
    );
  }
}
