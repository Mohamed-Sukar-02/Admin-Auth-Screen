import 'package:flutter/material.dart';

import '../theme/admin_palette.dart';
import 'admin_dialog.dart';

/// One section of an underline page-tab bar. [count] is the live number the tab
/// reports; pass null for a tab that has nothing to count.
typedef AdminPageTab = ({IconData icon, String label, int? count});

/// ===========================================================================
/// Shared page chrome
///
/// The notifications screen set this composition — an underline tab bar over
/// cards that open with [AdminCardHeading] and close with a tinted action band.
/// Any admin page after the same look builds it out of these pieces instead of
/// redrawing them, so the two pages cannot drift apart.
/// ===========================================================================
class AdminPageTabs extends StatelessWidget {
  final List<AdminPageTab> tabs;
  final int selected;
  final ValueChanged<int> onSelect;

  const AdminPageTabs({
    super.key,
    required this.tabs,
    required this.selected,
    required this.onSelect,
  });

  @override
  Widget build(BuildContext context) {
    final p = AdminPalette.of(context);
    return Container(
      decoration: BoxDecoration(
        border: Border(bottom: BorderSide(color: p.border)),
      ),
      child: Row(
        children: [
          for (var i = 0; i < tabs.length; i++) ...[
            if (i > 0) const SizedBox(width: 25),
            _tab(p, i, tabs[i]),
          ],
        ],
      ),
    );
  }

  Widget _tab(AdminPalette p, int index, AdminPageTab tab) {
    final active = selected == index;
    final color = active ? p.onClaySoft : p.inkMuted;
    return InkWell(
      onTap: () => onSelect(index),
      child: IntrinsicWidth(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: const EdgeInsets.only(top: 6, bottom: 11),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(tab.icon, size: 15, color: color),
                  const SizedBox(width: 8),
                  Text(
                    tab.label,
                    style: adminText(
                      size: 13,
                      weight: active ? FontWeight.w600 : FontWeight.w500,
                      color: color,
                    ),
                  ),
                  if (tab.count != null) ...[
                    const SizedBox(width: 8),
                    _TabCount(count: tab.count!),
                  ],
                ],
              ),
            ),
            Container(
              height: 2,
              decoration: BoxDecoration(
                color: active ? p.clay : Colors.transparent,
                borderRadius: BorderRadius.circular(3),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _TabCount extends StatelessWidget {
  final int count;

  const _TabCount({required this.count});

  @override
  Widget build(BuildContext context) {
    final p = AdminPalette.of(context);
    return Container(
      constraints: const BoxConstraints(minWidth: 18),
      padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
      decoration: BoxDecoration(
        color: p.surfaceAlt,
        borderRadius: BorderRadius.circular(4),
        border: Border.all(color: p.border),
      ),
      child: Text(
        count.toString().padLeft(2, '0'),
        textAlign: TextAlign.center,
        style: adminLatinText(size: 10.5, color: p.inkMuted),
      ),
    );
  }
}

/// The tinted band a card closes with: the primary action on one side, the
/// quieter ones on the other.
class AdminCardActionBar extends StatelessWidget {
  final List<Widget> children;

  const AdminCardActionBar({super.key, required this.children});

  @override
  Widget build(BuildContext context) {
    final p = AdminPalette.of(context);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 13),
      decoration: BoxDecoration(
        color: p.surfaceAlt,
        border: Border(top: BorderSide(color: p.border)),
      ),
      child: Row(children: children),
    );
  }
}

/// A state of the card's subject printed as a chip: small, tinted, bordered.
class AdminStatusChip extends StatelessWidget {
  final String label;
  final Color bg;
  final Color border;
  final Color fg;
  final IconData? icon;

  const AdminStatusChip({
    super.key,
    required this.label,
    required this.bg,
    required this.border,
    required this.fg,
    this.icon,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(5),
        border: Border.all(color: border),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icon != null) ...[
            Icon(icon, size: 12, color: fg),
            const SizedBox(width: 5),
          ],
          Text(
            label,
            style: adminText(size: 11, weight: FontWeight.w600, color: fg),
          ),
        ],
      ),
    );
  }
}

/// Neutral placeholder for a value the card cannot show yet: a list that is
/// loading, a stream that failed, a choice the admin has not finished making.
class AdminHintPanel extends StatelessWidget {
  final IconData icon;
  final String text;
  final bool isError;

  const AdminHintPanel({
    super.key,
    required this.icon,
    required this.text,
    this.isError = false,
  });

  @override
  Widget build(BuildContext context) {
    final p = AdminPalette.of(context);
    final fg = isError ? p.chiliInk : p.inkMuted;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
      decoration: BoxDecoration(
        color: isError ? p.chiliSoft : p.surfaceAlt,
        borderRadius: BorderRadius.circular(AdminRadii.sm),
        border: Border.all(
          color: isError ? p.chiliSolid.withValues(alpha: 0.35) : p.border,
        ),
      ),
      child: Row(
        children: [
          Icon(icon, size: 17, color: fg),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              text,
              style: adminText(size: 12.5, color: fg, height: 1.6),
            ),
          ),
        ],
      ),
    );
  }
}
