import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../theme/design_system.dart';
import '../../services/worker_service.dart';
import '../../widgets/form_widgets.dart';

String _inr(double v) =>
    NumberFormat.currency(locale: 'en_IN', symbol: '₹', decimalDigits: 0).format(v);

class PayoutsScreen extends StatefulWidget {
  const PayoutsScreen({super.key});

  @override
  State<PayoutsScreen> createState() => _PayoutsScreenState();
}

class _PayoutsScreenState extends State<PayoutsScreen> {
  final _service = WorkerService();
  List<Payout>? _payouts;
  bool _loading = true;
  String _error = '';

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() { _loading = true; _error = ''; });
    try {
      final p = await _service.getPayouts();
      if (mounted) setState(() { _payouts = p; _loading = false; });
    } catch (e) {
      if (mounted) setState(() { _error = e.toString().replaceFirst('Exception: ', ''); _loading = false; });
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
                  Text('Payouts', style: GsTypography.heading.copyWith(fontSize: 22)),
                  Text('Money sent directly to your UPI', style: GsTypography.body),
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
    final payouts = _payouts ?? [];
    if (payouts.isEmpty) {
      return ListView(
        padding: const EdgeInsets.all(GsSpacing.md),
        children: [
          GsCard(
            child: Column(
              children: [
                const Icon(Icons.account_balance_wallet_outlined, size: 48, color: GsColors.textTertiary),
                const SizedBox(height: GsSpacing.md),
                Text('No payouts yet', style: GsTypography.subheading),
                const SizedBox(height: GsSpacing.xs),
                Text('Payouts are sent automatically when claims are approved.', style: GsTypography.body, textAlign: TextAlign.center),
              ],
            ),
          ),
        ],
      );
    }

    final total = payouts.fold<double>(0, (s, p) => s + p.amountInr);
    return ListView.separated(
      padding: const EdgeInsets.all(GsSpacing.md),
      itemCount: payouts.length + 1,
      separatorBuilder: (_, i) => i == 0 ? const SizedBox(height: GsSpacing.md) : const SizedBox(height: GsSpacing.sm),
      itemBuilder: (ctx, i) {
        if (i == 0) {
          return Container(
            padding: const EdgeInsets.all(GsSpacing.md),
            decoration: BoxDecoration(
              gradient: GsColors.primaryGradient,
              borderRadius: GsShapes.lg,
              boxShadow: GsShadows.card,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Total Received', style: GsTypography.caption.copyWith(color: Colors.white70)),
                const SizedBox(height: GsSpacing.xs),
                Text(_inr(total), style: GsTypography.heading.copyWith(color: Colors.white, fontSize: 28)),
                Text('${payouts.length} payouts', style: GsTypography.caption.copyWith(color: Colors.white60)),
              ],
            ),
          );
        }
        final p = payouts[i - 1];
        final isPaid = p.status == 'paid' || p.status == 'completed';
        return GsCard(
          child: Row(children: [
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: isPaid ? GsColors.successSoft : GsColors.warningSoft,
                borderRadius: GsShapes.sm,
              ),
              child: Icon(
                Icons.send_rounded,
                color: isPaid ? GsColors.success : GsColors.warning,
                size: 18,
              ),
            ),
            const SizedBox(width: GsSpacing.md),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(_inr(p.amountInr), style: GsTypography.subheading),
                  Text(p.paidAt.isNotEmpty ? _formatDate(p.paidAt) : 'Processing',
                      style: GsTypography.caption),
                ],
              ),
            ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: GsSpacing.sm, vertical: 3),
              decoration: BoxDecoration(
                color: isPaid ? GsColors.successSoft : GsColors.warningSoft,
                borderRadius: GsShapes.xl,
              ),
              child: Text(
                p.status,
                style: GsTypography.label.copyWith(
                  color: isPaid ? GsColors.success : GsColors.warning,
                  fontSize: 10,
                ),
              ),
            ),
          ]),
        );
      },
    );
  }

  String _formatDate(String iso) {
    try { return DateFormat('MMM d, yyyy').format(DateTime.parse(iso)); }
    catch (_) { return iso; }
  }
}
