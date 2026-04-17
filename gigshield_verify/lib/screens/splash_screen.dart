import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../theme/design_system.dart';
import '../services/auth_service.dart';

/// Checks stored JWT on launch and routes accordingly.
class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> {
  @override
  void initState() {
    super.initState();
    _init();
  }

  Future<void> _init() async {
    await Future.delayed(const Duration(milliseconds: 600)); // logo moment
    final auth = AuthService();
    final restored = await auth.tryRestoreSession();
    if (!mounted) return;
    if (!restored) {
      context.go('/login');
      return;
    }
    final verified = await auth.isVerified();
    if (!mounted) return;
    context.go(verified ? '/home' : '/verify');
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: GsColors.primary,
      body: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 100,
              height: 100,
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: GsShapes.lg,
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.05),
                    blurRadius: 20,
                    offset: const Offset(0, 10),
                  ),
                ],
              ),
              child: Image.asset('assets/images/logo.png'),
            ),
            const SizedBox(height: GsSpacing.md),
            Text(
              'GigShield',
              style: GsTypography.heading.copyWith(
                color: Colors.white,
                fontSize: 28,
              ),
            ),
            const SizedBox(height: GsSpacing.xs),
            Text(
              'Protecting India\'s Gig Workers',
              style: GsTypography.caption.copyWith(color: Colors.white60),
            ),
            const SizedBox(height: GsSpacing.xxl),
            const SizedBox(
              width: 24,
              height: 24,
              child: CircularProgressIndicator(
                strokeWidth: 2,
                color: Colors.white54,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
