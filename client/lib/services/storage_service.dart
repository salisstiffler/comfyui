import 'dart:async';
import 'dart:io';
import 'package:path/path.dart';
import 'package:sqflite/sqflite.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import '../models/task_model.dart';

class StorageService {
  static Database? _database;

  static Future<Database> get database async {
    if (_database != null) return _database!;
    _database = await _initDB();
    return _database!;
  }

  static Future<Database> _initDB() async {
    if (Platform.isWindows || Platform.isLinux) {
      // CRITICAL: Initialize FFI and Factory BEFORE any other sqflite call
      sqfliteFfiInit();
      databaseFactory = databaseFactoryFfi;
    }

    // Now it's safe to call getDatabasesPath()
    String dbDir = await getDatabasesPath();
    String path = join(dbDir, 'comfy_ai.db');

    return await openDatabase(
      path,
      version: 2,
      onCreate: (db, version) async {
        await db.execute('''
          CREATE TABLE tasks(
            promptId TEXT PRIMARY KEY,
            prompt TEXT,
            status TEXT,
            resultImageUrl TEXT,
            timestamp TEXT,
            completedAt TEXT
          )
        ''');
      },
      onUpgrade: (db, oldVersion, newVersion) async {
        if (oldVersion < 2) {
          await db.execute('ALTER TABLE tasks ADD COLUMN completedAt TEXT');
        }
      },
    );
  }

  static Future<void> saveTask(AiTask task) async {
    final db = await database;
    await db.insert(
      'tasks',
      task.toMap(),
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  static Future<List<AiTask>> getTasks() async {
    final db = await database;
    try {
      final List<Map<String, dynamic>> maps = await db.query(
        'tasks',
        orderBy: 'timestamp DESC',
      );
      return List.generate(maps.length, (i) => AiTask.fromMap(maps[i]));
    } catch (e) {
      print('Error querying tasks: $e');
      return [];
    }
  }

  static Future<void> deleteTask(String promptId) async {
    final db = await database;
    await db.delete('tasks', where: 'promptId = ?', whereArgs: [promptId]);
  }

  static Future<void> updateTaskStatus(
    String promptId,
    String status, {
    String? imageUrl,
    DateTime? completedAt,
  }) async {
    final db = await database;
    final Map<String, dynamic> values = {
      'status': status,
      if (imageUrl != null) 'resultImageUrl': imageUrl,
      if (completedAt != null) 'completedAt': completedAt.toIso8601String(),
    };
    await db.update(
      'tasks',
      values,
      where: 'promptId = ?',
      whereArgs: [promptId],
    );
  }
}
