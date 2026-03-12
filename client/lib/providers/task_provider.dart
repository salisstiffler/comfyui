import 'dart:async';
import 'package:flutter/material.dart';
import '../models/task_model.dart';
import '../services/api_service.dart';

class TaskProvider extends ChangeNotifier {
  List<AiTask> tasks = [];
  Timer? _timer;
  bool isLoading = true;

  TaskProvider() {
    startPolling();
  }

  void startPolling() {
    refresh();
    _timer = Timer.periodic(const Duration(seconds: 4), (_) => refresh());
  }

  Future<void> refresh() async {
    try {
      final list = await ApiService.getJobs();
      tasks = list;
      isLoading = false;
      notifyListeners();
    } catch (e) {
      print("Error refreshing tasks: $e");
    }
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }
}
