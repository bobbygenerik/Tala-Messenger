import 'dart:io';
import 'package:image_picker/image_picker.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter_sound/flutter_sound.dart';
import 'package:path_provider/path_provider.dart';
import 'package:permission_handler/permission_handler.dart';

class MediaService {
  static final MediaService _instance = MediaService._internal();
  factory MediaService() => _instance;
  MediaService._internal();

  final ImagePicker _picker = ImagePicker();
  final FlutterSoundRecorder _recorder = FlutterSoundRecorder();
  bool _isRecorderInitialized = false;

  Future<File?> pickImage({ImageSource source = ImageSource.gallery}) async {
    final XFile? image = await _picker.pickImage(source: source);
    return image != null ? File(image.path) : null;
  }

  Future<File?> pickVideo({ImageSource source = ImageSource.gallery}) async {
    final XFile? video = await _picker.pickVideo(source: source);
    return video != null ? File(video.path) : null;
  }

  Future<File?> pickFile() async {
    final result = await FilePicker.platform.pickFiles();
    return result?.files.single.path != null ? File(result!.files.single.path!) : null;
  }

  Future<void> _initRecorder() async {
    if (!_isRecorderInitialized) {
      await _recorder.openRecorder();
      _isRecorderInitialized = true;
    }
  }

  Future<String?> startRecording() async {
    final permission = await Permission.microphone.request();
    if (permission != PermissionStatus.granted) return null;

    await _initRecorder();
    final directory = await getTemporaryDirectory();
    final path = '${directory.path}/audio_${DateTime.now().millisecondsSinceEpoch}.aac';
    
    await _recorder.startRecorder(
      toFile: path,
      codec: Codec.aacADTS,
    );
    return path;
  }

  Future<String?> stopRecording() async {
    if (!_isRecorderInitialized) return null;
    return await _recorder.stopRecorder();
  }

  Future<bool> isRecording() async {
    if (!_isRecorderInitialized) return false;
    return _recorder.isRecording;
  }

  void dispose() {
    if (_isRecorderInitialized) {
      _recorder.closeRecorder();
    }
  }

  String getMediaType(String path) {
    final extension = path.split('.').last.toLowerCase();
    switch (extension) {
      case 'jpg':
      case 'jpeg':
      case 'png':
      case 'gif':
        return 'image';
      case 'mp4':
      case 'mov':
      case 'avi':
        return 'video';
      case 'm4a':
      case 'mp3':
      case 'wav':
        return 'audio';
      default:
        return 'file';
    }
  }
}