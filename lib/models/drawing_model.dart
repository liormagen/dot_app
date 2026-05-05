import 'dot_model.dart';

class DrawingModel {
  const DrawingModel({
    required this.id,
    required this.names,
    required this.storyId,
    required this.chapter,
    required this.difficulty,
    required this.canvasWidth,
    required this.canvasHeight,
    required this.imageOutline,
    required this.imageColored,
    required this.tutorialSteps,
    required this.dots,
  });

  final String id;
  final Map<String, String> names;
  final String storyId;
  final int chapter;
  final String difficulty;
  final int canvasWidth;
  final int canvasHeight;
  final String imageOutline;
  final String imageColored;
  final List<String> tutorialSteps;
  final List<DotModel> dots;

  int get hintDelaySeconds {
    switch (difficulty) {
      case 'easy':
        return 2;
      case 'hard':
        return 5;
      case 'medium':
      default:
        return 3;
    }
  }

  String getName(String lang) => names[lang] ?? names['en'] ?? id;

  factory DrawingModel.fromJson(Map<String, dynamic> json) {
    final namesRaw = json['names'] as Map<String, dynamic>? ?? {};
    final tutorialRaw = json['tutorial_steps'] as List<dynamic>? ?? [];
    final dotsRaw = json['dots'] as List<dynamic>? ?? [];

    return DrawingModel(
      id: json['id'] as String,
      names: namesRaw.map((k, v) => MapEntry(k, v as String)),
      storyId: json['story_id'] as String,
      chapter: (json['chapter'] as num).toInt(),
      difficulty: json['difficulty'] as String? ?? 'medium',
      canvasWidth: (json['canvas_width'] as num).toInt(),
      canvasHeight: (json['canvas_height'] as num).toInt(),
      imageOutline: json['image_outline'] as String,
      imageColored: json['image_colored'] as String,
      tutorialSteps: tutorialRaw.map((e) => e as String).toList(),
      dots: dotsRaw
          .map((e) => DotModel.fromJson(e as Map<String, dynamic>))
          .toList(),
    );
  }
}
