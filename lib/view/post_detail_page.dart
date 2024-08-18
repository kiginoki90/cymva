import 'package:cymva/view/navigation_bar.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:cymva/model/post.dart';
import 'package:cymva/view/account/account_page.dart';
import 'package:video_player/video_player.dart';
import 'package:cymva/view/full_screen_image.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class PostDetailPage extends StatelessWidget {
  final Post post;
  final String postAccountName;
  final String postAccountUserId;
  final String postAccountImagePath;

  const PostDetailPage({
    Key? key,
    required this.post,
    required this.postAccountName,
    required this.postAccountUserId,
    required this.postAccountImagePath,
  }) : super(key: key);

  Future<void> _deletePost(
      BuildContext context, String postId, String postAccountId) async {
    final FirebaseFirestore _firestore = FirebaseFirestore.instance;

    // サブコレクションの削除を含むドキュメント削除関数
    Future<void> deleteCollection(String collectionPath) async {
      final collectionRef = _firestore.collection(collectionPath);
      final querySnapshot = await collectionRef.get();

      for (final doc in querySnapshot.docs) {
        await doc.reference.delete();
      }
    }

    try {
      // favorite_usersサブコレクションの削除
      await deleteCollection('posts/$postId/favorite_users');

      // postsコレクションから該当するドキュメントを削除
      await _firestore.collection('posts').doc(postId).delete();

      // usersコレクションの該当するユーザーのmy_postsサブコレクションから該当するドキュメントを削除
      await _firestore
          .collection('users')
          .doc(postAccountId)
          .collection('my_posts')
          .doc(postId)
          .delete();

      // 削除成功メッセージ
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('投稿を削除しました')),
      );

      // 削除後に前の画面に戻る
      Navigator.of(context).pop();
    } catch (e) {
      // エラーメッセージ
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('投稿の削除に失敗しました: $e')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    // 現在ログインしているユーザーのIDを取得
    final String currentUserId = FirebaseAuth.instance.currentUser!.uid;

    final FirebaseFirestore _firestore = FirebaseFirestore.instance;

    return Scaffold(
      appBar: AppBar(
        title: const Text('ポストの詳細'),
      ),
      body: Padding(
        padding: const EdgeInsets.all(10.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                GestureDetector(
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) =>
                            AccountPage(userId: post.postAccountId),
                      ),
                    );
                  },
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(8.0), // 角を丸める
                    child: Image.network(
                      postAccountImagePath,
                      width: 44, // 高さをCircleAvatarの直径に合わせる
                      height: 44,
                      fit: BoxFit.cover,
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      postAccountName,
                      style: const TextStyle(fontWeight: FontWeight.bold),
                    ),
                    Text(
                      '@$postAccountUserId',
                      style: const TextStyle(color: Colors.grey),
                    ),
                  ],
                ),
                Spacer(),
                if (post.postAccountId == currentUserId)
                  PopupMenuButton<String>(
                    icon: Icon(Icons.add),
                    onSelected: (String value) {
                      switch (value) {
                        case 'Option 1':
                          _deletePost(context, post.id,
                              post.postAccountId); // 削除処理を呼び出す
                          break;
                        case 'Option 2':
                          // Option 2 の処理
                          break;
                        case 'Option 3':
                          // Option 3 の処理
                          break;
                      }
                    },
                    itemBuilder: (BuildContext context) {
                      return [
                        PopupMenuItem<String>(
                          value: 'Option 1',
                          child: Text(
                            'ポストの削除',
                            style: TextStyle(color: Colors.red), // テキストの色を赤に変更
                          ),
                        ),
                        PopupMenuItem<String>(
                          value: 'Option 2',
                          child: Text('Option 2'),
                        ),
                        PopupMenuItem<String>(
                          value: 'Option 3',
                          child: Text('Option 3'),
                        ),
                      ];
                    },
                  ),
              ],
            ),
            const SizedBox(height: 10),
            Text(
              DateFormat('yyyy/M/d').format(post.createdTime!.toDate()),
              style: const TextStyle(color: Colors.grey),
            ),
            const SizedBox(height: 10),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(post.content),
                const SizedBox(height: 10),
                if (post.isVideo)
                  AspectRatio(
                    aspectRatio: 16 / 9,
                    child: VideoPlayer(VideoPlayerController.networkUrl(
                        Uri.parse(post.mediaUrl!))),
                  )
                else if (post.mediaUrl != null)
                  GestureDetector(
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) =>
                              FullScreenImagePage(imageUrl: post.mediaUrl!),
                        ),
                      );
                    },
                    child: Container(
                      constraints: BoxConstraints(
                        maxHeight: 400,
                      ),
                      child: Image.network(
                        post.mediaUrl!,
                        fit: BoxFit.cover,
                        width: double.infinity,
                      ),
                    ),
                  )
              ],
            )
          ],
        ),
      ),
      bottomNavigationBar: NavigationBarPage(
        selectedIndex: 1,
      ),
    );
  }
}
