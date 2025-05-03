import 'package:flutter/material.dart';
import 'package:video_player/video_player.dart';

class VideoPlayerScreen extends StatefulWidget {
  final String videoUrl;

  const VideoPlayerScreen({Key? key, required this.videoUrl}) : super(key: key);

  @override
  _VideoPlayerScreenState createState() => _VideoPlayerScreenState();
}

class _VideoPlayerScreenState extends State<VideoPlayerScreen> {
  late VideoPlayerController _controller;
  bool _isPlaying = false;
  bool _isMuted = false;
  bool _controlsVisible = true;

  @override
  void initState() {
    super.initState();
    _controller =
        VideoPlayerController.networkUrl(Uri.parse(widget.videoUrl)) // 修正
          ..initialize().then((_) {
            setState(() {}); // 動画が初期化されたら再描画
          });
    _controller.setVolume(0.0); // 音量をデフォルトでオフに設定
    _isMuted = true; // デフォルトでミュート状態に設定
  }

  @override
  void dispose() {
    if (_controller.value.isInitialized) {
      _controller.dispose(); // コントローラのリソースを解放
    }
    super.dispose();
  }

  void _togglePlayPause() {
    setState(() {
      if (_controller.value.isPlaying) {
        _controller.pause();
        _isPlaying = false;
      } else {
        _controller.play();
        _isPlaying = true;
      }
    });
  }

  void _toggleMute() {
    setState(() {
      _isMuted = !_isMuted;
      _controller.setVolume(_isMuted ? 0.0 : 1.0);
    });
  }

  void _toggleControlsVisibility() {
    setState(() {
      _controlsVisible = !_controlsVisible;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      body: GestureDetector(
        onTap: _toggleControlsVisibility,
        child: Center(
          child: _controller.value.isInitialized
              ? Stack(
                  alignment: Alignment.center,
                  children: [
                    AspectRatio(
                      aspectRatio: _controller.value.aspectRatio,
                      child: VideoPlayer(_controller),
                    ),
                    AnimatedOpacity(
                      opacity: _controlsVisible ? 1.0 : 0.0,
                      duration: const Duration(milliseconds: 500), // 0.5秒に変更
                      child: Stack(
                        children: [
                          // 再生・停止ボタン
                          Center(
                            child: Container(
                              decoration: BoxDecoration(
                                color: Colors.grey.withAlpha(128), // グレーの枠を追加
                                shape: BoxShape.circle,
                              ),
                              child: IconButton(
                                iconSize: 64,
                                icon: Icon(
                                  _isPlaying ? Icons.pause : Icons.play_arrow,
                                  color: Colors.white,
                                ),
                                onPressed: _togglePlayPause,
                              ),
                            ),
                          ),
                          // 音量ボタン
                          Positioned(
                            bottom: 40, // 音量ボタンの位置を調整
                            right: 20,
                            child: Container(
                              decoration: BoxDecoration(
                                color: Colors.grey.withAlpha(128),
                                shape: BoxShape.circle,
                              ),
                              child: IconButton(
                                icon: Icon(
                                  _isMuted ? Icons.volume_off : Icons.volume_up,
                                  color: Colors.white,
                                ),
                                onPressed: _toggleMute,
                              ),
                            ),
                          ),
                          // 動画を最初に戻すボタン
                          Positioned(
                            bottom: 100, // 音量ボタンの上に配置
                            right: 20,
                            child: Container(
                              decoration: BoxDecoration(
                                color: Colors.grey.withAlpha(128),
                                shape: BoxShape.circle,
                              ),
                              child: IconButton(
                                icon: const Icon(
                                  Icons.replay,
                                  color: Colors.white,
                                ),
                                onPressed: () {
                                  _controller.seekTo(Duration.zero); // 動画を最初に戻す
                                  if (!_controller.value.isPlaying) {
                                    _controller.play(); // 再生を開始
                                    setState(() {
                                      _isPlaying = true;
                                    });
                                  }
                                },
                              ),
                            ),
                          ),
                          // スクロールバー
                          Positioned(
                            bottom: 80, // スクロールバーの位置を少し上に調整
                            left: 10,
                            right: 80, // 音量ボタンのスペースを確保
                            child: VideoProgressIndicator(
                              _controller,
                              allowScrubbing: true,
                              colors: VideoProgressColors(
                                playedColor: Colors.white,
                                backgroundColor: Colors.grey,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                )
              : const CircularProgressIndicator(), // 動画が初期化されるまでローディング表示
        ),
      ),
    );
  }
}
