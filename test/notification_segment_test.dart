import 'package:daily_meal/features/admin/data/models/notification_segment.dart';
import 'package:flutter_test/flutter_test.dart';

/// The two halves of the audience contract, tested as the pure encoding they
/// are: the panel's selectors are built from these same lists, so what holds
/// here is what a broadcast and its drafts can ever contain.
void main() {
  group('segment encoding', () {
    test('the document shape never varies', () {
      expect(NotificationSegment.encode(kind: 'all', days: 30), {
        'v': 1,
        'kind': 'all',
        'days': 30,
      });
      expect(NotificationSegment.encode(kind: 'returning', days: 30), {
        'v': 1,
        'kind': 'returning',
        'days': 30,
      });
      expect(NotificationSegment.encode(kind: 'new', days: 21), {
        'v': 1,
        'kind': 'new',
        'days': 21,
      });
    });

    test('the rule version is the one the app resolves', () {
      final encoded = NotificationSegment.encode(
        kind: 'new',
        days: NotificationSegment.defaultDays,
      );
      expect(encoded['v'], NotificationSegment.ruleVersion);
    });

    test('a kind outside the contract is coerced, never written', () {
      for (final kind in ['active', 'ALL', '', 'veteran', 'new ']) {
        expect(
          NotificationSegment.encode(kind: kind, days: 7)['kind'],
          NotificationSegment.kindAll,
          reason: 'unknown kind "$kind" must fall back to all',
        );
      }
      expect(NotificationSegment.encode(kind: 'new', days: 7)['kind'], 'new');
    });

    test('the window stays inside the range the rules accept', () {
      expect(NotificationSegment.encode(kind: 'new', days: 0)['days'], 1);
      expect(NotificationSegment.encode(kind: 'new', days: -50)['days'], 1);
      expect(NotificationSegment.encode(kind: 'new', days: 366)['days'], 365);
      expect(NotificationSegment.encode(kind: 'new', days: 9000)['days'], 365);
      expect(NotificationSegment.encode(kind: 'new', days: 1)['days'], 1);
      expect(NotificationSegment.encode(kind: 'new', days: 365)['days'], 365);
    });

    test('every offered stage carries a label', () {
      expect(NotificationSegment.kinds, ['all', 'new', 'returning']);
      for (final kind in NotificationSegment.kinds) {
        expect(NotificationSegment.stageLabels[kind], isNotNull);
      }
    });
  });

  group('draft restore and history reading', () {
    test('a document from before lifecycle targeting reads as every stage', () {
      expect(NotificationSegment.kindFrom(null), NotificationSegment.kindAll);
      expect(
        NotificationSegment.daysFrom(null),
        NotificationSegment.defaultDays,
      );
      expect(
        NotificationSegment.describeDocument(null),
        NotificationSegment.stageLabel(NotificationSegment.kindAll),
      );
      expect(NotificationSegment.kindFrom('new'), NotificationSegment.kindAll);
      expect(NotificationSegment.daysFrom({'days': '14'}), 7);
    });

    test('a stored map survives the round trip back into the form', () {
      final stored = NotificationSegment.encode(kind: 'new', days: 14);
      expect(NotificationSegment.kindFrom(stored), 'new');
      expect(NotificationSegment.daysFrom(stored), 14);
      expect(
        NotificationSegment.describeDocument(stored),
        'مستخدمون جدد — أول 14 أيام',
      );

      final legacy = {'v': 1, 'kind': 'returning'};
      expect(NotificationSegment.kindFrom(legacy), 'returning');
      expect(NotificationSegment.daysFrom(legacy), 7);
    });

    test('a draft edited from one stage to another keeps a valid window', () {
      // What the compose form does: restore, then re-encode on save.
      final restored = NotificationSegment.encode(
        kind: NotificationSegment.kindFrom({'kind': 'returning', 'days': 900}),
        days: NotificationSegment.daysFrom({'kind': 'returning', 'days': 900}),
      );
      expect(restored, {'v': 1, 'kind': 'returning', 'days': 365});
    });
  });

  test('the day window is spelled out only where it means something', () {
    expect(NotificationSegment.describe('new', 7), 'مستخدمون جدد — أول 7 أيام');
    expect(NotificationSegment.describe('all', 7), 'كل المراحل');
    expect(NotificationSegment.describe('returning', 45), 'مستخدمون قدامى');
    // An unresolvable kind has no window to describe either.
    expect(NotificationSegment.describe('active', 45), 'كل المراحل');
  });
}
