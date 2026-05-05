import 'dart:convert';

import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/drawing_model.dart';
import '../models/story_model.dart';

class AssetService {
  final Map<String, DrawingModel> _drawingCache = {};
  List<StoryModel>? _storiesCache;

  Future<List<StoryModel>> loadStories() async {
    if (_storiesCache != null) return _storiesCache!;

    final jsonString =
        await rootBundle.loadString('assets/stories/stories.json');
    final jsonMap = json.decode(jsonString) as Map<String, dynamic>;
    final storiesRaw = jsonMap['stories'] as List<dynamic>;

    _storiesCache = storiesRaw
        .map((e) => StoryModel.fromJson(e as Map<String, dynamic>))
        .toList();
    return _storiesCache!;
  }

  Future<DrawingModel> loadDrawing(String id) async {
    if (_drawingCache.containsKey(id)) return _drawingCache[id]!;

    final jsonString =
        await rootBundle.loadString('assets/drawings/$id/$id.json');
    final jsonMap = json.decode(jsonString) as Map<String, dynamic>;
    final model = DrawingModel.fromJson(jsonMap);
    _drawingCache[id] = model;
    return model;
  }

  Future<List<DrawingModel>> loadStoryDrawings(StoryModel story) async {
    final results = <DrawingModel>[];
    for (final id in story.drawingIds) {
      results.add(await loadDrawing(id));
    }
    return results;
  }
}

// ---------------------------------------------------------------------------
// Providers
// ---------------------------------------------------------------------------
final assetServiceProvider = Provider<AssetService>(
  (_) => AssetService(),
);

final storiesProvider = FutureProvider<List<StoryModel>>(
  (ref) => ref.watch(assetServiceProvider).loadStories(),
);
