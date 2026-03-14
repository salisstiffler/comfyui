import 'dart:convert';
import 'package:http/http.dart' as http;
import '../models/task_model.dart';

class ApiService {
  // Docker maps host port 8100 to container port 8000
  static String baseUrl = 'http://127.0.0.1:8100';
  static String userId = 'guest';

  static Future<String?> generateImage(
    String prompt, {
    int steps = 8,
    double cfg = 1.0,
    int? seed,
    String sampler = 'res_multistep',
    int batchSize = 1,
    int width = 1024,
    int height = 1024,
  }) async {
    try {
      final response = await http.post(
        Uri.parse('$baseUrl/api/generate'),
        headers: {'Content-Type': 'application/json', 'X-User-ID': userId},
        body: jsonEncode({
          'prompt': prompt,
          'steps': steps,
          'cfg': cfg,
          'seed': seed,
          'sampler_name': sampler,
          'batch_size': batchSize,
          'width': width,
          'height': height,
        }),
      );
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        if (data != null && data is Map) {
          return data['prompt_id'];
        }
      }
      return null;
    } catch (e) {
      print('Exception during image generate: $e');
      return null;
    }
  }

  static Future<String?> generateMusic({
    String? tags,
    String? lyrics,
    String? prompt,
    int bpm = 120,
    int duration = 120,
    int? seed,
    int steps = 30,
    double cfg = 1.0,
  }) async {
    try {
      final response = await http.post(
        Uri.parse('$baseUrl/api/generate/music'),
        headers: {'Content-Type': 'application/json', 'X-User-ID': userId},
        body: jsonEncode({
          'tags': tags,
          'lyrics': lyrics,
          'prompt': prompt,
          'bpm': bpm,
          'duration': duration,
          'seed': seed,
          'steps': steps,
          'cfg': cfg,
        }),
      );
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        return data['prompt_id'];
      }
      final error = jsonDecode(response.body);
      throw Exception(error['detail'] ?? 'SERVER_ERROR');
    } catch (e) {
      print('Exception during music generate: $e');
      rethrow;
    }
  }

  static Future<String?> uploadImage(List<int> bytes, String filename) async {
    try {
      final request = http.MultipartRequest(
        'POST',
        Uri.parse('$baseUrl/api/upload'),
      );
      request.files.add(
        http.MultipartFile.fromBytes('file', bytes, filename: filename),
      );
      final response = await request.send();
      if (response.statusCode == 200) {
        final resBody = await response.stream.bytesToString();
        return jsonDecode(resBody)['filename'];
      }
      return null;
    } catch (e) {
      print('Upload Error: $e');
      return null;
    }
  }

  static Future<String?> generateEdit({
    required String prompt,
    required String image,
    double denoise = 1.0,
    int steps = 4,
    int? seed,
  }) async {
    try {
      final request = http.MultipartRequest(
        'POST',
        Uri.parse('$baseUrl/api/generate/edit'),
      );
      request.headers['X-User-ID'] = userId;
      request.fields['prompt'] = prompt;
      request.fields['image'] = image;
      request.fields['denoise'] = denoise.toString();
      request.fields['steps'] = steps.toString();
      if (seed != null) request.fields['seed'] = seed.toString();

      final response = await request.send();
      if (response.statusCode == 200) {
        final resBody = await response.stream.bytesToString();
        return jsonDecode(resBody)['prompt_id'];
      }
      return null;
    } catch (e) {
      print('Edit Error: $e');
      return null;
    }
  }

  static Future<String?> generateNsfw({
    required String image,
  }) async {
    try {
      final request = http.MultipartRequest(
        'POST',
        Uri.parse('$baseUrl/api/generate/nsfw'),
      );
      request.headers['X-User-ID'] = userId;
      request.fields['image'] = image;

      final response = await request.send();
      if (response.statusCode == 200) {
        final resBody = await response.stream.bytesToString();
        return jsonDecode(resBody)['prompt_id'];
      }
      return null;
    } catch (e) {
      print('NSFW Error: $e');
      return null;
    }
  }

  static Future<String?> generateUndress({
    required String image,
  }) async {
    try {
      final request = http.MultipartRequest(
        'POST',
        Uri.parse('$baseUrl/api/generate/undress'),
      );
      request.headers['X-User-ID'] = userId;
      request.fields['image'] = image;

      final response = await request.send();
      if (response.statusCode == 200) {
        final resBody = await response.stream.bytesToString();
        return jsonDecode(resBody)['prompt_id'];
      }
      return null;
    } catch (e) {
      print('Undress Error: $e');
      return null;
    }
  }

  static Future<List<AiTask>> getJobs() async {
    try {
      final response = await http.get(
        Uri.parse('$baseUrl/api/jobs'),
        headers: {'X-User-ID': userId},
      );
      if (response.statusCode == 200) {
        final List list = jsonDecode(response.body);
        return list.map((item) {
          // Parse JSON strings from database if necessary
          Map<String, dynamic> params = {};
          if (item['params'] != null && item['params'] is String) {
            try {
              params = jsonDecode(item['params']);
            } catch (_) {}
          } else if (item['params'] is Map) {
            params = item['params'];
          }

          List images = [];
          if (item['images'] != null && item['images'] is String) {
            try {
              images = jsonDecode(item['images']);
            } catch (_) {}
          } else if (item['images'] is List) {
            images = item['images'];
          }

          List audioFiles = [];
          if (item['audio_files'] != null && item['audio_files'] is String) {
            try {
              audioFiles = jsonDecode(item['audio_files']);
            } catch (_) {}
          } else if (item['audio_files'] is List) {
            audioFiles = item['audio_files'];
          }

          final compAtVal = item['completed_at'];
          DateTime? compAt;
          if (compAtVal != null) {
            compAt = DateTime.fromMillisecondsSinceEpoch(
              ((compAtVal as num) * 1000).toInt(),
            );
          }

          return AiTask(
            promptId: item['prompt_id'] ?? '',
            prompt: item['prompt'] ?? '',
            status: item['status'] ?? 'queued',
            timestamp: DateTime.fromMillisecondsSinceEpoch(
              (((item['timestamp'] as num?) ?? 0) * 1000).toInt(),
            ),
            completedAt: compAt,
            type: item['type'] ?? 'image',
            resultImageUrl: images.isNotEmpty
                ? getImageUrl(images.first)
                : null,
            resultAudioUrl: audioFiles.isNotEmpty
                ? getAudioUrl(audioFiles.first)
                : null,
            resultFilename: images.isNotEmpty
                ? images.first
                : (audioFiles.isNotEmpty ? audioFiles.first : null),
            musicDuration: (params['duration'] as num?)?.toDouble(),
            steps: params['steps'] ?? 8,
            cfg: (params['cfg'] as num?)?.toDouble() ?? 1.0,
            seed: params['seed'],
            sampler: params['sampler'] ?? 'res_multistep',
            batchSize: params['batch_size'] ?? 1,
            width: params['width'] ?? 1024,
            height: params['height'] ?? 1024,
            workflowMode: params['mode'],
          );
        }).toList();
      }
      return [];
    } catch (e) {
      print('Exception getting jobs: $e');
      return [];
    }
  }

  static Future<Map<String, dynamic>?> checkHealthFull() async {
    try {
      final response = await http.get(Uri.parse('$baseUrl/api/health'));
      if (response.statusCode == 200) {
        return jsonDecode(response.body);
      }
      return null;
    } catch (e) {
      return null;
    }
  }

  static Future<bool> checkHealth() async {
    try {
      final response = await http.get(Uri.parse('$baseUrl/api/health'));
      return response.statusCode == 200;
    } catch (e) {
      return false;
    }
  }

  static Future<bool> wakeEngine() async {
    try {
      final response = await http.post(Uri.parse('$baseUrl/api/wake'));
      return response.statusCode == 200;
    } catch (e) {
      print('Exception waking engine: $e');
      return false;
    }
  }

  static Future<Map<String, dynamic>?> checkStatus(String promptId) async {
    try {
      final response = await http.get(
        Uri.parse('$baseUrl/api/status/$promptId'),
      );
      if (response.statusCode == 200) {
        return jsonDecode(response.body);
      }
      return null;
    } catch (e) {
      print('Exception checking status: $e');
      return null;
    }
  }

  static Future<bool> cancelTask(String promptId) async {
    try {
      final response = await http.delete(
        Uri.parse('$baseUrl/api/jobs/$promptId'),
        headers: {'X-User-ID': userId},
      );
      return response.statusCode == 200;
    } catch (e) {
      print('Exception cancelling task: $e');
      return false;
    }
  }

  static String getImageUrl(String filename) {
    return '$baseUrl/api/image/$filename';
  }

  static String getAudioUrl(String filename) {
    return '$baseUrl/api/audio/$filename';
  }
}
