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
  late int _mode;
  late bool _autoReply;
  late bool _hideNotifications;

  @override
  void initState() {
    super.initState();
    final p = widget.profile;
    _nameController = TextEditingController(text: p?.name ?? 'New Profile');
    _mode = p?.mode.index ?? DndMode.priorityOnly.index;
    _autoReply = p?.autoReply ?? true;
    _hideNotifications = p?.hideNotifications ?? false;
  }

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  void _handleSave() {
    final nav = Navigator.of(context);
    final modeEnum = DndMode.values[_mode];
    final updated = (widget.profile ?? const DndProfile(name: '', icon: DndIcons.moon, meta: '')).copyWith(
      name: _nameController.text.trim(),
      mode: modeEnum,
      autoReply: _autoReply,
      hideNotifications: _hideNotifications,
    );

    context.read<DndBloc>().add(DndSaveProfileRequested(updated));
    nav.pop();
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
              TextButton(
                onPressed: nav.pop,
                child: Text('Delete', style: context.text.labelLarge!.copyWith(color: c.critical)),
              ),
            ]),
            Expanded(
              child: ListView(children: [
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
                      IconTile(icon: widget.profile?.icon ?? DndIcons.moon, filled: true),
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
                const DndGroup(children: [
                  SettingRow(icon: DndIcons.phone, title: 'Calls from', subtitle: 'Contacts you starred', value: 'Starred'),
                  SettingRow(icon: DndIcons.user, title: 'Messages from', subtitle: 'Only your VIP list', value: 'VIP only'),
                  SettingRow(icon: DndIcons.clock, title: 'Repeat callers', subtitle: 'A second call rings through', value: '15 min'),
                ]),
                const SizedBox(height: Space.s16),
                DndGroup(children: [
                  toggleRow('Auto-reply', 'Text callers that you are asleep', _autoReply,
                      (v) => setState(() => _autoReply = v)),
                  toggleRow('Hide notifications', 'Keep the lock screen clear', _hideNotifications,
                      (v) => setState(() => _hideNotifications = v)),
                ]),
              ]),
            ),
            const SizedBox(height: Space.s16),
            AppButton('Save profile', onPressed: _handleSave),
          ]),
        ),
      ),
    );
  }
}
