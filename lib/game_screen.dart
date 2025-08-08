import 'package:flutter/material.dart';

import 'models.dart';
import 'services/architect_service.dart';
import 'services/grok_client.dart';
import 'services/narrator_service.dart';

class GameScreen extends StatefulWidget {
  const GameScreen({super.key});

  @override
  State<GameScreen> createState() => _GameScreenState();
}

class _GameScreenState extends State<GameScreen> {
  late final GrokClient _client;
  late final ArchitectService _architect;

  List<StoryHook>? _hooks;
  StoryBible? _bible;
  NarratorService? _narrator;
  GameState? _state;

  final List<String> _log = [];
  List<String>? _options; // null => conversation mode
  bool _loading = false;
  final TextEditingController _input = TextEditingController();

  @override
  void initState() {
    super.initState();
    _client = GrokClient();
    _architect = ArchitectService(_client);
    _fetchHooks();
  }

  Future<void> _fetchHooks() async {
    setState(() => _loading = true);
    try {
      _hooks = await _architect.fetchHooks();
    } finally {
      setState(() => _loading = false);
    }
  }

  Future<void> _selectHook(StoryHook hook) async {
    setState(() => _loading = true);
    try {
      _bible = await _architect.buildBible(hook);
      _state = GameState(location: 'start');
      _narrator = NarratorService(_client, _bible!);
      final turn = await _narrator!.narrate(_state!, 'start');
      _applyTurn(turn);
    } finally {
      setState(() => _loading = false);
    }
  }

  void _applyTurn(NarrationTurn turn) {
    _log.add(turn.narration);
    _options = turn.options;
    if (turn.stateDelta != null) {
      final loc = turn.stateDelta!['location'] as String?;
      if (loc != null) _state!.location = loc;
    }
  }

  Future<void> _handleOption(String option) async {
    setState(() => _loading = true);
    try {
      final turn = await _narrator!.narrate(_state!, option);
      _applyTurn(turn);
    } finally {
      setState(() => _loading = false);
    }
  }

  Future<void> _handleFreeText() async {
    final text = _input.text.trim();
    if (text.isEmpty) return;
    _input.clear();
    setState(() => _loading = true);
    try {
      final turn = await _narrator!.narrate(_state!, text);
      _applyTurn(turn);
    } finally {
      setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_loading && _hooks == null) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_hooks != null && _bible == null) {
      return Scaffold(
        appBar: AppBar(title: const Text('Choose a Mystery')),
        body: ListView(
          children: _hooks!
              .map((h) => ListTile(
                    title: Text(h.title),
                    subtitle: Text(h.description),
                    onTap: () => _selectHook(h),
                  ))
              .toList(),
        ),
      );
    }

    // Game in progress
    return Scaffold(
      appBar: AppBar(title: Text(_bible?.hookText ?? 'Mystery')),
      body: Column(
        children: [
          Expanded(
            child: ListView.builder(
              padding: const EdgeInsets.all(12),
              itemCount: _log.length,
              itemBuilder: (context, index) => Padding(
                padding: const EdgeInsets.symmetric(vertical: 4),
                child: Text(_log[index]),
              ),
            ),
          ),
          if (_loading) const LinearProgressIndicator(),
          if (_options != null) ...[
            for (final opt in _options!)
              ListTile(
                title: Text(opt),
                onTap: () => _handleOption(opt),
              )
          ] else
            Padding(
              padding: const EdgeInsets.all(8.0),
              child: Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _input,
                      onSubmitted: (_) => _handleFreeText(),
                      decoration: const InputDecoration(
                          hintText: 'Ask or say something...'),
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.send),
                    onPressed: _handleFreeText,
                  )
                ],
              ),
            )
        ],
      ),
    );
  }
}
