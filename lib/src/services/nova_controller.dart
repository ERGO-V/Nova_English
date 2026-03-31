import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

import '../models/entities.dart';
import 'file_transfer.dart';
import 'nova_repository.dart';

class NovaController extends ChangeNotifier {
  NovaController(this.repository)
    : _transferService = createFileTransferService();

  final NovaRepository repository;
  final FileTransferService _transferService;
  final ImagePicker _imagePicker = ImagePicker();

  bool isReady = false;
  bool isBusy = false;
  String? initError;
  int tabIndex = 0;
  BuiltinSource selectedSource = BuiltinSource.cet4;
  UserProfile profile = const UserProfile(nickname: 'Nova Learner');
  BuiltinStats studyStats = const BuiltinStats(
    total: 0,
    active: 0,
    due: 0,
    mastered: 0,
  );
  List<CustomDictionarySummary> customDictionaries = const [];

  Future<void> initialize() async {
    if (isReady || isBusy) {
      return;
    }
    isBusy = true;
    initError = null;
    notifyListeners();

    try {
      await repository.init();
      profile = await repository.fetchProfile();
      studyStats = await repository.fetchBuiltinStats(selectedSource);
      customDictionaries = await repository.fetchCustomDictionaries();
      isReady = true;
    } catch (error) {
      initError = error.toString();
    } finally {
      isBusy = false;
    }

    notifyListeners();
  }

  Future<void> refreshAll() async {
    studyStats = await repository.fetchBuiltinStats(selectedSource);
    customDictionaries = await repository.fetchCustomDictionaries();
    profile = await repository.fetchProfile();
    notifyListeners();
  }

  Future<void> changeSource(BuiltinSource source) async {
    selectedSource = source;
    studyStats = await repository.fetchBuiltinStats(source);
    notifyListeners();
  }

  void switchTab(int index) {
    tabIndex = index;
    notifyListeners();
  }

  Future<void> addDictionary(String name) async {
    await repository.addCustomDictionary(name);
    customDictionaries = await repository.fetchCustomDictionaries();
    notifyListeners();
  }

  Future<void> removeDictionary(int id) async {
    await repository.deleteCustomDictionary(id);
    customDictionaries = await repository.fetchCustomDictionaries();
    notifyListeners();
  }

  Future<void> updateNickname(String nickname) async {
    profile = profile.copyWith(nickname: nickname.trim());
    await repository.saveProfile(profile);
    notifyListeners();
  }

  Future<void> pickAvatar(ImageSource source) async {
    final file = await _imagePicker.pickImage(
      source: source,
      imageQuality: 82,
      maxWidth: 1024,
    );
    if (file == null) {
      return;
    }
    final bytes = await file.readAsBytes();
    final mime = _guessMimeType(file.name);
    final dataUrl = 'data:$mime;base64,${base64Encode(bytes)}';
    profile = profile.copyWith(avatarPath: dataUrl);
    await repository.saveProfile(profile);
    notifyListeners();
  }

  Future<void> clearAvatar() async {
    profile = profile.copyWith(clearAvatar: true);
    await repository.saveProfile(profile);
    notifyListeners();
  }

  ImageProvider<Object>? avatarProvider() {
    final raw = profile.avatarPath;
    if (raw == null || raw.isEmpty || !raw.startsWith('data:')) {
      return null;
    }
    return MemoryImage(_decodeDataUrl(raw));
  }

  Future<String> exportFullBackup() async {
    final json = await repository.exportFullBackupJsonString();
    return _transferService.saveJson(
      suggestedName:
          'novaenglish-backup-${DateTime.now().millisecondsSinceEpoch}.json',
      content: json,
    );
  }

  Future<String?> importFullBackup() async {
    final raw = await _transferService.pickJsonText();
    if (raw == null) {
      return null;
    }
    try {
      await repository.importFullBackupJsonString(raw);
      await refreshAll();
      return '完整备份已导入，内置学习进度和自定义词典数据已按备份内容合并。';
    } catch (error) {
      return '导入失败：$error';
    }
  }

  Future<String> exportCustomDictionaryBundle() async {
    final json = await repository.exportCustomDictionaryJsonString();
    return _transferService.saveJson(
      suggestedName:
          'novaenglish-custom-dicts-${DateTime.now().millisecondsSinceEpoch}.json',
      content: json,
    );
  }

  Future<String?> importCustomDictionaryBundle() async {
    final raw = await _transferService.pickJsonText();
    if (raw == null) {
      return null;
    }
    try {
      await repository.importCustomDictionaryJsonString(raw);
      await refreshAll();
      return '自定义词典已导入，当前学习进度保持不变。';
    } catch (error) {
      return '导入失败：$error';
    }
  }

  Future<String> exportData() => exportFullBackup();

  Future<String?> importData() => importFullBackup();

  String _guessMimeType(String fileName) {
    final lower = fileName.toLowerCase();
    if (lower.endsWith('.png')) {
      return 'image/png';
    }
    if (lower.endsWith('.webp')) {
      return 'image/webp';
    }
    return 'image/jpeg';
  }

  Uint8List _decodeDataUrl(String raw) {
    final content = raw.contains(',') ? raw.split(',').last : raw;
    return base64Decode(content);
  }
}
