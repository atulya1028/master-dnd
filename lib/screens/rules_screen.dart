import 'package:flutter/material.dart';

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

  static const List<String> _filters = ['All', 'Time', 'Places', 'Wi-Fi', 'Calendar'];

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

  void _showAddRuleDialog() {
    final titleController = TextEditingController();
    final subtitleController = TextEditingController();
    int selectedTypeIndex = 0;
    final types = ['schedule', 'location', 'wifi', 'calendar'];
    final typeLabels = ['Time', 'Places', 'Wi-Fi', 'Calendar'];

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
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text('Create New Rule', style: modalCtx.text.titleLarge),
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
                          hintText: 'e.g. Study Hours or Gym',
                          border: InputBorder.none,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: Space.s16),
                  const OverlineText('Trigger Condition / Schedule'),
                  const SizedBox(height: Space.s8),
                  DndCard(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: Space.s16, vertical: 4),
                      child: TextField(
                        controller: subtitleController,
                        style: modalCtx.text.titleMedium,
                        decoration: const InputDecoration(
                          hintText: 'e.g. Mon to Fri 4:00 PM to 7:00 PM',
                          border: InputBorder.none,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: Space.s16),
                  const OverlineText('Trigger Type'),
                  const SizedBox(height: Space.s8),
                  ChipRow(
                    labels: typeLabels,
                    selected: selectedTypeIndex,
                    onSelected: (i) => setModalState(() => selectedTypeIndex = i),
                  ),
                  const SizedBox(height: Space.s24),
                  AppButton('Create Rule', onPressed: () async {
                    final title = titleController.text.trim();
                    if (title.isEmpty) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('Please enter a rule title')),
                      );
                      return;
                    }

                    final newRule = DndRule(
                      title: title,
                      subtitle: subtitleController.text.trim().isNotEmpty
                          ? subtitleController.text.trim()
                          : 'Trigger: ${typeLabels[selectedTypeIndex]}',
                      triggerType: types[selectedTypeIndex],
                      active: true,
                    );

                    Navigator.of(modalCtx).pop();
                    final created = await ApiService.instance.createRule(newRule);
                    if (created != null && mounted) {
                      setState(() => _rules.add(created));
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(content: Text('Rule "$title" created successfully')),
                      );
                    } else {
                      _fetchRules();
                    }
                  }),
                ],
              ),
            );
          },
        );
      },
    );
  }

  List<DndRule> get _filteredRules {
    if (_filter == 0) return _rules;
    final category = _filters[_filter].toLowerCase();
    return _rules.where((r) {
      final t = r.triggerType.toLowerCase();
      if (category == 'time') return t == 'schedule' || t == 'time';
      if (category == 'places') return t == 'location' || t == 'places' || t == 'place';
      if (category == 'wi-fi') return t == 'wifi' || t == 'wi-fi';
      if (category == 'calendar') return t == 'calendar';
      return true;
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    final c = context.dnd;
    final rules = _filteredRules;

    return RefreshIndicator(
      onRefresh: _fetchRules,
      child: ListView(
        padding: const EdgeInsets.fromLTRB(Space.s24, Space.s16, Space.s24, Space.s24),
        children: [
          ScreenHeader(
            title: 'Rules',
            subtitle: '${_rules.length} schedules and triggers',
            onAdd: _showAddRuleDialog,
          ),
          const SizedBox(height: Space.s16),
          ChipRow(
            labels: _filters,
            selected: _filter,
            onSelected: (i) => setState(() => _filter = i),
          ),
          const SizedBox(height: Space.s16),
          const WarningBanner(
            title: 'Schedule overlap management',
            message: 'When multiple rules activate at once, higher priority profiles take precedence.',
          ),
          const SizedBox(height: Space.s16),
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
                    AppButton('Add a rule', type: AppButtonType.secondary, onPressed: _showAddRuleDialog),
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
                      onTap: () => _toggleRule(rules[i], !rules[i].active),
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
                                  Text(rules[i].subtitle, style: context.text.bodySmall),
                                ],
                              ),
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
          AppButton('Add new rule', type: AppButtonType.secondary, onPressed: _showAddRuleDialog),
        ],
      ),
    );
  }
}
