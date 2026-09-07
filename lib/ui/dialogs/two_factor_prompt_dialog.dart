import 'dart:async';
import 'dart:ui';
import 'package:flutter/material.dart';
import '../../Models/two_factor_challenge.dart';
import '../../Services/biometric_service.dart';
import '../../Services/two_factor_auth_service.dart';
import '../../main.dart';

/// Shows the 2FA login verification prompt modal using a local BuildContext
Future<bool?> showTwoFactorPromptDialog(
  BuildContext context, {
  required TwoFactorChallenge challenge,
  required String employeeId,
}) async {
  return showDialog<bool>(
    context: context,
    barrierDismissible: false,
    barrierColor: Colors.transparent,
    builder: (_) => _TwoFactorPromptDialog(
      challenge: challenge,
      employeeId: employeeId,
    ),
  );
}

/// Shows the 2FA login verification prompt modal using global navigatorKey
Future<bool?> showGlobalTwoFactorPrompt({
  required TwoFactorChallenge challenge,
  required String employeeId,
}) async {
  final ctx = navigatorKey.currentContext;
  if (ctx != null && ctx.mounted) {
    return showTwoFactorPromptDialog(
      ctx,
      challenge: challenge,
      employeeId: employeeId,
    );
  }
  return null;
}

class _TwoFactorPromptDialog extends StatefulWidget {
  final TwoFactorChallenge challenge;
  final String employeeId;

  const _TwoFactorPromptDialog({
    required this.challenge,
    required this.employeeId,
  });

  @override
  State<_TwoFactorPromptDialog> createState() => _TwoFactorPromptDialogState();
}

class _TwoFactorPromptDialogState extends State<_TwoFactorPromptDialog>
    with SingleTickerProviderStateMixin {
  late int _remainingSeconds;
  Timer? _countdownTimer;
  bool _isProcessing = false;
  String? _processingAction; // 'APPROVED' or 'DECLINED'
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _remainingSeconds = widget.challenge.remainingSeconds;
    if (_remainingSeconds <= 0) {
      _remainingSeconds = 0;
    } else {
      _countdownTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
        if (!mounted) return;
        if (_remainingSeconds > 1) {
          setState(() {
            _remainingSeconds--;
          });
        } else {
          setState(() {
            _remainingSeconds = 0;
          });
          timer.cancel();
        }
      });
    }
  }

  @override
  void dispose() {
    _countdownTimer?.cancel();
    super.dispose();
  }

  Future<void> _handleDecision(String action) async {
    if (_isProcessing || _remainingSeconds <= 0) return;

    setState(() {
      _isProcessing = true;
      _processingAction = action;
      _errorMessage = null;
    });

    bool biometricSuccess = false;

    // If approving, optionally verify biometric if device supports it
    if (action == 'APPROVED') {
      final bio = BiometricService();
      final canUseBio = await bio.canUseBiometric();
      if (canUseBio) {
        final authenticated = await bio.authenticate();
        if (!authenticated) {
          if (!mounted) return;
          setState(() {
            _isProcessing = false;
            _processingAction = null;
            _errorMessage = "Biometric authentication required to approve login.";
          });
          return;
        }
        biometricSuccess = true;
      }
    }

    final res = await TwoFactorAuthService.respondToChallenge(
      challengeId: widget.challenge.challengeId,
      employeeId: widget.employeeId,
      action: action,
      biometricVerified: biometricSuccess,
    );

    if (!mounted) return;

    if (res["success"] == true) {
      Navigator.of(context, rootNavigator: true).pop(action == 'APPROVED');
      // Always return to the main screen of the app
      navigatorKey.currentState?.popUntil((route) => route.isFirst);
      _showFeedbackSnackBar(
        isApproved: action == 'APPROVED',
        message: action == 'APPROVED'
            ? "Website login approved successfully."
            : "Website login request declined.",
      );
    } else {
      setState(() {
        _isProcessing = false;
        _processingAction = null;
        _errorMessage = res["message"] ?? "Failed to respond. Please try again.";
      });
    }
  }

  void _showFeedbackSnackBar({required bool isApproved, required String message}) {
    final messengerContext = navigatorKey.currentContext ?? context;
    ScaffoldMessenger.of(messengerContext).showSnackBar(
      SnackBar(
        behavior: SnackBarBehavior.floating,
        backgroundColor: Colors.transparent,
        elevation: 0,
        margin: const EdgeInsets.fromLTRB(16, 0, 16, 24),
        duration: const Duration(seconds: 3),
        content: Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          decoration: BoxDecoration(
            color: isApproved ? const Color(0xFF2E7D32) : const Color(0xFFC62828),
            borderRadius: BorderRadius.circular(16),
            boxShadow: [
              BoxShadow(
                color: (isApproved ? const Color(0xFF2E7D32) : const Color(0xFFC62828))
                    .withValues(alpha: 0.35),
                blurRadius: 16,
                offset: const Offset(0, 6),
              ),
            ],
          ),
          child: Row(
            children: [
              Icon(
                isApproved ? Icons.verified_user_rounded : Icons.shield_outlined,
                color: Colors.white,
                size: 22,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  message,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 13.5,
                    fontWeight: FontWeight.w600,
                    height: 1.3,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final w = MediaQuery.of(context).size.width;
    final dialogW = (w * 0.92).clamp(300.0, 420.0);
    final isExpired = _remainingSeconds <= 0;
    final totalDuration = widget.challenge.expiresInSeconds > 0
        ? widget.challenge.expiresInSeconds
        : 90;
    final progress = totalDuration > 0
        ? (_remainingSeconds / totalDuration).clamp(0.0, 1.0)
        : 0.0;

    return Stack(
      children: [
        BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 7, sigmaY: 7),
          child: Container(color: Colors.black.withValues(alpha: 0.35)),
        ),
        Center(
          child: Dialog(
            backgroundColor: Colors.white,
            elevation: 12,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(22)),
            insetPadding: const EdgeInsets.all(16),
            child: SizedBox(
              width: dialogW,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(22, 26, 22, 22),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // Shield Icon with security pulse styling
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: isExpired
                            ? Colors.grey.shade100
                            : const Color(0xFF0060A6).withValues(alpha: 0.1),
                        shape: BoxShape.circle,
                      ),
                      child: Icon(
                        isExpired
                            ? Icons.timer_off_outlined
                            : Icons.security_rounded,
                        size: 40,
                        color: isExpired
                            ? Colors.grey.shade600
                            : const Color(0xFF0060A6),
                      ),
                    ),
                    const SizedBox(height: 14),

                    // Title
                    Text(
                      isExpired ? "Request Expired" : "Sign-in Request",
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w800,
                        color: isExpired ? Colors.grey.shade700 : const Color(0xFF1A1A2E),
                      ),
                    ),
                    const SizedBox(height: 6),

                    // Message
                    Text(
                      isExpired
                          ? "This login attempt has timed out."
                          : "Are you trying to sign in to ${widget.challenge.websiteName.isNotEmpty ? widget.challenge.websiteName : 'Terminal Prime'}?",
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 14.5,
                        fontWeight: FontWeight.w500,
                        color: Colors.grey.shade700,
                        height: 1.4,
                      ),
                    ),
                    const SizedBox(height: 18),

                    // Verification Number Box
                    if (!isExpired &&
                        widget.challenge.securityCode != null &&
                        widget.challenge.securityCode!.isNotEmpty) ...[
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.symmetric(vertical: 20),
                        decoration: BoxDecoration(
                          color: const Color(0xFFF0F7FF),
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(
                            color: const Color(0xFF0060A6).withValues(alpha: 0.25),
                            width: 1.5,
                          ),
                        ),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              widget.challenge.securityCode!,
                              style: const TextStyle(
                                fontSize: 48,
                                fontWeight: FontWeight.w900,
                                letterSpacing: 6.0,
                                color: Color(0xFF0060A6),
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              "Verification Number",
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                                color: Colors.grey.shade600,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 16),
                    ],

                    // Countdown Progress Bar
                    if (!isExpired) ...[
                      ClipRRect(
                        borderRadius: BorderRadius.circular(6),
                        child: LinearProgressIndicator(
                          value: progress,
                          minHeight: 5,
                          backgroundColor: Colors.grey.shade200,
                          valueColor: AlwaysStoppedAnimation<Color>(
                            progress > 0.3
                                ? const Color(0xFF0060A6)
                                : const Color(0xFFE53935),
                          ),
                        ),
                      ),
                      const SizedBox(height: 6),
                      Align(
                        alignment: Alignment.centerRight,
                        child: Text(
                          "Expires in ${_remainingSeconds}s",
                          style: TextStyle(
                            fontSize: 11.5,
                            fontWeight: FontWeight.w600,
                            color: progress > 0.3
                                ? Colors.grey.shade600
                                : const Color(0xFFE53935),
                          ),
                        ),
                      ),
                    ],

                    // Error message
                    if (_errorMessage != null) ...[
                      const SizedBox(height: 12),
                      Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: Colors.red.shade50,
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Row(
                          children: [
                            const Icon(Icons.error_outline_rounded,
                                size: 16, color: Colors.red),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                _errorMessage!,
                                style: TextStyle(
                                  color: Colors.red.shade800,
                                  fontSize: 12,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],

                    const SizedBox(height: 22),

                    // Actions (2 Buttons: Decline & Approve)
                    if (isExpired) ...[
                      SizedBox(
                        width: double.infinity,
                        height: 48,
                        child: OutlinedButton(
                          onPressed: () {
                            Navigator.of(context, rootNavigator: true).pop(false);
                            navigatorKey.currentState?.popUntil((route) => route.isFirst);
                          },
                          style: OutlinedButton.styleFrom(
                            side: BorderSide(color: Colors.grey.shade400),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                          child: const Text(
                            "Dismiss",
                            style: TextStyle(
                              fontSize: 14.5,
                              fontWeight: FontWeight.w600,
                              color: Colors.black87,
                            ),
                          ),
                        ),
                      ),
                    ] else ...[
                      Row(
                        children: [
                          // Decline Button
                          Expanded(
                            flex: 1,
                            child: SizedBox(
                              height: 48,
                              child: OutlinedButton(
                                onPressed: _isProcessing
                                    ? null
                                    : () => _handleDecision('DECLINED'),
                                style: OutlinedButton.styleFrom(
                                  side: BorderSide(
                                    color: Colors.red.shade400,
                                    width: 1.4,
                                  ),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                ),
                                child: _isProcessing && _processingAction == 'DECLINED'
                                    ? const SizedBox(
                                        width: 20,
                                        height: 20,
                                        child: CircularProgressIndicator(
                                          strokeWidth: 2,
                                          color: Colors.red,
                                        ),
                                      )
                                    : const Text(
                                        "Decline",
                                        style: TextStyle(
                                          fontSize: 15,
                                          fontWeight: FontWeight.w700,
                                          color: Colors.red,
                                        ),
                                      ),
                              ),
                            ),
                          ),
                          const SizedBox(width: 12),

                          // Approve Button
                          Expanded(
                            flex: 1,
                            child: SizedBox(
                              height: 48,
                              child: ElevatedButton(
                                onPressed: _isProcessing
                                    ? null
                                    : () => _handleDecision('APPROVED'),
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: const Color(0xFF2E7D32),
                                  elevation: 0,
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                ),
                                child: _isProcessing && _processingAction == 'APPROVED'
                                    ? const SizedBox(
                                        width: 20,
                                        height: 20,
                                        child: CircularProgressIndicator(
                                          strokeWidth: 2,
                                          color: Colors.white,
                                        ),
                                      )
                                    : const Row(
                                        mainAxisAlignment: MainAxisAlignment.center,
                                        children: [
                                          Icon(Icons.check_rounded,
                                              size: 20, color: Colors.white),
                                          SizedBox(width: 6),
                                          Text(
                                            "Approve",
                                            style: TextStyle(
                                              fontSize: 15,
                                              fontWeight: FontWeight.w700,
                                              color: Colors.white,
                                            ),
                                          ),
                                        ],
                                      ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ],
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}
