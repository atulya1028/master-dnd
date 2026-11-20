import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../bloc/dnd/dnd_bloc.dart';
import '../bloc/dnd/dnd_event.dart';
import '../core/models.dart';
import '../core/tokens.dart';
import '../widgets/widgets.dart';

/// Figma: "5 Profile editor" powered by DndBloc.
class ProfileEditorScreen extends StatefulWidget {
  const ProfileEditorScreen({super.key, this.profile});

  final DndProfile? profile;

  @override
  State<ProfileEditorScreen> createState() => _ProfileEditorScreenState();
}

class _ProfileEditorScreenState extends State<ProfileEditorScreen> {
  late final TextEditingController _nameController;
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
    _icon = p?.icon ?? DndIcons.moon;
    _mode = p?.mode.index ?? DndMode.priorityOnly.index;
    _autoReply = p?.autoReply ?? true;
    _hideNotifications = p?.hideNotifications ?? false;
    _callWhitelist = p?.callWhitelist ?? 'Starred';
    _messageWhitelist = p?.messageWhitelist ?? 'VIP only';
    _repeatCallersWindow = p?.repeatCallersWindowMin ?? 15;
  }

  @override
  void dispose() {
    _nameController.dispose();
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
      mode: modeEnum,
      autoReply: _autoReply,
      hideNotifications: _hideNotifications,
      callWhitelist: _callWhitelist,
      messageWhitelist: _messageWhitelist,
      repeatCallersWindowMin: _repeatCallersWindow,
    );

    context.read<DndBloc>().add(DndSaveProfileRequested(updated));
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Profile "$name" saved successfully')),
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
  }) {
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
            padding: const EdgeInsets.symmetric(vertical: Space.s16),
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
              ],
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
                  const OverlineText('Who gets through'),
                  const SizedBox(height: Space.s8),
                  DndGroup(children: [
                    GestureDetector(
                      behavior: HitTestBehavior.opaque,
                      onTap: () {
                        _showOptionsPicker(
                          title: 'Calls from',
                          options: const ['Starred', 'Contacts only', 'Everyone', 'No one'],
                          current: _callWhitelist,
                          onSelected: (val) => setState(() => _callWhitelist = val),
                        );
                      },
                      child: SettingRow(
                        icon: DndIcons.phone,
                        title: 'Calls from',
                        subtitle: 'Tap to configure caller access',
                        value: _callWhitelist,
                      ),
                    ),
                    GestureDetector(
                      behavior: HitTestBehavior.opaque,
                      onTap: () {
                        _showOptionsPicker(
                          title: 'Messages from',
                          options: const ['VIP only', 'Contacts only', 'Everyone', 'No one'],
                          current: _messageWhitelist,
                          onSelected: (val) => setState(() => _messageWhitelist = val),
                        );
                      },
                      child: SettingRow(
                        icon: DndIcons.user,
                        title: 'Messages from',
                        subtitle: 'Tap to configure message access',
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
                    toggleRow('Auto-reply', 'Text callers that you are asleep', _autoReply,
                        (v) => setState(() => _autoReply = v)),
                    toggleRow('Hide notifications', 'Keep the lock screen clear', _hideNotifications,
                        (v) => setState(() => _hideNotifications = v)),
                  ]),
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
