class StoryChapter {
  const StoryChapter({
    required this.chapter,
    required this.narrations,
  });

  final int chapter;
  final Map<String, String> narrations;

  String getNarration(String lang) =>
      narrations[lang] ?? narrations['en'] ?? '';

  factory StoryChapter.fromJson(Map<String, dynamic> json) {
    final narrRaw = json['narrations'] as Map<String, dynamic>? ?? {};
    return StoryChapter(
      chapter: (json['chapter'] as num).toInt(),
      narrations: narrRaw.map((k, v) => MapEntry(k, v as String)),
    );
  }
}

class StoryModel {
  const StoryModel({
    required this.id,
    required this.titles,
    required this.companionAsset,
    required this.previewAsset,
    required this.drawingIds,
    required this.chapters,
  });

  final String id;
  final Map<String, String> titles;
  final String companionAsset;
  final String previewAsset;
  final List<String> drawingIds;
  final List<StoryChapter> chapters;

  String getTitle(String lang) => titles[lang] ?? titles['en'] ?? id;

  factory StoryModel.fromJson(Map<String, dynamic> json) {
    final titlesRaw = json['titles'] as Map<String, dynamic>? ?? {};
    final drawingIdsRaw = json['drawing_ids'] as List<dynamic>? ?? [];
    final chaptersRaw = json['chapters'] as List<dynamic>? ?? [];

    return StoryModel(
      id: json['id'] as String,
      titles: titlesRaw.map((k, v) => MapEntry(k, v as String)),
      companionAsset: json['companion_asset'] as String,
      previewAsset: json['preview_asset'] as String,
      drawingIds: drawingIdsRaw.map((e) => e as String).toList(),
      chapters: chaptersRaw
          .map((e) => StoryChapter.fromJson(e as Map<String, dynamic>))
          .toList(),
    );
  }
}
