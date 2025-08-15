import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cymva/ad_widget.dart';
import 'package:cymva/model/account.dart';
import 'package:cymva/model/post.dart';
import 'package:cymva/utils/book_mark.dart';
import 'package:cymva/utils/favorite_post.dart';
import 'package:cymva/view/post_item/post_item_widget.dart';
import 'package:flutter/material.dart';

class SearchTextPage extends StatefulWidget {
  final List<DocumentSnapshot> postSearchResults;
  final Future<List<String>> Function() fetchBlockedUserIds;
  final Future<void> Function() refreshSearchResults;
  final String userId;
  final FavoritePost favoritePost;
  final BookmarkPost bookmarkPost;
  final Future<Account?> Function(String postAccountId) getPostAccount;

  const SearchTextPage({
    Key? key,
    required this.postSearchResults,
    required this.fetchBlockedUserIds,
    required this.refreshSearchResults,
    required this.userId,
    required this.favoritePost,
    required this.bookmarkPost,
    required this.getPostAccount,
  }) : super(key: key);

  @override
  _SearchByTextPageState createState() => _SearchByTextPageState();
}

class _SearchByTextPageState extends State<SearchTextPage>
    with AutomaticKeepAliveClientMixin {
  int _displayLimit = 15; // 表示する件数の上限
  bool _isLoadingMore = false; // ローディング状態を管理
  List<String> _blockedUserIds = [];

  @override
  bool get wantKeepAlive => true;

  Future<void> _loadMorePosts() async {
    if (_displayLimit < widget.postSearchResults.length && !_isLoadingMore) {
      setState(() {
        _isLoadingMore = true;
      });

      await Future.delayed(const Duration(milliseconds: 500)); // ローディングのための遅延

      setState(() {
        _displayLimit = (_displayLimit + 15)
            .clamp(0, widget.postSearchResults.length); // 上限を超えないように調整
        _isLoadingMore = false;
      });
    }
  }

  @override
  void initState() {
    super.initState();
    _fetchBlockedUserIds().then((ids) {
      setState(() {
        _blockedUserIds = ids; // 非表示対象のユーザーIDを設定
      });
    });
  }

  Future<List<String>> _fetchBlockedUserIds() async {
    final blockUsersSnapshot = await FirebaseFirestore.instance
        .collection('users')
        .doc(widget.userId)
        .collection('blockUsers')
        .get();

    final blockSnapshot = await FirebaseFirestore.instance
        .collection('users')
        .doc(widget.userId)
        .collection('block')
        .get();

    // blocked_user_id をリストにまとめる
    final blockedUserIds = [
      ...blockUsersSnapshot.docs.map((doc) => doc['blocked_user_id'] as String),
      ...blockSnapshot.docs.map((doc) => doc['blocked_user_id'] as String),
    ];

    return blockedUserIds;
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);

    if (widget.postSearchResults.isEmpty) {
      return const Center(child: Text('検索結果がありません'));
    }

    return Center(
      child: ConstrainedBox(
        constraints: BoxConstraints(maxWidth: 500),
        child: NotificationListener<ScrollNotification>(
          onNotification: (ScrollNotification scrollInfo) {
            if (scrollInfo is ScrollUpdateNotification) {
              if (scrollInfo.metrics.pixels >=
                      scrollInfo.metrics.maxScrollExtent - 50 &&
                  !_isLoadingMore &&
                  _displayLimit < widget.postSearchResults.length) {
                // 下にスクロールして一番下に近づいた場合
                _loadMorePosts();
              }
            }
            return true;
          },
          child: ListView.builder(
            key: PageStorageKey('SearchTextPageList'),
            itemCount: _displayLimit + (_displayLimit ~/ 5) + 1,
            itemBuilder: (context, index) {
              if (index == _displayLimit + (_displayLimit ~/ 5)) {
                return const Center(child: Text("結果は以上です"));
              }

              if (index % 6 == 5) {
                return BannerAdWidget() ??
                    const SizedBox(height: 50); // 広告ウィジェットを表示
              }

              final postIndex = index - (index ~/ 6);
              if (postIndex >= _displayLimit ||
                  postIndex >= widget.postSearchResults.length) {
                return Container();
              }

              final postDoc = widget.postSearchResults[postIndex];
              final post = Post.fromDocument(postDoc);

              return FutureBuilder<Account?>(
                future: widget.getPostAccount(post.postAccountId),
                builder: (context, accountSnapshot) {
                  if (accountSnapshot.hasError) {
                    return Center(
                        child: Text('エラーが発生しました: ${accountSnapshot.error}'));
                  } else if (!accountSnapshot.hasData) {
                    return Container();
                  }

                  final postAccount = accountSnapshot.data!;

                  if (postAccount == null ||
                      postAccount.lockAccount ||
                      _blockedUserIds.contains(postAccount.id)) {
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
                    favoriteUsersNotifier:
                        widget.favoritePost.favoriteUsersNotifiers[post.id]!,
                    isFavoriteNotifier: ValueNotifier<bool>(
                      widget.favoritePost.favoritePostsNotifier.value
                          .contains(post.id),
                    ),
                    onFavoriteToggle: () {
                      final isFavorite = widget
                          .favoritePost.favoritePostsNotifier.value
                          .contains(post.id);
                      widget.favoritePost.toggleFavorite(post.id, isFavorite);
                    },
                    bookmarkUsersNotifier:
                        widget.bookmarkPost.bookmarkUsersNotifiers[post.id]!,
                    isBookmarkedNotifier: ValueNotifier<bool>(
                      widget.bookmarkPost.bookmarkPostsNotifier.value
                          .contains(post.id),
                    ),
                    onBookMsrkToggle: () => widget.bookmarkPost.toggleBookmark(
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
  }
}
