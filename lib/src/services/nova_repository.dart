import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:path/path.dart' as p;
import 'package:sqflite/sqflite.dart';

import '../models/entities.dart';

typedef ImportProgressCallback = void Function(ImportProgress update);

class ImportProgress {
  const ImportProgress({
    required this.progress,
    required this.message,
  });

  final double progress;
  final String message;
}

class NovaRepository {
  static const int _databaseVersion = 2;
  static const int _batchChunkSize = 500;
  static const String _seedDataVersionKey = 'seed_data_version';
  static const String _seedDataVersion = '20260328_common_lookup_v2';
  static const String _prefersLightThemeKey = 'prefers_light_theme';

  Database? _database;
  Future<void>? _initFuture;
  Future<void> _writeQueue = Future.value();

  Database get db => _database!;

  Future<void> init() async {
    if (_database != null) {
      return;
    }
    if (_initFuture != null) {
      return _initFuture!;
    }

    final future = _openDatabaseOnce();
    _initFuture = future;
    try {
      await future;
    } finally {
      if (identical(_initFuture, future)) {
        _initFuture = null;
      }
    }
  }

  Future<void> _openDatabaseOnce() async {
    if (_database != null) {
      return;
    }

    final path = kIsWeb
        ? 'novaenglish.db'
        : p.join(await getDatabasesPath(), 'novaenglish.db');

    _database = await openDatabase(
      path,
      version: _databaseVersion,
      onConfigure: (database) async {
        await database.execute('PRAGMA foreign_keys = ON');
        await database.execute('PRAGMA busy_timeout = 5000');
      },
      onCreate: (database, version) async {
        await _createTables(database);
        await _seedBuiltinData(database);
        await _seedOxfordData(database);
        await database.insert('user_profile', {
          'id': 1,
          'nickname': 'Nova Learner',
          'avatar_path': null,
        });
        await _setMetaValue(database, _seedDataVersionKey, _seedDataVersion);
      },
      onUpgrade: (database, oldVersion, newVersion) async {
        if (oldVersion < 2) {
          await database.execute('''
            CREATE TABLE IF NOT EXISTS app_meta (
              key TEXT PRIMARY KEY,
              value TEXT NOT NULL
            )
          ''');
          await database.execute('''
            CREATE UNIQUE INDEX IF NOT EXISTS idx_builtin_dict_source_word
            ON builtin_dict(source, word)
          ''');
          await database.execute('''
            CREATE UNIQUE INDEX IF NOT EXISTS idx_oxford_dict_word
            ON oxford_dict(word)
          ''');
        }
      },
    );

    await _ensureSeedData();
  }

  Future<T> _runSerializedWrite<T>(Future<T> Function() action) {
    final completer = Completer<T>();
    _writeQueue = _writeQueue
        .catchError((Object _) {})
        .then((_) async {
          try {
            completer.complete(await action());
          } catch (error, stackTrace) {
            completer.completeError(error, stackTrace);
          }
        });
    return completer.future;
  }

  Future<void> _createTables(Database database) async {
    await database.execute('''
      CREATE TABLE builtin_dict (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        word TEXT NOT NULL,
        meaning TEXT NOT NULL,
        source TEXT NOT NULL
      )
    ''');
    await database.execute('''
      CREATE TABLE oxford_dict (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        word TEXT NOT NULL,
        meaning TEXT NOT NULL
      )
    ''');
    await database.execute('''
      CREATE TABLE custom_dict (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        name TEXT NOT NULL UNIQUE
      )
    ''');
    await database.execute('''
      CREATE TABLE unit (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        dict_id INTEGER NOT NULL,
        name TEXT NOT NULL,
        FOREIGN KEY(dict_id) REFERENCES custom_dict(id) ON DELETE CASCADE
      )
    ''');
    await database.execute('''
      CREATE TABLE custom_word (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        unit_id INTEGER NOT NULL,
        word TEXT NOT NULL,
        meaning TEXT NOT NULL,
        FOREIGN KEY(unit_id) REFERENCES unit(id) ON DELETE CASCADE
      )
    ''');
    await database.execute('''
      CREATE TABLE learning_progress (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        word_id INTEGER NOT NULL,
        word_type TEXT NOT NULL,
        error_count INTEGER NOT NULL DEFAULT 0,
        last_review_time INTEGER NOT NULL DEFAULT 0,
        next_review_time INTEGER NOT NULL DEFAULT 0,
        consecutive_correct INTEGER NOT NULL DEFAULT 0,
        is_removed INTEGER NOT NULL DEFAULT 0
      )
    ''');
    await database.execute('''
      CREATE UNIQUE INDEX idx_learning_progress_word
      ON learning_progress(word_id, word_type)
    ''');
    await database.execute('''
      CREATE UNIQUE INDEX idx_builtin_dict_source_word
      ON builtin_dict(source, word)
    ''');
    await database.execute('''
      CREATE UNIQUE INDEX idx_oxford_dict_word
      ON oxford_dict(word)
    ''');
    await database.execute('''
      CREATE TABLE user_profile (
        id INTEGER PRIMARY KEY,
        nickname TEXT NOT NULL,
        avatar_path TEXT
      )
    ''');
    await database.execute('''
      CREATE TABLE app_meta (
        key TEXT PRIMARY KEY,
        value TEXT NOT NULL
      )
    ''');
  }

  Future<void> _seedBuiltinData(Database database) async {
    final raw = await rootBundle.loadString('assets/data/builtin_words.json');
    final items = (jsonDecode(raw) as List<dynamic>)
        .map((item) => Map<String, dynamic>.from(item as Map))
        .toList();

    final batch = database.batch();
    for (final item in items) {
      batch.insert('builtin_dict', {
        'word': item['word'],
        'meaning': item['meaning'],
        'source': item['source'],
      });
    }
    await batch.commit(noResult: true);

    final inserted = await database.query('builtin_dict', columns: ['id']);
    final progressBatch = database.batch();
    for (final item in inserted) {
      final wordId = item['id'] as int;
      progressBatch.insert(
        'learning_progress',
        LearningProgress.initialBuiltin(wordId).toMap(),
      );
    }
    await progressBatch.commit(noResult: true);
  }

  Future<void> _seedOxfordData(Database database) async {
    final raw = await rootBundle.loadString('assets/data/oxford_words.json');
    final items = (jsonDecode(raw) as List<dynamic>)
        .map((item) => Map<String, dynamic>.from(item as Map))
        .toList();

    final batch = database.batch();
    for (final item in items) {
      batch.insert('oxford_dict', {
        'word': item['word'],
        'meaning': item['meaning'],
      });
    }
    await batch.commit(noResult: true);
  }

  Future<void> _ensureSeedData() async {
    final currentVersion = await _getMetaValue(_seedDataVersionKey);
    if (currentVersion == _seedDataVersion) {
      return;
    }

    await _syncBuiltinData();
    await _syncOxfordData();
    await _setMetaValue(db, _seedDataVersionKey, _seedDataVersion);
  }

  Future<void> _syncBuiltinData() async {
    final raw = await rootBundle.loadString('assets/data/builtin_words.json');
    final items = (jsonDecode(raw) as List<dynamic>)
        .map((item) => Map<String, dynamic>.from(item as Map))
        .toList();

    final existingRows = await db.query(
      'builtin_dict',
      columns: ['id', 'word', 'meaning', 'source'],
    );
    final existingByKey = <String, Map<String, Object?>>{
      for (final row in existingRows)
        _builtinWordKey(
          source: row['source'] as String,
          word: row['word'] as String,
        ): row,
    };

    final batch = db.batch();
    for (final item in items) {
      final source = item['source'] as String? ?? '';
      final word = item['word'] as String? ?? '';
      final meaning = item['meaning'] as String? ?? '';
      if (source.isEmpty || word.isEmpty || meaning.isEmpty) {
        continue;
      }

      final key = _builtinWordKey(source: source, word: word);
      final existing = existingByKey[key];
      if (existing == null) {
        batch.insert('builtin_dict', {
          'word': word,
          'meaning': meaning,
          'source': source,
        });
        continue;
      }

      if ((existing['meaning'] as String? ?? '') != meaning) {
        batch.update(
          'builtin_dict',
          {'meaning': meaning},
          where: 'id = ?',
          whereArgs: [existing['id']],
        );
      }
    }
    await batch.commit(noResult: true);

    final builtinRows = await db.query('builtin_dict', columns: ['id']);
    final progressRows = await db.query(
      'learning_progress',
      columns: ['word_id'],
      where: 'word_type = ?',
      whereArgs: [WordType.builtin.key],
    );
    final progressIds = progressRows
        .map((row) => row['word_id'] as int)
        .toSet();

    final progressBatch = db.batch();
    for (final row in builtinRows) {
      final wordId = row['id'] as int;
      if (progressIds.contains(wordId)) {
        continue;
      }
      progressBatch.insert(
        'learning_progress',
        LearningProgress.initialBuiltin(wordId).toMap(),
      );
    }
    await progressBatch.commit(noResult: true);
  }

  Future<void> _syncOxfordData() async {
    final raw = await rootBundle.loadString('assets/data/oxford_words.json');
    final items = (jsonDecode(raw) as List<dynamic>)
        .map((item) => Map<String, dynamic>.from(item as Map))
        .toList();

    final existingRows = await db.query(
      'oxford_dict',
      columns: ['id', 'word', 'meaning'],
    );
    final existingByWord = <String, Map<String, Object?>>{
      for (final row in existingRows)
        _normalizedWord(row['word'] as String): row,
    };

    final batch = db.batch();
    for (final item in items) {
      final word = item['word'] as String? ?? '';
      final meaning = item['meaning'] as String? ?? '';
      if (word.isEmpty || meaning.isEmpty) {
        continue;
      }

      final existing = existingByWord[_normalizedWord(word)];
      if (existing == null) {
        batch.insert('oxford_dict', {'word': word, 'meaning': meaning});
        continue;
      }

      if ((existing['meaning'] as String? ?? '') != meaning) {
        batch.update(
          'oxford_dict',
          {'meaning': meaning},
          where: 'id = ?',
          whereArgs: [existing['id']],
        );
      }
    }
    await batch.commit(noResult: true);
  }

  Future<UserProfile> fetchProfile() async {
    final rows = await db.query(
      'user_profile',
      where: 'id = ?',
      whereArgs: [1],
      limit: 1,
    );
    if (rows.isEmpty) {
      return const UserProfile(nickname: 'Nova Learner');
    }
    return UserProfile.fromMap(rows.first);
  }

  Future<void> saveProfile(UserProfile profile) async {
    await _runSerializedWrite(
      () => db.insert('user_profile', {
        'id': 1,
        ...profile.toMap(),
      }, conflictAlgorithm: ConflictAlgorithm.replace),
    );
  }

  Future<bool> fetchPrefersLightTheme() async {
    final value = await _getMetaValue(_prefersLightThemeKey);
    return value == '1';
  }

  Future<void> savePrefersLightTheme(bool value) async {
    await _runSerializedWrite(
      () => _setMetaValue(db, _prefersLightThemeKey, value ? '1' : '0'),
    );
  }

  Future<BuiltinStats> fetchBuiltinStats(BuiltinSource source) async {
    final now = DateTime.now().millisecondsSinceEpoch;
    final total =
        Sqflite.firstIntValue(
          await db.rawQuery(
            'SELECT COUNT(*) FROM builtin_dict WHERE source = ?',
            [source.key],
          ),
        ) ??
        0;
    final active =
        Sqflite.firstIntValue(
          await db.rawQuery(
            '''
            SELECT COUNT(*)
            FROM builtin_dict b
            JOIN learning_progress p
              ON p.word_id = b.id
             AND p.word_type = ?
            WHERE b.source = ?
              AND p.is_removed = 0
            ''',
            [WordType.builtin.key, source.key],
          ),
        ) ??
        0;
    final due =
        Sqflite.firstIntValue(
          await db.rawQuery(
            '''
            SELECT COUNT(*)
            FROM builtin_dict b
            JOIN learning_progress p
              ON p.word_id = b.id
             AND p.word_type = ?
            WHERE b.source = ?
              AND p.is_removed = 0
              AND p.last_review_time > 0
              AND p.next_review_time > 0
              AND p.next_review_time <= ?
            ''',
            [WordType.builtin.key, source.key, now],
          ),
        ) ??
        0;

    return BuiltinStats(
      total: total,
      active: active,
      due: due,
      mastered: total - active,
    );
  }

  Future<List<StudyEntry>> startBuiltinSession({
    required BuiltinSource source,
    required bool reviewOnly,
  }) async {
    final rows = await db.rawQuery(
      '''
      SELECT
        b.id,
        b.word,
        b.meaning,
        '${WordType.builtin.key}' AS word_type,
        p.id AS progress_id,
        p.error_count,
        p.last_review_time,
        p.next_review_time,
        p.consecutive_correct,
        p.is_removed
      FROM builtin_dict b
      JOIN learning_progress p
        ON p.word_id = b.id
       AND p.word_type = ?
      WHERE b.source = ?
        AND p.is_removed = 0
        ${reviewOnly ? 'AND p.last_review_time > 0 AND p.next_review_time > 0 AND p.next_review_time <= ?' : ''}
      ORDER BY ${reviewOnly ? 'p.next_review_time ASC, p.error_count DESC' : 'RANDOM()'}
      LIMIT 20
      ''',
      [
        WordType.builtin.key,
        source.key,
        if (reviewOnly) DateTime.now().millisecondsSinceEpoch,
      ],
    );

    return rows.map(_mapStudyEntry).toList();
  }

  Future<List<StudyEntry>> startCustomUnitSession(int unitId) async {
    final rows = await db.rawQuery(
      '''
      SELECT
        w.id,
        w.word,
        w.meaning,
        '${WordType.custom.key}' AS word_type,
        p.id AS progress_id,
        COALESCE(p.error_count, 0) AS error_count,
        COALESCE(p.last_review_time, 0) AS last_review_time,
        COALESCE(p.next_review_time, 0) AS next_review_time,
        COALESCE(p.consecutive_correct, 0) AS consecutive_correct,
        COALESCE(p.is_removed, 0) AS is_removed
      FROM custom_word w
      LEFT JOIN learning_progress p
        ON p.word_id = w.id
       AND p.word_type = ?
      WHERE w.unit_id = ?
      ORDER BY RANDOM()
      ''',
      [WordType.custom.key, unitId],
    );

    return rows.map(_mapStudyEntry).toList();
  }

  StudyEntry _mapStudyEntry(Map<String, Object?> row) {
    final wordType = WordTypeX.fromKey(row['word_type'] as String);
    return StudyEntry(
      id: row['id'] as int,
      wordType: wordType,
      word: row['word'] as String,
      meaning: row['meaning'] as String,
      progress: LearningProgress(
        id: row['progress_id'] as int?,
        wordId: row['id'] as int,
        wordType: wordType,
        errorCount: row['error_count'] as int? ?? 0,
        lastReviewTime: row['last_review_time'] as int? ?? 0,
        nextReviewTime: row['next_review_time'] as int? ?? 0,
        consecutiveCorrect: row['consecutive_correct'] as int? ?? 0,
        isRemoved: (row['is_removed'] as int? ?? 0) == 1,
      ),
    );
  }

  Future<void> applyBuiltinResult(StudyEntry entry, bool remembered) async {
    final progress = entry.progress;
    final now = DateTime.now().millisecondsSinceEpoch;

    final Map<String, Object?> update;
    if (remembered) {
      final nextCorrect = (progress.consecutiveCorrect + 1).clamp(0, 3);
      final nextDays = nextCorrect <= 1 ? 1 : (nextCorrect == 2 ? 2 : 4);
      update = {
        'word_id': entry.id,
        'word_type': WordType.builtin.key,
        'error_count': progress.errorCount,
        'last_review_time': now,
        'next_review_time': now + Duration(days: nextDays).inMilliseconds,
        'consecutive_correct': nextCorrect,
        'is_removed': nextCorrect >= 3 ? 1 : 0,
      };
    } else {
      update = {
        'word_id': entry.id,
        'word_type': WordType.builtin.key,
        'error_count': progress.errorCount + 1,
        'last_review_time': now,
        'next_review_time': now + const Duration(days: 1).inMilliseconds,
        'consecutive_correct': 0,
        'is_removed': 0,
      };
    }

    await _runSerializedWrite(
      () => db.insert(
        'learning_progress',
        update,
        conflictAlgorithm: ConflictAlgorithm.replace,
      ),
    );
  }

  Future<void> applyCustomResult(StudyEntry entry, bool remembered) async {
    final now = DateTime.now().millisecondsSinceEpoch;
    final currentErrors = entry.progress.errorCount;
    await _runSerializedWrite(
      () => db.insert('learning_progress', {
        'word_id': entry.id,
        'word_type': WordType.custom.key,
        'error_count': remembered ? currentErrors : currentErrors + 1,
        'last_review_time': now,
        'next_review_time': 0,
        'consecutive_correct': remembered ? 1 : 0,
        'is_removed': 0,
      }, conflictAlgorithm: ConflictAlgorithm.replace),
    );
  }

  Future<List<CustomDictionarySummary>> fetchCustomDictionaries() async {
    final rows = await db.rawQuery('''
      SELECT
        d.id,
        d.name,
        COUNT(DISTINCT u.id) AS unit_count,
        COUNT(w.id) AS word_count
      FROM custom_dict d
      LEFT JOIN unit u ON u.dict_id = d.id
      LEFT JOIN custom_word w ON w.unit_id = u.id
      GROUP BY d.id
      ORDER BY d.id DESC
    ''');

    return rows
        .map(
          (row) => CustomDictionarySummary(
            id: row['id'] as int,
            name: row['name'] as String,
            unitCount: row['unit_count'] as int? ?? 0,
            wordCount: row['word_count'] as int? ?? 0,
          ),
        )
        .toList();
  }

  Future<void> addCustomDictionary(String name) async {
    await _runSerializedWrite(
      () => db.insert('custom_dict', {'name': name.trim()}),
    );
  }

  Future<void> deleteCustomDictionary(int id) async {
    await _runSerializedWrite(
      () => db.delete('custom_dict', where: 'id = ?', whereArgs: [id]),
    );
  }

  Future<List<CustomUnitSummary>> fetchUnits(int dictionaryId) async {
    final rows = await db.query(
      'unit',
      where: 'dict_id = ?',
      whereArgs: [dictionaryId],
      orderBy: 'id DESC',
    );

    final units = <CustomUnitSummary>[];
    for (final row in rows) {
      final unitId = row['id'] as int;
      final previewRows = await db.query(
        'custom_word',
        columns: ['word'],
        where: 'unit_id = ?',
        whereArgs: [unitId],
        limit: 5,
      );
      final count =
          Sqflite.firstIntValue(
            await db.rawQuery(
              'SELECT COUNT(*) FROM custom_word WHERE unit_id = ?',
              [unitId],
            ),
          ) ??
          0;
      units.add(
        CustomUnitSummary(
          id: unitId,
          dictId: dictionaryId,
          name: row['name'] as String,
          wordCount: count,
          previewWords: previewRows
              .map((item) => item['word'] as String)
              .toList(),
        ),
      );
    }
    return units;
  }

  Future<void> addUnit({
    required int dictionaryId,
    required String name,
  }) async {
    await _runSerializedWrite(
      () => db.insert('unit', {'dict_id': dictionaryId, 'name': name.trim()}),
    );
  }

  Future<void> deleteUnit(int unitId) async {
    await _runSerializedWrite(
      () => db.delete('unit', where: 'id = ?', whereArgs: [unitId]),
    );
  }

  Future<List<CustomWordDraft>> fetchUnitWords(int unitId) async {
    final rows = await db.query(
      'custom_word',
      where: 'unit_id = ?',
      whereArgs: [unitId],
      orderBy: 'id ASC',
    );
    return rows
        .map(
          (row) => CustomWordDraft(
            id: row['id'] as int,
            word: row['word'] as String,
            meaning: row['meaning'] as String,
          ),
        )
        .toList();
  }

  Future<void> replaceUnitWords({
    required int unitId,
    required List<CustomWordDraft> words,
  }) async {
    await _runSerializedWrite(() async {
      await db.transaction((txn) async {
        final existingRows = await txn.query(
          'custom_word',
          columns: ['id'],
          where: 'unit_id = ?',
          whereArgs: [unitId],
        );
        final existingIds = existingRows.map((row) => row['id'] as int).toList();

        if (existingIds.isNotEmpty) {
          final placeholders = List.filled(existingIds.length, '?').join(',');
          await txn.delete(
            'learning_progress',
            where: 'word_type = ? AND word_id IN ($placeholders)',
            whereArgs: [WordType.custom.key, ...existingIds],
          );
        }

        await txn.delete(
          'custom_word',
          where: 'unit_id = ?',
          whereArgs: [unitId],
        );

        for (final word in words) {
          await txn.insert('custom_word', {
            'unit_id': unitId,
            'word': word.word.trim(),
            'meaning': word.meaning.trim(),
          });
        }
      });
    });
  }

  Future<List<OxfordEntry>> searchOxford(String query) async {
    final normalized = query.trim();
    if (normalized.isEmpty) {
      return const [];
    }
    final normalizedLower = _normalizedWord(normalized);
    final shortQuery = normalizedLower.length <= 2;
    final whereClause = shortQuery
        ? 'LOWER(word) LIKE ?'
        : 'LOWER(word) LIKE ?';
    final rows = await db.rawQuery(
      '''
      SELECT id, word, meaning
      FROM oxford_dict
      WHERE $whereClause
      ORDER BY
        CASE
          WHEN LOWER(word) = ? THEN 0
          WHEN LOWER(word) LIKE ? THEN 1
          ELSE 2
        END,
        CASE
          WHEN word = LOWER(word) THEN 0
          ELSE 1
        END,
        LENGTH(word) ASC,
        word COLLATE NOCASE ASC
      LIMIT 20
      ''',
      [
        shortQuery ? '$normalizedLower%' : '%$normalizedLower%',
        normalizedLower,
        '$normalizedLower%',
      ],
    );
    return rows.map(OxfordEntry.fromMap).toList();
  }

  Future<String> exportFullBackupJsonString() async {
    final payload = {
      'version': 1,
      'backup_type': 'full_backup',
      'exported_at': DateTime.now().toIso8601String(),
      'profile': (await fetchProfile()).toMap(),
      'builtin_progress': await db.rawQuery(
        '''
        SELECT
          p.id,
          p.word_id,
          p.word_type,
          p.error_count,
          p.last_review_time,
          p.next_review_time,
          p.consecutive_correct,
          p.is_removed,
          b.word,
          b.source
        FROM learning_progress p
        LEFT JOIN builtin_dict b
          ON b.id = p.word_id
        WHERE p.word_type = ?
        ORDER BY p.word_id ASC
        ''',
        [WordType.builtin.key],
      ),
      'custom_dicts': await db.query('custom_dict', orderBy: 'id ASC'),
      'units': await db.query('unit', orderBy: 'id ASC'),
      'custom_words': await db.query('custom_word', orderBy: 'id ASC'),
    };
    return const JsonEncoder.withIndent('  ').convert(payload);
  }

  Future<String> exportCustomDictionaryJsonString() async {
    final payload = {
      'version': 1,
      'backup_type': 'custom_dictionary_bundle',
      'exported_at': DateTime.now().toIso8601String(),
      ...await _buildCustomDictionaryPayload(),
    };
    return const JsonEncoder.withIndent('  ').convert(payload);
  }

  Future<void> importFullBackupJsonString(
    String rawJson, {
    ImportProgressCallback? onProgress,
  }) async {
    _emitImportProgress(onProgress, 0.02, '正在解析完整备份...');
    final decoded = _decodeBackupJson(rawJson);
    final profile = decoded['profile'] as Map<String, dynamic>?;
    final builtinProgress = _normalizeMapList(decoded['builtin_progress']);
    final customDicts = _normalizeMapList(decoded['custom_dicts']);
    final units = _normalizeMapList(decoded['units']);
    final customWords = _normalizeMapList(decoded['custom_words']);
    _emitImportProgress(onProgress, 0.10, '备份解析完成，准备写入数据库...');

    await _runSerializedWrite(() async {
      await db.transaction((txn) async {
        if (profile != null) {
          await txn.insert('user_profile', {
            'id': 1,
            ...profile,
          }, conflictAlgorithm: ConflictAlgorithm.replace);
        }
        _emitImportProgress(onProgress, 0.16, '正在写入账户信息...');

        await _importBuiltinProgressFast(
          txn: txn,
          builtinProgress: builtinProgress,
          onProgress: onProgress,
          startProgress: 0.18,
          endProgress: 0.56,
        );

        await _replaceCustomDictionaryBundleFast(
          txn,
          customDicts: customDicts,
          units: units,
          customWords: customWords,
          onProgress: onProgress,
          startProgress: 0.56,
          endProgress: 0.96,
        );
      });
    });
    _emitImportProgress(onProgress, 1.0, '完整备份导入完成');
  }

  Future<void> importCustomDictionaryJsonString(
    String rawJson, {
    ImportProgressCallback? onProgress,
  }) async {
    _emitImportProgress(onProgress, 0.02, '正在解析自定义词典...');
    final decoded = _decodeBackupJson(rawJson);
    final customDicts = _normalizeMapList(decoded['custom_dicts']);
    final units = _normalizeMapList(decoded['units']);
    final customWords = _normalizeMapList(decoded['custom_words']);
    _emitImportProgress(onProgress, 0.10, '词典解析完成，准备写入数据库...');

    await _runSerializedWrite(() async {
      await db.transaction((txn) async {
        await _mergeCustomDictionaryBundleFast(
          txn,
          customDicts: customDicts,
          units: units,
          customWords: customWords,
          onProgress: onProgress,
          startProgress: 0.12,
          endProgress: 0.96,
        );
      });
    });
    _emitImportProgress(onProgress, 1.0, '自定义词典导入完成');
  }

  Future<String> exportJsonString() => exportFullBackupJsonString();

  Future<void> importJsonString(String rawJson) =>
      importFullBackupJsonString(rawJson);

  List<Map<String, dynamic>> _normalizeMapList(dynamic raw) {
    if (raw is! List) {
      return const [];
    }
    return raw
        .whereType<Map>()
        .map(
          (item) => item.map((key, value) => MapEntry(key.toString(), value)),
        )
        .toList();
  }

  Map<String, dynamic> _decodeBackupJson(String rawJson) {
    final sanitized = rawJson.trimLeft().replaceFirst('\ufeff', '');
    final decoded = jsonDecode(sanitized);
    if (decoded is! Map) {
      throw const FormatException('备份文件格式不正确');
    }
    return decoded.map((key, value) => MapEntry(key.toString(), value));
  }

  Future<Map<String, Object?>> _buildCustomDictionaryPayload() async {
    return {
      'custom_dicts': await db.query('custom_dict', orderBy: 'id ASC'),
      'units': await db.query('unit', orderBy: 'id ASC'),
      'custom_words': await db.query('custom_word', orderBy: 'id ASC'),
    };
  }

  // ignore: unused_element
  Future<void> _replaceCustomDictionaryBundle(
    Transaction txn, {
    required List<Map<String, dynamic>> customDicts,
    required List<Map<String, dynamic>> units,
    required List<Map<String, dynamic>> customWords,
  }) async {
    final dictionaryIdMap = <int, int>{};
    final unitIdMap = <int, int>{};

    for (final dictionary in customDicts) {
      final name = (dictionary['name'] as String? ?? '未命名字典').trim();
      final existing = await txn.query(
        'custom_dict',
        columns: ['id'],
        where: 'name = ?',
        whereArgs: [name],
      );
      for (final item in existing) {
        await txn.delete(
          'custom_dict',
          where: 'id = ?',
          whereArgs: [item['id']],
        );
      }
      final newId = await txn.insert('custom_dict', {'name': name});
      final oldId = (dictionary['id'] as num?)?.toInt() ?? newId;
      dictionaryIdMap[oldId] = newId;
    }

    for (final unit in units) {
      final oldDictId = (unit['dict_id'] as num?)?.toInt();
      if (oldDictId == null || !dictionaryIdMap.containsKey(oldDictId)) {
        continue;
      }
      final newId = await txn.insert('unit', {
        'dict_id': dictionaryIdMap[oldDictId],
        'name': (unit['name'] as String? ?? '未命名单元').trim(),
      });
      final oldUnitId = (unit['id'] as num?)?.toInt() ?? newId;
      unitIdMap[oldUnitId] = newId;
    }

    for (final word in customWords) {
      final oldUnitId = (word['unit_id'] as num?)?.toInt();
      if (oldUnitId == null || !unitIdMap.containsKey(oldUnitId)) {
        continue;
      }
      await txn.insert('custom_word', {
        'unit_id': unitIdMap[oldUnitId],
        'word': (word['word'] as String? ?? '').trim(),
        'meaning': (word['meaning'] as String? ?? '').trim(),
      });
    }
  }

  // ignore: unused_element
  Future<void> _mergeCustomDictionaryBundle(
    Transaction txn, {
    required List<Map<String, dynamic>> customDicts,
    required List<Map<String, dynamic>> units,
    required List<Map<String, dynamic>> customWords,
  }) async {
    final dictionaryIdMap = <int, int>{};
    final unitIdMap = <int, int>{};

    for (final dictionary in customDicts) {
      final name = (dictionary['name'] as String? ?? '未命名字典').trim();
      if (name.isEmpty) {
        continue;
      }
      final existing = await txn.query(
        'custom_dict',
        columns: ['id'],
        where: 'name = ?',
        whereArgs: [name],
        limit: 1,
      );
      final newId = existing.isNotEmpty
          ? existing.first['id'] as int
          : await txn.insert('custom_dict', {'name': name});
      final oldId = (dictionary['id'] as num?)?.toInt() ?? newId;
      dictionaryIdMap[oldId] = newId;
    }

    for (final unit in units) {
      final oldDictId = (unit['dict_id'] as num?)?.toInt();
      final mappedDictId = oldDictId == null
          ? null
          : dictionaryIdMap[oldDictId];
      if (mappedDictId == null) {
        continue;
      }

      final name = (unit['name'] as String? ?? '未命名单元').trim();
      if (name.isEmpty) {
        continue;
      }

      final existing = await txn.query(
        'unit',
        columns: ['id'],
        where: 'dict_id = ? AND name = ?',
        whereArgs: [mappedDictId, name],
        limit: 1,
      );
      final newId = existing.isNotEmpty
          ? existing.first['id'] as int
          : await txn.insert('unit', {'dict_id': mappedDictId, 'name': name});
      final oldUnitId = (unit['id'] as num?)?.toInt() ?? newId;
      unitIdMap[oldUnitId] = newId;
    }

    for (final word in customWords) {
      final oldUnitId = (word['unit_id'] as num?)?.toInt();
      final mappedUnitId = oldUnitId == null ? null : unitIdMap[oldUnitId];
      if (mappedUnitId == null) {
        continue;
      }

      final rawWord = (word['word'] as String? ?? '').trim();
      final rawMeaning = (word['meaning'] as String? ?? '').trim();
      if (rawWord.isEmpty || rawMeaning.isEmpty) {
        continue;
      }

      final existing = await txn.query(
        'custom_word',
        columns: ['id', 'meaning'],
        where: 'unit_id = ? AND LOWER(word) = ?',
        whereArgs: [mappedUnitId, _normalizedWord(rawWord)],
        limit: 1,
      );

      if (existing.isEmpty) {
        await txn.insert('custom_word', {
          'unit_id': mappedUnitId,
          'word': rawWord,
          'meaning': rawMeaning,
        });
        continue;
      }

      if ((existing.first['meaning'] as String? ?? '') != rawMeaning) {
        await txn.update(
          'custom_word',
          {'word': rawWord, 'meaning': rawMeaning},
          where: 'id = ?',
          whereArgs: [existing.first['id']],
        );
      }
    }
  }

  Future<void> _importBuiltinProgressFast({
    required Transaction txn,
    required List<Map<String, dynamic>> builtinProgress,
    ImportProgressCallback? onProgress,
    double startProgress = 0,
    double endProgress = 1,
  }) async {
    final builtinIdMap = await _loadBuiltinIdMap(txn);
    final builtinIdSet = builtinIdMap.values.toSet();
    Batch batch = txn.batch();
    var queued = 0;
    var processed = 0;
    _emitImportProgress(onProgress, startProgress, '正在导入内置学习进度...');

    Future<void> flush() async {
      if (queued == 0) {
        return;
      }
      await batch.commit(noResult: true);
      processed += queued;
      _emitImportProgress(
        onProgress,
        _sliceProgress(startProgress, endProgress, processed, builtinProgress.length),
        '正在导入内置学习进度...',
      );
      batch = txn.batch();
      queued = 0;
    }

    for (final progress in builtinProgress) {
      final targetWordId = _resolveBuiltinWordId(
        progress,
        builtinIdMap,
        builtinIdSet,
      );
      if (targetWordId == null) {
        continue;
      }
      batch.insert('learning_progress', {
        'word_id': targetWordId,
        'word_type': progress['word_type'] ?? WordType.builtin.key,
        'error_count': progress['error_count'] ?? 0,
        'last_review_time': progress['last_review_time'] ?? 0,
        'next_review_time': progress['next_review_time'] ?? 0,
        'consecutive_correct': progress['consecutive_correct'] ?? 0,
        'is_removed': progress['is_removed'] ?? 0,
      }, conflictAlgorithm: ConflictAlgorithm.replace);
      queued++;
      if (queued >= _batchChunkSize) {
        await flush();
      }
    }

    await flush();
  }

  Future<void> _replaceCustomDictionaryBundleFast(
    Transaction txn, {
    required List<Map<String, dynamic>> customDicts,
    required List<Map<String, dynamic>> units,
    required List<Map<String, dynamic>> customWords,
    ImportProgressCallback? onProgress,
    double startProgress = 0,
    double endProgress = 1,
  }) async {
    final dictionaryIdMap = <int, int>{};
    final unitIdMap = <int, int>{};
    final dictionaryEnd = _lerpProgress(startProgress, endProgress, 0.20);
    final unitEnd = _lerpProgress(startProgress, endProgress, 0.45);
    final wordEnd = _lerpProgress(startProgress, endProgress, 1.0);
    _emitImportProgress(onProgress, startProgress, '正在替换自定义词典...');
    final existingDictionaryRows = await txn.query(
      'custom_dict',
      columns: ['id', 'name'],
    );
    final existingDictionaryIdsByName = <String, List<int>>{};
    for (final row in existingDictionaryRows) {
      final name = row['name'] as String? ?? '';
      final id = row['id'] as int?;
      if (name.isEmpty || id == null) {
        continue;
      }
      existingDictionaryIdsByName.putIfAbsent(name, () => <int>[]).add(id);
    }

    for (final dictionary in customDicts) {
      final name = _sanitizeImportedDictionaryName(dictionary['name']);
      final existingIds = existingDictionaryIdsByName[name] ?? const <int>[];
      for (final existingId in existingIds) {
        await txn.delete(
          'custom_dict',
          where: 'id = ?',
          whereArgs: [existingId],
        );
      }
      final newId = await txn.insert('custom_dict', {'name': name});
      final oldId = (dictionary['id'] as num?)?.toInt() ?? newId;
      dictionaryIdMap[oldId] = newId;
      _emitImportProgress(
        onProgress,
        _sliceProgress(startProgress, dictionaryEnd, dictionaryIdMap.length, customDicts.length),
        '正在替换词典列表...',
      );
    }

    if (customDicts.isEmpty) {
      _emitImportProgress(onProgress, dictionaryEnd, '词典列表处理完成');
    }

    final unitRows = <Map<String, Object?>>[];
    final unitOldIds = <int>[];
    for (final unit in units) {
      final oldDictId = (unit['dict_id'] as num?)?.toInt();
      if (oldDictId == null) {
        continue;
      }
      final mappedDictId = dictionaryIdMap[oldDictId];
      if (mappedDictId == null) {
        continue;
      }
      unitRows.add({
        'dict_id': mappedDictId,
        'name': _sanitizeImportedUnitName(unit['name']),
      });
      unitOldIds.add((unit['id'] as num?)?.toInt() ?? -1);
    }

    if (unitRows.isNotEmpty) {
      final batch = txn.batch();
      for (final row in unitRows) {
        batch.insert('unit', row);
      }
      final results = await batch.commit();
      for (var index = 0; index < results.length; index++) {
        final newId = results[index] as int;
        final oldUnitId = unitOldIds[index] == -1 ? newId : unitOldIds[index];
        unitIdMap[oldUnitId] = newId;
      }
    }
    _emitImportProgress(
      onProgress,
      unitEnd,
      unitRows.isEmpty ? '没有需要导入的单元' : '单元写入完成',
    );

    final wordRows = <Map<String, Object?>>[];
    for (final word in customWords) {
      final oldUnitId = (word['unit_id'] as num?)?.toInt();
      if (oldUnitId == null) {
        continue;
      }
      final mappedUnitId = unitIdMap[oldUnitId];
      if (mappedUnitId == null) {
        continue;
      }

      final rawWord = (word['word'] as String? ?? '').trim();
      final rawMeaning = (word['meaning'] as String? ?? '').trim();
      if (rawWord.isEmpty || rawMeaning.isEmpty) {
        continue;
      }

      wordRows.add({
        'unit_id': mappedUnitId,
        'word': rawWord,
        'meaning': rawMeaning,
      });
    }

    await _commitInsertChunked(
      txn,
      table: 'custom_word',
      rows: wordRows,
      onProgress: onProgress,
      startProgress: unitEnd,
      endProgress: wordEnd,
      progressMessage: '正在导入自定义单词...',
    );
  }

  Future<void> _mergeCustomDictionaryBundleFast(
    Transaction txn, {
    required List<Map<String, dynamic>> customDicts,
    required List<Map<String, dynamic>> units,
    required List<Map<String, dynamic>> customWords,
    ImportProgressCallback? onProgress,
    double startProgress = 0,
    double endProgress = 1,
  }) async {
    final dictionaryIdMap = <int, int>{};
    final unitIdMap = <int, int>{};
    final dictionaryEnd = _lerpProgress(startProgress, endProgress, 0.18);
    final unitEnd = _lerpProgress(startProgress, endProgress, 0.40);
    final insertEnd = _lerpProgress(startProgress, endProgress, 0.82);
    final updateEnd = _lerpProgress(startProgress, endProgress, 1.0);
    _emitImportProgress(onProgress, startProgress, '正在合并自定义词典...');
    final existingDictionaryRows = await txn.query(
      'custom_dict',
      columns: ['id', 'name'],
    );
    final existingDictionaryIdByName = <String, int>{
      for (final row in existingDictionaryRows)
        if (row['id'] is int && row['name'] is String)
          row['name'] as String: row['id'] as int,
    };

    for (final dictionary in customDicts) {
      final name = _sanitizeImportedDictionaryName(dictionary['name']);
      if (name.isEmpty) {
        continue;
      }
      final existingId = existingDictionaryIdByName[name];
      final newId = existingId ?? await txn.insert('custom_dict', {'name': name});
      existingDictionaryIdByName[name] = newId;
      final oldId = (dictionary['id'] as num?)?.toInt() ?? newId;
      dictionaryIdMap[oldId] = newId;
      _emitImportProgress(
        onProgress,
        _sliceProgress(startProgress, dictionaryEnd, dictionaryIdMap.length, customDicts.length),
        '正在匹配词典...',
      );
    }

    if (customDicts.isEmpty) {
      _emitImportProgress(onProgress, dictionaryEnd, '词典匹配完成');
    }

    final existingUnitRows = await txn.query(
      'unit',
      columns: ['id', 'dict_id', 'name'],
    );
    final existingUnitIdByKey = <String, int>{
      for (final row in existingUnitRows)
        if (row['id'] is int && row['dict_id'] is int && row['name'] is String)
          _customUnitKey(
            dictId: row['dict_id'] as int,
            name: row['name'] as String,
          ): row['id'] as int,
    };

    for (final unit in units) {
      final oldDictId = (unit['dict_id'] as num?)?.toInt();
      if (oldDictId == null) {
        continue;
      }
      final mappedDictId = dictionaryIdMap[oldDictId];
      if (mappedDictId == null) {
        continue;
      }

      final name = _sanitizeImportedUnitName(unit['name']);
      if (name.isEmpty) {
        continue;
      }

      final key = _customUnitKey(dictId: mappedDictId, name: name);
      final existingId = existingUnitIdByKey[key];
      final newId =
          existingId ??
          await txn.insert('unit', {'dict_id': mappedDictId, 'name': name});
      existingUnitIdByKey[key] = newId;
      final oldUnitId = (unit['id'] as num?)?.toInt() ?? newId;
      unitIdMap[oldUnitId] = newId;
      _emitImportProgress(
        onProgress,
        _sliceProgress(dictionaryEnd, unitEnd, unitIdMap.length, units.length),
        '正在匹配单元...',
      );
    }

    if (units.isEmpty) {
      _emitImportProgress(onProgress, unitEnd, '单元匹配完成');
    }

    final existingWordRows = await txn.query(
      'custom_word',
      columns: ['id', 'unit_id', 'word', 'meaning'],
    );
    final existingWordByKey = <String, Map<String, Object?>>{
      for (final row in existingWordRows)
        if (row['id'] is int && row['unit_id'] is int && row['word'] is String)
          _customWordKey(
            unitId: row['unit_id'] as int,
            word: row['word'] as String,
          ): Map<String, Object?>.from(row),
    };
    final insertRows = <Map<String, Object?>>[];
    final updateRows = <Map<String, Object?>>[];

    for (final word in customWords) {
      final oldUnitId = (word['unit_id'] as num?)?.toInt();
      if (oldUnitId == null) {
        continue;
      }
      final mappedUnitId = unitIdMap[oldUnitId];
      if (mappedUnitId == null) {
        continue;
      }

      final rawWord = (word['word'] as String? ?? '').trim();
      final rawMeaning = (word['meaning'] as String? ?? '').trim();
      if (rawWord.isEmpty || rawMeaning.isEmpty) {
        continue;
      }

      final key = _customWordKey(unitId: mappedUnitId, word: rawWord);
      final existing = existingWordByKey[key];
      if (existing == null) {
        final insertedRow = <String, Object?>{
          'unit_id': mappedUnitId,
          'word': rawWord,
          'meaning': rawMeaning,
        };
        insertRows.add(insertedRow);
        existingWordByKey[key] = insertedRow;
        continue;
      }

      if ((existing['meaning'] as String? ?? '') != rawMeaning) {
        updateRows.add({
          'id': existing['id'],
          'word': rawWord,
          'meaning': rawMeaning,
        });
        existing['meaning'] = rawMeaning;
        existing['word'] = rawWord;
      }
    }

    await _commitInsertChunked(
      txn,
      table: 'custom_word',
      rows: insertRows,
      onProgress: onProgress,
      startProgress: unitEnd,
      endProgress: insertEnd,
      progressMessage: '正在写入新增单词...',
    );
    await _commitCustomWordUpdateChunked(
      txn,
      updateRows,
      onProgress: onProgress,
      startProgress: insertEnd,
      endProgress: updateEnd,
      progressMessage: '正在更新已有单词...',
    );
  }

  Future<void> _commitInsertChunked(
    Transaction txn, {
    required String table,
    required List<Map<String, Object?>> rows,
    ConflictAlgorithm? conflictAlgorithm,
    ImportProgressCallback? onProgress,
    double startProgress = 0,
    double endProgress = 1,
    String progressMessage = '正在写入数据...',
  }) async {
    if (rows.isEmpty) {
      _emitImportProgress(onProgress, endProgress, progressMessage);
      return;
    }

    Batch batch = txn.batch();
    var queued = 0;
    var processed = 0;
    _emitImportProgress(onProgress, startProgress, progressMessage);
    for (final row in rows) {
      batch.insert(
        table,
        row,
        conflictAlgorithm: conflictAlgorithm,
      );
      queued++;
      if (queued >= _batchChunkSize) {
        await batch.commit(noResult: true);
        processed += queued;
        _emitImportProgress(
          onProgress,
          _sliceProgress(startProgress, endProgress, processed, rows.length),
          progressMessage,
        );
        batch = txn.batch();
        queued = 0;
      }
    }

    if (queued > 0) {
      await batch.commit(noResult: true);
      processed += queued;
      _emitImportProgress(
        onProgress,
        _sliceProgress(startProgress, endProgress, processed, rows.length),
        progressMessage,
      );
    }
  }

  Future<void> _commitCustomWordUpdateChunked(
    Transaction txn,
    List<Map<String, Object?>> rows, {
    ImportProgressCallback? onProgress,
    double startProgress = 0,
    double endProgress = 1,
    String progressMessage = '正在更新数据...',
  }) async {
    if (rows.isEmpty) {
      _emitImportProgress(onProgress, endProgress, progressMessage);
      return;
    }

    Batch batch = txn.batch();
    var queued = 0;
    var processed = 0;
    _emitImportProgress(onProgress, startProgress, progressMessage);
    for (final row in rows) {
      batch.update(
        'custom_word',
        {
          'word': row['word'],
          'meaning': row['meaning'],
        },
        where: 'id = ?',
        whereArgs: [row['id']],
      );
      queued++;
      if (queued >= _batchChunkSize) {
        await batch.commit(noResult: true);
        processed += queued;
        _emitImportProgress(
          onProgress,
          _sliceProgress(startProgress, endProgress, processed, rows.length),
          progressMessage,
        );
        batch = txn.batch();
        queued = 0;
      }
    }

    if (queued > 0) {
      await batch.commit(noResult: true);
      processed += queued;
      _emitImportProgress(
        onProgress,
        _sliceProgress(startProgress, endProgress, processed, rows.length),
        progressMessage,
      );
    }
  }

  void _emitImportProgress(
    ImportProgressCallback? onProgress,
    double progress,
    String message,
  ) {
    onProgress?.call(
      ImportProgress(
        progress: progress.clamp(0.0, 1.0),
        message: message,
      ),
    );
  }

  double _sliceProgress(
    double start,
    double end,
    int processed,
    int total,
  ) {
    if (total <= 0) {
      return end;
    }
    final ratio = (processed / total).clamp(0.0, 1.0);
    return start + (end - start) * ratio;
  }

  double _lerpProgress(double start, double end, double ratio) {
    return start + (end - start) * ratio.clamp(0.0, 1.0);
  }

  String _sanitizeImportedDictionaryName(Object? rawName) {
    final name = (rawName as String? ?? '').trim();
    return name.isEmpty ? 'Imported Dictionary' : name;
  }

  String _sanitizeImportedUnitName(Object? rawName) {
    final name = (rawName as String? ?? '').trim();
    return name.isEmpty ? 'Imported Unit' : name;
  }

  String _customUnitKey({required int dictId, required String name}) {
    return '$dictId|$name';
  }

  String _customWordKey({required int unitId, required String word}) {
    return '$unitId|${_normalizedWord(word)}';
  }

  Future<String?> _getMetaValue(String key) async {
    final rows = await db.query(
      'app_meta',
      columns: ['value'],
      where: 'key = ?',
      whereArgs: [key],
      limit: 1,
    );
    if (rows.isEmpty) {
      return null;
    }
    return rows.first['value'] as String?;
  }

  Future<void> _setMetaValue(
    DatabaseExecutor executor,
    String key,
    String value,
  ) async {
    await executor.insert('app_meta', {
      'key': key,
      'value': value,
    }, conflictAlgorithm: ConflictAlgorithm.replace);
  }

  String _builtinWordKey({required String source, required String word}) {
    return '$source|${_normalizedWord(word)}';
  }

  String _normalizedWord(String word) => word.trim().toLowerCase();

  Future<Map<String, int>> _loadBuiltinIdMap(DatabaseExecutor executor) async {
    final rows = await executor.query(
      'builtin_dict',
      columns: ['id', 'word', 'source'],
    );
    return {
      for (final row in rows)
        _builtinWordKey(
          source: row['source'] as String,
          word: row['word'] as String,
        ): row['id'] as int,
    };
  }

  int? _resolveBuiltinWordId(
    Map<String, dynamic> progress,
    Map<String, int> builtinIdMap,
    Set<int> builtinIdSet,
  ) {
    final source = progress['source'] as String?;
    final word = progress['word'] as String?;
    if (source != null && word != null) {
      final resolved =
          builtinIdMap[_builtinWordKey(source: source, word: word)];
      if (resolved != null) {
        return resolved;
      }
    }

    final rawWordId = (progress['word_id'] as num?)?.toInt();
    if (rawWordId == null) {
      return null;
    }

    if (builtinIdSet.contains(rawWordId)) {
      return rawWordId;
    }
    return null;
  }
}
