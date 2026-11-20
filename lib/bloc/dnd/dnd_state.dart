import 'package:equatable/equatable.dart';

import '../../core/models.dart';

sealed class DndState extends Equatable {
  const DndState();

  @override
  List<Object?> get props => [];
}

class DndInitial extends DndState {
  const DndInitial();
}

class DndLoading extends DndState {
  const DndLoading();
}

class DndLoaded extends DndState {
  const DndLoaded({required this.profiles});

  final List<DndProfile> profiles;

  int get activeCount => profiles.where((p) => p.active).length;

  DndProfile? get activeProfile => profiles.where((p) => p.active).firstOrNull;

  @override
  List<Object?> get props => [profiles];
}

class DndError extends DndState {
  const DndError(this.message);

  final String message;

  @override
  List<Object?> get props => [message];
}
