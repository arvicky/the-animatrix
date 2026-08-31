import 'dart:convert';
import 'dart:io';

/// 读取录音文件（原生路径）为 base64。
Future<String> readAudioAsBase64(String path) async {
  final bytes = await File(path).readAsBytes();
  return base64Encode(bytes);
}
