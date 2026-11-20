import 'package:equatable/equatable.dart';

import '../../core/models.dart';

sealed class DndEvent extends Equatable {
  const DndEvent();

  @override
  List<Object?> get props => [];
}

class DndLoadRequested extends DndEvent {
  const DndLoadRequested();
}

class DndToggleProfileRequested extends DndEvent {
  const DndToggleProfileRequested({required this.profileId, required this.active});
  final String profileId;
  final bool active;

  @override
  List<Object?> get props => [profileId, active];
}

class DndSaveProfileRequested extends DndEvent {
  const DndSaveProfileRequested(this.profile);
  final DndProfile profile;

  @override
  List<Object?> get props => [profile];
}

class DndDeleteProfileRequested extends DndEvent {
  const DndDeleteProfileRequested(this.profileId);
  final String profileId;

  @override
  List<Object?> get props => [profileId];
}
