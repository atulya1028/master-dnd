import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../bloc/auth/auth_bloc.dart';
import '../bloc/dnd/dnd_bloc.dart';
import '../bloc/dnd/dnd_state.dart';
import '../core/models.dart';
import '../core/tokens.dart';
import '../widgets/widgets.dart';
import 'profile/edit_profile_screen.dart';
import 'profile_editor_screen.dart';

/// Home tab: Day look when DND is off, Night look when DND is armed.
class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key, required this.dndOn, required this.onToggle});

  final bool dndOn;
  final ValueChanged<bool> onToggle;

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  int _durationIndex = 1;

  void _showBatteryGuide(BuildContext context) {
    final c = context.dnd;
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: c.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(Radii.card)),
      ),
      builder: (ctx) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(Space.s24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(DndIcons.warning, color: c.warning, size: 28),
                    const SizedBox(width: Space.s12),
                    Expanded(
                      child: Text('Battery Optimisation Guide', style: ctx.text.titleLarge),
                    ),
                  ],
                ),
                const SizedBox(height: Space.s16),
                Text(
                  'To ensure Master DND automated rules and schedules fire precisely without delay:',
                  style: ctx.text.bodyMedium,
                ),
                const SizedBox(height: Space.s12),
                _guideStep(ctx, '1', 'Open Android Settings > Apps > Master DND.'),
                _guideStep(ctx, '2', 'Tap "App Battery Usage" or "Battery".'),
                _guideStep(ctx, '3', 'Select "Unrestricted" (Do not optimise).'),
                _guideStep(ctx, '4', 'Ensure "Do Not Disturb access" is granted in Special Access.'),
                const SizedBox(height: Space.s24),
                AppButton('Understood', onPressed: () => Navigator.of(ctx).pop()),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _guideStep(BuildContext ctx, String num, String text) {
    final c = ctx.dnd;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          CircleAvatar(
            radius: 10,
            backgroundColor: c.accentTint,
            child: Text(num, style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: c.accent)),
          ),
          const SizedBox(width: Space.s12),
          Expanded(child: Text(text, style: ctx.text.bodySmall)),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final c = context.dnd;
    final dndOn = widget.dndOn;

    final durationSubtitle = switch (_durationIndex) {
      0 => 'Quiet for 30 minutes once started',
      1 => 'Quiet for 1 hour once started',
      _ => 'Quiet until 6:30 AM once started',
    };

    return ListView(
      padding: const EdgeInsets.fromLTRB(Space.s24, Space.s16, Space.s24, Space.s24),
      children: [
        _Header(dndOn: dndOn),
        const SizedBox(height: Space.s24),
        Center(
          child: _PowerButton(
            on: dndOn,
            onTap: () => widget.onToggle(!dndOn),
          ),
        ),
        const SizedBox(height: Space.s24),
        Text(
          dndOn ? 'Sleep is on' : 'Do Not Disturb is off',
          textAlign: TextAlign.center,
          style: context.text.titleLarge,
        ),
        const SizedBox(height: Space.s4),
        Text(
          dndOn ? 'Quiet until 6:30 AM, 7 h 4 m left' : durationSubtitle,
          textAlign: TextAlign.center,
          style: context.text.bodyMedium!.copyWith(color: c.textSecondary),
        ),
        const SizedBox(height: Space.s24),
        if (dndOn) ..._onContent(context) else ..._offContent(context),
      ],
    );
  }

  List<Widget> _offContent(BuildContext context) {
    final dndState = context.watch<DndBloc>().state;
    final profiles = switch (dndState) {
      DndLoaded(:final profiles) => profiles,
      _ => sampleProfiles,
    };
    final nextProfile = profiles.isNotEmpty ? profiles.first : sampleProfiles.first;

    return [
      Center(
        child: ChipRow(
          labels: const ['30 min', '1 hour', 'Until 6:30 AM'],
          selected: _durationIndex,
          onSelected: (i) => setState(() => _durationIndex = i),
        ),
      ),
      const SizedBox(height: Space.s16),
      WarningBanner(
        title: 'Battery optimisation is on',
        message: 'Schedules may fire late on this phone.',
        action: 'Fix',
        onAction: () => _showBatteryGuide(context),
      ),
      const SizedBox(height: Space.s24),
      const OverlineText('Next up'),
      const SizedBox(height: Space.s8),
      GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: () {
          Navigator.of(context).push(
            MaterialPageRoute(
              builder: (_) => ProfileEditorScreen(profile: nextProfile),
            ),
          );
        },
        child: DndCard(
          child: SettingRow(
            icon: nextProfile.icon,
            title: nextProfile.name,
            subtitle: nextProfile.meta.isNotEmpty ? nextProfile.meta : 'Configured profile',
            value: 'in 2 h 19 m',
          ),
        ),
      ),
    ];
  }

  List<Widget> _onContent(BuildContext context) {
    final c = context.dnd;
    Widget tile(String value, String label) => Expanded(
          child: DndCard(
            child: Padding(
              padding: const EdgeInsets.all(Space.s16),
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(value, style: context.text.titleLarge),
                Text(label, style: context.text.bodySmall),
              ]),
            ),
          ),
        );

    Widget contact(String initial, String name, String detail) => Padding(
          padding: const EdgeInsets.symmetric(horizontal: Space.s16, vertical: Space.s12),
          child: Row(children: [
            CircleAvatar(
              radius: 18,
              backgroundColor: c.accentTint,
              child: Text(initial, style: context.text.labelLarge!.copyWith(color: c.accent)),
            ),
            const SizedBox(width: Space.s12),
            Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(name, style: context.text.labelLarge),
                Text(detail, style: context.text.bodySmall),
              ]),
            ),
            Icon(DndIcons.phone, size: 20, color: c.armed),
          ]),
        );

    return [
      Row(children: [
        tile('12', 'Silenced tonight'),
        const SizedBox(width: Space.s12),
        tile('2', 'Let through'),
      ]),
      const SizedBox(height: Space.s24),
      const OverlineText('Let through by your rules'),
      const SizedBox(height: Space.s8),
      DndGroup(children: [
        contact('M', 'Mom', 'Call at 11:12 PM, VIP contact'),
        contact('D', 'Dr. Rao', 'Call at 11:19 PM, repeat caller'),
      ]),
      const SizedBox(height: Space.s16),
      Row(children: [
        Expanded(
          child: AppButton(
            'Extend 1 hour',
            type: AppButtonType.ghost,
            onPressed: () {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('Quiet time extended by 1 hour (until 7:30 AM)'),
                ),
              );
            },
          ),
        ),
        const SizedBox(width: Space.s12),
        Expanded(
          child: AppButton(
            'End now',
            onPressed: () => widget.onToggle(false),
          ),
        ),
      ]),
    ];
  }
}

class _Header extends StatelessWidget {
  const _Header({required this.dndOn});

  final bool dndOn;

  @override
  Widget build(BuildContext context) {
    final c = context.dnd;
    final user = context.watch<AuthBloc>().currentUser;

    final hour = DateTime.now().hour;
    final timeGreeting = hour < 12
        ? 'Good morning'
        : (hour < 17 ? 'Good afternoon' : 'Good evening');

    final name = user?.displayName ?? 'User';
    final initial = user?.displayInitial ?? 'U';

    return Row(children: [
      Expanded(
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(dndOn ? 'Sleep profile' : '$timeGreeting, $name', style: context.text.bodySmall),
          Text('Master DND', style: context.text.titleLarge),
        ]),
      ),
      if (dndOn)
        Container(
          padding: const EdgeInsets.symmetric(horizontal: Space.s12, vertical: 6),
          decoration: BoxDecoration(color: c.accentTint, borderRadius: BorderRadius.circular(Radii.pill)),
          child: Row(mainAxisSize: MainAxisSize.min, children: [
            Container(width: 8, height: 8, decoration: BoxDecoration(color: c.armed, shape: BoxShape.circle)),
            const SizedBox(width: 6),
            Text('Armed', style: context.text.bodySmall!.copyWith(color: c.textPrimary)),
          ]),
        )
      else
        GestureDetector(
          onTap: () {
            Navigator.of(context).push(
              MaterialPageRoute(builder: (_) => const EditProfileScreen()),
            );
          },
          child: CircleAvatar(
            radius: 20,
            backgroundColor: c.accentTint,
            child: Text(initial, style: context.text.labelLarge!.copyWith(color: c.accent)),
          ),
        ),
    ]);
  }
}

/// The large circular toggle. Off: white button on a soft ring.
/// On: solid accent disc with a moon.
class _PowerButton extends StatelessWidget {
  const _PowerButton({required this.on, required this.onTap});

  final bool on;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final c = context.dnd;
    return Semantics(
      button: true,
      label: on ? 'Turn Do Not Disturb off' : 'Turn Do Not Disturb on',
      child: GestureDetector(
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          curve: Curves.easeOut,
          width: 220,
          height: 220,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: on ? c.accent : c.accentTint.withValues(alpha: 0.6),
          ),
          alignment: Alignment.center,
          child: on
              ? Icon(DndIcons.moon, size: 72, color: c.onAccent)
              : Container(
                  width: 140,
                  height: 140,
                  decoration: BoxDecoration(
                    color: c.surface,
                    shape: BoxShape.circle,
                    boxShadow: [
                      BoxShadow(
                        color: c.accent.withValues(alpha: 0.18),
                        blurRadius: 24,
                        offset: const Offset(0, 8),
                      ),
                    ],
                  ),
                  child: Icon(DndIcons.power, size: 56, color: c.accent),
                ),
        ),
      ),
    );
  }
}
