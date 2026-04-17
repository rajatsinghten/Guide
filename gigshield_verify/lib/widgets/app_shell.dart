import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../theme/design_system.dart';

/// Bottom navigation shell wrapping all home tabs.
class AppShell extends StatefulWidget {
  final Widget child;
  const AppShell({super.key, required this.child});

  @override
  State<AppShell> createState() => _AppShellState();
}

class _AppShellState extends State<AppShell> {
  int _selectedIndex = 0;

  static const _tabs = [
    (icon: Icons.home_outlined, activeIcon: Icons.home_rounded, label: 'Home', route: '/home'),
    (icon: Icons.policy_outlined, activeIcon: Icons.policy_rounded, label: 'Policies', route: '/home/policies'),
    (icon: Icons.calculate_outlined, activeIcon: Icons.calculate_rounded, label: 'Pricing', route: '/home/pricing'),
    (icon: Icons.receipt_long_outlined, activeIcon: Icons.receipt_long_rounded, label: 'Claims', route: '/home/claims'),
    (icon: Icons.account_balance_wallet_outlined, activeIcon: Icons.account_balance_wallet_rounded, label: 'Payouts', route: '/home/payouts'),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: widget.child,
      bottomNavigationBar: Container(
        decoration: BoxDecoration(
          color: GsColors.card,
          boxShadow: GsShadows.elevated,
        ),
        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: GsSpacing.md),
            child: Row(
              children: List.generate(
                _tabs.length,
                (i) => _NavItem(
                  icon: _tabs[i].icon,
                  activeIcon: _tabs[i].activeIcon,
                  label: _tabs[i].label,
                  isActive: _selectedIndex == i,
                  onTap: () {
                    setState(() => _selectedIndex = i);
                    context.go(_tabs[i].route);
                  },
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _NavItem extends StatelessWidget {
  final IconData icon;
  final IconData activeIcon;
  final String label;
  final bool isActive;
  final VoidCallback onTap;

  const _NavItem({
    required this.icon,
    required this.activeIcon,
    required this.label,
    required this.isActive,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: GestureDetector(
        onTap: onTap,
        behavior: HitTestBehavior.opaque,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          padding: const EdgeInsets.symmetric(vertical: GsSpacing.xs),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Transform.scale(
                scale: isActive ? 1.1 : 1.0,
                child: Icon(
                  isActive ? activeIcon : icon,
                  size: 24,
                  color: isActive ? GsColors.accent : GsColors.textTertiary,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                label,
                style: GsTypography.caption.copyWith(
                  fontSize: 10,
                  color: isActive ? GsColors.accent : GsColors.textTertiary,
                  fontWeight: isActive ? FontWeight.w600 : FontWeight.w400,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
