import 'package:cymva/model/post.dart';
import 'package:cymva/view/post_item/video_player_screen.dart';
import 'package:cymva/view/slide_direction_page_route.dart';
import 'package:device_info_plus/device_info_plus.dart';
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
  final Post? post;
  final bool is_video;

  const MediaDisplayWidget({
    Key? key,
    required this.mediaUrl,
    required this.category,
    this.fullVideo = false,
    this.atStart = false,
    required this.post,
    this.is_video = false,
  }) : super(key: key);

  @override
  _MediaDisplayWidgetState createState() => _MediaDisplayWidgetState();
}

class _MediaDisplayWidgetState extends State<MediaDisplayWidget> {
  Map<String, bool> _isVideoCache = {};
  Map<String, VideoPlayerController> _videoControllers = {};
  bool _isMuted = true;
  VideoPlayerController? _currentlyPlayingController;
  late AndroidDeviceInfo androidInfo;

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
    _disposeVideoControllers();
    super.dispose();
  }

  void _disposeVideoControllers() {
    for (var controller in _videoControllers.values) {
      if (controller.value.isInitialized) {
        controller.dispose();
      }
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
          controller.setVolume(_isMuted ? 0.0 : 1.0);
          setState(() {}); // ビデオコントローラの初期化後に再描画
        }
      }).catchError((error) {
        print('動画の初期化中にエラーが発生しました: $error');
      });
    }
  }

  Future<bool> _isVideo(String url) async {
    if (_isVideoCache.containsKey(url)) {
      return _isVideoCache[url]!;
    }

    try {
      final ref = FirebaseStorage.instance.refFromURL(url);
      final metadata = await ref.getMetadata();
      final contentType = metadata.contentType;

      bool isVideo = contentType != null && contentType.startsWith('video/');
      _isVideoCache[url] = isVideo;
      return isVideo;
    } catch (e) {
      print('Error retrieving metadata: $e');
      _isVideoCache[url] = false;
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

  // Future<int> _getVideoRotation(String videoUrl) async {
  //   try {
  //     final MethodChannel channel = MethodChannel('video_rotation');
  //     final int rotation =
  //         await channel.invokeMethod('getVideoRotation', videoUrl);
  //     return rotation;
  //   } catch (e) {
  //     print('ビデオ回転取得エラー: $e');
  //     return 0; // デフォルトで回転なし
  //   }
  // }

  // double _getCorrectedAspectRatio(
  //     VideoPlayerController controller, int rotation) {
  //   final size = controller.value.size;
  //   final aspectRatio = controller.value.aspectRatio;

  //   // 回転情報を考慮して縦横比を補正
  //   if (rotation == 90 || rotation == 270) {
  //     return 1 / aspectRatio; // 縦横を反転
  //   }
  //   return aspectRatio;
  // }

  double _calculateHeightFactor(double originalHeight) {
    if (widget.fullVideo == false) {
      return 1.0;
    }

    if (originalHeight <= 700) {
      return 1.0;
    } else if (originalHeight <= 777) {
      return 0.9;
    } else if (originalHeight <= 880) {
      return 0.8;
    } else if (originalHeight <= 1000) {
      return 0.7;
    } else if (originalHeight <= 1180) {
      return 0.6;
    } else if (originalHeight <= 1400) {
      return 0.5;
    } else {
      return 0.4;
    }
  }

  @override
  Widget build(BuildContext context) {
    if (widget.mediaUrl == null || widget.mediaUrl!.isEmpty) {
      return const SizedBox.shrink();
    }

    if (widget.category == '漫画' && widget.is_video == false) {
      return _buildMangaMedia(context);
    } else if (widget.mediaUrl!.length == 1) {
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
                      ? _buildSingleVideo(context, mediaUrl)
                      : _buildSingleMedia(context, mediaUrl);
                }
              },
            );
    } else {
      return _buildMultipleMedia(context);
    }
  }

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
          Container(
            decoration: BoxDecoration(
              border: Border.all(
                color: Colors.grey.shade300,
                width: 0.5,
              ),
            ),
            child: Image.network(
              widget.mediaUrl![0],
              width: screenWidth,
              height: maxHeight,
              fit: BoxFit.cover,
              errorBuilder: (context, error, stackTrace) {
                return const Center(
                  child: Icon(
                    Icons.error, // エラー時のアイコン
                    size: 50,
                    color: Colors.red,
                  ),
                );
              },
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
                  color: const Color(0xFF000000).withAlpha(138),
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

  Widget _buildSingleMedia(BuildContext context, String mediaUrl) {
    const double maxHeightFactor = 1.3;

    return FutureBuilder<ImageInfo>(
      future: _loadImageInfo(mediaUrl),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.done &&
            snapshot.hasData) {
          final imageWidth = snapshot.data!.image.width.toDouble();
          final imageHeight = snapshot.data!.image.height.toDouble();
          final aspectRatio = imageWidth / imageHeight;

          // 最大高さを計算
          final double maxHeight = imageWidth * maxHeightFactor;

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
            child: Container(
              decoration: BoxDecoration(
                border: Border.all(
                  color: Colors.grey.shade300,
                  width: 0.5,
                ),
              ),
              child: ClipRect(
                child: Align(
                  alignment: Alignment.center,
                  heightFactor: imageHeight > maxHeight
                      ? maxHeight / imageHeight
                      : 1.0, // 高さをトリミング
                  child: AspectRatio(
                    aspectRatio: aspectRatio, // 縦横比を維持
                    child: Image.network(
                      mediaUrl,
                      width: double.infinity, // 横幅を全て表示
                      fit: BoxFit.cover,
                      errorBuilder: (context, error, stackTrace) {
                        return const Center(
                          child: Icon(
                            Icons.error, // エラー時のアイコン
                            size: 50,
                            color: Colors.red,
                          ),
                        );
                      },
                    ),
                  ),
                ),
              ),
            ),
          );
        } else {
          return _buildPlaceholder(context);
        }
      },
    );
  }

  Widget _buildPlaceholder(BuildContext context) {
    double screenWidth = MediaQuery.of(context).size.width;

    // アスペクト比を計算して高さを設定
    double placeholderHeight;

    if (widget.post?.imageWidth != null && widget.post?.imageHeight != null) {
      // アスペクト比を計算
      double aspectRatio = widget.post!.imageWidth! / widget.post!.imageHeight!;
      double originalHeight = screenWidth / aspectRatio;

      // 動画かどうかを判定
      if (widget.mediaUrl != null &&
          widget.mediaUrl!.isNotEmpty &&
          _isVideoCache[widget.mediaUrl!.first] == true) {
        // アスペクト比を計算
        double aspectRatio =
            widget.post!.imageWidth! / widget.post!.imageHeight!;

        // widget.post?.imageHeight を _calculateHeightFactor で調整
        double adjustedHeight = widget.post!.imageHeight! *
            _calculateHeightFactor(widget.post!.imageHeight!.toDouble());

        // 調整後の高さからアスペクト比を考慮して placeholderHeight を計算
        placeholderHeight = screenWidth /
            aspectRatio *
            (adjustedHeight / widget.post!.imageHeight!);
      } else {
        // 画像の場合はそのままの高さ
        placeholderHeight = originalHeight;
      }
    } else {
      // デフォルトの高さ
      placeholderHeight = min(screenWidth, 300);
    }
    // 縦幅の最大値を横幅の1.2倍に制限
    double maxHeight = screenWidth * 1.2;
    placeholderHeight = min(placeholderHeight, maxHeight);

    return Container(
      width: screenWidth,
      height: placeholderHeight,
      color: Colors.grey[300],
    );
  }

  Future<ImageInfo> _loadImageInfo(String mediaUrl) async {
    Completer<ImageInfo> completer = Completer();
    final imageProvider = NetworkImage(mediaUrl);
    imageProvider.resolve(ImageConfiguration()).addListener(
          ImageStreamListener(
            (ImageInfo imageInfo, bool synchronousCall) {
              completer.complete(imageInfo);
            },
            onError: (error, stackTrace) {
              completer.completeError(error, stackTrace);
            },
          ),
        );

    return completer.future;
  }

  Widget _buildSingleVideo(BuildContext context, String mediaUrl) {
    final controller = _videoControllers[mediaUrl];
    if (controller == null || !controller.value.isInitialized) {
      return _buildPlaceholder(context);
    }

    // 高さと幅を取得
    final double adjustedHeight =
        (widget.post?.imageHeight != null && widget.post?.imageWidth != null)
            ? widget.post!.imageHeight!.toDouble() // imageHeightが存在する場合はそれを使用
            : controller.value.size.height; // デフォルトはcontrollerの高さ

    final double adjustedWidth =
        (widget.post?.imageHeight != null && widget.post?.imageWidth != null)
            ? widget.post!.imageWidth!.toDouble() // imageWidthが存在する場合はそれを使用
            : controller.value.size.width; // デフォルトはcontrollerの幅

    // 高さ制限を計算
    final heightFactor = _calculateHeightFactor(adjustedHeight); // 調整された高さを渡す

    return GestureDetector(
      onTap: () {
        if (controller.value.isPlaying) {
          controller.pause();
        }
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => VideoPlayerScreen(
              videoUrl: mediaUrl,
              isMuted: _isMuted,
              aspectRatio: adjustedWidth / adjustedHeight, // 縦横比を計算して渡す
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
              if (controller.value.isInitialized &&
                  controller.value.isPlaying) {
                controller.pause();
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
                alignment: Alignment.center,
                heightFactor: heightFactor, // 高さ制限を適用
                child: AspectRatio(
                  aspectRatio: adjustedWidth / adjustedHeight, // 縦横比を使用
                  child: Container(
                    decoration: BoxDecoration(
                      border: Border.all(
                        color: Colors.grey.shade300,
                        width: 0.5,
                      ),
                    ),
                    child: controller.value.isInitialized
                        ? VideoPlayer(controller)
                        : const Center(
                            child: CircularProgressIndicator(),
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
                onPressed: () {
                  _toggleVolume(controller);
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

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
                final controller = _videoControllers[mediaUrl];
                if (controller == null || !controller.value.isInitialized) {
                  return _buildPlaceholder(context);
                }

                final aspectRatio = controller.value.aspectRatio;

                return GestureDetector(
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => VideoPlayerScreen(
                          videoUrl: mediaUrl,
                          aspectRatio: aspectRatio, // 縦横比を渡す
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
                return FutureBuilder<ImageInfo>(
                  future: _loadImageInfo(mediaUrl),
                  builder: (context, imageSnapshot) {
                    if (imageSnapshot.connectionState == ConnectionState.done &&
                        imageSnapshot.hasData) {
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
                        child: Container(
                          decoration: BoxDecoration(
                            border: Border.all(
                              color: Colors.grey.shade300,
                              width: 0.5,
                            ),
                          ),
                          child: Image.network(
                            mediaUrl,
                            fit: BoxFit.cover,
                            errorBuilder: (context, error, stackTrace) {
                              return const Center(
                                child: Icon(
                                  Icons.error, // エラー時のアイコン
                                  size: 50,
                                  color: Colors.red,
                                ),
                              );
                            },
                          ),
                        ),
                      );
                    } else {
                      return _buildPlaceholder(context);
                    }
                  },
                );
              }
            }
          },
        );
      },
    );
  }
}
