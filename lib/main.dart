import 'package:equatable/equatable.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';

import 'package:reorderables/reorderables.dart';


void main() {
  runApp(MyApp());
}

class MyApp extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Kanban Board',
      theme: ThemeData(
        primarySwatch: Colors.blue,
      ),
      home: KanbanBoard(),
    );
  }
}


class ApiClient {
  final String baseUrl = 'https://development.kpi-drive.ru/_api';
  final String bearerToken = '48ab34464a5573519725deb5865cc74c';

  Future<List<Task>> fetchTasks() async {
    try {
      final response = await http.post(
        Uri.parse('$baseUrl/indicators/get_mo_indicators'),
        headers: {
          'Authorization': 'Bearer $bearerToken',
          'Content-Type': 'application/x-www-form-urlencoded',
        },
        body: {
          'period_start': '2024-06-01',
          'period_end': '2024-06-30',
          'period_key': 'month',
          'requested_mo_id': '478',
          'behaviour_key': 'task',
          'with_result': 'false',
          'response_fields': 'name,indicator_to_mo_id,parent_id,order',
          'auth_user_id': '2',
        },
      ).timeout(Duration(seconds: 10)); // Добавляем таймаут

      if (response.statusCode == 200) {
        final String decodedBody = utf8.decode(response.bodyBytes);
        final Map<String, dynamic> responseData = json.decode(decodedBody);
        
        if (responseData.containsKey('DATA') && responseData['DATA'] is Map<String, dynamic>) {
          final data = responseData['DATA'] as Map<String, dynamic>;
          if (data.containsKey('rows') && data['rows'] is List) {
            final List<dynamic> rows = data['rows'] as List<dynamic>;
            return rows.map((json) => Task.fromJson(json as Map<String, dynamic>)).toList();
          }
        }
        
        throw Exception('Unexpected data format from server');
      } else {
        throw Exception('Failed to load tasks. Status code: ${response.statusCode}');
      }
    } catch (e) {
      print('Error in fetchTasks: $e');
      throw Exception('Network error: $e');
    }
  }

  Future<void> saveTaskField(String taskId, String fieldName, String fieldValue) async {
    try {
      await http.post(
        Uri.parse('$baseUrl/indicators/save_indicator_instance_field'),
        headers: {
          'Authorization': 'Bearer $bearerToken',
        },
        body: {
          'period_start': '2024-06-01',
          'period_end': '2024-06-30',
          'period_key': 'month',
          'indicator_to_mo_id': taskId,
          'field_name': fieldName,
          'field_value': fieldValue,
          'auth_user_id': '2',
        },
      ).timeout(Duration(seconds: 10)); // Добавляем таймаут
    } catch (e) {
      print('Error in saveTaskField: $e');
      throw Exception('Failed to save task field: $e');
    }
  }
}

class TaskBloc extends Bloc<TaskEvent, TaskState> {
  final ApiClient apiClient;

  TaskBloc(this.apiClient) : super(TaskInitial()) {
    on<FetchTasks>((event, emit) async {
      emit(TaskLoading());
      try {
        final tasks = await apiClient.fetchTasks();
        emit(TaskLoaded(tasks));
      } catch (e) {
        emit(TaskError('Failed to fetch tasks: $e'));
      }
    });

    on<MoveTask>((event, emit) async {
      if (state is TaskLoaded) {
        final currentState = state as TaskLoaded;
        final updatedTasks = List<Task>.from(currentState.tasks);
        final taskIndex = updatedTasks.indexWhere((t) => t.id == event.taskId);
        if (taskIndex != -1) {
          final task = updatedTasks[taskIndex];
          updatedTasks.removeAt(taskIndex);
          final newTask = Task(
            id: task.id,
            parentId: event.newParentId,
            name: task.name,
            order: event.newOrder,
          );
          updatedTasks.insert(taskIndex, newTask);
          emit(TaskLoaded(updatedTasks)); // Обновляем состояние локально
        }
      }

      try {
        await _retryOperation(() => apiClient.saveTaskField(event.taskId, 'parent_id', event.newParentId));
        await _retryOperation(() => apiClient.saveTaskField(event.taskId, 'order', event.newOrder.toString()));
        
        final tasks = await apiClient.fetchTasks();
        emit(TaskLoaded(tasks));
      } catch (e) {
        emit(TaskError('Failed to move task: $e'));
      }
    });
  }

  Future<void> _retryOperation(Future<void> Function() operation, {int maxAttempts = 3}) async {
    for (int attempt = 1; attempt <= maxAttempts; attempt++) {
      try {
        await operation();
        return;
      } catch (e) {
        if (attempt == maxAttempts) rethrow;
        await Future.delayed(Duration(seconds: 1 * attempt));
      }
    }
  }
}

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


abstract class TaskState extends Equatable {
  const TaskState();

  @override
  List<Object> get props => [];
}

class TaskInitial extends TaskState {}

class TaskLoading extends TaskState {}

class TaskLoaded extends TaskState {
  final List<Task> tasks;

  TaskLoaded(this.tasks);

  @override
  List<Object> get props => [tasks];
}

class TaskError extends TaskState {
  final String message;

  TaskError(this.message);

  @override
  List<Object> get props => [message];
}


class Task extends Equatable {
  final String id;
  final String parentId;
  final String name;
  late final int order;

  Task({required this.id, required this.parentId, required this.name, required this.order});

factory Task.fromJson(Map<String, dynamic> json) {
  return Task(
    id: json['indicator_to_mo_id']?.toString() ?? '',
    parentId: json['parent_id']?.toString() ?? '',
    name: json['name']?.toString() ?? '',
    order: json['order'] is int ? json['order'] : int.tryParse(json['order']?.toString() ?? '') ?? 0,
  );
}

  @override
  List<Object> get props => [id, parentId, name, order];
}

class KanbanBoard extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (context) => TaskBloc(ApiClient())..add(FetchTasks()),
      child: Scaffold(
        appBar: AppBar(
          title: Text('Kanban Board'),
          backgroundColor: Colors.blue,
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

              return ListView.builder(
                scrollDirection: Axis.horizontal,
                itemCount: tasksByParent.length,
                itemBuilder: (context, index) {
                  final entry = tasksByParent.entries.elementAt(index);
                  return TaskColumn(
                    parentId: entry.key,
                    tasks: entry.value,
                  );
                },
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

class TaskColumn extends StatelessWidget {
  final String parentId;
  final List<Task> tasks;

  const TaskColumn({Key? key, required this.parentId, required this.tasks}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 300,
      child: Card(
        margin: EdgeInsets.all(8),
        child: Column(
          children: [
            Padding(
              padding: EdgeInsets.all(8),
              child: Text('Folder $parentId', style: TextStyle(fontWeight: FontWeight.bold)),
            ),
            Expanded(
              child: ListView.builder(
                itemCount: tasks.length * 2 + 1,
                itemBuilder: (context, index) {
                  if (index.isEven) {
                    return DragTarget<Task>(
                      builder: (context, candidateData, rejectedData) {
                        return Container(
                          height: 2,
                          color: candidateData.isNotEmpty ? Colors.blue : Colors.transparent,
                        );
                      },
                      onAccept: (Task movedTask) {
                        final newIndex = index ~/ 2;
                        BlocProvider.of<TaskBloc>(context).add(
                          MoveTask(movedTask.id, parentId, newIndex)
                        );
                      },
                    );
                  } else {
                    final taskIndex = index ~/ 2;
                    return TaskItem(task: tasks[taskIndex]);
                  }
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class TaskItem extends StatelessWidget {
  final Task task;

  const TaskItem({Key? key, required this.task}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Draggable<Task>(
      data: task,
      child: buildTaskCard(),
      feedback: Material(
        elevation: 4.0,
        child: Container(
          width: 280,
          child: buildTaskCard(),
        ),
      ),
      childWhenDragging: Opacity(
        opacity: 0.5,
        child: buildTaskCard(),
      ),
    );
  }

  Widget buildTaskCard() {
    return Card(
      key: ValueKey(task.id),
      child: ListTile(
        title: Text(task.name),
        subtitle: Text('Order: ${task.order}'),
      ),
    );
  }
}