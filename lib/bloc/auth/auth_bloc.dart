import 'dart:async';
import 'package:flutter/foundation.dart';
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
    on<AuthAddCustomDurationRequested>(_onAddCustomDuration);
    on<AuthRemoveCustomDurationRequested>(_onRemoveCustomDuration);
    on<AuthAddContactRequested>(_onAddContact);
    on<AuthDeleteContactRequested>(_onDeleteContact);
    on<AuthAddCustomWhitelistRequested>(_onAddCustomWhitelist);
    on<AuthRefreshUserRequested>(_onRefreshUser);
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
    } catch (e, stack) {
      debugPrint('[AuthBloc._onCheckRequested] Session check error: $e\n$stack');
      try {
        await _api.clearSession();
      } catch (_) {}
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
      final res = await _api.sendOtp(event.phone).timeout(
        const Duration(seconds: 15),
        onTimeout: () => throw TimeoutException('Request timed out while connecting to the backend.'),
      );
      emit(AuthOtpSentState(
        phone: event.phone,
        testOtp: res['testOtp']?.toString(),
        expiresInSeconds: (res['expiresInSeconds'] as num?)?.toInt() ?? 300,
      ));
    } catch (e, stack) {
      debugPrint('[AuthBloc._onSendOtpRequested] Error: $e\n$stack');
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
      final res = await _api.verifyOtp(event.phone, event.otp).timeout(
        const Duration(seconds: 15),
        onTimeout: () => throw TimeoutException('Verification timed out. Please try again.'),
      );
      final isProfileComplete = res['isProfileComplete'] == true;
      final userMap = res['user'] as Map<String, dynamic>? ?? {};
      final user = UserModel.fromJson(userMap);

      if (!isProfileComplete || user.name.trim().isEmpty) {
        emit(AuthNeedsProfileFormState(user: user));
      } else {
        emit(AuthenticatedState(user: user));
      }
    } catch (e, stack) {
      debugPrint('[AuthBloc._onVerifyOtpRequested] Error: $e\n$stack');
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
    final previous = state;
    emit(const AuthLoading(message: 'Resending verification code...'));
    try {
      final res = await _api.sendOtp(event.phone).timeout(
        const Duration(seconds: 15),
        onTimeout: () => throw TimeoutException('Resend timed out. Please try again.'),
      );
      emit(AuthOtpSentState(
        phone: event.phone,
        testOtp: res['testOtp']?.toString(),
      ));
    } catch (e, stack) {
      debugPrint('[AuthBloc._onResendOtpRequested] Error: $e\n$stack');
      emit(AuthFailureState(
        error: e.toString().replaceAll('Exception: ', ''),
        previousState: previous,
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
        phone: event.phone,
        avatar: event.avatar,
        bio: event.bio,
        notificationPreferences: event.notificationPreferences,
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
    final optimisticUser = user.copyWith(
      dndEnabled: target,
      activeSessionStart: target ? DateTime.now() : null,
      clearActiveSessionStart: !target,
      activeSessionPlannedMinutes: event.durationMinutes ?? user.activeSessionPlannedMinutes,
      activeSessionEndTime: target ? event.endTime : null,
      clearActiveSessionEndTime: !target,
      activeProfileName: event.profileName ?? user.activeProfileName,
    );
    emit(AuthenticatedState(user: optimisticUser));

    try {
      final res = await _api.toggleMasterDnd(
        enabled: target,
        durationMinutes: event.durationMinutes,
        endTime: event.endTime,
        profileName: event.profileName,
      );
      if (res['user'] is Map<String, dynamic>) {
        emit(AuthenticatedState(user: UserModel.fromJson(res['user'] as Map<String, dynamic>)));
      } else if (res['dndEnabled'] != target) {
        emit(AuthenticatedState(user: user.copyWith(dndEnabled: res['dndEnabled'] == true)));
      }
    } catch (_) {
      emit(AuthenticatedState(user: user));
    }
  }

  Future<void> _onAddCustomDuration(
    AuthAddCustomDurationRequested event,
    Emitter<AuthBlocState> emit,
  ) async {
    final user = currentUser;
    if (user == null) return;
    try {
      final updated = await _api.updatePreferences(addDurationMinutes: event.minutes);
      emit(AuthenticatedState(user: updated));
    } catch (_) {}
  }

  Future<void> _onRemoveCustomDuration(
    AuthRemoveCustomDurationRequested event,
    Emitter<AuthBlocState> emit,
  ) async {
    final user = currentUser;
    if (user == null) return;
    try {
      final updated = await _api.updatePreferences(removeDurationMinutes: event.minutes);
      emit(AuthenticatedState(user: updated));
    } catch (_) {}
  }

  Future<void> _onAddContact(
    AuthAddContactRequested event,
    Emitter<AuthBlocState> emit,
  ) async {
    final user = currentUser;
    if (user == null) return;
    try {
      final contacts = await _api.addContact(
        name: event.name,
        phone: event.phone,
        relationship: event.relationship,
      );
      final updatedCats = user.customContactCategories.contains(event.relationship)
          ? user.customContactCategories
          : [...user.customContactCategories, event.relationship];
      emit(AuthenticatedState(
        user: user.copyWith(
          emergencyContacts: contacts,
          customContactCategories: updatedCats,
        ),
      ));
    } catch (e) {
      debugPrint('[AuthBloc._onAddContact] Error: $e');
    }
  }

  Future<void> _onDeleteContact(
    AuthDeleteContactRequested event,
    Emitter<AuthBlocState> emit,
  ) async {
    final user = currentUser;
    if (user == null) return;
    try {
      final contacts = await _api.deleteContact(event.contactId);
      emit(AuthenticatedState(user: user.copyWith(emergencyContacts: contacts)));
    } catch (e) {
      debugPrint('[AuthBloc._onDeleteContact] Error: $e');
    }
  }

  Future<void> _onAddCustomWhitelist(
    AuthAddCustomWhitelistRequested event,
    Emitter<AuthBlocState> emit,
  ) async {
    final user = currentUser;
    if (user == null) return;
    try {
      final updated = await _api.updatePreferences(addWhitelistOption: event.option);
      emit(AuthenticatedState(user: updated));
    } catch (_) {}
  }

  Future<void> _onRefreshUser(
    AuthRefreshUserRequested event,
    Emitter<AuthBlocState> emit,
  ) async {
    try {
      final profile = await _api.getProfile();
      emit(AuthenticatedState(user: profile));
    } catch (_) {}
  }

  Future<void> _onLogoutRequested(
    AuthLogoutRequested event,
    Emitter<AuthBlocState> emit,
  ) async {
    await _api.clearSession();
    emit(const AuthUnauthenticated());
  }
}
