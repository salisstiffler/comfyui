import 'dart:convert';
import 'package:http/http.dart' as http;

class ApiService {
  // Use 10.0.2.2 for Android Emulator, localhost for Windows/Web
  // Later this can be replaced with the Cloudflare Tunnel URL
  static String baseUrl = 'http://127.0.0.1:8100';

  static Future<String?> generateImage(String prompt) async {
    try {
      final response = await http.post(
        Uri.parse('$baseUrl/api/generate'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'prompt': prompt}),
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
