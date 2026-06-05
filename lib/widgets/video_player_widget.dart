import 'package:flutter/material.dart';
import 'package:video_player/video_player.dart';
import 'package:chewie/chewie.dart';
import '../core/theme/app_theme.dart';

/// مشغّل فيديو بسيط — يستخدم Chewie فوق video_player
class OfferVideoPlayer extends StatefulWidget {
  final String videoUrl;
  final double height;

  const OfferVideoPlayer({
    super.key,
    required this.videoUrl,
    this.height = 220,
  });

  @override
  State<OfferVideoPlayer> createState() => _OfferVideoPlayerState();
}

class _OfferVideoPlayerState extends State<OfferVideoPlayer> {
  VideoPlayerController? _videoController;
  ChewieController? _chewieController;
  bool _initialized = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _init();
  }

  Future<void> _init() async {
    try {
      _videoController =
          VideoPlayerController.networkUrl(Uri.parse(widget.videoUrl));
      await _videoController!.initialize();
      _chewieController = ChewieController(
        videoPlayerController: _videoController!,
        autoPlay: false,
        looping: false,
        aspectRatio: _videoController!.value.aspectRatio,
        materialProgressColors: ChewieProgressColors(
          playedColor: AppTheme.primaryGold,
          handleColor: AppTheme.primaryGold,
          backgroundColor: Colors.grey,
          bufferedColor: Colors.white24,
        ),
        placeholder: Container(color: Colors.black),
        autoInitialize: true,
      );
      if (mounted) setState(() => _initialized = true);
    } catch (e) {
      if (mounted) setState(() => _error = e.toString());
    }
  }

  @override
  void dispose() {
    _videoController?.dispose();
    _chewieController?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_error != null) {
      return Container(
        height: widget.height,
        color: AppTheme.surfaceBlack,
        child: const Center(
          child: Icon(Icons.error_outline, color: Colors.red, size: 40),
        ),
      );
    }
    if (!_initialized || _chewieController == null) {
      return Container(
        height: widget.height,
        color: AppTheme.surfaceBlack,
        child: const Center(
          child: CircularProgressIndicator(color: AppTheme.primaryGold),
        ),
      );
    }
    return SizedBox(
      height: widget.height,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(12),
        child: Chewie(controller: _chewieController!),
      ),
    );
  }
}
