import 'package:flutter/material.dart';

import '../core/api_service.dart';
import '../core/models.dart';
import '../core/tokens.dart';
import '../widgets/widgets.dart';

/// Figma: "7 Insights". Data comes from GET /api/dnd/insights?range=...
class InsightsScreen extends StatefulWidget {
  const InsightsScreen({super.key});

  @override
  State<InsightsScreen> createState() => _InsightsScreenState();
}

class _InsightsScreenState extends State<InsightsScreen> {
  int _range = 0;
  bool _isLoading = true;
  InsightsData _data = InsightsData.defaults();

  static const List<String> _rangeLabels = ['This week', 'Last week', 'Month'];

  @override
  void initState() {
    super.initState();
    _fetchInsights(0);
  }

  Future<void> _fetchInsights(int range) async {
    setState(() => _isLoading = true);
    try {
      final fetched = await ApiService.instance.getInsights(range: range);
      if (mounted) {
        setState(() {
          _data = fetched;
          _isLoading = false;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _onRangeChanged(int index) {
    if (_range == index) return;
    setState(() => _range = index);
    _fetchInsights(index);
  }

  @override
  Widget build(BuildContext context) {
    final c = context.dnd;
    final breakdown = _data.breakdown.isNotEmpty
        ? _data.breakdown
        : const [
            DailyBreakdown(day: 'Mon', silenced: 14, allowed: 1, hours: 4.5),
            DailyBreakdown(day: 'Tue', silenced: 11, allowed: 3, hours: 5.0),
            DailyBreakdown(day: 'Wed', silenced: 15, allowed: 0, hours: 3.8),
            DailyBreakdown(day: 'Thu', silenced: 12, allowed: 2, hours: 5.6),
            DailyBreakdown(day: 'Fri', silenced: 9, allowed: 4, hours: 4.4),
            DailyBreakdown(day: 'Sat', silenced: 16, allowed: 1, hours: 4.2),
            DailyBreakdown(day: 'Sun', silenced: 12, allowed: 2, hours: 3.5),
          ];

    final maxHours = breakdown.fold<double>(1.0, (m, b) => b.hours > m ? b.hours : m);

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
                  FractionallySizedBox(
                    widthFactor: fraction.clamp(0.05, 1.0),
                    child: ColoredBox(color: c.accent),
                  ),
                ]),
              ),
            ),
            SizedBox(
              width: 48,
              child: Text('$hours h', textAlign: TextAlign.right, style: context.text.labelLarge),
            ),
          ]),
        );

    final rangeSubtitle = switch (_range) {
      1 => 'Your quiet time last week',
      2 => 'Your quiet time this month',
      _ => 'Your quiet time this week',
    };

    final topProfile = _data.profiles.isNotEmpty
        ? _data.profiles.first
        : const ProfileStat(name: 'Sleep', hours: 18, fraction: 1.0);

    final letThroughCount = _data.stats.letThroughTonight;

    return RefreshIndicator(
      onRefresh: () => _fetchInsights(_range),
      child: ListView(
        padding: const EdgeInsets.fromLTRB(Space.s24, Space.s16, Space.s24, Space.s24),
        children: [
          ScreenHeader(title: 'Insights', subtitle: rangeSubtitle),
          const SizedBox(height: Space.s16),
          ChipRow(
            labels: _rangeLabels,
            selected: _range,
            onSelected: _onRangeChanged,
          ),
          if (_isLoading)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: Space.s8),
              child: LinearProgressIndicator(minHeight: 2),
            )
          else
            const SizedBox(height: Space.s16),
          DndCard(
            child: Padding(
              padding: const EdgeInsets.all(Space.s16),
              child: Column(children: [
                Row(crossAxisAlignment: CrossAxisAlignment.end, mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
                  Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    const OverlineText('Focus time'),
                    Text('${_data.stats.focusHours} h', style: context.text.displayLarge),
                  ]),
                  Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
                    const OverlineText('Blocked'),
                    Text('${_data.stats.blockedTotal}', style: context.text.titleLarge),
                  ]),
                ]),
                const SizedBox(height: Space.s16),
                Row(crossAxisAlignment: CrossAxisAlignment.end, mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
                  for (var i = 0; i < breakdown.length; i++)
                    Column(mainAxisSize: MainAxisSize.min, children: [
                      Container(
                        width: breakdown.length > 5 ? 28 : 50,
                        height: (96 * (breakdown[i].hours / maxHours)).clamp(12.0, 96.0),
                        decoration: BoxDecoration(
                          color: i == breakdown.length - 2
                              ? c.accent
                              : c.accent.withValues(alpha: 0.35),
                          borderRadius: BorderRadius.circular(Radii.input),
                        ),
                      ),
                      const SizedBox(height: Space.s8),
                      Text(
                        breakdown[i].day,
                        style: context.text.bodySmall!.copyWith(
                          color: i == breakdown.length - 2 ? c.textPrimary : c.textSecondary,
                        ),
                      ),
                    ]),
                ]),
              ]),
            ),
          ),
          const SizedBox(height: Space.s16),
          Row(children: [
            statTile(
              'Top profile',
              topProfile.name,
              '${topProfile.hours} h ${_range == 2 ? 'this month' : 'this week'}',
            ),
            const SizedBox(width: Space.s12),
            statTile(
              'Let through',
              '$letThroughCount calls',
              'VIP and repeat callers',
            ),
          ]),
          const SizedBox(height: Space.s16),
          DndCard(
            child: Padding(
              padding: const EdgeInsets.all(Space.s16),
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text('By profile', style: context.text.labelLarge),
                for (final prof in _data.profiles)
                  profileBar(prof.name, prof.hours, prof.fraction),
              ]),
            ),
          ),
        ],
      ),
    );
  }
}
