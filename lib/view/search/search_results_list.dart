import 'package:cymva/view/post_item/post_item_widget.dart';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cymva/model/post.dart';
import 'package:cymva/model/account.dart';
import 'package:cymva/utils/favorite_post.dart';

class SearchResultsList extends StatelessWidget {
  final List<DocumentSnapshot> searchResults;
  final Map<String, Account> userMap;
  final FavoritePost favoritePost;

  const SearchResultsList({
    Key? key,
    required this.searchResults,
    required this.userMap,
    required this.favoritePost,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return ListView.builder(
      itemCount: searchResults.length,
      itemBuilder: (context, index) {
        final postDoc = searchResults[index];
        final post = Post.fromDocument(postDoc);
        final postAccount = userMap[post.postAccountId];

        if (postAccount == null) return Container();

        favoritePost.favoriteUsersNotifiers[post.id] ??= ValueNotifier<int>(0);
        favoritePost.updateFavoriteUsersCount(post.id);

        // リツイートの状態を管理するためのValueNotifierを初期化
        ValueNotifier<bool> isRetweetedNotifier = ValueNotifier<bool>(
          false, // Firestoreからリツイートの状態を取得し初期化する
        );

        return PostItemWidget(
          post: post,
          postAccount: postAccount,
          favoriteUsersNotifier: favoritePost.favoriteUsersNotifiers[post.id]!,
          isFavoriteNotifier: ValueNotifier<bool>(
            favoritePost.favoritePostsNotifier.value.contains(post.id),
          ),
          onFavoriteToggle: () => favoritePost.toggleFavorite(
            post.id,
            favoritePost.favoritePostsNotifier.value.contains(post.id),
          ),
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
        );
      },
    );
  }
}
