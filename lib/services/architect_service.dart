import '../models.dart';
import 'grok_client.dart';

/// Handles slow, high-level world creation tasks: generating mystery hooks
/// and expanding a selected hook into a Story Bible.
class ArchitectService {
  ArchitectService(this._client);
  final GrokClient _client;

  /// Ask Grok for three distinct mystery hooks.
  Future<List<StoryHook>> fetchHooks() async {
    const schema = {
      'type': 'object',
      'properties': {
        'hooks': {
          'type': 'array',
          'items': {
            'type': 'object',
            'properties': {
              'id': {'type': 'string'},
              'title': {'type': 'string'},
              'description': {'type': 'string'}
            },
            'required': ['id', 'title', 'description']
          }
        }
      },
      'required': ['hooks']
    };

    final res = await _client.chat([
      {
        'role': 'system',
        'content':
            'Return three genre-diverse detective mystery hooks as JSON.'
      },
      {'role': 'user', 'content': 'Pitch three mysteries'}
    ], schema: schema, model: 'grok-3-mini');

    final hooks = (res['hooks'] as List)
        .map((e) => StoryHook(
              id: e['id'] as String,
              title: e['title'] as String,
              description: e['description'] as String,
            ))
        .toList();
    return hooks;
  }

  /// Given a chosen hook, expand it into a Story Bible.
  Future<StoryBible> buildBible(StoryHook hook) async {
    const schema = {
      'type': 'object',
      'properties': {
        'id': {'type': 'string'},
        'hook_text': {'type': 'string'},
        'solution_summary': {'type': 'string'}
      },
      'required': ['id', 'hook_text', 'solution_summary']
    };

    final res = await _client.chat([
      {
        'role': 'system',
        'content':
            'You are the Architect. Expand the given hook into a concise story bible.'
      },
      {
        'role': 'user',
        'content': 'Hook: ${hook.description}'
      }
    ], schema: schema, model: 'grok-4');

    return StoryBible(
      id: res['id'] as String,
      hookText: res['hook_text'] as String,
      solutionSummary: res['solution_summary'] as String,
    );
  }
}
