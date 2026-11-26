import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../bloc/dnd/dnd_bloc.dart';
import '../bloc/dnd/dnd_state.dart';
import '../core/api_service.dart';
import '../core/models.dart';
import '../core/tokens.dart';
import 'widgets.dart';

/// Shared bottom sheet for manually logging a DND / focus session & stability rating
/// directly into MongoDB.
Future<bool> showLogSessionSheet(BuildContext context, {String? initialProfileName}) async {
  final dndState = context.read<DndBloc>().state;
  final profiles = switch (dndState) {
    DndLoaded(:final profiles) when profiles.isNotEmpty => profiles,
    _ => sampleProfiles,
  };

  final profileNames = profiles.map((p) => p.name).toList();
  String selectedProfile = initialProfileName != null && initialProfileName.isNotEmpty
      ? initialProfileName
      : (profiles.where((p) => p.active).firstOrNull?.name ?? profileNames.first);
  if (!profileNames.contains(selectedProfile)) {
    profileNames.insert(0, selectedProfile);
  }

  final durationCtrl = TextEditingController(text: '45');
  final silencedCtrl = TextEditingController(text: '5');
  final allowedCtrl = TextEditingController(text: '1');
  final notesCtrl = TextEditingController();
  final customProfileCtrl = TextEditingController();

  int stabilityRating = 4;
  bool completedFull = true;
  bool useCustomProfile = false;
  bool isSaving = false;

  final result = await showModalBottomSheet<bool>(
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
                      Icon(Icons.analytics_outlined, color: c.accent, size: 26),
                      const SizedBox(width: Space.s12),
                      Expanded(
                        child: Text('Log Quiet Session & Stability', style: ctx.text.titleLarge),
                      ),
                    ],
                  ),
                  const SizedBox(height: Space.s16),
                  const OverlineText('Profile'),
                  const SizedBox(height: Space.s8),
                  Wrap(
                    spacing: Space.s8,
                    runSpacing: Space.s8,
                    children: [
                      for (final name in profileNames)
                        ChoiceChip(
                          label: Text(name),
                          selected: !useCustomProfile && selectedProfile == name,
                          onSelected: (_) => setModalState(() {
                            useCustomProfile = false;
                            selectedProfile = name;
                          }),
                        ),
                      ChoiceChip(
                        label: const Text('+ Custom'),
                        selected: useCustomProfile,
                        onSelected: (_) => setModalState(() => useCustomProfile = true),
                      ),
                    ],
                  ),
                  if (useCustomProfile) ...[
                    const SizedBox(height: Space.s12),
                    DndCard(
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: Space.s16, vertical: 4),
                        child: TextField(
                          controller: customProfileCtrl,
                          style: ctx.text.titleMedium,
                          decoration: const InputDecoration(
                            hintText: 'Enter custom profile name',
                            border: InputBorder.none,
                          ),
                        ),
                      ),
                    ),
                  ],
                  const SizedBox(height: Space.s16),
                  Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const OverlineText('Duration (min)'),
                            const SizedBox(height: Space.s8),
                            DndCard(
                              child: Padding(
                                padding: const EdgeInsets.symmetric(horizontal: Space.s16, vertical: 4),
                                child: TextField(
                                  controller: durationCtrl,
                                  keyboardType: TextInputType.number,
                                  style: ctx.text.titleMedium,
                                  decoration: const InputDecoration(border: InputBorder.none),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: Space.s12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const OverlineText('Silenced'),
                            const SizedBox(height: Space.s8),
                            DndCard(
                              child: Padding(
                                padding: const EdgeInsets.symmetric(horizontal: Space.s16, vertical: 4),
                                child: TextField(
                                  controller: silencedCtrl,
                                  keyboardType: TextInputType.number,
                                  style: ctx.text.titleMedium,
                                  decoration: const InputDecoration(border: InputBorder.none),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: Space.s12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const OverlineText('Allowed'),
                            const SizedBox(height: Space.s8),
                            DndCard(
                              child: Padding(
                                padding: const EdgeInsets.symmetric(horizontal: Space.s16, vertical: 4),
                                child: TextField(
                                  controller: allowedCtrl,
                                  keyboardType: TextInputType.number,
                                  style: ctx.text.titleMedium,
                                  decoration: const InputDecoration(border: InputBorder.none),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: Space.s16),
                  const OverlineText('Focus Stability Rating (1 – 5)'),
                  const SizedBox(height: Space.s8),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      for (var r = 1; r <= 5; r++)
                        ChoiceChip(
                          label: Text('$r ★'),
                          selected: stabilityRating == r,
                          onSelected: (_) => setModalState(() => stabilityRating = r),
                        ),
                    ],
                  ),
                  const SizedBox(height: Space.s12),
                  SwitchListTile(
                    contentPadding: EdgeInsets.zero,
                    title: Text('Completed without early exit', style: ctx.text.labelLarge),
                    subtitle: Text(
                      'Did you stay in DND until your planned end?',
                      style: ctx.text.bodySmall,
                    ),
                    value: completedFull,
                    onChanged: (v) => setModalState(() => completedFull = v),
                  ),
                  const SizedBox(height: Space.s8),
                  const OverlineText('Notes (Optional)'),
                  const SizedBox(height: Space.s8),
                  DndCard(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: Space.s16, vertical: 4),
                      child: TextField(
                        controller: notesCtrl,
                        style: ctx.text.bodyLarge,
                        decoration: const InputDecoration(
                          hintText: 'e.g. Deep work block, zero interruptions',
                          border: InputBorder.none,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: Space.s24),
                  if (isSaving)
                    const Center(child: CircularProgressIndicator())
                  else
                    AppButton('Save to Database', onPressed: () async {
                      final prof = useCustomProfile && customProfileCtrl.text.trim().isNotEmpty
                          ? customProfileCtrl.text.trim()
                          : selectedProfile;
                      final mins = int.tryParse(durationCtrl.text.trim()) ?? 30;
                      final sil = int.tryParse(silencedCtrl.text.trim()) ?? 0;
                      final allow = int.tryParse(allowedCtrl.text.trim()) ?? 0;

                      setModalState(() => isSaving = true);
                      final saved = await ApiService.instance.createActivityLog(
                        profileName: prof,
                        durationMinutes: mins < 1 ? 1 : mins,
                        plannedMinutes: mins < 1 ? 1 : mins,
                        completedWithoutEarlyExit: completedFull,
                        silencedCount: sil < 0 ? 0 : sil,
                        letThroughCount: allow < 0 ? 0 : allow,
                        focusStabilityRating: stabilityRating,
                        notes: notesCtrl.text.trim(),
                      );
                      if (modalCtx.mounted) {
                        Navigator.of(modalCtx).pop(saved != null);
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

  durationCtrl.dispose();
  silencedCtrl.dispose();
  allowedCtrl.dispose();
  notesCtrl.dispose();
  customProfileCtrl.dispose();

  return result == true;
}
