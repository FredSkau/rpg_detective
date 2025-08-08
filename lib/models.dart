class StoryHook {
  final String id;
  final String title;
  final String description;
  StoryHook({required this.id, required this.title, required this.description});
}

class StoryBible {
  final String id;
  final String hookText;
  final String solutionSummary;
  StoryBible({required this.id, required this.hookText, required this.solutionSummary});
}

class GameState {
  String location;
  GameState({required this.location});
}

class NarrationTurn {
  final String narration;
  final List<String>? options;
  final Map<String, dynamic>? stateDelta;
  NarrationTurn({required this.narration, this.options, this.stateDelta});
}
