class BuiltinSource {
  const BuiltinSource._(this.key, this.label);

  final String key;
  final String label;

  static const cet4 = BuiltinSource._('cet4', '四级');
  static const cet6 = BuiltinSource._('cet6', '六级');
  static const kaoyan = BuiltinSource._('kaoyan', '考研');
  static const ielts = BuiltinSource._('ielts', '雅思');
  static const toefl = BuiltinSource._('toefl', '托福');

  static const values = [cet4, cet6, kaoyan, ielts, toefl];

  static BuiltinSource fromKey(String key) {
    return values.firstWhere((source) => source.key == key, orElse: () => cet4);
  }
}

enum WordType { builtin, custom }

extension WordTypeX on WordType {
  String get key => this == WordType.builtin ? 'builtin' : 'custom';

  static WordType fromKey(String raw) {
    return raw == 'custom' ? WordType.custom : WordType.builtin;
  }
}

enum SessionMode { builtinLearn, builtinReview, customUnit }

class BuiltinWord {
  const BuiltinWord({
    this.id,
    required this.word,
    required this.meaning,
    required this.source,
  });

  final int? id;
  final String word;
  final String meaning;
  final BuiltinSource source;

  factory BuiltinWord.fromMap(Map<String, Object?> map) {
    return BuiltinWord(
      id: map['id'] as int?,
      word: map['word'] as String,
      meaning: map['meaning'] as String,
      source: BuiltinSource.fromKey(map['source'] as String),
    );
  }

  Map<String, Object?> toMap() {
    return {'id': id, 'word': word, 'meaning': meaning, 'source': source.key};
  }
}

class OxfordEntry {
  const OxfordEntry({this.id, required this.word, required this.meaning});

  final int? id;
  final String word;
  final String meaning;

  factory OxfordEntry.fromMap(Map<String, Object?> map) {
    return OxfordEntry(
      id: map['id'] as int?,
      word: map['word'] as String,
      meaning: map['meaning'] as String,
    );
  }
}

class LearningProgress {
  const LearningProgress({
    this.id,
    required this.wordId,
    required this.wordType,
    required this.errorCount,
    required this.lastReviewTime,
    required this.nextReviewTime,
    required this.consecutiveCorrect,
    required this.isRemoved,
  });

  final int? id;
  final int wordId;
  final WordType wordType;
  final int errorCount;
  final int lastReviewTime;
  final int nextReviewTime;
  final int consecutiveCorrect;
  final bool isRemoved;

  factory LearningProgress.fromMap(Map<String, Object?> map) {
    return LearningProgress(
      id: map['id'] as int?,
      wordId: map['word_id'] as int,
      wordType: WordTypeX.fromKey(map['word_type'] as String),
      errorCount: map['error_count'] as int? ?? 0,
      lastReviewTime: map['last_review_time'] as int? ?? 0,
      nextReviewTime: map['next_review_time'] as int? ?? 0,
      consecutiveCorrect: map['consecutive_correct'] as int? ?? 0,
      isRemoved: (map['is_removed'] as int? ?? 0) == 1,
    );
  }

  static LearningProgress initialBuiltin(int wordId) {
    return LearningProgress(
      wordId: wordId,
      wordType: WordType.builtin,
      errorCount: 0,
      lastReviewTime: 0,
      nextReviewTime: 0,
      consecutiveCorrect: 0,
      isRemoved: false,
    );
  }

  Map<String, Object?> toMap() {
    return {
      'id': id,
      'word_id': wordId,
      'word_type': wordType.key,
      'error_count': errorCount,
      'last_review_time': lastReviewTime,
      'next_review_time': nextReviewTime,
      'consecutive_correct': consecutiveCorrect,
      'is_removed': isRemoved ? 1 : 0,
    };
  }
}

class UserProfile {
  const UserProfile({required this.nickname, this.avatarPath});

  final String nickname;
  final String? avatarPath;

  factory UserProfile.fromMap(Map<String, Object?> map) {
    return UserProfile(
      nickname: map['nickname'] as String? ?? 'Nova Learner',
      avatarPath: map['avatar_path'] as String?,
    );
  }

  Map<String, Object?> toMap() {
    return {'nickname': nickname, 'avatar_path': avatarPath};
  }

  UserProfile copyWith({
    String? nickname,
    String? avatarPath,
    bool clearAvatar = false,
  }) {
    return UserProfile(
      nickname: nickname ?? this.nickname,
      avatarPath: clearAvatar ? null : (avatarPath ?? this.avatarPath),
    );
  }
}

class BuiltinStats {
  const BuiltinStats({
    required this.total,
    required this.active,
    required this.due,
    required this.mastered,
  });

  final int total;
  final int active;
  final int due;
  final int mastered;

  double get completionRatio {
    if (total == 0) {
      return 0;
    }
    return mastered / total;
  }
}

class CustomDictionarySummary {
  const CustomDictionarySummary({
    required this.id,
    required this.name,
    required this.unitCount,
    required this.wordCount,
  });

  final int id;
  final String name;
  final int unitCount;
  final int wordCount;
}

class CustomUnitSummary {
  const CustomUnitSummary({
    required this.id,
    required this.dictId,
    required this.name,
    required this.wordCount,
    required this.previewWords,
  });

  final int id;
  final int dictId;
  final String name;
  final int wordCount;
  final List<String> previewWords;
}

class CustomWordDraft {
  const CustomWordDraft({this.id, required this.word, required this.meaning});

  final int? id;
  final String word;
  final String meaning;

  CustomWordDraft copyWith({int? id, String? word, String? meaning}) {
    return CustomWordDraft(
      id: id ?? this.id,
      word: word ?? this.word,
      meaning: meaning ?? this.meaning,
    );
  }
}

class StudyEntry {
  const StudyEntry({
    required this.id,
    required this.wordType,
    required this.word,
    required this.meaning,
    required this.progress,
  });

  final int id;
  final WordType wordType;
  final String word;
  final String meaning;
  final LearningProgress progress;
}

class SessionSummary {
  const SessionSummary({
    required this.totalSeen,
    required this.correctCount,
    required this.wrongCount,
    required this.topWrongWords,
  });

  final int totalSeen;
  final int correctCount;
  final int wrongCount;
  final List<MapEntry<String, int>> topWrongWords;
}
