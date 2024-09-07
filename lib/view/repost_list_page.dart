import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cymva/model/post.dart';
import 'package:cymva/view/post_detail_page.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

class RepostListPage extends StatelessWidget {
  final String postId;

  const RepostListPage({Key? key, required this.postId}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('引用'),
      ),
      body: StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance
            .collection('posts')
            .doc(postId)
            .collection('repost') // repostサブコレクションを取得
            .snapshots(),
        builder: (context, snapshot) {
          if (!snapshot.hasData) {
            return const Center(child: CircularProgressIndicator());
          }

          final reposts = snapshot.data!.docs;

          if (reposts.isEmpty) {
            return const Center(child: Text('引用はありません'));
          }

          return ListView.builder(
            itemCount: reposts.length,
            itemBuilder: (context, index) {
              final repost = reposts[index].data() as Map<String, dynamic>?;
              if (repost == null) {
                return const ListTile(
                  title: Text('データが存在しません'),
                );
              }
              final repostedPostId = repost['id'];

              // それぞれの repostId を使って、対応する post の情報を取得
              return FutureBuilder<DocumentSnapshot>(
                future: FirebaseFirestore.instance
                    .collection('posts')
                    .doc(repostedPostId) // repostされた投稿のID
                    .get(),
                builder: (context, postSnapshot) {
                  if (!postSnapshot.hasData) {
                    return const Center(child: CircularProgressIndicator());
                  }

                  final postData =
                      postSnapshot.data?.data() as Map<String, dynamic>?;

                  if (postData == null) {
                    return const SizedBox.shrink(); // 何も表示しない
                  }
                  final postDoc = postSnapshot.data!;
                  final post = Post.fromDocument(postDoc);
                  final postAccountId = postData['post_account_id'];

                  // 取得した post_account_id からユーザー情報を取得
                  return FutureBuilder<DocumentSnapshot>(
                    future: FirebaseFirestore.instance
                        .collection('users')
                        .doc(postAccountId) // 投稿者のアカウントID
                        .get(),
                    builder: (context, userSnapshot) {
                      if (!userSnapshot.hasData) {
                        return const Center(child: CircularProgressIndicator());
                      }

                      final userData =
                          userSnapshot.data?.data() as Map<String, dynamic>?;
                      if (userData == null) {
                        return const ListTile(
                          title: Text('ユーザーデータが存在しません'),
                        );
                      }

                      // 投稿とユーザー情報をタップ可能にして表示
                      return GestureDetector(
                        onTap: () {
                          // 投稿がタップされたときに詳細ページに遷移
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (context) => PostDetailPage(
                                post: post,
                                postAccountName: userData['name'],
                                postAccountUserId: userData['user_id'],
                                postAccountImagePath:
                                    userData['image_path'] ?? '',
                                favoriteUsersNotifier: ValueNotifier<int>(0),
                                isFavoriteNotifier: ValueNotifier<bool>(false),
                                onFavoriteToggle: () {},
                                isRetweetedNotifier: ValueNotifier<bool>(false),
                                onRetweetToggle: () {},
                              ),
                            ),
                          );
                        },
                        child: Column(
                          children: [
                            ListTile(
                              leading: CircleAvatar(
                                backgroundImage:
                                    NetworkImage(userData['image_path'] ?? ''),
                              ),
                              title: Text(userData['name'] ?? ''),
                              subtitle: Text(postData['content'] ?? ''),
                              trailing: Text(DateFormat('yyyy/MM/dd')
                                  .format(postData['created_time'].toDate())),
                            ),
                            const Divider(
                              color: Colors.grey,
                              thickness: 1.0,
                            ),
                          ],
                        ),
                      );
                    },
                  );
                },
              );
            },
          );
        },
      ),
    );
  }
}
