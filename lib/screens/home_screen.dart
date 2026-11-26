import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../bloc/auth/auth_bloc.dart';
import '../bloc/auth/auth_event.dart';
import '../bloc/dnd/dnd_bloc.dart';
import '../bloc/dnd/dnd_state.dart';
import '../core/api_service.dart';
import '../core/models.dart';
import '../core/tokens.dart';
import '../widgets/log_session_sheet.dart';
import '../widgets/widgets.dart';
import 'profile/edit_profile_screen.dart';
import 'profile_editor_screen.dart';
import 'stability_report_screen.dart';

/// Home tab: Day look when DND is off, Night look when DND is armed.
class HomeScreen extends StatefulWidget {
  const HomeScreen({
    super.key,
    required this.dndOn,
    required this.onToggle,
    this.onToggleWithSession,
    this.onOpenStabilityReport,
  });

  final bool dndOn;
  final ValueChanged<bool> onToggle;
  final void Function(bool enabled, int durationMinutes, DateTime? endTime)? onToggleWithSession;
  final VoidCallback? onOpenStabilityReport;

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  int _selectedChipIndex = 1; // index inside [durations..., customTimeChip]
  bool _useCustomEndTime = false;
  TimeOfDay _customEndTime = const TimeOfDay(hour: 6, minute: 30);
  static const _allowedContactsKey = 'master_dnd_allowed_contacts';
  List<LetThroughContact> _localFallbackContacts = [];
  int _silencedTonight = 0;

  @override
  void initState() {
    super.initState();
    _loadFallbackContacts();
    _refreshTonightStats();
  }

  Future<void> _refreshTonightStats() async {
    try {
      final user = context.read<AuthBloc>().currentUser;
      if (user == null) return;
      final insights = await ApiService.instance.getInsights(range: 0);
      if (mounted) {
        setState(() {
          _silencedTonight = insights.stats.silencedTonight;
        });
      }
    } catch (_) {}
  }

  Future<void> _loadFallbackContacts() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getStringList(_allowedContactsKey);
      if (raw != null && mounted) {
        setState(() {
          _localFallbackContacts = raw
              .map((item) => LetThroughContact.fromJson(jsonDecode(item) as Map<String, dynamic>))
              .toList();
        });
      }
    } catch (_) {}
  }

  Future<void> _saveFallbackContacts() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final list = _localFallbackContacts.map((c) => jsonEncode(c.toJson())).toList();
      await prefs.setStringList(_allowedContactsKey, list);
    } catch (_) {}
  }

  String _formatDurationLabel(int minutes, {bool verbose = false}) {
    if (minutes % 60 == 0) {
      final hrs = minutes ~/ 60;
      return hrs == 1 ? '1 hour' : '$hrs hours';
    }
    return verbose ? '$minutes minutes' : '$minutes min';
  }

  int _currentPlannedMinutes(List<int> durations) {
    if (_useCustomEndTime) {
      final now = DateTime.now();
      var targetDt = DateTime(now.year, now.month, now.day, _customEndTime.hour, _customEndTime.minute);
      if (targetDt.isBefore(now)) {
        targetDt = targetDt.add(const Duration(days: 1));
      }
      return targetDt.difference(now).inMinutes.clamp(1, 1440);
    }
    if (_selectedChipIndex >= 0 && _selectedChipIndex < durations.length) {
      return durations[_selectedChipIndex];
    }
    return durations.isNotEmpty ? durations.first : 60;
  }

  DateTime? _currentEndDateTime(List<int> durations) {
    if (_useCustomEndTime) {
      final now = DateTime.now();
      var targetDt = DateTime(now.year, now.month, now.day, _customEndTime.hour, _customEndTime.minute);
      if (targetDt.isBefore(now)) {
        targetDt = targetDt.add(const Duration(days: 1));
      }
      return targetDt;
    }
    return DateTime.now().add(Duration(minutes: _currentPlannedMinutes(durations)));
  }

  void _triggerToggle(bool targetOn, List<int> durations) {
    if (widget.onToggleWithSession != null) {
      widget.onToggleWithSession!(
        targetOn,
        _currentPlannedMinutes(durations),
        targetOn ? _currentEndDateTime(durations) : null,
      );
    } else {
      widget.onToggle(targetOn);
    }
    if (!targetOn) {
      Future.delayed(const Duration(milliseconds: 500), _refreshTonightStats);
    }
  }

  Future<void> _showAddCustomDurationDialog(BuildContext context) async {
    final minsCtrl = TextEditingController();
    await showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Add Custom Duration'),
        content: TextField(
          controller: minsCtrl,
          keyboardType: TextInputType.number,
          autofocus: true,
          decoration: const InputDecoration(
            labelText: 'Duration in minutes',
            hintText: 'e.g. 15, 45, 90',
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () {
              final mins = int.tryParse(minsCtrl.text.trim());
              if (mins == null || mins < 1 || mins > 1440) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Enter minutes between 1 and 1440')),
                );
                return;
              }
              context.read<AuthBloc>().add(AuthAddCustomDurationRequested(mins));
              Navigator.of(ctx).pop();
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(content: Text('Saved ${_formatDurationLabel(mins)} preset to database')),
              );
            },
            child: const Text('Save'),
          ),
        ],
      ),
    );
    minsCtrl.dispose();
  }

  Future<void> _showAddContactDialog(BuildContext context) async {
    final user = context.read<AuthBloc>().currentUser;
    final nameCtrl = TextEditingController();
    final phoneCtrl = TextEditingController();
    final customCatCtrl = TextEditingController();
    int selectedTagIndex = 0;
    bool useCustomCat = false;
    final tags = List<String>.from(
      user?.customContactCategories ??
          const ['VIP Contact', 'Family', 'Doctor / Emergency', 'Repeat Caller', 'Work Priority'],
    );

    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: context.dnd.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(Radii.card)),
      ),
      builder: (modalCtx) {
        return StatefulBuilder(
          builder: (ctx, setModalState) {
            final c = ctx.dnd;
            return Padding(
              padding: EdgeInsets.only(
                left: Space.s24,
                right: Space.s24,
                top: Space.s24,
                bottom: MediaQuery.of(ctx).viewInsets.bottom + Space.s24,
              ),
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Row(
                      children: [
                        Icon(Icons.person_add_alt_1, color: c.accent, size: 26),
                        const SizedBox(width: Space.s12),
                        Expanded(
                          child: Text('Add Allowed Contact', style: ctx.text.titleLarge),
                        ),
                      ],
                    ),
                    const SizedBox(height: Space.s16),
                    const OverlineText('Contact Name'),
                    const SizedBox(height: Space.s8),
                    DndCard(
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: Space.s16, vertical: 4),
                        child: TextField(
                          controller: nameCtrl,
                          autofocus: true,
                          style: ctx.text.titleMedium,
                          decoration: const InputDecoration(
                            hintText: 'e.g. Papa, Sarah, Emergency',
                            border: InputBorder.none,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: Space.s16),
                    const OverlineText('Phone Number (Optional)'),
                    const SizedBox(height: Space.s8),
                    DndCard(
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: Space.s16, vertical: 4),
                        child: TextField(
                          controller: phoneCtrl,
                          keyboardType: TextInputType.phone,
                          style: ctx.text.titleMedium,
                          decoration: const InputDecoration(
                            hintText: 'e.g. +91 98765 43210',
                            border: InputBorder.none,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: Space.s16),
                    const OverlineText('Permission Rule / Category'),
                    const SizedBox(height: Space.s8),
                    SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      child: Row(
                        children: [
                          for (var i = 0; i < tags.length; i++) ...[
                            if (i > 0) const SizedBox(width: Space.s8),
                            ChoiceChip(
                              label: Text(tags[i]),
                              selected: !useCustomCat && selectedTagIndex == i,
                              onSelected: (_) => setModalState(() {
                                useCustomCat = false;
                                selectedTagIndex = i;
                              }),
                            ),
                          ],
                          const SizedBox(width: Space.s8),
                          ChoiceChip(
                            label: const Text('+ Custom'),
                            selected: useCustomCat,
                            onSelected: (_) => setModalState(() => useCustomCat = true),
                          ),
                        ],
                      ),
                    ),
                    if (useCustomCat) ...[
                      const SizedBox(height: Space.s12),
                      DndCard(
                        child: Padding(
                          padding: const EdgeInsets.symmetric(horizontal: Space.s16, vertical: 4),
                          child: TextField(
                            controller: customCatCtrl,
                            style: ctx.text.titleMedium,
                            decoration: const InputDecoration(
                              hintText: 'Type custom category (saved to database)',
                              border: InputBorder.none,
                            ),
                          ),
                        ),
                      ),
                    ],
                    const SizedBox(height: Space.s24),
                    AppButton('Save Allowed Contact', onPressed: () async {
                      final name = nameCtrl.text.trim();
                      if (name.isEmpty) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('Please enter contact name')),
                        );
                        return;
                      }

                      final phone = phoneCtrl.text.trim();
                      final customTag = customCatCtrl.text.trim();
                      final tag = (useCustomCat && customTag.isNotEmpty)
                          ? customTag
                          : tags[selectedTagIndex];

                      if (user != null) {
                        context.read<AuthBloc>().add(
                              AuthAddContactRequested(
                                name: name,
                                phone: phone,
                                relationship: tag,
                              ),
                            );
                      } else {
                        final detail = phone.isNotEmpty ? '$tag • $phone' : tag;
                        final initial = name.isNotEmpty ? name[0].toUpperCase() : 'U';
                        setState(() {
                          _localFallbackContacts.add(
                            LetThroughContact(
                              initial: initial,
                              name: name,
                              detail: detail,
                              phone: phone,
                              relationship: tag,
                            ),
                          );
                        });
                        await _saveFallbackContacts();
                      }

                      if (modalCtx.mounted) Navigator.of(modalCtx).pop();
                      if (context.mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(content: Text('$name saved to allowed contacts')),
                        );
                      }
                    }),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  Future<void> _removeContact(int index, List<LetThroughContact> contacts, bool isAuthenticated) async {
    final contact = contacts[index];
    if (isAuthenticated && contact.id.isNotEmpty) {
      context.read<AuthBloc>().add(AuthDeleteContactRequested(contact.id));
    } else {
      setState(() {
        _localFallbackContacts.removeAt(index);
      });
      await _saveFallbackContacts();
    }
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('${contact.name} removed from allowed contacts')),
      );
    }
  }

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
        _useCustomEndTime = true;
      });
      final user = context.read<AuthBloc>().currentUser;
      if (user != null) {
        final now = DateTime.now();
        var targetDt = DateTime(now.year, now.month, now.day, picked.hour, picked.minute);
        if (targetDt.isBefore(now)) targetDt = targetDt.add(const Duration(days: 1));
        ApiService.instance.updatePreferences(activeSessionEndTime: targetDt);
      }
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
    final user = context.watch<AuthBloc>().currentUser;
    final dndState = context.watch<DndBloc>().state;
    final profiles = switch (dndState) {
      DndLoaded(:final profiles) => profiles,
      _ => sampleProfiles,
    };
    final activeProfile = profiles.where((p) => p.active).firstOrNull ??
        (profiles.isNotEmpty ? profiles.first : sampleProfiles.first);
    final activeProfileName = user?.activeProfileName.isNotEmpty == true
        ? user!.activeProfileName
        : activeProfile.name;

    final durations = user?.customDurations ?? const [30, 60];
    final safeIndex = _selectedChipIndex.clamp(0, durations.length - 1);
    final allowedContacts = user != null ? user.emergencyContacts : _localFallbackContacts;

    final customTimeLabel = 'Until ${_formatTimeOfDay(_customEndTime)}';
    final customRemaining = _calculateRemainingTime(_customEndTime);

    final durationSubtitle = _useCustomEndTime
        ? 'Quiet until ${_formatTimeOfDay(_customEndTime)} ($customRemaining)'
        : 'Quiet for ${_formatDurationLabel(durations[safeIndex], verbose: true)} once started';

    final activeSubtitle = _useCustomEndTime
        ? 'Quiet until ${_formatTimeOfDay(_customEndTime)}, $customRemaining'
        : 'Quiet for ${_formatDurationLabel(durations[safeIndex], verbose: true)} (active)';

    return ListView(
      padding: const EdgeInsets.fromLTRB(Space.s24, Space.s16, Space.s24, Space.s24),
      children: [
        _Header(
          dndOn: dndOn,
          activeProfileName: activeProfileName,
          onDiagnosticsTap: () => _showSystemDiagnostics(context),
        ),
        const SizedBox(height: Space.s24),
        Center(
          child: _PowerButton(
            on: dndOn,
            onTap: () => _triggerToggle(!dndOn, durations),
          ),
        ),
        const SizedBox(height: Space.s24),
        Text(
          dndOn ? '$activeProfileName is on' : 'Do Not Disturb is off',
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
        if (dndOn)
          ..._onContent(context, activeProfileName, durations, allowedContacts, user != null)
        else
          ..._offContent(context, customTimeLabel, durations, safeIndex, activeProfile, allowedContacts),
      ],
    );
  }

  List<Widget> _offContent(
    BuildContext context,
    String customTimeLabel,
    List<int> durations,
    int safeIndex,
    DndProfile nextProfile,
    List<LetThroughContact> allowedContacts,
  ) {
    final c = context.dnd;
    final user = context.read<AuthBloc>().currentUser;
    final labels = [
      for (final d in durations) _formatDurationLabel(d),
      customTimeLabel,
    ];
    final selectedChip = _useCustomEndTime ? durations.length : safeIndex;

    return [
      Center(
        child: SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              ChipRow(
                labels: labels,
                selected: selectedChip,
                onSelected: (i) async {
                  if (i == durations.length) {
                    await _pickCustomEndTime();
                  } else {
                    setState(() {
                      _useCustomEndTime = false;
                      _selectedChipIndex = i;
                    });
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
              if (user != null) ...[
                const SizedBox(width: Space.s8),
                ActionChip(
                  avatar: Icon(Icons.add, size: 16, color: c.accent),
                  label: Text(
                    'Add duration',
                    style: context.text.bodySmall!.copyWith(
                      color: c.accent,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  backgroundColor: c.surface,
                  side: BorderSide(color: c.border),
                  onPressed: () => _showAddCustomDurationDialog(context),
                ),
              ],
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
      const OverlineText('Active / Next Profile'),
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
            value: nextProfile.active ? 'Armed' : 'Ready',
          ),
        ),
      ),
      const SizedBox(height: Space.s16),
      Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          const Expanded(child: OverlineText('Allowed VIP Contacts')),
          TextButton.icon(
            icon: Icon(Icons.add, size: 16, color: c.accent),
            label: Text('Add', style: context.text.labelLarge?.copyWith(color: c.accent)),
            onPressed: () => _showAddContactDialog(context),
          ),
        ],
      ),
      const SizedBox(height: Space.s8),
      DndCard(
        child: SettingRow(
          icon: DndIcons.users,
          title: 'VIP & Allowed Contacts',
          subtitle: allowedContacts.isEmpty
              ? 'No contacts added yet • Tap to add VIP contacts'
              : '${allowedContacts.length} contact${allowedContacts.length > 1 ? 's' : ''} allowed to ring through',
          value: allowedContacts.isEmpty ? 'Add' : '${allowedContacts.length}',
          onTap: () => _showAddContactDialog(context),
        ),
      ),
    ];
  }

  Widget _contactItem(BuildContext context, LetThroughContact item, VoidCallback onRemove) {
    final c = context.dnd;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: Space.s16, vertical: Space.s8),
      child: Row(
        children: [
          CircleAvatar(
            radius: 18,
            backgroundColor: c.accentTint,
            child: Text(item.initial, style: context.text.labelLarge!.copyWith(color: c.accent)),
          ),
          const SizedBox(width: Space.s12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(item.name, style: context.text.labelLarge),
                Text(item.detail, style: context.text.bodySmall),
              ],
            ),
          ),
          Icon(DndIcons.phone, size: 20, color: c.armed),
          const SizedBox(width: Space.s4),
          IconButton(
            icon: Icon(Icons.close, size: 18, color: c.textSecondary),
            tooltip: 'Remove',
            onPressed: onRemove,
          ),
        ],
      ),
    );
  }

  List<Widget> _onContent(
    BuildContext context,
    String activeProfileName,
    List<int> durations,
    List<LetThroughContact> allowedContacts,
    bool isAuthenticated,
  ) {
    final c = context.dnd;
    Widget tile(String value, String label, {VoidCallback? onTap}) => Expanded(
          child: GestureDetector(
            onTap: onTap,
            child: DndCard(
              child: Padding(
                padding: const EdgeInsets.all(Space.s16),
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text(value, style: context.text.titleLarge),
                  Text(label, style: context.text.bodySmall),
                ]),
              ),
            ),
          ),
        );

    return [
      Row(children: [
        tile(
          '$_silencedTonight',
          'Silenced today (tap to log)',
          onTap: () async {
            final saved = await showLogSessionSheet(context, initialProfileName: activeProfileName);
            if (saved) _refreshTonightStats();
          },
        ),
        const SizedBox(width: Space.s12),
        tile(
          '${allowedContacts.length}',
          'Let through',
          onTap: () {
            if (widget.onOpenStabilityReport != null) {
              widget.onOpenStabilityReport!();
            } else {
              Navigator.of(context).push(
                MaterialPageRoute<void>(
                  builder: (_) => const Scaffold(body: SafeArea(child: StabilityReportScreen())),
                ),
              );
            }
          },
        ),
      ]),
      const SizedBox(height: Space.s24),
      Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          const Expanded(child: OverlineText('Let through by your rules')),
          TextButton.icon(
            icon: Icon(Icons.person_add_alt_1, size: 16, color: c.accent),
            label: Text('Add VIP', style: context.text.labelLarge?.copyWith(color: c.accent)),
            onPressed: () => _showAddContactDialog(context),
          ),
        ],
      ),
      const SizedBox(height: Space.s8),
      if (allowedContacts.isEmpty)
        DndCard(
          child: Padding(
            padding: const EdgeInsets.all(Space.s24),
            child: Column(
              children: [
                Icon(Icons.people_outline, size: 36, color: c.textSecondary),
                const SizedBox(height: Space.s8),
                Text('No allowed contacts yet', style: context.text.titleMedium),
                const SizedBox(height: Space.s4),
                Text(
                  'Add VIP contacts who can call or text through during Do Not Disturb.',
                  textAlign: TextAlign.center,
                  style: context.text.bodySmall?.copyWith(color: c.textSecondary),
                ),
                const SizedBox(height: Space.s16),
                AppButton(
                  'Add Allowed Contact',
                  type: AppButtonType.secondary,
                  onPressed: () => _showAddContactDialog(context),
                ),
              ],
            ),
          ),
        )
      else
        DndGroup(children: [
          for (var i = 0; i < allowedContacts.length; i++)
            _contactItem(
              context,
              allowedContacts[i],
              () => _removeContact(i, allowedContacts, isAuthenticated),
            ),
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
                _useCustomEndTime = true;
              });
              final now = DateTime.now();
              var targetDt = DateTime(now.year, now.month, now.day, newHour, _customEndTime.minute);
              if (targetDt.isBefore(now)) targetDt = targetDt.add(const Duration(days: 1));
              if (isAuthenticated) {
                ApiService.instance.updatePreferences(activeSessionEndTime: targetDt);
              }
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
            onPressed: () => _triggerToggle(false, durations),
          ),
        ),
      ]),
    ];
  }
}

class _Header extends StatelessWidget {
  const _Header({
    required this.dndOn,
    required this.activeProfileName,
    required this.onDiagnosticsTap,
  });

  final bool dndOn;
  final String activeProfileName;
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
          Text(dndOn ? '$activeProfileName profile' : '$timeGreeting, $name', style: context.text.bodySmall),
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

/// Interactive System Diagnostics sheet reading live backend health & BLoC status.
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
    final email = user?.email ?? '';
    if (email.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Sign in first to test OTP delivery to your email.')),
      );
      return;
    }

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
    final dbConnected = _healthResult?['dbConnected'] == true;
    final storageMode = _healthResult?['storageMode']?.toString() ?? 'checking';
    final smtpConfigured = _healthResult?['smtpConfigured'] == true;
    final uptime = _healthResult?['uptimeSeconds'] ?? 0;
    final user = context.watch<AuthBloc>().currentUser;
    final dndState = context.watch<DndBloc>().state;
    final profileCount = switch (dndState) {
      DndLoaded(:final profiles) => profiles.length,
      _ => 0,
    };

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
                  Icon(Icons.verified, color: isOnline ? c.armed : c.warning, size: 28),
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
                    ? '$service • Healthy (${latency}ms) • Uptime ${uptime}s'
                    : (_isChecking ? 'Checking backend...' : 'Backend offline or unreachable'),
                ok: isOnline,
                icon: Icons.cloud_done_outlined,
              ),
              const SizedBox(height: Space.s8),
              _item(
                context,
                title: 'MongoDB Database Cluster',
                subtitle: dbConnected
                    ? 'MongoDB Atlas connected & persisting live data'
                    : (isOnline ? 'Fallback mode ($storageMode)' : 'Awaiting API health check'),
                ok: dbConnected || isOnline,
                icon: Icons.storage_outlined,
              ),
              const SizedBox(height: Space.s8),
              _item(
                context,
                title: 'Zoho Mail SMTP OTP Engine',
                subtitle: smtpConfigured
                    ? 'SMTP configured for real 6-digit OTP delivery'
                    : 'Console / dev OTP mode (SMTP env not set)',
                ok: smtpConfigured,
                icon: Icons.mark_email_read_outlined,
              ),
              const SizedBox(height: Space.s8),
              _item(
                context,
                title: 'Active User & Profiles Sync',
                subtitle: user != null
                    ? '$profileCount profiles • ${user.emergencyContacts.length} VIP contacts • ${user.totalAppUsageMinutes}m app usage'
                    : 'Not signed in',
                ok: user != null,
                icon: Icons.sync_outlined,
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
                      label: const Text('Ping API'),
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
