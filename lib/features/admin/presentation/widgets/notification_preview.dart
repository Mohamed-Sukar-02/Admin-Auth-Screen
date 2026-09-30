import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../theme/admin_palette.dart';
import 'admin_dialog.dart';

/// Which phone the preview is currently drawing.
enum NotificationDevice { iphone, android }

/// ===========================================================================
/// Notification preview — two real phone mockups, and the push on their glass
/// ===========================================================================
/// The mockups preview a broadcast by drawing the device it lands on. The
/// hardware is now a photograph — `assets/images/iphone_moc.jpg` and
/// `assets/images/android_moc.jpg` — and everything inside the glass is painted
/// by this file, so the admin sees the notification at the size, position and
/// platform chrome the user will actually get.
///
/// The two photos ship with an empty white display, which is what makes the
/// overlay possible: [_Mockup] records where each photo's glass, corner radius
/// and camera cutout sit in source pixels (measured off the files), and the
/// screen content is clipped to that rectangle. The frame, the Dynamic Island
/// and the punch-hole come from the photo, never from us.
///
/// `app_v2` ships no FCM: an admin broadcast becomes a local notification built
/// by `NotificationService.showAdminNotification` with
/// `AndroidNotificationDetails('admin_announcements_channel', …,
/// importance: max, priority: high, showWhen: true)` and nothing else — no
/// large icon, no big-text style, no colour. So the Android row is a flat
/// single-colour app glyph, the OS app name, "· now", the title and one
/// collapsed body line. iOS renders the same payload its own way: the coloured
/// launcher icon, the app name leading and "now" trailing, and a body that is
/// allowed to wrap. Every difference below is a platform difference, not a
/// flourish.
class NotificationPreview extends StatefulWidget {
  /// Width, in logical pixels, of the glass area of either phone. Both devices
  /// are scaled to the same glass width so their type sits at the same size and
  /// the admin is comparing layouts rather than zoom levels.
  static const double glassWidth = 240;

  /// Full outer width of the drawn phone — what a parent must reserve.
  static double get width => _tallest.boxWidth;

  /// Full outer height of the tallest device, which is what the page is sized
  /// to so switching phones does not resize the dialog.
  static double get height => _tallest.boxHeight;

  static _Mockup get _tallest {
    final a = _Mockup.iphone, b = _Mockup.android;
    return a.boxHeight >= b.boxHeight ? a : b;
  }

  /// The app truncates what the admin typed before it reaches the shade
  /// (`notification_sync_service.dart` in the mobile app).
  static const int _titleCap = 80;
  static const int _bodyCap = 240;

  final String titleAr;
  final String messageAr;
  final String titleEn;
  final String messageEn;
  final bool arabic;
  final ValueChanged<bool> onPickArabic;

  const NotificationPreview({
    super.key,
    required this.titleAr,
    required this.messageAr,
    required this.titleEn,
    required this.messageEn,
    required this.arabic,
    required this.onPickArabic,
  });

  @override
  State<NotificationPreview> createState() => _NotificationPreviewState();
}

class _NotificationPreviewState extends State<NotificationPreview> {
  static const List<_Mockup> _devices = [_Mockup.iphone, _Mockup.android];

  late final PageController _pages = PageController();
  int _device = 0;

  @override
  void dispose() {
    _pages.dispose();
    super.dispose();
  }

  String get _title {
    final raw = widget.arabic ? widget.titleAr : widget.titleEn;
    // An empty title does not fall back to the other language — the app puts
    // its own default in that slot.
    if (raw.isNotEmpty) return _cap(raw, NotificationPreview._titleCap);
    return widget.arabic ? 'أكلة النهاردة 🍽️' : 'Daily Meal 🍽️';
  }

  String get _body => _cap(
    widget.arabic ? widget.messageAr : widget.messageEn,
    NotificationPreview._bodyCap,
  );

  static String _cap(String value, int limit) =>
      value.length <= limit ? value : '${value.substring(0, limit - 3)}...';

  @override
  Widget build(BuildContext context) {
    final p = AdminPalette.of(context);
    final phone = _PhoneSurface.of(p);

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        _SegmentedControl(
          index: _device,
          onPick: (index) {
            setState(() => _device = index);
            _pages.animateToPage(
              index,
              duration: const Duration(milliseconds: 260),
              curve: Curves.easeOutCubic,
            );
          },
          items: const [
            _Segment('iPhone', latin: true),
            _Segment('Android', latin: true),
          ],
        ),
        const SizedBox(height: 10),
        _SegmentedControl(
          index: widget.arabic ? 0 : 1,
          onPick: (index) => widget.onPickArabic(index == 0),
          items: const [
            _Segment('العربية'),
            _Segment('English', latin: true),
          ],
        ),
        const SizedBox(height: 18),
        SizedBox(
          width: NotificationPreview.width,
          height: NotificationPreview.height,
          child: PageView.builder(
            controller: _pages,
            itemCount: _devices.length,
            physics: const ClampingScrollPhysics(),
            onPageChanged: (index) => setState(() => _device = index),
            itemBuilder: (context, index) {
              final m = _devices[index];
              return Center(
                child: SizedBox.fromSize(
                  size: Size(m.boxWidth, m.boxHeight),
                  child: _Phone(
                    mockup: m,
                    phone: phone,
                    arabic: widget.arabic,
                    title: _title,
                    body: _body,
                  ),
                ),
              );
            },
          ),
        ),
      ],
    );
  }
}

/// ---------------------------------------------------------------------------
/// Where the glass sits inside each photograph
/// ---------------------------------------------------------------------------
/// Every number here is measured off the asset in source pixels, not guessed:
/// the glass rectangle, the corner radius that rounds it, and the camera
/// cutout the status bar has to type around. [crop] is the phone's own
/// silhouette plus a few pixels of cast shadow — the photos carry a white
/// margin, and cropping to the silhouette is what lets both devices render at
/// the same scale instead of one hiding inside its canvas.
class _Mockup {
  final String asset;

  /// Size of the photograph itself.
  final double canvasWidth;
  final double canvasHeight;

  /// Region of the photograph that is actually shown.
  final Rect crop;

  /// The display area, in photograph pixels.
  final Rect glass;
  final double glassRadius;

  /// Dynamic Island / punch-hole, in photograph pixels.
  final Rect cutout;

  /// True for the phone whose glass is drawn by the iOS notification layout.
  final bool iOs;

  const _Mockup({
    required this.asset,
    required this.canvasWidth,
    required this.canvasHeight,
    required this.crop,
    required this.glass,
    required this.glassRadius,
    required this.cutout,
    required this.iOs,
  });

  static const _Mockup iphone = _Mockup(
    asset: 'assets/images/iphone_moc.jpg',
    canvasWidth: 417,
    canvasHeight: 626,
    crop: Rect.fromLTWH(73, 45, 274, 540),
    glass: Rect.fromLTWH(91, 62, 235, 501),
    glassRadius: 24,
    cutout: Rect.fromLTWH(172, 73, 73, 21),
    iOs: true,
  );

  static const _Mockup android = _Mockup(
    asset: 'assets/images/android_moc.jpg',
    canvasWidth: 626,
    canvasHeight: 626,
    crop: Rect.fromLTWH(190, 57, 242, 510),
    glass: Rect.fromLTWH(208, 75, 208, 471),
    glassRadius: 13,
    cutout: Rect.fromLTWH(307, 81, 10, 10),
    iOs: false,
  );

  /// Photograph pixels per logical pixel once the glass is at [NotificationPreview.glassWidth].
  double get _k => NotificationPreview.glassWidth / glass.width;

  double get boxWidth => crop.width * _k;
  double get boxHeight => crop.height * _k;

  /// The glass, positioned inside the shown crop.
  Rect get glassRect => Rect.fromLTWH(
    (glass.left - crop.left) * _k,
    (glass.top - crop.top) * _k,
    glass.width * _k,
    glass.height * _k,
  );

  /// The camera cutout, positioned inside [glassRect].
  Rect get cutoutRect => Rect.fromLTWH(
    (cutout.left - glass.left) * _k,
    (cutout.top - glass.top) * _k,
    cutout.width * _k,
    cutout.height * _k,
  );

  double get roundedGlass => glassRadius * _k;

  /// How far the crop pushes the phone away from the edge of the photograph.
  Alignment get _cropAlignment => Alignment(
    2 * crop.left / (canvasWidth - crop.width) - 1,
    2 * crop.top / (canvasHeight - crop.height) - 1,
  );
}

/// ---------------------------------------------------------------------------
/// The device
/// ---------------------------------------------------------------------------
class _Phone extends StatelessWidget {
  final _Mockup mockup;
  final _PhoneSurface phone;
  final bool arabic;
  final String title;
  final String body;

  const _Phone({
    required this.mockup,
    required this.phone,
    required this.arabic,
    required this.title,
    required this.body,
  });

  @override
  Widget build(BuildContext context) {
    final glass = mockup.glassRect;

    return Stack(
      clipBehavior: Clip.none,
      children: [
        // The photograph, trimmed to the phone.
        Positioned(
          left: 0,
          top: 0,
          child: ClipRect(
            child: SizedBox(
              width: mockup.boxWidth,
              height: mockup.boxHeight,
              child: OverflowBox(
                alignment: mockup._cropAlignment,
                minWidth: 0,
                maxWidth: double.infinity,
                minHeight: 0,
                maxHeight: double.infinity,
                child: SizedBox(
                  width: mockup.canvasWidth * (NotificationPreview.glassWidth / mockup.glass.width),
                  height: mockup.canvasHeight * (NotificationPreview.glassWidth / mockup.glass.width),
                  child: Image.asset(
                    mockup.asset,
                    fit: BoxFit.fill,
                    filterQuality: FilterQuality.medium,
                    errorBuilder: (_, _, _) => const SizedBox.shrink(),
                  ),
                ),
              ),
            ),
          ),
        ),
        // Everything the display is showing.
        Positioned.fromRect(
          rect: glass,
          child: ClipRRect(
            borderRadius: BorderRadius.circular(mockup.roundedGlass),
            child: DecoratedBox(
              decoration: BoxDecoration(gradient: phone.screen),
              child: LayoutBuilder(
                builder: (context, constraints) => _LockScreen(
                  size: constraints.biggest,
                  mockup: mockup,
                  phone: phone,
                  arabic: arabic,
                  title: title,
                  body: body,
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}

/// The painted display: status bar, lock-screen clock, the push, the gesture
/// pill. Placement is expressed as a fraction of the glass so the same layout
/// holds at any [NotificationPreview.glassWidth].
class _LockScreen extends StatelessWidget {
  final Size size;
  final _Mockup mockup;
  final _PhoneSurface phone;
  final bool arabic;
  final String title;
  final String body;

  const _LockScreen({
    required this.size,
    required this.mockup,
    required this.phone,
    required this.arabic,
    required this.title,
    required this.body,
  });

  /// Type and spacing scale off the glass width, which is the one dimension
  /// both devices share.
  double get u => size.width;

  /// Vertical placement scales off the glass height.
  double get v => size.height;

  @override
  Widget build(BuildContext context) {
    final cutout = mockup.cutoutRect;

    return Stack(
      children: [
        // Status bar. The OS keeps it left-to-right even in an Arabic locale —
        // the clock stays on the left, the battery on the right — so only the
        // notification below mirrors.
        Positioned(
          left: u * (mockup.iOs ? 0.062 : 0.048),
          top: mockup.iOs
              ? cutout.center.dy - u * 0.026
              : cutout.bottom + v * 0.004,
          child: Text(
            '9:41',
            textDirection: TextDirection.ltr,
            style: adminLatinText(
              size: u * (mockup.iOs ? 0.042 : 0.034),
              weight: FontWeight.w600,
              color: phone.statusText,
            ),
          ),
        ),
        Positioned(
          right: u * (mockup.iOs ? 0.052 : 0.044),
          top: mockup.iOs
              ? cutout.center.dy - u * 0.020
              : cutout.bottom + v * 0.006,
          child: _StatusBarGlyphs(phone: phone, width: u, iOs: mockup.iOs),
        ),
        if (mockup.iOs) ..._iosChrome(),
        if (!mockup.iOs) ..._androidChrome(),
        // The gesture pill, which neither photograph ships with.
        Positioned(
          bottom: v * (mockup.iOs ? 0.018 : 0.014),
          left: 0,
          right: 0,
          child: Center(
            child: Container(
              width: u * (mockup.iOs ? 0.34 : 0.28),
              height: math.max(2, u * 0.011),
              decoration: BoxDecoration(
                color: phone.homeLine,
                borderRadius: BorderRadius.circular(u * 0.011),
              ),
            ),
          ),
        ),
      ],
    );
    // ignore: dead_code
  }

  /// iOS centres the date and the clock and stacks the push under them.
  List<Widget> _iosChrome() => [
    Positioned(
      top: v * 0.112,
      left: 0,
      right: 0,
      child: Text(
        arabic ? '٣٠ سبتمبر' : 'September 30',
        textAlign: TextAlign.center,
        textDirection: arabic ? TextDirection.rtl : TextDirection.ltr,
        style: adminText(
          size: u * 0.047,
          weight: FontWeight.w500,
          color: phone.dateText,
        ),
      ),
    ),
    Positioned(
      top: v * 0.138,
      left: 0,
      right: 0,
      child: Text(
        '9:41',
        textAlign: TextAlign.center,
        textDirection: TextDirection.ltr,
        style: adminLatinText(
          size: u * 0.205,
          weight: FontWeight.w500,
          color: phone.clockText,
          height: 1.1,
          letterSpacing: -u * 0.004,
        ),
      ),
    ),
    Positioned(
      top: v * 0.300,
      left: u * 0.042,
      right: u * 0.042,
      child: _IosPush(
        width: u,
        phone: phone,
        arabic: arabic,
        title: title,
        body: body,
        appName: arabic ? 'أكلة النهاردة' : 'Daily Meal',
      ),
    ),
  ];

  /// Android left-aligns a lighter clock and lets the push sit closer to it.
  List<Widget> _androidChrome() => [
    Positioned(
      top: v * 0.070,
      left: u * 0.070,
      child: Text(
        '9:41',
        textDirection: TextDirection.ltr,
        style: adminLatinText(
          size: u * 0.185,
          weight: FontWeight.w300,
          color: phone.clockText,
          height: 1.05,
          letterSpacing: -u * 0.002,
        ),
      ),
    ),
    Positioned(
      top: v * 0.150,
      left: u * 0.073,
      child: Text(
        arabic ? '٣٠ سبتمبر' : 'September 30',
        textDirection: arabic ? TextDirection.rtl : TextDirection.ltr,
        style: adminText(
          size: u * 0.040,
          weight: FontWeight.w400,
          color: phone.dateText,
        ),
      ),
    ),
    Positioned(
      top: v * 0.245,
      left: u * 0.030,
      right: u * 0.030,
      child: _AndroidPush(
        width: u,
        phone: phone,
        arabic: arabic,
        title: title,
        body: body,
        // Android reads the label from android:label, which is transliterated
        // outside Arabic system locales.
        appName: arabic ? 'أكلة النهاردة' : 'Aklit Elnaharda',
      ),
    ),
  ];
}

/// ---------------------------------------------------------------------------
/// The push, iOS flavour
/// ---------------------------------------------------------------------------
class _IosPush extends StatelessWidget {
  final double width;
  final _PhoneSurface phone;
  final bool arabic;
  final String appName;
  final String title;
  final String body;

  const _IosPush({
    required this.width,
    required this.phone,
    required this.arabic,
    required this.appName,
    required this.title,
    required this.body,
  });

  double get s => width;

  @override
  Widget build(BuildContext context) {
    final icon = s * 0.062;

    return Container(
      padding: EdgeInsets.symmetric(horizontal: s * 0.036, vertical: s * 0.032),
      decoration: BoxDecoration(
        color: phone.pushFill,
        borderRadius: BorderRadius.circular(s * 0.052),
        border: Border.all(color: phone.pushBorder),
        boxShadow: [
          BoxShadow(
            color: phone.pushShadow,
            blurRadius: s * 0.06,
            offset: Offset(0, s * 0.012),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              // iOS shows the launcher artwork, not a tinted silhouette.
              ClipRRect(
                borderRadius: BorderRadius.circular(icon * 0.24),
                child: Image.asset(
                  'assets/icon.png',
                  width: icon,
                  height: icon,
                  fit: BoxFit.cover,
                  errorBuilder: (_, _, _) => _fallbackGlyph(icon, phone),
                ),
              ),
              SizedBox(width: s * 0.024),
              Expanded(
                child: Text(
                  appName,
                  overflow: TextOverflow.ellipsis,
                  style: adminText(
                    size: s * 0.037,
                    weight: FontWeight.w500,
                    color: phone.pushMuted,
                  ),
                ),
              ),
              SizedBox(width: s * 0.02),
              Text(
                arabic ? 'الآن' : 'now',
                style: adminText(
                  size: s * 0.037,
                  color: phone.pushMuted,
                ),
              ),
            ],
          ),
          SizedBox(height: s * 0.028),
          Text(
            title,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: adminText(
              size: s * 0.046,
              weight: FontWeight.w700,
              color: phone.pushTitle,
              height: 1.35,
            ),
          ),
          if (body.isNotEmpty) ...[
            SizedBox(height: s * 0.006),
            Text(
              body,
              maxLines: 3,
              overflow: TextOverflow.ellipsis,
              style: adminText(
                size: s * 0.043,
                weight: FontWeight.w400,
                color: phone.pushInk,
                height: 1.45,
              ),
            ),
          ],
        ],
      ),
    );
  }
}

/// ---------------------------------------------------------------------------
/// The push, Android flavour
/// ---------------------------------------------------------------------------
/// AOSP puts the small icon in its own leading column and hangs the header, the
/// title and the text off it, so the copy is indented past the glyph — the one
/// structural difference from iOS that a side-by-side comparison has to show.
class _AndroidPush extends StatelessWidget {
  final double width;
  final _PhoneSurface phone;
  final bool arabic;
  final String appName;
  final String title;
  final String body;

  const _AndroidPush({
    required this.width,
    required this.phone,
    required this.arabic,
    required this.appName,
    required this.title,
    required this.body,
  });

  double get s => width;

  @override
  Widget build(BuildContext context) {
    final icon = s * 0.052;

    return Container(
      padding: EdgeInsets.symmetric(horizontal: s * 0.038, vertical: s * 0.034),
      decoration: BoxDecoration(
        color: phone.pushFillAndroid,
        borderRadius: BorderRadius.circular(s * 0.062),
        boxShadow: [
          BoxShadow(
            color: phone.pushShadow,
            blurRadius: s * 0.05,
            offset: Offset(0, s * 0.010),
          ),
        ],
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Android paints the small icon as a flat silhouette, not the
          // coloured launcher artwork.
          Padding(
            padding: EdgeInsets.only(top: s * 0.004),
            child: Image.asset(
              'assets/icons/brand_icon.png',
              width: icon,
              height: icon,
              color: phone.pushInk,
              colorBlendMode: BlendMode.srcIn,
              errorBuilder: (_, _, _) => _fallbackGlyph(icon, phone),
            ),
          ),
          SizedBox(width: s * 0.034),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        appName,
                        overflow: TextOverflow.ellipsis,
                        style: adminText(
                          size: s * 0.036,
                          weight: FontWeight.w500,
                          color: phone.pushInk,
                        ),
                      ),
                    ),
                    SizedBox(width: s * 0.016),
                    // `showWhen: true` with no explicit timestamp, so the shade
                    // prints the relative marker next to the app name.
                    Text(
                      arabic ? 'الآن' : 'now',
                      style: adminText(
                        size: s * 0.036,
                        color: phone.pushMuted,
                      ),
                    ),
                  ],
                ),
                SizedBox(height: s * 0.016),
                Text(
                  title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: adminText(
                    size: s * 0.044,
                    weight: FontWeight.w600,
                    color: phone.pushTitle,
                    height: 1.35,
                  ),
                ),
                // The channel has no big-text style, so a long body stays
                // collapsed to one line until the user pulls the shade open.
                if (body.isNotEmpty) ...[
                  SizedBox(height: s * 0.004),
                  Text(
                    body,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: adminText(
                      size: s * 0.041,
                      weight: FontWeight.w400,
                      color: phone.pushInk,
                      height: 1.45,
                    ),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}

Widget _fallbackGlyph(double size, _PhoneSurface phone) => Icon(
  AdminIcons.notifications,
  size: size,
  color: phone.pushInk,
);

/// ---------------------------------------------------------------------------
/// Status bar furniture
/// ---------------------------------------------------------------------------
class _StatusBarGlyphs extends StatelessWidget {
  final _PhoneSurface phone;
  final double width;
  final bool iOs;

  const _StatusBarGlyphs({
    required this.phone,
    required this.width,
    required this.iOs,
  });

  @override
  Widget build(BuildContext context) {
    final h = width * (iOs ? 0.030 : 0.026);
    return Row(
      textDirection: TextDirection.ltr,
      children: [
        _CellularBars(height: h, color: phone.statusText, flat: !iOs),
        SizedBox(width: width * 0.020),
        _WifiGlyph(size: h * 1.28, color: phone.statusText),
        SizedBox(width: width * 0.020),
        _BatteryGlyph(
          height: h,
          color: phone.statusText,
          level: iOs ? 0.82 : 0.72,
        ),
      ],
    );
  }
}

class _CellularBars extends StatelessWidget {
  final double height;
  final Color color;
  final bool flat;

  const _CellularBars({
    required this.height,
    required this.color,
    required this.flat,
  });

  @override
  Widget build(BuildContext context) {
    final bar = height * 0.22;
    return Row(
      textDirection: TextDirection.ltr,
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        for (final step in const [0.38, 0.58, 0.78, 1.0])
          Padding(
            padding: EdgeInsets.only(right: bar * 0.6),
            child: Container(
              width: bar,
              height: height * (flat ? 1.0 : step),
              decoration: BoxDecoration(
                color: flat && step < 1.0 ? color.withValues(alpha: 0.45) : color,
                borderRadius: BorderRadius.circular(bar * 0.4),
              ),
            ),
          ),
      ],
    );
  }
}

class _WifiGlyph extends StatelessWidget {
  final double size;
  final Color color;

  const _WifiGlyph({required this.size, required this.color});

  @override
  Widget build(BuildContext context) => SizedBox(
    width: size,
    height: size * 0.78,
    child: CustomPaint(painter: _WifiPainter(color)),
  );
}

class _WifiPainter extends CustomPainter {
  final Color color;

  _WifiPainter(this.color);

  @override
  void paint(Canvas canvas, Size size) {
    final stroke = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = size.width * 0.13
      ..strokeCap = StrokeCap.round;
    final origin = Offset(size.width / 2, size.height * 1.06);
    for (final fraction in const [1.0, 0.62, 0.26]) {
      final radius = size.width * 0.5 * fraction;
      canvas.drawArc(
        Rect.fromCircle(center: origin, radius: radius),
        math.pi * 1.18,
        math.pi * 0.64,
        false,
        stroke,
      );
    }
    canvas.drawCircle(
      Offset(origin.dx, size.height * 0.94),
      size.width * 0.085,
      Paint()..color = color,
    );
  }

  @override
  bool shouldRepaint(_WifiPainter old) => old.color != color;
}

class _BatteryGlyph extends StatelessWidget {
  final double height;
  final Color color;
  final double level;

  const _BatteryGlyph({
    required this.height,
    required this.color,
    required this.level,
  });

  @override
  Widget build(BuildContext context) {
    final width = height * 2.05;
    final shell = math.max(1.0, height * 0.09);
    return Row(
      textDirection: TextDirection.ltr,
      children: [
        Container(
          width: width,
          height: height,
          padding: EdgeInsets.all(shell),
          decoration: BoxDecoration(
            border: Border.all(color: color.withValues(alpha: 0.45), width: shell),
            borderRadius: BorderRadius.circular(height * 0.32),
          ),
          child: LayoutBuilder(
            builder: (context, constraints) => Row(
              children: [
                Container(
                  width: constraints.maxWidth * level,
                  decoration: BoxDecoration(
                    color: color,
                    borderRadius: BorderRadius.circular(height * 0.16),
                  ),
                ),
              ],
            ),
          ),
        ),
        SizedBox(width: shell * 0.6),
        Container(
          width: shell * 1.1,
          height: height * 0.36,
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.45),
            borderRadius: BorderRadiusDirectional.horizontal(
              end: Radius.circular(shell),
            ),
          ),
        ),
      ],
    );
  }
}

/// ---------------------------------------------------------------------------
/// Segmented controls above the phone
/// ---------------------------------------------------------------------------
class _Segment {
  final String label;
  final bool latin;

  const _Segment(this.label, {this.latin = false});
}

class _SegmentedControl extends StatelessWidget {
  final List<_Segment> items;
  final int index;
  final ValueChanged<int> onPick;

  const _SegmentedControl({
    required this.items,
    required this.index,
    required this.onPick,
  });

  @override
  Widget build(BuildContext context) {
    final p = AdminPalette.of(context);
    return Center(
      child: Container(
        padding: const EdgeInsets.all(4),
        decoration: BoxDecoration(
          color: p.surfaceSunken,
          borderRadius: BorderRadius.circular(AdminRadii.md),
          border: Border.all(color: p.borderStrong),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            for (var i = 0; i < items.length; i++) _segment(p, items[i], i),
          ],
        ),
      ),
    );
  }

  Widget _segment(AdminPalette p, _Segment item, int i) {
    final active = index == i;
    return GestureDetector(
      onTap: () => onPick(i),
      child: Container(
        width: 96,
        padding: const EdgeInsets.symmetric(vertical: 7),
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: active ? p.surface : Colors.transparent,
          borderRadius: BorderRadius.circular(AdminRadii.sm - 2),
        ),
        child: Text(
          item.label,
          style: item.latin
              ? adminLatinText(
                  size: 11.5,
                  weight: active ? FontWeight.w600 : FontWeight.w500,
                  color: active ? p.ink : p.inkMuted,
                )
              : adminText(
                  size: 11.5,
                  weight: active ? FontWeight.w600 : FontWeight.w500,
                  color: active ? p.ink : p.inkMuted,
                ),
        ),
      ),
    );
  }
}

/// ---------------------------------------------------------------------------
/// Device surfaces
/// ---------------------------------------------------------------------------
/// Values lifted from the two mockups' phone frames. They are device chrome,
/// not dashboard chrome, so they track the palette's brightness rather than its
/// tokens — the photograph supplies the metal, these supply the wallpaper the
/// notification sits on.
class _PhoneSurface {
  final Gradient screen;
  final Color statusText;
  final Color dateText;
  final Color clockText;
  final Color homeLine;
  final Color pushFill;
  final Color pushFillAndroid;
  final Color pushBorder;
  final Color pushShadow;
  final Color pushTitle;
  final Color pushInk;
  final Color pushMuted;

  const _PhoneSurface({
    required this.screen,
    required this.statusText,
    required this.dateText,
    required this.clockText,
    required this.homeLine,
    required this.pushFill,
    required this.pushFillAndroid,
    required this.pushBorder,
    required this.pushShadow,
    required this.pushTitle,
    required this.pushInk,
    required this.pushMuted,
  });

  static const _PhoneSurface light = _PhoneSurface(
    screen: LinearGradient(
      begin: Alignment.topRight,
      end: Alignment.bottomLeft,
      colors: [Color(0xFFEFF4DE), Color(0xFFD5E2C4)],
    ),
    statusText: Color(0xFF859374),
    dateText: Color(0xFF879B6E),
    clockText: Color(0xFF718957),
    homeLine: Color(0xFF9AAA89),
    pushFill: Color(0xA8FFFFFF),
    pushFillAndroid: Color(0xE8FFFFFF),
    pushBorder: Color(0x80FFFFFF),
    pushShadow: Color(0x1E637350),
    pushTitle: Color(0xFF41573A),
    pushInk: Color(0xFF69884E),
    pushMuted: Color(0xFF8CA177),
  );

  static const _PhoneSurface dark = _PhoneSurface(
    screen: LinearGradient(
      begin: Alignment.topRight,
      end: Alignment.bottomLeft,
      colors: [Color(0xFF4B5C3C), Color(0xFF1B3017)],
      stops: [0, 0.7],
    ),
    statusText: Color(0xFFA2AA8E),
    dateText: Color(0xFF9DB08A),
    clockText: Color(0xFFE7EDDC),
    homeLine: Color(0xFF6E7F5C),
    pushFill: Color(0x19EFF6E5),
    pushFillAndroid: Color(0x2A1A2A14),
    pushBorder: Color(0x28B1C694),
    pushShadow: Color(0x40050D04),
    pushTitle: Color(0xFFE8EFDA),
    pushInk: Color(0xFFC3CFAF),
    pushMuted: Color(0xFF93A47F),
  );

  static _PhoneSurface of(AdminPalette p) => p.isDark ? dark : light;
}
