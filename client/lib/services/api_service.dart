import 'dart:convert';
import 'package:http/http.dart' as http;
import '../models/task_model.dart';

class ApiService {
  // Use 10.0.2.2 for Android Emulator, localhost for Windows/Web
  // Later this can be replaced with the Cloudflare Tunnel URL
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
        headers: {
          'Content-Type': 'application/json',
          'X-User-ID': userId,
        },
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
        return data['prompt_id'];
      } else {
        print('Error generating image: ${response.statusCode}');
        return null;
      }
    } catch (e) {
      print('Exception during generate: $e');
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
          final params = item['params'] ?? {};
          final images = item['images'] as List? ?? [];
          final compAtVal = item['completed_at'];
          DateTime? compAt;
          if (compAtVal != null) {
            compAt = DateTime.fromMillisecondsSinceEpoch(
              ((compAtVal as num) * 1000).toInt(),
            );
          }

          return AiTask(
            promptId: item['prompt_id'],
            prompt: item['prompt'],
            status: item['status'],
            timestamp: DateTime.fromMillisecondsSinceEpoch(
              ((item['timestamp'] as num) * 1000).toInt(),
            ),
            completedAt: compAt,
            resultImageUrl:
                images.isNotEmpty ? getImageUrl(images.first) : null,
            steps: params['steps'] ?? 8,
            cfg: (params['cfg'] as num?)?.toDouble() ?? 1.0,
            seed: params['seed'],
            sampler: params['sampler'] ?? 'res_multistep',
            batchSize: params['batch_size'] ?? 1,
            width: params['width'] ?? 1024,
            height: params['height'] ?? 1024,
          );
        }).toList();
      }
      return [];
    } catch (e) {
      print('Exception getting jobs: $e');
      return [];
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
        Uri.parse('$baseUrl/api/queue/$promptId'),
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
}
