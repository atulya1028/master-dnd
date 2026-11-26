import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../bloc/auth/auth_bloc.dart';
import '../bloc/auth/auth_event.dart';
import '../bloc/dnd/dnd_bloc.dart';
import '../bloc/dnd/dnd_event.dart';
import '../bloc/dnd/dnd_state.dart';
import '../core/api_service.dart';
import '../core/theme.dart';
import 'home_screen.dart';
import 'insights_screen.dart';
import 'profiles_screen.dart';
import 'rules_screen.dart';
import 'stability_report_screen.dart';

/// Bottom navigation shell powered by BloC. The Home tab switches to the Night
/// theme while Do Not Disturb is on, matching "3 Home: on (Night)" in Figma.
class AppShell extends StatefulWidget {
  const AppShell({super.key});

  @override
  State<AppShell> createState() => _AppShellState();
}

class _AppShellState extends State<AppShell> with WidgetsBindingObserver {
  int _index = 0;
  Timer? _usageTimer;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    context.read<DndBloc>().add(const DndLoadRequested());
    // Track active app usage every minute so Stability Report reflects real usage over time.
    _usageTimer = Timer.periodic(const Duration(minutes: 1), (_) {
      if (mounted && context.read<AuthBloc>().currentUser != null) {
        ApiService.instance.pingAppUsage(minutes: 1);
      }
    });
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed && context.read<AuthBloc>().currentUser != null) {
      ApiService.instance.pingAppUsage(minutes: 1);
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _usageTimer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final user = context.watch<AuthBloc>().currentUser;
    final dndState = context.watch<DndBloc>().state;
    final activeProfileName = switch (dndState) {
      DndLoaded(:final activeProfile) => activeProfile?.name,
      _ => null,
    };
    final dndOn = user?.dndEnabled ?? false;
    final night = dndOn && _index == 0;

    return Theme(
      data: night ? nightTheme : dayTheme,
      child: Scaffold(
        body: SafeArea(
          bottom: false,
          child: IndexedStack(index: _index, children: [
            HomeScreen(
              dndOn: dndOn,
              onToggle: (v) => context.read<AuthBloc>().add(
                    AuthToggleDndRequested(
                      enabled: v,
                      profileName: activeProfileName,
                    ),
                  ),
              onToggleWithSession: (enabled, durationMinutes, endTime) {
                context.read<AuthBloc>().add(
                      AuthToggleDndRequested(
                        enabled: enabled,
                        durationMinutes: durationMinutes,
                        endTime: endTime,
                        profileName: activeProfileName,
                      ),
                    );
              },
              onOpenStabilityReport: () => setState(() => _index = 4),
            ),
            const ProfilesScreen(),
            const RulesScreen(),
            InsightsScreen(
              onOpenStabilityReport: () => setState(() => _index = 4),
            ),
            const StabilityReportScreen(),
          ]),
        ),
        bottomNavigationBar: NavigationBar(
          selectedIndex: _index,
          onDestinationSelected: (i) => setState(() => _index = i),
          destinations: const [
            NavigationDestination(icon: Icon(Icons.home_outlined), label: 'Home'),
            NavigationDestination(icon: Icon(Icons.layers_outlined), label: 'Profiles'),
            NavigationDestination(icon: Icon(Icons.schedule), label: 'Rules'),
            NavigationDestination(icon: Icon(Icons.bar_chart), label: 'Insights'),
            NavigationDestination(icon: Icon(Icons.analytics_outlined), label: 'Stability'),
          ],
        ),
      ),
    );
  }
}
