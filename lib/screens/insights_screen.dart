import 'package:flutter/material.dart';

import '../core/tokens.dart';
import '../widgets/widgets.dart';

/// Figma: "7 Insights". Data comes from GET /api/v1/insights/weekly.
class InsightsScreen extends StatefulWidget {
  const InsightsScreen({super.key});

  @override
  State<InsightsScreen> createState() => _InsightsScreenState();
}

class _InsightsScreenState extends State<InsightsScreen> {
  int _range = 0;

  static const _days = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
  static const _hours = [4.5, 5.0, 3.8, 5.6, 4.4, 4.2, 3.5]; // sums to 31 h

  @override
  Widget build(BuildContext context) {
    final c = context.dnd;
    final maxHours = _hours.reduce((a, b) => a > b ? a : b);

    Widget statTile(String label, String value, String sub) => Expanded(
          child: DndCard(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: Space.s16, vertical: 14),
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                OverlineText(label),
                Text(value, style: context.text.titleLarge),
                Text(sub, style: context.text.bodySmall),
              ]),
            ),
          ),
        );

    Widget profileBar(String name, int hours, double fraction) => Padding(
          padding: const EdgeInsets.only(top: Space.s12),
          child: Row(children: [
            Expanded(child: Text(name, style: context.text.bodyMedium)),
            SizedBox(
              width: 150,
              height: 8,
              child: ClipRRect(
                borderRadius: BorderRadius.circular(Radii.pill),
                child: Stack(children: [
                  Positioned.fill(child: ColoredBox(color: c.surfaceAlt)),
                  FractionallySizedBox(widthFactor: fraction, child: ColoredBox(color: c.accent)),
                ]),
              ),
            ),
            SizedBox(
              width: 48,
              child: Text('$hours h', textAlign: TextAlign.right, style: context.text.labelLarge),
            ),
          ]),
        );

    return ListView(
      padding: const EdgeInsets.fromLTRB(Space.s24, Space.s16, Space.s24, Space.s24),
      children: [
        const ScreenHeader(title: 'Insights', subtitle: 'Your quiet time this week'),
        const SizedBox(height: Space.s16),
        ChipRow(
          labels: const ['This week', 'Last week', 'Month'],
          selected: _range,
          onSelected: (i) => setState(() => _range = i),
        ),
        const SizedBox(height: Space.s16),
        DndCard(
          child: Padding(
            padding: const EdgeInsets.all(Space.s16),
            child: Column(children: [
              Row(crossAxisAlignment: CrossAxisAlignment.end, mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
                Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  const OverlineText('Focus time'),
                  Text('31 h', style: context.text.displayLarge),
                ]),
                Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
                  const OverlineText('Blocked'),
                  Text('84', style: context.text.titleLarge),
                ]),
              ]),
              const SizedBox(height: Space.s16),
              Row(crossAxisAlignment: CrossAxisAlignment.end, mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
                for (var i = 0; i < _days.length; i++)
                  Column(mainAxisSize: MainAxisSize.min, children: [
                    Container(
                      width: 28,
                      height: 96 * _hours[i] / maxHours,
                      decoration: BoxDecoration(
                        color: i == 3 ? c.accent : c.accent.withValues(alpha: 0.35),
                        borderRadius: BorderRadius.circular(Radii.input),
                      ),
                    ),
                    const SizedBox(height: Space.s8),
                    Text(_days[i],
                        style: context.text.bodySmall!.copyWith(color: i == 3 ? c.textPrimary : c.textSecondary)),
                  ]),
              ]),
            ]),
          ),
        ),
        const SizedBox(height: Space.s16),
        Row(children: [
          statTile('Top profile', 'Sleep', '18 h this week'),
          const SizedBox(width: Space.s12),
          statTile('Let through', '6 calls', 'VIP and repeat callers'),
        ]),
        const SizedBox(height: Space.s16),
        DndCard(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(Space.s16, Space.s16, Space.s16, Space.s16),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text('By profile', style: context.text.labelLarge),
              profileBar('Sleep', 18, 1),
              profileBar('Work', 9, 0.5),
              profileBar('Meeting', 3, 3 / 18),
              profileBar('Driving', 1, 1 / 18),
            ]),
          ),
        ),
      ],
    );
  }
}
