import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../../core/router/app_router.dart';
import '../theme/admin_palette.dart';
import 'admin_dialog.dart';

/// ============================================================================
/// AdminToast — the single notification surface for the admin panel.
///
/// One overlay-mounted stack for every transient message in the admin area
/// (login actions, vault operations, background uploads, appearance changes),
/// so feedback always looks and behaves the same way.
///
/// Behaviour baked in here:
///   • Newest toast sits at the bottom-right; older toasts are pushed upward.
///   • Once the stack grows past half the viewport height, its top edge fades
///     out (ShaderMask) instead of the messages just disappearing.
///   • Auto-dismiss timer doubles as a slim progress bar; hovering a toast
///     pauses it, leaving resumes it.
///   • The card always wears the *inverse* brightness of the screen behind it,
///     so it never blends into the page ([AdminToastTones]).
///   • `loading` toasts never expire on their own — they resolve in place into
///     a success/error toast through [AdminToastHandle.resolve].
///   • Every toast is mirrored into a history log, surfaced by the bell in the
///     top bar ([showAdminNotificationCenter]).
/// ============================================================================

/// ---------------------------------------------------------------------------
/// Notification taxonomy
/// ---------------------------------------------------------------------------
/// The split follows the taxonomy design systems converge on (Lightning,
/// Ant Design, Sonner, react-toastify): an acknowledgement tier, an
/// attention tier, and a status tier. Each kind owns its icon, accent,
/// lifetime and whether it can be dismissed by hand.
///
/// Two families decide how long a toast is actually kept on screen:
///   • Actionable — carries a `تراجع` affordance, so the admin needs a real
///     window to decide. It ignores the kind's status lifetime and stays up for
///     [AdminToastItem.actionWindow] instead.
///   • Status — "the operation finished", nothing to decide. Those stay up for
///     the kind's own (much shorter) lifetime and then collapse away.
enum AdminToastKind {
  /// Neutral confirmation that something is happening or is now true.
  info,

  /// A completed action — saved, approved, backed up.
  success,

  /// Destructive or risky work that still succeeded, or a duplicate/state the
  /// admin should re-check. Undo lives here, not in [error].
  warning,

  /// A failed action that needs attention. Longest status lifetime, since the
  /// reason text has to be readable.
  error,

  /// Work in flight; only ends when resolved by [AdminToastHandle.resolve].
  loading,

  /// Connectivity or degraded system state, until it recovers.
  offline,
}

class AdminToastSpec {
  final IconData icon;
  final Color accent;
  final String label;

  /// How long a *status* toast of this kind stays on its own; `null` means it
  /// waits for manual dismissal (or a resolve call).
  final Duration? autoDismiss;

  const AdminToastSpec({
    required this.icon,
    required this.accent,
    required this.label,
    required this.autoDismiss,
  });
}

extension AdminToastKindSpec on AdminToastKind {
  AdminToastSpec get spec => switch (this) {
        AdminToastKind.info => AdminToastSpec(
            icon: AdminIcons.info,
            accent: const Color(0xFF3B82F6),
            label: 'معلومة',
            autoDismiss: const Duration(milliseconds: 2200),
          ),
        AdminToastKind.success => AdminToastSpec(
            icon: AdminIcons.success,
            accent: const Color(0xFF22C55E),
            label: 'تم بنجاح',
            autoDismiss: const Duration(milliseconds: 2000),
          ),
        AdminToastKind.warning => AdminToastSpec(
            icon: AdminIcons.warning,
            accent: const Color(0xFFF59E0B),
            label: 'تنبيه',
            autoDismiss: const Duration(milliseconds: 3200),
          ),
        AdminToastKind.error => AdminToastSpec(
            icon: AdminIcons.danger,
            accent: const Color(0xFFEF4444),
            label: 'خطأ',
            autoDismiss: const Duration(milliseconds: 5500),
          ),
        AdminToastKind.loading => AdminToastSpec(
            icon: Icons.pending_rounded,
            accent: const Color(0xFF38BDF8),
            label: 'قيد التنفيذ',
            autoDismiss: null,
          ),
        AdminToastKind.offline => AdminToastSpec(
            icon: Icons.cloud_off_rounded,
            accent: const Color(0xFF94A3B8),
            label: 'حالة الاتصال',
            autoDismiss: null,
          ),
      };
}

/// ---------------------------------------------------------------------------
/// Toast surface
/// ---------------------------------------------------------------------------

/// The card is painted on the opposite brightness of the screen behind it:
/// light over the dark dashboard, dark over the light one. A toast that shares
/// its background's tone reads as part of the page instead of as feedback, so
/// the inversion is deliberate and not a theme bug.
class AdminToastTones {
  /// True when the card itself is the light surface (dark dashboard).
  final bool isLightCard;
  final Color card;
  final Color title;
  final Color subtitle;
  final Color dismissBg;
  final Color dismissFg;

  const AdminToastTones({
    required this.isLightCard,
    required this.card,
    required this.title,
    required this.subtitle,
    required this.dismissBg,
    required this.dismissFg,
  });

  static const AdminToastTones darkCard = AdminToastTones(
    isLightCard: false,
    card: Color(0xFF1E293B),
    title: Color(0xFFF1F5F9),
    subtitle: Color(0xFF94A3B8),
    dismissBg: Color(0xFF334155),
    dismissFg: Color(0xFF94A3B8),
  );

  static const AdminToastTones lightCard = AdminToastTones(
    isLightCard: true,
    card: Color(0xFFF8FAFC),
    title: Color(0xFF0F172A),
    subtitle: Color(0xFF475569),
    dismissBg: Color(0xFFE2E8F0),
    dismissFg: Color(0xFF334155),
  );

  static AdminToastTones forScreen(Brightness screen) =>
      screen == Brightness.dark ? lightCard : darkCard;

  /// The taxonomy accents are mid-tones tuned for the dark card; on the light
  /// card they sink, so they are pulled down toward slate.
  Color accent(Color base) =>
      isLightCard ? Color.lerp(base, const Color(0xFF1E293B), 0.32)! : base;
}

/// ---------------------------------------------------------------------------
/// Public API
/// ---------------------------------------------------------------------------

/// A live toast the caller can finish or dismiss later — used for tasks that
/// start in the background and report back when they land.
class AdminToastHandle {
  final String _id;

  const AdminToastHandle(this._id);

  /// Morph this toast into a final state without moving it in the stack.
  void resolve({
    String? message,
    String? subtitle,
    AdminToastKind? kind,
    Duration? duration,
    VoidCallback? onUndo,
  }) {
    AdminToastRegistry.instance.resolve(
      _id,
      message: message,
      subtitle: subtitle,
      kind: kind,
      duration: duration,
      onUndo: onUndo,
    );
  }

  void dismiss() => AdminToastRegistry.instance.dismiss(_id);
}

abstract final class AdminToast {
  /// Context-free entry point — resolves the root overlay itself, so data
  /// layers (upload providers, repositories) can report to the same stack.
  static AdminToastHandle show({
    required String message,
    String? subtitle,
    AdminToastKind kind = AdminToastKind.success,
    VoidCallback? onUndo,
    Duration? duration,
  }) {
    AdminToastOverlay.mount();
    return AdminToastHandle(AdminToastRegistry.instance.push(
      message: message,
      subtitle: subtitle,
      kind: kind,
      onUndo: onUndo,
      duration: duration,
    ));
  }

  /// A toast that stays until [AdminToastHandle.resolve] reports the outcome.
  static AdminToastHandle loading({
    required String message,
    String? subtitle,
  }) =>
      show(
        message: message,
        subtitle: subtitle,
        kind: AdminToastKind.loading,
        duration: null,
      );

  static void dismissAll() => AdminToastRegistry.instance.dismissAll();
}

/// Back-compatible call used across the dashboard: same stack, same look.
void showAdminToast(
  BuildContext context, {
  required String message,
  String? subtitle,
  AdminToastKind kind = AdminToastKind.success,
  VoidCallback? onUndo,
  Duration? duration,
}) {
  AdminToastOverlay.mount(context);
  AdminToastRegistry.instance.push(
    message: message,
    subtitle: subtitle,
    kind: kind,
    onUndo: onUndo,
    duration: duration,
  );
}

/// ---------------------------------------------------------------------------
/// Registry — stack contents + history log
/// ---------------------------------------------------------------------------

class AdminToastItem {
  /// Window given to a toast the admin can still act on (undo), so the offer
  /// doesn't expire mid-decision.
  static const Duration actionWindow = Duration(seconds: 8);

  final String id;
  String message;
  String? subtitle;
  AdminToastKind kind;
  Duration? duration;
  VoidCallback? onUndo;

  AdminToastItem({
    required this.id,
    required this.message,
    required this.kind,
    this.subtitle,
    this.duration,
    this.onUndo,
  });

  Duration? get lifetime {
    if (duration != null) return duration;
    if (onUndo != null) return actionWindow;
    return kind.spec.autoDismiss;
  }
}

class AdminToastRecord {
  final AdminToastKind kind;
  final String message;
  final String? subtitle;
  final DateTime time;

  const AdminToastRecord({
    required this.kind,
    required this.message,
    required this.subtitle,
    required this.time,
  });
}

class AdminToastRegistry extends ChangeNotifier {
  AdminToastRegistry._();

  static final AdminToastRegistry instance = AdminToastRegistry._();

  /// The stack only fades past half the viewport; a hard cap keeps the oldest
  /// messages from piling up forever behind that fade.
  static const int maxVisible = 7;
  static const int maxHistory = 40;

  final List<AdminToastItem> _items = [];
  final List<AdminToastRecord> _history = [];
  int _seq = 0;

  /// Oldest first — the stack renders bottom-up, so the last entry is newest.
  List<AdminToastItem> get items => List<AdminToastItem>.unmodifiable(_items);
  List<AdminToastRecord> get history =>
      List<AdminToastRecord>.unmodifiable(_history);

  String push({
    required String message,
    AdminToastKind kind = AdminToastKind.success,
    String? subtitle,
    Duration? duration,
    VoidCallback? onUndo,
  }) {
    final id = 'toast-${_seq++}';
    _items.add(AdminToastItem(
      id: id,
      message: message,
      subtitle: subtitle,
      kind: kind,
      duration: duration,
      onUndo: onUndo,
    ));
    _history.insert(
      0,
      AdminToastRecord(
        kind: kind,
        message: message,
        subtitle: subtitle,
        time: DateTime.now(),
      ),
    );
    if (_history.length > maxHistory) _history.removeRange(maxHistory, _history.length);
    if (_items.length > maxVisible) {
      _items.removeRange(0, _items.length - maxVisible);
    }
    notifyListeners();
    return id;
  }

  void resolve(
    String id, {
    String? message,
    String? subtitle,
    AdminToastKind? kind,
    Duration? duration,
    VoidCallback? onUndo,
  }) {
    final index = _items.indexWhere((t) => t.id == id);
    if (index == -1) return;
    final item = _items[index];
    if (onUndo != null) item.onUndo = onUndo;
    if (message != null) {
      item.message = message;
      _history.insert(
        0,
        AdminToastRecord(
          kind: kind ?? item.kind,
          message: message,
          subtitle: subtitle,
          time: DateTime.now(),
        ),
      );
      if (_history.length > maxHistory) {
        _history.removeRange(maxHistory, _history.length);
      }
    }
    if (subtitle != null) item.subtitle = subtitle;
    if (kind != null) item.kind = kind;
    if (duration != null || kind != null) item.duration = duration;
    notifyListeners();
  }

  void dismiss(String id) {
    final before = _items.length;
    _items.removeWhere((t) => t.id == id);
    if (_items.length != before) notifyListeners();
  }

  void dismissAll() {
    if (_items.isEmpty) return;
    _items.clear();
    notifyListeners();
  }

  void clearHistory() {
    _history.clear();
    notifyListeners();
  }

  @visibleForTesting
  void debugReset() {
    _items.clear();
    _history.clear();
    _seq = 0;
    notifyListeners();
  }
}

/// ---------------------------------------------------------------------------
/// Overlay host — one persistent entry, reused by every toast
/// ---------------------------------------------------------------------------

abstract final class AdminToastOverlay {
  static OverlayEntry? _entry;

  static void mount([BuildContext? context]) {
    if (_entry != null) return;
    // The root navigator's own overlay: it sits above every route, so the
    // stack survives page changes and nested navigators.
    final overlay = rootNavigatorKey.currentState?.overlay ??
        (context == null ? null : Overlay.of(context, rootOverlay: true));
    if (overlay == null) return;
    final entry = OverlayEntry(builder: (_) => const AdminToastStack());
    _entry = entry;
    overlay.insert(entry);
  }

  /// Drops the host entry — used by tests that rebuild the app between cases.
  @visibleForTesting
  static void debugUnmount() {
    _entry?.remove();
    _entry = null;
  }
}

/// ---------------------------------------------------------------------------
/// The stack
/// ---------------------------------------------------------------------------

class AdminToastStack extends StatefulWidget {
  /// Height of the toast area as a fraction of the viewport: past this the
  /// oldest messages fade out from the top.
  static const double fadeAtViewportFraction = 0.5;

  const AdminToastStack({super.key});

  @override
  State<AdminToastStack> createState() => _AdminToastStackState();
}

class _AdminToastStackState extends State<AdminToastStack> {
  @override
  void initState() {
    super.initState();
    AdminToastRegistry.instance.addListener(_onChange);
  }

  @override
  void dispose() {
    AdminToastRegistry.instance.removeListener(_onChange);
    super.dispose();
  }

  void _onChange() {
    if (mounted) setState(() {});
  }

  /// Worst-case height of one toast row (two-line title + one-line subtitle,
  /// padding and the gap below it), used to keep the stack inside the viewport.
  static const double _slotHeight = 96;

  @override
  Widget build(BuildContext context) {
    final all = AdminToastRegistry.instance.items;
    final screen = MediaQuery.sizeOf(context);
    final stackWidth = math.min(380.0, screen.width - 48);
    final fits = math.max(1, ((screen.height - 80) / _slotHeight).floor());
    final items = all.length > fits ? all.sublist(all.length - fits) : all;

    return Positioned(
      right: 24,
      bottom: 28,
      child: SizedBox(
        width: stackWidth,
        child: ShaderMask(
          blendMode: BlendMode.dstIn,
          shaderCallback: (rect) =>
              _fadeShader(rect, screen.height * AdminToastStack.fadeAtViewportFraction),
          child: items.isEmpty
              ? const SizedBox.shrink()
              : Column(
                  key: const ValueKey('admin-toast-column'),
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    for (var i = 0; i < items.length; i++)
                      AdminToastCard(
                        key: ValueKey(items[i].id),
                        item: items[i],
                        isBottom: i == items.length - 1,
                      ),
                  ],
                ),
        ),
      ),
    );
  }

  /// Transparent at the very top of the stack, opaque below the fade band. The
  /// band only opens up once the stack passes [safeHeight], so short stacks are
  /// untouched.
  Shader _fadeShader(Rect rect, double safeHeight) {
    final height = rect.height;
    final strength = ((height - safeHeight) / safeHeight).clamp(0.0, 1.0);
    if (strength <= 0) {
      return const LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [Color(0xFFFFFFFF), Color(0xFFFFFFFF)],
      ).createShader(rect);
    }
    final band = math.min(
        height, math.max(safeHeight * 0.35, height * 0.2 * strength + safeHeight * 0.12));
    final topAlpha = (1 - 0.94 * strength).clamp(0.0, 1.0);
    return LinearGradient(
      begin: Alignment.topCenter,
      end: Alignment.bottomCenter,
      colors: [
        Color.fromARGB((topAlpha * 255).round(), 255, 255, 255),
        const Color(0xFFFFFFFF),
      ],
      stops: [0, (band / height).clamp(0.05, 1.0)],
    ).createShader(rect);
  }
}

/// ---------------------------------------------------------------------------
/// A single toast
/// ---------------------------------------------------------------------------

class AdminToastCard extends StatefulWidget {
  final AdminToastItem item;

  /// Only the newest toast (bottom of the stack) drops its gap.
  final bool isBottom;

  const AdminToastCard({
    super.key,
    required this.item,
    required this.isBottom,
  });

  @override
  State<AdminToastCard> createState() => _AdminToastCardState();
}

class _AdminToastCardState extends State<AdminToastCard>
    with TickerProviderStateMixin {
  late final AnimationController _enter;
  AnimationController? _life;
  bool _leaving = false;
  bool _collapsed = false;
  bool _paused = false;

  // The item is mutated in place by resolve(), so the timer state the card was
  // last armed with has to be tracked here rather than compared to the old
  // widget config.
  AdminToastKind? _armedKind;
  Duration? _armedLifetime;

  @override
  void initState() {
    super.initState();
    _enter = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 300),
      reverseDuration: const Duration(milliseconds: 200),
    )..forward();
    _armTimer();
  }

  @override
  void didUpdateWidget(AdminToastCard old) {
    super.didUpdateWidget(old);
    // A resolve() can change the kind and therefore the lifetime: re-arm so
    // a loading toast that just succeeded starts counting down now.
    if (_armedKind != widget.item.kind || _armedLifetime != widget.item.lifetime) {
      _armTimer();
    }
  }

  void _armTimer() {
    final lifetime = widget.item.lifetime;
    _armedKind = widget.item.kind;
    _armedLifetime = lifetime;
    _life?.dispose();
    if (lifetime == null) {
      _life = null;
      return;
    }
    final controller = AnimationController(vsync: this, duration: lifetime);
    controller.addStatusListener((status) {
      if (status == AnimationStatus.completed) _dismiss();
    });
    controller.forward();
    _life = controller;
    _paused = false;
  }

  void _pause() {
    if (_life == null || _leaving) return;
    _paused = true;
    _life!.stop();
  }

  void _resume() {
    if (_life == null || !_paused || _leaving) return;
    _paused = false;
    // Continue counting down with only the time that is actually left.
    _life!.animateTo(1, duration: _life!.duration! * (1 - _life!.value));
  }

  Future<void> _dismiss() async {
    if (_leaving || !mounted) return;
    setState(() => _leaving = true);
    _life?.stop();
    await _enter.reverse();
    if (!mounted) return;
    setState(() => _collapsed = true);
    await Future<void>.delayed(const Duration(milliseconds: 220));
    AdminToastRegistry.instance.dismiss(widget.item.id);
  }

  void _runUndo() {
    widget.item.onUndo?.call();
    _dismiss();
  }

  @override
  void dispose() {
    _enter.dispose();
    _life?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final item = widget.item;
    final spec = item.kind.spec;
    final tones =
        AdminToastTones.forScreen(Theme.of(context).brightness);
    final accent = tones.accent(spec.accent);

    return AnimatedSize(
      duration: const Duration(milliseconds: 220),
      curve: Curves.easeOutCubic,
      alignment: Alignment.bottomCenter,
      child: _collapsed
          ? const SizedBox(width: double.infinity, height: 0)
          : Padding(
              padding: EdgeInsets.only(bottom: widget.isBottom ? 0 : 10),
              child: FadeTransition(
                opacity: CurvedAnimation(parent: _enter, curve: Curves.easeOut),
                child: SlideTransition(
                  position: Tween<Offset>(
                    begin: const Offset(1.15, 0),
                    end: Offset.zero,
                  ).animate(CurvedAnimation(
                      parent: _enter, curve: Curves.easeOutCubic)),
                  child: MouseRegion(
                    onEnter: (_) => _pause(),
                    onExit: (_) => _resume(),
                    child: Semantics(
                      label: '${spec.label}: ${item.message}',
                      liveRegion: true,
                      child: Material(
                        color: tones.card,
                        borderRadius: BorderRadius.circular(16),
                        clipBehavior: Clip.antiAlias,
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Padding(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 14, vertical: 13),
                              child: Row(
                                crossAxisAlignment: CrossAxisAlignment.center,
                                children: [
                                  _LeadingIcon(
                                    spec: spec,
                                    accent: accent,
                                    spins: item.kind == AdminToastKind.loading,
                                  ),
                                  const SizedBox(width: 12),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        Text(
                                          item.message,
                                          maxLines: 2,
                                          overflow: TextOverflow.ellipsis,
                                          style: GoogleFonts.cairo(
                                            fontSize: 13,
                                            fontWeight: FontWeight.bold,
                                            color: tones.title,
                                          ),
                                        ),
                                        if (item.subtitle != null) ...[
                                          const SizedBox(height: 1),
                                          Text(
                                            item.subtitle!,
                                            maxLines: 1,
                                            overflow: TextOverflow.ellipsis,
                                            style: GoogleFonts.cairo(
                                              fontSize: 11.5,
                                              color: tones.subtitle,
                                            ),
                                          ),
                                        ],
                                      ],
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  if (item.onUndo != null) ...[
                                    _PillAction(
                                      label: 'تراجع',
                                      background: const Color(0xFF16A34A),
                                      onPressed: _runUndo,
                                    ),
                                    const SizedBox(width: 6),
                                  ],
                                  _DismissButton(
                                    background: tones.dismissBg,
                                    foreground: tones.dismissFg,
                                    onPressed: _dismiss,
                                  ),
                                ],
                              ),
                            ),
                            if (_life != null) _LifetimeBar(life: _life!, accent: accent),                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
    );
  }
}

/// Spins while the work is still running, settles into the kind's glyph once
/// the toast is resolved.
class _LeadingIcon extends StatelessWidget {
  final AdminToastSpec spec;
  final Color accent;
  final bool spins;

  const _LeadingIcon({
    required this.spec,
    required this.accent,
    required this.spins,
  });

  @override
  Widget build(BuildContext context) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 260),
      curve: Curves.easeOut,
      width: 36,
      height: 36,
      decoration: BoxDecoration(
        color: accent.withValues(alpha: 0.18),
        shape: BoxShape.circle,
      ),
      child: Center(
        child: spins
            ? SizedBox(
                width: 19,
                height: 19,
                child: CircularProgressIndicator(
                  strokeWidth: 2.2,
                  color: accent,
                ),
              )
            : Icon(spec.icon, size: 20, color: accent),
      ),
    );
  }
}

class _LifetimeBar extends StatelessWidget {
  /// Runs 0 → 1 over the toast's lifetime, so the bar shows what is left.
  final AnimationController life;
  final Color accent;

  const _LifetimeBar({required this.life, required this.accent});

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: life,
      builder: (context, _) => Align(
        alignment: AlignmentDirectional.centerStart,
        child: FractionallySizedBox(
          widthFactor: (1 - life.value).clamp(0.0, 1.0),
          child: Container(
            height: 2.5,
            color: accent.withValues(alpha: 0.55),
          ),
        ),
      ),
    );
  }
}

class _PillAction extends StatelessWidget {
  final String label;
  final Color background;
  final VoidCallback onPressed;

  const _PillAction({
    required this.label,
    required this.background,
    required this.onPressed,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onPressed,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 5),
        decoration: BoxDecoration(
          color: background,
          borderRadius: BorderRadius.circular(20),
        ),
        child: Text(
          label,
          style: GoogleFonts.cairo(
            fontSize: 12,
            fontWeight: FontWeight.bold,
            color: Colors.white,
          ),
        ),
      ),
    );
  }
}

class _DismissButton extends StatelessWidget {
  final Color background;
  final Color foreground;
  final VoidCallback onPressed;

  const _DismissButton({
    required this.background,
    required this.foreground,
    required this.onPressed,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onPressed,
      child: Container(
        width: 26,
        height: 26,
        decoration: BoxDecoration(
          color: background,
          shape: BoxShape.circle,
        ),
        child: Icon(
          Icons.close_rounded,
          size: 14,
          color: foreground,
        ),
      ),
    );
  }
}

/// ---------------------------------------------------------------------------
/// Notification centre — the same stack's history, grouped by taxonomy
/// ---------------------------------------------------------------------------

Future<void> showAdminNotificationCenter(BuildContext context) {
  final p = AdminPalette.of(context);
  final records = AdminToastRegistry.instance.history;
  final shown = records.take(12).toList();

  return showAdminDialog<void>(
    context: context,
    builder: (dialogCtx) => AdminDialogShell(
      icon: Icons.notifications_rounded,
      tone: AdminDialogTone.brand,
      title: 'مركز الإشعارات',
      subtitle: 'آخر ما صدر عن لوحة التحكم، مرتّباً حسب نوع الإشعار',
      maxWidth: 470,
      actions: [
        if (records.isNotEmpty)
          AdminDialogButtons.ghost(
            p,
            label: 'مسح السجل',
            icon: AdminIcons.delete,
            onPressed: () {
              AdminToastRegistry.instance.clearHistory();
              Navigator.of(dialogCtx).pop();
            },
          ),
      ],
      child: shown.isEmpty
          ? const AdminDialogPanel(
              icon: AdminIcons.empty,
              text: 'لا توجد إشعارات في هذه الجلسة بعد.',
            )
          : Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                for (var i = 0; i < shown.length; i++) ...[
                  if (i > 0) const SizedBox(height: 8),
                  _HistoryTile(record: shown[i], palette: p),
                ],
                if (records.length > shown.length) ...[
                  const SizedBox(height: 10),
                  Text(
                    'يعرض السجل أحدث ${shown.length} إشعاراً من أصل ${records.length}.',
                    textAlign: TextAlign.center,
                    style: adminText(size: 11, color: p.inkFaint),
                  ),
                ],
              ],
            ),
    ),
  );
}

class _HistoryTile extends StatelessWidget {
  final AdminToastRecord record;
  final AdminPalette palette;

  const _HistoryTile({required this.record, required this.palette});

  @override
  Widget build(BuildContext context) {
    final p = palette;
    final spec = record.kind.spec;
    return Container(
      padding: const EdgeInsetsDirectional.fromSTEB(11, 10, 11, 10),
      decoration: p.panel(color: p.surfaceAlt, radius: AdminRadii.md),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 30,
            height: 30,
            decoration: BoxDecoration(
              color: spec.accent.withValues(alpha: 0.14),
              shape: BoxShape.circle,
            ),
            child: Icon(spec.icon, size: 16, color: spec.accent),
          ),
          const SizedBox(width: 11),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  record.message,
                  style: adminText(
                      size: 12.5, weight: FontWeight.w700, color: p.ink),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
                if (record.subtitle != null) ...[
                  const SizedBox(height: 2),
                  Text(
                    record.subtitle!,
                    style: adminText(size: 11, color: p.inkFaint),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(width: 10),
          Text(
            _relativeTime(record.time),
            style: adminText(size: 10.5, color: p.inkFaint),
          ),
        ],
      ),
    );
  }

  static String _relativeTime(DateTime time) {
    final diff = DateTime.now().difference(time);
    if (diff.inSeconds < 45) return 'الآن';
    if (diff.inMinutes < 60) return 'منذ ${diff.inMinutes} د';
    if (diff.inHours < 24) return 'منذ ${diff.inHours} س';
    return 'منذ ${diff.inDays} يوم';
  }
}
