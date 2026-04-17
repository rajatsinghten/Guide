import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../theme/design_system.dart';
import '../../services/worker_service.dart';
import '../../widgets/form_widgets.dart';

String _inr(double v) =>
    NumberFormat.currency(locale: 'en_IN', symbol: '₹', decimalDigits: 0).format(v);

class ClaimsScreen extends StatefulWidget {
  const ClaimsScreen({super.key});

  @override
  State<ClaimsScreen> createState() => _ClaimsScreenState();
}

class _ClaimsScreenState extends State<ClaimsScreen> {
  final _service = WorkerService();
  List<Claim>? _claims;
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
      final c = await _service.getClaims();
      if (mounted) setState(() { _claims = c; _loading = false; });
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
                  Text('Claims', style: GsTypography.heading.copyWith(fontSize: 22)),
                  Text('Auto-triggered when a parametric event occurs', style: GsTypography.body),
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
    final claims = _claims ?? [];
    if (claims.isEmpty) {
      return ListView(
        padding: const EdgeInsets.all(GsSpacing.md),
        children: [
          GsCard(
            child: Column(
              children: [
                const Icon(Icons.receipt_long_outlined, size: 48, color: GsColors.textTertiary),
                const SizedBox(height: GsSpacing.md),
                Text('No claims yet', style: GsTypography.subheading),
                const SizedBox(height: GsSpacing.xs),
                Text('Claims are auto-created when parametric events trigger.', style: GsTypography.body, textAlign: TextAlign.center),
              ],
            ),
          ),
        ],
      );
    }
    return ListView.separated(
      padding: const EdgeInsets.all(GsSpacing.md),
      itemCount: claims.length,
      separatorBuilder: (_, __) => const SizedBox(height: GsSpacing.md),
      itemBuilder: (ctx, i) {
        final c = claims[i];
        final isPaid = c.status == 'approved' || c.status == 'paid';
        return GsCard(
          border: Border.all(
            color: isPaid ? GsColors.success.withOpacity(0.3) : GsColors.divider,
          ),
          child: Row(children: [
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: isPaid ? GsColors.successSoft : GsColors.surface,
                borderRadius: GsShapes.sm,
              ),
              child: Icon(
                isPaid ? Icons.check_rounded : Icons.pending_outlined,
                color: isPaid ? GsColors.success : GsColors.textTertiary,
                size: 20,
              ),
            ),
            const SizedBox(width: GsSpacing.md),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(c.eventType.replaceAll('_', ' ').toUpperCase(),
                      style: GsTypography.label.copyWith(color: GsColors.textSecondary)),
                  Text(_inr(c.claimAmountInr), style: GsTypography.subheading),
                ],
              ),
            ),
            Text(c.status, style: GsTypography.caption.copyWith(
              color: isPaid ? GsColors.success : GsColors.textTertiary,
            )),
          ]),
        );
      },
    );
  }
}
