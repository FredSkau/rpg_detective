import 'dart:convert';

import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:http/http.dart' as http;

/// Thin wrapper around Grok's chat/completions API supporting
/// basic chat as well as structured JSON outputs.
class GrokClient {
  GrokClient() : _apiKey = dotenv.env['XAI_API_KEY'] ?? '' {
    if (_apiKey.isEmpty) {
      throw StateError('XAI_API_KEY missing – add it to your .env file.');
    }
  }

  final String _apiKey;
  static const _baseUrl = 'https://api.x.ai/v1/chat/completions';

  Map<String, String> _headers() => {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $_apiKey',
      };

  /// Send `messages` to Grok. Optionally provide a JSON `schema` that
  /// the model must follow using the `json_schema` response format.
  Future<Map<String, dynamic>> chat(
    List<Map<String, String>> messages, {
    Map<String, dynamic>? schema,
    String model = 'grok-4',
  }) async {
    final body = {
      'model': model,
      'messages': messages,
      'stream': false,
    };
    if (schema != null) {
      body['response_format'] = {
        'type': 'json_schema',
        'json_schema': {
          'schema': schema,
          'strict': true,
        }
      };
    }

    final response = await http.post(
      Uri.parse(_baseUrl),
      headers: _headers(),
      body: jsonEncode(body),
    );

    if (response.statusCode != 200) {
      throw http.ClientException(
          'Grok error → ${response.statusCode}: ${response.body}');
    }

    final data = jsonDecode(response.body) as Map<String, dynamic>;
    final msg = data['choices'][0]['message'] as Map<String, dynamic>;
    final content = msg['content'];
    if (content is String) {
      // No structured output, just return as {'content': text}
      return {'content': content.trim()};
    }
    return jsonDecode(content as String) as Map<String, dynamic>;
  }
}
