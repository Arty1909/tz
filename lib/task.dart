import 'package:equatable/equatable.dart';

class Task extends Equatable {
  final String id;
  final String parentId;
  final String name;
  late final int order;

  Task({required this.id, required this.parentId, required this.name, required this.order});

  factory Task.fromJson(Map<String, dynamic> json) {
    return Task(
      id: json['indicator_to_mo_id'].toString(),
      parentId: json['parent_id'].toString(),
      name: json['name'],
      order: json['order'],
    );
  }

  @override
  List<Object> get props => [id, parentId, name, order];
}
