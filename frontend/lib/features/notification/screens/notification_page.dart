import 'package:flutter/material.dart';

import '../../../core/constants/app_colors.dart';
import '../providers/notification_badge_controller.dart';
import '../providers/notification_provider.dart';
import 'notification_detail_page.dart';
import '../widgets/notification_card.dart';

/// Displays seller and order activity notifications. Pull down to refresh;
/// the filter button narrows the list (Unread, Messages, Offers, Orders,
/// Reviews); Mark All as Read clears every unread mark at once.
class NotificationPage extends StatefulWidget {
  const NotificationPage({super.key, this.provider});

  static const routeName = '/notifications';

  /// For tests; the page makes its own otherwise.
  final NotificationProvider? provider;

  @override
  State<NotificationPage> createState() => _NotificationPageState();
}

class _NotificationPageState extends State<NotificationPage> {
  late final NotificationProvider _provider = widget.provider ?? NotificationProvider();
  List<NotificationRecord>? _notifications;
  String? _error;
  bool _markingAll = false;
  NotificationFilter _filter = NotificationFilter.all;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    if (widget.provider == null) _provider.dispose();
    super.dispose();
  }

  /// [pulled] is a pull-to-refresh: a failure then keeps the list on screen
  /// and says so in a snackbar.
  Future<void> _load({bool pulled = false}) async {
    try {
      final notifications = await _provider.fetchNotifications();
      if (!mounted) return;
      setState(() {
        _notifications = notifications;
        _error = null;
      });
      _syncBadge();
    } catch (error) {
      if (!mounted) return;
      final message = error.toString().replaceFirst('Exception: ', '');
      if (pulled && _notifications != null) {
        ScaffoldMessenger.of(context)
          ..hideCurrentSnackBar()
          ..showSnackBar(const SnackBar(content: Text('Could not refresh. Check your connection and try again.')));
      } else {
        setState(() => _error = message);
      }
    }
  }

  // The bell shows what this list says, so the two never disagree.
  void _syncBadge() {
    final unread = _notifications?.where((n) => !n.isRead).length ?? 0;
    NotificationBadgeController.instance.setCount(unread);
  }

  bool get _hasUnread => _notifications?.any((n) => !n.isRead) ?? false;

  // Marked on screen at once; put back if the server says no.
  Future<void> _markAllRead() async {
    final before = _notifications;
    if (before == null || !_hasUnread) return;
    setState(() {
      _markingAll = true;
      _notifications = [for (final n in before) n.asRead()];
    });
    _syncBadge();
    try {
      await _provider.markAllRead();
    } catch (error) {
      if (!mounted) return;
      setState(() => _notifications = before);
      _syncBadge();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(error.toString().replaceFirst('Exception: ', ''))),
      );
    } finally {
      if (mounted) setState(() => _markingAll = false);
    }
  }

  void _open(NotificationRecord notification) {
    final id = notification.id;
    if (!notification.isRead && id != null) {
      setState(() {
        _notifications = [
          for (final n in _notifications ?? const <NotificationRecord>[]) identical(n, notification) ? n.asRead() : n,
        ];
      });
      _syncBadge();
      // Not worth bothering anyone over: it shows as unread again next time.
      _provider.markRead(id).catchError((_) {});
    }
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => NotificationDetailPage(notification: notification),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final filtering = _filter != NotificationFilter.all;
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
        actions: [
          PopupMenuButton<NotificationFilter>(
            tooltip: 'Filter',
            initialValue: _filter,
            onSelected: (filter) => setState(() => _filter = filter),
            itemBuilder: (_) => [
              for (final filter in NotificationFilter.values)
                CheckedPopupMenuItem<NotificationFilter>(
                  value: filter,
                  checked: filter == _filter,
                  child: Text(filter.label),
                ),
            ],
            // A green dot while a filter is on, so a short list is not
            // mistaken for everything there is.
            icon: Badge(
              isLabelVisible: filtering,
              smallSize: 8,
              backgroundColor: AppColors.green,
              child: Icon(Icons.filter_list, color: filtering ? AppColors.green : AppColors.black),
            ),
          ),
          // Greyed out when there is nothing unread.
          TextButton(
            onPressed: _hasUnread && !_markingAll ? _markAllRead : null,
            style: TextButton.styleFrom(foregroundColor: AppColors.green),
            child: const Text('Mark All as Read', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700)),
          ),
        ],
      ),
      body: Column(
        children: [
          if (filtering)
            Padding(
              padding: const EdgeInsets.fromLTRB(22, 0, 22, 6),
              child: Align(
                alignment: Alignment.centerLeft,
                child: InputChip(
                  label: Text('Showing: ${_filter.label}'),
                  onDeleted: () => setState(() => _filter = NotificationFilter.all),
                  deleteButtonTooltipMessage: 'Show All',
                  backgroundColor: AppColors.white,
                  side: const BorderSide(color: AppColors.green),
                ),
              ),
            ),
          Expanded(
            child: RefreshIndicator(
              color: AppColors.green,
              onRefresh: () => _load(pulled: true),
              child: _buildBody(),
            ),
          ),
        ],
      ),
    );
  }

  // Every state is a scrollable, so each one can be pulled to refresh.
  Widget _buildBody() {
    final all = _notifications;
    if (all == null && _error == null) {
      return const Center(child: CircularProgressIndicator(color: AppColors.green));
    }
    final notifications = all?.where(_filter.matches).toList() ?? const <NotificationRecord>[];
    if (notifications.isEmpty) {
      final message = _error ??
          (_filter == NotificationFilter.all
              ? 'No notifications yet'
              : _filter == NotificationFilter.unread
                  ? 'You are all caught up.'
                  : 'No ${_filter.label.toLowerCase()} notifications.');
      return LayoutBuilder(
        builder: (context, constraints) => SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          child: SizedBox(
            height: constraints.maxHeight,
            child: Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Text(
                  message,
                  textAlign: TextAlign.center,
                  style: const TextStyle(color: AppColors.gray, fontSize: 14),
                ),
              ),
            ),
          ),
        ),
      );
    }
    return ListView.separated(
      physics: const AlwaysScrollableScrollPhysics(),
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
          unread: !notification.isRead,
          onTap: () => _open(notification),
        );
      },
    );
  }
}
