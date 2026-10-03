import 'package:flutter/material.dart';

import '../../../core/constants/app_colors.dart';
import '../providers/notification_provider.dart';
import 'notification_detail_page.dart';
import '../widgets/notification_card.dart';

/// Displays seller and order activity notifications.
class NotificationPage extends StatefulWidget {
  const NotificationPage({super.key});

  static const routeName = '/notifications';

  @override
  State<NotificationPage> createState() => _NotificationPageState();
}

class _NotificationPageState extends State<NotificationPage> {
  final NotificationProvider _provider = NotificationProvider();
  late Future<List<NotificationRecord>> _notifications;

  @override
  void initState() {
    super.initState();
    _notifications = _provider.fetchNotifications();
  }

  @override
  void dispose() {
    _provider.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.softBackground,
      appBar: AppBar(
        backgroundColor: AppColors.softBackground,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        centerTitle: true,
        title: const Text(
          'NOTIFICATIONS',
          style: TextStyle(
            color: AppColors.black,
            fontSize: 14,
            fontWeight: FontWeight.w700,
            letterSpacing: 1.2,
          ),
        ),
      ),
      body: FutureBuilder<List<NotificationRecord>>(
        future: _notifications,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError) {
            return Center(
              child: Text(
                snapshot.error.toString().replaceFirst('Exception: ', ''),
                textAlign: TextAlign.center,
                style: const TextStyle(color: AppColors.gray, fontSize: 14),
              ),
            );
          }
          final notifications = snapshot.data ?? const <NotificationRecord>[];
          if (notifications.isEmpty) {
            return const Center(
              child: Text(
                'No notifications yet',
                style: TextStyle(color: AppColors.gray, fontSize: 14),
              ),
            );
          }
          return ListView.separated(
            padding: const EdgeInsets.fromLTRB(22, 8, 22, 24),
            itemCount: notifications.length,
            separatorBuilder: (_, __) => const SizedBox(height: 12),
            itemBuilder: (_, index) {
              final notification = notifications[index];
              return buildNotificationCard(
                title: notification.title,
                message: notification.displayMessage,
                date: notification.date,
                time: notification.time,
                image: 'assets/images/Placeholder_img.png',
                onTap: () {
                  Navigator.of(context).push(
                    MaterialPageRoute<void>(
                      builder: (_) => NotificationDetailPage(notification: notification),
                    ),
                  );
                },
              );
            },
          );
        },
      ),
    );
  }
}
