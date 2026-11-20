import 'package:equatable/equatable.dart';

import '../../core/models.dart';

sealed class AuthBlocState extends Equatable {
  const AuthBlocState();

  @override
  List<Object?> get props => [];
}

class AuthInitial extends AuthBlocState {
  const AuthInitial();
}

class AuthLoading extends AuthBlocState {
  const AuthLoading({this.message});

  final String? message;

  @override
  List<Object?> get props => [message];
}

class AuthUnauthenticated extends AuthBlocState {
  const AuthUnauthenticated({this.message});

  final String? message;

  @override
  List<Object?> get props => [message];
}

class AuthOtpSentState extends AuthBlocState {
  const AuthOtpSentState({
    required this.phone,
    this.testOtp,
    this.expiresInSeconds = 300,
  });

  final String phone;
  final String? testOtp;
  final int expiresInSeconds;

  @override
  List<Object?> get props => [phone, testOtp, expiresInSeconds];
}

class AuthNeedsProfileFormState extends AuthBlocState {
  const AuthNeedsProfileFormState({required this.user});

  final UserModel user;

  @override
  List<Object?> get props => [user];
}

class AuthenticatedState extends AuthBlocState {
  const AuthenticatedState({required this.user});

  final UserModel user;

  @override
  List<Object?> get props => [user];
}

class AuthFailureState extends AuthBlocState {
  const AuthFailureState({required this.error, this.previousState});

  final String error;
  final AuthBlocState? previousState;

  @override
  List<Object?> get props => [error, previousState];
}
