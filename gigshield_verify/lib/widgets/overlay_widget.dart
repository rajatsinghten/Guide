import 'dart:async';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../theme/design_system.dart';

/// Floating overlay widget displayed during recording.
/// Shows: session ID, live timestamp, rotating nonce.
/// Must be rendered as part of the screen so MediaProjection captures it.
class OverlayWidget extends StatefulWidget {
  final String sessionId;
  final String nonce;

  const OverlayWidget({
    super.key,
    required this.sessionId,
    required this.nonce,
  });

  @override
  State<OverlayWidget> createState() => _OverlayWidgetState();
}

class _OverlayWidgetState extends State<OverlayWidget>
    with SingleTickerProviderStateMixin {
  late Timer _clockTimer;
  late String _currentTime;
  late AnimationController _pulseController;

  @override
  void initState() {
    super.initState();
    _currentTime = _formatNow();
    _clockTimer = Timer.periodic(const Duration(seconds: 1), (_) {
      setState(() => _currentTime = _formatNow());
    });
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _clockTimer.cancel();
    _pulseController.dispose();
    super.dispose();
  }

  String _formatNow() =>
      DateFormat('yyyy-MM-dd  HH:mm:ss').format(DateTime.now());

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.fromLTRB(
        GsSpacing.md,
        GsSpacing.sm,
        GsSpacing.md,
        0,
      ),
      padding: const EdgeInsets.all(GsSpacing.md),
      decoration: BoxDecoration(
        color: GsColors.primary,
        borderRadius: GsShapes.md,
        boxShadow: GsShadows.elevated,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ── Header row ──────────────────────────────────────────
          Row(
            children: [
              FadeTransition(
                opacity: _pulseController.drive(
                  Tween(begin: 0.5, end: 1.0),
                ),
                child: Container(
                  width: 8,
                  height: 8,
                  decoration: const BoxDecoration(
                    color: Color(0xFFEF4444),
                    shape: BoxShape.circle,
                  ),
                ),
              ),
              const SizedBox(width: GsSpacing.sm),
              Text(
                'RECORDING',
                style: GsTypography.label.copyWith(
                  color: const Color(0xFFEF4444),
                  letterSpacing: 1.5,
                ),
              ),
              const Spacer(),
              Text(
                _currentTime,
                style: GsTypography.mono.copyWith(
                  fontSize: 11,
                  color: Colors.white60,
                ),
              ),
            ],
          ),
          const SizedBox(height: GsSpacing.md),

          // ── Session + Nonce ─────────────────────────────────────
          Row(
            children: [
              _infoBlock(
                'SESSION',
                widget.sessionId.substring(0, 8).toUpperCase(),
              ),
              const SizedBox(width: GsSpacing.lg),
              _infoBlock(
                'VERIFY CODE',
                widget.nonce,
                valueColor: GsColors.secondary,
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _infoBlock(String label, String value, {Color? valueColor}) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: GsTypography.label.copyWith(
            color: Colors.white38,
            fontSize: 10,
          ),
        ),
        const SizedBox(height: 2),
        Text(
          value,
          style: GsTypography.mono.copyWith(
            color: valueColor ?? Colors.white,
            fontSize: 15,
            fontWeight: FontWeight.w700,
          ),
        ),
      ],
    );
  }
}
