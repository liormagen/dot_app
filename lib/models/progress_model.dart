enum DifficultyMode { easy, normal, hard, superHard }

DifficultyMode parseDifficultyMode(String? s) {
  switch (s) {
    case 'easy':
      return DifficultyMode.easy;
    case 'hard':
      return DifficultyMode.hard;
    case 'superHard':
      return DifficultyMode.superHard;
    default:
      return DifficultyMode.normal;
  }
}

class ProgressModel {
  const ProgressModel({
    this.completedDrawingIds = const {},
    this.selectedLanguage = 'en',
    this.onboardingComplete = false,
    this.musicEnabled = true,
    this.sfxEnabled = true,
    this.purchaseUnlocked = false,
    this.difficulty = DifficultyMode.normal,
    this.bestTimeMs = const {},
  });

  final Set<String> completedDrawingIds;
  final String selectedLanguage;
  final bool onboardingComplete;
  final bool musicEnabled;
  final bool sfxEnabled;
  final bool purchaseUnlocked;
  final DifficultyMode difficulty;
  final Map<String, int> bestTimeMs;

  static const ProgressModel initial = ProgressModel(
    completedDrawingIds: {},
    selectedLanguage: 'en',
    onboardingComplete: false,
    musicEnabled: true,
    sfxEnabled: true,
    purchaseUnlocked: false,
    difficulty: DifficultyMode.normal,
    bestTimeMs: {},
  );

  ProgressModel copyWith({
    Set<String>? completedDrawingIds,
    String? selectedLanguage,
    bool? onboardingComplete,
    bool? musicEnabled,
    bool? sfxEnabled,
    bool? purchaseUnlocked,
    DifficultyMode? difficulty,
    Map<String, int>? bestTimeMs,
  }) {
    return ProgressModel(
      completedDrawingIds: completedDrawingIds ?? this.completedDrawingIds,
      selectedLanguage: selectedLanguage ?? this.selectedLanguage,
      onboardingComplete: onboardingComplete ?? this.onboardingComplete,
      musicEnabled: musicEnabled ?? this.musicEnabled,
      sfxEnabled: sfxEnabled ?? this.sfxEnabled,
      purchaseUnlocked: purchaseUnlocked ?? this.purchaseUnlocked,
      difficulty: difficulty ?? this.difficulty,
      bestTimeMs: bestTimeMs ?? this.bestTimeMs,
    );
  }

  Map<String, dynamic> toJson() => {
        'completedDrawingIds': completedDrawingIds.toList(),
        'selectedLanguage': selectedLanguage,
        'onboardingComplete': onboardingComplete,
        'musicEnabled': musicEnabled,
        'sfxEnabled': sfxEnabled,
        'purchaseUnlocked': purchaseUnlocked,
        'difficulty': difficulty.name,
        'bestTimeMs': bestTimeMs,
      };

  factory ProgressModel.fromJson(Map<String, dynamic> json) {
    return ProgressModel(
      completedDrawingIds: (json['completedDrawingIds'] as List<dynamic>? ?? [])
          .map((e) => e as String)
          .toSet(),
      selectedLanguage: json['selectedLanguage'] as String? ?? 'en',
      onboardingComplete: json['onboardingComplete'] as bool? ?? false,
      musicEnabled: json['musicEnabled'] as bool? ?? true,
      sfxEnabled: json['sfxEnabled'] as bool? ?? true,
      purchaseUnlocked: json['purchaseUnlocked'] as bool? ?? false,
      difficulty: parseDifficultyMode(json['difficulty'] as String?),
      bestTimeMs: Map<String, int>.from(
          (json['bestTimeMs'] as Map? ?? {}).map(
              (k, v) => MapEntry(k as String, v as int))),
    );
  }
}
