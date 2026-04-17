import 'dart:async';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import '../../theme/design_system.dart';
import '../../services/auth_service.dart';
import '../../services/worker_service.dart';
import '../../widgets/form_widgets.dart';

String _inr(double v) =>
    NumberFormat.currency(locale: 'en_IN', symbol: '₹', decimalDigits: 0)
        .format(v);

class DashboardScreen extends StatefulWidget {
  const DashboardScreen({super.key});

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  final _service = WorkerService();
  DashboardData? _data;
  bool _loading = true;
  String _error = '';
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _load();
    _timer = Timer.periodic(const Duration(seconds: 8), (_) => _load(silent: true));
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  Future<void> _load({bool silent = false}) async {
    if (!silent) setState(() => _loading = true);
    try {
      final data = await _service.getDashboard();
      if (mounted) setState(() { _data = data; _loading = false; _error = ''; });
    } catch (e) {
      if (mounted) setState(() { _error = e.toString().replaceFirst('Exception: ', ''); _loading = false; });
    }
  }

  @override
  Widget build(BuildContext context) {
    final worker = AuthService().currentWorker;
    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            // ── Header ────────────────────────────────────────────────
            Padding(
              padding: const EdgeInsets.fromLTRB(GsSpacing.lg, GsSpacing.md, GsSpacing.md, GsSpacing.sm),
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Good ${_greeting()}, ${worker?.name.split(' ').first ?? ''}',
                            style: GsTypography.subheading),
                        Text("Here's your safety check today", style: GsTypography.caption),
                      ],
                    ),
                  ),
                  const SizedBox(width: GsSpacing.sm),
                  Container(
                    width: 36,
                    height: 36,
                    padding: const EdgeInsets.all(4),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: GsShapes.sm,
                      boxShadow: GsShadows.subtle,
                    ),
                    child: Image.asset('assets/images/logo.png'),
                  ),
                  const SizedBox(width: GsSpacing.xs),
                  IconButton(
                    icon: const Icon(Icons.logout_rounded, size: 20, color: GsColors.textTertiary),
                    onPressed: () async {
                      await AuthService().logout();
                      if (mounted) context.go('/login');
                    },
                  ),
                ],
              ),
            ),

            // ── Content ───────────────────────────────────────────────
            Expanded(
              child: _loading
                  ? const Center(child: CircularProgressIndicator(color: GsColors.accent))
                  : _error.isNotEmpty
                      ? _errorView()
                      : _content(),
            ),
          ],
        ),
      ),
    );
  }

  Widget _content() {
    final d = _data!;
    final active = d.activePolicy;
    final risk = d.riskToday;

    return RefreshIndicator(
      color: GsColors.accent,
      onRefresh: _load,
      child: ListView(
        padding: const EdgeInsets.all(GsSpacing.md),
        children: [
          // ── Protection card ────────────────────────────────────────
          _ProtectionCard(
            isActive: active != null,
            maxPayout: active?.coverageAmountInr ?? 0,
            validTill: active?.endDate,
            weeklyCost: active?.weeklyPremiumInr ?? 0,
            onGetCoverage: () => context.go('/home/policies'),
          ),
          const SizedBox(height: GsSpacing.md),

          // ── This week ──────────────────────────────────────────────
          Row(children: [
            Expanded(child: _StatCard(label: 'Income Protected', value: _inr(d.incomeProtectedThisWeek))),
            const SizedBox(width: GsSpacing.md),
            Expanded(child: _StatCard(label: 'Payout This Month', value: _inr(d.payoutTotal))),
          ]),
          const SizedBox(height: GsSpacing.md),

          // ── Today's risk ───────────────────────────────────────────
          GsCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(children: [
                  Text('Risk Today', style: GsTypography.subheading),
                  const Spacer(),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: GsSpacing.sm, vertical: 2),
                    decoration: BoxDecoration(
                      color: GsColors.accent.withOpacity(0.1),
                      borderRadius: GsShapes.xl,
                    ),
                    child: Text('Live · 8s', style: GsTypography.caption.copyWith(color: GsColors.accent, fontSize: 10)),
                  ),
                ]),
                const SizedBox(height: GsSpacing.sm),
                if (risk != null) ...[
                  _RiskRow(label: 'Weather', value: risk['weather_condition'] as String? ?? '—'),
                  _RiskRow(label: 'Traffic', value: risk['traffic_level'] as String? ?? '—'),
                  _RiskRow(
                    label: 'Precipitation',
                    value: '${((risk['precipitation_mm'] as num?)?.toDouble() ?? 0).toStringAsFixed(1)} mm',
                  ),
                  if (risk['note'] != null) ...[
                    const SizedBox(height: GsSpacing.sm),
                    Container(
                      padding: const EdgeInsets.all(GsSpacing.sm),
                      decoration: BoxDecoration(
                        color: GsColors.warningSoft,
                        borderRadius: GsShapes.sm,
                      ),
                      child: Text(risk['note'] as String,
                          style: GsTypography.caption.copyWith(color: GsColors.warning)),
                    ),
                  ],
                ] else
                  Text('No risk signal right now.', style: GsTypography.body.copyWith(color: GsColors.success)),
              ],
            ),
          ),
          const SizedBox(height: GsSpacing.md),

          // ── Activity ────────────────────────────────────────────────
          GsCard(
            color: GsColors.successSoft,
            child: Row(children: [
              const Icon(Icons.check_circle_outline, color: GsColors.success, size: 20),
              const SizedBox(width: GsSpacing.sm),
              Expanded(
                child: Text(
                  '${d.claimsThisMonth} support events · ${_inr(d.payoutTotal)} sent this month',
                  style: GsTypography.body.copyWith(color: GsColors.success),
                ),
              ),
            ]),
          ),
          const SizedBox(height: GsSpacing.md),
          GsCard(
            color: GsColors.primary,
            child: Text(
              'No forms. No claims. Money sent automatically.',
              style: GsTypography.body.copyWith(color: Colors.white, fontWeight: FontWeight.w600),
            ),
          ),
        ],
      ),
    );
  }

  Widget _errorView() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(GsSpacing.lg),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.cloud_off_rounded, size: 40, color: GsColors.textTertiary),
            const SizedBox(height: GsSpacing.md),
            Text(_error, style: GsTypography.body, textAlign: TextAlign.center),
            const SizedBox(height: GsSpacing.md),
            GsGradientButton(
              label: 'Retry',
              gradient: GsColors.primaryGradient,
              onPressed: _load,
            ),
          ],
        ),
      ),
    );
  }

  String _greeting() {
    final h = DateTime.now().hour;
    if (h < 12) return 'morning';
    if (h < 17) return 'afternoon';
    return 'evening';
  }
}

// ── Sub-widgets ───────────────────────────────────────────────────────────────

class _ProtectionCard extends StatelessWidget {
  final bool isActive;
  final double maxPayout;
  final String? validTill;
  final double weeklyCost;
  final VoidCallback onGetCoverage;

  const _ProtectionCard({
    required this.isActive,
    required this.maxPayout,
    required this.validTill,
    required this.weeklyCost,
    required this.onGetCoverage,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(GsSpacing.md + 4),
      decoration: BoxDecoration(
        color: isActive ? GsColors.primary : GsColors.error,
        borderRadius: GsShapes.lg,
        boxShadow: GsShadows.card,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: GsSpacing.sm, vertical: 4),
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.15),
                borderRadius: GsShapes.xl,
              ),
              child: Row(children: [
                Icon(
                  isActive ? Icons.shield_rounded : Icons.shield_outlined,
                  color: Colors.white,
                  size: 14,
                ),
                const SizedBox(width: 6),
                Text(
                  isActive ? 'ACTIVE COVERAGE' : 'NOT COVERED',
                  style: GsTypography.label.copyWith(color: Colors.white, fontSize: 11, letterSpacing: 1),
                ),
              ]),
            ),
            const Spacer(),
            if (isActive)
              Text(
                'Till ${_formatDate(validTill)}',
                style: GsTypography.caption.copyWith(color: Colors.white70),
              ),
          ]),
          const SizedBox(height: GsSpacing.lg),
          Text(
            isActive ? _inr(maxPayout) : 'Get Protected',
            style: GsTypography.heading.copyWith(color: Colors.white, fontSize: 32),
          ),
          const SizedBox(height: 4),
          Text(
            isActive ? 'Weekly Max payout · ${_inr(weeklyCost)} cost' : 'Identify your risks and get covered',
            style: GsTypography.caption.copyWith(color: Colors.white.withOpacity(0.8)),
          ),
          if (!isActive) ...[
            const SizedBox(height: GsSpacing.md),
            InkWell(
              onTap: onGetCoverage,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: GsSpacing.md, vertical: GsSpacing.sm),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: GsShapes.md,
                ),
                child: Text('Get Coverage', style: GsTypography.button.copyWith(color: GsColors.primary)),
              ),
            ),
          ],
        ],
      ),
    );
  }

  String _formatDate(String? iso) {
    if (iso == null || iso.isEmpty) return '—';
    try {
      return DateFormat('MMM d, yyyy').format(DateTime.parse(iso));
    } catch (_) {
      return iso;
    }
  }
}

class _StatCard extends StatelessWidget {
  final String label;
  final String value;

  const _StatCard({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return GsCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(value, style: GsTypography.subheading.copyWith(fontSize: 18, color: GsColors.accent)),
          const SizedBox(height: 2),
          Text(label, style: GsTypography.caption),
        ],
      ),
    );
  }
}

class _RiskRow extends StatelessWidget {
  final String label;
  final String value;

  const _RiskRow({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: GsSpacing.xs),
      child: Row(children: [
        Text(label, style: GsTypography.body),
        const Spacer(),
        Text(value, style: GsTypography.body.copyWith(color: GsColors.textPrimary, fontWeight: FontWeight.w600)),
      ]),
    );
  }
}
