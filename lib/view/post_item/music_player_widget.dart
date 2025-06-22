import 'package:flutter/material.dart';
import 'package:audioplayers/audioplayers.dart';
import 'dart:async';

class MusicPlayerWidget extends StatefulWidget {
  final String musicUrl;
  final String? mediaUrl; // 画像のURLをオプションとして追加

  const MusicPlayerWidget({Key? key, required this.musicUrl, this.mediaUrl})
      : super(key: key);

  @override
  _MusicPlayerWidgetState createState() => _MusicPlayerWidgetState();
}

class _MusicPlayerWidgetState extends State<MusicPlayerWidget>
    with SingleTickerProviderStateMixin {
  final AudioPlayer _audioPlayer = AudioPlayer();
  bool isPlaying = false;
  bool showIcon = true; // アイコンの表示状態を管理
  Duration currentPosition = Duration.zero;
  Duration totalDuration = Duration.zero;
  late AnimationController _animationController;

  @override
  void initState() {
    super.initState();

    // アニメーションコントローラーを初期化
    _animationController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 1), // じんわり消えるアニメーションの時間
    );

    // 再生位置を監視
    _audioPlayer.onPositionChanged.listen((Duration position) {
      setState(() {
        currentPosition = position;
      });
    });

    // 音楽の総時間を監視
    _audioPlayer.onDurationChanged.listen((Duration duration) {
      setState(() {
        totalDuration = duration;
      });
    });
  }

  @override
  void dispose() {
    _audioPlayer.dispose(); // オーディオプレイヤーを破棄
    _animationController.dispose(); // アニメーションコントローラーを破棄
    super.dispose();
  }

  void _togglePlayPause() async {
    if (isPlaying) {
      await _audioPlayer.pause(); // 再生を停止
    } else {
      await _audioPlayer.play(UrlSource(widget.musicUrl)); // 再生を開始
    }
    setState(() {
      isPlaying = !isPlaying; // 再生状態を切り替え
      if (widget.mediaUrl != null && widget.mediaUrl!.isNotEmpty) {
        showIcon = true; // アイコンを表示
        _animationController.forward(); // アニメーション開始
        Timer(const Duration(seconds: 2), () {
          _animationController.reverse(); // アニメーションでアイコンをじんわり消す
          setState(() {
            showIcon = false; // アイコンを非表示
          });
        });
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    double containerWidth = MediaQuery.of(context).size.width * 0.6;

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        GestureDetector(
          onTap: _togglePlayPause, // タップで再生/停止を切り替え
          child: Stack(
            alignment: Alignment.center, // アイコンを常に中央に配置
            children: [
              Container(
                width: containerWidth, // 幅を設定
                height: containerWidth, // 高さを幅と同じに設定
                decoration: BoxDecoration(
                  color: const Color.fromARGB(255, 255, 255, 255), // 背景色
                  borderRadius: BorderRadius.circular(8.0), // 角丸
                  border: Border.all(color: Colors.grey, width: 2.0), // 枠線
                ),
                child: widget.mediaUrl != null && widget.mediaUrl!.isNotEmpty
                    ? ClipRRect(
                        borderRadius: BorderRadius.circular(8.0), // 画像の角丸
                        child: Image.network(
                          widget.mediaUrl!, // `media_url` を使用して画像を表示
                          width: containerWidth,
                          height: containerWidth,
                          fit: BoxFit.cover, // 画像をコンテナにフィット
                          errorBuilder: (context, error, stackTrace) {
                            return const SizedBox(); // 画像取得エラー時は空のコンテナ
                          },
                        ),
                      )
                    : const SizedBox(), // mediaUrl がない場合は空のコンテナ
              ),
              // 常に中央に音符アイコンを表示
              Icon(
                isPlaying ? Icons.music_note : Icons.music_off, // 再生中/停止中のアイコン
                size: 50,
                color: Colors.grey, // アイコンの色
              ),
            ],
          ),
        ),
        const SizedBox(height: 10),
        Slider(
          value: currentPosition.inSeconds.toDouble(),
          max: totalDuration.inSeconds.toDouble(),
          onChanged: (value) async {
            await _audioPlayer
                .seek(Duration(seconds: value.toInt())); // シークバーで位置を変更
          },
        ),
        Text(
          '${_formatDuration(currentPosition)} / ${_formatDuration(totalDuration)}', // 残り時間と総時間を表示
          style: const TextStyle(fontSize: 14, color: Colors.grey),
        ),
      ],
    );
  }

  String _formatDuration(Duration duration) {
    String twoDigits(int n) => n.toString().padLeft(2, '0');
    final minutes = twoDigits(duration.inMinutes.remainder(60));
    final seconds = twoDigits(duration.inSeconds.remainder(60));
    return '$minutes:$seconds';
  }
}
