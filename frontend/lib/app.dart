import 'package:flutter/material.dart';

import 'core/constants/app_colors.dart';
import 'features/chat/screens/messages_page.dart';
import 'features/explore/screens/explore_page.dart';
import 'features/login/screens/create_account_page.dart';
import 'features/login/screens/get_started_page.dart';
import 'features/login/screens/login_page.dart';
import 'features/market/screens/market_page.dart';
import 'features/notification/screens/notification_page.dart';
import 'features/profile/screens/profile_page.dart';
import 'features/search/screens/search_page.dart';

/// Root application widget that defines the theme and named routes for Kubo.
class KuboApp extends StatelessWidget {
  const KuboApp({super.key});

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
      debugShowCheckedModeBanner: false,
      title: 'Kubo',
      theme: ThemeData(
        useMaterial3: true,
        colorScheme: colorScheme,
        scaffoldBackgroundColor: AppColors.white,
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
      routes: {
        LoginPage.routeName: (_) => const LoginPage(),
        CreateAccountPage.routeName: (_) => const CreateAccountPage(),
        GetStartedPage.routeName: (_) => const GetStartedPage(),
        ExplorePage.routeName: (_) => const ExplorePage(),
        SearchPage.routeName: (_) => const SearchPage(),
        MarketPage.routeName: (_) => const MarketPage(),
        NotificationPage.routeName: (_) => const NotificationPage(),
        MessagesPage.routeName: (_) => const MessagesPage(),
        ProfilePage.routeName: (_) => const ProfilePage(),
      },
      initialRoute: LoginPage.routeName,
    );
  }
}
