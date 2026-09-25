const _months = [
  'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
  'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec',
];

/// Short "how long ago": `now`, `5m`, `3h`, `2d`, then `Sep 3` /
/// `Sep 3, 2024`.
String relativeTime(DateTime time, {DateTime? now}) {
  final current = now ?? DateTime.now();
  final diff = current.difference(time);
  if (diff.inMinutes < 1) return 'now';
  if (diff.inHours < 1) return '${diff.inMinutes}m';
  if (diff.inDays < 1) return '${diff.inHours}h';
  if (diff.inDays < 7) return '${diff.inDays}d';
  final local = time.toLocal();
  final day = '${_months[local.month - 1]} ${local.day}';
  return local.year == current.year ? day : '$day, ${local.year}';
}
