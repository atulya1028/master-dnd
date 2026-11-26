import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../bloc/auth/auth_bloc.dart';
import '../bloc/auth/auth_event.dart';
import '../core/models.dart';
import '../core/tokens.dart';
import '../widgets/widgets.dart';
import 'app_shell.dart';

/// Figma: "1 Onboarding: permissions" wired to persist preferences in MongoDB.
class OnboardingScreen extends StatefulWidget {
  const OnboardingScreen({super.key});

  @override
  State<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends State<OnboardingScreen> {
  bool _allowDndAccess = true;
  bool _allowContacts = true;
  bool _allowNotifications = true;

  void _continue({required bool savePrefs}) {
    if (savePrefs && context.read<AuthBloc>().currentUser != null) {
      context.read<AuthBloc>().add(
            AuthUpdateProfileRequested(
              notificationPreferences: {
                'allowDndAccess': _allowDndAccess,
                'allowContacts': _allowContacts,
                'allowNotifications': _allowNotifications,
              },
            ),
          );
    }
    Navigator.of(context).pushReplacement(
      MaterialPageRoute<void>(builder: (_) => const AppShell()),
    );
  }

  @override
  Widget build(BuildContext context) {
    final c = context.dnd;
    return Scaffold(
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(Space.s24),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
              Text('STEP 2 OF 3', style: context.text.labelSmall),
              TextButton(
                onPressed: () => _continue(savePrefs: false),
                child: Text('Skip', style: context.text.labelLarge!.copyWith(color: c.accent)),
              ),
            ]),
            const SizedBox(height: Space.s16),
            Container(
              width: 88,
              height: 88,
              decoration: BoxDecoration(color: c.accentTint, shape: BoxShape.circle),
              child: Icon(DndIcons.moon, size: 40, color: c.accent),
            ),
            const SizedBox(height: Space.s24),
            Text('Let Master DND keep you quiet', style: context.text.displayLarge),
            const SizedBox(height: Space.s12),
            Text(
              'Choose the permissions you want enabled. Your choices are saved to your account.',
              style: context.text.bodyLarge!.copyWith(color: c.textSecondary),
            ),
            const SizedBox(height: Space.s24),
            DndGroup(children: [
              SwitchListTile(
                secondary: const IconTile(icon: DndIcons.shield, size: 40, iconSize: 20),
                title: Text('Do Not Disturb access', style: context.text.labelLarge),
                subtitle: Text('Lets the app switch silent modes', style: context.text.bodySmall),
                value: _allowDndAccess,
                onChanged: (v) => setState(() => _allowDndAccess = v),
              ),
              SwitchListTile(
                secondary: const IconTile(icon: DndIcons.user, size: 40, iconSize: 20),
                title: Text('Contacts', style: context.text.labelLarge),
                subtitle: Text('VIP contact matching', style: context.text.bodySmall),
                value: _allowContacts,
                onChanged: (v) => setState(() => _allowContacts = v),
              ),
              SwitchListTile(
                secondary: const IconTile(icon: DndIcons.bell, size: 40, iconSize: 20),
                title: Text('Notifications', style: context.text.labelLarge),
                subtitle: Text('Reminders before a profile starts', style: context.text.bodySmall),
                value: _allowNotifications,
                onChanged: (v) => setState(() => _allowNotifications = v),
              ),
            ]),
            const Spacer(),
            AppButton('Allow and continue', onPressed: () => _continue(savePrefs: true)),
            const SizedBox(height: Space.s12),
            AppButton('Not now', type: AppButtonType.ghost, onPressed: () => _continue(savePrefs: false)),
          ]),
        ),
      ),
    );
  }
}
