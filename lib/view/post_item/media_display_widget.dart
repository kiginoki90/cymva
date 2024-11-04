import 'package:cymva/view/slide_direction_page_route.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/material.dart';
import 'package:video_player/video_player.dart';
import 'package:visibility_detector/visibility_detector.dart';
import 'full_screen_image.dart';
import 'dart:async';

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
  Map<String, bool> _isVideoCache = {};
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
    _disposeVideoControllers();
    super.dispose();
  }

  // すべてのビデオコントローラを破棄する
  void _disposeVideoControllers() {
    for (var controller in _videoControllers.values) {
      controller.dispose();
    }
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
    if (!_videoControllers.containsKey(videoUrl)) {
      final controller = VideoPlayerController.networkUrl(Uri.parse(videoUrl));
      _videoControllers[videoUrl] = controller;
      controller.initialize().then((_) {
        if (mounted) {
          setState(() {}); // ビデオコントローラの初期化後に再描画
        }
      }).catchError((error) {
        print('Error initializing video: $error');
      });
    }
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
    double screenWidth = MediaQuery.of(context).size.width;
    double maxHeight = screenWidth * 1.3;

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
            width: screenWidth, // 横幅を画面幅に合わせる
            height: maxHeight, // 縦の最大値を1.5倍に設定
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
    return FutureBuilder<ImageInfo>(
      future: _loadImageInfo(mediaUrl), // 画像の情報を取得する非同期関数
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.done &&
            snapshot.hasData) {
          final imageWidth = snapshot.data!.image.width.toDouble();
          final imageHeight = snapshot.data!.image.height.toDouble();

          double screenWidth = MediaQuery.of(context).size.width;

          // アスペクト比を計算
          double aspectRatio = imageWidth / imageHeight;

          // 横長の場合 (アスペクト比が1以上)
          if (aspectRatio >= 1) {
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
                width: screenWidth,
                height: screenWidth / aspectRatio, // 横長の場合はアスペクト比に基づいて高さを計算
                fit: BoxFit.cover,
              ),
            );
          }
          // 縦長の場合 (アスペクト比が1未満)
          else {
            double maxHeight = screenWidth * 0.8;

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
                width: screenWidth,
                height: maxHeight, // 縦長の場合は幅と同じ高さ
                fit: BoxFit.cover,
              ),
            );
          }
        } else {
          // 画像が読み込まれていない場合の表示
          return Center(child: CircularProgressIndicator());
        }
      },
    );
  }

// 画像の情報を取得するための非同期関数
  Future<ImageInfo> _loadImageInfo(String mediaUrl) async {
    Completer<ImageInfo> completer = Completer();
    final imageProvider = NetworkImage(mediaUrl);
    imageProvider.resolve(ImageConfiguration()).addListener(
      ImageStreamListener((ImageInfo imageInfo, bool synchronousCall) {
        completer.complete(imageInfo);
      }),
    );
    return completer.future;
  }

  Widget _buildSingleVideo(BuildContext context, String mediaUrl) {
    final controller = _videoControllers[mediaUrl];
    if (controller == null || !controller.value.isInitialized) {
      return const Center(child: CircularProgressIndicator());
    }

    return GestureDetector(
      onTap: () {
        if (controller.value.isPlaying) {
          controller.pause(); // 動画が再生中の場合は一時停止
        } else {
          controller.play(); // 動画が停止中の場合は再生
        }
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => VideoPlayerScreen(videoUrl: mediaUrl),
          ),
        );
      },
      child: VisibilityDetector(
        key: Key(mediaUrl),
        onVisibilityChanged: (info) {
          if (info.visibleFraction > 0.5) {
            if (!controller.value.isPlaying) {
              // 動画が50%以上表示された場合、初期化のみ行い、自動再生はさせない
              _initializeVideo(mediaUrl);
            }
          } else {
            // 50%未満表示の場合、再生中なら一時停止
            if (controller.value.isPlaying) {
              controller.pause();
            }
          }
        },
        child: Container(
          width: double.infinity,
          height: MediaQuery.of(context).size.width,
          child: ClipRect(
            child: Align(
              alignment: Alignment.center,
              widthFactor: 1.0,
              heightFactor: 1.0,
              child: AspectRatio(
                aspectRatio: controller.value.aspectRatio, // 動画のアスペクト比に合わせる
                child: VideoPlayer(controller),
              ),
            ),
          ),
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
    _controller = VideoPlayerController.networkUrl(Uri.parse(widget.videoUrl));
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
      backgroundColor: Colors.black, // 背景色を黒に設定
      appBar: AppBar(
        backgroundColor: Colors.black, // AppBarも黒に設定
      ),
      body: SafeArea(
        child: GestureDetector(
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
                    // 中央に再生・停止ボタンを配置
                    Positioned(
                      child: _controlsVisible
                          ? Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
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
                            )
                          : const SizedBox.shrink(),
                    ),
                    // 最下部に時間のバーを配置
                    Positioned(
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
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Text(
                                  _formatDuration(_controller.value.position),
                                  style: const TextStyle(color: Colors.white),
                                ),
                                Text(
                                  _formatDuration(_controller.value.duration),
                                  style: const TextStyle(color: Colors.white),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                );
              } else {
                return const Center(child: CircularProgressIndicator());
              }
            },
          ),
        ),
      ),
    );
  }
}
