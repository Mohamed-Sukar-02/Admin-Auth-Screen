/// ===========================================================================
/// Lifecycle segment
///
/// Which stage of a user's life in the app a broadcast is announced to. It is
/// written as a nested map on both `admin_notifications` and
/// `admin_notification_drafts`:
///
///   `segment: { v: 1, kind: 'all' | 'new' | 'returning', days: 1..365 }`
///
/// `v` is the rule version the mobile app knows how to read. An app build that
/// cannot interpret the map stays silent about that broadcast instead of
/// guessing, so nothing outside the three kinds or the day range may ever leave
/// this panel — which is why every value entering or leaving a document is
/// coerced here rather than trusted.
///
/// `new` means "first app open within [days] days and never cooked a meal";
/// `returning` is its exact complement. [days] only decides the window for
/// `new`, but it is always written so the document shape never varies.
/// ===========================================================================
abstract final class NotificationSegment {
  static const int ruleVersion = 1;

  static const String kindAll = 'all';
  static const String kindNew = 'new';
  static const String kindReturning = 'returning';

  static const List<String> kinds = [kindAll, kindNew, kindReturning];

  static const int defaultDays = 7;
  static const int minDays = 1;
  static const int maxDays = 365;

  /// The stage names the admin picks. Kept next to the coercion so a label and
  /// its key can never drift apart.
  static const Map<String, String> stageLabels = {
    kindAll: 'الجميع',
    kindNew: 'مستخدمون جدد',
    kindReturning: 'مستخدمون قدامى',
  };

  /// A kind the app cannot resolve falls back to [kindAll], which is what an
  /// app from before this feature already behaves as.
  static String coerceKind(Object? kind) =>
      kind is String && kinds.contains(kind) ? kind : kindAll;

  /// Anything unreadable lands on the default window, anything out of range on
  /// the nearest edge — never a number the security rules would reject.
  static int clampDays(Object? days) {
    if (days is! num) return defaultDays;
    final value = days.round();
    if (value < minDays) return minDays;
    if (value > maxDays) return maxDays;
    return value;
  }

  /// The document body. Both halves are normalised even when the caller already
  /// picked from the panel's own lists, so there is one place that decides what
  /// a valid map looks like.
  static Map<String, dynamic> encode({
    required String kind,
    required int days,
  }) {
    return {
      'v': ruleVersion,
      'kind': coerceKind(kind),
      'days': clampDays(days),
    };
  }

  static String stageLabel(String kind) => stageLabels[coerceKind(kind)]!;

  /// The stage as a sentence, carrying the window only where it means
  /// something.
  static String describe(String kind, int days) {
    if (coerceKind(kind) == kindNew) {
      return '${stageLabels[kindNew]} — أول ${clampDays(days)} أيام';
    }
    return stageLabel(kind);
  }

  /// Reading a stored document: a broadcast from before lifecycle targeting
  /// carries no map at all, and reaches every stage.
  static String describeDocument(Object? segment) {
    return describe(kindFrom(segment), daysFrom(segment));
  }

  static String kindFrom(Object? segment) =>
      segment is Map ? coerceKind(segment['kind']) : kindAll;

  static int daysFrom(Object? segment) =>
      segment is Map ? clampDays(segment['days']) : defaultDays;
}
