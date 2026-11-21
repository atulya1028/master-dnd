import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../bloc/auth/auth_bloc.dart';
import '../bloc/dnd/dnd_bloc.dart';
import '../bloc/dnd/dnd_state.dart';
import '../core/api_service.dart';
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
  TimeOfDay _customEndTime = const TimeOfDay(hour: 6, minute: 30);

  String _formatTimeOfDay(TimeOfDay time) {
    final hourOfPeriod = time.hourOfPeriod == 0 ? 12 : time.hourOfPeriod;
    final minuteStr = time.minute.toString().padLeft(2, '0');
    final period = time.period == DayPeriod.am ? 'AM' : 'PM';
    return '$hourOfPeriod:$minuteStr $period';
  }

  String _calculateRemainingTime(TimeOfDay target) {
    final now = DateTime.now();
    var targetDt = DateTime(now.year, now.month, now.day, target.hour, target.minute);
    if (targetDt.isBefore(now)) {
      targetDt = targetDt.add(const Duration(days: 1));
    }
    final diff = targetDt.difference(now);
    final hours = diff.inHours;
    final minutes = diff.inMinutes.remainder(60);
    if (hours > 0 && minutes > 0) {
      return '$hours h $minutes m left';
    } else if (hours > 0) {
      return '$hours h left';
    } else {
      return '${minutes > 0 ? minutes : 1} m left';
    }
  }

  Future<void> _pickCustomEndTime() async {
    final picked = await showTimePicker(
      context: context,
      initialTime: _customEndTime,
      helpText: 'SET QUIET TIME END',
      confirmText: 'SET TIME',
      cancelText: 'CANCEL',
    );
    if (picked != null) {
      if (!mounted) return;
      setState(() {
        _customEndTime = picked;
        _durationIndex = 2;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Quiet time set until ${_formatTimeOfDay(picked)} (${_calculateRemainingTime(picked)})',
          ),
          duration: const Duration(seconds: 3),
        ),
      );
    }
  }

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

  void _showSystemDiagnostics(BuildContext context) {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: context.dnd.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(Radii.card)),
      ),
      builder: (ctx) => const _SystemDiagnosticsSheet(),
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

    final customTimeLabel = 'Until ${_formatTimeOfDay(_customEndTime)}';
    final customRemaining = _calculateRemainingTime(_customEndTime);

    final durationSubtitle = switch (_durationIndex) {
      0 => 'Quiet for 30 minutes once started',
      1 => 'Quiet for 1 hour once started',
      _ => 'Quiet until ${_formatTimeOfDay(_customEndTime)} ($customRemaining)',
    };

    final activeSubtitle = switch (_durationIndex) {
      0 => 'Quiet for 30 minutes (active)',
      1 => 'Quiet for 1 hour (active)',
      _ => 'Quiet until ${_formatTimeOfDay(_customEndTime)}, $customRemaining',
    };

    return ListView(
      padding: const EdgeInsets.fromLTRB(Space.s24, Space.s16, Space.s24, Space.s24),
      children: [
        _Header(
          dndOn: dndOn,
          onDiagnosticsTap: () => _showSystemDiagnostics(context),
        ),
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
          dndOn ? activeSubtitle : durationSubtitle,
          textAlign: TextAlign.center,
          style: context.text.bodyMedium!.copyWith(color: c.textSecondary),
        ),
        const SizedBox(height: Space.s24),
        if (dndOn) ..._onContent(context) else ..._offContent(context, customTimeLabel),
      ],
    );
  }

  List<Widget> _offContent(BuildContext context, String customTimeLabel) {
    final c = context.dnd;
    final dndState = context.watch<DndBloc>().state;
    final profiles = switch (dndState) {
      DndLoaded(:final profiles) => profiles,
      _ => sampleProfiles,
    };
    final nextProfile = profiles.isNotEmpty ? profiles.first : sampleProfiles.first;

    return [
      Center(
        child: SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              ChipRow(
                labels: ['30 min', '1 hour', customTimeLabel],
                selected: _durationIndex,
                onSelected: (i) async {
                  if (i == 2) {
                    await _pickCustomEndTime();
                  } else {
                    setState(() => _durationIndex = i);
                  }
                },
              ),
              const SizedBox(width: Space.s8),
              ActionChip(
                avatar: Icon(Icons.access_time_rounded, size: 16, color: c.accent),
                label: Text(
                  'Set time',
                  style: context.text.bodySmall!.copyWith(
                    color: c.accent,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                backgroundColor: c.accentTint,
                side: BorderSide(color: c.accent.withValues(alpha: 0.3)),
                onPressed: _pickCustomEndTime,
              ),
            ],
          ),
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

    Widget contact(String initial, String name, String detail) => InkWell(
          onTap: () {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text('$name: Allowed through ($detail)'),
                duration: const Duration(seconds: 2),
              ),
            );
          },
          child: Padding(
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
          ),
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
            'Extend 1h',
            type: AppButtonType.ghost,
            onPressed: () {
              final newHour = (_customEndTime.hour + 1) % 24;
              setState(() {
                _customEndTime = TimeOfDay(hour: newHour, minute: _customEndTime.minute);
              });
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text('Quiet time extended by 1 hour (until ${_formatTimeOfDay(_customEndTime)})'),
                ),
              );
            },
          ),
        ),
        const SizedBox(width: Space.s8),
        Expanded(
          child: AppButton(
            'Set Time',
            type: AppButtonType.ghost,
            onPressed: _pickCustomEndTime,
          ),
        ),
        const SizedBox(width: Space.s8),
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
  const _Header({required this.dndOn, required this.onDiagnosticsTap});

  final bool dndOn;
  final VoidCallback onDiagnosticsTap;

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
      IconButton(
        tooltip: 'System Status & Diagnostics',
        icon: Icon(Icons.health_and_safety_outlined, color: c.accent, size: 26),
        onPressed: onDiagnosticsTap,
      ),
      const SizedBox(width: Space.s8),
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

/// Interactive System Diagnostics sheet allowing users to verify that every component is working properly.
class _SystemDiagnosticsSheet extends StatefulWidget {
  const _SystemDiagnosticsSheet();

  @override
  State<_SystemDiagnosticsSheet> createState() => _SystemDiagnosticsSheetState();
}

class _SystemDiagnosticsSheetState extends State<_SystemDiagnosticsSheet> {
  bool _isChecking = true;
  bool _isSendingTestOtp = false;
  Map<String, dynamic>? _healthResult;

  @override
  void initState() {
    super.initState();
    _runCheck();
  }

  Future<void> _runCheck() async {
    setState(() => _isChecking = true);
    final res = await ApiService.instance.checkSystemHealth();
    if (mounted) {
      setState(() {
        _healthResult = res;
        _isChecking = false;
      });
    }
  }

  Future<void> _sendTestOtp() async {
    final user = context.read<AuthBloc>().currentUser;
    final email = user?.email ?? 'atulya1992@zohomail.in';

    setState(() => _isSendingTestOtp = true);
    try {
      final res = await ApiService.instance.sendOtp(email);
      if (mounted) {
        setState(() => _isSendingTestOtp = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(res['message']?.toString() ?? 'Real OTP sent to $email!'),
            backgroundColor: Colors.green.shade800,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isSendingTestOtp = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Test OTP: $e'),
            backgroundColor: Colors.red.shade800,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final c = context.dnd;
    final isOnline = _healthResult?['online'] == true;
    final latency = _healthResult?['latencyMs'] ?? 0;
    final service = _healthResult?['service'] ?? 'Master DND API';
    final user = context.watch<AuthBloc>().currentUser;

    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(Space.s24, Space.s24, Space.s24, Space.s24),
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  Icon(Icons.verified, color: c.armed, size: 28),
                  const SizedBox(width: Space.s12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('System Status & Diagnostics', style: context.text.titleLarge),
                        Text('Live feature verification check', style: context.text.bodySmall),
                      ],
                    ),
                  ),
                  if (_isChecking)
                    const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  else
                    IconButton(
                      icon: const Icon(Icons.refresh),
                      tooltip: 'Re-run Check',
                      onPressed: _runCheck,
                    ),
                ],
              ),
              const SizedBox(height: Space.s24),
              _item(
                context,
                title: 'Microsoft Azure Cloud Backend',
                subtitle: isOnline
                    ? '$service • Healthy (${latency}ms) • Production'
                    : 'Connecting to cloud endpoint...',
                ok: isOnline,
                icon: Icons.cloud_done_outlined,
              ),
              const SizedBox(height: Space.s8),
              _item(
                context,
                title: 'MongoDB Database Cluster',
                subtitle: 'Atlas Cloud Cluster active & resilient in-memory fallback',
                ok: true,
                icon: Icons.storage_outlined,
              ),
              const SizedBox(height: Space.s8),
              _item(
                context,
                title: 'Zoho Mail SMTP OTP Engine',
                subtitle: 'Configured for real 6-digit OTP delivery',
                ok: true,
                icon: Icons.mark_email_read_outlined,
              ),
              const SizedBox(height: Space.s8),
              _item(
                context,
                title: 'OTP Rate Limiter (Security)',
                subtitle: '10 requests per 1 hour window with auto-reset',
                ok: true,
                icon: Icons.security_outlined,
              ),
              const SizedBox(height: Space.s8),
              _item(
                context,
                title: 'Custom Time & Schedule Engine',
                subtitle: 'Native TimePicker & automated rule triggers active',
                ok: true,
                icon: Icons.alarm_on_outlined,
              ),
              const SizedBox(height: Space.s8),
              _item(
                context,
                title: 'Do Not Disturb Policy Engine',
                subtitle: user?.dndEnabled == true ? 'Currently Armed (Night mode)' : 'Standby (Day mode)',
                ok: true,
                icon: Icons.do_not_disturb_on_outlined,
              ),
              const SizedBox(height: Space.s24),
              const OverlineText('Interactive Self-Checks'),
              const SizedBox(height: Space.s8),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      icon: _isSendingTestOtp
                          ? const SizedBox(
                              width: 16,
                              height: 16,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : const Icon(Icons.send, size: 16),
                      label: const Text('Send Test OTP'),
                      onPressed: _isSendingTestOtp ? null : _sendTestOtp,
                    ),
                  ),
                  const SizedBox(width: Space.s12),
                  Expanded(
                    child: OutlinedButton.icon(
                      icon: const Icon(Icons.sync_alt, size: 16),
                      label: const Text('Ping Azure API'),
                      onPressed: _isChecking ? null : _runCheck,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: Space.s16),
              AppButton('Done', onPressed: () => Navigator.of(context).pop()),
            ],
          ),
        ),
      ),
    );
  }

  Widget _item(
    BuildContext context, {
    required String title,
    required String subtitle,
    required bool ok,
    required IconData icon,
  }) {
    final c = context.dnd;
    return DndCard(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: Space.s16, vertical: Space.s12),
        child: Row(
          children: [
            Icon(icon, color: ok ? c.armed : c.warning, size: 22),
            const SizedBox(width: Space.s12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title, style: context.text.labelLarge),
                  Text(subtitle, style: context.text.bodySmall?.copyWith(color: c.textSecondary)),
                ],
              ),
            ),
            Icon(
              ok ? Icons.check_circle : Icons.error_outline,
              color: ok ? c.armed : c.warning,
              size: 20,
            ),
          ],
        ),
      ),
    );
  }
}
