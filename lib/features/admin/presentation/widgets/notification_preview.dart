import 'package:flutter/material.dart';

import '../theme/admin_palette.dart';
import 'admin_dialog.dart';

/// ===========================================================================
/// Notification preview — a phone, and the real Android shade row
/// ===========================================================================
/// The mockups preview a broadcast by drawing the device it lands on. The phone
/// is theirs; the notification inside it is the consumer app's. `app_v2` ships
/// no FCM: an admin broadcast becomes a local Android notification built by
/// `NotificationService.showAdminNotification` with
/// `AndroidNotificationDetails('admin_announcements_channel', …,
/// importance: max, priority: high, showWhen: true)` and nothing else — no
/// large icon, no big-text style, no colour, no per-type glyph. So the row here
/// is a flat single-colour app glyph, the OS app name, "· now", the title, and
/// one collapsed body line. Anything prettier would misrepresent what the user
/// actually gets.
///
/// Each library paints its own phone — the light one a pale sage screen, the
/// dark one a deep olive lock screen — so the device carries its own surface
/// values instead of reading the dashboard tokens.
class NotificationPreview extends StatelessWidget {
  /// The mockups draw the phone at 280 logical pixels, which reads like a
  /// thumbnail inside a review dialog. Everything below is authored at that
  /// size and multiplied by [scale], so the device can grow without anyone
  /// re-deriving twelve numbers.
  static const double scale = 1.4;
  static const double _nativeWidth = 280;
  static const double _nativeFrame = 5;

  /// Full outer width of the drawn phone — what a parent must reserve.
  static double get width => (_nativeWidth + _nativeFrame * 2) * scale;

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
  Widget build(BuildContext context) {
    final p = AdminPalette.of(context);
    final phone = _PhoneSurface.of(p);
    double s(double v) => v * scale;

    final title = arabic ? titleAr : titleEn;
    final body = arabic ? messageAr : messageEn;

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        _LanguageToggle(arabic: arabic, onPick: onPickArabic),
        SizedBox(height: s(19)),
        Container(
          width: s(_nativeWidth),
          constraints: BoxConstraints(minHeight: s(307)),
          padding: EdgeInsets.fromLTRB(s(13), s(13), s(13), s(45)),
          decoration: BoxDecoration(
            gradient: phone.screen,
            borderRadius: BorderRadius.circular(s(32)),
            border: Border.all(color: phone.frame, width: s(_nativeFrame)),
            boxShadow: [BoxShadow(color: phone.shadow, blurRadius: s(12))],
          ),
          clipBehavior: Clip.antiAlias,
          child: Stack(
            children: [
              Row(
                textDirection: TextDirection.ltr,
                children: [
                  Text(
                    '9:41',
                    style: adminLatinText(
                      size: s(8),
                      weight: FontWeight.w600,
                      color: phone.statusText,
                    ),
                  ),
                  const Spacer(),
                  Text(
                    '••• ▰',
                    style: adminLatinText(
                      size: s(8),
                      weight: FontWeight.w600,
                      color: phone.statusText,
                    ),
                  ),
                ],
              ),
              Positioned(
                top: s(-2),
                left: 0,
                right: 0,
                child: Center(
                  child: Container(
                    width: s(71),
                    height: s(18),
                    decoration: BoxDecoration(
                      color: phone.island,
                      borderRadius: BorderRadius.circular(s(15)),
                    ),
                  ),
                ),
              ),
              Positioned(
                top: s(32),
                left: 0,
                right: 0,
                child: Text(
                  arabic ? 'النهاردة يوم حلو' : 'Today is a good day',
                  textAlign: TextAlign.center,
                  style: adminText(size: s(9.5), color: phone.dateText),
                ),
              ),
              Positioned(
                top: s(46),
                left: 0,
                right: 0,
                child: Text(
                  '9:41',
                  textAlign: TextAlign.center,
                  textDirection: TextDirection.ltr,
                  style: adminLatinText(
                    size: s(45),
                    color: phone.clockText,
                    height: 1.3,
                    letterSpacing: -2,
                  ),
                ),
              ),
              Positioned(
                top: s(128),
                left: 0,
                right: 0,
                child: _ShadeRow(
                  phone: phone,
                  scale: scale,
                  // The OS label, not the in-app name: Android reads it from
                  // android:label, which is transliterated outside Arabic
                  // system locales.
                  appName: arabic ? 'أكلة النهاردة' : 'Aklit Elnaharda',
                  // An empty title does not fall back to the other language —
                  // the app puts its own default in that slot.
                  title: title.isEmpty
                      ? (arabic ? 'أكلة النهاردة 🍽️' : 'Daily Meal 🍽️')
                      : _cap(title, _titleCap),
                  body: _cap(body, _bodyCap),
                ),
              ),
              Positioned(
                bottom: s(8),
                left: 0,
                right: 0,
                child: Center(
                  child: Container(
                    width: s(80),
                    height: 3,
                    decoration: BoxDecoration(
                      color: phone.homeLine,
                      borderRadius: BorderRadius.circular(3),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  static String _cap(String value, int limit) =>
      value.length <= limit ? value : '${value.substring(0, limit - 3)}...';
}

/// The collapsed shade row: tinted app glyph, app name, "· now", then the title
/// and a single body line — what Android paints for this channel.
class _ShadeRow extends StatelessWidget {
  final _PhoneSurface phone;
  final double scale;
  final String appName;
  final String title;
  final String body;

  const _ShadeRow({
    required this.phone,
    required this.scale,
    required this.appName,
    required this.title,
    required this.body,
  });

  @override
  Widget build(BuildContext context) {
    double s(double v) => v * scale;

    return Container(
      padding: EdgeInsets.all(s(12)),
      decoration: BoxDecoration(
        color: phone.pushFill,
        borderRadius: BorderRadius.circular(s(13)),
        border: Border.all(color: phone.pushBorder),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              // Android paints the small icon as a flat silhouette, not the
              // coloured launcher artwork.
              Image.asset(
                'assets/icons/brand_icon.png',
                width: s(17),
                height: s(17),
                color: phone.pushInk,
                colorBlendMode: BlendMode.srcIn,
                errorBuilder: (_, _, _) => Icon(
                  AdminIcons.notifications,
                  size: s(17),
                  color: phone.pushInk,
                ),
              ),
              SizedBox(width: s(6)),
              Expanded(
                child: Text(
                  appName,
                  overflow: TextOverflow.ellipsis,
                  style: adminText(
                    size: s(10),
                    weight: FontWeight.w500,
                    color: phone.pushInk,
                  ),
                ),
              ),
              Text(
                // `showWhen: true` with no explicit timestamp, so the shade
                // prints the relative marker next to the app name.
                '· الآن',
                style: adminText(size: s(10), color: phone.pushMuted),
              ),
            ],
          ),
          SizedBox(height: s(7)),
          Text(
            title,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: adminText(
              size: s(12.5),
              weight: FontWeight.w600,
              color: phone.pushTitle,
              height: 1.4,
            ),
          ),
          // The channel has no big-text style, so a long body stays collapsed
          // to one line until the user pulls the shade open. An empty body
          // stays empty — the app never borrows the other language.
          if (body.isNotEmpty) ...[
            SizedBox(height: s(2)),
            Text(
              body,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: adminText(size: s(11), color: phone.pushInk, height: 1.5),
            ),
          ],
        ],
      ),
    );
  }
}

/// Segmented العربية / English control centred above the phone.
class _LanguageToggle extends StatelessWidget {
  final bool arabic;
  final ValueChanged<bool> onPick;

  const _LanguageToggle({required this.arabic, required this.onPick});

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
            for (final (label, isArabic) in const [
              ('العربية', true),
              ('English', false),
            ])
              _segment(p, label, isArabic),
          ],
        ),
      ),
    );
  }

  Widget _segment(AdminPalette p, String label, bool isArabic) {
    final active = arabic == isArabic;
    return GestureDetector(
      onTap: () => onPick(isArabic),
      child: Container(
        width: 96,
        padding: const EdgeInsets.symmetric(vertical: 7),
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: active ? p.surface : Colors.transparent,
          borderRadius: BorderRadius.circular(AdminRadii.sm - 2),
        ),
        child: Text(
          label,
          style: isArabic
              ? adminText(
                  size: 11.5,
                  weight: active ? FontWeight.w600 : FontWeight.w500,
                  color: active ? p.ink : p.inkMuted,
                )
              : adminLatinText(
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
/// tokens.
class _PhoneSurface {
  final Gradient screen;
  final Color frame;
  final Color shadow;
  final Color statusText;
  final Color island;
  final Color dateText;
  final Color clockText;
  final Color homeLine;
  final Color pushFill;
  final Color pushBorder;
  final Color pushTitle;
  final Color pushInk;
  final Color pushMuted;

  const _PhoneSurface({
    required this.screen,
    required this.frame,
    required this.shadow,
    required this.statusText,
    required this.island,
    required this.dateText,
    required this.clockText,
    required this.homeLine,
    required this.pushFill,
    required this.pushBorder,
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
    frame: Color(0xFFD8DFCC),
    shadow: Color(0x08637350),
    statusText: Color(0xFF859374),
    island: Color(0xFF84956F),
    dateText: Color(0xFF879B6E),
    clockText: Color(0xFF718957),
    homeLine: Color(0xFF9AAA89),
    pushFill: Color(0xA8FFFFFF),
    pushBorder: Color(0x80FFFFFF),
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
    frame: Color(0xFF101B0C),
    shadow: Color(0x800B1C09),
    statusText: Color(0xFFA2AA8E),
    island: Color(0xFF101B0C),
    dateText: Color(0xFF9DB08A),
    clockText: Color(0xFFE7EDDC),
    homeLine: Color(0xFF6E7F5C),
    pushFill: Color(0x19EFF6E5),
    pushBorder: Color(0x28B1C694),
    pushTitle: Color(0xFFE8EFDA),
    pushInk: Color(0xFFC3CFAF),
    pushMuted: Color(0xFF93A47F),
  );

  static _PhoneSurface of(AdminPalette p) => p.isDark ? dark : light;
}
