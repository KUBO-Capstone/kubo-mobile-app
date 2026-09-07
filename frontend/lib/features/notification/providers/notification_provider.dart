import '../../../shared/data/synthetic_records.dart';

/// Supplies notification records to the notification screen.
List<SyntheticNotificationRecord> getNotifications() {
  return List<SyntheticNotificationRecord>.unmodifiable(syntheticNotifications);
}
