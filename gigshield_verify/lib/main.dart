import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'theme/design_system.dart';
import 'screens/splash_screen.dart';
import 'screens/auth/login_screen.dart';
import 'screens/auth/register_screen.dart';
import 'screens/verification_screen.dart';
import 'screens/home/dashboard_screen.dart';
import 'screens/home/policies_screen.dart';
import 'screens/home/pricing_screen.dart';
import 'screens/home/claims_screen.dart';
import 'screens/home/payouts_screen.dart';
import 'widgets/app_shell.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  SystemChrome.setSystemUIOverlayStyle(
    const SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      statusBarIconBrightness: Brightness.dark,
      systemNavigationBarColor: GsColors.surface,
      systemNavigationBarIconBrightness: Brightness.dark,
    ),
  );
  runApp(const GigShieldVerifyApp());
}

// ── Router ───────────────────────────────────────────────────────────────────

final _router = GoRouter(
  initialLocation: '/',
  routes: [
    GoRoute(path: '/', builder: (_, __) => const SplashScreen()),
    GoRoute(path: '/login', builder: (_, __) => const LoginScreen()),
    GoRoute(path: '/register', builder: (_, __) => const RegisterScreen()),
    GoRoute(path: '/verify', builder: (_, __) => const VerificationScreen()),

    // ── Main app shell with bottom nav ─────────────────────────────────────
    ShellRoute(
      builder: (_, __, child) => AppShell(child: child),
      routes: [
        GoRoute(path: '/home', builder: (_, __) => const DashboardScreen()),
        GoRoute(path: '/home/policies', builder: (_, __) => const PoliciesScreen()),
        GoRoute(path: '/home/pricing', builder: (_, __) => const PricingScreen()),
        GoRoute(path: '/home/claims', builder: (_, __) => const ClaimsScreen()),
        GoRoute(path: '/home/payouts', builder: (_, __) => const PayoutsScreen()),
      ],
    ),
  ],
);

// ── App ──────────────────────────────────────────────────────────────────────

class GigShieldVerifyApp extends StatelessWidget {
  const GigShieldVerifyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp.router(
      title: 'GigShield',
      debugShowCheckedModeBanner: false,
      routerConfig: _router,
      theme: ThemeData(
        useMaterial3: true,
        scaffoldBackgroundColor: GsColors.surface,
        colorScheme: ColorScheme.fromSeed(
          seedColor: GsColors.primary,
          surface: GsColors.surface,
        ),
        textTheme: GoogleFonts.interTextTheme(),
        appBarTheme: AppBarTheme(
          elevation: 0,
          scrolledUnderElevation: 0,
          backgroundColor: Colors.transparent,
          foregroundColor: GsColors.textPrimary,
          titleTextStyle: GsTypography.subheading,
        ),
      ),
    );
  }
}
