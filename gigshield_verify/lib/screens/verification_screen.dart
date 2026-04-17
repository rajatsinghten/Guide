import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../services/verification_service.dart';
import '../services/location_service.dart';
import '../services/api_service.dart';
import '../services/auth_service.dart';
import '../widgets/overlay_widget.dart';
import '../theme/design_system.dart';

enum VerificationState {
  idle,
  starting,
  recording,
  finishing,
  done,
  error,
}

class VerificationScreen extends StatefulWidget {
  const VerificationScreen({super.key});

  @override
  State<VerificationScreen> createState() => _VerificationScreenState();
}

class _VerificationScreenState extends State<VerificationScreen>
    with TickerProviderStateMixin {
  final _verificationService = VerificationService();
  final _locationService = LocationService();
  final _apiService = ApiService();

  VerificationState _state = VerificationState.idle;
  String _statusMessage = 'Ready to verify';
  String _errorMessage = '';

  // Session-related UI state
  String _currentNonce = '';
  String _sessionId = '';
  bool _driverAppOpened = false;
  Map<String, bool> _installedDriverApps = {};

  // Final result
  Map<String, dynamic>? _verificationResult;

  // Animations
  late AnimationController _fadeController;
  late Animation<double> _fadeAnimation;

  @override
  void initState() {
    super.initState();
    _fadeController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 400),
    );
    _fadeAnimation = CurvedAnimation(
      parent: _fadeController,
      curve: Curves.easeOut,
    );
    _fadeController.forward();
  }

  @override
  void dispose() {
    _fadeController.dispose();
    _verificationService.dispose();
    _locationService.stopCollection();
    super.dispose();
  }

  // ── STEP 1: Start Verification ──────────────────────────────────────────

  Future<void> _startVerification() async {
    setState(() {
      _state = VerificationState.starting;
      _statusMessage = 'Initializing session...';
      _errorMessage = '';
    });

    try {
      // 1a. Check location permissions
      final hasLocation = await _locationService.ensurePermissions();
      if (!hasLocation) {
        throw VerificationException('Location permission required');
      }

      // 1b. Create session
      final session = _verificationService.createSession();
      setState(() {
        _sessionId = session.sessionId;
        _currentNonce = session.nonce;
        _statusMessage = 'Session created. Starting recording...';
      });

      // 1c. Notify backend
      try {
        await _apiService.startVerification(
          sessionId: session.sessionId,
          nonce: session.nonce,
          timestamp: session.startTime.toIso8601String(),
        );
      } catch (e) {
        debugPrint('Verification start error: $e');
        _setStatus('Backend offline, continuing offline...');
        await Future.delayed(const Duration(seconds: 1));
      }

      // 1d. Start recording
      final recordingStarted = await _verificationService.startRecording();
      if (!recordingStarted) {
        throw VerificationException(
            'Could not start recording. Grant screen capture permission.');
      }

      // 1e. Start location collection
      _locationService.startCollection();

      // 1f. Start nonce rotation
      _verificationService.startNonceRotation((newNonce) {
        if (mounted) setState(() => _currentNonce = newNonce);
      });

      // 1g. Start foreground app polling
      _verificationService.startForegroundPolling();

      // 1h. Check installed driver apps
      try {
        _installedDriverApps =
            await _verificationService.checkInstalledDriverApps();
      } catch (_) {
        _installedDriverApps = {};
      }

      setState(() {
        _state = VerificationState.recording;
        _statusMessage = 'Recording in progress';
      });
    } on VerificationException catch (e) {
      setState(() {
        _state = VerificationState.error;
        _errorMessage = e.message;
        _statusMessage = 'Verification failed';
      });
    } catch (e) {
      setState(() {
        _state = VerificationState.error;
        _errorMessage = 'Unexpected error: $e';
        _statusMessage = 'Verification failed';
      });
    }
  }

  // ── STEP 2: Open driver app ─────────────────────────────────────────────

  Future<void> _openDriverApp() async {
    final String? chosen = await showModalBottomSheet<String>(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (ctx) => _DriverAppSheet(installedApps: _installedDriverApps),
    );

    if (chosen != null && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Switch to $chosen — recording will detect it automatically.',
            style: GsTypography.body.copyWith(color: Colors.white),
          ),
          backgroundColor: GsColors.primary,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: GsShapes.md),
          margin: const EdgeInsets.all(GsSpacing.md),
          duration: const Duration(seconds: 4),
        ),
      );
    }
  }

  // ── STEP 3: Finish Verification ─────────────────────────────────────────

  Future<void> _finishVerification() async {
    setState(() {
      _state = VerificationState.finishing;
      _statusMessage = 'Stopping recording...';
    });

    try {
      _verificationService.stopNonceRotation();
      _locationService.stopCollection();

      final videoPath = await _verificationService.stopRecording();

      setState(() => _statusMessage = 'Analyzing location data...');
      final spoofing = await _locationService.analyzeSpoofing();

      final session = _verificationService.currentSession!;
      final metadata = {
        ...session.toJson(),
        'location_samples':
            _locationService.samples.map((s) => s.toJson()).toList(),
        'spoofing': spoofing.toJson(),
        'installed_driver_apps': _installedDriverApps,
      };

      Map<String, dynamic> result;
      try {
        setState(() => _statusMessage = 'Uploading to server...');
        await _apiService.uploadVerification(
          sessionId: session.sessionId,
          videoPath: videoPath ?? '',
          metadata: metadata,
        );
        setState(() => _statusMessage = 'Validating...');
        result = await _apiService.validateVerification(
          sessionId: session.sessionId,
        );
      } catch (_) {
        result = _localValidate(metadata, spoofing.score);
      }

      final isVerified = result['status'] == 'verified';

      setState(() {
        _verificationResult = result;
        _state = VerificationState.done;
        _statusMessage = isVerified ? 'Verification successful' : 'Verification failed';
      });

      if (isVerified) {
        // Mark device as verified (once per device)
        await AuthService().markVerified();
        // Navigate to home after a brief moment so user sees result
        await Future.delayed(const Duration(seconds: 2));
        if (mounted) context.go('/home');
      } else {
        _setStatus('Verification failed. Please try again.');
      }
    } on VerificationException catch (e) {
      setState(() {
        _state = VerificationState.error;
        _errorMessage = e.message;
        _statusMessage = 'Finish failed';
      });
    } catch (e) {
      setState(() {
        _state = VerificationState.error;
        _errorMessage = 'Error: $e';
        _statusMessage = 'Finish failed';
      });
    }
  }

  /// Local fallback validation when backend is offline
  Map<String, dynamic> _localValidate(
      Map<String, dynamic> metadata, int spoofingScore) {
    final reasons = <String>[];
    int fraudScore = 0;

    if (spoofingScore > 50) {
      fraudScore += 40;
      reasons.add('High spoofing score: $spoofingScore');
    } else if (spoofingScore > 20) {
      fraudScore += 20;
      reasons.add('Moderate spoofing indicators');
    }

    final driverOpened = metadata['driver_app_opened'] as bool? ?? false;
    if (!driverOpened) {
      fraudScore += 30;
      reasons.add('No driver app usage detected');
    }

    final duration = metadata['duration_seconds'] as int? ?? 0;
    if (duration < 10) {
      fraudScore += 20;
      reasons.add('Recording too short (<10s)');
    }

    fraudScore = fraudScore.clamp(0, 100);
    final status = fraudScore < 40 ? 'verified' : 'failed';

    return {
      'status': status,
      'fraud_score': fraudScore,
      'spoofing_score': spoofingScore,
      'reasons': reasons,
      'source': 'local_validation',
    };
  }

  void _reset() {
    setState(() {
      _state = VerificationState.idle;
      _statusMessage = 'Ready to verify';
      _errorMessage = '';
      _currentNonce = '';
      _sessionId = '';
      _driverAppOpened = false;
      _installedDriverApps = {};
      _verificationResult = null;
    });
  }

  void _setStatus(String msg) {
    if (mounted) setState(() => _statusMessage = msg);
  }

  // ── Build ────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: FadeTransition(
          opacity: _fadeAnimation,
          child: Column(
            children: [
              _buildHeader(),
              if (_state == VerificationState.recording)
                OverlayWidget(
                  sessionId: _sessionId,
                  nonce: _currentNonce,
                ),
              Expanded(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.all(GsSpacing.md),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      _buildStatusSection(),
                      const SizedBox(height: GsSpacing.md),
                      if (_state == VerificationState.recording)
                        _buildSessionDetails(),
                      if (_state == VerificationState.done &&
                          _verificationResult != null) ...[
                        _buildResultCard(),
                        const SizedBox(height: GsSpacing.md),
                      ],
                      _buildActions(),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ── Header ──────────────────────────────────────────────────────────

  Widget _buildHeader() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(
        GsSpacing.lg,
        GsSpacing.md,
        GsSpacing.lg,
        GsSpacing.sm,
      ),
      child: Row(
        children: [
          Container(
            width: 40,
            height: 40,
            padding: const EdgeInsets.all(4),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: GsShapes.sm,
              boxShadow: GsShadows.subtle,
            ),
            child: Image.asset('assets/images/logo.png'),
          ),
          const SizedBox(width: GsSpacing.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('GigShield', style: GsTypography.subheading),
                Text('Verify', style: GsTypography.caption),
              ],
            ),
          ),
          if (_state == VerificationState.recording)
            _buildRecordingBadge(),
        ],
      ),
    );
  }

  Widget _buildRecordingBadge() {
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: GsSpacing.md,
        vertical: GsSpacing.xs + 2,
      ),
      decoration: BoxDecoration(
        color: GsColors.error.withOpacity(0.1),
        borderRadius: GsShapes.xl,
        border: Border.all(
          color: GsColors.error.withOpacity(0.3),
          width: 1,
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 6,
            height: 6,
            decoration: const BoxDecoration(
              color: GsColors.error,
              shape: BoxShape.circle,
            ),
          ),
          const SizedBox(width: 6),
          Text(
            'REC',
            style: GsTypography.label.copyWith(
              color: GsColors.error,
              letterSpacing: 1.2,
            ),
          ),
        ],
      ),
    );
  }

  // ── Status section ──────────────────────────────────────────────────

  Widget _buildStatusSection() {
    IconData icon;
    Color iconColor;
    Color bgColor;

    switch (_state) {
      case VerificationState.idle:
        icon = Icons.radio_button_unchecked;
        iconColor = GsColors.textTertiary;
        bgColor = GsColors.card;
      case VerificationState.starting:
      case VerificationState.finishing:
        icon = Icons.hourglass_top_rounded;
        iconColor = GsColors.warning;
        bgColor = GsColors.warningSoft;
      case VerificationState.recording:
        icon = Icons.fiber_manual_record;
        iconColor = GsColors.error;
        bgColor = GsColors.errorSoft;
      case VerificationState.done:
        icon = Icons.check_circle_outline;
        iconColor = GsColors.success;
        bgColor = GsColors.successSoft;
      case VerificationState.error:
        icon = Icons.error_outline;
        iconColor = GsColors.error;
        bgColor = GsColors.errorSoft;
    }

    return Container(
      padding: const EdgeInsets.all(GsSpacing.md),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: GsShapes.md,
        boxShadow: GsShadows.subtle,
      ),
      child: Row(
        children: [
          Icon(icon, color: iconColor, size: 20),
          const SizedBox(width: GsSpacing.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  _statusMessage,
                  style: GsTypography.subheading.copyWith(fontSize: 14),
                ),
                if (_errorMessage.isNotEmpty) ...[
                  const SizedBox(height: GsSpacing.xs),
                  Text(
                    _errorMessage,
                    style: GsTypography.caption.copyWith(
                      color: GsColors.error,
                    ),
                  ),
                ],
              ],
            ),
          ),
          if (_state == VerificationState.starting ||
              _state == VerificationState.finishing)
            const SizedBox(
              width: 18,
              height: 18,
              child: CircularProgressIndicator(
                strokeWidth: 2,
                color: GsColors.warning,
              ),
            ),
        ],
      ),
    );
  }

  // ── Session details (while recording) ───────────────────────────────

  Widget _buildSessionDetails() {
    final installedCount =
        _installedDriverApps.entries.where((e) => e.value).length;

    return Column(
      children: [
        const SizedBox(height: GsSpacing.md),
        Container(
          padding: const EdgeInsets.all(GsSpacing.md),
          decoration: BoxDecoration(
            color: GsColors.card,
            borderRadius: GsShapes.md,
            boxShadow: GsShadows.subtle,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'SESSION DETAILS',
                style: GsTypography.label.copyWith(
                  color: GsColors.textTertiary,
                ),
              ),
              const SizedBox(height: GsSpacing.md),
              _detailRow(
                'Session ID',
                _sessionId.substring(0, 8).toUpperCase(),
                isMono: true,
              ),
              const Divider(
                color: GsColors.divider,
                height: GsSpacing.lg,
              ),
              _detailRow(
                'Verify Code',
                _currentNonce,
                isMono: true,
                valueColor: GsColors.accent,
              ),
              const Divider(
                color: GsColors.divider,
                height: GsSpacing.lg,
              ),
              _detailRow(
                'Driver Apps',
                '$installedCount of ${_installedDriverApps.length} detected',
              ),
            ],
          ),
        ),
        const SizedBox(height: GsSpacing.md),
      ],
    );
  }

  Widget _detailRow(
    String label,
    String value, {
    bool isMono = false,
    Color? valueColor,
  }) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(label, style: GsTypography.body),
        Text(
          value,
          style: isMono
              ? GsTypography.mono.copyWith(
                  color: valueColor ?? GsColors.textPrimary,
                  fontWeight: FontWeight.w600,
                )
              : GsTypography.body.copyWith(
                  color: valueColor ?? GsColors.textPrimary,
                  fontWeight: FontWeight.w600,
                ),
        ),
      ],
    );
  }

  // ── Result card ─────────────────────────────────────────────────────

  Widget _buildResultCard() {
    final r = _verificationResult!;
    final status = r['status'] as String? ?? 'unknown';
    final fraudScore = r['fraud_score'] as int? ?? 0;
    final spoofScore = r['spoofing_score'] as int?;
    final reasons = (r['reasons'] as List?)?.cast<String>() ?? [];
    final isVerified = status == 'verified';

    return Container(
      padding: const EdgeInsets.all(GsSpacing.lg),
      decoration: BoxDecoration(
        color: GsColors.card,
        borderRadius: GsShapes.lg,
        boxShadow: GsShadows.card,
        border: Border.all(
          color: isVerified
              ? GsColors.success.withOpacity(0.3)
              : GsColors.error.withOpacity(0.3),
          width: 1,
        ),
      ),
      child: Column(
        children: [
          // ── Status icon + title ─────────────────────────────────
          Container(
            width: 56,
            height: 56,
            decoration: BoxDecoration(
              color: isVerified
                  ? GsColors.successSoft
                  : GsColors.errorSoft,
              shape: BoxShape.circle,
            ),
            child: Icon(
              isVerified ? Icons.check_rounded : Icons.close_rounded,
              color: isVerified ? GsColors.success : GsColors.error,
              size: 28,
            ),
          ),
          const SizedBox(height: GsSpacing.md),
          Text(
            isVerified ? 'Verified' : 'Verification Failed',
            style: GsTypography.heading.copyWith(
              fontSize: 20,
              color: isVerified ? GsColors.success : GsColors.error,
            ),
          ),
          const SizedBox(height: GsSpacing.lg),

          // ── Scores ──────────────────────────────────────────────
          Row(
            children: [
              Expanded(
                child: _scoreBlock(
                  'Fraud Score',
                  fraudScore,
                  fraudScore < 40 ? GsColors.success : GsColors.error,
                ),
              ),
              if (spoofScore != null) ...[
                Container(
                  width: 1,
                  height: 48,
                  color: GsColors.divider,
                ),
                Expanded(
                  child: _scoreBlock(
                    'Spoof Score',
                    spoofScore,
                    spoofScore < 30 ? GsColors.success : GsColors.warning,
                  ),
                ),
              ],
            ],
          ),

          // ── Flags ───────────────────────────────────────────────
          if (reasons.isNotEmpty) ...[
            const SizedBox(height: GsSpacing.md),
            const Divider(color: GsColors.divider),
            const SizedBox(height: GsSpacing.sm),
            ...reasons.map(
              (r) => Padding(
                padding: const EdgeInsets.only(bottom: GsSpacing.xs),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      margin: const EdgeInsets.only(top: 6),
                      width: 4,
                      height: 4,
                      decoration: const BoxDecoration(
                        color: GsColors.textTertiary,
                        shape: BoxShape.circle,
                      ),
                    ),
                    const SizedBox(width: GsSpacing.sm),
                    Expanded(
                      child: Text(r, style: GsTypography.caption),
                    ),
                  ],
                ),
              ),
            ),
          ],

          // ── Offline badge ───────────────────────────────────────
          if (r['source'] == 'local_validation') ...[
            const SizedBox(height: GsSpacing.sm),
            Container(
              padding: const EdgeInsets.symmetric(
                horizontal: GsSpacing.sm,
                vertical: GsSpacing.xs,
              ),
              decoration: BoxDecoration(
                color: GsColors.warningSoft,
                borderRadius: GsShapes.sm,
              ),
              child: Text(
                'Offline validation — backend unavailable',
                style: GsTypography.caption.copyWith(
                  color: GsColors.warning,
                  fontSize: 11,
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _scoreBlock(String label, int score, Color color) {
    return Column(
      children: [
        Text(
          '$score',
          style: GsTypography.heading.copyWith(
            fontSize: 28,
            color: color,
          ),
        ),
        const SizedBox(height: 2),
        Text(
          label,
          style: GsTypography.caption,
        ),
      ],
    );
  }

  // ── Action Buttons ──────────────────────────────────────────────────

  Widget _buildActions() {
    final isRecording = _state == VerificationState.recording;
    final isIdle = _state == VerificationState.idle ||
        _state == VerificationState.error ||
        _state == VerificationState.done;
    final isBusy = _state == VerificationState.starting ||
        _state == VerificationState.finishing;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // ── Primary action ────────────────────────────────────────
        if (isIdle)
          _GsButton(
            label: 'Start Verification',
            icon: Icons.play_arrow_rounded,
            gradient: GsColors.primaryGradient,
            onPressed: _startVerification,
          ),

        if (isRecording) ...[
          _GsButton(
            label: 'Open Driver App',
            icon: Icons.open_in_new_rounded,
            gradient: GsColors.accentGradient,
            onPressed: _openDriverApp,
          ),
          const SizedBox(height: GsSpacing.md),
          _GsButton(
            label: 'Finish Verification',
            icon: Icons.stop_rounded,
            gradient: GsColors.recordingGradient,
            onPressed: _finishVerification,
          ),
        ],

        if (isBusy)
          _GsButton(
            label: _state == VerificationState.starting
                ? 'Starting...'
                : 'Finishing...',
            icon: null,
            gradient: GsColors.primaryGradient,
            onPressed: null,
            isLoading: true,
          ),

        if (_state == VerificationState.done ||
            _state == VerificationState.error) ...[
          const SizedBox(height: GsSpacing.md),
          Center(
            child: TextButton(
              onPressed: _reset,
              style: TextButton.styleFrom(
                foregroundColor: GsColors.accent,
                padding: const EdgeInsets.symmetric(
                  horizontal: GsSpacing.lg,
                  vertical: GsSpacing.md,
                ),
              ),
              child: Text(
                'Start New Verification',
                style: GsTypography.button.copyWith(color: GsColors.accent),
              ),
            ),
          ),
        ],
      ],
    );
  }
}

// ── Premium gradient button ─────────────────────────────────────────────────

class _GsButton extends StatelessWidget {
  final String label;
  final IconData? icon;
  final LinearGradient gradient;
  final VoidCallback? onPressed;
  final bool isLoading;

  const _GsButton({
    required this.label,
    required this.icon,
    required this.gradient,
    required this.onPressed,
    this.isLoading = false,
  });

  @override
  Widget build(BuildContext context) {
    return AnimatedOpacity(
      opacity: onPressed == null && !isLoading ? 0.5 : 1.0,
      duration: const Duration(milliseconds: 200),
      child: Material(
        color: Colors.transparent,
        borderRadius: GsShapes.md,
        child: InkWell(
          onTap: onPressed,
          borderRadius: GsShapes.md,
          child: Ink(
            decoration: BoxDecoration(
              gradient: gradient,
              borderRadius: GsShapes.md,
              boxShadow: [
                BoxShadow(
                  color: gradient.colors.first.withOpacity(0.3),
                  blurRadius: 12,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            padding: const EdgeInsets.symmetric(vertical: 16),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                if (isLoading) ...[
                  const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: Colors.white,
                    ),
                  ),
                  const SizedBox(width: GsSpacing.sm),
                ],
                if (icon != null && !isLoading) ...[
                  Icon(icon, color: Colors.white, size: 20),
                  const SizedBox(width: GsSpacing.sm),
                ],
                Text(
                  label,
                  style: GsTypography.button.copyWith(color: Colors.white),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// ── Driver app selection bottom sheet ────────────────────────────────────────

class _DriverAppSheet extends StatelessWidget {
  final Map<String, bool> installedApps;

  const _DriverAppSheet({required this.installedApps});

  static const _appNames = {
    'com.zomato.delivery': 'Zomato Delivery',
    'in.swiggy.deliveryapp': 'Swiggy Delivery',
    'com.ubercab.driver': 'Uber Driver',
    'com.ola.driver': 'Ola Driver',
  };

  static const _appIcons = {
    'com.zomato.delivery': Icons.restaurant_rounded,
    'in.swiggy.deliveryapp': Icons.delivery_dining_rounded,
    'com.ubercab.driver': Icons.local_taxi_rounded,
    'com.ola.driver': Icons.directions_car_rounded,
  };

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: GsColors.card,
        borderRadius: const BorderRadius.vertical(
          top: Radius.circular(24),
        ),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const SizedBox(height: GsSpacing.md),
          Container(
            width: 40,
            height: 4,
            decoration: BoxDecoration(
              color: GsColors.divider,
              borderRadius: GsShapes.xl,
            ),
          ),
          const SizedBox(height: GsSpacing.lg),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: GsSpacing.lg),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Select Driver App', style: GsTypography.subheading),
                const SizedBox(height: GsSpacing.xs),
                Text(
                  'Choose the app you want to verify with',
                  style: GsTypography.body,
                ),
              ],
            ),
          ),
          const SizedBox(height: GsSpacing.md),
          ..._appNames.entries.map((entry) {
            final installed = installedApps[entry.key] ?? false;
            return _appTile(context, entry.key, entry.value, installed);
          }),
          SizedBox(height: MediaQuery.of(context).padding.bottom + GsSpacing.md),
        ],
      ),
    );
  }

  Widget _appTile(
    BuildContext context,
    String pkg,
    String name,
    bool installed,
  ) {
    return InkWell(
      onTap: () => Navigator.of(context).pop(name),
      child: Padding(
        padding: const EdgeInsets.symmetric(
          horizontal: GsSpacing.lg,
          vertical: GsSpacing.md,
        ),
        child: Row(
          children: [
            Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                color: installed
                    ? GsColors.accent.withOpacity(0.1)
                    : GsColors.surface,
                borderRadius: GsShapes.sm,
              ),
              child: Icon(
                _appIcons[pkg] ?? Icons.apps_rounded,
                color: installed ? GsColors.accent : GsColors.textTertiary,
                size: 22,
              ),
            ),
            const SizedBox(width: GsSpacing.md),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(name, style: GsTypography.subheading.copyWith(fontSize: 14)),
                  Text(
                    installed ? 'Installed' : 'Not detected',
                    style: GsTypography.caption.copyWith(
                      color: installed ? GsColors.success : GsColors.textTertiary,
                    ),
                  ),
                ],
              ),
            ),
            Icon(
              Icons.chevron_right_rounded,
              color: GsColors.textTertiary,
              size: 20,
            ),
          ],
        ),
      ),
    );
  }
}
