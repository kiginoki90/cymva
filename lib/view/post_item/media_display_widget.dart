import 'package:cymva/view/slide_direction_page_route.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/material.dart';
import 'package:video_player/video_player.dart';
import 'full_screen_image.dart';

class MediaDisplayWidget extends StatefulWidget {
  final List<String>? mediaUrl;
  final String category;

  const MediaDisplayWidget({
    Key? key,
    required this.mediaUrl,
    required this.category,
  }) : super(key: key);

  @override
  _MediaDisplayWidgetState createState() => _MediaDisplayWidgetState();
}

class _MediaDisplayWidgetState extends State<MediaDisplayWidget> {
  Map<String, bool> _isVideoCache = {}; // 判定結果のキャッシュ
  Map<String, VideoPlayerController> _videoControllers = {};

  @override
  void initState() {
    super.initState();
    if (widget.mediaUrl != null && widget.mediaUrl!.isNotEmpty) {
      _initializeMedia();
    }
  }

  @override
  void dispose() {
    // すべてのビデオコントローラを破棄
    for (var controller in _videoControllers.values) {
      controller.dispose();
    }
    super.dispose();
  }

  Future<void> _initializeMedia() async {
    for (String url in widget.mediaUrl!) {
      bool isVideo = await _isVideo(url);
      if (isVideo) {
        _initializeVideo(url);
      }
    }

    // ウィジェットがまだマウントされているか確認する
    if (mounted) {
      setState(() {});
    }
  }

  void _initializeVideo(String videoUrl) {
    final controller = VideoPlayerController.networkUrl(Uri.parse(videoUrl));
    _videoControllers[videoUrl] = controller;
    controller.initialize().then((_) {
      setState(() {}); // ビデオコントローラの初期化後に再描画
    });
  }

  // メタデータを使ってファイルが動画か画像かを判別
  Future<bool> _isVideo(String url) async {
    if (_isVideoCache.containsKey(url)) {
      return _isVideoCache[url]!;
    }

    try {
      final ref = FirebaseStorage.instance.refFromURL(url);
      final metadata = await ref.getMetadata();
      final contentType = metadata.contentType; // MIMEタイプを取得

      bool isVideo = contentType != null && contentType.startsWith('video/');
      _isVideoCache[url] = isVideo; // キャッシュに保存
      return isVideo;
    } catch (e) {
      print('Error retrieving metadata: $e');
      _isVideoCache[url] = false; // エラー時は画像として扱う
      return false;
    }
  }

  @override
  Widget build(BuildContext context) {
    // メディアが無い場合
    if (widget.mediaUrl == null || widget.mediaUrl!.isEmpty) {
      return const SizedBox.shrink();
    }

    // カテゴリーが "漫画" の場合
    if (widget.category == '漫画') {
      return _buildMangaMedia(context);
    }

    // メディアが1つの場合
    else if (widget.mediaUrl!.length == 1) {
      final mediaUrl = widget.mediaUrl!.first;
      return _isVideoCache.containsKey(mediaUrl)
          ? _isVideoCache[mediaUrl]!
              ? _buildSingleVideo(context, mediaUrl)
              : _buildSingleMedia(context, mediaUrl)
          : FutureBuilder<bool>(
              future: _isVideo(mediaUrl),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                } else if (snapshot.hasError) {
                  return const Text('Error loading media');
                } else {
                  return snapshot.data == true
                      ? _buildSingleVideo(context, mediaUrl) // 動画
                      : _buildSingleMedia(context, mediaUrl); // 画像
                }
              },
            );
    }

    // メディアが複数枚ある場合
    else {
      return _buildMultipleMedia(context);
    }
  }

  // 漫画の場合の表示
  Widget _buildMangaMedia(BuildContext context) {
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
      child: Stack(
        children: [
          Image.network(
            widget.mediaUrl![0],
            width: MediaQuery.of(context).size.width,
            height: 200,
            fit: BoxFit.cover,
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
      ),
    );
  }

  // メディアが1枚の場合の表示（画像）
  Widget _buildSingleMedia(BuildContext context, String mediaUrl) {
    return GestureDetector(
      onTap: () {
        Navigator.push(
          context,
          SlideDirectionPageRoute(
            page: FullScreenImagePage(
              imageUrls: [mediaUrl],
              initialIndex: 0,
            ),
            isSwipeUp: true,
          ),
        );
      },
      child: Image.network(
        mediaUrl,
        width: MediaQuery.of(context).size.width * 0.9,
        height: 250,
        fit: BoxFit.cover,
      ),
    );
  }

  // メディアが1枚の場合の表示（動画）
  Widget _buildSingleVideo(BuildContext context, String mediaUrl) {
    final controller = _videoControllers[mediaUrl];
    if (controller == null || !controller.value.isInitialized) {
      return const Center(child: CircularProgressIndicator());
    }

    return GestureDetector(
      onTap: () {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => VideoPlayerScreen(videoUrl: mediaUrl),
          ),
        );
      },
      child: Container(
        height: 250, // タップ前の高さの上限
        child: AspectRatio(
          aspectRatio: controller.value.aspectRatio,
          child: VideoPlayer(controller),
        ),
      ),
    );
  }

  // メディアが複数枚ある場合の表示
  Widget _buildMultipleMedia(BuildContext context) {
    return GridView.builder(
      physics: const NeverScrollableScrollPhysics(),
      shrinkWrap: true,
      itemCount: widget.mediaUrl!.length,
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
      ),
      itemBuilder: (BuildContext context, int index) {
        final mediaUrl = widget.mediaUrl![index];
        return FutureBuilder<bool>(
          future: _isVideo(mediaUrl),
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const Center(child: CircularProgressIndicator());
            } else if (snapshot.hasError) {
              return const Text('Error loading media');
            } else {
              if (snapshot.data == true) {
                // 動画の場合
                return GestureDetector(
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) =>
                            VideoPlayerScreen(videoUrl: mediaUrl),
                      ),
                    );
                  },
                  child: Stack(
                    alignment: Alignment.center,
                    children: [
                      Container(
                        color: Colors.black,
                      ),
                      const Icon(Icons.play_circle_fill,
                          color: Colors.white, size: 50),
                    ],
                  ),
                );
              } else {
                // 画像の場合
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
                  child: Image.network(
                    mediaUrl,
                    fit: BoxFit.cover,
                  ),
                );
              }
            }
          },
        );
      },
    );
  }
}

// 別ウィジェットとしてVideoPlayerScreenを作成
class VideoPlayerScreen extends StatefulWidget {
  final String videoUrl;

  const VideoPlayerScreen({Key? key, required this.videoUrl}) : super(key: key);

  @override
  _VideoPlayerScreenState createState() => _VideoPlayerScreenState();
}

class _VideoPlayerScreenState extends State<VideoPlayerScreen> {
  late VideoPlayerController _controller;
  bool _controlsVisible = true; // コントロールの表示/非表示
  late Future<void> _initializeVideoPlayerFuture;

  @override
  void initState() {
    super.initState();
    _controller = VideoPlayerController.network(widget.videoUrl);
    _initializeVideoPlayerFuture = _controller.initialize().then((_) {
      setState(() {}); // 初期化後に再描画
    });
    _controller.addListener(() {
      setState(() {}); // 再生位置の変更を検知して再描画
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  String _formatDuration(Duration duration) {
    String twoDigits(int n) => n.toString().padLeft(2, '0');
    final hours = duration.inHours;
    final minutes = duration.inMinutes.remainder(60);
    final seconds = duration.inSeconds.remainder(60);
    return [
      if (hours > 0) twoDigits(hours),
      twoDigits(minutes),
      twoDigits(seconds),
    ].join(':');
  }

  void _toggleControls() {
    setState(() {
      _controlsVisible = !_controlsVisible;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(),
      body: GestureDetector(
        onTap: _toggleControls,
        child: FutureBuilder<void>(
          future: _initializeVideoPlayerFuture,
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.done) {
              return Stack(
                alignment: Alignment.center,
                children: [
                  AspectRatio(
                    aspectRatio: _controller.value.aspectRatio,
                    child: VideoPlayer(_controller),
                  ),
                  _controlsVisible
                      ? Positioned(
                          bottom: 0,
                          left: 0,
                          right: 0,
                          child: Column(
                            children: [
                              VideoProgressIndicator(
                                _controller,
                                allowScrubbing: true,
                              ),
                              Padding(
                                padding: const EdgeInsets.all(8.0),
                                child: Row(
                                  mainAxisAlignment:
                                      MainAxisAlignment.spaceBetween,
                                  children: [
                                    Text(
                                      _formatDuration(
                                          _controller.value.position),
                                      style:
                                          const TextStyle(color: Colors.white),
                                    ),
                                    Text(
                                      _formatDuration(
                                          _controller.value.duration),
                                      style:
                                          const TextStyle(color: Colors.white),
                                    ),
                                  ],
                                ),
                              ),
                              IconButton(
                                iconSize: 64,
                                icon: Icon(
                                  _controller.value.isPlaying
                                      ? Icons.pause
                                      : Icons.play_arrow,
                                  color: Colors.white,
                                ),
                                onPressed: () {
                                  setState(() {
                                    _controller.value.isPlaying
                                        ? _controller.pause()
                                        : _controller.play();
                                  });
                                },
                              ),
                            ],
                          ),
                        )
                      : const SizedBox.shrink(),
                ],
              );
            } else {
              return const Center(child: CircularProgressIndicator());
            }
          },
        ),
      ),
    );
  }
}
