# Admin panel design system

Every admin screen and widget follows the redesigned system. The old look was
removed on purpose — do not reintroduce it, and do not copy an older screen as a
template for a new one.

## Feedback (toasts)

- All admin feedback goes through `showAdminToast` (or `AdminToast.loading` +
  `handle.resolve` for work in flight) in
  `lib/features/admin/presentation/widgets/admin_toast.dart`.
- Never use `SnackBar` / `ScaffoldMessenger` in the admin panel.
- Pick the taxonomy kind deliberately: `success` for a finished action,
  `warning` for risky/destructive outcomes (undo lives here), `error` for
  failures with a readable reason in `subtitle`, `info` for state, `offline`
  for connectivity.
- One action raises one toast. A child widget that reports through its host
  callback stays silent.

## Colour, type, shape

- Colours come from `AdminPalette.of(context)` tokens only — no `Color(0x...)`
  literals, no `Colors.white` / `Colors.black` standing in for a token, and no
  screen-local `isDark ? ... : ...` palette block.
- Text uses `adminText(...)` from `widgets/admin_dialog.dart`.
- Panels use `AdminPalette.panel(...)`; radii come from `AdminRadii`.
- Icons come from the `AdminIcons` set; add a member there instead of reaching
  for a raw `Icons.*` glyph.

## Shared building blocks

- Page sections open with `AdminSectionHeader` — never a screen-local header.
- Secondary icon actions use `AdminIconChip` (filled `surfaceAlt`, `borderStrong`
  outline, full-strength glyph). A bare `IconButton` with `inkFaint` is not
  acceptable: it disappears on the dark theme.
- Dialogs and confirmations use `showAdminDialog` / `showAdminConfirmDialog` and
  `AdminDialogShell` / `AdminDialogPanel` / `AdminDialogButtons`.
- Form fields use `adminFieldDeco`.

## Shell rules

- Pages render inside the dashboard shell, so the top bar already prints the
  page title and subtitle from `_pageMeta`. Do not repeat them inside the page.
- Desktop/mobile split is the `constraints.maxWidth < 900` breakpoint.
- Admin UI text is Arabic; keep route paths and emails LTR inside RTL rows.
