import 'package:daily_meal/core/router/app_router.dart';
import 'package:daily_meal/features/admin/presentation/widgets/admin_toast.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  Future<void> pumpHost(WidgetTester tester, {bool dark = false}) async {
    await tester.pumpWidget(MaterialApp(
      navigatorKey: rootNavigatorKey,
      theme: ThemeData(brightness: Brightness.light),
      darkTheme: ThemeData(brightness: Brightness.dark),
      themeMode: dark ? ThemeMode.dark : ThemeMode.light,
      home: const Scaffold(body: SizedBox.expand()),
    ));
  }

  /// The painted card surface of the newest toast.
  Color cardSurface(WidgetTester tester) => tester
      .widgetList<Material>(find.descendant(
          of: find.byType(AdminToastCard), matching: find.byType(Material)))
      .first
      .color!;

  setUp(() {
    AdminToastRegistry.instance.debugReset();
    AdminToastOverlay.debugUnmount();
  });
  tearDown(() {
    AdminToastRegistry.instance.debugReset();
    AdminToastOverlay.debugUnmount();
  });

  test('taxonomy covers acknowledgement, attention and status tiers', () {
    expect(AdminToastKind.values,
        containsAll(<AdminToastKind>[
          AdminToastKind.info,
          AdminToastKind.success,
          AdminToastKind.warning,
          AdminToastKind.error,
          AdminToastKind.loading,
          AdminToastKind.offline,
        ]));
    // Status tiers never expire on their own; they wait to be resolved.
    expect(AdminToastKind.loading.spec.autoDismiss, isNull);
    expect(AdminToastKind.offline.spec.autoDismiss, isNull);
    expect(AdminToastKind.error.spec.autoDismiss! >
            AdminToastKind.info.spec.autoDismiss!,
        isTrue);
  });

  test('undo-bearing toasts wait, pure status ones disappear quickly', () {
    final status = AdminToastItem(
      id: 'status',
      message: 'تم الاعتماد',
      kind: AdminToastKind.warning,
    );
    final actionable = AdminToastItem(
      id: 'actionable',
      message: 'تم الحذف',
      kind: AdminToastKind.warning,
      onUndo: () {},
    );

    expect(actionable.lifetime, AdminToastItem.actionWindow);
    expect(actionable.lifetime!, greaterThan(status.lifetime!));
    expect(status.lifetime!, lessThan(const Duration(seconds: 4)));
  });

  testWidgets('newest toast sits at the bottom, older ones stack above it',
      (tester) async {
    await pumpHost(tester);

    AdminToast.show(message: 'first', kind: AdminToastKind.info);
    await tester.pump(const Duration(milliseconds: 400));
    AdminToast.show(message: 'second', kind: AdminToastKind.info);
    await tester.pump(const Duration(milliseconds: 400));
    AdminToast.show(message: 'third', kind: AdminToastKind.info);
    await tester.pump(const Duration(milliseconds: 400));

    final cards = tester.widgetList<AdminToastCard>(find.byType(AdminToastCard));
    expect(cards, hasLength(3));

    final tops = find
        .byType(AdminToastCard)
        .evaluate()
        .map((e) => (e.renderObject as RenderBox?)?.localToGlobal(Offset.zero).dy)
        .toList();
    expect(tops[0], lessThan(tops[1]!));
    expect(tops[1], lessThan(tops[2]!));

    // Newest is anchored to the bottom edge of the stack area.
    final newestRect = tester.getRect(find.byType(AdminToastCard).last);
    expect(tester.view.physicalSize.height / tester.view.devicePixelRatio -
        newestRect.bottom,
        closeTo(28, 1));
  });

  testWidgets('a loading toast resolves in place instead of stacking a new one',
      (tester) async {
    await pumpHost(tester);

    final handle = AdminToast.loading(message: 'جارٍ الرفع');
    await tester.pump(const Duration(milliseconds: 400));
    expect(find.byType(CircularProgressIndicator), findsOneWidget);

    handle.resolve(
      message: 'تم الرفع',
      kind: AdminToastKind.success,
      duration: const Duration(milliseconds: 3000),
    );
    await tester.pump(const Duration(milliseconds: 400));

    expect(find.byType(AdminToastCard), findsOneWidget);
    expect(find.byType(CircularProgressIndicator), findsNothing);
    expect(find.text('تم الرفع'), findsOneWidget);
  });

  testWidgets('toasts dismiss themselves and collapse the stack', (tester) async {
    await pumpHost(tester);

    AdminToast.show(
      message: 'short lived',
      kind: AdminToastKind.success,
      duration: const Duration(milliseconds: 500),
    );
    await tester.pump(const Duration(milliseconds: 400));
    expect(find.byType(AdminToastCard), findsOneWidget);

    // lifetime + exit animation + collapse
    await tester.pump(const Duration(milliseconds: 600));
    await tester.pump(const Duration(milliseconds: 600));
    await tester.pump(const Duration(milliseconds: 400));
    expect(find.byType(AdminToastCard), findsNothing);
  });

  testWidgets('a full stack fades without overflowing the viewport',
      (tester) async {
    await pumpHost(tester);

    for (var i = 0; i < 12; i++) {
      AdminToast.show(message: 'message $i', kind: AdminToastKind.info);
    }
    await tester.pump(const Duration(milliseconds: 400));

    // Past half the viewport the stack paints through a fade mask, and it is
    // trimmed to what physically fits, so no overflow stripes appear.
    expect(tester.takeException(), isNull);
    final visible = AdminToastRegistry.instance.items.length;
    final stackBottom = tester
        .getRect(find.byType(AdminToastCard).last)
        .bottom;
    final stackTop = tester
        .getRect(find.byType(AdminToastCard).first)
        .top;
    expect(stackBottom, lessThanOrEqualTo(600 - 28 + 1));
    expect(stackTop, greaterThanOrEqualTo(0));
    expect(visible, greaterThan(2));
  });

  testWidgets('every toast lands in the notification centre log',
      (tester) async {    await pumpHost(tester);

    final handle = AdminToast.show(message: 'loading', kind: AdminToastKind.loading);
    handle.resolve(message: 'resolved', kind: AdminToastKind.success);
    await tester.pump(const Duration(milliseconds: 400));

    final history = AdminToastRegistry.instance.history;
    expect(history.first.kind, AdminToastKind.success);
    expect(history.first.message, 'resolved');
    expect(history.last.message, 'loading');
  });

  testWidgets('a light dashboard gets a dark toast card', (tester) async {
    await pumpHost(tester);
    AdminToast.show(message: 'تم الحفظ');
    await tester.pump(const Duration(milliseconds: 400));

    expect(cardSurface(tester), AdminToastTones.darkCard.card);
  });

  testWidgets('a dark dashboard gets a light toast card so it stands out',
      (tester) async {
    await pumpHost(tester, dark: true);
    AdminToast.show(message: 'تم الحفظ');
    await tester.pump(const Duration(milliseconds: 400));

    expect(cardSurface(tester), AdminToastTones.lightCard.card);
  });
}
