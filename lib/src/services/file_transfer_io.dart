import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:file_picker/file_picker.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

import 'file_transfer_base.dart';

class IoFileTransferService implements FileTransferService {
  @override
  Future<String?> pickJsonText() async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: const ['json'],
      withData: true,
    );
    if (result == null || result.files.isEmpty) {
      return null;
    }
    final file = result.files.single;
    if (file.bytes != null) {
      return utf8.decode(file.bytes!);
    }
    if (file.path == null) {
      return null;
    }
    return File(file.path!).readAsString();
  }

  @override
  Future<String> saveJson({
    required String suggestedName,
    required String content,
  }) async {
    if (Platform.isAndroid) {
      final savedPath = await FilePicker.platform.saveFile(
        dialogTitle: '选择导出位置',
        fileName: suggestedName,
        type: FileType.custom,
        allowedExtensions: const ['json'],
        bytes: Uint8List.fromList(utf8.encode(content)),
      );
      if (savedPath != null && savedPath.isNotEmpty) {
        return '已导出到 $savedPath';
      }
      return '已取消导出';
    }

    final directory = await getApplicationDocumentsDirectory();
    final file = File(p.join(directory.path, suggestedName));
    await file.writeAsString(content, flush: true);
    return '已导出到 ${file.path}';
  }
}

FileTransferService createPlatformFileTransferService() =>
    IoFileTransferService();
