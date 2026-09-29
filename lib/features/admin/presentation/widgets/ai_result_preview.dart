import 'package:flutter/material.dart';

import '../../data/models/ai_notification_result.dart';
import '../theme/admin_palette.dart';
import 'admin_dialog.dart';

/// ===========================================================================
/// AI result preview
///
/// Shows the four generated fields plus the broadcast kind, with the single
/// action that matters: pushing the copy into the compose form.
/// ===========================================================================
class AiResultPreview extends StatelessWidget {
  final AiNotificationResult result;
  final VoidCallback onApply;

  const AiResultPreview({
    super.key,
    required this.result,
    required this.onApply,
  });

  @override
  Widget build(BuildContext context) {
    final p = AdminPalette.of(context);
    final type = _typeStyle(p, result.type);

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: p.surface,
        borderRadius: BorderRadius.circular(AdminRadii.lg),
        border: Border.all(color: p.oliveSolid.withValues(alpha: 0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              _TypePill(label: type.label, bg: type.bg, fg: type.fg),
              const Spacer(),
              Text(
                'نتيجة التوليد',
                style: adminText(size: 11, color: p.inkFaint),
              ),
            ],
          ),
          const SizedBox(height: 12),
          _LabeledField(label: 'العنوان بالعربي', value: result.titleAr),
          const SizedBox(height: 8),
          _LabeledField(
            label: 'العنوان بالإنجليزي',
            value: result.titleEn,
            ltr: true,
          ),
          const SizedBox(height: 8),
          _LabeledField(label: 'الرسالة بالعربي', value: result.messageAr),
          const SizedBox(height: 8),
          _LabeledField(
            label: 'الرسالة بالإنجليزي',
            value: result.messageEn,
            ltr: true,
          ),
          const SizedBox(height: 16),
          FilledButton.icon(
            onPressed: onApply,
            icon: const Icon(Icons.auto_fix_high_rounded, size: 18),
            label: Text(
              'تطبيق في النموذج',
              style: adminText(size: 13, weight: FontWeight.bold),
            ),
            style: FilledButton.styleFrom(
              backgroundColor: p.claySolid,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(vertical: 14),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(AdminRadii.md),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// ---------------------------------------------------------------------------
/// Labeled field
/// ---------------------------------------------------------------------------
/// One generated field: a quiet caption above the copy, so the admin reads the
/// suggestion exactly the way the form below will hold it.
class _LabeledField extends StatelessWidget {
  final String label;
  final String value;
  final bool ltr;

  const _LabeledField({
    required this.label,
    required this.value,
    this.ltr = false,
  });

  @override
  Widget build(BuildContext context) {
    final p = AdminPalette.of(context);
    final text = value.trim();

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(12, 10, 12, 12),
      decoration: BoxDecoration(
        color: p.surfaceAlt,
        borderRadius: BorderRadius.circular(AdminRadii.sm),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: adminText(
              size: 11,
              weight: FontWeight.w700,
              color: p.inkFaint,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            text.isEmpty ? '—' : text,
            textDirection: ltr ? TextDirection.ltr : TextDirection.rtl,
            style: adminText(
              size: 13.5,
              weight: FontWeight.w500,
              color: text.isEmpty ? p.inkFaint : p.ink,
              height: 1.6,
            ),
          ),
        ],
      ),
    );
  }
}

/// ---------------------------------------------------------------------------
/// Type pill
/// ---------------------------------------------------------------------------
class _TypePill extends StatelessWidget {
  final String label;
  final Color bg;
  final Color fg;

  const _TypePill({required this.label, required this.bg, required this.fg});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(AdminRadii.pill),
      ),
      child: Text(
        label,
        style: adminText(size: 11, weight: FontWeight.w700, color: fg),
      ),
    );
  }
}

/// The model can answer with a kind the form never offers, so anything unknown
/// falls back to the meal tint instead of painting a colourless badge.
({Color bg, Color fg, String label}) _typeStyle(AdminPalette p, String type) {
  switch (type) {
    case 'reminder':
      return (bg: p.nileSoft, fg: p.nileInk, label: 'تذكير');
    case 'update':
      return (bg: p.oliveSoft, fg: p.oliveInk, label: 'تحديث');
    default:
      return (bg: p.honeySoft, fg: p.honeyInk, label: 'وجبة');
  }
}
