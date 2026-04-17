import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../theme/design_system.dart';
import '../../services/worker_service.dart';
import '../../widgets/form_widgets.dart';

String _inr(double v) =>
    NumberFormat.currency(locale: 'en_IN', symbol: '₹', decimalDigits: 0).format(v);

class PoliciesScreen extends StatefulWidget {
  const PoliciesScreen({super.key});

  @override
  State<PoliciesScreen> createState() => _PoliciesScreenState();
}

class _PoliciesScreenState extends State<PoliciesScreen> {
  final _service = WorkerService();
  List<Policy>? _policies;
  bool _loading = true;
  String _error = '';
  bool _purchasing = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() { _loading = true; _error = ''; });
    try {
      final p = await _service.getPolicies();
      if (mounted) setState(() { _policies = p; _loading = false; });
    } catch (e) {
      if (mounted) setState(() { _error = e.toString().replaceFirst('Exception: ', ''); _loading = false; });
    }
  }

  Future<void> _buyCoverage(String plan) async {
    setState(() => _purchasing = true);
    try {
      await _service.purchasePolicy(plan);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('$plan policy activated!', style: GsTypography.body.copyWith(color: Colors.white)),
            backgroundColor: GsColors.success,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(borderRadius: GsShapes.md),
            margin: const EdgeInsets.all(GsSpacing.md),
          ),
        );
        await _load();
      }
    } catch (e) {
      setState(() => _error = e.toString().replaceFirst('Exception: ', ''));
    } finally {
      if (mounted) setState(() => _purchasing = false);
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
                  Text('My Policies', style: GsTypography.heading.copyWith(fontSize: 22)),
                  Text('Your income protection coverage', style: GsTypography.body),
                ],
              ),
            ),
            Expanded(
              child: _loading
                  ? const Center(child: CircularProgressIndicator(color: GsColors.accent))
                  : RefreshIndicator(
                      color: GsColors.accent,
                      onRefresh: _load,
                      child: _content(),
                    ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _content() {
    final policies = _policies ?? [];
    if (policies.isEmpty) {
      return ListView(
        padding: const EdgeInsets.all(GsSpacing.md),
        children: [
          GsCard(
            child: Column(
              children: [
                const Icon(Icons.policy_outlined, size: 48, color: GsColors.textTertiary),
                const SizedBox(height: GsSpacing.md),
                Text('No active policy', style: GsTypography.subheading),
                const SizedBox(height: GsSpacing.xs),
                Text('Go to Pricing to get coverage.', style: GsTypography.body),
              ],
            ),
          ),
        ],
      );
    }
    return ListView.separated(
      padding: const EdgeInsets.all(GsSpacing.md),
      itemCount: policies.length,
      separatorBuilder: (_, __) => const SizedBox(height: GsSpacing.md),
      itemBuilder: (ctx, i) => _PolicyCard(policy: policies[i]),
    );
  }
}

class _PolicyCard extends StatelessWidget {
  final Policy policy;
  const _PolicyCard({required this.policy});

  @override
  Widget build(BuildContext context) {
    final isActive = policy.status == 'active';
    return GsCard(
      border: Border.all(
        color: isActive
            ? GsColors.success.withOpacity(0.4)
            : GsColors.divider,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: GsSpacing.sm, vertical: 3),
              decoration: BoxDecoration(
                color: isActive ? GsColors.successSoft : GsColors.surface,
                borderRadius: GsShapes.xl,
              ),
              child: Text(
                policy.status.toUpperCase(),
                style: GsTypography.label.copyWith(
                  color: isActive ? GsColors.success : GsColors.textTertiary,
                  fontSize: 10,
                ),
              ),
            ),
            const Spacer(),
            Text(policy.endDate != null ? _formatDate(policy.endDate!) : 'Ongoing', style: GsTypography.caption),
          ]),
          const SizedBox(height: GsSpacing.md),
          Text(_inr(policy.coverageAmountInr),
              style: GsTypography.heading.copyWith(fontSize: 22, color: GsColors.textPrimary)),
          Text('Coverage · ${_inr(policy.weeklyPremiumInr)}/week',
              style: GsTypography.caption),
        ],
      ),
    );
  }

  String _formatDate(String? iso) {
    if (iso == null || iso.isEmpty) return '—';
    try { return DateFormat('MMM d, yyyy').format(DateTime.parse(iso)); }
    catch (_) { return iso; }
  }
}
