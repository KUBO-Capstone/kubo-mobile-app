/// "₱3,100" for whole amounts, "₱1,234.50" otherwise.
String formatPeso(num value) {
  final negative = value < 0;
  final cents = (value.abs() * 100).round();
  final whole = _groupThousands((cents ~/ 100).toString());
  final fraction = cents % 100;
  final amount = fraction == 0 ? whole : '$whole.${fraction.toString().padLeft(2, '0')}';
  return '${negative ? '-' : ''}₱$amount';
}

String _groupThousands(String digits) {
  final buffer = StringBuffer();
  for (var i = 0; i < digits.length; i++) {
    if (i > 0 && (digits.length - i) % 3 == 0) buffer.write(',');
    buffer.write(digits[i]);
  }
  return buffer.toString();
}

/// Parses a backend timestamp. SQLite's CURRENT_TIMESTAMP is UTC without a
/// zone ("2026-10-29 08:23:11"), so a bare value is read as UTC.
DateTime? parseServerTime(String? raw) {
  if (raw == null || raw.trim().isEmpty) return null;
  final text = raw.trim().replaceFirst(' ', 'T');
  final hasZone = RegExp(r'(?:[zZ]|[+-]\d{2}:?\d{2})$').hasMatch(text);
  return DateTime.tryParse(hasZone ? text : '${text}Z')?.toLocal();
}

const _monthNames = <String>['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];

/// "Just now", "5m ago", "3h ago", "2d ago", "3w ago", then "Mar 2026".
String timeAgo(DateTime? date, {DateTime? now}) {
  if (date == null) return '';
  final elapsed = (now ?? DateTime.now()).difference(date);
  if (elapsed.inMinutes < 1) return 'Just now';
  if (elapsed.inHours < 1) return '${elapsed.inMinutes}m ago';
  if (elapsed.inDays < 1) return '${elapsed.inHours}h ago';
  if (elapsed.inDays < 7) return '${elapsed.inDays}d ago';
  if (elapsed.inDays < 35) return '${elapsed.inDays ~/ 7}w ago';
  return monthYear(date);
}

/// "Mar 2026".
String monthYear(DateTime date) => '${_monthNames[date.month - 1]} ${date.year}';
