import 'package:daily_meal/features/admin/presentation/widgets/notification_review.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

/// The audience half of the review dialog: the two targeting dimensions printed
/// as separate facts, and the honest caveat that an app build from before stage
/// filtering cannot honour it.
void main() {
  /// [screen] is the viewport the dialog was opened in and [body] the width the
  /// shell actually gives the review — the real dialog is wider on screen than
  /// the column it hands down, and the widget picks its layout from the screen.
  Future<void> pumpReview(
    WidgetTester tester, {
    required String segmentLabel,
    required bool segmentRestricted,
    required double screen,
    required double body,
  }) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Builder(
          builder: (context) => MediaQuery(
            data: MediaQuery.of(context).copyWith(size: Size(screen, 1000)),
            child: Directionality(
              textDirection: TextDirection.rtl,
              child: Scaffold(
                body: SizedBox(
                  width: body,
                  child: SingleChildScrollView(
                    child: NotificationReview(
                      titleAr: 'جاهزة للطبخ',
                      messageAr: 'اختارنا لك أكلة اليوم',
                      titleEn: 'Ready to cook',
                      messageEn: "Today's pick is waiting",
                      typeLabel: 'وجبة / اقتراح',
                      audienceLabel: 'العربية',
                      segmentLabel: segmentLabel,
                      segmentRestricted: segmentRestricted,
                      route: '/vault?tab=explore',
                      onDecision: (_) {},
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  testWidgets('language and stage are reviewed as two separate facts', (
    tester,
  ) async {
    await pumpReview(
      tester,
      segmentLabel: 'مستخدمون جدد — أول 7 أيام',
      segmentRestricted: true,
      screen: 900,
      body: 680,
    );

    expect(find.text('لغة المستخدمين:'), findsOneWidget);
    expect(find.text('مرحلة المستخدمين:'), findsOneWidget);
    expect(find.text('مستخدمون جدد — أول 7 أيام'), findsOneWidget);
    // The old single-line audience fact is gone rather than doubled up.
    expect(find.text('الجمهور:'), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('the old-build caveat appears only when the stage filters', (
    tester,
  ) async {
    await pumpReview(
      tester,
      segmentLabel: 'كل المراحل',
      segmentRestricted: false,
      screen: 900,
      body: 680,
    );
    expect(find.textContaining('تفرز بالمرحلة'), findsNothing);
    // The pull-based note is not conditional, so every review carries it.
    expect(find.textContaining('مفيش دفع فوري'), findsOneWidget);

    await pumpReview(
      tester,
      segmentLabel: 'مستخدمون قدامى',
      segmentRestricted: true,
      screen: 900,
      body: 680,
    );
    expect(find.textContaining('تفرز بالمرحلة'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('a phone-width review stacks the phone and still fits', (
    tester,
  ) async {
    await pumpReview(
      tester,
      segmentLabel: 'مستخدمون جدد — أول 365 أيام',
      segmentRestricted: true,
      screen: 420,
      body: 420,
    );

    expect(tester.takeException(), isNull);
    expect(find.text('مرحلة المستخدمين:'), findsOneWidget);
    expect(find.text('مستخدمون جدد — أول 365 أيام'), findsOneWidget);
  });
}
