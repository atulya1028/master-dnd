import 'package:flutter_bloc/flutter_bloc.dart';

import '../../core/api_service.dart';
import '../../core/models.dart';
import 'auth_event.dart';
import 'auth_state.dart';

class AuthBloc extends Bloc<AuthEvent, AuthBlocState> {
  AuthBloc({ApiService? apiService})
      : _api = apiService ?? ApiService.instance,
        super(const AuthInitial()) {
    on<AuthCheckRequested>(_onCheckRequested);
    on<AuthSendOtpRequested>(_onSendOtpRequested);
    on<AuthVerifyOtpRequested>(_onVerifyOtpRequested);
    on<AuthResendOtpRequested>(_onResendOtpRequested);
    on<AuthCompleteProfileRequested>(_onCompleteProfileRequested);
    on<AuthUpdateProfileRequested>(_onUpdateProfileRequested);
    on<AuthToggleDndRequested>(_onToggleDndRequested);
    on<AuthLogoutRequested>(_onLogoutRequested);
  }

  final ApiService _api;

  UserModel? get currentUser => switch (state) {
        AuthenticatedState(:final user) => user,
        AuthNeedsProfileFormState(:final user) => user,
        _ => null,
      };

  Future<void> _onCheckRequested(
    AuthCheckRequested event,
    Emitter<AuthBlocState> emit,
  ) async {
    emit(const AuthLoading(message: 'Checking session...'));
    try {
      final token = await _api.getToken();
      if (token == null || token.isEmpty) {
        emit(const AuthUnauthenticated());
        return;
      }

      final profile = await _api.getProfile().timeout(const Duration(seconds: 4));
      if (!profile.isProfileComplete || profile.name.trim().isEmpty) {
        emit(AuthNeedsProfileFormState(user: profile));
      } else {
        emit(AuthenticatedState(user: profile));
      }
    } catch (_) {
      await _api.clearSession();
      emit(const AuthUnauthenticated());
    }
  }

  Future<void> _onSendOtpRequested(
    AuthSendOtpRequested event,
    Emitter<AuthBlocState> emit,
  ) async {
    final previous = state;
    emit(const AuthLoading(message: 'Sending verification code...'));
    try {
      final res = await _api.sendOtp(event.phone);
      emit(AuthOtpSentState(
        phone: event.phone,
        testOtp: res['testOtp']?.toString(),
        expiresInSeconds: (res['expiresInSeconds'] as num?)?.toInt() ?? 300,
      ));
    } catch (e) {
      emit(AuthFailureState(
        error: e.toString().replaceAll('Exception: ', ''),
        previousState: previous,
      ));
    }
  }

  Future<void> _onVerifyOtpRequested(
    AuthVerifyOtpRequested event,
    Emitter<AuthBlocState> emit,
  ) async {
    final previous = state;
    emit(const AuthLoading(message: 'Verifying code...'));
    try {
      final res = await _api.verifyOtp(event.phone, event.otp);
      final isProfileComplete = res['isProfileComplete'] == true;
      final userMap = res['user'] as Map<String, dynamic>? ?? {};
      final user = UserModel.fromJson(userMap);

      if (!isProfileComplete || user.name.trim().isEmpty) {
        emit(AuthNeedsProfileFormState(user: user));
      } else {
        emit(AuthenticatedState(user: user));
      }
    } catch (e) {
      emit(AuthFailureState(
        error: e.toString().replaceAll('Exception: ', ''),
        previousState: previous,
      ));
    }
  }

  Future<void> _onResendOtpRequested(
    AuthResendOtpRequested event,
    Emitter<AuthBlocState> emit,
  ) async {
    try {
      final res = await _api.sendOtp(event.phone);
      emit(AuthOtpSentState(
        phone: event.phone,
        testOtp: res['testOtp']?.toString(),
      ));
    } catch (e) {
      emit(AuthFailureState(
        error: e.toString().replaceAll('Exception: ', ''),
        previousState: state,
      ));
    }
  }

  Future<void> _onCompleteProfileRequested(
    AuthCompleteProfileRequested event,
    Emitter<AuthBlocState> emit,
  ) async {
    final previous = state;
    emit(const AuthLoading(message: 'Saving profile...'));
    try {
      final updated = await _api.updateProfile(
        name: event.name,
        email: event.email,
        avatar: event.avatar,
        bio: event.bio,
      );
      emit(AuthenticatedState(user: updated));
    } catch (e) {
      emit(AuthFailureState(
        error: e.toString().replaceAll('Exception: ', ''),
        previousState: previous,
      ));
    }
  }

  Future<void> _onUpdateProfileRequested(
    AuthUpdateProfileRequested event,
    Emitter<AuthBlocState> emit,
  ) async {
    final user = currentUser;
    if (user == null) return;

    try {
      final updated = await _api.updateProfile(
        name: event.name,
        email: event.email,
        avatar: event.avatar,
        bio: event.bio,
      );
      emit(AuthenticatedState(user: updated));
    } catch (e) {
      emit(AuthFailureState(
        error: e.toString().replaceAll('Exception: ', ''),
        previousState: state,
      ));
    }
  }

  Future<void> _onToggleDndRequested(
    AuthToggleDndRequested event,
    Emitter<AuthBlocState> emit,
  ) async {
    final user = currentUser;
    if (user == null) return;

    final target = event.enabled ?? !user.dndEnabled;
    // Optimistic update
    final optimisticUser = user.copyWith(dndEnabled: target);
    emit(AuthenticatedState(user: optimisticUser));

    try {
      final actualState = await _api.toggleMasterDnd(enabled: target);
      if (actualState != target) {
        emit(AuthenticatedState(user: user.copyWith(dndEnabled: actualState)));
      }
    } catch (_) {
      // Revert if API fails
      emit(AuthenticatedState(user: user));
    }
  }

  Future<void> _onLogoutRequested(
    AuthLogoutRequested event,
    Emitter<AuthBlocState> emit,
  ) async {
    await _api.clearSession();
    emit(const AuthUnauthenticated());
  }
}
