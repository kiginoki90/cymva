import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:cymva/view/post_item/post_item_widget.dart';
import 'package:cymva/model/account.dart';
import 'package:cymva/model/post.dart';
import 'package:cymva/utils/favorite_post.dart';
import 'package:cymva/utils/firestore/posts.dart';
import 'package:cymva/utils/firestore/users.dart';
import 'package:flutter/widgets.dart';

class TimeLinePage extends StatefulWidget {
  final String userId;
  const TimeLinePage({
    super.key,
    required this.userId,
  });

  @override
  State<TimeLinePage> createState() => _TimeLineState();
}

class _TimeLineState extends State<TimeLinePage> {
  late Future<List<String>>? _favoritePostsFuture;
  final FavoritePost _favoritePost = FavoritePost();

  Future<List<QueryDocumentSnapshot>> _fetchPosts() async {
    final querySnapshot = await PostFirestore.posts
        .orderBy('created_time', descending: true)
        .get();
    return querySnapshot.docs;
  }

  Future<void> _refreshPosts() async {
    setState(() {
      // FutureBuilderを再度トリガーするために空のsetStateを使う
    });
    await Future.delayed(const Duration(seconds: 1));
  }

  @override
  void initState() {
    super.initState();
    _favoritePostsFuture = _favoritePost.getFavoritePosts();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: RefreshIndicator(
        onRefresh: _refreshPosts, // スクロールで更新するためのリフレッシュ機能
        child: FutureBuilder<List<QueryDocumentSnapshot>>(
          future: _fetchPosts(),
          builder: (context, postSnapshot) {
            if (postSnapshot.hasData) {
              List<String> postAccountIds = [];
              postSnapshot.data!.forEach((doc) {
                Map<String, dynamic> data = doc.data() as Map<String, dynamic>;
                if (!postAccountIds.contains(data['post_account_id'])) {
                  postAccountIds.add(data['post_account_id']);
                }
              });

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
                          // 投稿をフィルタリング
                          List<Post> visiblePosts = postSnapshot.data!
                              .map((doc) => Post.fromDocument(doc))
                              .where((post) {
                            Account postAccount =
                                userSnapshot.data![post.postAccountId]!;
                            return !postAccount
                                .lockAccount; // lockAccountがfalseのもののみ
                          }).toList();

                          return ListView.builder(
                            itemCount: visiblePosts.length, // フィルタリング後のアイテム数
                            itemBuilder: (context, index) {
                              Post post = visiblePosts[index];

                              Account postAccount =
                                  userSnapshot.data![post.postAccountId]!;

                              _favoritePost.favoriteUsersNotifiers[post.id] ??=
                                  ValueNotifier<int>(0);
                              _favoritePost.updateFavoriteUsersCount(post.id);

                              ValueNotifier<bool> isRetweetedNotifier =
                                  ValueNotifier<bool>(false);

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
                                isRetweetedNotifier: isRetweetedNotifier,
                                onRetweetToggle: () {
                                  bool currentState = isRetweetedNotifier.value;
                                  isRetweetedNotifier.value = !currentState;
                                },
                                replyFlag: ValueNotifier<bool>(false),
                                userId: widget.userId,
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
