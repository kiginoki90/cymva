import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:cymva/model/account.dart';
import 'package:cymva/model/post.dart';
import 'package:cymva/view/post_item/post_item_widget.dart';
import 'package:cymva/ad_widget.dart';
import 'package:cymva/utils/favorite_post.dart';
import 'package:cymva/utils/book_mark.dart';

class SearchByImagePage extends StatefulWidget {
  final List<DocumentSnapshot> recentImageResults;
  final Future<List<String>> Function() fetchBlockedUserIds;
  final Future<void> Function() refreshPosts;
  final String userId;
  final FavoritePost favoritePost;
  final BookmarkPost bookmarkPost;
  final Future<Account?> Function(String postAccountId) getPostAccount;

  const SearchByImagePage({
    Key? key,
    required this.recentImageResults,
    required this.fetchBlockedUserIds,
    required this.refreshPosts,
    required this.userId,
    required this.favoritePost,
    required this.bookmarkPost,
    required this.getPostAccount,
  }) : super(key: key);

  @override
  _SearchByImagePageState createState() => _SearchByImagePageState();
}

class _SearchByImagePageState extends State<SearchByImagePage>
    with AutomaticKeepAliveClientMixin {
  @override
  bool get wantKeepAlive => true; // 状態を保持する

  @override
  Widget build(BuildContext context) {
    super.build(context); // AutomaticKeepAliveClientMixin を使用する場合に必要

    if (widget.recentImageResults.isEmpty) {
      return const Center(child: Text('検索結果がありません'));
    }

    return FutureBuilder<List<String>>(
      future: widget.fetchBlockedUserIds(),
      builder: (context, blockedUsersSnapshot) {
        if (blockedUsersSnapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: Text('読み込み中...'));
        } else if (blockedUsersSnapshot.hasError) {
          return Center(
              child: Text('エラーが発生しました: ${blockedUsersSnapshot.error}'));
        } else if (!blockedUsersSnapshot.hasData) {
          return Container(); // データがない場合は空のコンテナを返す
        }

        final blockedUserIds = blockedUsersSnapshot.data!;

        return Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 500),
            child: RefreshIndicator(
              onRefresh: widget.refreshPosts,
              child: ListView.builder(
                itemCount: widget.recentImageResults.length +
                    (widget.recentImageResults.length ~/ 5) +
                    1,
                itemBuilder: (context, index) {
                  if (index ==
                      widget.recentImageResults.length +
                          (widget.recentImageResults.length ~/ 5)) {
                    return const Center(child: Text("結果は以上です"));
                  }

                  if (index % 6 == 5) {
                    return BannerAdWidget() ??
                        const SizedBox(height: 50); // 広告ウィジェットを表示
                  }

                  final postIndex = index - (index ~/ 6);
                  if (postIndex >= widget.recentImageResults.length) {
                    return Container();
                  }

                  final postDoc = widget.recentImageResults[postIndex];
                  final post = Post.fromDocument(postDoc);

                  if (post.mediaUrl == null || post.mediaUrl!.isEmpty) {
                    return Container(); // media_urlがない場合はスキップ
                  }

                  return FutureBuilder<Account?>(
                    future: widget.getPostAccount(post.postAccountId),
                    builder: (context, accountSnapshot) {
                      if (accountSnapshot.hasError) {
                        return Center(
                            child:
                                Text('エラーが発生しました: ${accountSnapshot.error}'));
                      } else if (!accountSnapshot.hasData) {
                        return Container();
                      }

                      final postAccount = accountSnapshot.data!;

                      if (blockedUserIds.contains(postAccount.id)) {
                        return Container();
                      }

                      if (postAccount.lockAccount &&
                          postAccount.id != widget.userId) {
                        return Container();
                      }

                      widget.favoritePost.favoriteUsersNotifiers[post.id] ??=
                          ValueNotifier<int>(0);
                      widget.favoritePost.updateFavoriteUsersCount(post.id);

                      widget.bookmarkPost.bookmarkUsersNotifiers[post.id] ??=
                          ValueNotifier<int>(0);
                      widget.bookmarkPost.updateBookmarkUsersCount(post.id);

                      return PostItemWidget(
                        post: post,
                        postAccount: postAccount,
                        favoriteUsersNotifier: widget
                            .favoritePost.favoriteUsersNotifiers[post.id]!,
                        isFavoriteNotifier: ValueNotifier<bool>(
                          widget.favoritePost.favoritePostsNotifier.value
                              .contains(post.id),
                        ),
                        onFavoriteToggle: () {
                          final isFavorite = widget
                              .favoritePost.favoritePostsNotifier.value
                              .contains(post.id);
                          widget.favoritePost
                              .toggleFavorite(post.id, isFavorite);
                        },
                        bookmarkUsersNotifier: widget
                            .bookmarkPost.bookmarkUsersNotifiers[post.id]!,
                        isBookmarkedNotifier: ValueNotifier<bool>(
                          widget.bookmarkPost.bookmarkPostsNotifier.value
                              .contains(post.id),
                        ),
                        onBookMsrkToggle: () =>
                            widget.bookmarkPost.toggleBookmark(
                          post.id,
                          widget.bookmarkPost.bookmarkPostsNotifier.value
                              .contains(post.id),
                        ),
                        replyFlag: ValueNotifier<bool>(false),
                        userId: widget.userId,
                      );
                    },
                  );
                },
              ),
            ),
          ),
        );
      },
    );
  }
}
