import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:image_cropper/image_cropper.dart';
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
  bool isImporting = false;
  String? initError;
  String? importStatusText;
  double? importProgressValue;
  int tabIndex = 0;
  bool prefersLightTheme = false;
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
      prefersLightTheme = await repository.fetchPrefersLightTheme();
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
    prefersLightTheme = await repository.fetchPrefersLightTheme();
    studyStats = await repository.fetchBuiltinStats(selectedSource);
    customDictionaries = await repository.fetchCustomDictionaries();
    profile = await repository.fetchProfile();
    notifyListeners();
  }

  ThemeMode get themeMode =>
      prefersLightTheme ? ThemeMode.light : ThemeMode.dark;

  Future<void> setPrefersLightTheme(bool value) async {
    if (prefersLightTheme == value) {
      return;
    }
    prefersLightTheme = value;
    await repository.savePrefersLightTheme(value);
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

  Future<void> pickAvatar(BuildContext context, ImageSource source) async {
    final file = await _imagePicker.pickImage(
      source: source,
      imageQuality: 82,
      maxWidth: 1024,
    );

    if (file == null) {
      return;
    }

    if (!context.mounted) return;

    final croppedFile = await ImageCropper().cropImage(
      sourcePath: file.path,
      aspectRatio: const CropAspectRatio(ratioX: 1, ratioY: 1),
      uiSettings: [
        AndroidUiSettings(
          toolbarTitle: '调整头像',
          toolbarColor: const Color(0xFF121E2D),
          toolbarWidgetColor: Colors.white,
          initAspectRatio: CropAspectRatioPreset.square,
          lockAspectRatio: true,
          hideBottomControls: true,
        ),
        IOSUiSettings(
          title: '调整头像',
          doneButtonTitle: '确定',
          cancelButtonTitle: '取消',
          aspectRatioLockEnabled: true,
          resetAspectRatioEnabled: false,
        ),
        WebUiSettings(
          context: context,
          presentStyle: WebPresentStyle.dialog,
          size: const CropperSize(
            width: 480,
            height: 480,
          ),
          translations: const WebTranslations(
            title: '调整头像',
            cancelButton: '取消',
            cropButton: '确定',
            rotateLeftTooltip: '向左旋转',
            rotateRightTooltip: '向右旋转',
          ),
        ),
      ],
    );

    if (croppedFile == null) {
      return;
    }

    final bytes = await croppedFile.readAsBytes();
    final mime = _guessMimeType(croppedFile.path.isEmpty ? file.name : croppedFile.path);
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
    if (isImporting) {
      return importStatusText ?? '正在导入数据，请稍候。';
    }
    final raw = await _transferService.pickJsonText();
    if (raw == null) {
      return null;
    }
    return _runImportTask(
      message: '正在导入完整备份...',
      task: (onProgress) async {
        await repository.importFullBackupJsonString(raw, onProgress: onProgress);
        _handleImportProgress(
          const ImportProgress(progress: 0.98, message: '正在刷新应用数据...'),
        );
        await refreshAll();
      },
      successMessage: '完整备份已导入，内置学习进度和自定义词典数据已合并。',
    );
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
    if (isImporting) {
      return importStatusText ?? '正在导入数据，请稍候。';
    }
    final raw = await _transferService.pickJsonText();
    if (raw == null) {
      return null;
    }
    return _runImportTask(
      message: '正在导入自定义词典...',
      task: (onProgress) async {
        await repository.importCustomDictionaryJsonString(
          raw,
          onProgress: onProgress,
        );
        _handleImportProgress(
          const ImportProgress(progress: 0.98, message: '正在刷新应用数据...'),
        );
        await refreshAll();
      },
      successMessage: '自定义词典已导入，当前学习进度保持不变。',
    );
  }

  Future<String> exportData() => exportFullBackup();

  Future<String?> importData() => importFullBackup();

  Future<String?> _runImportTask({
    required String message,
    required Future<void> Function(ImportProgressCallback onProgress) task,
    required String successMessage,
  }) async {
    isImporting = true;
    importStatusText = message;
    importProgressValue = 0;
    notifyListeners();

    try {
      await task(_handleImportProgress);
      _handleImportProgress(
        const ImportProgress(progress: 1.0, message: '导入完成'),
      );
      return successMessage;
    } catch (error) {
      return '导入失败：$error';
    } finally {
      isImporting = false;
      importStatusText = null;
      importProgressValue = null;
      notifyListeners();
    }
  }

  void _handleImportProgress(ImportProgress update) {
    importStatusText = update.message;
    importProgressValue = update.progress.clamp(0.0, 1.0);
    notifyListeners();
  }

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
