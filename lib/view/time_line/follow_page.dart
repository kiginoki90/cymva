import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:cymva/view/post_item/post_item_widget.dart';
import 'package:cymva/model/account.dart';
import 'package:cymva/model/post.dart';
import 'package:cymva/utils/favorite_post.dart';

class FollowPage extends StatefulWidget {
  final Account myAccount;

  FollowPage({Key? key, required this.myAccount}) : super(key: key);

  @override
  State<FollowPage> createState() => _FollowPageState();
}

class _FollowPageState extends State<FollowPage> {
  final FavoritePost _favoritePost = FavoritePost();
  late Future<List<String>>? _favoritePostsFuture;

  // 投稿を取得する非同期関数
  Future<List<QueryDocumentSnapshot>> _fetchFollowedPosts() async {
    // フォローしているユーザーのIDリストを取得
    final followSnapshot = await FirebaseFirestore.instance
        .collection('users')
        .doc(widget.myAccount.id)
        .collection('follow')
        .get();
    List<String> followedUserIds =
        followSnapshot.docs.map((doc) => doc.id).toList();

    // フォローしているユーザーがいない場合は空のリストを返す
    if (followedUserIds.isEmpty) {
      return [];
    }

    // フォローしているユーザーの投稿を取得
    final postSnapshot = await FirebaseFirestore.instance
        .collection('posts')
        .where('post_account_id', whereIn: followedUserIds)
        .get();

    return postSnapshot.docs;
  }

  Future<Account?> _fetchAccount(String accountId) async {
    final userDoc = await FirebaseFirestore.instance
        .collection('users')
        .doc(accountId)
        .get();
    if (userDoc.exists) {
      return Account.fromDocument(userDoc);
    }
    return null;
  }

  // スクロールでデータをリフレッシュ
  Future<void> _refreshPosts() async {
    setState(() {});
    await Future.delayed(const Duration(seconds: 1)); // スピナー表示時間
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
        onRefresh: _refreshPosts,
        child: FutureBuilder<List<QueryDocumentSnapshot>>(
          future: _fetchFollowedPosts(),
          builder: (context, postSnapshot) {
            if (postSnapshot.connectionState == ConnectionState.waiting) {
              return const Center(child: CircularProgressIndicator());
            }

            if (postSnapshot.hasData) {
              if (postSnapshot.data!.isEmpty) {
                return const Center(child: Text('投稿がありません'));
              } else {
                return FutureBuilder<List<String>>(
                  future: _favoritePostsFuture,
                  builder: (context, favoriteSnapshot) {
                    if (favoriteSnapshot.connectionState ==
                        ConnectionState.waiting) {
                      return const Center(child: CircularProgressIndicator());
                    }

                    // お気に入り情報の取得が成功した場合
                    List<String> favoritePostIds = favoriteSnapshot.data ?? [];

                    return ListView.builder(
                      itemCount: postSnapshot.data!.length,
                      itemBuilder: (context, index) {
                        Map<String, dynamic> data = postSnapshot.data![index]
                            .data() as Map<String, dynamic>;

                        Post post =
                            Post.fromDocument(postSnapshot.data![index]);
                        bool isFavorite = favoritePostIds.contains(post.id);

                        return FutureBuilder<Account?>(
                          future: _fetchAccount(post.postAccountId),
                          builder: (context, userSnapshot) {
                            if (userSnapshot.connectionState ==
                                ConnectionState.waiting) {
                              return const Center(
                                  child: CircularProgressIndicator());
                            }

                            if (userSnapshot.hasError ||
                                !userSnapshot.hasData) {
                              return const Center(
                                  child: Text('ユーザー情報が取得できませんでした'));
                            }

                            _favoritePost.favoriteUsersNotifiers[post.id] ??=
                                ValueNotifier<int>(0);
                            _favoritePost.updateFavoriteUsersCount(post.id);

                            Account postAccount = userSnapshot.data!;

                            return PostItemWidget(
                              post: post,
                              postAccount: postAccount,
                              favoriteUsersNotifier: _favoritePost
                                  .favoriteUsersNotifiers[post.id]!,
                              isFavoriteNotifier:
                                  ValueNotifier<bool>(isFavorite),
                              onFavoriteToggle: () {
                                _favoritePost.toggleFavorite(
                                    post.id, isFavorite);
                              },
                              isRetweetedNotifier: ValueNotifier<bool>(false),
                              onRetweetToggle: () {},
                              replyFlag: ValueNotifier<bool>(false),
                              userId: widget.myAccount.id,
                            );
                          },
                        );
                      },
                    );
                  },
                );
              }
            } else {
              return const Center(child: CircularProgressIndicator());
            }
          },
        ),
      ),
    );
  }
}
