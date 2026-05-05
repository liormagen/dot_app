import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../services/asset_service.dart';
import '../../services/progress_service.dart';
import '../../widgets/parental_gate.dart';
import '../../widgets/story_card.dart';
import 'settings_sheet.dart';

class StorySelectionScreen extends ConsumerWidget {
  const StorySelectionScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final storiesAsync = ref.watch(storiesProvider);
    final progress = ref.watch(progressProvider);

    return Scaffold(
      backgroundColor: const Color(0xFFF8F4FF),
      appBar: AppBar(
        backgroundColor: const Color(0xFF6B4EFF),
        foregroundColor: Colors.white,
        title: const Text(
          'Dot Story',
          style: TextStyle(
            fontWeight: FontWeight.bold,
            fontSize: 24,
          ),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.photo_library_outlined),
            tooltip: 'Gallery',
            onPressed: () => context.go('/gallery'),
          ),
          IconButton(
            icon: const Icon(Icons.settings_outlined),
            tooltip: 'Settings',
            onPressed: () async {
              final allowed = await ParentalGate.show(context);
              if (!allowed || !context.mounted) return;
              showModalBottomSheet(
                context: context,
                isScrollControlled: true,
                shape: const RoundedRectangleBorder(
                  borderRadius:
                      BorderRadius.vertical(top: Radius.circular(24)),
                ),
                builder: (_) => const SettingsSheet(),
              );
            },
          ),
          const SizedBox(width: 8),
        ],
        elevation: 0,
      ),
      body: storiesAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('Error: $e')),
        data: (stories) {
          if (stories.isEmpty) {
            return const Center(child: Text('No stories available.'));
          }
          return Padding(
            padding: const EdgeInsets.all(16.0),
            child: GridView.builder(
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 2,
                crossAxisSpacing: 16,
                mainAxisSpacing: 16,
                childAspectRatio: 0.75,
              ),
              itemCount: stories.length,
              itemBuilder: (context, index) {
                final story = stories[index];
                final completedCount = story.drawingIds
                    .where((id) =>
                        progress.completedDrawingIds.contains(id))
                    .length;

                return StoryCard(
                  story: story,
                  completedCount: completedCount,
                  language: progress.selectedLanguage,
                  onTap: () => _onStoryTap(context, story.id,
                      story.drawingIds, progress.completedDrawingIds),
                );
              },
            ),
          );
        },
      ),
    );
  }

  void _onStoryTap(
    BuildContext context,
    String storyId,
    List<String> drawingIds,
    Set<String> completed,
  ) {
    // Find first incomplete drawing; if all done, start from beginning (replay)
    String? targetId;
    for (final id in drawingIds) {
      if (!completed.contains(id)) {
        targetId = id;
        break;
      }
    }
    targetId ??= drawingIds.first;
    context.go('/drawing/$targetId');
  }
}
