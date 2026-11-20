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
    this.avatar,
    this.bio,
  });

  final String? name;
  final String? email;
  final String? avatar;
  final String? bio;

  @override
  List<Object?> get props => [name, email, avatar, bio];
}

/// Dispatched to toggle master DND power switch
class AuthToggleDndRequested extends AuthEvent {
  const AuthToggleDndRequested({this.enabled});
  final bool? enabled;

  @override
  List<Object?> get props => [enabled];
}

/// Dispatched on user logout
class AuthLogoutRequested extends AuthEvent {
  const AuthLogoutRequested();
}
