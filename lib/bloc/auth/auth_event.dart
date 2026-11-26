import 'package:equatable/equatable.dart';

sealed class AuthEvent extends Equatable {
  const AuthEvent();

  @override
  List<Object?> get props => [];
}

/// Dispatched on app startup to verify existing session token
class AuthCheckRequested extends AuthEvent {
  const AuthCheckRequested();
}

/// Dispatched from phone login screen
class AuthSendOtpRequested extends AuthEvent {
  const AuthSendOtpRequested(this.phone);
  final String phone;

  @override
  List<Object?> get props => [phone];
}

/// Dispatched from OTP verification screen
class AuthVerifyOtpRequested extends AuthEvent {
  const AuthVerifyOtpRequested({required this.phone, required this.otp});
  final String phone;
  final String otp;

  @override
  List<Object?> get props => [phone, otp];
}

/// Dispatched to resend a fresh OTP
class AuthResendOtpRequested extends AuthEvent {
  const AuthResendOtpRequested(this.phone);
  final String phone;

  @override
  List<Object?> get props => [phone];
}

/// Dispatched from profile setup form (step 2 onboarding)
class AuthCompleteProfileRequested extends AuthEvent {
  const AuthCompleteProfileRequested({
    required this.name,
    required this.email,
    required this.avatar,
    this.bio = '',
  });

  final String name;
  final String email;
  final String avatar;
  final String bio;

  @override
  List<Object?> get props => [name, email, avatar, bio];
}

/// Dispatched from edit profile screen
class AuthUpdateProfileRequested extends AuthEvent {
  const AuthUpdateProfileRequested({
    this.name,
    this.email,
    this.phone,
    this.avatar,
    this.bio,
    this.notificationPreferences,
  });

  final String? name;
  final String? email;
  final String? phone;
  final String? avatar;
  final String? bio;
  final Map<String, bool>? notificationPreferences;

  @override
  List<Object?> get props => [name, email, phone, avatar, bio, notificationPreferences];
}

/// Dispatched to toggle master DND power switch and log session timing
class AuthToggleDndRequested extends AuthEvent {
  const AuthToggleDndRequested({
    this.enabled,
    this.durationMinutes,
    this.endTime,
    this.profileName,
  });
  final bool? enabled;
  final int? durationMinutes;
  final DateTime? endTime;
  final String? profileName;

  @override
  List<Object?> get props => [enabled, durationMinutes, endTime, profileName];
}

/// Dispatched to add/remove custom user choices & VIP contacts saved to MongoDB
class AuthAddCustomDurationRequested extends AuthEvent {
  const AuthAddCustomDurationRequested(this.minutes);
  final int minutes;

  @override
  List<Object?> get props => [minutes];
}

class AuthRemoveCustomDurationRequested extends AuthEvent {
  const AuthRemoveCustomDurationRequested(this.minutes);
  final int minutes;

  @override
  List<Object?> get props => [minutes];
}

class AuthAddContactRequested extends AuthEvent {
  const AuthAddContactRequested({
    required this.name,
    this.phone = '',
    this.relationship = 'VIP Contact',
  });
  final String name;
  final String phone;
  final String relationship;

  @override
  List<Object?> get props => [name, phone, relationship];
}

class AuthDeleteContactRequested extends AuthEvent {
  const AuthDeleteContactRequested(this.contactId);
  final String contactId;

  @override
  List<Object?> get props => [contactId];
}

class AuthAddCustomWhitelistRequested extends AuthEvent {
  const AuthAddCustomWhitelistRequested(this.option);
  final String option;

  @override
  List<Object?> get props => [option];
}

class AuthRefreshUserRequested extends AuthEvent {
  const AuthRefreshUserRequested();
}

/// Dispatched on user logout
class AuthLogoutRequested extends AuthEvent {
  const AuthLogoutRequested();
}
