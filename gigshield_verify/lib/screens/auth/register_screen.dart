import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import '../../theme/design_system.dart';
import '../../widgets/form_widgets.dart';
import '../../services/auth_service.dart';

class RegisterScreen extends StatefulWidget {
  const RegisterScreen({super.key});

  @override
  State<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends State<RegisterScreen> {
  final _nameCtrl = TextEditingController();
  final _phoneCtrl = TextEditingController();
  final _pincodeCtrl = TextEditingController();
  final _incomeCtrl = TextEditingController(text: '8000');
  bool _loading = false;
  String _error = '';

  String _city = 'Bangalore';
  String _platform = 'swiggy';
  String _vehicle = 'bike';

  @override
  void dispose() {
    _nameCtrl.dispose();
    _phoneCtrl.dispose();
    _pincodeCtrl.dispose();
    _incomeCtrl.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (_nameCtrl.text.trim().isEmpty) {
      setState(() => _error = 'Name is required');
      return;
    }
    if (_phoneCtrl.text.trim().length < 10) {
      setState(() => _error = 'Enter a valid 10-digit phone number');
      return;
    }
    setState(() { _loading = true; _error = ''; });
    try {
      await AuthService().register(
        name: _nameCtrl.text.trim(),
        phone: _phoneCtrl.text.trim(),
        city: _city,
        pincode: _pincodeCtrl.text.trim(),
        platform: _platform,
        avgWeeklyIncomeInr: double.tryParse(_incomeCtrl.text) ?? 8000,
        vehicleType: _vehicle,
      );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Account created! Login with OTP 1234',
              style: GsTypography.body.copyWith(color: Colors.white)),
          backgroundColor: GsColors.success,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: GsShapes.md),
          margin: const EdgeInsets.all(GsSpacing.md),
        ),
      );
      context.go('/login');
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
              const SizedBox(height: GsSpacing.lg),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  GestureDetector(
                    onTap: () => context.go('/login'),
                    child: Container(
                      padding: const EdgeInsets.all(GsSpacing.sm),
                      decoration: BoxDecoration(
                        color: GsColors.card,
                        borderRadius: GsShapes.sm,
                        boxShadow: GsShadows.subtle,
                      ),
                      child: const Icon(Icons.arrow_back_rounded, color: GsColors.textPrimary, size: 20),
                    ),
                  ),
                  Container(
                    width: 40,
                    height: 40,
                    padding: const EdgeInsets.all(4),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: GsShapes.sm,
                    ),
                    child: Image.asset('assets/images/logo.png'),
                  ),
                ],
              ),
              const SizedBox(height: GsSpacing.lg),
              Text('Create account', style: GsTypography.heading),
              const SizedBox(height: GsSpacing.xs),
              Text('Register as a GigShield delivery worker', style: GsTypography.body),
              const SizedBox(height: GsSpacing.xl),

              GsField(label: 'Full Name', controller: _nameCtrl, hint: 'Arjun Rawat'),
              const SizedBox(height: GsSpacing.md),
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
              GsDropdown(
                label: 'City',
                value: _city,
                items: const ['Bangalore', 'Hyderabad', 'Chennai', 'Pune', 'Kolkata', 'Ahmedabad', 'Surat', 'Jaipur'],
                onChanged: (v) => setState(() => _city = v!),
              ),
              const SizedBox(height: GsSpacing.md),
              Row(children: [
                Expanded(
                  child: GsField(
                    label: 'Pincode',
                    controller: _pincodeCtrl,
                    hint: '560001',
                    inputType: TextInputType.number,
                    formatters: [
                      FilteringTextInputFormatter.digitsOnly,
                      LengthLimitingTextInputFormatter(6),
                    ],
                  ),
                ),
                const SizedBox(width: GsSpacing.md),
                Expanded(
                  child: GsDropdown(
                    label: 'Platform',
                    value: _platform,
                    items: const ['swiggy', 'zomato', 'dunzo', 'ola', 'uber', 'rapido'],
                    onChanged: (v) => setState(() => _platform = v!),
                  ),
                ),
              ]),
              const SizedBox(height: GsSpacing.md),
              Row(children: [
                Expanded(
                  child: GsDropdown(
                    label: 'Vehicle',
                    value: _vehicle,
                    items: const ['bike', 'scooter', 'cycle'],
                    onChanged: (v) => setState(() => _vehicle = v!),
                  ),
                ),
                const SizedBox(width: GsSpacing.md),
                Expanded(
                  child: GsField(
                    label: 'Weekly Income (₹)',
                    controller: _incomeCtrl,
                    hint: '8000',
                    inputType: TextInputType.number,
                  ),
                ),
              ]),

              if (_error.isNotEmpty) ...[
                const SizedBox(height: GsSpacing.md),
                Container(
                  padding: const EdgeInsets.all(GsSpacing.md),
                  decoration: BoxDecoration(color: GsColors.errorSoft, borderRadius: GsShapes.sm),
                  child: Text(_error, style: GsTypography.caption.copyWith(color: GsColors.error)),
                ),
              ],
              const SizedBox(height: GsSpacing.xl),
              GsGradientButton(
                label: 'Create Account',
                gradient: GsColors.primaryGradient,
                isLoading: _loading,
                onPressed: _submit,
              ),
              const SizedBox(height: GsSpacing.lg),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text('Already have an account? ', style: GsTypography.body),
                  GestureDetector(
                    onTap: () => context.go('/login'),
                    child: Text('Sign In',
                        style: GsTypography.body.copyWith(color: GsColors.accent, fontWeight: FontWeight.w600)),
                  ),
                ],
              ),
              const SizedBox(height: GsSpacing.lg),
            ],
          ),
        ),
      ),
    );
  }
}
