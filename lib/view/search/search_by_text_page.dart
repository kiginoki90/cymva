import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cymva/model/account.dart';
import 'package:cymva/model/post.dart';
import 'package:cymva/view/post_item/post_item_widget.dart';
import 'package:cymva/utils/favorite_post.dart';
import 'package:cymva/view/search/search_item.dart';

class SearchByTextPage extends StatefulWidget {
  final List<DocumentSnapshot> postSearchResults;
  final Future<List<String>> Function() fetchBlockedUserIds;
  final Future<void> Function() refreshSearchResults;
  final Future<void> Function() fetchInitialSearchResults;
  final ScrollController scrollController;
  final SearchItem searchItem;
  final String userId;
  final FavoritePost favoritePost;
  final bool hasMore;
  final String lastQuery;
  final String? selectedCategory;

  const SearchByTextPage({
    Key? key,
    required this.postSearchResults,
    required this.fetchBlockedUserIds,
    required this.refreshSearchResults,
    required this.fetchInitialSearchResults,
    required this.scrollController,
    required this.searchItem,
    required this.userId,
    required this.favoritePost,
    required this.hasMore,
    required this.lastQuery,
    required this.selectedCategory,
  }) : super(key: key);

  @override
  _SearchByTextPageState createState() => _SearchByTextPageState();
}

class _SearchByTextPageState extends State<SearchByTextPage> {
  List<DocumentSnapshot> _postSearchResults = [];
  bool _hasMore = true;
  DocumentSnapshot? _lastDocument;

  @override
  void initState() {
    super.initState();
    _postSearchResults = widget.postSearchResults;
    _hasMore = widget.hasMore;
  }

  Future<void> _fetchMoreSearchResults() async {
    if (!_hasMore) return;

    widget.searchItem.searchPosts(
        widget.lastQuery, widget.selectedCategory, _lastDocument, 5, (results) {
      if (results.isNotEmpty) {
        setState(() {
          _postSearchResults.addAll(results); // 新しい投稿を既存のリストに追加
          _lastDocument = results.last;
          if (results.length < 5) {
            _hasMore = false;
          }
        });
      } else {
        setState(() {
          _hasMore = false;
        });
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    if (_postSearchResults.isEmpty) {
      return const Center(child: Text('検索結果がありません'));
    }

    return FutureBuilder<List<String>>(
      future: widget.fetchBlockedUserIds(), // ブロックされたユーザーIDを取得するFuture
      builder: (context, blockedUsersSnapshot) {
        if (blockedUsersSnapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        } else if (blockedUsersSnapshot.hasError) {
          return Center(
              child: Text('エラーが発生しました: ${blockedUsersSnapshot.error}'));
        } else if (!blockedUsersSnapshot.hasData) {
          return Container();
        }

        final blockedUserIds = blockedUsersSnapshot.data!; // ブロックされたユーザーIDのリスト

        return RefreshIndicator(
          onRefresh: widget.refreshSearchResults,
          child: ListView.builder(
            controller: widget.scrollController,
            itemCount: _postSearchResults.length + 1,
            itemBuilder: (context, index) {
              if (index == _postSearchResults.length) {
                if (_hasMore) {
                  return Center(
                    child: ElevatedButton(
                      onPressed: _fetchMoreSearchResults,
                      child: const Text('さらに表示する'),
                    ),
                  );
                } else {
                  return const Center(child: Text('結果は以上です'));
                }
              }

              final postDoc = _postSearchResults[index];
              final post = Post.fromDocument(postDoc);

              return FutureBuilder<Account?>(
                future: widget.searchItem.getPostAccount(post.postAccountId),
                builder: (context, accountSnapshot) {
                  if (accountSnapshot.connectionState ==
                      ConnectionState.waiting) {
                    return const Center(child: CircularProgressIndicator());
                  } else if (accountSnapshot.hasError) {
                    return Center(
                        child: Text('エラーが発生しました: ${accountSnapshot.error}'));
                  } else if (!accountSnapshot.hasData) {
                    return Container();
                  }

                  final postAccount = accountSnapshot.data!;

                  // 自分のblockUsersサブコレクションでブロックされたユーザーIDと一致したらスキップする
                  if (blockedUserIds.contains(postAccount.id)) {
                    return Container(); // スキップして何も表示しない
                  }

                  // lock_accountがtrueで、自分ではないアカウントならスキップする
                  if (postAccount.lockAccount &&
                      postAccount.id != widget.userId) {
                    return Container(); // スキップして何も表示しない
                  }

                  // フォロワー数の処理
                  widget.favoritePost.favoriteUsersNotifiers[post.id] ??=
                      ValueNotifier<int>(0);
                  widget.favoritePost.updateFavoriteUsersCount(post.id);

                  return PostItemWidget(
                    post: post,
                    postAccount: postAccount,
                    favoriteUsersNotifier:
                        widget.favoritePost.favoriteUsersNotifiers[post.id]!,
                    isFavoriteNotifier: ValueNotifier<bool>(widget
                        .favoritePost.favoritePostsNotifier.value
                        .contains(post.id)),
                    onFavoriteToggle: () {
                      final isFavorite = widget
                          .favoritePost.favoritePostsNotifier.value
                          .contains(post.id);
                      widget.favoritePost.toggleFavorite(post.id, isFavorite);
                    },
                    // isRetweetedNotifier: ValueNotifier<bool>(false),
                    replyFlag: ValueNotifier<bool>(false),
                    userId: widget.userId,
                  );
                },
              );
            },
          ),
        );
      },
    );
  }
}

Future<void> fetchInitialSearchResults({
  required String lastQuery,
  required String? selectedCategory,
  required SearchItem searchItem,
  required Function(List<DocumentSnapshot>) updateResults,
  required Function(bool) updateHasMore,
}) async {
  updateHasMore(true);

  searchItem.searchPosts(lastQuery, selectedCategory, null, 5, (results) {
    updateResults(results);

    if (results.length < 5) {
      updateHasMore(false);
    }
  });
}
