import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../bloc/auth/auth_bloc.dart';
import '../../bloc/auth/auth_event.dart';
import '../../bloc/auth/auth_state.dart';
import '../../core/models.dart';
import '../../core/tokens.dart';
import '../../widgets/widgets.dart';
import 'otp_verification_screen.dart';

class PhoneLoginScreen extends StatefulWidget {
  const PhoneLoginScreen({super.key});

  @override
  State<PhoneLoginScreen> createState() => _PhoneLoginScreenState();
}

class _PhoneLoginScreenState extends State<PhoneLoginScreen> {
  final _emailController = TextEditingController();
  String? _localError;

  @override
  void dispose() {
    _emailController.dispose();
    super.dispose();
  }

  void _handleSendOtp() {
    try {
      setState(() => _localError = null);

      final email = _emailController.text.trim().toLowerCase();
      if (email.isEmpty) {
        setState(() => _localError = 'Please enter your email address.');
        return;
      }
      if (!RegExp(r'^[^\s@]+@[^\s@]+\.[^\s@]+$').hasMatch(email)) {
        setState(() => _localError = 'Please enter a valid email address (e.g. name@example.com).');
        return;
      }

      context.read<AuthBloc>().add(AuthSendOtpRequested(email));
    } catch (e, stack) {
      debugPrint('[PhoneLoginScreen._handleSendOtp] UI exception: $e\n$stack');
      setState(() => _localError = 'Unexpected error: ${e.toString().replaceAll('Exception: ', '')}');
    }
  }

  @override
  Widget build(BuildContext context) {
    final c = context.dnd;

    return BlocConsumer<AuthBloc, AuthBlocState>(
      listener: (context, state) {
        if (state is AuthOtpSentState) {
          setState(() => _localError = null);
          Navigator.of(context).push(
            MaterialPageRoute(
              builder: (_) => OtpVerificationScreen(
                phone: state.phone,
                initialTestOtp: state.testOtp,
              ),
            ),
          );
        } else if (state is AuthFailureState) {
          setState(() => _localError = state.error);
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(state.error),
              backgroundColor: c.critical,
              duration: const Duration(seconds: 4),
              action: SnackBarAction(
                label: 'Retry',
                textColor: Colors.white,
                onPressed: _handleSendOtp,
              ),
            ),
          );
        }
      },
      builder: (context, state) {
        final isLoading = state is AuthLoading;

        return Scaffold(
          backgroundColor: c.canvas,
          body: SafeArea(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: Space.s24, vertical: Space.s16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const SizedBox(height: Space.s16),
                  Container(
                    width: 64,
                    height: 64,
                    decoration: BoxDecoration(color: c.accentTint, shape: BoxShape.circle),
                    child: Icon(DndIcons.moon, size: 32, color: c.accent),
                  ),
                  const SizedBox(height: Space.s24),
                  Text('Welcome to Master DND', style: context.text.displayLarge),
                  const SizedBox(height: Space.s8),
                  Text(
                    'Enter your email address to receive a secure 6-digit verification code.',
                    style: context.text.bodyLarge!.copyWith(color: c.textSecondary),
                  ),
                  const SizedBox(height: Space.s32),

                  const OverlineText('Email Address'),
                  const SizedBox(height: Space.s8),

                  DndCard(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: Space.s16, vertical: 4),
                      child: Row(
                        children: [
                          Icon(Icons.mail_outline, size: 20, color: c.textSecondary),
                          const SizedBox(width: Space.s12),
                          Expanded(
                            child: TextField(
                              controller: _emailController,
                              keyboardType: TextInputType.emailAddress,
                              autocorrect: false,
                              autofillHints: const [AutofillHints.email],
                              style: context.text.titleMedium,
                              decoration: const InputDecoration(
                                hintText: 'you@example.com',
                                border: InputBorder.none,
                              ),
                              onSubmitted: (_) => _handleSendOtp(),
                            ),
                          ),
                        ],
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
                  const SizedBox(height: Space.s16),
                  Container(
                    padding: const EdgeInsets.all(Space.s12),
                    decoration: BoxDecoration(
                      color: c.surfaceAlt,
                      borderRadius: BorderRadius.circular(Radii.input),
                    ),
                    child: Row(
                      children: [
                        Icon(Icons.mark_email_read_outlined, size: 18, color: c.accent),
                        const SizedBox(width: Space.s8),
                        Expanded(
                          child: Text(
                            'A real 6-digit verification code will be sent to your email inbox.',
                            style: context.text.bodySmall!.copyWith(color: c.textSecondary),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const Spacer(),
                  if (isLoading)
                    const Center(child: CircularProgressIndicator())
                  else
                    AppButton('Send Verification Code', onPressed: _handleSendOtp),
                  const SizedBox(height: Space.s12),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}
