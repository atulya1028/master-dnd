import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../bloc/dnd/dnd_bloc.dart';
import '../bloc/dnd/dnd_event.dart';
import '../bloc/dnd/dnd_state.dart';
import '../core/models.dart';
import '../core/tokens.dart';
import '../widgets/widgets.dart';
import 'profile_editor_screen.dart';

/// Figma: "4 Profiles" powered by DndBloc.
class ProfilesScreen extends StatefulWidget {
  const ProfilesScreen({super.key});

  @override
  State<ProfilesScreen> createState() => _ProfilesScreenState();
}

class _ProfilesScreenState extends State<ProfilesScreen> {
  @override
  void initState() {
    super.initState();
    context.read<DndBloc>().add(const DndLoadRequested());
  }

  void _open([DndProfile? profile]) {
    Navigator.of(context).push(
      MaterialPageRoute<void>(builder: (_) => ProfileEditorScreen(profile: profile)),
    );
  }

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<DndBloc, DndState>(
      builder: (context, state) {
        final profiles = switch (state) {
          DndLoaded(:final profiles) => profiles,
          _ => sampleProfiles,
        };
        final activeCount = switch (state) {
          DndLoaded(:final activeCount) => activeCount,
          _ => profiles.where((p) => p.active).length,
        };
        final isLoading = state is DndLoading;

        return RefreshIndicator(
          onRefresh: () async {
            context.read<DndBloc>().add(const DndLoadRequested());
          },
          child: ListView(
            padding: const EdgeInsets.fromLTRB(Space.s24, Space.s16, Space.s24, Space.s24),
            children: [
              ScreenHeader(
                title: 'Profiles',
                subtitle: '${profiles.length} profiles, $activeCount active',
                onAdd: () => _open(),
              ),
              const SizedBox(height: Space.s24),
              if (isLoading && profiles.isEmpty)
                const Center(
                  child: Padding(
                    padding: EdgeInsets.all(Space.s32),
                    child: CircularProgressIndicator(),
                  ),
                )
              else
                for (var i = 0; i < profiles.length; i++) ...[
                  ProfileCard(
                    profile: profiles[i],
                    onTap: () => _open(profiles[i]),
                    onChanged: (v) {
                      context.read<DndBloc>().add(
                            DndToggleProfileRequested(
                              profileId: profiles[i].id,
                              active: v,
                            ),
                          );
                    },
                  ),
                  const SizedBox(height: Space.s12),
                ],
              const SizedBox(height: Space.s12),
              AppButton('Create a profile', type: AppButtonType.secondary, onPressed: () => _open()),
            ],
          ),
        );
      },
    );
  }
}
