import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/database/app_database.dart';
import '../../settings/providers/settings_providers.dart';
import 'theme/admin_palette.dart';
import 'widgets/admin_dialog.dart';
import 'widgets/admin_toast.dart';

class AdminForgotPasswordScreen extends ConsumerStatefulWidget {
  final String? initialEmail;

  const AdminForgotPasswordScreen({super.key, this.initialEmail});

  @override
  ConsumerState<AdminForgotPasswordScreen> createState() =>
      _AdminForgotPasswordScreenState();
}

class _AdminForgotPasswordScreenState
    extends ConsumerState<AdminForgotPasswordScreen> {
  late final TextEditingController _emailController;
  final _formKey = GlobalKey<FormState>();

  bool _isLoading = false;
  String? _errorMessage;
  String? _successMessage;

  // Settings Gear
  bool _isEnglish = false;

  @override
  void initState() {
    super.initState();
    _emailController = TextEditingController(text: widget.initialEmail);
  }

  @override
  void dispose() {
    _emailController.dispose();
    super.dispose();
  }

  /// Arabic copy rides the Arabic face, English copy is set as a Latin run.
  TextStyle _ui({
    double size = 13.5,
    FontWeight weight = FontWeight.w500,
    Color? color,
    double? height,
  }) {
    return _isEnglish
        ? adminLatinText(
            size: size,
            weight: weight,
            color: color,
            height: height,
          )
        : adminText(size: size, weight: weight, color: color, height: height);
  }

  /// Recovery results belong to the form, so they show in place (the banners
  /// above the field) instead of in the dashboard's toast stack.
  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() {
      _isLoading = true;
      _errorMessage = null;
      _successMessage = null;
    });

    final email = _emailController.text.trim();

    try {
      await FirebaseAuth.instance.sendPasswordResetEmail(email: email);
      setState(() => _successMessage = _sentMessage);
    } catch (e) {
      final msg = e.toString().toLowerCase();

      // Handle user-not-found silently to prevent email enumeration
      if (msg.contains('user-not-found')) {
        setState(() => _successMessage = _sentMessage);
        return;
      }

      final isRateLimited = msg.contains('too-many-requests');
      final isOffline = msg.contains('network');
      setState(
        () => _errorMessage = isRateLimited
            ? (_isEnglish
                  ? 'Too many attempts. Try again later.'
                  : 'محاولات كثيرة جداً. حاول لاحقاً.')
            : isOffline
            ? (_isEnglish
                  ? 'Network error. Check your connection.'
                  : 'خطأ في الاتصال. تحقق من الإنترنت.')
            : (_isEnglish
                  ? 'An error occurred. Please try again.'
                  : 'حدث خطأ. يرجى المحاولة مرة أخرى.'),
      );
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  String get _sentMessage => _isEnglish
      ? 'If an account exists, a reset link was sent! Check your inbox.'
      : 'إذا كان هذا البريد مشرفاً، فقد تم إرسال رابط الاستعادة! تحقق من صندوق الوارد.';

  Future<void> _setThemeMode(AppThemeModePreference mode) async {
    final light = mode == AppThemeModePreference.light;
    try {
      await ref.read(settingsControllerProvider.notifier).updateThemeMode(mode);
      if (!mounted) return;
      AdminToast.show(
        message: _isEnglish
            ? (light ? 'Light mode enabled' : 'Dark mode enabled')
            : (light
                  ? 'تم التبديل إلى الوضع النهاري'
                  : 'تم التبديل إلى الوضع الداكن'),
        kind: AdminToastKind.success,
      );
    } catch (_) {
      if (!mounted) return;
      AdminToast.show(
        message: _isEnglish
            ? 'Could not change the display mode'
            : 'تعذر تغيير وضع العرض',
        kind: AdminToastKind.error,
      );
    }
  }

  /// Language + theme menu. Behaviour is untouched; only the skin is the
  /// shared one — filled `surfaceAlt` chip, `borderStrong` hairline,
  /// full-strength glyph.
  Widget _settingsMenu(AdminPalette p, bool isDark) {
    final tLangMenu = _isEnglish ? 'العربية' : 'English';
    final tThemeMenu = isDark
        ? (_isEnglish ? 'Light mode' : 'الوضع الفاتح')
        : (_isEnglish ? 'Dark mode' : 'الوضع الداكن');

    return PopupMenuButton<String>(
      onSelected: (value) {
        if (value == 'lang') {
          setState(() => _isEnglish = !_isEnglish);
        } else if (value == 'theme') {
          _setThemeMode(
            isDark ? AppThemeModePreference.light : AppThemeModePreference.dark,
          );
        }
      },
      offset: const Offset(0, 48),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AdminRadii.md),
      ),
      color: p.surface,
      child: Container(
        width: 42,
        height: 42,
        decoration: BoxDecoration(
          color: p.surfaceAlt,
          borderRadius: BorderRadius.circular(AdminRadii.sm),
          border: Border.all(color: p.borderStrong),
        ),
        child: Icon(AdminIcons.settings, size: 20, color: p.ink),
      ),
      itemBuilder: (menuContext) => [
        PopupMenuItem(
          value: 'lang',
          child: Row(
            children: [
              Icon(
                // No language glyph in AdminIcons yet.
                AdminIcons.language,
                size: 18,
                color: p.inkMuted,
              ),
              const SizedBox(width: 10),
              Text(
                tLangMenu,
                style: _isEnglish
                    ? adminText(size: 13, weight: FontWeight.w600, color: p.ink)
                    : adminLatinText(
                        size: 13,
                        weight: FontWeight.w600,
                        color: p.ink,
                      ),
              ),
            ],
          ),
        ),
        PopupMenuItem(
          value: 'theme',
          child: Row(
            children: [
              Icon(
                // No sun/moon glyph in AdminIcons yet (same as the dashboard
                // top bar).
                isDark ? AdminIcons.lightMode : AdminIcons.darkMode,
                size: 18,
                color: p.inkMuted,
              ),
              const SizedBox(width: 10),
              Text(
                tThemeMenu,
                style: _ui(size: 13, weight: FontWeight.w600, color: p.ink),
              ),
            ],
          ),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final p = AdminPalette.of(context);
    final isDark = p.isDark;

    final tTitle = _isEnglish ? 'Reset Password' : 'استعادة كلمة المرور';
    final tSubtitle = _isEnglish
        ? 'Enter your admin email to receive a reset link'
        : 'أدخل بريدك الإلكتروني كمسؤول لاستلام رابط الاستعادة';
    final tEmailLabel = _isEnglish ? 'Email address' : 'البريد الإلكتروني';
    final tEmailErr = _isEnglish ? 'Invalid email' : 'بريد غير صالح';
    final tEmailEmpty = _isEnglish ? 'Please enter email' : 'يرجى إدخال البريد';
    final tSubmit = _isEnglish ? 'Send Reset Link' : 'إرسال رابط الاستعادة';
    final tBack = _isEnglish ? 'Back to Sign In' : 'العودة لتسجيل الدخول';

    return Title(
      title: 'Password Recovery - أكلة النهاردة',
      color: p.claySolid,
      child: Scaffold(
        backgroundColor: p.canvas,
        body: Directionality(
          textDirection: _isEnglish ? TextDirection.ltr : TextDirection.rtl,
          child: Stack(
            children: [
              // Settings Gear (Interactive)
              Positioned(top: 18, right: 18, child: _settingsMenu(p, isDark)),

              // Back Button (Top Left)
              Positioned(
                top: 18,
                left: 18,
                child: AdminIconChip(
                  tooltip: _isEnglish
                      ? 'Back to Sign In'
                      : 'العودة لتسجيل الدخول',
                  // No directional arrow glyph in AdminIcons.
                  icon: _isEnglish ? AdminIcons.back : AdminIcons.forward,
                  onTap: () => context.pop(),
                ),
              ),

              Center(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.all(24),
                  child: Container(
                    constraints: const BoxConstraints(maxWidth: 455),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 30,
                      vertical: 32,
                    ),
                    decoration: p.panel(radius: AdminRadii.lg, shadow: true),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        // Lock Icon
                        Center(
                          child: Container(
                            width: 64,
                            height: 64,
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(
                                AdminRadii.xl,
                              ),
                              gradient: p.brandGradient,
                            ),
                            child: Center(
                              child: Icon(
                                AdminIcons.lock,
                                color: p.onSolid(p.brandGradient.colors.first),
                                size: 32,
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(height: 20),

                        // Title
                        Text(
                          tTitle,
                          textAlign: TextAlign.center,
                          style: _ui(
                            size: 20,
                            weight: FontWeight.w600,
                            color: p.ink,
                            height: 1.25,
                          ),
                        ),
                        const SizedBox(height: 7),
                        Text(
                          tSubtitle,
                          textAlign: TextAlign.center,
                          style: _ui(size: 13, color: p.inkMuted, height: 1.5),
                        ),
                        const SizedBox(height: 26),

                        if (_errorMessage != null) ...[
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 13,
                              vertical: 12,
                            ),
                            decoration: BoxDecoration(
                              color: p.chiliSoft,
                              borderRadius: BorderRadius.circular(
                                AdminRadii.md,
                              ),
                              border: Border.all(
                                color: p.chiliSolid.withValues(alpha: 0.32),
                              ),
                            ),
                            child: Text(
                              _errorMessage!,
                              style: _ui(
                                size: 12.5,
                                weight: FontWeight.w600,
                                color: p.chiliInk,
                                height: 1.6,
                              ),
                              textAlign: TextAlign.center,
                            ),
                          ),
                          const SizedBox(height: 16),
                        ],

                        if (_successMessage != null) ...[
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 13,
                              vertical: 12,
                            ),
                            decoration: BoxDecoration(
                              color: p.oliveSoft,
                              borderRadius: BorderRadius.circular(
                                AdminRadii.md,
                              ),
                              border: Border.all(
                                color: p.oliveSolid.withValues(alpha: 0.32),
                              ),
                            ),
                            child: Text(
                              _successMessage!,
                              style: _ui(
                                size: 12.5,
                                weight: FontWeight.w600,
                                color: p.oliveInk,
                                height: 1.6,
                              ),
                              textAlign: TextAlign.center,
                            ),
                          ),
                          const SizedBox(height: 16),
                        ],

                        Form(
                          key: _formKey,
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              // Email Field
                              TextFormField(
                                controller: _emailController,
                                keyboardType: TextInputType.emailAddress,
                                textAlign: TextAlign.left,
                                textDirection: TextDirection.ltr,
                                style: adminLatinText(size: 13.5, color: p.ink),
                                decoration: adminFieldDeco(
                                  p,
                                  label: tEmailLabel,
                                  icon: AdminIcons.email,
                                ),
                                validator: (v) {
                                  if (v == null || v.trim().isEmpty) {
                                    return tEmailEmpty;
                                  }
                                  if (!v.contains('@')) return tEmailErr;
                                  return null;
                                },
                              ),
                              const SizedBox(height: 18),

                              // Submit Button
                              FilledButton(
                                onPressed: _isLoading ? null : _submit,
                                style: FilledButton.styleFrom(
                                  backgroundColor: p.claySolid,
                                  foregroundColor: p.onClay,
                                  elevation: 0,
                                  padding: const EdgeInsets.symmetric(
                                    vertical: 15,
                                  ),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(
                                      AdminRadii.sm,
                                    ),
                                  ),
                                ),
                                child: _isLoading
                                    ? SizedBox(
                                        width: 20,
                                        height: 20,
                                        child: CircularProgressIndicator(
                                          strokeWidth: 2,
                                          color: p.onClay,
                                        ),
                                      )
                                    : Text(
                                        tSubmit,
                                        style: _ui(
                                          size: 13.5,
                                          weight: FontWeight.w600,
                                          color: p.onClay,
                                        ),
                                      ),
                              ),

                              const SizedBox(height: 10),

                              // Back to Login Button
                              TextButton(
                                onPressed: () => context.pop(),
                                style: TextButton.styleFrom(
                                  foregroundColor: p.inkMuted,
                                  padding: const EdgeInsets.symmetric(
                                    vertical: 12,
                                  ),
                                ),
                                child: Text(
                                  tBack,
                                  style: _ui(
                                    size: 13,
                                    weight: FontWeight.w600,
                                    color: p.inkMuted,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
