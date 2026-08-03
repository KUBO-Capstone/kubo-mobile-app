import 'package:flutter/material.dart';

import 'core/constants/app_colors.dart';
import 'features/explore/screens/explore_page.dart';
import 'features/login/screens/create_account_page.dart';
import 'features/login/screens/get_started_page.dart';
import 'features/login/screens/login_page.dart';

class KuboApp extends StatelessWidget {
  const KuboApp({super.key});

  @override
  Widget build(BuildContext context) {
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
      },
      initialRoute: LoginPage.routeName,
    );
  }
}