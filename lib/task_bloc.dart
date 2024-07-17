import 'package:flutter_bloc/flutter_bloc.dart';
import 'task_event.dart';
import 'task_state.dart';
import 'api_client.dart';

class TaskBloc extends Bloc<TaskEvent, TaskState> {
  final ApiClient apiClient;

  TaskBloc(this.apiClient) : super(TaskInitial());

  @override
  Stream<TaskState> mapEventToState(TaskEvent event) async* {
    if (event is FetchTasks) {
      yield TaskLoading();
      try {
        final tasks = await apiClient.fetchTasks();
        yield TaskLoaded(tasks);
      } catch (e) {
        yield TaskError('Failed to fetch tasks');
      }
    } else if (event is MoveTask) {
      try {
        await apiClient.saveTaskField(event.taskId, 'parent_id', event.newParentId);
        await apiClient.saveTaskField(event.taskId, 'order', event.newOrder.toString());
        final tasks = await apiClient.fetchTasks();
        yield TaskLoaded(tasks);
      } catch (e) {
        yield TaskError('Failed to move task');
      }
    }
  }
}
