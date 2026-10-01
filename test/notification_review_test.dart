import 'package:daily_meal/features/admin/presentation/widgets/notification_review.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

/// The audience half of the review dialog: the target-audience stage printed as
/// a fact, and the honest caveat that an app build from before stage filtering
/// cannot honour it.
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
    required double height,
  }) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Builder(
          builder: (context) => MediaQuery(
            data: MediaQuery.of(context).copyWith(size: Size(screen, height)),
            child: Directionality(
              textDirection: TextDirection.rtl,
              child: Scaffold(
                // The shell hands the review a bounded box and expects it to
                // fit, which is the whole point of the widget.
                body: Align(
                  alignment: Alignment.topLeft,
                  child: SizedBox(
                    width: body,
                    height: height - 130,
                    child: NotificationReview(
                      titleAr: 'جاهزة للطبخ',
                      messageAr: 'اختارنا لك أكلة اليوم',
                      titleEn: 'Ready to cook',
                      messageEn: "Today's pick is waiting",
                      typeLabel: 'وجبة / اقتراح',
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

  testWidgets('the target audience is reviewed as its own fact', (
    tester,
  ) async {
    await pumpReview(
      tester,
      segmentLabel: 'مستخدمون جدد — أول 7 أيام',
      segmentRestricted: true,
      screen: 900,
      body: 680,
      height: 900,
    );

    // The language selector is gone: only the stage fact remains.
    expect(find.text('لغة المستخدمين:'), findsNothing);
    expect(find.text('الجمهور المستهدف:'), findsOneWidget);
    expect(find.text('مستخدمون جدد — أول 7 أيام'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('the old-build caveat appears only when the stage filters', (
    tester,
  ) async {
    await pumpReview(
      tester,
      segmentLabel: 'الجميع',
      segmentRestricted: false,
      screen: 900,
      body: 680,
      height: 900,
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
      height: 900,
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
      height: 900,
    );

    expect(tester.takeException(), isNull);
    expect(find.text('الجمهور المستهدف:'), findsOneWidget);
    expect(find.text('مستخدمون جدد — أول 365 أيام'), findsOneWidget);
  });

  testWidgets('a short viewport still shows the whole review', (tester) async {
    await pumpReview(
      tester,
      segmentLabel: 'مستخدمون جدد — أول 7 أيام',
      segmentRestricted: true,
      screen: 900,
      body: 740,
      height: 520,
    );

    expect(tester.takeException(), isNull);
    // Nothing is pushed out of the box: the last note and both buttons are on
    // screen without a scrollbar.
    expect(find.textContaining('مفيش دفع فوري'), findsOneWidget);
    expect(find.text('تأكيد الإرسال'), findsOneWidget);
    expect(find.text('لسه هعدّل حاجة'), findsOneWidget);
  });
}
