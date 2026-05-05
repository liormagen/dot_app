import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../models/progress_model.dart';

// ---------------------------------------------------------------------------
// Keys
// ---------------------------------------------------------------------------
const _kCompletedDrawings = 'completed_drawings';
const _kLanguage = 'language';
const _kOnboarding = 'onboarding_complete';
const _kMusic = 'music_enabled';
const _kSfx = 'sfx_enabled';
const _kPurchase = 'purchase_unlocked';

// ---------------------------------------------------------------------------
// Service
// ---------------------------------------------------------------------------
class ProgressService {
  SharedPreferences? _prefs;

  Future<void> init() async {
    _prefs = await SharedPreferences.getInstance();
  }

  ProgressModel load() {
    final prefs = _prefs;
    if (prefs == null) return ProgressModel.initial;

    final completedList = prefs.getStringList(_kCompletedDrawings) ?? [];
    return ProgressModel(
      completedDrawingIds: completedList.toSet(),
      selectedLanguage: prefs.getString(_kLanguage) ?? 'en',
      onboardingComplete: prefs.getBool(_kOnboarding) ?? false,
      musicEnabled: prefs.getBool(_kMusic) ?? true,
      sfxEnabled: prefs.getBool(_kSfx) ?? true,
      purchaseUnlocked: prefs.getBool(_kPurchase) ?? false,
    );
  }

  Future<void> save(ProgressModel model) async {
    final prefs = _prefs;
    if (prefs == null) return;
    await prefs.setStringList(
        _kCompletedDrawings, model.completedDrawingIds.toList());
    await prefs.setString(_kLanguage, model.selectedLanguage);
    await prefs.setBool(_kOnboarding, model.onboardingComplete);
    await prefs.setBool(_kMusic, model.musicEnabled);
    await prefs.setBool(_kSfx, model.sfxEnabled);
    await prefs.setBool(_kPurchase, model.purchaseUnlocked);
  }

  Future<void> markDrawingComplete(String drawingId) async {
    final prefs = _prefs;
    if (prefs == null) return;
    final existing =
        (prefs.getStringList(_kCompletedDrawings) ?? []).toSet();
    existing.add(drawingId);
    await prefs.setStringList(_kCompletedDrawings, existing.toList());
  }

  Future<void> setLanguage(String lang) async =>
      _prefs?.setString(_kLanguage, lang);

  Future<void> setOnboardingComplete(bool value) async =>
      _prefs?.setBool(_kOnboarding, value);

  Future<void> setMusicEnabled(bool value) async =>
      _prefs?.setBool(_kMusic, value);

  Future<void> setSfxEnabled(bool value) async =>
      _prefs?.setBool(_kSfx, value);

  Future<void> setPurchaseUnlocked(bool value) async =>
      _prefs?.setBool(_kPurchase, value);
}

// ---------------------------------------------------------------------------
// StateNotifier
// ---------------------------------------------------------------------------
class ProgressNotifier extends StateNotifier<ProgressModel> {
  ProgressNotifier(this._service) : super(ProgressModel.initial) {
    state = _service.load();
  }

  final ProgressService _service;

  Future<void> markDrawingComplete(String drawingId) async {
    await _service.markDrawingComplete(drawingId);
    state = state.copyWith(
      completedDrawingIds: {...state.completedDrawingIds, drawingId},
    );
  }

  Future<void> setLanguage(String lang) async {
    await _service.setLanguage(lang);
    state = state.copyWith(selectedLanguage: lang);
  }

  Future<void> completeOnboarding() async {
    await _service.setOnboardingComplete(true);
    state = state.copyWith(onboardingComplete: true);
  }

  Future<void> resetOnboarding() async {
    await _service.setOnboardingComplete(false);
    state = state.copyWith(onboardingComplete: false);
  }

  Future<void> setMusicEnabled(bool value) async {
    await _service.setMusicEnabled(value);
    state = state.copyWith(musicEnabled: value);
  }

  Future<void> setSfxEnabled(bool value) async {
    await _service.setSfxEnabled(value);
    state = state.copyWith(sfxEnabled: value);
  }

  Future<void> setPurchaseUnlocked(bool value) async {
    await _service.setPurchaseUnlocked(value);
    state = state.copyWith(purchaseUnlocked: value);
  }
}

// ---------------------------------------------------------------------------
// Providers
// ---------------------------------------------------------------------------
final progressServiceProvider = Provider<ProgressService>(
  (_) => throw UnimplementedError('Override progressServiceProvider'),
);

final progressProvider =
    StateNotifierProvider<ProgressNotifier, ProgressModel>(
  (ref) => ProgressNotifier(ref.watch(progressServiceProvider)),
);
