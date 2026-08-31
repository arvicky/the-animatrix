import 'dart:html' as html;

/// 读取录音文件（web blob URL）为 base64。
Future<String> readAudioAsBase64(String pathOrUrl) async {
  final req = await html.HttpRequest.request(pathOrUrl, responseType: 'blob');
  final blob = req.response as html.Blob;
  final reader = html.FileReader();
  reader.readAsDataUrl(blob);
  await reader.onLoad.first;
  final dataUrl = reader.result as String;
  return dataUrl.split(',').last;
}
