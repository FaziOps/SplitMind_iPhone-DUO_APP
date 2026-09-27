import 'package:hive_ce/hive.dart';

/// Small key-value settings persisted in Hive.
class AppSettings {
  const AppSettings(this._box);

  static const boxName = 'settings';
  static const _onboardingComplete = 'onboardingComplete';
  static const _activeDocumentId = 'activeDocumentId';

  final Box<dynamic> _box;

  bool get onboardingComplete => _box.get(_onboardingComplete, defaultValue: false) as bool;
  Future<void> setOnboardingComplete() => _box.put(_onboardingComplete, true);

  String? get activeDocumentId => _box.get(_activeDocumentId) as String?;
  Future<void> setActiveDocumentId(String id) => _box.put(_activeDocumentId, id);
}
