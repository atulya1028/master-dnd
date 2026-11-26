import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../bloc/dnd/dnd_bloc.dart';
import '../bloc/dnd/dnd_state.dart';
import '../core/api_service.dart';
import '../core/models.dart';
import '../core/tokens.dart';
import '../widgets/widgets.dart';

/// Figma: "6 Rules". Schedules and triggers backed by ApiService and MongoDB.
class RulesScreen extends StatefulWidget {
  const RulesScreen({super.key});

  @override
  State<RulesScreen> createState() => _RulesScreenState();
}

class _RulesScreenState extends State<RulesScreen> {
  int _filter = 0;
  bool _isLoading = true;
  List<DndRule> _rules = [];

  static const List<String> _baseFilters = ['All', 'Time', 'Places', 'Wi-Fi', 'Calendar'];
  static const List<String> _allDays = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];

  @override
  void initState() {
    super.initState();
    _fetchRules();
  }

  Future<void> _fetchRules() async {
    setState(() => _isLoading = true);
    try {
      final fetched = await ApiService.instance.getRules();
      if (mounted) {
        setState(() {
          _rules = fetched;
          _isLoading = false;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _toggleRule(DndRule rule, bool active) async {
    setState(() {
      _rules = [
        for (final r in _rules)
          if (r.id == rule.id) r.copyWith(active: active) else r,
      ];
    });

    await ApiService.instance.updateRule(rule.id, active: active);
  }

  Future<void> _deleteRule(DndRule rule) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete Rule'),
        content: Text('Are you sure you want to delete rule "${rule.title}"?'),
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
      setState(() => _rules.removeWhere((r) => r.id == rule.id));
      await ApiService.instance.deleteRule(rule.id);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Rule "${rule.title}" deleted')),
        );
      }
    }
  }

  static String _formatTimeOfDay(TimeOfDay time) {
    final hourOfPeriod = time.hourOfPeriod == 0 ? 12 : time.hourOfPeriod;
    final minuteStr = time.minute.toString().padLeft(2, '0');
    final period = time.period == DayPeriod.am ? 'AM' : 'PM';
    return '$hourOfPeriod:$minuteStr $period';
  }

  List<String> _availableProfileNames() {
    final dndState = context.read<DndBloc>().state;
    final list = switch (dndState) {
      DndLoaded(:final profiles) when profiles.isNotEmpty => profiles.map((p) => p.name).toList(),
      _ => sampleProfiles.map((p) => p.name).toList(),
    };
    return list;
  }

  void _showRuleSheet({DndRule? existing}) {
    final isEdit = existing != null;
    final titleController = TextEditingController(text: existing?.title ?? '');
    final subtitleController = TextEditingController(
      text: existing?.subtitle ?? '10:00 PM – 7:00 AM (Mon - Fri)',
    );
    final customTypeController = TextEditingController();
    final customConditionController = TextEditingController(text: existing?.customCondition ?? '');

    final baseTypes = ['schedule', 'location', 'wifi', 'calendar'];
    final typeLabels = ['Time', 'Places', 'Wi-Fi', 'Calendar'];
    int selectedTypeIndex = 0;
    bool useCustomType = false;
    if (existing != null) {
      final idx = baseTypes.indexOf(existing.triggerType.toLowerCase());
      if (idx >= 0) {
        selectedTypeIndex = idx;
      } else {
        useCustomType = true;
        customTypeController.text = existing.triggerType;
      }
    }

    List<String> selectedDays = List<String>.from(existing?.days ?? _allDays);
    final profileNames = _availableProfileNames();
    String selectedProfile = existing?.targetProfileName.isNotEmpty == true
        ? existing!.targetProfileName
        : (profileNames.isNotEmpty ? profileNames.first : 'Sleep');
    if (!profileNames.contains(selectedProfile)) {
      profileNames.insert(0, selectedProfile);
    }

    TimeOfDay startTime = const TimeOfDay(hour: 22, minute: 0);
    TimeOfDay endTime = const TimeOfDay(hour: 7, minute: 0);

    void updateScheduleText() {
      final daysText = selectedDays.length == 7
          ? 'Every day'
          : (selectedDays.length == 5 && !selectedDays.contains('Sat') && !selectedDays.contains('Sun')
              ? 'Mon - Fri'
              : selectedDays.join(', '));
      subtitleController.text = '${_formatTimeOfDay(startTime)} – ${_formatTimeOfDay(endTime)} ($daysText)';
    }

    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: context.dnd.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(Radii.card)),
      ),
      builder: (ctx) {
        return StatefulBuilder(
          builder: (modalCtx, setModalState) {
            return Padding(
              padding: EdgeInsets.only(
                left: Space.s24,
                right: Space.s24,
                top: Space.s24,
                bottom: MediaQuery.of(modalCtx).viewInsets.bottom + Space.s24,
              ),
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(isEdit ? 'Edit Rule' : 'Create New Rule',
                              style: modalCtx.text.titleLarge),
                        ),
                        if (isEdit)
                          IconButton(
                            icon: Icon(Icons.delete_outline, color: modalCtx.dnd.critical),
                            tooltip: 'Delete Rule',
                            onPressed: () {
                              Navigator.of(modalCtx).pop();
                              _deleteRule(existing);
                            },
                          ),
                      ],
                    ),
                    const SizedBox(height: Space.s16),
                    const OverlineText('Rule Title'),
                    const SizedBox(height: Space.s8),
                    DndCard(
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: Space.s16, vertical: 4),
                        child: TextField(
                          controller: titleController,
                          style: modalCtx.text.titleMedium,
                          decoration: const InputDecoration(
                            hintText: 'e.g. Bedtime Quiet or Study Hours',
                            border: InputBorder.none,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: Space.s16),
                    const OverlineText('Trigger Type'),
                    const SizedBox(height: Space.s8),
                    Wrap(
                      spacing: Space.s8,
                      runSpacing: Space.s8,
                      children: [
                        for (var i = 0; i < typeLabels.length; i++)
                          ChoiceChip(
                            label: Text(typeLabels[i]),
                            selected: !useCustomType && selectedTypeIndex == i,
                            onSelected: (_) {
                              setModalState(() {
                                useCustomType = false;
                                selectedTypeIndex = i;
                                if (!isEdit) {
                                  if (i == 0) {
                                    updateScheduleText();
                                  } else if (i == 1) {
                                    subtitleController.text = 'When arriving at Office';
                                  } else if (i == 2) {
                                    subtitleController.text = 'Connected to Home Wi-Fi';
                                  } else {
                                    subtitleController.text = 'During "Busy" calendar events';
                                  }
                                }
                              });
                            },
                          ),
                        ChoiceChip(
                          label: const Text('+ Custom'),
                          selected: useCustomType,
                          onSelected: (_) => setModalState(() => useCustomType = true),
                        ),
                      ],
                    ),
                    if (useCustomType) ...[
                      const SizedBox(height: Space.s12),
                      DndCard(
                        child: Padding(
                          padding: const EdgeInsets.symmetric(horizontal: Space.s16, vertical: 4),
                          child: TextField(
                            controller: customTypeController,
                            style: modalCtx.text.titleMedium,
                            decoration: const InputDecoration(
                              hintText: 'Enter custom trigger type (e.g. app, bluetooth)',
                              border: InputBorder.none,
                            ),
                          ),
                        ),
                      ),
                    ],
                    const SizedBox(height: Space.s16),
                    const OverlineText('Target DND Profile'),
                    const SizedBox(height: Space.s8),
                    Wrap(
                      spacing: Space.s8,
                      runSpacing: Space.s8,
                      children: [
                        for (final pname in profileNames)
                          ChoiceChip(
                            label: Text(pname),
                            selected: selectedProfile == pname,
                            onSelected: (_) => setModalState(() => selectedProfile = pname),
                          ),
                      ],
                    ),
                    const SizedBox(height: Space.s16),
                    const OverlineText('Active Days'),
                    const SizedBox(height: Space.s8),
                    Wrap(
                      spacing: 6,
                      runSpacing: 6,
                      children: [
                        for (final day in _allDays)
                          FilterChip(
                            label: Text(day),
                            selected: selectedDays.contains(day),
                            onSelected: (sel) {
                              setModalState(() {
                                if (sel) {
                                  if (!selectedDays.contains(day)) selectedDays.add(day);
                                } else if (selectedDays.length > 1) {
                                  selectedDays.remove(day);
                                }
                                if (!useCustomType && selectedTypeIndex == 0) {
                                  updateScheduleText();
                                }
                              });
                            },
                          ),
                      ],
                    ),
                    const SizedBox(height: Space.s16),
                    if (!useCustomType && selectedTypeIndex == 0) ...[
                      const OverlineText('Set Schedule Hours'),
                      const SizedBox(height: Space.s8),
                      Row(
                        children: [
                          Expanded(
                            child: OutlinedButton.icon(
                              icon: const Icon(Icons.access_time, size: 16),
                              label: Text('Start: ${_formatTimeOfDay(startTime)}'),
                              onPressed: () async {
                                final picked = await showTimePicker(
                                  context: modalCtx,
                                  initialTime: startTime,
                                  helpText: 'SELECT START TIME',
                                );
                                if (picked != null) {
                                  setModalState(() {
                                    startTime = picked;
                                    updateScheduleText();
                                  });
                                }
                              },
                            ),
                          ),
                          const SizedBox(width: Space.s8),
                          Expanded(
                            child: OutlinedButton.icon(
                              icon: const Icon(Icons.access_time_filled, size: 16),
                              label: Text('End: ${_formatTimeOfDay(endTime)}'),
                              onPressed: () async {
                                final picked = await showTimePicker(
                                  context: modalCtx,
                                  initialTime: endTime,
                                  helpText: 'SELECT END TIME',
                                );
                                if (picked != null) {
                                  setModalState(() {
                                    endTime = picked;
                                    updateScheduleText();
                                  });
                                }
                              },
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: Space.s16),
                    ],
                    const OverlineText('Trigger Condition / Schedule Description'),
                    const SizedBox(height: Space.s8),
                    DndCard(
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: Space.s16, vertical: 4),
                        child: TextField(
                          controller: subtitleController,
                          style: modalCtx.text.titleMedium,
                          decoration: const InputDecoration(
                            hintText: 'e.g. 10:00 PM – 7:00 AM (Mon - Fri)',
                            border: InputBorder.none,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: Space.s12),
                    const OverlineText('Custom Condition Note (Optional)'),
                    const SizedBox(height: Space.s8),
                    DndCard(
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: Space.s16, vertical: 4),
                        child: TextField(
                          controller: customConditionController,
                          style: modalCtx.text.bodyLarge,
                          decoration: const InputDecoration(
                            hintText: 'e.g. Wi-Fi SSID, Office address, or App name',
                            border: InputBorder.none,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: Space.s24),
                    AppButton(isEdit ? 'Save Changes' : 'Create Rule', onPressed: () async {
                      final title = titleController.text.trim();
                      if (title.isEmpty) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('Please enter a rule title')),
                        );
                        return;
                      }
                      final triggerType = useCustomType && customTypeController.text.trim().isNotEmpty
                          ? customTypeController.text.trim().toLowerCase()
                          : baseTypes[selectedTypeIndex];
                      final sub = subtitleController.text.trim().isNotEmpty
                          ? subtitleController.text.trim()
                          : 'Trigger: $triggerType';
                      final cond = customConditionController.text.trim();

                      Navigator.of(modalCtx).pop();

                      if (isEdit) {
                        setState(() {
                          _rules = [
                            for (final r in _rules)
                              if (r.id == existing.id)
                                r.copyWith(
                                  title: title,
                                  subtitle: sub,
                                  triggerType: triggerType,
                                  days: selectedDays,
                                  targetProfileName: selectedProfile,
                                  customCondition: cond,
                                )
                              else
                                r,
                          ];
                        });
                        await ApiService.instance.updateRule(
                          existing.id,
                          title: title,
                          subtitle: sub,
                          triggerType: triggerType,
                          days: selectedDays,
                          targetProfileName: selectedProfile,
                          customCondition: cond,
                        );
                        if (mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(content: Text('Rule "$title" updated in database')),
                          );
                        }
                      } else {
                        final newRule = DndRule(
                          title: title,
                          subtitle: sub,
                          triggerType: triggerType,
                          days: selectedDays,
                          targetProfileName: selectedProfile,
                          customCondition: cond,
                          active: true,
                        );
                        final created = await ApiService.instance.createRule(newRule);
                        if (created != null && mounted) {
                          setState(() => _rules.add(created));
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(content: Text('Rule "$title" saved to database')),
                          );
                        } else {
                          _fetchRules();
                        }
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

  List<String> get _dynamicFilters {
    final extra = <String>[];
    for (final r in _rules) {
      final t = r.triggerType.toLowerCase();
      if (t != 'schedule' &&
          t != 'time' &&
          t != 'location' &&
          t != 'places' &&
          t != 'place' &&
          t != 'wifi' &&
          t != 'wi-fi' &&
          t != 'calendar') {
        final label = t[0].toUpperCase() + t.substring(1);
        if (!extra.contains(label)) extra.add(label);
      }
    }
    return [..._baseFilters, ...extra];
  }

  List<DndRule> get _filteredRules {
    final filters = _dynamicFilters;
    final idx = _filter.clamp(0, filters.length - 1);
    if (idx == 0) return _rules;
    final category = filters[idx].toLowerCase();
    return _rules.where((r) {
      final t = r.triggerType.toLowerCase();
      if (category == 'time') return t == 'schedule' || t == 'time';
      if (category == 'places') return t == 'location' || t == 'places' || t == 'place';
      if (category == 'wi-fi') return t == 'wifi' || t == 'wi-fi';
      if (category == 'calendar') return t == 'calendar';
      return t == category;
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    final c = context.dnd;
    final filters = _dynamicFilters;
    final safeFilter = _filter.clamp(0, filters.length - 1);
    final rules = _filteredRules;
    final activeRulesCount = _rules.where((r) => r.active).length;

    return RefreshIndicator(
      onRefresh: _fetchRules,
      child: ListView(
        padding: const EdgeInsets.fromLTRB(Space.s24, Space.s16, Space.s24, Space.s24),
        children: [
          ScreenHeader(
            title: 'Rules',
            subtitle: '${_rules.length} schedules and triggers ($activeRulesCount active)',
            onAdd: () => _showRuleSheet(),
          ),
          const SizedBox(height: Space.s16),
          ChipRow(
            labels: filters,
            selected: safeFilter,
            onSelected: (i) => setState(() => _filter = i),
          ),
          const SizedBox(height: Space.s16),
          if (activeRulesCount > 1) ...[
            WarningBanner(
              title: '$activeRulesCount automated rules active',
              message:
                  'Active rules target ${_rules.where((r) => r.active && r.targetProfileName.isNotEmpty).map((r) => r.targetProfileName).toSet().isEmpty ? 'your active profile' : _rules.where((r) => r.active && r.targetProfileName.isNotEmpty).map((r) => r.targetProfileName).toSet().join(', ')}.',
            ),
            const SizedBox(height: Space.s16),
          ],
          if (_isLoading)
            const Center(
              child: Padding(
                padding: EdgeInsets.all(Space.s32),
                child: CircularProgressIndicator(),
              ),
            )
          else if (rules.isEmpty)
            Center(
              child: Padding(
                padding: const EdgeInsets.all(Space.s32),
                child: Column(
                  children: [
                    Icon(DndIcons.clock, size: 48, color: c.textSecondary),
                    const SizedBox(height: Space.s12),
                    Text('No rules found in this category', style: context.text.bodyMedium),
                    const SizedBox(height: Space.s16),
                    AppButton(
                      'Add a rule',
                      type: AppButtonType.secondary,
                      onPressed: () => _showRuleSheet(),
                    ),
                  ],
                ),
              ),
            )
          else
            DndCard(
              child: Column(
                children: [
                  for (var i = 0; i < rules.length; i++) ...[
                    if (i > 0) const DndDivider(),
                    InkWell(
                      onTap: () => _showRuleSheet(existing: rules[i]),
                      onLongPress: () => _deleteRule(rules[i]),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: Space.s16, vertical: 12),
                        child: Row(
                          children: [
                            IconTile(icon: rules[i].icon, size: 40, iconSize: 20, filled: rules[i].active),
                            const SizedBox(width: Space.s12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(rules[i].title, style: context.text.labelLarge),
                                  Text(
                                    rules[i].targetProfileName.isNotEmpty
                                        ? '${rules[i].subtitle} • ${rules[i].targetProfileName}'
                                        : rules[i].subtitle,
                                    style: context.text.bodySmall,
                                  ),
                                ],
                              ),
                            ),
                            IconButton(
                              icon: const Icon(Icons.edit_outlined, size: 18),
                              tooltip: 'Edit Schedule',
                              onPressed: () => _showRuleSheet(existing: rules[i]),
                            ),
                            Switch(
                              value: rules[i].active,
                              onChanged: (v) => _toggleRule(rules[i], v),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            ),
          const SizedBox(height: Space.s24),
          AppButton('Add new rule', type: AppButtonType.secondary, onPressed: () => _showRuleSheet()),
        ],
      ),
    );
  }
}
