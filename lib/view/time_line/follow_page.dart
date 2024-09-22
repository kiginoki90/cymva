import 'package:cymva/model/account.dart';
import 'package:cymva/model/post.dart';
import 'package:cymva/view/post_item/post_item_widget.dart';
import 'package:flutter/material.dart';
import 'package:cymva/utils/favorite_post.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class FollowPage extends StatelessWidget {
  final Account myAccount;
  final FavoritePost _favoritePost = FavoritePost(); // お気に入り機能のインスタンス

  FollowPage({Key? key, required this.myAccount}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<QuerySnapshot>(
      future: FirebaseFirestore.instance
          .collection('users')
          .doc(myAccount.id)
          .collection('follow')
          .get(),
      builder: (context, followSnapshot) {
        if (followSnapshot.hasData) {
          List<String> followedUserIds =
              followSnapshot.data!.docs.map((doc) => doc.id).toList();

          if (followedUserIds.isEmpty) {
            return const Center(child: Text('フォローしているユーザーがいません'));
          }

          return StreamBuilder<QuerySnapshot>(
            stream: FirebaseFirestore.instance
                .collection('posts')
                .where('post_account_id', whereIn: followedUserIds)
                .snapshots(),
            builder: (context, postSnapshot) {
              if (postSnapshot.hasData) {
                if (postSnapshot.data!.docs.isEmpty) {
                  return const Center(child: Text('投稿がありません'));
                } else {
                  return ListView.builder(
                    itemCount: postSnapshot.data!.docs.length,
                    itemBuilder: (context, index) {
                      Map<String, dynamic> data = postSnapshot.data!.docs[index]
                          .data() as Map<String, dynamic>;

                      Post post = Post(
                        id: postSnapshot.data!.docs[index].id,
                        content: data['content'],
                        postAccountId: data['post_account_id'],
                        createdTime: data['created_time'],
                        mediaUrl: data['media_url'],
                        isVideo: data['is_video'] ?? false,
                      );

                      bool isFavorite = _favoritePost
                          .favoritePostsNotifier.value
                          .contains(post.id);

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
                        postAccount: myAccount,
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
                          // ここにリツイートの状態をFirestoreに保存するロジックを追加する
                          bool currentState = isRetweetedNotifier.value;
                          isRetweetedNotifier.value = !currentState;
                          // Firestoreでリツイートの情報を更新する処理
                        },
                        replyFlag: ValueNotifier<bool>(false),
                        userId: myAccount.id,
                      );
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
