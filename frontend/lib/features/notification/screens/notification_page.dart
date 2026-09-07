import 'package:flutter/material.dart';

import '../../../core/constants/app_colors.dart';
import '../providers/notification_provider.dart';
import '../widgets/notification_card.dart';

/// Displays seller and order activity notifications.
class NotificationPage extends StatelessWidget {
  const NotificationPage({super.key});

  static const routeName = '/notifications';

  @override
  Widget build(BuildContext context) {
    final notifications = getNotifications();

    return Scaffold(
      backgroundColor: AppColors.softBackground,
      appBar: AppBar(
        backgroundColor: AppColors.softBackground,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        title: const Text(
          'Notifications',
          style: TextStyle(
            color: AppColors.black,
            fontSize: 20,
            fontWeight: FontWeight.w700,
          ),
        ),
      ),
      body:
          notifications.isEmpty
              ? const Center(
                child: Text(
                  'No notifications yet',
                  style: TextStyle(color: AppColors.gray, fontSize: 14),
                ),
              )
              : ListView.separated(
                padding: const EdgeInsets.fromLTRB(22, 8, 22, 24),
                itemCount: notifications.length,
                separatorBuilder: (_, __) => const SizedBox(height: 12),
                itemBuilder: (_, index) {
                  final notification = notifications[index];
                  return buildNotificationCard(
                    title: notification.title,
                    message: notification.message,
                    date: notification.date,
                    time: notification.time,
                    image: notification.imageAssetPath,
                  );
                },
              ),
    );
  }
}
