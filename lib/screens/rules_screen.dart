import 'package:flutter/material.dart';

import '../core/models.dart';
import '../core/tokens.dart';
import '../widgets/widgets.dart';

/// Figma: "6 Rules". Groups come from GET /api/v1/profiles/{id}/schedules and /triggers.
class RulesScreen extends StatefulWidget {
  const RulesScreen({super.key});

  @override
  State<RulesScreen> createState() => _RulesScreenState();
}

class _RulesScreenState extends State<RulesScreen> {
  int _filter = 0;

  @override
  Widget build(BuildContext context) {
    Widget group(String label, List<SettingRow> rows) => Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            OverlineText(label),
            const SizedBox(height: 6),
            DndGroup(children: rows),
            const SizedBox(height: Space.s16),
          ],
        );

    return ListView(
      padding: const EdgeInsets.fromLTRB(Space.s24, Space.s16, Space.s24, Space.s24),
      children: [
        ScreenHeader(title: 'Rules', subtitle: '5 schedules and triggers', onAdd: () {}),
        const SizedBox(height: Space.s16),
        ChipRow(
          labels: const ['Time', 'Places', 'Wi-Fi', 'Calendar'],
          selected: _filter,
          onSelected: (i) => setState(() => _filter = i),
        ),
        const SizedBox(height: Space.s16),
        const WarningBanner(
          title: 'Work and Meeting overlap',
          message: 'Weekdays at 9 AM. Work wins because its priority is higher.',
        ),
        const SizedBox(height: Space.s16),
        group('Sleep · priority 80', const [
          SettingRow(icon: DndIcons.clock, title: 'Weeknights', subtitle: '10:00 PM to 6:30 AM, every night'),
          SettingRow(icon: DndIcons.pin, title: 'At Home', subtitle: 'Enter, within 150 m'),
        ]),
        group('Work · priority 70', const [
          SettingRow(icon: DndIcons.briefcase, title: 'Weekdays', subtitle: '9:00 AM to 6:00 PM'),
          SettingRow(icon: DndIcons.wifi, title: 'Office Wi-Fi', subtitle: 'Connect to HQ-Staff'),
        ]),
        group('Meeting · priority 60', const [
          SettingRow(icon: DndIcons.calendar, title: 'Calendar events', subtitle: 'Titles containing meeting'),
        ]),
      ],
    );
  }
}
