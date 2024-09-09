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

  // アイコン、名前、アカウントIDを格納するための変数
  String? _postAccountName;
  String? _postAccountIconUrl;
  String? _postAccountId;

  @override
  void initState() {
    super.initState();
    _fetchPostAccountInfo(); // 投稿者情報を取得
  }

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

  Future<void> _fetchPostAccountInfo() async {
    // Firestoreから投稿者の情報を取得
    final accountSnapshot = await FirebaseFirestore.instance
        .collection('users')
        .doc(widget.post.postAccountId)
        .get();

    if (accountSnapshot.exists) {
      setState(() {
        _postAccountName = accountSnapshot['name']; // 名前を取得
        _postAccountIconUrl = accountSnapshot['image_path']; // アイコン画像を取得
        _postAccountId = accountSnapshot['user_id']; // アカウントIDを取得
      });
    }
  }

  Future<void> _sendReply() async {
    if (_replyController.text.isNotEmpty || _mediaFile != null) {
      List<String>? mediaUrls;

      if (_mediaFile != null) {
        final String userId = FirebaseAuth.instance.currentUser!.uid;
        String? mediaUrl =
            await FunctionUtils.uploadImage(userId, _mediaFile!, context);

        if (mediaUrl != null) {
          mediaUrls = [mediaUrl]; // 画像がある場合はリストに追加
        }
      }

      Post replyPost = Post(
        content: _replyController.text,
        postAccountId: FirebaseAuth.instance.currentUser!.uid,
        mediaUrl: mediaUrls, // リストで渡す
        isVideo: isVideo,
        reply: widget.post.id,
      );

      String? replyPostId = await PostFirestore.addPost(replyPost);

      if (replyPostId != null) {
        final replyPostCollectionRef = FirebaseFirestore.instance
            .collection('posts')
            .doc(widget.post.id)
            .collection('reply_post');

        await replyPostCollectionRef.doc(replyPostId).set({
          'id': replyPostId,
          'timestamp': FieldValue.serverTimestamp(),
        });

        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('返信が完了しました')),
        );
        Navigator.of(context).pop();
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
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // 投稿者のアイコンと名前、アカウントIDを表示
                  Row(
                    children: [
                      if (_postAccountIconUrl != null)
                        CircleAvatar(
                          backgroundImage: NetworkImage(_postAccountIconUrl!),
                        ),
                      const SizedBox(width: 10),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          if (_postAccountName != null)
                            Text(
                              _postAccountName!,
                              style: const TextStyle(
                                  fontWeight: FontWeight.bold, fontSize: 15),
                            ),
                          if (_postAccountId != null)
                            Text(
                              '@$_postAccountId',
                              style: const TextStyle(
                                  color: Colors.grey, fontSize: 13),
                            ),
                        ],
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  Text(
                    widget.post.content,
                    style: const TextStyle(fontSize: 18),
                  ),
                  const SizedBox(height: 10),
                  // 複数のメディアがある場合に表示
                  if (widget.post.mediaUrl != null &&
                      widget.post.mediaUrl!.isNotEmpty)
                    for (String mediaUrl in widget.post.mediaUrl!)
                      Padding(
                        padding: const EdgeInsets.only(bottom: 10),
                        child: Image.network(
                          mediaUrl,
                          fit: BoxFit.cover,
                          width: double.infinity,
                        ),
                      ),
                ],
              ),
              const SizedBox(height: 20),
              TextField(
                controller: _replyController,
                maxLines: 5,
                decoration: const InputDecoration(
                  hintText: '返信を入力...',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 20),
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
