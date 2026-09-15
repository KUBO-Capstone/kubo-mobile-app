import 'package:flutter/material.dart';

import '../../../core/constants/app_colors.dart';
import '../widgets/messages_view.dart';

/// Inbox, pushed from the chat icon in the explore app bar.
class MessagesPage extends StatelessWidget {
  const MessagesPage({super.key});

  static const routeName = '/messages';

  @override
  Widget build(BuildContext context) {
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
        title: const Text(
          'MESSAGES',
          style: TextStyle(
            color: AppColors.black,
            fontSize: 14,
            fontWeight: FontWeight.w700,
            letterSpacing: 1.2,
          ),
        ),
      ),
      body: const MessagesView(),
    );
  }
}
