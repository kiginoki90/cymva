import 'dart:io';
import 'package:cymva/utils/firestore/posts.dart';
import 'package:cymva/utils/function_utils.dart';
import 'package:flutter/material.dart';
import 'package:cymva/model/post.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:image_picker/image_picker.dart';
import 'package:firebase_auth/firebase_auth.dart';

class RepostPage extends StatefulWidget {
  final Post post;
  final String userId;

  const RepostPage({Key? key, required this.post, required this.userId})
      : super(key: key);

  @override
  State<RepostPage> createState() => _RepostPageState();
}

class _RepostPageState extends State<RepostPage> {
  final TextEditingController _retweetController = TextEditingController();
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
    final pickedFiles = await FunctionUtils.getImagesFromGallery(context);

    if (pickedFiles != null) {
      setState(() {
        _mediaFiles = pickedFiles;
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

  @override
  void dispose() {
    _retweetController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('引用'),
      ),
      body: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.all(10.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // 引用部分を四角い枠線で囲む
              Padding(
                padding: const EdgeInsets.all(8.0),
                child: Container(
                  padding: const EdgeInsets.all(10.0),
                  decoration: BoxDecoration(
                    border: Border.all(
                      color: Colors.grey, // 枠線の色
                      width: 1.0, // 枠線の太さ
                    ),
                    borderRadius: BorderRadius.circular(8.0), // 角を丸くする
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // 投稿者のアイコンと名前を表示
                      Row(
                        children: [
                          if (_postAccountIconUrl != null)
                            GestureDetector(
                              child: ClipRRect(
                                borderRadius: BorderRadius.circular(8.0),
                                child: Image.network(
                                  _postAccountIconUrl! ??
                                      'https://firebasestorage.googleapis.com/v0/b/cymva-595b7.appspot.com/o/Lr2K2MmxmyZNjXheJ7mPfT2vXNh2?alt=media&token=100952df-1a76-4d22-a1e7-bf4e726cc344',
                                  width: 40,
                                  height: 40,
                                  fit: BoxFit.cover,
                                  errorBuilder: (context, error, stackTrace) {
                                    // 画像の取得に失敗した場合のエラービルダー
                                    return Image.network(
                                      'https://firebasestorage.googleapis.com/v0/b/cymva-595b7.appspot.com/o/Lr2K2MmxmyZNjXheJ7mPfT2vXNh2?alt=media&token=100952df-1a76-4d22-a1e7-bf4e726cc344',
                                      width: 40,
                                      height: 40,
                                      fit: BoxFit.cover,
                                    );
                                  },
                                ),
                              ),
                            ),
                          const SizedBox(width: 10),
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              if (_postAccountName != null)
                                Text(
                                  _postAccountName!.length > 25
                                      ? '${_postAccountName!.substring(0, 25)}...'
                                      : _postAccountName!,
                                  style: const TextStyle(
                                      fontWeight: FontWeight.bold),
                                  overflow: TextOverflow.ellipsis,
                                  maxLines: 1,
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
                      // 元の投稿内容を表示
                      Text(
                        widget.post.content,
                        style: const TextStyle(fontSize: 18),
                      ),
                      const SizedBox(height: 10),
                      // 画像がある場合は表示
                      if (widget.post.mediaUrl != null &&
                          widget.post.mediaUrl!.isNotEmpty) ...[
                        const SizedBox(height: 10),
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
                                  mediaUrl ??
                                      'https://firebasestorage.googleapis.com/v0/b/cymva-595b7.appspot.com/o/Lr2K2MmxmyZNjXheJ7mPfT2vXNh2?alt=media&token=100952df-1a76-4d22-a1e7-bf4e726cc344',
                                  width: MediaQuery.of(context).size.width *
                                      0.4, // 画像の幅を画面に合わせる
                                  height: 150, // 固定高さ
                                  fit: BoxFit.cover, // 画像のフィット方法
                                  errorBuilder: (context, error, stackTrace) {
                                    // 画像の取得に失敗した場合のエラービルダー
                                    return Image.network(
                                      'https://firebasestorage.googleapis.com/v0/b/cymva-595b7.appspot.com/o/Lr2K2MmxmyZNjXheJ7mPfT2vXNh2?alt=media&token=100952df-1a76-4d22-a1e7-bf4e726cc344',
                                      width: 40,
                                      height: 40,
                                      fit: BoxFit.cover,
                                    );
                                  },
                                ),
                              ),
                            );
                          },
                        ),
                      ],
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 20),
              // 引用テキストフィールド
              TextField(
                controller: _retweetController,
                maxLines: 5,
                decoration: const InputDecoration(
                  hintText: '引用コメント...',
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
              // 引用を送信するボタン
              ElevatedButton(
                onPressed: () async {
                  if (_retweetController.text.isNotEmpty ||
                      _mediaFiles.isNotEmpty) {
                    List<String>? mediaUrls;

                    // メディアが選択されている場合、Firebase Storageにアップロードする
                    if (_mediaFiles.isNotEmpty) {
                      mediaUrls = [];

                      for (var file in _mediaFiles) {
                        String? uploadedMediaUrl =
                            await FunctionUtils.uploadImage(
                                widget.userId, file, context);

                        if (uploadedMediaUrl != null) {
                          mediaUrls.add(uploadedMediaUrl);
                        }
                      }
                    }

                    // Firestoreに再投稿情報を追加する処理を実装
                    Post rePost = Post(
                      content: _retweetController.text,
                      postAccountId: widget.userId,
                      mediaUrl: mediaUrls,
                      repost: widget.post.id,
                    );

                    // Firestoreに返信を追加し、新しい投稿のIDを取得
                    String? rePostId = await PostFirestore.addPost(rePost);

                    if (rePostId != null) {
                      final rePostCollectionRef = FirebaseFirestore.instance
                          .collection('posts')
                          .doc(widget.post.postId != null &&
                                  widget.post.postId.isNotEmpty
                              ? widget.post.postId
                              : widget.post.id)
                          .collection('repost');

                      // サブコレクションにドキュメントを追加（存在しない場合は作成）
                      await rePostCollectionRef.doc(rePostId).set({
                        'id': rePostId,
                        'timestamp': FieldValue.serverTimestamp(),
                      });

                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('引用投稿が完了しました')),
                      );
                      Navigator.of(context).pop(); // 返信後に前の画面に戻る
                    } else {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('引用投稿に失敗しました')),
                      );
                    }
                  }
                },
                child: const Text('引用を送信'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
