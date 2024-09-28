import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cymva/model/post.dart';
import 'package:cymva/view/account/account_page.dart';
import 'package:cymva/view/post_item/full_screen_image.dart';
import 'package:cymva/view/post_item/media_display_widget.dart';
import 'package:cymva/view/post_item/post_detail_page.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

class RepostListPage extends StatelessWidget {
  final String postId;
  final String userId;

  const RepostListPage({
    Key? key,
    required this.postId,
    required this.userId,
  }) : super(key: key);

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

              // repostId を使って、post の情報を取得
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

                  // post_account_id からユーザー情報を取得
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

                      // 投稿とユーザー情報を表示、タップで詳細ページに遷移
                      return Column(
                        children: [
                          GestureDetector(
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
                                    favoriteUsersNotifier:
                                        ValueNotifier<int>(0),
                                    isFavoriteNotifier:
                                        ValueNotifier<bool>(false),
                                    onFavoriteToggle: () {},
                                    isRetweetedNotifier:
                                        ValueNotifier<bool>(false),
                                    onRetweetToggle: () {},
                                    replyFlag: ValueNotifier<bool>(false),
                                    userId: userId,
                                  ),
                                ),
                              );
                            },
                            child: Padding(
                              padding: const EdgeInsets.all(10.0),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      // プロフィール画像をタップでアカウントページに遷移
                                      GestureDetector(
                                        onTap: () {
                                          Navigator.push(
                                            context,
                                            MaterialPageRoute(
                                              builder: (context) => AccountPage(
                                                  postUserId:
                                                      userData['user_id']),
                                            ),
                                          );
                                        },
                                        child: ClipRRect(
                                          borderRadius: BorderRadius.circular(
                                              8.0), // 角を丸くする
                                          child: Image.network(
                                            userData['image_path'], // プロフィール画像
                                            width: 40,
                                            height: 40,
                                            fit: BoxFit.cover, // 画像が正方形にフィット
                                          ),
                                        ),
                                      ),
                                      const SizedBox(width: 5),

                                      // 名前とユーザーIDを表示
                                      Expanded(
                                        child: Column(
                                          crossAxisAlignment:
                                              CrossAxisAlignment.start,
                                          children: [
                                            Row(
                                              mainAxisAlignment:
                                                  MainAxisAlignment
                                                      .spaceBetween,
                                              children: [
                                                // 名前とユーザーID
                                                Column(
                                                  crossAxisAlignment:
                                                      CrossAxisAlignment.start,
                                                  children: [
                                                    Text(
                                                      userData['name'].length >
                                                              25
                                                          ? '${userData['name'].substring(0, 25)}...'
                                                          : userData['name'],
                                                      style: const TextStyle(
                                                          fontWeight:
                                                              FontWeight.bold),
                                                      overflow:
                                                          TextOverflow.ellipsis,
                                                      maxLines: 1,
                                                    ),
                                                    Text(
                                                      '@${userData['user_id'].length > 25 ? '${userData['user_id'].substring(0, 25)}...' : userData['user_id']}',
                                                      style: const TextStyle(
                                                          color: Colors.grey),
                                                      overflow:
                                                          TextOverflow.ellipsis,
                                                      maxLines: 1,
                                                    ),
                                                  ],
                                                ),
                                                // 投稿日時
                                                Text(
                                                  DateFormat('yyyy/M/d').format(
                                                      postData['created_time']
                                                          .toDate()),
                                                ),
                                              ],
                                            ),
                                            const SizedBox(height: 5),

                                            // 投稿内容とメディア表示
                                            Column(
                                              crossAxisAlignment:
                                                  CrossAxisAlignment.start,
                                              children: [
                                                Text(postData['content']),

                                                // メディア（画像）がある場合に表示
                                                if (postData['media_url'] !=
                                                    null) ...[
                                                  Column(
                                                    crossAxisAlignment:
                                                        CrossAxisAlignment
                                                            .start,
                                                    children: [
                                                      MediaDisplayWidget(
                                                        // 'media_url'がList<dynamic>型の場合、List<String>に変換する
                                                        mediaUrl: (postData[
                                                                    'media_url']
                                                                as List<
                                                                    dynamic>)
                                                            .map((url) =>
                                                                url.toString())
                                                            .toList(),
                                                        category: postData[
                                                                'category'] ??
                                                            '',
                                                      ),
                                                    ],
                                                  ),
                                                ],
                                              ],
                                            ),
                                          ],
                                        ),
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                            ),
                          ),
                          // 投稿の下にラインを表示
                          const Divider(
                            color: Colors.grey,
                            thickness: 1.0,
                          ),
                        ],
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
