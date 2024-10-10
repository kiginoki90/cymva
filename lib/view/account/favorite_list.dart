import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cymva/model/post.dart';
import 'package:cymva/model/account.dart';
import 'package:cymva/utils/firestore/posts.dart';
import 'package:cymva/utils/firestore/users.dart'; // Firestoreからユーザー情報を取得するために必要
import 'package:cymva/utils/favorite_post.dart';
import 'package:cymva/view/post_item/post_item_widget.dart';

class FavoriteList extends StatelessWidget {
  final Account myAccount;
  final FavoritePost _favoritePost = FavoritePost(); // お気に入り機能のインスタンス

  FavoriteList({Key? key, required this.myAccount}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('users')
          .doc(myAccount.id)
          .collection('favorite_posts')
          .orderBy('added_at', descending: true)
          .snapshots(),
      builder: (context, snapshot) {
        if (snapshot.hasData) {
          List<String> favoritePostIds =
              List.generate(snapshot.data!.docs.length, (index) {
            return snapshot.data!.docs[index].id;
          });

          if (favoritePostIds.isEmpty) {
            return const Center(child: Text('まだお気に入りの投稿がありません'));
          }

          // 投稿とユーザー情報を同時に取得する
          return FutureBuilder<List<Post>>(
            future: PostFirestore.getPostsFromIds(favoritePostIds),
            builder: (context, postSnapshot) {
              if (postSnapshot.hasData) {
                List<Post> posts = postSnapshot.data!;

                // 投稿者のユーザー情報を取得する
                List<String> accountIds =
                    posts.map((post) => post.postAccountId).toSet().toList();
                return FutureBuilder<Map<String, Account>>(
                  future: UserFirestore.getUsersByIds(accountIds),
                  builder: (context, accountSnapshot) {
                    if (accountSnapshot.hasData) {
                      Map<String, Account> accounts = accountSnapshot.data!;

                      return ListView.builder(
                        itemCount: posts.length,
                        itemBuilder: (context, index) {
                          Post post = posts[index];
                          Account postAccount = accounts[post.postAccountId]!;

                          bool isFavorite = true; // お気に入りの投稿なので常にtrue

                          // お気に入りユーザー数の初期化と更新
                          _favoritePost.favoriteUsersNotifiers[post.id] ??=
                              ValueNotifier<int>(0);
                          _favoritePost.updateFavoriteUsersCount(post.id);

                          // リツイートの状態を管理するためのValueNotifierを初期化
                          ValueNotifier<bool> isRetweetedNotifier =
                              ValueNotifier<bool>(false);

                          return PostItemWidget(
                            post: post,
                            postAccount: postAccount, // Firestoreから取得したユーザー情報
                            favoriteUsersNotifier:
                                _favoritePost.favoriteUsersNotifiers[post.id]!,
                            isFavoriteNotifier: ValueNotifier<bool>(isFavorite),
                            onFavoriteToggle: () {
                              _favoritePost.toggleFavorite(
                                post.id,
                                isFavorite,
                              );
                            },
                            // リツイートの状態を渡す
                            isRetweetedNotifier: isRetweetedNotifier,
                            // リツイートの状態をトグルする処理
                            onRetweetToggle: () {
                              bool currentState = isRetweetedNotifier.value;
                              isRetweetedNotifier.value = !currentState;
                              // Firestoreでリツイートの情報を更新する処理
                            },
                            replyFlag: ValueNotifier<bool>(false),
                            userId: myAccount.userId,
                          );
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
          );
        } else {
          return const Center(child: CircularProgressIndicator());
        }
      },
    );
  }
}
