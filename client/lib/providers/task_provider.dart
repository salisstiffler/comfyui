import 'dart:async';
import 'package:flutter/material.dart';
import '../models/task_model.dart';
import '../services/api_service.dart';
import '../services/storage_service.dart';

class TaskProvider extends ChangeNotifier {
  List<AiTask> tasks = [];
  Timer? _timer;
  bool isLoading = true;

  TaskProvider() {
    _loadCache().then((_) => startPolling());
  }

  Future<void> _loadCache() async {
    try {
      final cached = await StorageService.getTasks();
      if (cached.isNotEmpty) {
        tasks = cached;
        isLoading = false;
        notifyListeners();
      }
    } catch (e) {
      print("Error loading cache: $e");
    }
  }

  void startPolling() {
    refresh();
    _timer = Timer.periodic(const Duration(seconds: 4), (_) => refresh());
  }

  Future<void> refresh() async {
    try {
      final list = await ApiService.getJobs();
      if (list.isNotEmpty) {
        tasks = list;
        // 异步存入缓存，不阻塞 UI
        StorageService.saveTasks(list);
      }
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
