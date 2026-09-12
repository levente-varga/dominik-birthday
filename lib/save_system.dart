import 'dart:convert';

import 'package:crypto/crypto.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Tracks all lifetime statistics for the gauntlet.
class Statistics {
  int totalRunsStarted;
  int totalDeaths;

  /// Per-stage completion count (stage number → count).
  /// Also used to compute adaptive difficulty (every 5 solves = easier).
  Map<int, int> gameCompletions;

  /// Per-stage loss count (stage number → count).
  Map<int, int> gameLosses;

  /// Map of achievement ID → status ('locked', 'unlocked', 'collected').
  Map<String, String> achievementStates;

  /// Map of achievement ID → whether its hint popup has ever been shown.
  Map<String, bool> achievementPopupsShown;

  /// Map of stage number → whether the anomaly version was encountered.
  Map<int, bool> encounteredAnomalies;

  /// Stage number of the most recent death (null if never died).
  int? lastStageLostAt;

  /// Correct secret number from the most recent Number Guesser active run.
  int? lastNumberGuesserTarget;

  /// Correct secret number from the most recent Number Guesser practice session.
  int? lastPracticeNumberGuesserTarget;

  /// Total time spent inside active runs (in seconds).
  int totalPlayTimeSeconds;

  /// Per-stage total time spent inside active runs (stage number → seconds).
  Map<int, int> gamePlayTimeSeconds;

  /// Total individual games completed across all runs.
  int totalGamesCompleted;

  /// Total lifetime tokens acquired across all runs.
  int totalTokensEarned;

  /// Total flawless Minesweeper completions (0 misplaced flags).
  int flawlessMinesweeperCompletions;

  /// Whether the statistics popup has ever been opened.
  bool hasOpenedStatistics;

  /// Whether the skill tree screen has ever been opened.
  bool hasOpenedSkillTree;

  /// Whether the practice mode info popup has ever been shown.
  bool hasSeenPracticeInfo;

  /// Map of key slot index -> whether the player has hovered over that slot on the main menu.
  Map<int, bool> hoveredKeySlots;

  /// Total literal word text picks in Stroop Test (selecting text word color instead of ink color).
  int stroopLiteralTextPicks;

  Statistics({
    this.totalRunsStarted = 0,
    this.totalDeaths = 0,
    this.totalPlayTimeSeconds = 0,
    this.totalGamesCompleted = 0,
    this.totalTokensEarned = 0,
    this.flawlessMinesweeperCompletions = 0,
    this.hasOpenedStatistics = false,
    this.hasOpenedSkillTree = false,
    this.hasSeenPracticeInfo = false,
    Map<int, bool>? hoveredKeySlots,
    this.stroopLiteralTextPicks = 0,
    this.lastNumberGuesserTarget,
    this.lastPracticeNumberGuesserTarget,
    Map<int, int>? gamePlayTimeSeconds,
    Map<int, int>? gameCompletions,
    Map<int, int>? gameLosses,
    Map<String, String>? achievementStates,
    Map<String, bool>? achievementPopupsShown,
    Map<int, bool>? encounteredAnomalies,
    this.lastStageLostAt,
  }) : hoveredKeySlots = hoveredKeySlots ?? {},
       gameCompletions = gameCompletions ?? {},
       gamePlayTimeSeconds = gamePlayTimeSeconds ?? {},
       gameLosses = gameLosses ?? {},
       achievementStates = achievementStates ?? {},
       achievementPopupsShown = achievementPopupsShown ?? {},
       encounteredAnomalies = encounteredAnomalies ?? {};

  Map<String, dynamic> toJson() => {
    'totalRunsStarted': totalRunsStarted,
    'totalDeaths': totalDeaths,
    'totalPlayTimeSeconds': totalPlayTimeSeconds,
    'totalGamesCompleted': totalGamesCompleted,
    'totalTokensEarned': totalTokensEarned,
    'flawlessMinesweeperCompletions': flawlessMinesweeperCompletions,
    'hasOpenedStatistics': hasOpenedStatistics,
    'hasOpenedSkillTree': hasOpenedSkillTree,
    'hasSeenPracticeInfo': hasSeenPracticeInfo,
    'hoveredKeySlots': hoveredKeySlots.map((k, v) => MapEntry(k.toString(), v)),
    'stroopLiteralTextPicks': stroopLiteralTextPicks,
    'gamePlayTimeSeconds': gamePlayTimeSeconds.map(
      (k, v) => MapEntry(k.toString(), v),
    ),
    'gameCompletions': gameCompletions.map(
      (k, v) => MapEntry(k.toString(), v),
    ),
    'gameLosses': gameLosses.map((k, v) => MapEntry(k.toString(), v)),
    'achievementStates': achievementStates,
    'achievementPopupsShown': achievementPopupsShown,
    'encounteredAnomalies': encounteredAnomalies.map(
      (k, v) => MapEntry(k.toString(), v),
    ),
    'lastStageLostAt': lastStageLostAt,
    'lastNumberGuesserTarget': lastNumberGuesserTarget,
    'lastPracticeNumberGuesserTarget': lastPracticeNumberGuesserTarget,
  };

  factory Statistics.fromJson(Map<String, dynamic> json) {
    final hoveredSlots =
        (json['hoveredKeySlots'] as Map<String, dynamic>?)?.map(
          (k, v) => MapEntry(int.parse(k), v as bool),
        ) ??
        {};
    if (json['hasHoveredFirstKeySlot'] == true) {
      hoveredSlots[0] = true;
    }

    final playTimeRaw =
        (json['gamePlayTimeSeconds'] ?? json['minigamePlayTimeSeconds'])
            as Map<String, dynamic>?;
    final completionsRaw =
        (json['gameCompletions'] ?? json['minigameCompletions'])
            as Map<String, dynamic>?;
    final lossesRaw =
        (json['gameLosses'] ?? json['minigameLosses'])
            as Map<String, dynamic>?;

    final rawAchievements =
        (json['achievementStates'] as Map<String, dynamic>?)?.map(
          (k, v) => MapEntry(k, v as String),
        ) ??
        {};
    if (rawAchievements.containsKey('minigames_play_all')) {
      rawAchievements['games_play_all'] = rawAchievements.remove('minigames_play_all')!;
    }
    if (rawAchievements.containsKey('minigames_clear_500')) {
      rawAchievements['games_clear_500'] = rawAchievements.remove('minigames_clear_500')!;
    }

    final rawPopups =
        (json['achievementPopupsShown'] as Map<String, dynamic>?)?.map(
          (k, v) => MapEntry(k, v as bool),
        ) ??
        {};
    if (rawPopups.containsKey('minigames_play_all')) {
      rawPopups['games_play_all'] = rawPopups.remove('minigames_play_all')!;
    }
    if (rawPopups.containsKey('minigames_clear_500')) {
      rawPopups['games_clear_500'] = rawPopups.remove('minigames_clear_500')!;
    }

    return Statistics(
      totalRunsStarted: json['totalRunsStarted'] as int? ?? 0,
      totalDeaths: json['totalDeaths'] as int? ?? 0,
      totalPlayTimeSeconds: json['totalPlayTimeSeconds'] as int? ?? 0,
      totalGamesCompleted:
          (json['totalGamesCompleted'] ?? json['totalMinigamesCompleted'])
              as int? ??
          0,
      totalTokensEarned: json['totalTokensEarned'] as int? ?? 0,
      flawlessMinesweeperCompletions:
          json['flawlessMinesweeperCompletions'] as int? ?? 0,
      hasOpenedStatistics: json['hasOpenedStatistics'] as bool? ?? false,
      hasOpenedSkillTree: json['hasOpenedSkillTree'] as bool? ?? false,
      hasSeenPracticeInfo: json['hasSeenPracticeInfo'] as bool? ?? false,
      hoveredKeySlots: hoveredSlots,
      stroopLiteralTextPicks: json['stroopLiteralTextPicks'] as int? ?? 0,
      lastNumberGuesserTarget: json['lastNumberGuesserTarget'] as int?,
      lastPracticeNumberGuesserTarget:
          json['lastPracticeNumberGuesserTarget'] as int?,
      gamePlayTimeSeconds:
          playTimeRaw?.map(
            (k, v) => MapEntry(int.parse(k), v as int),
          ) ??
          {},
      gameCompletions:
          completionsRaw?.map(
            (k, v) => MapEntry(int.parse(k), v as int),
          ) ??
          {},
      gameLosses:
          lossesRaw?.map(
            (k, v) => MapEntry(int.parse(k), v as int),
          ) ??
          {},
      achievementStates: rawAchievements,
      achievementPopupsShown: rawPopups,
      encounteredAnomalies:
          (json['encounteredAnomalies'] as Map<String, dynamic>?)?.map(
            (k, v) => MapEntry(int.parse(k), v as bool),
          ) ??
          {},
      lastStageLostAt: json['lastStageLostAt'] as int?,
    );
  }
}

/// Wraps [SharedPreferences] in a tamper-proof, HMAC-SHA256 signed and encrypted vault.
class SaveSystem {
  static const _saveVaultKey = 'dominik_save_vault_v1';
  static const _salt = 'L@c1_B1rthd@y_2026_V@ult_S3cr3t_K3y_#998244353!';

  late final SharedPreferences _prefs;
  Map<String, dynamic>? _cachedData;

  /// Must be called once before any load/save operations.
  Future<void> init() async {
    _prefs = await SharedPreferences.getInstance();
    _loadVault();
  }

  void _loadVault() {
    final rawVault = _prefs.getString(_saveVaultKey);
    if (rawVault == null) {
      _cachedData = <String, dynamic>{};
      return;
    }

    try {
      final envelope = jsonDecode(rawVault) as Map<String, dynamic>;
      final payload = envelope['data'] as String?;
      final signature = envelope['sig'] as String?;

      if (payload == null || signature == null) {
        _handleTamper();
        return;
      }

      // Verify HMAC-SHA256 signature
      final expectedSig = _computeHmac(payload);
      if (expectedSig != signature) {
        _handleTamper();
        return;
      }

      // Decrypt / descramble payload
      final decodedJson = _descramble(payload);
      _cachedData = jsonDecode(decodedJson) as Map<String, dynamic>;
    } catch (e) {
      _handleTamper();
    }
  }

  void _handleTamper() {
    _cachedData = <String, dynamic>{};
  }

  static String _computeHmac(String data) {
    final key = utf8.encode(_salt);
    final bytes = utf8.encode(data);
    final hmac = Hmac(sha256, key);
    return hmac.convert(bytes).toString();
  }

  static String _scramble(String plaintext) {
    final bytes = utf8.encode(plaintext);
    final saltBytes = utf8.encode(_salt);
    final scrambled = List<int>.generate(
      bytes.length,
      (i) => bytes[i] ^ saltBytes[i % saltBytes.length],
    );
    return base64Encode(scrambled);
  }

  static String _descramble(String ciphertext) {
    final bytes = base64Decode(ciphertext);
    final saltBytes = utf8.encode(_salt);
    final plainBytes = List<int>.generate(
      bytes.length,
      (i) => bytes[i] ^ saltBytes[i % saltBytes.length],
    );
    return utf8.decode(plainBytes);
  }

  Future<void> _persistVault() async {
    final jsonStr = jsonEncode(_cachedData ?? {});
    final scrambledPayload = _scramble(jsonStr);
    final sig = _computeHmac(scrambledPayload);

    final envelope = jsonEncode({'data': scrambledPayload, 'sig': sig});

    await _prefs.setString(_saveVaultKey, envelope);
  }

  /// Returns a 15-element list of nullable strings (null = not yet unlocked).
  List<String?> loadUnlockedKeyChars() {
    final raw = _cachedData?['unlockedKeyChars'] as List<dynamic>?;
    if (raw == null) return List<String?>.filled(15, null);
    return raw.map((e) => e as String?).toList();
  }

  Future<void> saveUnlockedKeyChars(List<String?> chars) async {
    _cachedData ??= {};
    _cachedData!['unlockedKeyChars'] = chars;
    await _persistVault();
  }

  Statistics loadStatistics() {
    final raw = _cachedData?['statistics'] as Map<String, dynamic>?;
    if (raw == null) return Statistics();
    return Statistics.fromJson(raw);
  }

  Future<void> saveStatistics(Statistics stats) async {
    _cachedData ??= {};
    _cachedData!['statistics'] = stats.toJson();
    await _persistVault();
  }

  /// Load current token currency balance.
  int loadTokens() {
    return _cachedData?['tokens'] as int? ?? 0;
  }

  /// Persist current token currency balance.
  Future<void> saveTokens(int tokens) async {
    _cachedData ??= {};
    _cachedData!['tokens'] = tokens;
    await _persistVault();
  }

  /// Load list of unlocked skill node IDs.
  List<String> loadUnlockedSkills() {
    final list = _cachedData?['unlockedSkills'] as List<dynamic>?;
    return list?.map((e) => e as String).toList() ?? <String>[];
  }

  /// Persist list of unlocked skill node IDs.
  Future<void> saveUnlockedSkills(List<String> skills) async {
    _cachedData ??= {};
    _cachedData!['unlockedSkills'] = skills;
    await _persistVault();
  }

  /// Load map of skill node levels (id -> level).
  Map<String, int> loadSkillLevels() {
    final raw = _cachedData?['skillLevels'] as Map<String, dynamic>?;
    if (raw == null) return <String, int>{};
    return raw.map((k, v) => MapEntry(k, v as int));
  }

  /// Persist map of skill node levels.
  Future<void> saveSkillLevels(Map<String, int> levels) async {
    _cachedData ??= {};
    _cachedData!['skillLevels'] = levels;
    await _persistVault();
  }

  /// Wipes all saved data (for debug / reset).
  Future<void> clearAll() async {
    _cachedData = <String, dynamic>{};
    await _prefs.clear();
  }
}
