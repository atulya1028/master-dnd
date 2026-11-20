import 'package:flutter/material.dart';

import '../core/models.dart';
import '../core/tokens.dart';
import '../widgets/widgets.dart';
import 'app_shell.dart';

/// Figma: "1 Onboarding: permissions".
class OnboardingScreen extends StatelessWidget {
  const OnboardingScreen({super.key});

  void _continue(BuildContext context) => Navigator.of(context).pushReplacement(
        MaterialPageRoute<void>(builder: (_) => const AppShell()),
      );

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
                onPressed: () => _continue(context),
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
              'Grant these once so rules can run in the background. Your contacts stay on this phone.',
              style: context.text.bodyLarge!.copyWith(color: c.textSecondary),
            ),
            const SizedBox(height: Space.s24),
            const DndGroup(children: [
              SettingRow(
                icon: DndIcons.shield,
                title: 'Do Not Disturb access',
                subtitle: 'Lets the app switch silent modes',
                value: 'Allow',
              ),
              SettingRow(
                icon: DndIcons.user,
                title: 'Contacts',
                subtitle: 'Matched on your phone only',
                value: 'Allow',
              ),
              SettingRow(
                icon: DndIcons.bell,
                title: 'Notifications',
                subtitle: 'Reminders before a profile starts',
                value: 'Optional',
              ),
            ]),
            const Spacer(),
            AppButton('Allow and continue', onPressed: () => _continue(context)),
            const SizedBox(height: Space.s12),
            AppButton('Not now', type: AppButtonType.ghost, onPressed: () => _continue(context)),
          ]),
        ),
      ),
    );
  }
}
