import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../core/database/app_database.dart';
import '../../settings/providers/settings_providers.dart';
import '../data/admin_auth_service.dart';
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

  String _sanitizeError(dynamic e) {
    final msg = e.toString().toLowerCase();
    if (e is AdminUnauthorizedException) return e.message;
    if (msg.contains('user-not-found') || msg.contains('wrong-password') || msg.contains('invalid-credential')) {
      return _isEnglish ? 'Incorrect email or password.' : 'البريد الإلكتروني أو كلمة المرور غير صحيحة.';
    }
    if (msg.contains('too-many-requests')) {
      return _isEnglish ? 'Too many attempts. Try again later.' : 'محاولات كثيرة جداً. حاول لاحقاً.';
    }
    if (msg.contains('network')) {
      return _isEnglish ? 'Network error. Check your connection.' : 'خطأ في الاتصال. تحقق من الإنترنت.';
    }
    return _isEnglish ? 'Sign in failed. Please try again.' : 'فشل تسجيل الدخول. يرجى المحاولة مرة أخرى.';
  }

  /// Sign-in problems belong to the form, so they show in place (the red
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
      await ref
          .read(settingsControllerProvider.notifier)
          .updateThemeMode(mode);
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

  @override
  Widget build(BuildContext context) {
    // Dynamic Colors based on the active theme brightness
    const primaryColor = Color(0xFF635BFF);
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bgColor =
        isDark ? const Color(0xFF0E1120) : const Color(0xFFF5F7FC);
    final cardBg = isDark ? const Color(0xFF171B30) : Colors.white;
    final textColor = isDark ? const Color(0xFFEEF0F8) : const Color(0xFF172033);
    final mutedColor =
        isDark ? const Color(0xFF98A0BA) : const Color(0xFF788199);
    final lineColor =
        isDark ? const Color(0xFF2B3050) : const Color(0xFFE2E6EF);
    final inputBg = isDark ? const Color(0xFF171B30) : Colors.white;
    final shadowColor = isDark
        ? Colors.black.withValues(alpha: 0.45)
        : const Color.fromRGBO(42, 48, 87, 0.13);
    final errorBg = isDark ? const Color(0xFF4A1919) : Colors.red.shade50;
    final errorText = isDark ? const Color(0xFFFF6B6B) : Colors.red.shade900;

    final tTitle = _isEnglish ? 'Sign In' : 'تسجيل الدخول';
    final tSubtitle = _isEnglish
        ? 'Enter your details to continue to your account'
        : 'أدخل بياناتك للمتابعة إلى حسابك';

    final tEmailLabel = _isEnglish ? 'Email address' : 'البريد الإلكتروني';
    final tPasswordLabel = _isEnglish ? 'Password' : 'كلمة المرور';
    final tForgot = _isEnglish ? 'Forgot your password?' : 'نسيت كلمة المرور؟';
    final tSubmit = _isEnglish ? 'Sign In' : 'تسجيل الدخول';
    final tDivider = _isEnglish ? 'Or continue with' : 'أو تابع باستخدام';
    final tGoogle =
        _isEnglish ? 'Sign in with Google' : 'تسجيل الدخول باستخدام Google';
    final tLangMenu = _isEnglish ? 'العربية' : 'English';
    final tThemeMenu = isDark
        ? (_isEnglish ? 'Light mode' : 'الوضع الفاتح')
        : (_isEnglish ? 'Dark mode' : 'الوضع الداكن');
    final tEmailErr = _isEnglish ? 'Invalid email' : 'بريد غير صالح';
    final tEmailEmpty = _isEnglish ? 'Please enter email' : 'يرجى إدخال البريد';
    final tPassErr =
        _isEnglish ? 'Minimum 6 characters' : 'يجب أن لا تقل عن 6 أحرف';

    return Title(
      title: 'Admin Login - أكلة النهاردة',
      color: primaryColor,
      child: Scaffold(
        backgroundColor: bgColor,
      body: Directionality(
        textDirection: _isEnglish ? TextDirection.ltr : TextDirection.rtl,
        child: Stack(
          children: [
            // Background blobs
            Positioned(
              top: -100,
              left: -100,
              child: Container(
                width: 350,
                height: 350,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: primaryColor.withValues(alpha: 0.14),
                ),
              ),
            ),
            Positioned(
              bottom: -100,
              right: -100,
              child: Container(
                width: 450,
                height: 450,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: const Color(0xFF21BEB5).withValues(alpha: 0.12),
                ),
              ),
            ),

            // Settings Gear (Interactive)
            Positioned(
              top: 18,
              right: 18,
              child: PopupMenuButton<String>(
                onSelected: (value) {
                  if (value == 'lang') {
                    setState(() => _isEnglish = !_isEnglish);
                  } else if (value == 'theme') {
                    _setThemeMode(
                      isDark
                          ? AppThemeModePreference.light
                          : AppThemeModePreference.dark,
                    );
                  }
                },
                offset: const Offset(0, 50),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14)),
                color: cardBg,
                elevation: 8,
                child: Container(
                  width: 42,
                  height: 42,
                  decoration: BoxDecoration(
                    color: cardBg,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: lineColor),
                    boxShadow: [
                      BoxShadow(
                        color: shadowColor,
                        blurRadius: 16,
                        offset: const Offset(0, 6),
                      ),
                    ],
                  ),
                  child: Icon(Icons.settings_outlined,
                      color: mutedColor, size: 20),
                ),
                itemBuilder: (context) => [
                  PopupMenuItem(
                    value: 'lang',
                    child: Row(
                      children: [
                        Icon(Icons.language_rounded,
                            size: 18, color: textColor),
                        const SizedBox(width: 10),
                        Text(
                          tLangMenu,
                          style: GoogleFonts.cairo(
                            fontSize: 13.5,
                            fontWeight: FontWeight.bold,
                            color: textColor,
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
                          isDark
                              ? Icons.light_mode_outlined
                              : Icons.dark_mode_outlined,
                          size: 18,
                          color: textColor,
                        ),
                        const SizedBox(width: 10),
                        Text(
                          tThemeMenu,
                          style: GoogleFonts.cairo(
                            fontSize: 13.5,
                            fontWeight: FontWeight.bold,
                            color: textColor,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),

            Center(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(24),
                child: Container(
                  constraints: const BoxConstraints(maxWidth: 455),
                  padding:
                      const EdgeInsets.symmetric(horizontal: 40, vertical: 44),
                  decoration: BoxDecoration(
                    color: cardBg,
                    borderRadius: BorderRadius.circular(24),
                    border: Border.all(color: lineColor.withValues(alpha: 0.9)),
                    boxShadow: [
                      BoxShadow(
                        color: shadowColor,
                        blurRadius: 70,
                        offset: const Offset(0, 24),
                      ),
                    ],
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      // Logo / Icon
                      Center(
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(15),
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
                                borderRadius: BorderRadius.circular(15),
                                gradient: const LinearGradient(
                                  begin: Alignment.topLeft,
                                  end: Alignment.bottomRight,
                                  colors: [
                                    Color(0xFF716AFF),
                                    Color(0xFF5149D9)
                                  ],
                                ),
                              ),
                              child: const Center(
                                child: Icon(
                                  Icons.restaurant_menu,
                                  color: Colors.white,
                                  size: 28,
                                ),
                              ),
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: 22),

                      // Title
                      Text(
                        tTitle,
                        textAlign: TextAlign.center,
                        style: GoogleFonts.cairo(
                          fontSize: 26,
                          fontWeight: FontWeight.bold,
                          color: textColor,
                          height: 1.2,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        tSubtitle,
                        textAlign: TextAlign.center,
                        style: GoogleFonts.cairo(
                          fontSize: 14,
                          color: mutedColor,
                        ),
                      ),
                      const SizedBox(height: 28),

                      if (_errorMessage != null) ...[
                        Container(
                          key: const Key('admin_auth_error_container'),
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: errorBg,
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Text(
                            _errorMessage!,
                            style: GoogleFonts.cairo(
                              fontSize: 13,
                              color: errorText,
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
                              style: GoogleFonts.cairo(
                                  fontSize: 14, color: textColor),
                              decoration: InputDecoration(
                                labelText: tEmailLabel,
                                labelStyle: GoogleFonts.cairo(
                                    fontSize: 14, color: mutedColor),
                                floatingLabelStyle: GoogleFonts.cairo(
                                  fontSize: 14,
                                  fontWeight: FontWeight.bold,
                                  color: primaryColor,
                                ),
                                prefixIcon: const Icon(Icons.email_outlined,
                                    color: Color(0xFF9AA2B5), size: 20),
                                contentPadding: const EdgeInsets.symmetric(
                                    horizontal: 17, vertical: 18),
                                filled: true,
                                fillColor: inputBg,
                                enabledBorder: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(13),
                                  borderSide: BorderSide(color: lineColor),
                                ),
                                focusedBorder: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(13),
                                  borderSide: const BorderSide(
                                      color: primaryColor, width: 1.5),
                                ),
                                errorBorder: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(13),
                                  borderSide:
                                      const BorderSide(color: Colors.red),
                                ),
                                focusedErrorBorder: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(13),
                                  borderSide: const BorderSide(
                                      color: Colors.red, width: 1.5),
                                ),
                              ),
                              validator: (v) {
                                if (v == null || v.trim().isEmpty) {
                                  return tEmailEmpty;
                                }
                                if (!v.contains('@')) return tEmailErr;
                                return null;
                              },
                            ),
                            const SizedBox(height: 26),

                            // Password Field
                            TextFormField(
                              key: const Key('admin_password_field'),
                              controller: _passwordController,
                              obscureText: _obscurePassword,
                              textAlign: TextAlign.left,
                              textDirection: TextDirection.ltr,
                              style: GoogleFonts.cairo(
                                fontSize: _obscurePassword ? 20 : 14,
                                color: textColor,
                                letterSpacing: _obscurePassword ? 2 : 0,
                              ),
                              decoration: InputDecoration(
                                labelText: tPasswordLabel,
                                labelStyle: GoogleFonts.cairo(
                                    fontSize: 14, color: mutedColor),
                                floatingLabelStyle: GoogleFonts.cairo(
                                  fontSize: 14,
                                  fontWeight: FontWeight.bold,
                                  color: primaryColor,
                                ),
                                prefixIcon: const Icon(Icons.lock_outline,
                                    color: Color(0xFF9AA2B5), size: 20),
                                suffixIcon: GestureDetector(
                                  key: const Key('admin_toggle_password'),
                                  onTap: () => setState(() =>
                                      _obscurePassword = !_obscurePassword),
                                  child: Container(
                                    width: 48,
                                    height: 48,
                                    alignment: Alignment.center,
                                    child: Text(
                                      _obscurePassword ? '🙈' : '👁',
                                      style: const TextStyle(fontSize: 18),
                                    ),
                                  ),
                                ),
                                contentPadding: const EdgeInsets.symmetric(
                                    horizontal: 17, vertical: 18),
                                filled: true,
                                fillColor: inputBg,
                                enabledBorder: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(13),
                                  borderSide: BorderSide(color: lineColor),
                                ),
                                focusedBorder: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(13),
                                  borderSide: const BorderSide(
                                      color: primaryColor, width: 1.5),
                                ),
                                errorBorder: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(13),
                                  borderSide:
                                      const BorderSide(color: Colors.red),
                                ),
                                focusedErrorBorder: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(13),
                                  borderSide: const BorderSide(
                                      color: Colors.red, width: 1.5),
                                ),
                              ),
                              validator: (v) {
                                if (v == null || v.length < 6) return tPassErr;
                                return null;
                              },
                            ),

                            const SizedBox(height: 8),
                            Align(
                              alignment: _isEnglish
                                  ? Alignment.centerRight
                                  : Alignment.centerLeft,
                              child: TextButton(
                                onPressed: () {
                                  context.push('/admin/forgot-password', extra: _emailController.text.trim());
                                },
                                style: TextButton.styleFrom(
                                  padding: EdgeInsets.zero,
                                  minimumSize: const Size(0, 0),
                                  tapTargetSize:
                                      MaterialTapTargetSize.shrinkWrap,
                                ),
                                child: Text(
                                  tForgot,
                                  style: GoogleFonts.cairo(
                                    fontSize: 12,
                                    fontWeight: FontWeight.bold,
                                    color: primaryColor,
                                  ),
                                ),
                              ),
                            ),
                            const SizedBox(height: 20),

                            // Submit Button
                            ElevatedButton(
                              key: const Key('admin_auth_submit_button'),
                              onPressed: _isLoading ? null : _submit,
                              style: ElevatedButton.styleFrom(
                                backgroundColor: primaryColor,
                                foregroundColor: Colors.white,
                                elevation: 0,
                                padding:
                                    const EdgeInsets.symmetric(vertical: 16),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                shadowColor: primaryColor.withValues(alpha: 0.4),
                              ).copyWith(
                                elevation:
                                    WidgetStateProperty.resolveWith((states) {
                                  if (states.contains(WidgetState.hovered)) {
                                    return 6;
                                  }
                                  return 2;
                                }),
                              ),
                              child: _isLoading
                                  ? const SizedBox(
                                      width: 20,
                                      height: 20,
                                      child: CircularProgressIndicator(
                                          strokeWidth: 2, color: Colors.white),
                                    )
                                  : Text(
                                      tSubmit,
                                      style: GoogleFonts.cairo(
                                        fontSize: 14,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                            ),

                            const SizedBox(height: 24),
                            Row(
                              children: [
                                Expanded(child: Divider(color: lineColor)),
                                Padding(
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 13),
                                  child: Text(
                                    tDivider,
                                    style: GoogleFonts.cairo(
                                      color: const Color(0xFFA0A7B8),
                                      fontSize: 12,
                                    ),
                                  ),
                                ),
                                Expanded(child: Divider(color: lineColor)),
                              ],
                            ),
                            const SizedBox(height: 19),

                            OutlinedButton.icon(
                              key: const Key('admin_google_signin_button'),
                              onPressed: _isLoading ? null : _signInWithGoogle,
                              style: OutlinedButton.styleFrom(
                                backgroundColor: cardBg,
                                foregroundColor: textColor,
                                padding:
                                    const EdgeInsets.symmetric(vertical: 16),
                                side: BorderSide(color: lineColor),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(12),
                                ),
                              ),
                              icon: Image.network(
                                'https://upload.wikimedia.org/wikipedia/commons/c/c1/Google_%22G%22_logo.svg',
                                width: 19,
                                height: 19,
                                errorBuilder: (context, error, stackTrace) =>
                                    const Icon(Icons.g_mobiledata_rounded,
                                        color: Colors.blue),
                              ),
                              label: Text(
                                tGoogle,
                                style: GoogleFonts.cairo(
                                  fontSize: 14,
                                  fontWeight: FontWeight.bold,
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
    ));
  }
}
