import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cymva/model/post.dart';
import 'package:cymva/model/account.dart';
import 'package:cymva/utils/firestore/posts.dart';
import 'package:cymva/utils/favorite_post.dart';
import 'package:cymva/view/post_item/post_item_widget.dart';

class PostList extends StatefulWidget {
  final Account myAccount;
  final Account postAccount;

  const PostList({Key? key, required this.myAccount, required this.postAccount})
      : super(key: key);

  @override
  State<PostList> createState() => _PostListState();
}

class _PostListState extends State<PostList> {
  late Future<List<String>> _favoritePostsFuture;
  final FavoritePost _favoritePost = FavoritePost();

  @override
  void initState() {
    super.initState();
    _favoritePostsFuture = _favoritePost.getFavoritePosts(); // お気に入りの投稿を取得
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('users')
          .doc(widget.postAccount.id)
          .collection('my_posts')
          .where('clip', isEqualTo: true)
          .orderBy('clipTime', descending: true)
          .snapshots(),
      builder: (context, clipTrueSnapshot) {
        if (!clipTrueSnapshot.hasData) {
          return const Center(child: CircularProgressIndicator());
        }

        // clipがtrueの投稿を取得
        List<DocumentSnapshot> clipTruePosts = clipTrueSnapshot.data!.docs;

        // clipがfalseの投稿を取得
        return StreamBuilder<QuerySnapshot>(
          stream: FirebaseFirestore.instance
              .collection('users')
              .doc(widget.postAccount.id)
              .collection('my_posts')
              .where('clip', isEqualTo: false)
              .orderBy('created_time', descending: true)
              .snapshots(),
          builder: (context, clipFalseSnapshot) {
            if (!clipFalseSnapshot.hasData) {
              return const Center(child: CircularProgressIndicator());
            }

            // clipがfalseの投稿を取得
            List<DocumentSnapshot> clipFalsePosts =
                clipFalseSnapshot.data!.docs;

            // すべての投稿を結合する
            List<DocumentSnapshot> allPosts = [
              ...clipTruePosts,
              ...clipFalsePosts
            ];

            return FutureBuilder<List<Post>?>(
              future: PostFirestore.getPostsFromIds(
                  allPosts.map((doc) => doc.id).toList()),
              builder: (context, postSnapshot) {
                if (postSnapshot.hasData) {
                  if (postSnapshot.data!.isEmpty) {
                    return const Center(child: Text('まだ投稿がありません'));
                  } else {
                    return FutureBuilder<List<String>>(
                      future: _favoritePostsFuture,
                      builder: (context, favoriteSnapshot) {
                        if (favoriteSnapshot.connectionState ==
                                ConnectionState.done &&
                            favoriteSnapshot.hasData) {
                          return ListView.builder(
                            itemCount: postSnapshot.data!.length,
                            itemBuilder: (context, index) {
                              Post post = postSnapshot.data![index];
                              bool isFavorite =
                                  favoriteSnapshot.data!.contains(post.id);

                              // お気に入りユーザー数の初期化と更新
                              _favoritePost.favoriteUsersNotifiers[post.id] ??=
                                  ValueNotifier<int>(0);
                              _favoritePost.updateFavoriteUsersCount(post.id);

                              // リツイートの状態を管理するためのValueNotifierを初期化
                              ValueNotifier<bool> isRetweetedNotifier =
                                  ValueNotifier<bool>(false);

                              return PostItemWidget(
                                post: post,
                                postAccount: widget.postAccount,
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
                                isRetweetedNotifier: isRetweetedNotifier,
                                onRetweetToggle: () {
                                  bool currentState = isRetweetedNotifier.value;
                                  isRetweetedNotifier.value = !currentState;
                                },
                                replyFlag: ValueNotifier<bool>(false),
                                userId: widget.myAccount.id,
                              );
                            },
                          );
                        } else {
                          return const Center(
                              child: CircularProgressIndicator());
                        }
                      },
                    );
                  }
                } else {
                  return const Center(child: CircularProgressIndicator());
                }
              },
            );
          },
        );
      },
    );
  }
}
