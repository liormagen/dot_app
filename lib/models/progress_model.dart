enum DifficultyMode { easy, normal, hard, superHard }

class ProgressModel {
  const ProgressModel({
    required this.completedDrawingIds,
    required this.selectedLanguage,
    required this.onboardingComplete,
    required this.musicEnabled,
    required this.sfxEnabled,
    required this.purchaseUnlocked,
    this.difficulty = DifficultyMode.normal,
  });

  final Set<String> completedDrawingIds;
  final String selectedLanguage;
  final bool onboardingComplete;
  final bool musicEnabled;
  final bool sfxEnabled;
  final bool purchaseUnlocked;
  final DifficultyMode difficulty;

  static const ProgressModel initial = ProgressModel(
    completedDrawingIds: {},
    selectedLanguage: 'en',
    onboardingComplete: false,
    musicEnabled: true,
    sfxEnabled: true,
    purchaseUnlocked: false,
    difficulty: DifficultyMode.normal,
  );

  ProgressModel copyWith({
    Set<String>? completedDrawingIds,
    String? selectedLanguage,
    bool? onboardingComplete,
    bool? musicEnabled,
    bool? sfxEnabled,
    bool? purchaseUnlocked,
    DifficultyMode? difficulty,
  }) {
    return ProgressModel(
      completedDrawingIds: completedDrawingIds ?? this.completedDrawingIds,
      selectedLanguage: selectedLanguage ?? this.selectedLanguage,
      onboardingComplete: onboardingComplete ?? this.onboardingComplete,
      musicEnabled: musicEnabled ?? this.musicEnabled,
      sfxEnabled: sfxEnabled ?? this.sfxEnabled,
      purchaseUnlocked: purchaseUnlocked ?? this.purchaseUnlocked,
      difficulty: difficulty ?? this.difficulty,
    );
  }
}
