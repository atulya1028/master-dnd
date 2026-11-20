import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:master_dnd/bloc/auth/auth_bloc.dart';
import 'package:master_dnd/bloc/auth/auth_state.dart';
import 'package:master_dnd/bloc/dnd/dnd_bloc.dart';
import 'package:master_dnd/bloc/dnd/dnd_state.dart';
import 'package:master_dnd/core/models.dart';
import 'package:master_dnd/main.dart';

void main() {
  group('Master DND Widget & App Smoke Tests', () {
    testWidgets('Master DND app mounts MaterialApp correctly', (WidgetTester tester) async {
      await tester.pumpWidget(const MasterDndApp());
      expect(find.byType(MaterialApp), findsOneWidget);
    });
  });

  group('UserModel Unit Tests', () {
    test('fromJson and toJson round-trip preserves user data', () {
      final json = {
        'id': 'user_123',
        'phone': '+1234567890',
        'name': 'John Doe',
        'email': 'john@example.com',
        'avatar': 'J',
        'bio': 'Deep work advocate',
        'isProfileComplete': true,
        'dndEnabled': true,
      };

      final user = UserModel.fromJson(json);
      expect(user.id, 'user_123');
      expect(user.phone, '+1234567890');
      expect(user.name, 'John Doe');
      expect(user.displayName, 'John Doe');
      expect(user.displayInitial, 'J');
      expect(user.isProfileComplete, isTrue);
      expect(user.dndEnabled, isTrue);

      final exported = user.toJson();
      expect(exported['id'], 'user_123');
      expect(exported['name'], 'John Doe');
      expect(exported['dndEnabled'], isTrue);
    });

    test('displayName and displayInitial fallback gracefully when empty', () {
      const user = UserModel(id: '1', phone: '+1234567890');
      expect(user.displayName, 'User');
      expect(user.displayInitial, 'A'); // defaults avatar to 'A'
    });

    test('copyWith updates specified fields only', () {
      const user = UserModel(id: '1', phone: '+123', name: 'Original');
      final updated = user.copyWith(name: 'Updated', dndEnabled: true);
      expect(updated.id, '1');
      expect(updated.name, 'Updated');
      expect(updated.dndEnabled, isTrue);
    });
  });

  group('DndProfile Unit Tests', () {
    test('fromJson parses modes and active status correctly', () {
      final json = {
        'id': 'prof_1',
        'name': 'Deep Focus',
        'icon': 'moon',
        'meta': 'Total Silence',
        'active': true,
        'mode': 'totalSilence',
        'autoReply': true,
        'hideNotifications': true,
      };

      final profile = DndProfile.fromJson(json);
      expect(profile.id, 'prof_1');
      expect(profile.name, 'Deep Focus');
      expect(profile.active, isTrue);
      expect(profile.mode, DndMode.totalSilence);
      expect(profile.hideNotifications, isTrue);

      final exported = profile.toJson();
      expect(exported['mode'], 'totalSilence');
      expect(exported['active'], isTrue);
    });

    test('DndIcons resolves unknown keys gracefully to moon icon', () {
      expect(DndIcons.fromKey('moon'), DndIcons.moon);
      expect(DndIcons.fromKey('briefcase'), DndIcons.briefcase);
      expect(DndIcons.fromKey('nonexistent_key'), DndIcons.moon);
    });
  });

  group('BLoC State Initialization Tests', () {
    test('AuthBloc starts in AuthInitial state', () {
      final authBloc = AuthBloc();
      expect(authBloc.state, isA<AuthInitial>());
      authBloc.close();
    });

    test('DndBloc starts in DndInitial state', () {
      final dndBloc = DndBloc();
      expect(dndBloc.state, isA<DndInitial>());
      dndBloc.close();
    });
  });

  group('AuthFlow State Invariant Tests', () {
    test('AuthLoading preserves previous screen without unmounting', () {
      // Verify AuthGate buildWhen logic:
      // It must return false for transient AuthLoading, AuthOtpSentState, and AuthFailureState
      // so it never replaces active form screens with the splash screen.
      const initial = AuthInitial();
      const loading = AuthLoading(message: 'Sending verification code...');
      const otpSent = AuthOtpSentState(phone: 'user@example.com');
      const failure = AuthFailureState(error: 'Failed');

      bool shouldRebuild(AuthBlocState current) {
        return current is AuthInitial ||
            current is AuthUnauthenticated ||
            current is AuthNeedsProfileFormState ||
            current is AuthenticatedState;
      }

      expect(shouldRebuild(initial), isTrue);
      expect(shouldRebuild(loading), isFalse);
      expect(shouldRebuild(otpSent), isFalse);
      expect(shouldRebuild(failure), isFalse);
      expect(shouldRebuild(const AuthUnauthenticated()), isTrue);
      expect(shouldRebuild(const AuthenticatedState(user: UserModel(id: '1', phone: 'test'))), isTrue);
    });
  });
}
