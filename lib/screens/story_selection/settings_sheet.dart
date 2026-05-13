import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../l10n/app_localizations.dart';
import '../../models/progress_model.dart';
import '../../services/audio_service.dart';
import '../../services/progress_service.dart';
import '../../services/purchase_service.dart';

// ---------------------------------------------------------------------------
// Toca Boca design tokens (local)
// ---------------------------------------------------------------------------
const _kYellow = Color(0xFFF5C800);
const _kInk    = Color(0xFF1A1A2E);

class SettingsSheet extends ConsumerWidget {
  const SettingsSheet({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final progress = ref.watch(progressProvider);
    final audio = ref.read(audioServiceProvider);

    return DraggableScrollableSheet(
      expand: false,
      initialChildSize: 0.55,
      minChildSize: 0.4,
      maxChildSize: 0.85,
      builder: (context, scrollController) {
        return Container(
          decoration: const BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const SizedBox(height: 8),
              Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: Colors.grey.shade300,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              Expanded(
                child: ListView(
                  controller: scrollController,
                  padding: const EdgeInsets.symmetric(
                      horizontal: 24, vertical: 16),
                  children: [
                    Text(
                      AppLocalizations.of(context)!.settings,
                      style:
                          Theme.of(context).textTheme.headlineSmall?.copyWith(
                                fontWeight: FontWeight.bold,
                              ),
                    ),
                    const SizedBox(height: 24),
                    // Language selector
                    Text(
                      AppLocalizations.of(context)!.language,
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        _LangButton(
                          label: 'English',
                          code: 'en',
                          selected: progress.selectedLanguage == 'en',
                          onTap: () => ref
                              .read(progressProvider.notifier)
                              .setLanguage('en'),
                        ),
                        const SizedBox(width: 8),
                        _LangButton(
                          label: 'עברית',
                          code: 'he',
                          selected: progress.selectedLanguage == 'he',
                          onTap: () => ref
                              .read(progressProvider.notifier)
                              .setLanguage('he'),
                        ),
                        const SizedBox(width: 8),
                        _LangButton(
                          label: 'العربية',
                          code: 'ar',
                          selected: progress.selectedLanguage == 'ar',
                          onTap: () => ref
                              .read(progressProvider.notifier)
                              .setLanguage('ar'),
                        ),
                      ],
                    ),
                    const SizedBox(height: 24),
                    Text(
                      'Difficulty',
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                    const SizedBox(height: 8),
                    _DifficultySelector(
                      current: progress.difficulty,
                      onChanged: (mode) =>
                          ref.read(progressProvider.notifier).setDifficulty(mode),
                    ),
                    const SizedBox(height: 24),
                    // Music toggle
                    SwitchListTile(
                      title: Text(AppLocalizations.of(context)!.music),
                      value: progress.musicEnabled,
                      onChanged: (val) {
                        ref
                            .read(progressProvider.notifier)
                            .setMusicEnabled(val);
                        audio.setMusicEnabled(val);
                      },
                    ),
                    // SFX toggle
                    SwitchListTile(
                      title: Text(AppLocalizations.of(context)!.soundEffects),
                      value: progress.sfxEnabled,
                      onChanged: (val) {
                        ref
                            .read(progressProvider.notifier)
                            .setSfxEnabled(val);
                        audio.setSfxEnabled(val);
                      },
                    ),
                    const Divider(height: 32),
                    // Replay Onboarding
                    ListTile(
                      leading: const Icon(Icons.replay),
                      title: Text(AppLocalizations.of(context)!.replayOnboarding),
                      onTap: () async {
                        await ref
                            .read(progressProvider.notifier)
                            .resetOnboarding();
                        if (!context.mounted) return;
                        Navigator.of(context).pop();
                        context.go('/onboarding');
                      },
                    ),
                    // Unlock Full Access (hidden once purchased)
                    if (!progress.purchaseUnlocked)
                      ListTile(
                        leading: const Icon(Icons.lock_open),
                        title: Text(AppLocalizations.of(context)!.unlockFullAccess),
                        onTap: () {
                          ref.read(purchaseServiceProvider).buyFullAccess();
                        },
                      ),
                    // Restore Purchases
                    ListTile(
                      leading: const Icon(Icons.restore),
                      title: Text(AppLocalizations.of(context)!.restorePurchases),
                      onTap: () {
                        ref
                            .read(purchaseServiceProvider)
                            .restorePurchases();
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                              content: Text(AppLocalizations.of(context)!.restoringPurchases)),
                        );
                      },
                    ),
                    const Divider(height: 32),
                    Center(
                      child: Text(
                        AppLocalizations.of(context)!.version,
                        style: TextStyle(color: Colors.grey.shade500),
                      ),
                    ),
                    const SizedBox(height: 24),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

class _LangButton extends StatelessWidget {
  const _LangButton({
    required this.label,
    required this.code,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final String code;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: GestureDetector(
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          padding: const EdgeInsets.symmetric(vertical: 12),
          decoration: BoxDecoration(
            color: selected
                ? Theme.of(context).colorScheme.primary
                : Colors.grey.shade100,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: selected
                  ? Theme.of(context).colorScheme.primary
                  : Colors.grey.shade300,
              width: 2,
            ),
          ),
          alignment: Alignment.center,
          child: Text(
            label,
            style: TextStyle(
              color: selected ? Colors.white : Colors.black87,
              fontWeight: FontWeight.bold,
            ),
            textAlign: TextAlign.center,
          ),
        ),
      ),
    );
  }
}

class _DifficultySelector extends StatelessWidget {
  const _DifficultySelector({
    required this.current,
    required this.onChanged,
  });

  final DifficultyMode current;
  final void Function(DifficultyMode) onChanged;

  @override
  Widget build(BuildContext context) {
    const modes = [
      (DifficultyMode.easy,      'Easy',       Icons.sentiment_satisfied_rounded),
      (DifficultyMode.normal,    'Normal',     Icons.sentiment_neutral_rounded),
      (DifficultyMode.hard,      'Hard',       Icons.timer_rounded),
      (DifficultyMode.superHard, 'Super Hard', Icons.whatshot_rounded),
    ];
    return Wrap(
      spacing: 10,
      runSpacing: 10,
      children: [
        for (final (mode, label, icon) in modes)
          GestureDetector(
            onTap: () => onChanged(mode),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 180),
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              decoration: BoxDecoration(
                color: current == mode ? _kYellow : Colors.white,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(
                  color: _kInk,
                  width: current == mode ? 3 : 2,
                ),
                boxShadow: current == mode
                    ? const [BoxShadow(color: _kInk, blurRadius: 0, offset: Offset(3, 3))]
                    : const [],
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(icon, size: 20, color: _kInk),
                  const SizedBox(width: 8),
                  Text(
                    label,
                    style: const TextStyle(
                      fontFamily: 'Boogaloo',
                      fontSize: 16,
                      color: _kInk,
                      height: 1.0,
                    ),
                  ),
                ],
              ),
            ),
          ),
      ],
    );
  }
}
