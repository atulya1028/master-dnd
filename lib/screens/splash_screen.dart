import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../bloc/auth/auth_bloc.dart';
import '../bloc/auth/auth_event.dart';
import '../bloc/auth/auth_state.dart';
import '../core/models.dart';
import '../core/tokens.dart';
import 'app_shell.dart';
import 'auth/phone_login_screen.dart';
import 'auth/profile_form_screen.dart';

/// App entry gate powered by BloC: checks auth status and dynamically routes
/// to Phone Login, Profile Setup Form, or Dashboard.
class AuthGate extends StatefulWidget {
  const AuthGate({super.key});

  @override
  State<AuthGate> createState() => _AuthGateState();
}

class _AuthGateState extends State<AuthGate> {
  Timer? _safetyTimer;

  @override
  void initState() {
    super.initState();
    try {
      if (context.read<AuthBloc>().state is AuthInitial) {
        context.read<AuthBloc>().add(const AuthCheckRequested());
      }
      // Safety guard: if session check takes longer than 4 seconds,
      // fallback to PhoneLoginScreen automatically so the user is never stuck on splash.
      _safetyTimer = Timer(const Duration(seconds: 4), () {
        if (mounted && context.read<AuthBloc>().state is AuthInitial) {
          debugPrint('[AuthGate] Session check timed out after 4s; showing login screen.');
          context.read<AuthBloc>().add(const AuthLogoutRequested());
        }
      });
    } catch (e, stack) {
      debugPrint('[AuthGate.initState] Error: $e\n$stack');
    }
  }

  @override
  void dispose() {
    _safetyTimer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final c = context.dnd;

    return BlocBuilder<AuthBloc, AuthBlocState>(
      buildWhen: (previous, current) {
        // Only trigger full-screen route switches on significant auth state changes.
        // Transient operational states (AuthLoading, AuthOtpSentState, AuthFailureState)
        // are handled locally by PhoneLoginScreen & OtpVerificationScreen.
        return current is AuthInitial ||
            current is AuthUnauthenticated ||
            current is AuthNeedsProfileFormState ||
            current is AuthenticatedState;
      },
      builder: (context, state) {
        return switch (state) {
          AuthInitial() => Scaffold(
              backgroundColor: c.canvas,
              body: Center(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.all(Space.s24),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Container(
                        width: 88,
                        height: 88,
                        decoration: BoxDecoration(color: c.accentTint, shape: BoxShape.circle),
                        child: Icon(DndIcons.moon, size: 44, color: c.accent),
                      ),
                      const SizedBox(height: Space.s24),
                      Text('Master DND', style: context.text.displayLarge),
                      const SizedBox(height: Space.s16),
                      SizedBox(
                        width: 24,
                        height: 24,
                        child: CircularProgressIndicator(strokeWidth: 2.5, color: c.accent),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          AuthNeedsProfileFormState() => const ProfileFormScreen(),
          AuthenticatedState() => const AppShell(),
          _ => const PhoneLoginScreen(),
        };
      },
    );
  }
}
