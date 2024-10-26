import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cymva/model/post.dart';
import 'package:cymva/model/account.dart';
import 'package:cymva/utils/firestore/posts.dart';
import 'package:cymva/utils/favorite_post.dart';
import 'package:cymva/view/post_item/post_item_widget.dart';

class ImagePostList extends StatefulWidget {
  final Account myAccount;

  const ImagePostList({Key? key, required this.myAccount}) : super(key: key);

  @override
  _ImagePostListState createState() => _ImagePostListState();
}

class _ImagePostListState extends State<ImagePostList> {
  late Future<List<String>> _favoritePostsFuture;
  final FavoritePost _favoritePost = FavoritePost();

  @override
  void initState() {
    super.initState();
    _favoritePostsFuture = _favoritePost.getFavoritePosts();
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('users')
          .doc(widget.myAccount.id)
          .collection('my_posts')
          .orderBy('created_time', descending: true)
          .snapshots(),
      builder: (context, snapshot) {
        if (snapshot.hasData) {
          List<String> myPostIds =
              List.generate(snapshot.data!.docs.length, (index) {
            return snapshot.data!.docs[index].id;
          });

          return FutureBuilder<List<Post>?>(
            future: PostFirestore.getPostsFromIds(myPostIds),
            builder: (context, postSnapshot) {
              if (postSnapshot.hasData) {
                // 画像が選択されている投稿のみをフィルタリング
                List<Post> imagePosts = postSnapshot.data!
                    .where((post) =>
                        post.mediaUrl != null && post.mediaUrl!.isNotEmpty)
                    .toList();

                if (imagePosts.isEmpty) {
                  return const Center(child: Text('まだ画像が含まれている投稿がありません'));
                } else {
                  return FutureBuilder<List<String>>(
                    future: _favoritePostsFuture,
                    builder: (context, favoriteSnapshot) {
                      if (favoriteSnapshot.connectionState ==
                              ConnectionState.done &&
                          favoriteSnapshot.hasData) {
                        return ListView.builder(
                          itemCount: imagePosts.length,
                          itemBuilder: (context, index) {
                            Post post = imagePosts[index];

                            // お気に入りユーザー数の初期化と更新
                            _favoritePost.favoriteUsersNotifiers[post.id] ??=
                                ValueNotifier<int>(0);
                            _favoritePost.updateFavoriteUsersCount(post.id);

                            // リツイートの状態を管理するためのValueNotifierを初期化
                            ValueNotifier<bool> isRetweetedNotifier =
                                ValueNotifier<bool>(
                              false, // Firestoreからリツイートの状態を取得し初期化する
                            );

                            return PostItemWidget(
                              post: post,
                              postAccount: widget.myAccount,
                              favoriteUsersNotifier: _favoritePost
                                  .favoriteUsersNotifiers[post.id]!,
                              isFavoriteNotifier: ValueNotifier<bool>(
                                _favoritePost.favoritePostsNotifier.value
                                    .contains(post.id),
                              ),
                              onFavoriteToggle: () =>
                                  _favoritePost.toggleFavorite(
                                post.id,
                                _favoritePost.favoritePostsNotifier.value
                                    .contains(post.id),
                              ),
                              // リツイートの状態を渡す
                              isRetweetedNotifier: isRetweetedNotifier,
                              // リツイートの状態をトグルする処理
                              onRetweetToggle: () {
                                bool currentState = isRetweetedNotifier.value;
                                isRetweetedNotifier.value = !currentState;
                                // Firestoreでリツイートの情報を更新する処理を追加
                              },
                              replyFlag: ValueNotifier<bool>(false),
                              userId: widget.myAccount.userId,
                            );
                          },
                        );
                      } else {
                        return const Center(child: CircularProgressIndicator());
                      }
                    },
                  );
                }
              } else {
                return const Center(child: CircularProgressIndicator());
              }
            },
          );
        } else {
          return const Center(child: CircularProgressIndicator());
        }
      },
    );
  }
}
