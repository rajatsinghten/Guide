import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../theme/design_system.dart';
import '../../services/worker_service.dart';
import '../../widgets/form_widgets.dart';

String _inr(double v) =>
    NumberFormat.currency(locale: 'en_IN', symbol: '₹', decimalDigits: 0).format(v);

class PricingScreen extends StatefulWidget {
  const PricingScreen({super.key});

  @override
  State<PricingScreen> createState() => _PricingScreenState();
}

class _PricingScreenState extends State<PricingScreen> {
  final _service = WorkerService();
  List<PremiumBreakdown>? _plans;
  bool _loading = true;
  String _error = '';
  bool _buying = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() { _loading = true; _error = ''; });
    try {
      final p = await _service.getPricing();
      if (mounted) setState(() { _plans = p; _loading = false; });
    } catch (e) {
      if (mounted) setState(() { _error = e.toString().replaceFirst('Exception: ', ''); _loading = false; });
    }
  }

  Future<void> _buy(String planName) async {
    setState(() => _buying = true);
    try {
      await _service.purchasePolicy(planName);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('$planName activated!', style: GsTypography.body.copyWith(color: Colors.white)),
            backgroundColor: GsColors.success,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(borderRadius: GsShapes.md),
            margin: const EdgeInsets.all(GsSpacing.md),
          ),
        );
      }
    } catch (e) {
      if (mounted) setState(() => _error = e.toString().replaceFirst('Exception: ', ''));
    } finally {
      if (mounted) setState(() => _buying = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(GsSpacing.lg, GsSpacing.md, GsSpacing.lg, GsSpacing.sm),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Pricing', style: GsTypography.heading.copyWith(fontSize: 22)),
                  Text('Choose your weekly income protection', style: GsTypography.body),
                ],
              ),
            ),
            Expanded(
              child: _loading
                  ? const Center(child: CircularProgressIndicator(color: GsColors.accent))
                  : _error.isNotEmpty
                      ? Center(child: Text(_error, style: GsTypography.body))
                      : ListView.separated(
                          padding: const EdgeInsets.all(GsSpacing.md),
                          itemCount: (_plans ?? []).length,
                          separatorBuilder: (_, __) => const SizedBox(height: GsSpacing.md),
                          itemBuilder: (ctx, i) => _PlanCard(
                            plan: _plans![i],
                            onBuy: _buying ? null : () => _buy(_plans![i].planName),
                          ),
                        ),
            ),
          ],
        ),
      ),
    );
  }
}

class _PlanCard extends StatelessWidget {
  final PremiumBreakdown plan;
  final VoidCallback? onBuy;

  const _PlanCard({required this.plan, required this.onBuy});

  @override
  Widget build(BuildContext context) {
    return GsCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(children: [
            Expanded(child: Text(plan.planName, style: GsTypography.subheading)),
            Text(_inr(plan.finalPremium) + '/week',
                style: GsTypography.subheading.copyWith(color: GsColors.accent)),
          ]),
          const SizedBox(height: GsSpacing.sm),
          Text('Coverage up to ${_inr(plan.coverageAmount)}', style: GsTypography.body),
          const SizedBox(height: GsSpacing.md),
          const Divider(color: GsColors.divider),
          const SizedBox(height: GsSpacing.sm),
          Container(
            padding: const EdgeInsets.all(GsSpacing.sm),
            decoration: BoxDecoration(
              color: GsColors.accent.withOpacity(0.05),
              borderRadius: GsShapes.sm,
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Icon(Icons.auto_awesome, size: 14, color: GsColors.accent),
                const SizedBox(width: GsSpacing.sm),
                Expanded(
                  child: Text(
                    plan.whyRecommended,
                    style: GsTypography.caption.copyWith(color: GsColors.accent),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: GsSpacing.md),
          GsGradientButton(
            label: 'Activate ${plan.planName}',
            gradient: GsColors.primaryGradient,
            onPressed: onBuy,
          ),
        ],
      ),
    );
  }
}

class _BreakdownRow extends StatelessWidget {
  final String label;
  final String value;
  const _BreakdownRow(this.label, this.value);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: GsSpacing.xs),
      child: Row(children: [
        Text(label, style: GsTypography.body),
        const Spacer(),
        Text(value, style: GsTypography.body.copyWith(fontWeight: FontWeight.w600, color: GsColors.textPrimary)),
      ]),
    );
  }
}
