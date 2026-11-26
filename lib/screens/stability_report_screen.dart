import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../bloc/auth/auth_bloc.dart';
import '../core/api_service.dart';
import '../core/models.dart';
import '../core/tokens.dart';
import '../widgets/log_session_sheet.dart';
import '../widgets/widgets.dart';

/// Data Analysis Report Screen: evaluates the user's overall stability over the time
/// they use the app (session adherence, consistency streak, distraction shield,
/// focus stability rating, and time-series trend).
class StabilityReportScreen extends StatefulWidget {
  const StabilityReportScreen({super.key});

  @override
  State<StabilityReportScreen> createState() => _StabilityReportScreenState();
}

class _StabilityReportScreenState extends State<StabilityReportScreen> {
  int _range = 0; // 0=7d, 1=30d, 2=90d, 3=All time
  bool _isLoading = true;
  int? _selectedPointIndex;
  StabilityReportData _report = StabilityReportData.empty();

  static const List<String> _rangeLabels = ['7 Days', '30 Days', '90 Days', 'All Time'];

  @override
  void initState() {
    super.initState();
    _fetchReport(0);
  }

  Future<void> _fetchReport(int range) async {
    setState(() => _isLoading = true);
    try {
      final fetched = await ApiService.instance.getStabilityReport(range: range);
      if (mounted) {
        setState(() {
          _report = fetched;
          _isLoading = false;
          _selectedPointIndex = fetched.trend.isNotEmpty ? fetched.trend.length - 1 : null;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _onRangeChanged(int index) {
    if (_range == index) return;
    setState(() => _range = index);
    _fetchReport(index);
  }

  Future<void> _handleLogSession() async {
    final saved = await showLogSessionSheet(context);
    if (saved && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Session saved & stability report updated')),
      );
      _fetchReport(_range);
    }
  }

  Future<void> _deleteLog(DndActivityLog log) async {
    final ok = await ApiService.instance.deleteActivityLog(log.id);
    if (ok && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Log entry removed')),
      );
      _fetchReport(_range);
    }
  }

  String _formatMinutes(int totalMinutes) {
    if (totalMinutes <= 0) return '0m';
    final hrs = totalMinutes ~/ 60;
    final mins = totalMinutes % 60;
    if (hrs > 0 && mins > 0) return '${hrs}h ${mins}m';
    if (hrs > 0) return '${hrs}h';
    return '${mins}m';
  }

  @override
  Widget build(BuildContext context) {
    final c = context.dnd;
    final user = context.watch<AuthBloc>().currentUser;
    final summary = _report.summary;
    final pillars = _report.pillars;
    final appUsageMinutes = math.max(
      summary.totalAppUsageMinutes,
      user?.totalAppUsageMinutes ?? 0,
    );

    final scoreColor = !_report.hasData
        ? c.textSecondary
        : _report.overallStabilityScore >= 75
            ? c.armed
            : (_report.overallStabilityScore >= 50 ? c.accent : c.warning);

    return RefreshIndicator(
      onRefresh: () => _fetchReport(_range),
      child: ListView(
        padding: const EdgeInsets.fromLTRB(Space.s24, Space.s16, Space.s24, Space.s32),
        children: [
          ScreenHeader(
            title: 'Stability Report',
            subtitle: 'Data analysis of your focus stability over time',
            onAdd: _handleLogSession,
          ),
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

          // Hero Overall Stability Score Card
          DndCard(
            child: Padding(
              padding: const EdgeInsets.all(Space.s24),
              child: Column(
                children: [
                  Row(
                    children: [
                      SizedBox(
                        width: 112,
                        height: 112,
                        child: CustomPaint(
                          painter: _StabilityGaugePainter(
                            score: _report.overallStabilityScore,
                            trackColor: c.surfaceAlt,
                            progressColor: scoreColor,
                          ),
                          child: Center(
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Text(
                                  '${_report.overallStabilityScore}%',
                                  style: context.text.titleLarge!.copyWith(
                                    color: scoreColor,
                                    fontWeight: FontWeight.w800,
                                  ),
                                ),
                                Text('STABILITY', style: context.text.labelSmall),
                              ],
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: Space.s24),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                              decoration: BoxDecoration(
                                color: scoreColor.withValues(alpha: 0.14),
                                borderRadius: BorderRadius.circular(Radii.pill),
                              ),
                              child: Text(
                                _report.stabilityGrade,
                                style: context.text.labelLarge!.copyWith(color: scoreColor),
                              ),
                            ),
                            const SizedBox(height: Space.s8),
                            Text(
                              _report.hasData
                                  ? '${summary.completedSessions}/${summary.totalSessions} sessions completed'
                                  : 'No DND sessions logged yet',
                              style: context.text.titleMedium,
                            ),
                            const SizedBox(height: Space.s4),
                            Text(
                              _report.stabilityDelta == 0
                                  ? 'App usage tracked: ${_formatMinutes(appUsageMinutes)}'
                                  : '${_report.stabilityDelta > 0 ? '+' : ''}${_report.stabilityDelta}% vs previous period • ${_formatMinutes(appUsageMinutes)} in app',
                              style: context.text.bodySmall,
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  if (!_report.hasData) ...[
                    const SizedBox(height: Space.s16),
                    AppButton(
                      'Log First Focus Session',
                      type: AppButtonType.secondary,
                      onPressed: _handleLogSession,
                    ),
                  ],
                ],
              ),
            ),
          ),

          const SizedBox(height: Space.s16),

          // Stability Trend Over Time Chart
          DndCard(
            child: Padding(
              padding: const EdgeInsets.all(Space.s16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const OverlineText('Stability Trajectory'),
                          const SizedBox(height: 2),
                          Text('Stability % & Quiet Hours over time', style: context.text.labelLarge),
                        ],
                      ),
                      Text(
                        _rangeLabels[_range],
                        style: context.text.bodySmall!.copyWith(color: c.accent),
                      ),
                    ],
                  ),
                  const SizedBox(height: Space.s16),
                  if (_report.trend.isEmpty)
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: Space.s24),
                      child: Center(
                        child: Text(
                          'Start using Master DND or log a session to plot your stability curve.',
                          style: context.text.bodySmall,
                          textAlign: TextAlign.center,
                        ),
                      ),
                    )
                  else ...[
                    SizedBox(
                      height: 160,
                      width: double.infinity,
                      child: LayoutBuilder(
                        builder: (context, constraints) {
                          return GestureDetector(
                            onTapDown: (details) {
                              final count = _report.trend.length;
                              if (count == 0) return;
                              final idx = ((details.localPosition.dx / constraints.maxWidth) * count)
                                  .floor()
                                  .clamp(0, count - 1);
                              setState(() => _selectedPointIndex = idx);
                            },
                            child: CustomPaint(
                              painter: _StabilityTrendPainter(
                                points: _report.trend,
                                selectedIndex: _selectedPointIndex,
                                lineColor: c.accent,
                                barColor: c.armed.withValues(alpha: 0.28),
                                gridColor: c.border,
                                textColor: c.textSecondary,
                              ),
                            ),
                          );
                        },
                      ),
                    ),
                    const SizedBox(height: Space.s8),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        for (var i = 0; i < _report.trend.length; i++)
                          GestureDetector(
                            onTap: () => setState(() => _selectedPointIndex = i),
                            child: Text(
                              _report.trend[i].label,
                              style: context.text.bodySmall!.copyWith(
                                fontWeight: _selectedPointIndex == i ? FontWeight.bold : FontWeight.normal,
                                color: _selectedPointIndex == i ? c.accent : c.textSecondary,
                              ),
                            ),
                          ),
                      ],
                    ),
                    if (_selectedPointIndex != null &&
                        _selectedPointIndex! < _report.trend.length) ...[
                      const SizedBox(height: Space.s12),
                      _SelectedBucketDetail(point: _report.trend[_selectedPointIndex!]),
                    ],
                  ],
                ],
              ),
            ),
          ),

          const SizedBox(height: Space.s16),

          // 4 Stability Pillars
          DndCard(
            child: Padding(
              padding: const EdgeInsets.all(Space.s16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const OverlineText('Stability Pillars'),
                  const SizedBox(height: Space.s4),
                  Text('How your overall score is calculated', style: context.text.labelLarge),
                  const SizedBox(height: Space.s12),
                  _pillarRow(context, 'Session Adherence (35%)', pillars.adherenceScore, c.accent),
                  _pillarRow(context, 'Daily Consistency (25%)', pillars.consistencyScore, c.armed),
                  _pillarRow(context, 'Focus Check-in Rating (25%)', pillars.focusRatingScore, c.accent),
                  _pillarRow(context, 'Distraction Shield (15%)', pillars.shieldScore, c.warning),
                ],
              ),
            ),
          ),

          const SizedBox(height: Space.s16),

          // Usage & Streak Metrics Grid
          Row(
            children: [
              _metricCard(
                context,
                label: 'App Usage',
                value: _formatMinutes(appUsageMinutes),
                sub: '${summary.activeDaysCount} active days',
              ),
              const SizedBox(width: Space.s12),
              _metricCard(
                context,
                label: 'Quiet Time',
                value: _formatMinutes(summary.totalQuietMinutes),
                sub: 'Avg ${summary.avgSessionMinutes}m / session',
              ),
            ],
          ),
          const SizedBox(height: Space.s12),
          Row(
            children: [
              _metricCard(
                context,
                label: 'Streak',
                value: '${summary.currentStreakDays}d',
                sub: 'Best: ${summary.longestStreakDays} days',
              ),
              const SizedBox(width: Space.s12),
              _metricCard(
                context,
                label: 'Interruptions',
                value: '${summary.totalSilenced}',
                sub: '${summary.totalLetThrough} VIP let through',
              ),
            ],
          ),

          const SizedBox(height: Space.s16),

          // Profile Stability Breakdown
          if (_report.profileStability.isNotEmpty) ...[
            DndCard(
              child: Padding(
                padding: const EdgeInsets.all(Space.s16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const OverlineText('Profile Stability'),
                    const SizedBox(height: Space.s4),
                    Text('Performance by DND mode', style: context.text.labelLarge),
                    const SizedBox(height: Space.s12),
                    for (final p in _report.profileStability)
                      Padding(
                        padding: const EdgeInsets.only(bottom: Space.s12),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Text(p.name, style: context.text.labelLarge),
                                Text(
                                  '${p.avgStabilityScore}% stability • ${p.totalHours}h (${p.sessions})',
                                  style: context.text.bodySmall,
                                ),
                              ],
                            ),
                            const SizedBox(height: 6),
                            ClipRRect(
                              borderRadius: BorderRadius.circular(Radii.pill),
                              child: LinearProgressIndicator(
                                value: (p.avgStabilityScore / 100).clamp(0.04, 1.0),
                                minHeight: 8,
                                backgroundColor: c.surfaceAlt,
                                color: p.avgStabilityScore >= 75 ? c.armed : c.accent,
                              ),
                            ),
                          ],
                        ),
                      ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: Space.s16),
          ],

          // Recommendations
          if (_report.recommendations.isNotEmpty) ...[
            const OverlineText('Analysis & Insights'),
            const SizedBox(height: Space.s8),
            for (final rec in _report.recommendations) ...[
              DndCard(
                child: Padding(
                  padding: const EdgeInsets.all(Space.s16),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Icon(
                        rec.tone == 'positive'
                            ? Icons.trending_up
                            : (rec.tone == 'warning'
                                ? Icons.warning_amber_rounded
                                : Icons.lightbulb_outline),
                        color: rec.tone == 'positive'
                            ? c.armed
                            : (rec.tone == 'warning' ? c.warning : c.accent),
                        size: 22,
                      ),
                      const SizedBox(width: Space.s12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(rec.title, style: context.text.labelLarge),
                            const SizedBox(height: 2),
                            Text(rec.detail, style: context.text.bodySmall),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: Space.s8),
            ],
            const SizedBox(height: Space.s8),
          ],

          // Recent Logged Sessions & Manual Check-ins
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const OverlineText('Session & Check-in History'),
              TextButton.icon(
                icon: Icon(Icons.add, size: 16, color: c.accent),
                label: Text('Log entry', style: context.text.labelLarge?.copyWith(color: c.accent)),
                onPressed: _handleLogSession,
              ),
            ],
          ),
          const SizedBox(height: Space.s8),
          if (_report.recentLogs.isEmpty)
            DndCard(
              child: Padding(
                padding: const EdgeInsets.all(Space.s24),
                child: Column(
                  children: [
                    Icon(Icons.history, size: 32, color: c.textSecondary),
                    const SizedBox(height: Space.s8),
                    Text('No session history yet', style: context.text.titleMedium),
                    const SizedBox(height: Space.s4),
                    Text(
                      'Toggle Master DND on/off or tap Log entry to record sessions in the database.',
                      textAlign: TextAlign.center,
                      style: context.text.bodySmall,
                    ),
                  ],
                ),
              ),
            )
          else
            DndGroup(
              children: [
                for (final log in _report.recentLogs)
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: Space.s16, vertical: Space.s12),
                    child: Row(
                      children: [
                        IconTile(
                          icon: log.completedWithoutEarlyExit
                              ? Icons.check_circle_outline
                              : Icons.timelapse,
                          size: 40,
                          iconSize: 20,
                          filled: log.completedWithoutEarlyExit,
                        ),
                        const SizedBox(width: Space.s12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                '${log.profileName} • ${log.durationMinutes}m',
                                style: context.text.labelLarge,
                              ),
                              Text(
                                '${log.date.month}/${log.date.day} • ${log.silencedCount} silenced • ${log.focusStabilityRating}/5 ★${log.notes.isNotEmpty ? ' • ${log.notes}' : ''}',
                                style: context.text.bodySmall,
                              ),
                            ],
                          ),
                        ),
                        IconButton(
                          icon: Icon(Icons.delete_outline, size: 18, color: c.textSecondary),
                          tooltip: 'Delete entry',
                          onPressed: () => _deleteLog(log),
                        ),
                      ],
                    ),
                  ),
              ],
            ),
        ],
      ),
    );
  }

  Widget _metricCard(
    BuildContext context, {
    required String label,
    required String value,
    required String sub,
  }) {
    return Expanded(
      child: DndCard(
        child: Padding(
          padding: const EdgeInsets.all(Space.s16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              OverlineText(label),
              const SizedBox(height: 4),
              Text(value, style: context.text.titleLarge),
              Text(sub, style: context.text.bodySmall),
            ],
          ),
        ),
      ),
    );
  }

  Widget _pillarRow(BuildContext context, String label, int score, Color color) {
    final c = context.dnd;
    return Padding(
      padding: const EdgeInsets.only(bottom: Space.s12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(label, style: context.text.bodyMedium),
              Text('$score%', style: context.text.labelLarge!.copyWith(color: color)),
            ],
          ),
          const SizedBox(height: 6),
          ClipRRect(
            borderRadius: BorderRadius.circular(Radii.pill),
            child: LinearProgressIndicator(
              value: (score / 100).clamp(0.03, 1.0),
              minHeight: 8,
              backgroundColor: c.surfaceAlt,
              color: color,
            ),
          ),
        ],
      ),
    );
  }
}

class _SelectedBucketDetail extends StatelessWidget {
  const _SelectedBucketDetail({required this.point});
  final StabilityTrendPoint point;

  @override
  Widget build(BuildContext context) {
    final c = context.dnd;
    return Container(
      padding: const EdgeInsets.all(Space.s12),
      decoration: BoxDecoration(
        color: c.surfaceAlt,
        borderRadius: BorderRadius.circular(Radii.input),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            '${point.label}: ${point.stabilityScore}% stability',
            style: context.text.labelLarge!.copyWith(color: c.accent),
          ),
          Text(
            '${point.quietHours}h quiet • ${point.appUsageMinutes}m app • ${point.sessions} sess',
            style: context.text.bodySmall,
          ),
        ],
      ),
    );
  }
}

class _StabilityGaugePainter extends CustomPainter {
  _StabilityGaugePainter({
    required this.score,
    required this.trackColor,
    required this.progressColor,
  });

  final int score;
  final Color trackColor;
  final Color progressColor;

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = (math.min(size.width, size.height) / 2) - 8;
    const stroke = 10.0;

    final trackPaint = Paint()
      ..color = trackColor
      ..style = PaintingStyle.stroke
      ..strokeWidth = stroke
      ..strokeCap = StrokeCap.round;

    final progressPaint = Paint()
      ..color = progressColor
      ..style = PaintingStyle.stroke
      ..strokeWidth = stroke
      ..strokeCap = StrokeCap.round;

    canvas.drawCircle(center, radius, trackPaint);
    final sweep = 2 * math.pi * (score.clamp(0, 100) / 100.0);
    if (sweep > 0) {
      canvas.drawArc(
        Rect.fromCircle(center: center, radius: radius),
        -math.pi / 2,
        sweep,
        false,
        progressPaint,
      );
    }
  }

  @override
  bool shouldRepaint(covariant _StabilityGaugePainter oldDelegate) =>
      oldDelegate.score != score ||
      oldDelegate.progressColor != progressColor ||
      oldDelegate.trackColor != trackColor;
}

class _StabilityTrendPainter extends CustomPainter {
  _StabilityTrendPainter({
    required this.points,
    required this.selectedIndex,
    required this.lineColor,
    required this.barColor,
    required this.gridColor,
    required this.textColor,
  });

  final List<StabilityTrendPoint> points;
  final int? selectedIndex;
  final Color lineColor;
  final Color barColor;
  final Color gridColor;
  final Color textColor;

  @override
  void paint(Canvas canvas, Size size) {
    if (points.isEmpty) return;
    final gridPaint = Paint()
      ..color = gridColor
      ..strokeWidth = 1;

    for (final frac in [0.25, 0.5, 0.75, 1.0]) {
      final y = size.height * (1 - frac);
      canvas.drawLine(Offset(0, y), Offset(size.width, y), gridPaint);
    }

    final maxQuiet = points.fold<double>(1.0, (m, p) => p.quietHours > m ? p.quietHours : m);
    final n = points.length;
    final stepX = n > 1 ? size.width / (n - 1) : size.width / 2;
    final barPaint = Paint()..color = barColor;

    // Quiet hours background bars
    for (var i = 0; i < n; i++) {
      final cx = n > 1 ? i * stepX : size.width / 2;
      final barH = (points[i].quietHours / maxQuiet) * (size.height * 0.75);
      final rect = RRect.fromRectAndRadius(
        Rect.fromLTWH(cx - 10, size.height - barH, 20, barH),
        const Radius.circular(6),
      );
      canvas.drawRRect(rect, barPaint);
    }

    // Stability line & area
    final path = Path();
    final fillPath = Path();
    final coords = <Offset>[];

    for (var i = 0; i < n; i++) {
      final x = n > 1 ? i * stepX : size.width / 2;
      final y = size.height - ((points[i].stabilityScore.clamp(0, 100) / 100.0) * (size.height - 16)) - 8;
      coords.add(Offset(x, y));
      if (i == 0) {
        path.moveTo(x, y);
        fillPath.moveTo(x, size.height);
        fillPath.lineTo(x, y);
      } else {
        path.lineTo(x, y);
        fillPath.lineTo(x, y);
      }
    }

    if (coords.isNotEmpty) {
      fillPath.lineTo(coords.last.dx, size.height);
      fillPath.close();
      canvas.drawPath(
        fillPath,
        Paint()..color = lineColor.withValues(alpha: 0.12),
      );
    }

    canvas.drawPath(
      path,
      Paint()
        ..color = lineColor
        ..style = PaintingStyle.stroke
        ..strokeWidth = 3
        ..strokeCap = StrokeCap.round
        ..strokeJoin = StrokeJoin.round,
    );

    for (var i = 0; i < coords.length; i++) {
      final isSelected = i == selectedIndex;
      canvas.drawCircle(
        coords[i],
        isSelected ? 6 : 4,
        Paint()..color = isSelected ? lineColor : Colors.white,
      );
      canvas.drawCircle(
        coords[i],
        isSelected ? 6 : 4,
        Paint()
          ..color = lineColor
          ..style = PaintingStyle.stroke
          ..strokeWidth = 2.5,
      );
    }
  }

  @override
  bool shouldRepaint(covariant _StabilityTrendPainter oldDelegate) =>
      oldDelegate.points != points || oldDelegate.selectedIndex != selectedIndex;
}
