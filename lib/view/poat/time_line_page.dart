import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:cymva/view/poat/post_item_widget.dart';
import 'package:cymva/model/account.dart';
import 'package:cymva/model/post.dart';
import 'package:cymva/utils/favorite_post.dart';
import 'package:cymva/utils/firestore/posts.dart';
import 'package:cymva/utils/firestore/users.dart';

class TimeLinePage extends StatefulWidget {
  const TimeLinePage({super.key});

  @override
  State<TimeLinePage> createState() => _TimeLineState();
}

class _TimeLineState extends State<TimeLinePage> {
  late Future<List<String>>? _favoritePostsFuture;
  final FavoritePost _favoritePost = FavoritePost();

  @override
  void initState() {
    super.initState();
    _favoritePostsFuture = _favoritePost.getFavoritePosts();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        //Firestoreからポストデータをリアルタイムで取得
        child: StreamBuilder<QuerySnapshot>(
          stream: PostFirestore.posts
              .orderBy('created_time', descending: true)
              .snapshots(),
          builder: (context, postSnapshot) {
            if (postSnapshot.hasData) {
              List<String> postAccountIds = [];
              postSnapshot.data!.docs.forEach((doc) {
                Map<String, dynamic> data = doc.data() as Map<String, dynamic>;
                if (!postAccountIds.contains(data['post_account_id'])) {
                  postAccountIds.add(data['post_account_id']);
                }
              });
              //投稿に関するユーザー情報を取得
              return FutureBuilder<Map<String, Account>?>(
                future: UserFirestore.getPostUserMap(postAccountIds),
                builder: (context, userSnapshot) {
                  if (userSnapshot.hasData &&
                      userSnapshot.connectionState == ConnectionState.done) {
                    return FutureBuilder<List<String>>(
                      future: _favoritePostsFuture,
                      builder: (context, favoriteSnapshot) {
                        if (favoriteSnapshot.connectionState ==
                                ConnectionState.done &&
                            favoriteSnapshot.hasData) {
                          return ListView.builder(
                            itemCount: postSnapshot.data!.docs.length,
                            itemBuilder: (context, index) {
                              // Post クラスのインスタンスを作成するために fromDocument を使用
                              Post post = Post.fromDocument(
                                  postSnapshot.data!.docs[index]);

                              Account postAccount =
                                  userSnapshot.data![post.postAccountId]!;

                              _favoritePost.favoriteUsersNotifiers[post.id] ??=
                                  ValueNotifier<int>(0);
                              _favoritePost.updateFavoriteUsersCount(post.id);

                              return PostItemWidget(
                                post: post,
                                postAccount: postAccount,
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
                              );
                            },
                          );
                        } else {
                          return const Center(
                              child: CircularProgressIndicator());
                        }
                      },
                    );
                  } else {
                    return const Center(child: CircularProgressIndicator());
                  }
                },
              );
            } else {
              return const Center(child: CircularProgressIndicator());
            }
          },
        ),
      ),
    );
  }
}
