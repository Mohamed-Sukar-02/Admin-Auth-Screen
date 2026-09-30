import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'firebase_options.dart';
import 'core/router/app_router.dart';
import 'core/theme/app_theme.dart';
import 'features/settings/providers/settings_providers.dart';
import 'core/services/notification_service.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  try {
    await Firebase.initializeApp(
      options: DefaultFirebaseOptions.currentPlatform,
    );
    if (kIsWeb) {
      await FirebaseAuth.instance.setPersistence(Persistence.SESSION);
    }
  } catch (e) {
    debugPrint('Firebase initialization warning: $e');
  }
  await NotificationService.instance.init();
  runApp(const ProviderScope(child: DailyMealApp()));
}

class DailyMealApp extends ConsumerWidget {
  const DailyMealApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final themeMode = ref.watch(themeModeProvider);
    final router = ref.watch(appRouterProvider);
    final locale = ref.watch(localeProvider);

    return MaterialApp.router(
      title: 'أكلة النهاردة',
      debugShowCheckedModeBanner: false,
      themeMode: themeMode,
      theme: AppTheme.lightTheme,
      darkTheme: AppTheme.darkTheme,
      routerConfig: router,
      locale: locale,
      supportedLocales: const [Locale('ar'), Locale('en')],
      localizationsDelegates: const [
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      builder: (context, child) {
        final brightness = Theme.of(context).brightness;
        return Directionality(
          textDirection: locale.languageCode == 'ar'
              ? TextDirection.rtl
              : TextDirection.ltr,
          child: _ThemeFadeTransition(
            brightness: brightness,
            child: child ?? const SizedBox.shrink(),
          ),
        );
      },
    );
  }
}

/// Brief dim-and-brighten animation when the theme brightness changes.
/// Fades to 45% opacity and back to 100% over ~350ms — no state lost.
class _ThemeFadeTransition extends StatefulWidget {
  final Brightness brightness;
  final Widget child;

  const _ThemeFadeTransition({required this.brightness, required this.child});

  @override
  State<_ThemeFadeTransition> createState() => _ThemeFadeTransitionState();
}

class _ThemeFadeTransitionState extends State<_ThemeFadeTransition>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 180),
      value: 1.0,
    );
  }

  @override
  void didUpdateWidget(_ThemeFadeTransition old) {
    super.didUpdateWidget(old);
    if (old.brightness != widget.brightness) {
      _ctrl
          .animateTo(0.42, curve: Curves.easeIn)
          .then((_) => _ctrl.animateTo(1.0, curve: Curves.easeOut));
    }
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _ctrl,
      builder: (_, child) => Opacity(opacity: _ctrl.value, child: child),
      child: widget.child,
    );
  }
}
