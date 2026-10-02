import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/database/app_database.dart';
import '../../settings/providers/settings_providers.dart';
import '../data/admin_auth_service.dart';
import 'theme/admin_palette.dart';
import 'widgets/admin_dialog.dart';
import 'widgets/admin_toast.dart';

class AdminAuthScreen extends ConsumerStatefulWidget {
  final String? initialErrorMessage;

  const AdminAuthScreen({super.key, this.initialErrorMessage});

  @override
  ConsumerState<AdminAuthScreen> createState() => _AdminAuthScreenState();
}

class _AdminAuthScreenState extends ConsumerState<AdminAuthScreen> {
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();

  final _formKey = GlobalKey<FormState>();

  bool _isLoading = false;
  String? _errorMessage;
  bool _obscurePassword = true;

  // Settings Gear
  bool _isEnglish = false;

  @override
  void initState() {
    super.initState();
    _errorMessage = widget.initialErrorMessage;
  }

  @override
  void didUpdateWidget(covariant AdminAuthScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.initialErrorMessage != null &&
        widget.initialErrorMessage != oldWidget.initialErrorMessage) {
      setState(() {
        _errorMessage = widget.initialErrorMessage;
      });
    }
  }

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
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

  String _sanitizeError(dynamic e) {
    final msg = e.toString().toLowerCase();
    if (e is AdminUnauthorizedException) return e.message;
    if (msg.contains('user-not-found') ||
        msg.contains('wrong-password') ||
        msg.contains('invalid-credential')) {
      return _isEnglish
          ? 'Incorrect email or password.'
          : 'البريد الإلكتروني أو كلمة المرور غير صحيحة.';
    }
    if (msg.contains('too-many-requests')) {
      return _isEnglish
          ? 'Too many attempts. Try again later.'
          : 'محاولات كثيرة جداً. حاول لاحقاً.';
    }
    if (msg.contains('network')) {
      return _isEnglish
          ? 'Network error. Check your connection.'
          : 'خطأ في الاتصال. تحقق من الإنترنت.';
    }
    return _isEnglish
        ? 'Sign in failed. Please try again.'
        : 'فشل تسجيل الدخول. يرجى المحاولة مرة أخرى.';
  }

  /// Sign-in problems belong to the form, so they show in place (the warm-clay
  /// banner above the fields) instead of in the dashboard's toast stack.
  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });
    try {
      final auth = ref.read(adminAuthProvider);
      await auth.signInWithEmail(
        _emailController.text,
        _passwordController.text,
      );
    } catch (e) {
      setState(() => _errorMessage = _sanitizeError(e));
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _signInWithGoogle() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });
    try {
      final auth = ref.read(adminAuthProvider);
      await auth.signInWithGoogle();
    } catch (e) {
      setState(() => _errorMessage = _sanitizeError(e));
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

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

    final tTitle = _isEnglish ? 'Sign In' : 'تسجيل الدخول';
    final tSubtitle = _isEnglish
        ? 'Enter your details to continue to your account'
        : 'أدخل بياناتك للمتابعة إلى حسابك';

    final tEmailLabel = _isEnglish ? 'Email address' : 'البريد الإلكتروني';
    final tPasswordLabel = _isEnglish ? 'Password' : 'كلمة المرور';
    final tForgot = _isEnglish ? 'Forgot your password?' : 'نسيت كلمة المرور؟';
    final tSubmit = _isEnglish ? 'Sign In' : 'تسجيل الدخول';
    final tDivider = _isEnglish ? 'Or continue with' : 'أو تابع باستخدام';
    final tGoogle = _isEnglish
        ? 'Sign in with Google'
        : 'تسجيل الدخول باستخدام Google';
    final tEmailErr = _isEnglish ? 'Invalid email' : 'بريد غير صالح';
    final tEmailEmpty = _isEnglish ? 'Please enter email' : 'يرجى إدخال البريد';
    final tPassErr = _isEnglish
        ? 'Minimum 6 characters'
        : 'يجب أن لا تقل عن 6 أحرف';

    return Title(
      title: 'Admin Login - أكلة النهاردة',
      color: p.claySolid,
      child: Scaffold(
        backgroundColor: p.canvas,
        body: Directionality(
          textDirection: _isEnglish ? TextDirection.ltr : TextDirection.rtl,
          child: Stack(
            children: [
              // Settings Gear (Interactive)
              Positioned(top: 18, right: 18, child: _settingsMenu(p, isDark)),

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
                        // Logo / Icon
                        Center(
                          child: ClipRRect(
                            borderRadius: BorderRadius.circular(AdminRadii.xl),
                            child: Image.asset(
                              'assets/icon.png',
                              width: 64,
                              height: 64,
                              fit: BoxFit.cover,
                              errorBuilder: (context, error, stackTrace) =>
                                  Container(
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
                                        AdminIcons.meal,
                                        color: p.onSolid(
                                          p.brandGradient.colors.first,
                                        ),
                                        size: 28,
                                      ),
                                    ),
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
                            key: const Key('admin_auth_error_container'),
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

                        Form(
                          key: _formKey,
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              // Email Field
                              TextFormField(
                                key: const Key('admin_email_field'),
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
                              const SizedBox(height: 16),

                              // Password Field
                              TextFormField(
                                key: const Key('admin_password_field'),
                                controller: _passwordController,
                                obscureText: _obscurePassword,
                                textAlign: TextAlign.left,
                                textDirection: TextDirection.ltr,
                                style: adminLatinText(size: 13.5, color: p.ink),
                                decoration: adminFieldDeco(
                                  p,
                                  label: tPasswordLabel,
                                  icon: AdminIcons.password,
                                  suffixIcon: IconButton(
                                    key: const Key('admin_toggle_password'),
                                    tooltip: _obscurePassword
                                        ? 'إظهار كلمة المرور'
                                        : 'إخفاء كلمة المرور',
                                    onPressed: () => setState(
                                      () =>
                                          _obscurePassword = !_obscurePassword,
                                    ),
                                    icon: Icon(
                                      _obscurePassword
                                          ? AdminIcons.visibility
                                          : AdminIcons.visibilityOff,
                                      size: 19,
                                      color: p.inkFaint,
                                    ),
                                  ),
                                ),
                                validator: (v) {
                                  if (v == null || v.length < 6) {
                                    return tPassErr;
                                  }
                                  return null;
                                },
                              ),

                              const SizedBox(height: 4),
                              Align(
                                alignment: _isEnglish
                                    ? Alignment.centerRight
                                    : Alignment.centerLeft,
                                child: TextButton(
                                  onPressed: () {
                                    context.push(
                                      '/admin/forgot-password',
                                      extra: _emailController.text.trim(),
                                    );
                                  },
                                  style: TextButton.styleFrom(
                                    foregroundColor: p.clay,
                                    padding: EdgeInsets.zero,
                                    minimumSize: const Size(0, 0),
                                    tapTargetSize:
                                        MaterialTapTargetSize.shrinkWrap,
                                  ),
                                  child: Text(
                                    tForgot,
                                    style: _ui(
                                      size: 12,
                                      weight: FontWeight.w600,
                                      color: p.clay,
                                    ),
                                  ),
                                ),
                              ),
                              const SizedBox(height: 16),

                              // Submit Button
                              FilledButton(
                                key: const Key('admin_auth_submit_button'),
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

                              const SizedBox(height: 22),
                              Row(
                                children: [
                                  Expanded(
                                    child: Divider(
                                      color: p.border,
                                      thickness: 1,
                                    ),
                                  ),
                                  Padding(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 12,
                                    ),
                                    child: Text(
                                      tDivider,
                                      style: _ui(size: 11.5, color: p.inkFaint),
                                    ),
                                  ),
                                  Expanded(
                                    child: Divider(
                                      color: p.border,
                                      thickness: 1,
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 18),

                              OutlinedButton.icon(
                                key: const Key('admin_google_signin_button'),
                                onPressed: _isLoading
                                    ? null
                                    : _signInWithGoogle,
                                style: OutlinedButton.styleFrom(
                                  backgroundColor: p.surface,
                                  foregroundColor: p.ink,
                                  padding: const EdgeInsets.symmetric(
                                    vertical: 14,
                                  ),
                                  side: BorderSide(color: p.borderStrong),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(
                                      AdminRadii.sm,
                                    ),
                                  ),
                                ),
                                icon: Image.asset(
                                  'assets/icons/google_g.png',
                                  width: 19,
                                  height: 19,
                                ),
                                label: Text(
                                  tGoogle,
                                  style: _ui(size: 13, weight: FontWeight.w600),
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
