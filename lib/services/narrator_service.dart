import '../models.dart';
import 'grok_client.dart';

/// Handles fast, turn-to-turn narration and game updates.
class NarratorService {
  NarratorService(this._client, this._bible);
  final GrokClient _client;
  final StoryBible _bible;

  /// Request a narration step given the current game [state] and
  /// the player's chosen [input] (either option text or free form).
  Future<NarrationTurn> narrate(GameState state, String input) async {
    const schema = {
      'type': 'object',
      'properties': {
        'narration': {'type': 'string'},
        'options': {
          'type': ['array', 'null'],
          'items': {'type': 'string'}
        },
        'stateDelta': {
          'type': ['object', 'null']
        }
      },
      'required': ['narration', 'options', 'stateDelta']
    };

    final messages = [
      {
        'role': 'system',
        'content': 'You are the Narrator of an interactive detective story.'
      },
      {
        'role': 'user',
        'content': 'Story bible: ${_bible.hookText}\nCurrent location: ${state.location}\nPlayer input: $input'
      }
    ];

    final res = await _client.chat(messages, schema: schema, model: 'grok-3-mini');
    return NarrationTurn(
      narration: res['narration'] as String,
      options: (res['options'] as List?)?.cast<String>(),
      stateDelta: res['stateDelta'] as Map<String, dynamic>?,
    );
  }
}
