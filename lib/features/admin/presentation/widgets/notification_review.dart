import 'package:flutter/material.dart';

import '../theme/admin_palette.dart';
import 'admin_dialog.dart';
import 'notification_preview.dart';

/// What the admin decided inside the review dialog.
enum NotificationReviewResult { send, close }

/// ===========================================================================
/// Pre-send review
/// ===========================================================================
/// The mockups do not let a broadcast go out from the form: the send button
/// opens this review, with the phone on one side and everything the push
/// carries on the other, and the decision happens there. Wide layouts get the
/// two halves side by side; narrow ones stack the phone above the summary so
/// the device stays readable.
class NotificationReview extends StatefulWidget {
  final String titleAr;
  final String messageAr;
  final String titleEn;
  final String messageEn;
  final String typeLabel;

  /// The lifecycle half of the audience, spelled out with its day window.
  final String segmentLabel;

  /// True when the broadcast is narrowed to one stage rather than to everyone.
  final bool segmentRestricted;
  final String route;

  /// False when the dialog is opened just to look, without the send offer.
  final bool allowSend;
  final bool sending;
  final ValueChanged<NotificationReviewResult> onDecision;

  const NotificationReview({
    super.key,
    required this.titleAr,
    required this.messageAr,
    required this.titleEn,
    required this.messageEn,
    required this.typeLabel,
    required this.segmentLabel,
    this.segmentRestricted = false,
    required this.route,
    this.allowSend = true,
    this.sending = false,
    required this.onDecision,
  });

  @override
  State<NotificationReview> createState() => _NotificationReviewState();
}

class _NotificationReviewState extends State<NotificationReview> {
  bool _arabic = true;

  String get _title => _arabic ? widget.titleAr : widget.titleEn;
  String get _message => _arabic ? widget.messageAr : widget.messageEn;

  @override
  Widget build(BuildContext context) {
    final p = AdminPalette.of(context);
    final wide = MediaQuery.sizeOf(context).width >= 760;

    // The phone is a fixed object sized by the preview widget itself, so it
    // claims an exact width instead of fighting the summary for the row.
    final phone = SizedBox(
      width: NotificationPreview.width,
      child: NotificationPreview(
        titleAr: widget.titleAr,
        messageAr: widget.messageAr,
        titleEn: widget.titleEn,
        messageEn: widget.messageEn,
        arabic: _arabic,
        onPickArabic: (arabic) => setState(() => _arabic = arabic),
      ),
    );

    final summary = _Summary(
      arabic: _arabic,
      title: _title,
      message: _message,
      typeLabel: widget.typeLabel,
      segmentLabel: widget.segmentLabel,
      segmentRestricted: widget.segmentRestricted,
      route: widget.route,
    );

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (wide)
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(child: summary),
              const SizedBox(width: 26),
              phone,
            ],
          )
        else ...[
          Center(child: phone),
          const SizedBox(height: 22),
          summary,
        ],
        const SizedBox(height: 24),
        _actions(p),
      ],
    );
  }

  Widget _actions(AdminPalette p) {
    final confirm = widget.allowSend
        ? FilledButton.icon(
            onPressed: widget.sending
                ? null
                : () => widget.onDecision(NotificationReviewResult.send),
            icon: widget.sending
                ? const SizedBox(
                    width: 15,
                    height: 15,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(AdminIcons.send, size: 17),
            label: Text(
              widget.sending ? 'جارٍ الإرسال…' : 'تأكيد الإرسال',
              style: adminText(size: 13.5, weight: FontWeight.w600),
            ),
            style: FilledButton.styleFrom(
              backgroundColor: p.claySolid,
              foregroundColor: p.onClay,
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(AdminRadii.sm),
              ),
            ),
          )
        : const SizedBox.shrink();

    final back = OutlinedButton.icon(
      onPressed: widget.sending
          ? null
          : () => widget.onDecision(NotificationReviewResult.close),
      icon: const Icon(AdminIcons.edit, size: 16),
      label: Text(
        widget.allowSend ? 'لسه هعدّل حاجة' : 'العودة لتعديل الإشعار',
        style: adminText(size: 13.5, weight: FontWeight.w500),
      ),
      style: OutlinedButton.styleFrom(
        foregroundColor: p.inkMuted,
        side: BorderSide(color: p.borderStrong),
        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AdminRadii.sm),
        ),
      ),
    );

    if (!widget.allowSend) {
      return Row(children: [Expanded(child: back)]);
    }
    return Row(
      children: [
        Expanded(child: confirm),
        const SizedBox(width: 10),
        Expanded(child: back),
      ],
    );
  }
}

/// The right-hand half: what the push says, and where it goes.
class _Summary extends StatelessWidget {
  final bool arabic;
  final String title;
  final String message;
  final String typeLabel;
  final String segmentLabel;
  final bool segmentRestricted;
  final String route;

  const _Summary({
    required this.arabic,
    required this.title,
    required this.message,
    required this.typeLabel,
    required this.segmentLabel,
    required this.segmentRestricted,
    required this.route,
  });

  @override
  Widget build(BuildContext context) {
    final p = AdminPalette.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _FactRow(icon: AdminIcons.tags, label: 'نوع الإشعار', value: typeLabel),
        const SizedBox(height: 12),
        _FactRow(
          icon: AdminIcons.users,
          label: 'الجمهور المستهدف',
          value: segmentLabel,
        ),
        const SizedBox(height: 12),
        _FactRow(
          icon: AdminIcons.route,
          label: 'المسار',
          value: route.isEmpty ? 'الصفحة الرئيسية' : route,
          latin: true,
        ),
        const SizedBox(height: 18),
        Container(height: 1, color: p.border),
        const SizedBox(height: 18),
        Text(
          arabic ? 'بالمصري' : 'In English',
          style: adminText(
            size: 11,
            weight: FontWeight.w600,
            color: p.inkFaint,
          ),
        ),
        const SizedBox(height: 6),
        Text(
          title.isEmpty ? 'عنوان الإشعار يظهر هنا' : title,
          textDirection: arabic ? TextDirection.rtl : TextDirection.ltr,
          style: adminText(
            size: 15,
            weight: FontWeight.w600,
            color: p.ink,
            height: 1.5,
          ),
        ),
        const SizedBox(height: 5),
        Text(
          message.isEmpty ? 'رسالتك هتظهر هنا.' : message,
          textDirection: arabic ? TextDirection.rtl : TextDirection.ltr,
          style: adminText(size: 12.5, color: p.inkMuted, height: 1.8),
        ),
        const SizedBox(height: 16),
        Text(
          arabic
              ? 'راجع الصياغة قبل ما تبعتها — دي آخر خطوة.'
              : 'Review the English copy before it goes out.',
          style: adminText(size: 11, color: p.inkFaint, height: 1.7),
        ),
        // The app has no push channel: an announcement is pulled the next time
        // the user opens it, and the audience decides whether it is announced
        // then. Saying so here stops the selector from being read as a send.
        const SizedBox(height: 4),
        Text(
          'الإشعار يوصل أول ما المستخدم يفتح التطبيق — مفيش دفع فوري.',
          style: adminText(size: 11, color: p.inkFaint, height: 1.7),
        ),
        // Stage filtering is newer than the builds already installed. An old
        // build cannot resolve the segment, so it shows the broadcast to
        // everyone — the admin has to hear that before committing, not after.
        if (segmentRestricted) ...[
          const SizedBox(height: 4),
          Text(
            'نسخ التطبيق الأقدم من هذه الميزة ما بتعرفش تفرز بالمرحلة، '
            'فبتعرض الإشعار لكل المستخدمين مهما كانت مرحلتهم.',
            style: adminText(size: 11, color: p.inkFaint, height: 1.7),
          ),
        ],
      ],
    );
  }
}

class _FactRow extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  final bool latin;

  const _FactRow({
    required this.icon,
    required this.label,
    required this.value,
    this.latin = false,
  });

  @override
  Widget build(BuildContext context) {
    final p = AdminPalette.of(context);
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: 15, color: p.inkFaint),
        const SizedBox(width: 7),
        Expanded(
          child: Text(
            '$label:',
            overflow: TextOverflow.ellipsis,
            style: adminText(
              size: 12,
              weight: FontWeight.w500,
              color: p.inkMuted,
            ),
          ),
        ),
        const SizedBox(width: 2),
        Expanded(
          flex: 2,
          child: Text(
            value,
            overflow: TextOverflow.ellipsis,
            textDirection: latin ? TextDirection.ltr : TextDirection.rtl,
            style: latin
                ? adminLatinText(
                    size: 12,
                    weight: FontWeight.w500,
                    color: p.ink,
                  )
                : adminText(size: 12, weight: FontWeight.w500, color: p.ink),
          ),
        ),
      ],
    );
  }
}
