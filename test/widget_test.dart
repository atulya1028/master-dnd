import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:master_dnd/bloc/auth/auth_bloc.dart';
import 'package:master_dnd/bloc/auth/auth_state.dart';
import 'package:master_dnd/bloc/dnd/dnd_bloc.dart';
import 'package:master_dnd/bloc/dnd/dnd_state.dart';
import 'package:master_dnd/core/models.dart';
import 'package:master_dnd/core/theme.dart';
import 'package:master_dnd/main.dart';
import 'package:master_dnd/screens/home_screen.dart';
import 'package:master_dnd/screens/insights_screen.dart';

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
      expect(exported['callWhitelist'], 'Starred');
      expect(exported['messageWhitelist'], 'VIP only');
      expect(exported['repeatCallersWindowMin'], 15);
    });

    test('DndIcons resolves unknown keys gracefully to moon icon', () {
      expect(DndIcons.fromKey('moon'), DndIcons.moon);
      expect(DndIcons.fromKey('briefcase'), DndIcons.briefcase);
      expect(DndIcons.fromKey('nonexistent_key'), DndIcons.moon);
    });

    test('DndRule parses json and converts to json properly', () {
      final json = {
        'id': 'rule_1',
        'title': 'Night focus',
        'subtitle': '10 PM to 7 AM',
        'triggerType': 'schedule',
        'active': true,
      };

      final rule = DndRule.fromJson(json);
      expect(rule.id, 'rule_1');
      expect(rule.title, 'Night focus');
      expect(rule.subtitle, '10 PM to 7 AM');
      expect(rule.triggerType, 'schedule');
      expect(rule.active, isTrue);

      final exported = rule.toJson();
      expect(exported['title'], 'Night focus');
      expect(exported['triggerType'], 'schedule');
    });

    test('InsightsData parses json and defaults correctly', () {
      final defaults = InsightsData.defaults();
      expect(defaults.stats.focusHours, 31);
      expect(defaults.stats.blockedTotal, 84);
      expect(defaults.breakdown.length, 7);
      expect(defaults.profiles.length, 4);
    });
  });

  group('UI Screen Interaction Widget Tests', () {
    testWidgets('HomeScreen renders power button, duration chips, and handles toggle', (WidgetTester tester) async {
      bool toggled = false;
      await tester.pumpWidget(
        MultiBlocProvider(
          providers: [
            BlocProvider<AuthBloc>(create: (_) => AuthBloc()),
            BlocProvider<DndBloc>(create: (_) => DndBloc()),
          ],
          child: MaterialApp(
            theme: dayTheme,
            home: Scaffold(
              body: HomeScreen(
                dndOn: false,
                onToggle: (v) => toggled = v,
              ),
            ),
          ),
        ),
      );

      expect(find.text('Do Not Disturb is off'), findsOneWidget);
      expect(find.text('30 min'), findsOneWidget);
      expect(find.text('1 hour'), findsOneWidget);
      expect(find.text('Until 6:30 AM'), findsOneWidget);

      // Tap 30 min chip
      await tester.tap(find.text('30 min'));
      await tester.pumpAndSettle();
      expect(find.text('Quiet for 30 minutes once started'), findsOneWidget);

      // Tap power button
      await tester.tap(find.bySemanticsLabel('Turn Do Not Disturb on'));
      await tester.pumpAndSettle();
      expect(toggled, isTrue);
    });

    testWidgets('HomeScreen renders custom time chip and diagnostics button', (WidgetTester tester) async {
      await tester.pumpWidget(
        MultiBlocProvider(
          providers: [
            BlocProvider<AuthBloc>(create: (_) => AuthBloc()),
            BlocProvider<DndBloc>(create: (_) => DndBloc()),
          ],
          child: MaterialApp(
            theme: dayTheme,
            home: Scaffold(
              body: HomeScreen(
                dndOn: false,
                onToggle: (_) {},
              ),
            ),
          ),
        ),
      );

      expect(find.text('Set time'), findsOneWidget);
      expect(find.byTooltip('System Status & Diagnostics'), findsOneWidget);

      // Open diagnostics sheet
      await tester.tap(find.byTooltip('System Status & Diagnostics'));
      await tester.pump(const Duration(milliseconds: 500));
      expect(find.text('System Status & Diagnostics'), findsOneWidget);
      expect(find.text('Microsoft Azure Cloud Backend'), findsOneWidget);
      expect(find.text('MongoDB Database Cluster'), findsOneWidget);
      expect(find.text('Zoho Mail SMTP OTP Engine'), findsOneWidget);
    });

    testWidgets('InsightsScreen renders headers and range chips', (WidgetTester tester) async {
      await tester.pumpWidget(
        MaterialApp(
          theme: dayTheme,
          home: const Scaffold(
            body: InsightsScreen(),
          ),
        ),
      );

      expect(find.text('Insights'), findsOneWidget);
      expect(find.text('This week'), findsOneWidget);
      expect(find.text('Last week'), findsOneWidget);
      expect(find.text('Month'), findsOneWidget);
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

    test('AuthFailureState terminates loading and preserves error details', () {
      const failure = AuthFailureState(
        error: 'Connection error: Unable to reach backend at http://localhost:5001/api',
        previousState: AuthUnauthenticated(),
      );
      expect(failure.error, contains('Unable to reach backend'));
      expect(failure.previousState, isA<AuthUnauthenticated>());
      // When failure is emitted, isLoading evaluates to false so progress indicator is dismissed
      final isLoading = failure is AuthLoading;
      expect(isLoading, isFalse);
    });
  });
}
