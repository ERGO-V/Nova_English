import 'dart:async';
import 'dart:convert';

import 'package:universal_html/html.dart' as html;

import 'file_transfer_base.dart';

class WebFileTransferService implements FileTransferService {
  @override
  Future<String?> pickJsonText() async {
    final completer = Completer<String?>();
    final input = html.FileUploadInputElement()..accept = '.json';
    input.onChange.listen((_) {
      final file = input.files?.first;
      if (file == null) {
        completer.complete(null);
        return;
      }
      final reader = html.FileReader();
      reader.onLoadEnd.listen((_) {
        completer.complete(reader.result as String?);
      });
      reader.readAsText(file);
    });
    input.click();
    return completer.future;
  }

  @override
  Future<String> saveJson({
    required String suggestedName,
    required String content,
  }) async {
    final bytes = utf8.encode(content);
    final blob = html.Blob([bytes], 'application/json');
    final url = html.Url.createObjectUrlFromBlob(blob);
    final anchor = html.AnchorElement(href: url)
      ..download = suggestedName
      ..style.display = 'none';
    html.document.body?.children.add(anchor);
    anchor.click();
    anchor.remove();
    html.Url.revokeObjectUrl(url);
    return '浏览器已开始下载 $suggestedName';
  }
}

FileTransferService createPlatformFileTransferService() =>
    WebFileTransferService();
