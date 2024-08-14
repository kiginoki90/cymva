import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cymva/model/post.dart';
import 'package:cymva/model/account.dart';
import 'package:cymva/utils/firestore/posts.dart';
import 'package:cymva/utils/favorite_post.dart';
import 'package:cymva/view/poat/post_item_widget.dart';

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
          .snapshots(),
      builder: (context, snapshot) {
        if (snapshot.hasData) {
          List<String> favoritePostIds =
              List.generate(snapshot.data!.docs.length, (index) {
            return snapshot.data!.docs[index].id;
          });

          return FutureBuilder<List<Post>?>(
            future: PostFirestore.getPostsFromIds(favoritePostIds),
            builder: (context, postSnapshot) {
              if (postSnapshot.hasData) {
                if (postSnapshot.data!.isEmpty) {
                  return const Center(child: Text('まだお気に入りの投稿がありません'));
                } else {
                  return ListView.builder(
                    itemCount: postSnapshot.data!.length,
                    itemBuilder: (context, index) {
                      Post post = postSnapshot.data![index];
                      bool isFavorite =
                          true; // Since these are all favorite posts

                      // お気に入りユーザー数の初期化と更新
                      _favoritePost.favoriteUsersNotifiers[post.id] ??=
                          ValueNotifier<int>(0);
                      _favoritePost.updateFavoriteUsersCount(post.id);

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
