import 'file_transfer_base.dart';

class UnsupportedFileTransferService implements FileTransferService {
  @override
  Future<String?> pickJsonText() async => null;

  @override
  Future<String> saveJson({
    required String suggestedName,
    required String content,
  }) async {
    return '当前平台暂不支持文件导出。';
  }
}

FileTransferService createPlatformFileTransferService() =>
    UnsupportedFileTransferService();
