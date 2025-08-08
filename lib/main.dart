import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:http/http.dart' as http;

/// Entry point – ensure .env is loaded before the UI builds.
Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await dotenv.load(fileName: '.env');
  runApp(const MyApp());
}

/// A lightweight Grok client supporting:
///  * normal chat (`sendMessage`)
///  * reasoning + structured output (`evaluateMath`)
///
/// It keeps message history in‑memory so you can call it from anywhere.
class GrokClient {
  GrokClient() : _apiKey = dotenv.env['XAI_API_KEY'] ?? '' {
    if (_apiKey.isEmpty) {
      throw StateError('XAI_API_KEY missing – add it to your .env file.');
    }
  }

  // ---------------- fields ----------------

  final String _apiKey;
  static const _baseUrl = 'https://api.x.ai/v1/chat/completions';

  /// Running conversation – starts with a system prompt so Grok knows its role.
  final List<Map<String, String>> _messages = [
    {
      'role': 'system',
      'content': 'You are Grok, a highly intelligent, helpful AI assistant.'
    }
  ];

  List<Map<String, String>> get messages => List.unmodifiable(_messages);

  Map<String, String> _headers() => {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $_apiKey',
      };

  // ---------------- basic chat ----------------

  /// Send a free‑form chat message and return Grok’s reply.
  Future<String> sendMessage(String userMessage) async {
    _messages.add({'role': 'user', 'content': userMessage});

    final response = await http.post(
      Uri.parse(_baseUrl),
      headers: _headers(),
      body: jsonEncode({
        'model': 'grok-4',
        'messages': _messages,
        'stream': false,
      }),
    );

    if (response.statusCode != 200) {
      throw http.ClientException(
          'Grok error → ${response.statusCode}: ${response.body}');
    }

    final data = jsonDecode(response.body) as Map<String, dynamic>;
    final assistantContent =
        (data['choices'][0]['message']['content'] as String).trim();

    _messages.add({'role': 'assistant', 'content': assistantContent});
    return assistantContent;
  }

  // ---------------- structured output demo ----------------

  /// Very small demo: ask Grok to solve a math expression and return
  /// structured JSON **plus** its reasoning trace (using a reasoning model).
  ///
  /// Returns a tuple‑ish Map with keys: `answer`, `explanation`, `reasoning`.
  Future<Map<String, dynamic>> evaluateMath(String expression) async {
    // JSON‑schema the model must obey.
    const schema = {
      'type': 'object',
      'properties': {
        'answer': {'type': 'number'},
        'explanation': {'type': 'string'}
      },
      'required': ['answer', 'explanation']
    };

    final response = await http.post(
      Uri.parse(_baseUrl),
      headers: _headers(),
      body: jsonEncode({
        'model': 'grok-3-mini', // returns `reasoning_content`
        'messages': [
          {
            'role': 'system',
            'content':
                'Return the result of the math expression in JSON following the given schema.'
          },
          {'role': 'user', 'content': expression}
        ],
        'response_format': {
          'type': 'json_schema',
          'json_schema': {
            'schema': schema,
            'strict': true
          }
        },
        'stream': false,
      }),
    );

    if (response.statusCode != 200) {
      throw http.ClientException(
          'Grok structured error → ${response.statusCode}: ${response.body}');
    }

    final data = jsonDecode(response.body) as Map<String, dynamic>;
    final choice = data['choices'][0]['message'] as Map<String, dynamic>;

    final parsed = jsonDecode(choice['content'] as String)
        as Map<String, dynamic>; // answer + explanation
    final reasoning = choice['reasoning_content'] as String?; // may be null

    // Add human‑readable messages to chat history so they show up in the UI.
    _messages.add({'role': 'user', 'content': expression});
    _messages.add({
      'role': 'assistant',
      'content': 'Answer: ${parsed['answer']}\nExplanation: ${parsed['explanation']}'
    });
    if (reasoning != null && reasoning.isNotEmpty) {
      _messages.add({'role': 'assistant', 'content': 'Reasoning trace:\n$reasoning'});
    }

    return {
      'answer': parsed['answer'],
      'explanation': parsed['explanation'],
      'reasoning': reasoning,
    };
  }
}

// ---------------------------------------------------------------------------
// UI
// ---------------------------------------------------------------------------

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Grok Chat Demo',
      theme: ThemeData(colorScheme: ColorScheme.fromSeed(seedColor: Colors.blue)),
      home: const ChatPage(),
    );
  }
}

class ChatPage extends StatefulWidget {
  const ChatPage({super.key});

  @override
  State<ChatPage> createState() => _ChatPageState();
}

class _ChatPageState extends State<ChatPage> {
  final _client = GrokClient();
  final _input = TextEditingController();
  final _scroll = ScrollController();
  bool _isSending = false;

  @override
  void dispose() {
    _input.dispose();
    _scroll.dispose();
    super.dispose();
  }

  Future<void> _handleSend() async {
    final text = _input.text.trim();
    if (text.isEmpty || _isSending) return;
    _input.clear();

    setState(() => _isSending = true);
    try {
      await _client.sendMessage(text);
      _rebuildAndScroll();
    } catch (e) {
      if (mounted) _showError(e);
    } finally {
      if (mounted) setState(() => _isSending = false);
    }
  }

  Future<void> _runStructuredDemo() async {
    if (_isSending) return;
    setState(() => _isSending = true);
    try {
      await _client.evaluateMath('101*3');
      _rebuildAndScroll();
    } catch (e) {
      if (mounted) _showError(e);
    } finally {
      if (mounted) setState(() => _isSending = false);
    }
  }

  void _rebuildAndScroll() async {
    setState(() {});
    // Let the list build first.
    await Future.delayed(const Duration(milliseconds: 100));
    _scroll.animateTo(
      _scroll.position.maxScrollExtent + 80,
      duration: const Duration(milliseconds: 300),
      curve: Curves.easeOut,
    );
  }

  void _showError(Object e) {
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text(e.toString())));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Chat with Grok'),
        actions: [
          IconButton(
            tooltip: 'Run structured‑output demo',
            onPressed: _runStructuredDemo,
            icon: const Icon(Icons.science_outlined),
          ),
        ],
      ),
      body: Column(
        children: [
          // Messages list
          Expanded(
            child: ListView.builder(
              controller: _scroll,
              padding: const EdgeInsets.all(12),
              itemCount: _client.messages.length,
              itemBuilder: (context, index) {
                final msg = _client.messages[index];
                final isUser = msg['role'] == 'user';
                return Align(
                  alignment:
                      isUser ? Alignment.centerRight : Alignment.centerLeft,
                  child: Container(
                    margin: const EdgeInsets.symmetric(vertical: 4),
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: isUser
                          ? Theme.of(context).colorScheme.primary
                          : Theme.of(context).colorScheme.surfaceVariant,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      msg['content'] ?? '',
                      style: TextStyle(
                        color: isUser
                            ? Theme.of(context).colorScheme.onPrimary
                            : Theme.of(context).colorScheme.onSurface,
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
          // Input field
          SafeArea(
            child: Padding(
              padding:
                  const EdgeInsets.symmetric(horizontal: 8.0, vertical: 4.0),
              child: Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _input,
                      onSubmitted: (_) => _handleSend(),
                      decoration: const InputDecoration(hintText: 'Type a message…'),
                    ),
                  ),
                  IconButton(
                    onPressed: _isSending ? null : _handleSend,
                    icon: _isSending
                        ? const SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(),
                          )
                        : const Icon(Icons.send),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
