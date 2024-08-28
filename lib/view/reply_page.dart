import 'dart:io';
import 'package:flutter/material.dart';
import 'package:cymva/model/post.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:image_picker/image_picker.dart';
import 'package:video_player/video_player.dart';
import 'package:cymva/utils/function_utils.dart';
import 'package:cymva/utils/firestore/posts.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class ReplyPage extends StatefulWidget {
  final Post post;

  const ReplyPage({Key? key, required this.post}) : super(key: key);

  @override
  State<ReplyPage> createState() => _ReplyPageState();
}

class _ReplyPageState extends State<ReplyPage> {
  final TextEditingController _replyController = TextEditingController();
  File? _mediaFile;
  final picker = ImagePicker();
  bool isVideo = false;
  VideoPlayerController? _videoController;
  bool isPickerActive = false;

  Future getMedia(bool isVideo) async {
    if (isPickerActive) return;
    setState(() {
      isPickerActive = true;
    });

    File? pickedFile;
    if (isVideo) {
      final videoFile = await picker.pickVideo(source: ImageSource.gallery);
      if (videoFile != null) {
        pickedFile = File(videoFile.path);
      }
    } else {
      pickedFile = await FunctionUtils.getImageFromGallery(context);
    }

    setState(() {
      if (pickedFile != null) {
        _mediaFile = pickedFile;
        this.isVideo = isVideo;

        if (isVideo) {
          _videoController = VideoPlayerController.file(_mediaFile!)
            ..initialize().then((_) {
              setState(() {});
              _videoController!.play();
            });
        }
      } else {
        print('No media selected or file too large.');
      }
      isPickerActive = false;
    });
  }

  Future<void> _sendReply() async {
    if (_replyController.text.isNotEmpty || _mediaFile != null) {
      String? mediaUrl;
      if (_mediaFile != null) {
        final String userId = FirebaseAuth.instance.currentUser!.uid;
        mediaUrl =
            await FunctionUtils.uploadImage(userId, _mediaFile!, context);
      }

      // 返信ポストとして新しい投稿を作成
      Post replyPost = Post(
        content: _replyController.text,
        postAccountId: FirebaseAuth.instance.currentUser!.uid,
        mediaUrl: mediaUrl,
        isVideo: isVideo,
        reply: widget.post.id,
      );

      // Firestoreに返信を追加し、新しい投稿のIDを取得
      String? replyPostId = await PostFirestore.addPost(replyPost);

      if (replyPostId != null) {
        final replyPostCollectionRef = FirebaseFirestore.instance
            .collection('posts')
            .doc(widget.post.id)
            .collection('reply_post');

        // サブコレクションにドキュメントを追加（存在しない場合は作成）
        await replyPostCollectionRef.doc(replyPostId).set({
          'id': replyPostId,
          'timestamp': FieldValue.serverTimestamp(),
        });

        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('返信が完了しました')),
        );
        Navigator.of(context).pop(); // 返信後に前の画面に戻る
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('返信に失敗しました')),
        );
      }
    }
  }

  @override
  void dispose() {
    _replyController.dispose();
    _videoController?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('返信'),
      ),
      body: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.all(10.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // 投稿内容を表示
              Text(
                widget.post.content,
                style:
                    const TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
              ),
              const SizedBox(height: 10),
              // 画像がある場合は表示
              if (widget.post.mediaUrl != null && !widget.post.isVideo)
                Padding(
                  padding: const EdgeInsets.only(bottom: 10),
                  child: Image.network(
                    widget.post.mediaUrl!,
                    fit: BoxFit.cover,
                    width: double.infinity,
                  ),
                ),
              // 動画がある場合は表示
              if (widget.post.isVideo && widget.post.mediaUrl != null)
                AspectRatio(
                  aspectRatio: 16 / 9,
                  child: VideoPlayer(VideoPlayerController.networkUrl(
                      Uri.parse(widget.post.mediaUrl!))),
                ),
              const SizedBox(height: 20),
              // 返信テキストフィールド
              TextField(
                controller: _replyController,
                maxLines: 5,
                decoration: const InputDecoration(
                  hintText: '返信を入力...',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 20),
              // メディアが選択されている場合の表示
              if (_mediaFile != null)
                isVideo
                    ? _videoController != null &&
                            _videoController!.value.isInitialized
                        ? AspectRatio(
                            aspectRatio: _videoController!.value.aspectRatio,
                            child: VideoPlayer(_videoController!),
                          )
                        : CircularProgressIndicator()
                    : Container(
                        width: 150,
                        height: 150,
                        child: Image.file(
                          _mediaFile!,
                          fit: BoxFit.cover,
                        ),
                      ),
              const SizedBox(height: 20),
              // メディア選択ボタン
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  ElevatedButton(
                    onPressed: () => getMedia(false),
                    child: const Text('画像を選択'),
                  ),
                  ElevatedButton(
                    onPressed: () => getMedia(true),
                    child: const Text('ビデオを選択'),
                  ),
                ],
              ),
              const SizedBox(height: 20),
              // 返信を送信するボタン
              ElevatedButton(
                onPressed: _sendReply,
                child: const Text('返信を送信'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
