import 'package:equatable/equatable.dart';

abstract class TaskEvent extends Equatable {
  const TaskEvent();

  @override
  List<Object> get props => [];
}

class FetchTasks extends TaskEvent {}

class MoveTask extends TaskEvent {
  final String taskId;
  final String newParentId;
  final int newOrder;

  MoveTask(this.taskId, this.newParentId, this.newOrder);

  @override
  List<Object> get props => [taskId, newParentId, newOrder];
}
