import 'dart:io';
import 'package:flutter/material.dart';
import 'package:cymva/model/post.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:image_picker/image_picker.dart';
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
  String? _postAccountName;
  String? _postAccountIconUrl;
  String? _postAccountId;
  List<File> _mediaFiles = [];
  final picker = ImagePicker();

  @override
  void initState() {
    super.initState();
    _fetchPostAccountInfo();
  }

  Future<void> _pickMedia() async {
    final pickedFiles = await picker.pickMultiImage();
    if (pickedFiles != null) {
      setState(() {
        _mediaFiles = pickedFiles.map((file) => File(file.path)).toList();
      });
    }
  }

  Future<void> _fetchPostAccountInfo() async {
    // Firestoreから投稿者の情報を取得
    final accountSnapshot = await FirebaseFirestore.instance
        .collection('users')
        .doc(widget.post.postAccountId)
        .get();

    if (accountSnapshot.exists) {
      setState(() {
        _postAccountName = accountSnapshot['name'];
        _postAccountIconUrl = accountSnapshot['image_path'];
        _postAccountId = accountSnapshot['user_id'];
      });
    }
  }

  Future<void> _sendReply() async {
    if (_replyController.text.isNotEmpty || _mediaFiles.isNotEmpty) {
      List<String>? mediaUrls;

      // メディアが選択されている場合、Firebase Storageにアップロードする
      if (_mediaFiles.isNotEmpty) {
        final String userId = FirebaseAuth.instance.currentUser!.uid;
        mediaUrls = [];

        for (var file in _mediaFiles) {
          String? uploadedMediaUrl =
              await FunctionUtils.uploadImage(userId, file, context);

          if (uploadedMediaUrl != null) {
            mediaUrls.add(uploadedMediaUrl);
          }
        }
      }

      // Firestoreに返信情報を追加する処理を実装
      Post replyPost = Post(
        content: _replyController.text,
        postAccountId: FirebaseAuth.instance.currentUser!.uid,
        mediaUrl: mediaUrls,
        reply: widget.post.id,
      );

      // Firestoreに返信を追加し、新しい投稿のIDを取得
      String? replyPostId = await PostFirestore.addPost(replyPost);

      if (replyPostId != null) {
        final replyPostCollectionRef = FirebaseFirestore.instance
            .collection('posts')
            .doc(replyPost.reply)
            .collection('reply_post');

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
                        GestureDetector(
                          child: ClipRRect(
                            borderRadius: BorderRadius.circular(8.0),
                            child: Image.network(
                              _postAccountIconUrl!,
                              width: 40,
                              height: 40,
                              fit: BoxFit.cover,
                            ),
                          ),
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
                    GridView.builder(
                      physics:
                          const NeverScrollableScrollPhysics(), // グリッド内でのスクロールを無効に
                      shrinkWrap: true, // グリッドのサイズを内容に合わせる
                      itemCount: widget.post.mediaUrl!.length,
                      gridDelegate:
                          const SliverGridDelegateWithFixedCrossAxisCount(
                        crossAxisCount: 2, // グリッドの列数を2に設定
                      ),
                      itemBuilder: (BuildContext context, int index) {
                        final mediaUrl = widget.post.mediaUrl![index];
                        return GestureDetector(
                          child: ClipRRect(
                            child: Image.network(
                              mediaUrl,
                              width: MediaQuery.of(context).size.width *
                                  0.4, // 画像の幅を画面に合わせる
                              height: 150, // 固定高さ
                              fit: BoxFit.cover,
                            ),
                          ),
                        );
                      },
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
              // メディア選択ボタン
              ElevatedButton(
                onPressed: _pickMedia,
                child: const Text('画像を選択'),
              ),
              if (_mediaFiles.isNotEmpty)
                SizedBox(
                  height: 150,
                  child: GridView.builder(
                    itemCount: _mediaFiles.length,
                    gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                      crossAxisCount: 3,
                      crossAxisSpacing: 4,
                      mainAxisSpacing: 4,
                    ),
                    itemBuilder: (BuildContext context, int index) {
                      return Image.file(
                        _mediaFiles[index],
                        width: 150,
                        height: 150,
                        fit: BoxFit.cover,
                      );
                    },
                  ),
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
