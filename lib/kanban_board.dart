import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:reorderables/reorderables.dart';
import 'package:tz/api_client.dart';
import 'task_bloc.dart';
import 'task_event.dart';
import 'task_state.dart';
import 'task.dart';

class KanbanBoard extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (context) => TaskBloc(ApiClient())..add(FetchTasks()),
      child: Scaffold(
        appBar: AppBar(
          title: Text('Kanban Board'),
        ),
        body: BlocBuilder<TaskBloc, TaskState>(
          builder: (context, state) {
            if (state is TaskLoading) {
             // return Center(child: CircularProgressIndicator());
            } else if (state is TaskLoaded) {
              final tasksByParent = <String, List<Task>>{};
              for (var task in state.tasks) {
                tasksByParent.putIfAbsent(task.parentId, () => []).add(task);
              }

              return ReorderableColumn(
                onReorder: (oldIndex, newIndex) {
                  // Здесь нужно будет реализовать логику перемещения задач между списками
                },
                children: tasksByParent.entries.map((entry) {
                  return ReorderableColumn(
                    key: ValueKey(entry.key),
                    header: Text('Folder ${entry.key}'),
                    onReorder: (oldIndex, newIndex) {
                      final movedTask = entry.value[oldIndex];
                      movedTask.order = newIndex;
                      BlocProvider.of<TaskBloc>(context).add(
                        MoveTask(movedTask.id, movedTask.parentId, movedTask.order)
                      );
                    },
                    children: entry.value.map((task) {
                      return ListTile(
                        key: ValueKey(task.id),
                        title: Text(task.name),
                        trailing: Text(task.order.toString()),
                      );
                    }).toList(),
                  );
                }).toList(),
              );
            } else if (state is TaskError) {
              return Center(child: Text(state.message));
            }
            return Container();
          },
        ),
      ),
    );
  }
}