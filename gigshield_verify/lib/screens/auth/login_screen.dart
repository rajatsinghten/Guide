import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../theme/design_system.dart';
import '../../widgets/form_widgets.dart';
import '../../services/auth_service.dart';
import 'package:flutter/services.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _phoneCtrl = TextEditingController();
  final _otpCtrl = TextEditingController(text: '1234');
  bool _loading = false;
  String _error = '';

  @override
  void dispose() {
    _phoneCtrl.dispose();
    _otpCtrl.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (_phoneCtrl.text.trim().length < 10) {
      setState(() => _error = 'Enter a valid 10-digit phone number');
      return;
    }
    setState(() {
      _loading = true;
      _error = '';
    });
    try {
      await AuthService().login(
        phone: _phoneCtrl.text.trim(),
        otp: _otpCtrl.text.trim(),
      );
      if (!mounted) return;
      final verified = await AuthService().isVerified();
      if (!mounted) return;
      context.go(verified ? '/home' : '/verify');
    } catch (e) {
      setState(() => _error = e.toString().replaceFirst('Exception: ', ''));
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(GsSpacing.lg),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SizedBox(height: GsSpacing.xl),
              Container(
                width: 56,
                height: 56,
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: GsShapes.sm,
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.05),
                      blurRadius: 10,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: Image.asset('assets/images/logo.png'),
              ),
              const SizedBox(height: GsSpacing.lg),
              Text('Welcome back', style: GsTypography.heading),
              const SizedBox(height: GsSpacing.xs),
              Text('Sign in to your GigShield account', style: GsTypography.body),
              const SizedBox(height: GsSpacing.xl),
              GsField(
                label: 'Phone Number',
                controller: _phoneCtrl,
                hint: '9876543210',
                inputType: TextInputType.phone,
                formatters: [
                  FilteringTextInputFormatter.digitsOnly,
                  LengthLimitingTextInputFormatter(10),
                ],
              ),
              const SizedBox(height: GsSpacing.md),
              GsField(
                label: 'OTP',
                controller: _otpCtrl,
                hint: '1234',
                inputType: TextInputType.number,
                formatters: [
                  FilteringTextInputFormatter.digitsOnly,
                  LengthLimitingTextInputFormatter(6),
                ],
              ),
              const SizedBox(height: GsSpacing.xs),
              Text(
                'For testing, the OTP is always 1234',
                style: GsTypography.caption.copyWith(color: GsColors.accent),
              ),
              if (_error.isNotEmpty) ...[
                const SizedBox(height: GsSpacing.md),
                Container(
                  padding: const EdgeInsets.all(GsSpacing.md),
                  decoration: BoxDecoration(
                    color: GsColors.errorSoft,
                    borderRadius: GsShapes.sm,
                  ),
                  child: Text(_error,
                      style: GsTypography.caption.copyWith(color: GsColors.error)),
                ),
              ],
              const SizedBox(height: GsSpacing.xl),
              GsGradientButton(
                label: 'Sign In',
                gradient: GsColors.primaryGradient,
                isLoading: _loading,
                onPressed: _submit,
              ),
              const SizedBox(height: GsSpacing.lg),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text("Don't have an account? ", style: GsTypography.body),
                  GestureDetector(
                    onTap: () => context.go('/register'),
                    child: Text(
                      'Register',
                      style: GsTypography.body.copyWith(
                          color: GsColors.accent, fontWeight: FontWeight.w600),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
