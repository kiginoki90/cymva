import 'package:cymva/view/post_item/full_screen_image.dart';
import 'package:cymva/view/slide_direction_page_route.dart';
import 'package:flutter/material.dart';
import 'package:video_player/video_player.dart';

class MediaDisplayWidget extends StatefulWidget {
  final List<String>? mediaUrl;
  final String category;

  const MediaDisplayWidget({
    Key? key,
    required this.mediaUrl,
    required this.category,
  }) : super(key: key);

  @override
  State<MediaDisplayWidget> createState() => _MediaDisplayWidgetState();
}

class _MediaDisplayWidgetState extends State<MediaDisplayWidget> {
  VideoPlayerController? _videoController;

  @override
  void initState() {
    super.initState();
    if (widget.mediaUrl != null &&
        widget.mediaUrl!.isNotEmpty &&
        _isVideo(widget.mediaUrl!.first)) {
      _initializeVideo(widget.mediaUrl!.first);
    }
  }

  @override
  void dispose() {
    _videoController?.dispose();
    super.dispose();
  }

  Future<void> _initializeVideo(String url) async {
    _videoController = VideoPlayerController.network(url);
    await _videoController!.initialize();
    setState(() {}); // 状態を更新して、動画が初期化されたことを反映
  }

  bool _isVideo(String? url) {
    if (url == null) return false;
    return url.endsWith(".mp4") || url.endsWith(".mov") || url.endsWith(".avi");
  }

  @override
  Widget build(BuildContext context) {
    if (widget.mediaUrl == null || widget.mediaUrl!.isEmpty) {
      return SizedBox.shrink();
    }

    // カテゴリーが "漫画" の場合
    if (widget.category == '漫画') {
      return _buildMangaMedia(context);
    }

    // メディアが1枚の場合
    else if (widget.mediaUrl!.length == 1) {
      return _isVideo(widget.mediaUrl!.first)
          ? _buildSingleVideo(context)
          : _buildSingleMedia(context);
    }

    // メディアが複数枚ある場合
    else {
      return _buildMultipleMedia(context);
    }
  }

  // 漫画の場合の表示
  Widget _buildMangaMedia(BuildContext context) {
    return Stack(
      children: [
        GestureDetector(
          onTap: () {
            Navigator.push(
              context,
              SlideDirectionPageRoute(
                page: FullScreenImagePage(
                  imageUrls: widget.mediaUrl!,
                  initialIndex: 0,
                ),
                isSwipeUp: true,
              ),
            );
          },
          child: ClipRRect(
            child: Image.network(
              widget.mediaUrl![0],
              width: MediaQuery.of(context).size.width,
              height: 200,
              fit: BoxFit.cover,
            ),
          ),
        ),
        if (widget.mediaUrl!.length > 1)
          Positioned(
            bottom: 10,
            left: 10,
            child: Container(
              padding:
                  const EdgeInsets.symmetric(horizontal: 8.0, vertical: 4.0),
              decoration: BoxDecoration(
                color: Colors.black.withOpacity(0.6),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Text(
                '${widget.mediaUrl!.length}',
                style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                    fontSize: 16),
              ),
            ),
          ),
      ],
    );
  }

  // メディアが1枚の場合の表示（画像）
  Widget _buildSingleMedia(BuildContext context) {
    return GestureDetector(
      onTap: () {
        Navigator.push(
          context,
          SlideDirectionPageRoute(
            page: FullScreenImagePage(
              imageUrls: widget.mediaUrl!,
              initialIndex: 0,
            ),
            isSwipeUp: true,
          ),
        );
      },
      child: ClipRRect(
        child: Image.network(
          widget.mediaUrl![0],
          width: MediaQuery.of(context).size.width * 0.9,
          height: 250,
          fit: BoxFit.cover,
        ),
      ),
    );
  }

  // メディアが1枚の場合の表示（動画）
  Widget _buildSingleVideo(BuildContext context) {
    if (_videoController == null || !_videoController!.value.isInitialized) {
      return Center(child: CircularProgressIndicator());
    }

    return GestureDetector(
      onTap: () {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => Scaffold(
              appBar: AppBar(),
              body: Center(
                child: AspectRatio(
                  aspectRatio: _videoController!.value.aspectRatio,
                  child: VideoPlayer(_videoController!),
                ),
              ),
              floatingActionButton: FloatingActionButton(
                onPressed: () {
                  setState(() {
                    _videoController!.value.isPlaying
                        ? _videoController!.pause()
                        : _videoController!.play();
                  });
                },
                child: Icon(
                  _videoController!.value.isPlaying
                      ? Icons.pause
                      : Icons.play_arrow,
                ),
              ),
            ),
          ),
        );
      },
      child: AspectRatio(
        aspectRatio: _videoController!.value.aspectRatio,
        child: VideoPlayer(_videoController!),
      ),
    );
  }

  // メディアが複数枚の場合の表示
  Widget _buildMultipleMedia(BuildContext context) {
    return GridView.builder(
      physics: const NeverScrollableScrollPhysics(),
      shrinkWrap: true,
      itemCount: widget.mediaUrl!.length,
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
      ),
      itemBuilder: (BuildContext context, int index) {
        return GestureDetector(
          onTap: () {
            Navigator.push(
              context,
              SlideDirectionPageRoute(
                page: FullScreenImagePage(
                  imageUrls: widget.mediaUrl!,
                  initialIndex: index,
                ),
                isSwipeUp: true,
              ),
            );
          },
          child: _isVideo(widget.mediaUrl![index])
              ? AspectRatio(
                  aspectRatio: 16 / 9,
                  child: Center(child: Icon(Icons.play_arrow)),
                )
              : ClipRRect(
                  child: Image.network(
                    widget.mediaUrl![index],
                    width: MediaQuery.of(context).size.width * 0.4,
                    height: 150,
                    fit: BoxFit.cover,
                  ),
                ),
        );
      },
    );
  }
}
