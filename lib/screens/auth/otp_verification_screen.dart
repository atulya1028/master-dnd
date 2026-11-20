import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../bloc/auth/auth_bloc.dart';
import '../../bloc/auth/auth_event.dart';
import '../../bloc/auth/auth_state.dart';
import '../../core/tokens.dart';
import '../../widgets/widgets.dart';
import '../splash_screen.dart';

class OtpVerificationScreen extends StatefulWidget {
  const OtpVerificationScreen({
    super.key,
    required this.phone,
    this.initialTestOtp,
  });

  final String phone;
  final String? initialTestOtp;

  @override
  State<OtpVerificationScreen> createState() => _OtpVerificationScreenState();
}

class _OtpVerificationScreenState extends State<OtpVerificationScreen> {
  final _otpController = TextEditingController();
  final _focusNode = FocusNode();

  String? _localError;
  int _secondsRemaining = 60;
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _startCountdown();
  }

  void _startCountdown() {
    _secondsRemaining = 60;
    _timer?.cancel();
    _timer = Timer.periodic(const Duration(seconds: 1), (t) {
      if (_secondsRemaining > 0) {
        setState(() => _secondsRemaining--);
      } else {
        t.cancel();
      }
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    _otpController.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  void _handleVerify() {
    try {
      final code = _otpController.text.trim();
      if (code.length < 6) {
        setState(() => _localError = 'Please enter the complete 6-digit code.');
        return;
      }

      setState(() => _localError = null);
      context.read<AuthBloc>().add(AuthVerifyOtpRequested(
            phone: widget.phone,
            otp: code,
          ));
    } catch (e, stack) {
      debugPrint('[OtpVerificationScreen._handleVerify] Error: $e\n$stack');
      setState(() => _localError = 'Error: ${e.toString().replaceAll('Exception: ', '')}');
    }
  }

  void _handleResend() {
    try {
      if (_secondsRemaining > 0) return;
      setState(() => _localError = null);
      context.read<AuthBloc>().add(AuthResendOtpRequested(widget.phone));
    } catch (e, stack) {
      debugPrint('[OtpVerificationScreen._handleResend] Error: $e\n$stack');
      setState(() => _localError = 'Resend error: ${e.toString().replaceAll('Exception: ', '')}');
    }
  }

  @override
  Widget build(BuildContext context) {
    final c = context.dnd;

    return BlocConsumer<AuthBloc, AuthBlocState>(
      listener: (context, state) {
        if (state is AuthNeedsProfileFormState || state is AuthenticatedState) {
          Navigator.of(context).pushAndRemoveUntil(
            MaterialPageRoute(builder: (_) => const AuthGate()),
            (route) => false,
          );
        } else if (state is AuthOtpSentState) {
          setState(() {
            _otpController.clear();
            _localError = null;
          });
          _startCountdown();
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('A new verification code has been sent.')),
          );
        } else if (state is AuthFailureState) {
          setState(() => _localError = state.error);
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(state.error),
              backgroundColor: c.critical,
              duration: const Duration(seconds: 4),
            ),
          );
        }
      },
      builder: (context, state) {
        final isLoading = state is AuthLoading;

        return Scaffold(
          backgroundColor: c.canvas,
          body: SafeArea(
            child: LayoutBuilder(
              builder: (context, constraints) {
                return SingleChildScrollView(
                  keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
                  padding: const EdgeInsets.symmetric(horizontal: Space.s24, vertical: Space.s16),
                  child: ConstrainedBox(
                    constraints: BoxConstraints(
                      minHeight: constraints.maxHeight - Space.s32,
                    ),
                    child: IntrinsicHeight(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          IconButton(
                            onPressed: () => Navigator.of(context).pop(),
                            icon: const Icon(Icons.arrow_back),
                            padding: EdgeInsets.zero,
                            alignment: Alignment.centerLeft,
                          ),
                          const SizedBox(height: Space.s16),
                          Text('Verify Email Address', style: context.text.displayLarge),
                          const SizedBox(height: Space.s8),
                          Wrap(
                            crossAxisAlignment: WrapCrossAlignment.center,
                            children: [
                              Text(
                                'Code sent to ',
                                style: context.text.bodyMedium!.copyWith(color: c.textSecondary),
                              ),
                              Text(
                                widget.phone,
                                style: context.text.labelLarge!.copyWith(color: c.accent, fontWeight: FontWeight.bold),
                              ),
                            ],
                          ),
                          const SizedBox(height: Space.s4),
                          Text(
                            'Check your inbox or spam folder.',
                            style: context.text.bodySmall!.copyWith(color: c.textSecondary),
                          ),
                          const SizedBox(height: Space.s32),

                          const OverlineText('6-Digit Verification Code'),
                          const SizedBox(height: Space.s8),
                          DndCard(
                            child: Padding(
                              padding: const EdgeInsets.symmetric(horizontal: Space.s16, vertical: 4),
                              child: TextField(
                                controller: _otpController,
                                focusNode: _focusNode,
                                keyboardType: TextInputType.number,
                                maxLength: 6,
                                textAlign: TextAlign.center,
                                style: context.text.displayLarge!.copyWith(
                                  letterSpacing: 16,
                                  color: c.accent,
                                ),
                                decoration: const InputDecoration(
                                  hintText: '••••••',
                                  counterText: '',
                                  border: InputBorder.none,
                                ),
                                onChanged: (val) {
                                  if (val.length == 6) {
                                    _handleVerify();
                                  }
                                },
                              ),
                            ),
                          ),

                          if (_localError != null) ...[
                            const SizedBox(height: Space.s12),
                            Text(
                              _localError!,
                              style: context.text.bodySmall!.copyWith(color: c.critical),
                            ),
                          ],

                          const SizedBox(height: Space.s24),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text(
                                _secondsRemaining > 0
                                    ? 'Resend code in ${_secondsRemaining}s'
                                    : "Didn't receive the code?",
                                style: context.text.bodyMedium!.copyWith(color: c.textSecondary),
                              ),
                              TextButton(
                                onPressed: _secondsRemaining == 0 ? _handleResend : null,
                                child: Text(
                                  'Resend Code',
                                  style: context.text.labelLarge!.copyWith(
                                    color: _secondsRemaining == 0 ? c.accent : c.border,
                                  ),
                                ),
                              ),
                            ],
                          ),

                          const Spacer(),
                          const SizedBox(height: Space.s24),
                          if (isLoading)
                            const Center(child: CircularProgressIndicator())
                          else
                            AppButton('Verify & Continue', onPressed: _handleVerify),
                          const SizedBox(height: Space.s12),
                        ],
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
        );
      },
    );
  }
}
