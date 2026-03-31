abstract class FileTransferService {
  Future<String> saveJson({
    required String suggestedName,
    required String content,
  });

  Future<String?> pickJsonText();
}
