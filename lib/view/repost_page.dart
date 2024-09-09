import 'dart:io';
import 'package:cymva/utils/firestore/posts.dart';
import 'package:cymva/utils/function_utils.dart';
import 'package:flutter/material.dart';
import 'package:cymva/model/post.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:image_picker/image_picker.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:firebase_auth/firebase_auth.dart';

class RepostPage extends StatefulWidget {
  final Post post;

  const RepostPage({Key? key, required this.post}) : super(key: key);

  @override
  State<RepostPage> createState() => _RepostPageState();
}

class _RepostPageState extends State<RepostPage> {
  final TextEditingController _retweetController = TextEditingController();
  String? _postAccountName;
  String? _postAccountIconUrl;
  File? _mediaFile; // メディアファイルを管理するためのフィールドを追加
  final picker = ImagePicker();

  @override
  void initState() {
    super.initState();
    _fetchPostAccountInfo();
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
      });
    }
  }

  Future<void> _pickMedia() async {
    final pickedFile = await picker.pickImage(source: ImageSource.gallery);

    if (pickedFile != null) {
      setState(() {
        _mediaFile = File(pickedFile.path);
      });
    }
  }

  Future<void> _sendRepost() async {
    if (_retweetController.text.isNotEmpty || _mediaFile != null) {
      List<String>? mediaUrls; // 修正: メディアURLをリストとして扱う

      // メディアが選択されている場合、Firebase Storageにアップロードする
      if (_mediaFile != null) {
        final String userId = FirebaseAuth.instance.currentUser!.uid;
        String? uploadedMediaUrl =
            await FunctionUtils.uploadImage(userId, _mediaFile!, context);

        if (uploadedMediaUrl != null) {
          mediaUrls = [uploadedMediaUrl]; // URLをリストに追加
        }
      }

      // Firestoreに再投稿情報を追加する処理を実装
      Post rePost = Post(
        content: _retweetController.text,
        postAccountId: FirebaseAuth.instance.currentUser!.uid,
        mediaUrl: mediaUrls, // 修正: リストを渡す
        repost: widget.post.id,
      );

      // Firestoreに返信を追加し、新しい投稿のIDを取得
      String? rePostId = await PostFirestore.addPost(rePost);

      if (rePostId != null) {
        final rePostCollectionRef = FirebaseFirestore.instance
            .collection('posts')
            .doc(widget.post.id)
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
        // ページ全体をスクロール可能にするためにSingleChildScrollViewでラップ
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
                            CircleAvatar(
                              backgroundImage:
                                  NetworkImage(_postAccountIconUrl!),
                            ),
                          const SizedBox(width: 10),
                          if (_postAccountName != null)
                            Text(
                              _postAccountName!,
                              style: const TextStyle(
                                  fontWeight: FontWeight.bold, fontSize: 15),
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
                      if (widget.post.mediaUrl != null)
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
              if (_mediaFile != null)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 10),
                  child: Image.file(
                    _mediaFile!,
                    fit: BoxFit.cover,
                    width: double.infinity,
                    height: 200,
                  ),
                ),
              const SizedBox(height: 20),
              // 引用を送信するボタン
              ElevatedButton(
                onPressed: _sendRepost,
                child: const Text('引用を送信'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
