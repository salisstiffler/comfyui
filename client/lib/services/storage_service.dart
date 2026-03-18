import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';
import 'dart:convert';
import '../models/task_model.dart';

class StorageService {
  static Database? _db;

  static Future<Database> get database async {
    if (_db != null) return _db!;
    _db = await _initDB();
    return _db!;
  }

  static Future<Database> _initDB() async {
    String path = join(await getDatabasesPath(), 'comfy_cache.db');
    return await openDatabase(
      path,
      version: 1,
      onCreate: (db, version) async {
        await db.execute('''
          CREATE TABLE tasks(
            prompt_id TEXT PRIMARY KEY,
            prompt TEXT,
            status TEXT,
            timestamp INTEGER,
            completed_at INTEGER,
            type TEXT,
            params TEXT,
            images TEXT,
            audio_files TEXT
          )
        ''');
      },
    );
  }

  static Future<void> saveTasks(List<AiTask> tasks) async {
    final db = await database;
    final batch = db.batch();
    for (var task in tasks) {
      batch.insert(
        'tasks',
        {
          'prompt_id': task.promptId,
          'prompt': task.prompt,
          'status': task.status,
          'timestamp': (task.timestamp.millisecondsSinceEpoch / 1000).toInt(),
          'completed_at': task.completedAt != null 
              ? (task.completedAt!.millisecondsSinceEpoch / 1000).toInt() 
              : null,
          'type': task.type,
          // We don't have direct access to raw params/images from AiTask easily, 
          // so we'll store what we can. 
          // For a perfect sync, we'd need to modify AiTask or the mapping logic.
        },
        conflictAlgorithm: ConflictAlgorithm.replace,
      );
    }
    await batch.commit(noResult: true);
  }

  static Future<List<AiTask>> getTasks() async {
    final db = await database;
    final List<Map<String, dynamic>> maps = await db.query('tasks', orderBy: 'timestamp DESC');
    
    return List.generate(maps.length, (i) {
      final row = maps[i];
      return AiTask(
        promptId: row['prompt_id'],
        prompt: row['prompt'],
        status: row['status'],
        timestamp: DateTime.fromMillisecondsSinceEpoch(row['timestamp'] * 1000),
        completedAt: row['completed_at'] != null 
            ? DateTime.fromMillisecondsSinceEpoch(row['completed_at'] * 1000) 
            : null,
        type: row['type'] ?? 'image',
        // In a real scenario, we'd store the result filename to reconstruct URLs
      );
    });
  }
}
