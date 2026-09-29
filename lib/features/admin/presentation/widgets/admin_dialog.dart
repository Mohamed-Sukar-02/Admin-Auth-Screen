import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../theme/admin_palette.dart';

/// ============================================================================
/// The admin dialog system.
///
/// One shell ([AdminDialogShell]) and one motion curve ([showAdminDialog]) for
/// every modal in the dashboard, plus the surface's icon system
/// ([AdminIcons]) and form-field style ([adminFieldDeco]).
///
/// Design rules baked in here:
///   • Plain [Dialog] instead of [AlertDialog] — no intrinsic measurement, so
///     nested lists / grids inside a dialog can never crash the layout.
///   • A slim icon "chip" + title + subtitle header, with a single circular
///     close affordance (no duplicate close buttons in the footer).
///   • Tone-driven colour: each dialog declares intent (brand / danger / warn
///     / success / info / neutral) and every accent derives from it.
///   • Rectangular-soft buttons (radius 12) — never stadium capsules.
///   • Entrance motion: fade + 0.94→1 scale, 220ms easeOutCubic.
/// ============================================================================

/// Shared typography for the admin surface (Cairo, RTL-friendly).
TextStyle adminText({
  double size = 14,
  FontWeight weight = FontWeight.w500,
  Color? color,
  double? height,
}) {
  return GoogleFonts.cairo(
    fontSize: size,
    fontWeight: weight,
    color: color,
    height: height,
  );
}

/// ---------------------------------------------------------------------------
/// Icon system
/// ---------------------------------------------------------------------------
/// Exactly one glyph per concept, all from the filled `_rounded` family so
/// stroke weight, corners and optical size stay consistent everywhere.
abstract final class AdminIcons {
  // Chrome & navigation
  static const IconData dashboard = Icons.space_dashboard_rounded;
  static const IconData suggestions = Icons.pending_actions_rounded;
  static const IconData settings = Icons.tune_rounded;
  static const IconData close = Icons.close_rounded;
  static const IconData expand = Icons.expand_more_rounded;
  static const IconData search = Icons.search_rounded;
  static const IconData add = Icons.add_rounded;
  static const IconData edit = Icons.edit_rounded;
  static const IconData delete = Icons.delete_rounded;
  static const IconData refresh = Icons.refresh_rounded;
  static const IconData logout = Icons.logout_rounded;
  static const IconData palette = Icons.palette_rounded;
  static const IconData lock = Icons.lock_rounded;
  static const IconData verified = Icons.verified_user_rounded;

  // Feedback tones
  static const IconData warning = Icons.error_rounded;
  static const IconData danger = Icons.dangerous_rounded;
  static const IconData success = Icons.check_circle_rounded;
  static const IconData info = Icons.info_rounded;
  static const IconData empty = Icons.inbox_rounded;

  // Meals
  static const IconData meal = Icons.ramen_dining_rounded;
  static const IconData category = Icons.local_dining_rounded;
  static const IconData protein = Icons.egg_alt_rounded;
  static const IconData carbs = Icons.rice_bowl_rounded;
  static const IconData time = Icons.schedule_rounded;
  static const IconData friday = Icons.celebration_rounded;
  static const IconData money = Icons.savings_rounded;
  static const IconData starter = Icons.stars_rounded;
  static const IconData notes = Icons.sticky_note_2_rounded;
  static const IconData source = Icons.person_rounded;
  static const IconData basicInfo = Icons.badge_rounded;
  static const IconData tags = Icons.sell_rounded;
  static const IconData photo = Icons.photo_camera_rounded;
  static const IconData image = Icons.image_rounded;
  static const IconData upload = Icons.cloud_upload_rounded;
  static const IconData link = Icons.link_rounded;

  // System & admins
  static const IconData backup = Icons.backup_rounded;
  static const IconData restore = Icons.settings_backup_restore_rounded;
  static const IconData cleanup = Icons.cleaning_services_rounded;
  static const IconData update = Icons.system_update_alt_rounded;
  static const IconData campaign = Icons.campaign_rounded;
  static const IconData password = Icons.key_rounded;
  static const IconData admins = Icons.shield_rounded;
  static const IconData adminAdd = Icons.person_add_rounded;
  static const IconData adminRemove = Icons.person_remove_rounded;
  static const IconData person = Icons.person_rounded;
  static const IconData email = Icons.alternate_email_rounded;
  static const IconData visibility = Icons.visibility_rounded;
  static const IconData visibilityOff = Icons.visibility_off_rounded;
  static const IconData role = Icons.military_tech_rounded;
  static const IconData checkbox = Icons.check_box_rounded;
  static const IconData checkboxOff = Icons.check_box_outline_blank_rounded;
}

/// ---------------------------------------------------------------------------
/// Tones
/// ---------------------------------------------------------------------------
enum AdminDialogTone { brand, danger, warn, success, info, plum, neutral }

class AdminDialogToneColors {
  final Color solid;
  final Color soft;
  final Color ink;

  const AdminDialogToneColors({
    required this.solid,
    required this.soft,
    required this.ink,
  });
}

AdminDialogToneColors adminToneColors(AdminPalette p, AdminDialogTone tone) {
  switch (tone) {
    case AdminDialogTone.brand:
      return AdminDialogToneColors(
          solid: p.claySolid, soft: p.claySoft, ink: p.onClaySoft);
    case AdminDialogTone.danger:
      return AdminDialogToneColors(
          solid: p.chiliSolid, soft: p.chiliSoft, ink: p.chiliInk);
    case AdminDialogTone.warn:
      return AdminDialogToneColors(
          solid: p.honeySolid, soft: p.honeySoft, ink: p.honeyInk);
    case AdminDialogTone.success:
      return AdminDialogToneColors(
          solid: p.oliveSolid, soft: p.oliveSoft, ink: p.oliveInk);
    case AdminDialogTone.info:
      return AdminDialogToneColors(
          solid: p.nileSolid, soft: p.nileSoft, ink: p.nileInk);
    case AdminDialogTone.plum:
      return AdminDialogToneColors(
          solid: p.plumSolid, soft: p.plumSoft, ink: p.plumInk);
    case AdminDialogTone.neutral:
      return AdminDialogToneColors(
          solid: p.borderStrong, soft: p.surfaceSunken, ink: p.inkMuted);
  }
}

/// ---------------------------------------------------------------------------
/// Entry point — fade + scale motion for every admin dialog.
/// ---------------------------------------------------------------------------
Future<T?> showAdminDialog<T>({
  required BuildContext context,
  required WidgetBuilder builder,
  bool barrierDismissible = true,
  String? barrierLabel,
}) {
  final p = AdminPalette.of(context);
  return showGeneralDialog<T>(
    context: context,
    barrierDismissible: barrierDismissible,
    barrierLabel: barrierLabel ??
        MaterialLocalizations.of(context).modalBarrierDismissLabel,
    barrierColor: p.scrim,
    transitionDuration: const Duration(milliseconds: 220),
    pageBuilder: (ctx, _, _) => builder(ctx),
    transitionBuilder: (ctx, animation, _, child) {
      final curved = CurvedAnimation(
        parent: animation,
        curve: Curves.easeOutCubic,
        reverseCurve: Curves.easeInCubic,
      );
      return FadeTransition(
        opacity: curved,
        child: ScaleTransition(
          scale: Tween<double>(begin: 0.94, end: 1).animate(curved),
          child: child,
        ),
      );
    },
  );
}

/// ---------------------------------------------------------------------------
/// Shell
/// ---------------------------------------------------------------------------
class AdminDialogShell extends StatelessWidget {
  final IconData icon;
  final String title;
  final AdminDialogTone tone;
  final String? subtitle;

  /// Optional full-bleed media band rendered above the header.
  final Widget? hero;

  /// Dialog body. Scrolls when it outgrows the viewport.
  final Widget? child;

  /// Footer buttons. Empty list ⇒ no footer.
  final List<Widget> actions;

  final double maxWidth;
  final EdgeInsetsGeometry bodyPadding;
  final bool showClose;

  const AdminDialogShell({
    super.key,
    required this.icon,
    required this.title,
    this.tone = AdminDialogTone.brand,
    this.subtitle,
    this.hero,
    this.child,
    this.actions = const <Widget>[],
    this.maxWidth = 440,
    this.bodyPadding = const EdgeInsetsDirectional.fromSTEB(22, 18, 22, 22),
    this.showClose = true,
  });

  @override
  Widget build(BuildContext context) {
    final p = AdminPalette.of(context);
    final t = adminToneColors(p, tone);
    final maxHeight = MediaQuery.sizeOf(context).height * 0.86;

    return Dialog(
      backgroundColor: Colors.transparent,
      elevation: 0,
      insetPadding: const EdgeInsets.symmetric(horizontal: 18, vertical: 22),
      child: ConstrainedBox(
        constraints: BoxConstraints(maxWidth: maxWidth, maxHeight: maxHeight),
        child: Container(
          clipBehavior: Clip.antiAlias,
          decoration: BoxDecoration(
            color: p.surface,
            borderRadius: BorderRadius.circular(AdminRadii.xl + 2),
            border: Border.all(color: p.border),
            boxShadow: [
              BoxShadow(
                color: p.shadow,
                blurRadius: 42,
                spreadRadius: -10,
                offset: const Offset(0, 18),
              ),
            ],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              ?hero,
              Padding(
                padding: EdgeInsetsDirectional.fromSTEB(
                    22, hero == null ? 22 : 18, 22, 0),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      width: 46,
                      height: 46,
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          begin: AlignmentDirectional.topStart,
                          end: AlignmentDirectional.bottomEnd,
                          colors: [
                            t.soft,
                            Color.alphaBlend(
                                t.solid.withValues(alpha: 0.14), t.soft),
                          ],
                        ),
                        borderRadius: BorderRadius.circular(15),
                        border:
                            Border.all(color: t.solid.withValues(alpha: 0.28)),
                      ),
                      child: Icon(icon, size: 22, color: t.ink),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Padding(
                        padding: const EdgeInsets.only(top: 2),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              title,
                              style: adminText(
                                  size: 16.5,
                                  weight: FontWeight.bold,
                                  color: p.ink,
                                  height: 1.3),
                            ),
                            if (subtitle != null) ...[
                              const SizedBox(height: 3),
                              Text(
                                subtitle!,
                                style: adminText(
                                    size: 12, color: p.inkMuted, height: 1.5),
                              ),
                            ],
                          ],
                        ),
                      ),
                    ),
                    if (showClose) ...[
                      const SizedBox(width: 10),
                      const AdminDialogCloseButton(),
                    ],
                  ],
                ),
              ),
              if (child != null)
                Flexible(
                  child: SingleChildScrollView(
                    padding: bodyPadding,
                    child: child,
                  ),
                ),
              if (actions.isNotEmpty) _footer(p, actions),
            ],
          ),
        ),
      ),
    );
  }

  Widget _footer(AdminPalette p, List<Widget> actions) {
    return Container(
      padding: const EdgeInsetsDirectional.fromSTEB(18, 14, 18, 16),
      decoration: BoxDecoration(
        color: p.surfaceAlt.withValues(alpha: p.isDark ? 0.35 : 0.55),
        border: Border(top: BorderSide(color: p.border)),
      ),
      child: Row(
        children: [
          for (var i = 0; i < actions.length; i++) ...[
            if (i > 0) const SizedBox(width: 10),
            actions[i],
          ],
        ],
      ),
    );
  }
}

/// Single close affordance for every dialog header.
class AdminDialogCloseButton extends StatelessWidget {
  const AdminDialogCloseButton({super.key});

  @override
  Widget build(BuildContext context) {
    final p = AdminPalette.of(context);
    return Tooltip(
      message: 'إغلاق',
      child: Material(
        color: p.surfaceAlt,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AdminRadii.pill),
          side: BorderSide(color: p.border),
        ),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: () => Navigator.of(context).maybePop(),
          child: SizedBox(
            width: 34,
            height: 34,
            child: Icon(AdminIcons.close, size: 18, color: p.inkMuted),
          ),
        ),
      ),
    );
  }
}

/// ---------------------------------------------------------------------------
/// Buttons
/// ---------------------------------------------------------------------------
class AdminDialogButtons {
  AdminDialogButtons._();

  /// Quiet, borderless secondary action.
  static Widget ghost(
    AdminPalette p, {
    required String label,
    VoidCallback? onPressed,
    IconData? icon,
  }) {
    final text =
        Text(label, style: adminText(size: 13.5, weight: FontWeight.bold));
    return TextButton(
      onPressed: onPressed,
      style: TextButton.styleFrom(
        foregroundColor: p.inkMuted,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 15),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AdminRadii.md),
        ),
      ),
      child: icon == null
          ? text
          : Row(
              mainAxisSize: MainAxisSize.min,
              children: [Icon(icon, size: 17), const SizedBox(width: 8), text],
            ),
    );
  }

  /// Solid, tone-coloured primary action. Set [loading] to swap the label for
  /// a spinner and block taps.
  static Widget primary(
    AdminPalette p, {
    required String label,
    required AdminDialogTone tone,
    VoidCallback? onPressed,
    IconData? icon,
    bool loading = false,
  }) {
    final t = adminToneColors(p, tone);
    final style = FilledButton.styleFrom(
      backgroundColor: t.solid,
      foregroundColor: Colors.white,
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 15),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AdminRadii.md),
      ),
    );
    if (loading) {
      return FilledButton(
        style: style,
        onPressed: null,
        child: const SizedBox(
          width: 17,
          height: 17,
          child: CircularProgressIndicator(
              strokeWidth: 2, color: Colors.white),
        ),
      );
    }
    final text = Text(label,
        style: adminText(size: 13.5, weight: FontWeight.bold, color: Colors.white));
    if (icon == null) {
      return FilledButton(style: style, onPressed: onPressed, child: text);
    }
    return FilledButton.icon(
      style: style,
      onPressed: onPressed,
      icon: Icon(icon, size: 17),
      label: text,
    );
  }

  /// Soft, tinted button for secondary-but-positive actions.
  static Widget tonal(
    AdminPalette p, {
    required String label,
    required AdminDialogTone tone,
    VoidCallback? onPressed,
    IconData? icon,
  }) {
    final t = adminToneColors(p, tone);
    final style = FilledButton.styleFrom(
      backgroundColor: t.soft,
      foregroundColor: t.ink,
      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 15),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AdminRadii.md),
      ),
    );
    final text = Text(label, style: adminText(size: 13.5, weight: FontWeight.bold));
    if (icon == null) {
      return FilledButton(style: style, onPressed: onPressed, child: text);
    }
    return FilledButton.icon(
      style: style,
      onPressed: onPressed,
      icon: Icon(icon, size: 17),
      label: text,
    );
  }
}

/// ---------------------------------------------------------------------------
/// Confirmation dialogs
/// ---------------------------------------------------------------------------
/// Standard yes/no dialog. Returns `true` only when the primary action was
/// pressed (barrier dismiss / close / cancel all yield `false`).
Future<bool> showAdminConfirmDialog({
  required BuildContext context,
  required IconData icon,
  required AdminDialogTone tone,
  required String title,
  String? subtitle,
  required String message,
  Widget? note,
  String confirmLabel = 'تأكيد',
  String cancelLabel = 'إلغاء',
  IconData? confirmIcon,
  bool barrierDismissible = true,
}) async {
  final p = AdminPalette.of(context);
  final result = await showAdminDialog<bool>(
    context: context,
    barrierDismissible: barrierDismissible,
    barrierLabel: cancelLabel,
    builder: (ctx) => AdminDialogShell(
      icon: icon,
      tone: tone,
      title: title,
      subtitle: subtitle,
      maxWidth: 430,
      actions: [
        AdminDialogButtons.ghost(
          p,
          label: cancelLabel,
          onPressed: () => Navigator.of(ctx).pop(false),
        ),
        AdminDialogButtons.primary(
          p,
          label: confirmLabel,
          tone: tone,
          icon: confirmIcon,
          onPressed: () => Navigator.of(ctx).pop(true),
        ),
      ],
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(message,
              style: adminText(size: 13.5, color: p.inkMuted, height: 1.7)),
          if (note != null) ...[const SizedBox(height: 14), note],
        ],
      ),
    ),
  );
  return result ?? false;
}

/// ---------------------------------------------------------------------------
/// Body building blocks
/// ---------------------------------------------------------------------------
/// Inline soft alert (errors, hints) inside a dialog body.
class AdminDialogBanner extends StatelessWidget {
  final AdminDialogTone tone;
  final IconData icon;
  final String message;

  const AdminDialogBanner({
    super.key,
    required this.tone,
    required this.icon,
    required this.message,
  });

  @override
  Widget build(BuildContext context) {
    final p = AdminPalette.of(context);
    final t = adminToneColors(p, tone);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 12),
      decoration: BoxDecoration(
        color: t.soft,
        borderRadius: BorderRadius.circular(AdminRadii.md),
        border: Border.all(color: t.solid.withValues(alpha: 0.32)),
      ),
      child: Row(
        children: [
          Icon(icon, size: 18, color: t.ink),
          const SizedBox(width: 10),
          Expanded(
            child: Text(message,
                style: adminText(
                    size: 12.5, weight: FontWeight.w600, color: t.ink, height: 1.6)),
          ),
        ],
      ),
    );
  }
}

/// Small "entity" card used to quote the thing a dialog is about
/// (the meal being deleted, the admin being removed, …).
class AdminDialogNote extends StatelessWidget {
  final AdminDialogTone tone;
  final IconData icon;
  final String title;
  final String? subtitle;
  final String? badge;

  /// Optional leading media (e.g. a meal thumbnail) replacing the icon chip.
  final Widget? leading;

  const AdminDialogNote({
    super.key,
    this.tone = AdminDialogTone.neutral,
    required this.icon,
    required this.title,
    this.subtitle,
    this.badge,
    this.leading,
  });

  @override
  Widget build(BuildContext context) {
    final p = AdminPalette.of(context);
    final t = adminToneColors(p, tone);
    return Container(
      padding: const EdgeInsetsDirectional.fromSTEB(12, 12, 14, 12),
      decoration: BoxDecoration(
        color: p.surfaceAlt,
        borderRadius: BorderRadius.circular(AdminRadii.md),
        border: Border.all(color: p.border),
      ),
      child: Row(
        children: [
          leading ??
              Container(
                width: 38,
                height: 38,
                decoration: BoxDecoration(
                  color: t.soft,
                  borderRadius: BorderRadius.circular(AdminRadii.sm),
                ),
                child: Icon(icon, size: 19, color: t.ink),
              ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title,
                    style: adminText(
                        size: 13, weight: FontWeight.w700, color: p.ink, height: 1.4),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis),
                if (subtitle != null) ...[
                  const SizedBox(height: 3),
                  Text(subtitle!,
                      style: adminText(size: 11.5, color: p.inkMuted, height: 1.5),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis),
                ],
              ],
            ),
          ),
          if (badge != null) ...[
            const SizedBox(width: 10),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
              decoration: BoxDecoration(
                color: t.soft,
                borderRadius: BorderRadius.circular(AdminRadii.pill),
              ),
              child: Text(badge!,
                  style: adminText(
                      size: 11, weight: FontWeight.w700, color: t.ink)),
            ),
          ],
        ],
      ),
    );
  }
}

/// Thumbnail used as [AdminDialogNote.leading] for meals.
class AdminDialogThumb extends StatelessWidget {
  final String? imageUrl;

  const AdminDialogThumb({super.key, required this.imageUrl});

  @override
  Widget build(BuildContext context) {
    final p = AdminPalette.of(context);
    final placeholder = Container(
      width: 38,
      height: 38,
      color: p.surfaceSunken,
      child: Icon(AdminIcons.meal, size: 18, color: p.inkFaint),
    );
    return ClipRRect(
      borderRadius: BorderRadius.circular(AdminRadii.sm),
      child: (imageUrl == null || imageUrl!.isEmpty)
          ? placeholder
          : Image.network(
              imageUrl!,
              width: 38,
              height: 38,
              fit: BoxFit.cover,
              errorBuilder: (_, _, _) => placeholder,
            ),
    );
  }
}

/// Full-bleed media band for the top of a dialog.
class AdminDialogHero extends StatelessWidget {
  final String? imageUrl;
  final double height;

  const AdminDialogHero({super.key, required this.imageUrl, this.height = 150});

  @override
  Widget build(BuildContext context) {
    final p = AdminPalette.of(context);
    final placeholder = Container(
      height: height,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: AlignmentDirectional.topStart,
          end: AlignmentDirectional.bottomEnd,
          colors: [p.surfaceAlt, p.surfaceSunken],
        ),
      ),
      child: Center(child: Icon(AdminIcons.meal, size: 34, color: p.inkFaint)),
    );
    if (imageUrl == null || imageUrl!.isEmpty) return placeholder;
    return Stack(
      children: [
        Image.network(
          imageUrl!,
          height: height,
          width: double.infinity,
          fit: BoxFit.cover,
          loadingBuilder: (ctx, child, progress) => progress == null
              ? child
              : Container(
                  height: height,
                  color: p.surfaceAlt,
                  child: Center(
                    child: SizedBox(
                      width: 22,
                      height: 22,
                      child: CircularProgressIndicator(
                          strokeWidth: 2, color: p.inkFaint),
                    ),
                  ),
                ),
          errorBuilder: (_, _, _) => placeholder,
        ),
        // Hairline that separates the media from the header without a hard cut.
        Positioned(
          left: 0,
          right: 0,
          bottom: 0,
          child: Container(height: 1, color: p.border.withValues(alpha: 0.6)),
        ),
      ],
    );
  }
}

/// Small icon + caption used to head a group of fields.
class AdminSectionLabel extends StatelessWidget {
  final IconData icon;
  final String text;
  final String? trailing;

  const AdminSectionLabel({
    super.key,
    required this.icon,
    required this.text,
    this.trailing,
  });

  @override
  Widget build(BuildContext context) {
    final p = AdminPalette.of(context);
    return Row(
      children: [
        Container(
          width: 22,
          height: 22,
          decoration: BoxDecoration(
            color: p.surfaceAlt,
            borderRadius: BorderRadius.circular(7),
          ),
          child: Icon(icon, size: 13, color: p.inkMuted),
        ),
        const SizedBox(width: 8),
        Text(text,
            style: adminText(size: 12, weight: FontWeight.w700, color: p.inkFaint)),
        if (trailing != null) ...[
          const Spacer(),
          Text(trailing!,
              style: adminText(size: 11, color: p.inkFaint)),
        ],
      ],
    );
  }
}

/// Compact label/value tile for the details dialog spec grid.
class AdminSpecTile extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;

  const AdminSpecTile({
    super.key,
    required this.icon,
    required this.label,
    required this.value,
  });

  @override
  Widget build(BuildContext context) {
    final p = AdminPalette.of(context);
    return Container(
      padding: const EdgeInsetsDirectional.fromSTEB(12, 11, 12, 12),
      decoration: p.panel(color: p.surfaceAlt, radius: AdminRadii.md),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, size: 14, color: p.inkFaint),
              const SizedBox(width: 6),
              Expanded(
                child: Text(label,
                    style: adminText(size: 11, weight: FontWeight.w600, color: p.inkFaint),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(value,
              style: adminText(size: 13, weight: FontWeight.w700, color: p.ink, height: 1.4),
              maxLines: 2,
              overflow: TextOverflow.ellipsis),
        ],
      ),
    );
  }
}

/// Two-per-row layout for [AdminSpecTile]s.
class AdminSpecGrid extends StatelessWidget {
  final List<AdminSpecTile> tiles;

  const AdminSpecGrid({super.key, required this.tiles});

  @override
  Widget build(BuildContext context) {
    const gap = 10.0;
    return LayoutBuilder(
      builder: (context, constraints) {
        final width = (constraints.maxWidth - gap) / 2;
        return Wrap(
          spacing: gap,
          runSpacing: gap,
          children: [
            for (final tile in tiles) SizedBox(width: width, child: tile),
          ],
        );
      },
    );
  }
}

/// Soft note panel (free-form text, e.g. a meal's notes).
class AdminDialogPanel extends StatelessWidget {
  final IconData? icon;
  final String text;

  const AdminDialogPanel({super.key, this.icon, required this.text});

  @override
  Widget build(BuildContext context) {
    final p = AdminPalette.of(context);
    return Container(
      width: double.infinity,
      padding: const EdgeInsetsDirectional.fromSTEB(13, 12, 13, 13),
      decoration: p.panel(color: p.surfaceAlt, radius: AdminRadii.md),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (icon != null) ...[
            Icon(icon, size: 16, color: p.inkFaint),
            const SizedBox(width: 9),
          ],
          Expanded(
            child: Text(text,
                style: adminText(size: 12.5, color: p.inkMuted, height: 1.7)),
          ),
        ],
      ),
    );
  }
}

/// ---------------------------------------------------------------------------
/// Role badges (admin management)
/// ---------------------------------------------------------------------------
({String label, String short, AdminDialogTone tone, IconData icon})
    adminRoleMeta(String role) {
  switch (role) {
    case 'super_admin':
      return (
        label: 'صلاحيات كاملة',
        short: 'Super',
        tone: AdminDialogTone.brand,
        icon: AdminIcons.role,
      );
    case 'editing_admin':
    case 'admin':
      return (
        label: 'إدارة المحتوى',
        short: 'Editing',
        tone: AdminDialogTone.info,
        icon: AdminIcons.edit,
      );
    default:
      return (
        label: 'مشاهدة فقط',
        short: 'Viewing',
        tone: AdminDialogTone.neutral,
        icon: AdminIcons.visibility,
      );
  }
}

class AdminRoleBadge extends StatelessWidget {
  final String role;
  final bool withIcon;

  const AdminRoleBadge({super.key, required this.role, this.withIcon = true});

  @override
  Widget build(BuildContext context) {
    final p = AdminPalette.of(context);
    final meta = adminRoleMeta(role);
    final t = adminToneColors(p, meta.tone);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: t.soft,
        borderRadius: BorderRadius.circular(AdminRadii.pill),
        border: Border.all(color: t.solid.withValues(alpha: 0.3)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (withIcon) ...[
            Icon(meta.icon, size: 12, color: t.ink),
            const SizedBox(width: 5),
          ],
          Text(meta.label,
              style: adminText(size: 11, weight: FontWeight.w700, color: t.ink)),
        ],
      ),
    );
  }
}

/// ---------------------------------------------------------------------------
/// Fields
/// ---------------------------------------------------------------------------
/// Filled input style shared by every admin form.
InputDecoration adminFieldDeco(
  AdminPalette p, {
  required String label,
  String? hint,
  IconData? icon,
  Widget? suffixIcon,
  String? helper,
}) {
  OutlineInputBorder border(Color color, [double width = 1]) =>
      OutlineInputBorder(
        borderRadius: BorderRadius.circular(AdminRadii.sm),
        borderSide: BorderSide(color: color, width: width),
      );

  return InputDecoration(
    labelText: label,
    hintText: hint,
    labelStyle: adminText(size: 13, color: p.inkMuted),
    floatingLabelStyle:
        adminText(size: 13, weight: FontWeight.w700, color: p.clay),
    hintStyle: adminText(size: 12.5, color: p.inkFaint),
    helperText: helper,
    helperStyle: adminText(size: 11.5, color: p.inkFaint),
    prefixIcon: icon == null ? null : Icon(icon, size: 18, color: p.inkFaint),
    suffixIcon: suffixIcon,
    filled: true,
    fillColor: p.surfaceAlt,
    contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 15),
    border: border(p.border),
    enabledBorder: border(p.border),
    focusedBorder: border(p.clay, 1.6),
    errorBorder: border(p.chiliSolid),
    focusedErrorBorder: border(p.chiliSolid, 1.6),
    errorStyle: adminText(size: 11.5, color: p.chiliInk),
  );
}

/// Password field with a show/hide toggle.
class AdminPasswordField extends StatelessWidget {
  final TextEditingController controller;
  final String label;
  final bool visible;
  final VoidCallback onToggle;
  final String? helper;
  final ValueChanged<String>? onChanged;
  final bool enabled;

  const AdminPasswordField({
    super.key,
    required this.controller,
    required this.label,
    required this.visible,
    required this.onToggle,
    this.helper,
    this.onChanged,
    this.enabled = true,
  });

  @override
  Widget build(BuildContext context) {
    final p = AdminPalette.of(context);
    return TextField(
      controller: controller,
      obscureText: !visible,
      enabled: enabled,
      style: adminText(color: p.ink),
      onChanged: onChanged,
      decoration: adminFieldDeco(
        p,
        label: label,
        icon: AdminIcons.password,
        helper: helper,
        suffixIcon: IconButton(
          tooltip: visible ? 'إخفاء كلمة المرور' : 'إظهار كلمة المرور',
          onPressed: onToggle,
          icon: Icon(
            visible ? AdminIcons.visibilityOff : AdminIcons.visibility,
            size: 19,
            color: p.inkFaint,
          ),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Toast notifications live in `admin_toast.dart` (AdminToast / showAdminToast).
// ─────────────────────────────────────────────────────────────────────────────
