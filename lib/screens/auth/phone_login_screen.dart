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
  final _phoneController = TextEditingController();
  final _emailController = TextEditingController();

  bool _isEmailMode = false;
  String _selectedCountryCode = '+1';
  String? _localError;

  final List<String> _countryCodes = const [
    '+1',   // US / Canada
    '+91',  // India
    '+44',  // UK
    '+61',  // Australia
    '+49',  // Germany
    '+33',  // France
    '+81',  // Japan
    '+65',  // Singapore
    '+971', // UAE
  ];

  @override
  void dispose() {
    _phoneController.dispose();
    _emailController.dispose();
    super.dispose();
  }

  void _handleSendOtp() {
    setState(() => _localError = null);

    if (_isEmailMode) {
      final email = _emailController.text.trim().toLowerCase();
      if (email.isEmpty) {
        setState(() => _localError = 'Please enter your email address.');
        return;
      }
      if (!RegExp(r'^[^\s@]+@[^\s@]+\.[^\s@]+$').hasMatch(email)) {
        setState(() => _localError = 'Please enter a valid email address.');
        return;
      }

      context.read<AuthBloc>().add(AuthSendOtpRequested(email));
    } else {
      final rawNumber = _phoneController.text.trim().replaceAll(RegExp(r'\s+'), '');
      if (rawNumber.isEmpty) {
        setState(() => _localError = 'Please enter your phone number.');
        return;
      }
      if (rawNumber.length < 7) {
        setState(() => _localError = 'Phone number is too short.');
        return;
      }

      final fullPhone = '$_selectedCountryCode$rawNumber';
      context.read<AuthBloc>().add(AuthSendOtpRequested(fullPhone));
    }
  }

  @override
  Widget build(BuildContext context) {
    final c = context.dnd;

    return BlocConsumer<AuthBloc, AuthBlocState>(
      listener: (context, state) {
        if (state is AuthOtpSentState) {
          Navigator.of(context).push(
            MaterialPageRoute(
              builder: (_) => OtpVerificationScreen(
                phone: state.phone,
                initialTestOtp: state.testOtp,
              ),
            ),
          );
        } else if (state is AuthFailureState) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(state.error),
              backgroundColor: c.critical,
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
                    _isEmailMode
                        ? 'Enter your email address to receive a 6-digit verification code.'
                        : 'Enter your mobile number to sign in or create your quiet account.',
                    style: context.text.bodyLarge!.copyWith(color: c.textSecondary),
                  ),
                  const SizedBox(height: Space.s24),

                  // Auth Mode Switch (Phone vs Email)
                  Row(
                    children: [
                      Expanded(
                        child: GestureDetector(
                          onTap: () => setState(() {
                            _isEmailMode = false;
                            _localError = null;
                          }),
                          child: Container(
                            height: 40,
                            decoration: BoxDecoration(
                              color: !_isEmailMode ? c.accent : c.surface,
                              borderRadius: BorderRadius.circular(Radii.pill),
                              border: Border.all(color: !_isEmailMode ? c.accent : c.border),
                            ),
                            alignment: Alignment.center,
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(Icons.phone_android,
                                    size: 16, color: !_isEmailMode ? c.onAccent : c.textSecondary),
                                const SizedBox(width: 6),
                                Text(
                                  'Phone',
                                  style: context.text.labelLarge!.copyWith(
                                    color: !_isEmailMode ? c.onAccent : c.textSecondary,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: Space.s12),
                      Expanded(
                        child: GestureDetector(
                          onTap: () => setState(() {
                            _isEmailMode = true;
                            _localError = null;
                          }),
                          child: Container(
                            height: 40,
                            decoration: BoxDecoration(
                              color: _isEmailMode ? c.accent : c.surface,
                              borderRadius: BorderRadius.circular(Radii.pill),
                              border: Border.all(color: _isEmailMode ? c.accent : c.border),
                            ),
                            alignment: Alignment.center,
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(Icons.mail_outline,
                                    size: 16, color: _isEmailMode ? c.onAccent : c.textSecondary),
                                const SizedBox(width: 6),
                                Text(
                                  'Email',
                                  style: context.text.labelLarge!.copyWith(
                                    color: _isEmailMode ? c.onAccent : c.textSecondary,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: Space.s24),

                  OverlineText(_isEmailMode ? 'Email Address' : 'Mobile Number'),
                  const SizedBox(height: Space.s8),

                  if (_isEmailMode) ...[
                    DndCard(
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: Space.s16, vertical: 4),
                        child: TextField(
                          controller: _emailController,
                          keyboardType: TextInputType.emailAddress,
                          autocorrect: false,
                          style: context.text.titleMedium,
                          decoration: const InputDecoration(
                            hintText: 'name@example.com',
                            border: InputBorder.none,
                          ),
                          onSubmitted: (_) => _handleSendOtp(),
                        ),
                      ),
                    ),
                  ] else ...[
                    DndCard(
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: Space.s16, vertical: 4),
                        child: Row(
                          children: [
                            DropdownButtonHideUnderline(
                              child: DropdownButton<String>(
                                value: _selectedCountryCode,
                                icon: Icon(Icons.arrow_drop_down, color: c.textSecondary),
                                items: _countryCodes.map((code) {
                                  return DropdownMenuItem<String>(
                                    value: code,
                                    child: Text(code, style: context.text.titleMedium),
                                  );
                                }).toList(),
                                onChanged: (val) {
                                  if (val != null) setState(() => _selectedCountryCode = val);
                                },
                              ),
                            ),
                            Container(
                              height: 24,
                              width: 1,
                              color: c.border,
                              margin: const EdgeInsets.symmetric(horizontal: Space.s8),
                            ),
                            Expanded(
                              child: TextField(
                                controller: _phoneController,
                                keyboardType: TextInputType.phone,
                                style: context.text.titleMedium,
                                decoration: const InputDecoration(
                                  hintText: '555 019 2834',
                                  border: InputBorder.none,
                                ),
                                onSubmitted: (_) => _handleSendOtp(),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],

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
                        Icon(Icons.lock_outline, size: 18, color: c.textSecondary),
                        const SizedBox(width: Space.s8),
                        Expanded(
                          child: Text(
                            _isEmailMode
                                ? 'A 6-digit OTP will be delivered directly to your email inbox.'
                                : 'A 6-digit OTP will be generated for instant verification.',
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
