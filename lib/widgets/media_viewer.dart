import 'dart:io';
import 'package:flutter/material.dart';
import 'package:photo_view/photo_view.dart';
import 'package:video_player/video_player.dart';
import 'package:share_plus/share_plus.dart';
import '../services/haptic_service.dart';

class MediaViewer extends StatefulWidget {
  final String mediaPath;
  final String mediaType;

  const MediaViewer({
    Key? key,
    required this.mediaPath,
    required this.mediaType,
  }) : super(key: key);

  @override
  State<MediaViewer> createState() => _MediaViewerState();
}

class _MediaViewerState extends State<MediaViewer> {
  VideoPlayerController? _videoController;

  @override
  void initState() {
    super.initState();
    if (widget.mediaType == 'video') {
      _videoController = VideoPlayerController.file(File(widget.mediaPath))
        ..initialize().then((_) {
          if (mounted) setState(() {});
        });
    }
  }

  @override
  void dispose() {
    _videoController?.dispose();
    super.dispose();
  }

  void _shareMedia() {
    HapticService().light();
    Share.shareXFiles([XFile(widget.mediaPath)]);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        actions: [
          IconButton(
            icon: const Icon(Icons.share),
            onPressed: _shareMedia,
          ),
        ],
      ),
      body: Center(
        child: widget.mediaType == 'image'
            ? PhotoView(
                imageProvider: FileImage(File(widget.mediaPath)),
                minScale: PhotoViewComputedScale.contained,
                maxScale: PhotoViewComputedScale.covered * 2,
              )
            : widget.mediaType == 'video' && _videoController != null
                ? _videoController!.value.isInitialized
                    ? AspectRatio(
                        aspectRatio: _videoController!.value.aspectRatio,
                        child: Stack(
                          children: [
                            VideoPlayer(_videoController!),
                            Center(
                              child: IconButton(
                                icon: Icon(
                                  _videoController!.value.isPlaying ? Icons.pause : Icons.play_arrow,
                                  size: 64,
                                  color: Colors.white,
                                ),
                                onPressed: () {
                                  HapticService().medium();
                                  setState(() {
                                    _videoController!.value.isPlaying
                                        ? _videoController!.pause()
                                        : _videoController!.play();
                                  });
                                },
                              ),
                            ),
                          ],
                        ),
                      )
                    : const CircularProgressIndicator()
                : const Icon(Icons.file_present, size: 64, color: Colors.white),
      ),
    );
  }
}