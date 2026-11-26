import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../bloc/auth/auth_bloc.dart';
import '../bloc/auth/auth_event.dart';
import '../bloc/dnd/dnd_bloc.dart';
import '../bloc/dnd/dnd_event.dart';
import '../core/models.dart';
import '../core/tokens.dart';
import '../widgets/widgets.dart';

/// Figma: "5 Profile editor" powered by DndBloc & user-defined choices saved to MongoDB.
class ProfileEditorScreen extends StatefulWidget {
  const ProfileEditorScreen({super.key, this.profile});

  final DndProfile? profile;

  @override
  State<ProfileEditorScreen> createState() => _ProfileEditorScreenState();
}

class _ProfileEditorScreenState extends State<ProfileEditorScreen> {
  late final TextEditingController _nameController;
  late final TextEditingController _metaController;
  late final TextEditingController _autoReplyMsgController;
  late final TextEditingController _customTagController;
  late IconData _icon;
  late int _mode;
  late bool _autoReply;
  late bool _hideNotifications;
  late String _callWhitelist;
  late String _messageWhitelist;
  late int _repeatCallersWindow;

  static const List<IconData> _selectableIcons = [
    DndIcons.moon,
    DndIcons.briefcase,
    DndIcons.users,
    DndIcons.car,
    DndIcons.book,
    DndIcons.shield,
    DndIcons.phone,
    DndIcons.bell,
    DndIcons.calendar,
  ];

  @override
  void initState() {
    super.initState();
    final p = widget.profile;
    _nameController = TextEditingController(text: p?.name ?? 'New Profile');
    _metaController = TextEditingController(
      text: p?.meta.isNotEmpty == true ? p!.meta : '10:00 PM – 7:00 AM',
    );
    _autoReplyMsgController = TextEditingController(
      text: p?.autoReplyMessage ?? 'I am currently in Do Not Disturb mode and will respond shortly.',
    );
    _customTagController = TextEditingController(text: p?.customTag ?? '');
    _icon = p?.icon ?? DndIcons.moon;
    _mode = p?.mode.index ?? DndMode.priorityOnly.index;
    _autoReply = p?.autoReply ?? true;
    _hideNotifications = p?.hideNotifications ?? false;
    _callWhitelist = p?.callWhitelist ?? 'Starred';
    _messageWhitelist = p?.messageWhitelist ?? 'VIP only';
    _repeatCallersWindow = p?.repeatCallersWindowMin ?? 15;
  }

  static String _formatTime(TimeOfDay time) {
    final hourOfPeriod = time.hourOfPeriod == 0 ? 12 : time.hourOfPeriod;
    final minuteStr = time.minute.toString().padLeft(2, '0');
    final period = time.period == DayPeriod.am ? 'AM' : 'PM';
    return '$hourOfPeriod:$minuteStr $period';
  }

  Future<void> _pickScheduleTimes() async {
    final start = await showTimePicker(
      context: context,
      initialTime: const TimeOfDay(hour: 22, minute: 0),
      helpText: 'SELECT PROFILE START TIME',
    );
    if (start == null || !mounted) return;

    final end = await showTimePicker(
      context: context,
      initialTime: const TimeOfDay(hour: 7, minute: 0),
      helpText: 'SELECT PROFILE END TIME',
    );
    if (end == null || !mounted) return;

    setState(() {
      _metaController.text = '${_formatTime(start)} – ${_formatTime(end)}';
    });
  }

  @override
  void dispose() {
    _nameController.dispose();
    _metaController.dispose();
    _autoReplyMsgController.dispose();
    _customTagController.dispose();
    super.dispose();
  }

  void _handleSave() {
    final name = _nameController.text.trim();
    if (name.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter a profile name')),
      );
      return;
    }

    final modeEnum = DndMode.values[_mode];
    final updated = (widget.profile ??
            const DndProfile(name: '', icon: DndIcons.moon, meta: 'Custom profile'))
        .copyWith(
      name: name,
      icon: _icon,
      meta: _metaController.text.trim(),
      mode: modeEnum,
      autoReply: _autoReply,
      hideNotifications: _hideNotifications,
      callWhitelist: _callWhitelist,
      messageWhitelist: _messageWhitelist,
      repeatCallersWindowMin: _repeatCallersWindow,
      autoReplyMessage: _autoReplyMsgController.text.trim(),
      customTag: _customTagController.text.trim(),
    );

    context.read<DndBloc>().add(DndSaveProfileRequested(updated));
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Profile "$name" saved to database')),
    );
    Navigator.of(context).pop();
  }

  Future<void> _confirmDelete() async {
    final p = widget.profile;
    if (p == null) return;

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete Profile'),
        content: Text('Are you sure you want to delete "${p.name}"? This action cannot be undone.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            style: TextButton.styleFrom(foregroundColor: ctx.dnd.critical),
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (confirmed == true && mounted) {
      context.read<DndBloc>().add(DndDeleteProfileRequested(p.id));
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Profile "${p.name}" deleted')),
      );
      Navigator.of(context).pop();
    }
  }

  void _showIconPicker() {
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
                Text('Choose Profile Icon', style: ctx.text.titleLarge),
                const SizedBox(height: Space.s16),
                Wrap(
                  spacing: Space.s16,
                  runSpacing: Space.s16,
                  children: _selectableIcons.map((ic) {
                    final selected = ic == _icon;
                    return GestureDetector(
                      onTap: () {
                        setState(() => _icon = ic);
                        Navigator.of(ctx).pop();
                      },
                      child: Container(
                        width: 54,
                        height: 54,
                        decoration: BoxDecoration(
                          color: selected ? c.accent : c.surfaceAlt,
                          shape: BoxShape.circle,
                        ),
                        child: Icon(ic, color: selected ? c.onAccent : c.textPrimary, size: 28),
                      ),
                    );
                  }).toList(),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  void _showOptionsPicker({
    required String title,
    required List<String> options,
    required String current,
    required ValueChanged<String> onSelected,
    bool allowCustom = true,
    bool numericMinutes = false,
  }) {
    final c = context.dnd;
    final customCtrl = TextEditingController();
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: c.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(Radii.card)),
      ),
      builder: (ctx) {
        return SafeArea(
          child: Padding(
            padding: EdgeInsets.only(
              top: Space.s16,
              bottom: MediaQuery.of(ctx).viewInsets.bottom + Space.s16,
            ),
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: Space.s24),
                    child: Text(title, style: ctx.text.titleLarge),
                  ),
                  const SizedBox(height: Space.s12),
                  for (final opt in options)
                    ListTile(
                      title: Text(opt, style: ctx.text.titleMedium),
                      trailing: opt == current ? Icon(Icons.check, color: c.accent) : null,
                      onTap: () {
                        onSelected(opt);
                        Navigator.of(ctx).pop();
                      },
                    ),
                  if (allowCustom) ...[
                    const DndDivider(),
                    Padding(
                      padding: const EdgeInsets.fromLTRB(Space.s24, Space.s12, Space.s24, Space.s8),
                      child: Row(
                        children: [
                          Expanded(
                            child: TextField(
                              controller: customCtrl,
                              keyboardType:
                                  numericMinutes ? TextInputType.number : TextInputType.text,
                              decoration: InputDecoration(
                                hintText: numericMinutes
                                    ? 'Custom minutes (e.g. 10)'
                                    : 'Add custom choice (saved to DB)',
                                isDense: true,
                              ),
                            ),
                          ),
                          const SizedBox(width: Space.s8),
                          TextButton(
                            onPressed: () {
                              final raw = customCtrl.text.trim();
                              if (raw.isEmpty) return;
                              if (numericMinutes) {
                                final mins = int.tryParse(raw);
                                if (mins != null && mins > 0) {
                                  onSelected('$mins min');
                                  Navigator.of(ctx).pop();
                                }
                              } else {
                                context.read<AuthBloc>().add(AuthAddCustomWhitelistRequested(raw));
                                onSelected(raw);
                                Navigator.of(ctx).pop();
                              }
                            },
                            child: const Text('Add & Use'),
                          ),
                        ],
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final c = context.dnd;
    final nav = Navigator.of(context);
    final user = context.watch<AuthBloc>().currentUser;
    final whitelistChoices = <String>{
      ...?user?.customWhitelistOptions,
      'Starred',
      'Contacts only',
      'VIP only',
      'Work Team',
      'Everyone',
      'No one',
      _callWhitelist,
      _messageWhitelist,
    }.where((e) => e.isNotEmpty).toList();

    Widget toggleRow(String title, String sub, bool value, ValueChanged<bool> onChanged) => Padding(
          padding: const EdgeInsets.symmetric(horizontal: Space.s16, vertical: Space.s12),
          child: Row(children: [
            Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(title, style: context.text.labelLarge),
                Text(sub, style: context.text.bodySmall),
              ]),
            ),
            Switch(value: value, onChanged: onChanged),
          ]),
        );

    return Scaffold(
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(Space.s24, Space.s8, Space.s24, Space.s24),
          child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
              TextButton(
                onPressed: nav.pop,
                child: Text('Cancel', style: context.text.labelLarge!.copyWith(color: c.accent)),
              ),
              Text(widget.profile == null ? 'New profile' : 'Edit profile', style: context.text.titleMedium),
              if (widget.profile != null)
                TextButton(
                  onPressed: _confirmDelete,
                  child: Text('Delete', style: context.text.labelLarge!.copyWith(color: c.critical)),
                )
              else
                const SizedBox(width: 48),
            ]),
            Expanded(
              child: ListView(
                keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
                children: [
                  const SizedBox(height: Space.s8),
                  DndCard(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: Space.s16, vertical: 14),
                      child: Row(children: [
                        Expanded(
                          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                            const OverlineText('Profile name'),
                            TextFormField(
                              controller: _nameController,
                              style: context.text.titleMedium,
                              decoration: const InputDecoration(
                                isDense: true,
                                border: InputBorder.none,
                                contentPadding: EdgeInsets.only(top: 2),
                              ),
                            ),
                          ]),
                        ),
                        GestureDetector(
                          onTap: _showIconPicker,
                          child: Stack(
                            alignment: Alignment.bottomRight,
                            children: [
                              IconTile(icon: _icon, filled: true),
                              Container(
                                padding: const EdgeInsets.all(2),
                                decoration: BoxDecoration(
                                  color: c.accent,
                                  shape: BoxShape.circle,
                                ),
                                child: Icon(Icons.edit, size: 10, color: c.onAccent),
                              ),
                            ],
                          ),
                        ),
                      ]),
                    ),
                  ),
                  const SizedBox(height: Space.s16),
                  const OverlineText('Mode'),
                  const SizedBox(height: Space.s8),
                  ChipRow(
                    labels: const ['Total silence', 'Priority only', 'Alarms only', 'Custom'],
                    selected: _mode,
                    onSelected: (i) => setState(() => _mode = i),
                  ),
                  const SizedBox(height: Space.s16),
                  const OverlineText('Schedule / Description'),
                  const SizedBox(height: Space.s8),
                  DndCard(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: Space.s16, vertical: 8),
                      child: Row(
                        children: [
                          Expanded(
                            child: TextField(
                              controller: _metaController,
                              style: context.text.bodyLarge,
                              decoration: const InputDecoration(
                                hintText: 'e.g. 10:00 PM – 7:00 AM',
                                border: InputBorder.none,
                              ),
                            ),
                          ),
                          IconButton(
                            icon: Icon(DndIcons.clock, color: c.accent),
                            tooltip: 'Pick Start & End Time',
                            onPressed: _pickScheduleTimes,
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: Space.s16),
                  const OverlineText('Who gets through'),
                  const SizedBox(height: Space.s8),
                  DndGroup(children: [
                    GestureDetector(
                      behavior: HitTestBehavior.opaque,
                      onTap: () {
                        _showOptionsPicker(
                          title: 'Calls from',
                          options: whitelistChoices,
                          current: _callWhitelist,
                          onSelected: (val) => setState(() => _callWhitelist = val),
                        );
                      },
                      child: SettingRow(
                        icon: DndIcons.phone,
                        title: 'Calls from',
                        subtitle: 'Tap to pick or add custom group',
                        value: _callWhitelist,
                      ),
                    ),
                    GestureDetector(
                      behavior: HitTestBehavior.opaque,
                      onTap: () {
                        _showOptionsPicker(
                          title: 'Messages from',
                          options: whitelistChoices,
                          current: _messageWhitelist,
                          onSelected: (val) => setState(() => _messageWhitelist = val),
                        );
                      },
                      child: SettingRow(
                        icon: DndIcons.user,
                        title: 'Messages from',
                        subtitle: 'Tap to pick or add custom group',
                        value: _messageWhitelist,
                      ),
                    ),
                    GestureDetector(
                      behavior: HitTestBehavior.opaque,
                      onTap: () {
                        _showOptionsPicker(
                          title: 'Repeat callers',
                          options: const ['15 min', '5 min', '3 min', 'Off'],
                          current: _repeatCallersWindow == 0 ? 'Off' : '$_repeatCallersWindow min',
                          numericMinutes: true,
                          onSelected: (val) {
                            setState(() {
                              _repeatCallersWindow = val == 'Off'
                                  ? 0
                                  : (int.tryParse(val.replaceAll(' min', '')) ?? 15);
                            });
                          },
                        );
                      },
                      child: SettingRow(
                        icon: DndIcons.clock,
                        title: 'Repeat callers',
                        subtitle: 'A second call rings through',
                        value: _repeatCallersWindow == 0 ? 'Off' : '$_repeatCallersWindow min',
                      ),
                    ),
                  ]),
                  const SizedBox(height: Space.s16),
                  DndGroup(children: [
                    toggleRow('Auto-reply', 'Send custom message when unavailable', _autoReply,
                        (v) => setState(() => _autoReply = v)),
                    toggleRow('Hide notifications', 'Keep the lock screen clear', _hideNotifications,
                        (v) => setState(() => _hideNotifications = v)),
                  ]),
                  if (_autoReply) ...[
                    const SizedBox(height: Space.s16),
                    const OverlineText('Custom Auto-Reply Message'),
                    const SizedBox(height: Space.s8),
                    DndCard(
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: Space.s16, vertical: 4),
                        child: TextField(
                          controller: _autoReplyMsgController,
                          maxLines: 2,
                          style: context.text.bodyMedium,
                          decoration: const InputDecoration(
                            hintText: 'Enter custom auto-reply message...',
                            border: InputBorder.none,
                          ),
                        ),
                      ),
                    ),
                  ],
                  const SizedBox(height: Space.s16),
                  const OverlineText('Custom Label / Tag (Optional)'),
                  const SizedBox(height: Space.s8),
                  DndCard(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: Space.s16, vertical: 4),
                      child: TextField(
                        controller: _customTagController,
                        style: context.text.bodyMedium,
                        decoration: const InputDecoration(
                          hintText: 'e.g. Deep Focus, Night Routine',
                          border: InputBorder.none,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: Space.s24),
                  AppButton('Save profile', onPressed: _handleSave),
                  const SizedBox(height: Space.s16),
                ],
              ),
            ),
          ]),
        ),
      ),
    );
  }
}
