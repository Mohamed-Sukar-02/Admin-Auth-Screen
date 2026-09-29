import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../core/database/app_database.dart';
import '../../settings/providers/settings_providers.dart';
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
      setState(() => _errorMessage = isRateLimited
          ? (_isEnglish
              ? 'Too many attempts. Try again later.'
              : 'محاولات كثيرة جداً. حاول لاحقاً.')
          : isOffline
              ? (_isEnglish
                  ? 'Network error. Check your connection.'
                  : 'خطأ في الاتصال. تحقق من الإنترنت.')
              : (_isEnglish
                  ? 'An error occurred. Please try again.'
                  : 'حدث خطأ. يرجى المحاولة مرة أخرى.'));
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
    const primaryColor = Color(0xFF635BFF);
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bgColor = isDark ? const Color(0xFF0E1120) : const Color(0xFFF5F7FC);
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
    final successBg = isDark ? const Color(0xFF14472F) : Colors.green.shade50;
    final successText = isDark ? const Color(0xFF5DEB98) : Colors.green.shade900;

    final tTitle = _isEnglish ? 'Reset Password' : 'استعادة كلمة المرور';
    final tSubtitle = _isEnglish
        ? 'Enter your admin email to receive a reset link'
        : 'أدخل بريدك الإلكتروني كمسؤول لاستلام رابط الاستعادة';
    final tEmailLabel = _isEnglish ? 'Email address' : 'البريد الإلكتروني';
    final tEmailErr = _isEnglish ? 'Invalid email' : 'بريد غير صالح';
    final tEmailEmpty = _isEnglish ? 'Please enter email' : 'يرجى إدخال البريد';
    final tSubmit = _isEnglish ? 'Send Reset Link' : 'إرسال رابط الاستعادة';
    final tBack = _isEnglish ? 'Back to Sign In' : 'العودة لتسجيل الدخول';
    
    final tLangMenu = _isEnglish ? 'العربية' : 'English';
    final tThemeMenu = isDark
        ? (_isEnglish ? 'Light mode' : 'الوضع الفاتح')
        : (_isEnglish ? 'Dark mode' : 'الوضع الداكن');

    return Title(
      title: 'Password Recovery - أكلة النهاردة',
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

            // Back Button (Top Left)
            Positioned(
              top: 18,
              left: 18,
              child: InkWell(
                onTap: () => context.pop(),
                borderRadius: BorderRadius.circular(12),
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
                  child: Icon(
                    _isEnglish
                        ? Icons.arrow_back_ios_new_rounded
                        : Icons.arrow_forward_ios_rounded,
                    color: mutedColor,
                    size: 18,
                  ),
                ),
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
                      // Lock Icon
                      Center(
                        child: Container(
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
                              Icons.lock_reset_rounded,
                              color: Colors.white,
                              size: 32,
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

                      if (_successMessage != null) ...[
                        Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: successBg,
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Text(
                            _successMessage!,
                            style: GoogleFonts.cairo(
                              fontSize: 13,
                              fontWeight: FontWeight.bold,
                              color: successText,
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
                            const SizedBox(height: 24),

                            // Submit Button
                            ElevatedButton(
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
                            
                            const SizedBox(height: 16),
                            
                            // Back to Login Button
                            TextButton(
                              onPressed: () => context.pop(),
                              style: TextButton.styleFrom(
                                foregroundColor: mutedColor,
                                padding: const EdgeInsets.symmetric(vertical: 12),
                              ),
                              child: Text(
                                tBack,
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
