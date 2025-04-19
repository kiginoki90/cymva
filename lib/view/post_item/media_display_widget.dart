import 'package:cymva/view/post_item/video_player_screen.dart';
import 'package:cymva/view/slide_direction_page_route.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:video_player/video_player.dart';
import 'package:visibility_detector/visibility_detector.dart';
import 'full_screen_image.dart';
import 'dart:async';
import 'dart:math';

class MediaDisplayWidget extends StatefulWidget {
  final List<String>? mediaUrl;
  final String category;
  final bool atStart;
  final bool? fullVideo;

  const MediaDisplayWidget({
    Key? key,
    required this.mediaUrl,
    required this.category,
    this.fullVideo = false,
    this.atStart = false,
  }) : super(key: key);

  @override
  _MediaDisplayWidgetState createState() => _MediaDisplayWidgetState();
}

class _MediaDisplayWidgetState extends State<MediaDisplayWidget> {
  Map<String, bool> _isVideoCache = {};
  Map<String, VideoPlayerController> _videoControllers = {};
  bool _isMuted = true;
  VideoPlayerController? _currentlyPlayingController;

  @override
  void initState() {
    super.initState();
    _loadVolumePreference();
    if (widget.mediaUrl != null && widget.mediaUrl!.isNotEmpty) {
      _initializeMedia();
    }
  }

  Future<void> _loadVolumePreference() async {
    final prefs = await SharedPreferences.getInstance();
    if (mounted) {
      setState(() {
        _isMuted = prefs.getBool('isMuted') ?? true;
      });
    }
  }

  Future<void> _saveVolumePreference(bool isMuted) async {
    final prefs = await SharedPreferences.getInstance();
    prefs.setBool('isMuted', isMuted);
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
    _videoControllers.clear();
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
        controller.setVolume(_isMuted ? 0.0 : 1.0);
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

  void _toggleVolume(VideoPlayerController controller) {
    setState(() {
      _isMuted = !_isMuted;
      controller.setVolume(_isMuted ? 0.0 : 1.0);
      _saveVolumePreference(_isMuted);
    });
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
                  return _buildPlaceholder(context);
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
    double maxHeight = min(screenWidth * 1.1, 500);

    return GestureDetector(
      onTap: () {
        Navigator.push(
          context,
          SlideDirectionPageRoute(
            page: FullScreenImagePage(
              imageUrls: widget.mediaUrl!,
              initialIndex: 0,
              unberBar: true,
            ),
            isSwipeUp: true,
          ),
        );
      },
      child: Stack(
        children: [
          Hero(
            tag: widget.mediaUrl![0], // ユニークなタグを設定
            child: Container(
              decoration: BoxDecoration(
                border: Border.all(
                  color: Colors.grey.shade300, // 薄いグレーのライン
                  width: 0.5, // ラインの太さ
                ),
              ),
              child: Image.network(
                widget.mediaUrl![0],
                width: screenWidth,
                height: maxHeight,
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
                  color: Colors.black.withValues(),
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
              child: Hero(
                tag: mediaUrl, // ユニークなタグを設定
                child: Container(
                  decoration: BoxDecoration(
                    border: Border.all(
                      color: Colors.grey.shade300, // 薄いグレーのライン
                      width: 0.5, // ラインの太さ
                    ),
                  ),
                  child: Image.network(
                    mediaUrl,
                    width: screenWidth,
                    height: screenWidth / aspectRatio, // 横長の場合はアスペクト比に基づいて高さを計算
                    fit: BoxFit.cover,
                  ),
                ),
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
              child: Hero(
                tag: mediaUrl, // ユニークなタグを設定
                child: Container(
                  decoration: BoxDecoration(
                    border: Border.all(
                      color: Colors.grey.shade300, // 薄いグレーのライン
                      width: 0.5, // ラインの太さ
                    ),
                  ),
                  child: Image.network(
                    mediaUrl,
                    width: screenWidth,
                    height: maxHeight, // 縦長の場合は幅と同じ高さ
                    fit: BoxFit.cover,
                  ),
                ),
              ),
            );
          }
        } else {
          // 画像が読み込まれていない場合の表示
          return _buildPlaceholder(context);
        }
      },
    );
  }

  // プレースホルダーを表示するウィジェット
  Widget _buildPlaceholder(BuildContext context) {
    double screenWidth = MediaQuery.of(context).size.width;
    return Container(
      width: screenWidth,
      height: min(screenWidth, 500),
      color: Colors.grey[300],
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
      return _buildPlaceholder(context);
    }

    double originalHeight = controller.value.size.height;
    double heightFactor = 1.0; // デフォルトは等倍表示

    // 高さに応じて縮小率を調整
    if (widget.fullVideo == false && originalHeight > 700) {
      if (originalHeight <= 777) {
        heightFactor = 0.9;
      } else if (originalHeight <= 880) {
        heightFactor = 0.8;
      } else if (originalHeight <= 1000) {
        heightFactor = 0.7;
      } else if (originalHeight <= 1180) {
        heightFactor = 0.6;
      } else if (originalHeight <= 1400) {
        heightFactor = 0.5;
      } else {
        heightFactor = 0.4;
      }
    }

    return GestureDetector(
      onTap: () {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => VideoPlayerScreen(
              videoUrl: mediaUrl,
            ),
          ),
        );
      },
      child: VisibilityDetector(
        key: Key(mediaUrl),
        onVisibilityChanged: (info) {
          if (widget.atStart == false) {
            if (info.visibleFraction > 0.8) {
              if (_currentlyPlayingController == null ||
                  !_currentlyPlayingController!.value.isPlaying) {
                if (!controller.value.isPlaying) {
                  controller.play();
                  _currentlyPlayingController = controller;
                }
              }
            } else {
              if (controller.value.isPlaying) {
                if (controller.value.isInitialized) {
                  // controller.pause();
                }
                if (_currentlyPlayingController == controller) {
                  _currentlyPlayingController = null;
                }
              }
            }
          }
        },
        child: Stack(
          alignment: Alignment.center,
          children: [
            ClipRect(
              child: Align(
                alignment: Alignment.center, // 上下の位置を調整
                heightFactor: heightFactor,
                child: AspectRatio(
                  aspectRatio: controller.value.aspectRatio,
                  child: Container(
                    decoration: BoxDecoration(
                      border: Border.all(
                        color: Colors.grey.shade300,
                        width: 0.5,
                      ),
                    ),
                    child: FittedBox(
                      fit: BoxFit.cover,
                      child: SizedBox(
                        width: controller.value.size.width,
                        height: controller.value.size.height,
                        child: VideoPlayer(controller),
                      ),
                    ),
                  ),
                ),
              ),
            ),
            Positioned(
              bottom: 10,
              right: 10,
              child: IconButton(
                icon: Icon(
                  _isMuted ? Icons.volume_off : Icons.volume_up,
                  color: Colors.white,
                ),
                onPressed: () => _toggleVolume(controller),
              ),
            ),
          ],
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
              return _buildPlaceholder(context);
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
                        builder: (context) => VideoPlayerScreen(
                          videoUrl: mediaUrl,
                        ),
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
                  child: Hero(
                    tag: mediaUrl, // ユニークなタグを設定
                    child: Container(
                      decoration: BoxDecoration(
                        border: Border.all(
                          color: Colors.grey.shade300, // 薄いグレーのライン
                          width: 0.5, // ラインの太さ
                        ),
                      ),
                      child: Image.network(
                        mediaUrl,
                        fit: BoxFit.cover,
                      ),
                    ),
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
