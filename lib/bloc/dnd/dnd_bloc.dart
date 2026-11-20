import 'package:flutter_bloc/flutter_bloc.dart';

import '../../core/api_service.dart';
import 'dnd_event.dart';
import 'dnd_state.dart';

class DndBloc extends Bloc<DndEvent, DndState> {
  DndBloc({ApiService? apiService})
      : _api = apiService ?? ApiService.instance,
        super(const DndInitial()) {
    on<DndLoadRequested>(_onLoadRequested);
    on<DndToggleProfileRequested>(_onToggleProfileRequested);
    on<DndSaveProfileRequested>(_onSaveProfileRequested);
  }

  final ApiService _api;

  Future<void> _onLoadRequested(
    DndLoadRequested event,
    Emitter<DndState> emit,
  ) async {
    emit(const DndLoading());
    try {
      final list = await _api.getProfiles();
      emit(DndLoaded(profiles: list));
    } catch (e) {
      emit(DndError(e.toString().replaceAll('Exception: ', '')));
    }
  }

  Future<void> _onToggleProfileRequested(
    DndToggleProfileRequested event,
    Emitter<DndState> emit,
  ) async {
    if (state is! DndLoaded) return;
    final currentList = (state as DndLoaded).profiles;

    final updatedList = [
      for (final p in currentList)
        p.copyWith(
          active: p.id == event.profileId
              ? event.active
              : (event.active ? false : p.active),
        ),
    ];

    emit(DndLoaded(profiles: updatedList));

    final targetProfile = updatedList.where((p) => p.id == event.profileId).firstOrNull;
    if (targetProfile != null) {
      await _api.updateDndProfile(targetProfile);
    }
  }

  Future<void> _onSaveProfileRequested(
    DndSaveProfileRequested event,
    Emitter<DndState> emit,
  ) async {
    await _api.updateDndProfile(event.profile);
    add(const DndLoadRequested());
  }
}
