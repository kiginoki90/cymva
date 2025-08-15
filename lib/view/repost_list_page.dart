import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cymva/model/account.dart';
import 'package:cymva/model/post.dart';
import 'package:cymva/utils/book_mark.dart';
import 'package:cymva/utils/navigation_utils.dart';
import 'package:cymva/view/account/account_page.dart';
import 'package:cymva/view/navigation_bar.dart';
import 'package:cymva/view/post_item/media_display_widget.dart';
import 'package:cymva/view/post_item/post_detail_page.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

class RepostListPage extends StatefulWidget {
  final String postId;
  final String userId;

  const RepostListPage({
    Key? key,
    required this.postId,
    required this.userId,
  }) : super(key: key);

  @override
  _RepostListPageState createState() => _RepostListPageState();
}

class _RepostListPageState extends State<RepostListPage> {
  final BookmarkPost _bookmarkPost = BookmarkPost();

  @override
  void initState() {
    super.initState();
    // _bookmarkPost.getBookmarkPosts();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('引用'),
      ),
      body: StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance
            .collection('posts')
            .doc(widget.postId)
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

                      _bookmarkPost.bookmarkUsersNotifiers[post.id] ??=
                          ValueNotifier<int>(0);
                      _bookmarkPost.updateBookmarkUsersCount(post.id);

                      final postAccount =
                          Account.fromDocument(userSnapshot.data!);
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
                                    postAccount: postAccount,
                                    replyFlag: ValueNotifier<bool>(false),
                                    userId: widget.userId,
                                    bookmarkUsersNotifier: _bookmarkPost
                                        .bookmarkUsersNotifiers[post.id]!,
                                    isBookmarkedNotifier: ValueNotifier<bool>(
                                      _bookmarkPost.bookmarkPostsNotifier.value
                                          .contains(post.id),
                                    ),
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
                                                postUserId: postAccount.id,
                                                withDelay: false,
                                              ),
                                            ),
                                          );
                                        },
                                        child: ClipRRect(
                                          borderRadius:
                                              BorderRadius.circular(8.0),
                                          child: Image.network(
                                            userData['image_path'] ??
                                                'https://firebasestorage.googleapis.com/v0/b/cymva-595b7.appspot.com/o/export.jpg?alt=media&token=82889b0e-2163-40d8-917b-9ffd4a116ae7',
                                            width: 40,
                                            height: 40,
                                            fit: BoxFit.cover, // 画像が正方形にフィット
                                            errorBuilder:
                                                (context, error, stackTrace) {
                                              // 画像の取得に失敗した場合のエラービルダー
                                              return Image.network(
                                                'https://firebasestorage.googleapis.com/v0/b/cymva-595b7.appspot.com/o/export.jpg?alt=media&token=82889b0e-2163-40d8-917b-9ffd4a116ae7',
                                                width: 40,
                                                height: 40,
                                                fit: BoxFit.cover,
                                              );
                                            },
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
                                                              18
                                                          ? '${userData['name'].substring(0, 18)}...'
                                                          : userData['name'],
                                                      style: const TextStyle(
                                                          fontWeight:
                                                              FontWeight.bold),
                                                      overflow:
                                                          TextOverflow.ellipsis,
                                                      maxLines: 1,
                                                    ),
                                                    Text(
                                                      '@${userData['user_id'].length > 20 ? '${userData['user_id'].substring(0, 20)}...' : userData['user_id']}',
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
                                                        atStart: true,
                                                        post: post,
                                                        is_video: postData[
                                                                'is_video'] ??
                                                            false,
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
