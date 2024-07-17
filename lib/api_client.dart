import 'package:http/http.dart' as http;
import 'dart:convert';
import 'task.dart';

class ApiClient {
  final String baseUrl = 'https://development.kpi-drive.ru/_api';
  final String bearerToken = '48ab34464a5573519725deb5865cc74c';

  Future<List<Task>> fetchTasks() async {
    final response = await http.post(
      Uri.parse('$baseUrl/indicators/get_mo_indicators'),
      headers: {
        'Authorization': 'Bearer $bearerToken',
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
    );

    if (response.statusCode == 200) {
      List<dynamic> data = json.decode(response.body);
      return data.map((json) => Task.fromJson(json)).toList();
    } else {
      throw Exception('Failed to load tasks');
    }
  }

  Future<void> saveTaskField(String taskId, String fieldName, String fieldValue) async {
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
    );
  }
}
