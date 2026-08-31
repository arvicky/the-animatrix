// 跨平台读取录音文件为 base64（web 读 blob，原生读文件）。
export 'audio_utils_web.dart' if (dart.library.io) 'audio_utils_io.dart';
