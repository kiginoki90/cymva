import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cymva/model/account.dart';
import 'package:cymva/model/post.dart';
import 'package:cymva/utils/book_mark.dart';
import 'package:cymva/utils/favorite_post.dart';
import 'package:cymva/view/post_item/post_item_widget.dart';
import 'package:cymva/view/search/trending_words_page.dart';
import 'package:flutter/material.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

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
  List<String> _blockedUserIds = [];
  final ScrollController _scrollController = ScrollController();
  late Future<Account?> _postAccountFuture;
  final Map<String, Account?> _accountCache = {}; // キャッシュを追加
  final storage = FlutterSecureStorage();

  @override
  bool get wantKeepAlive => true;

  @override
  void initState() {
    super.initState();
    _fetchBlockedUserIds().then((ids) {
      setState(() {
        _blockedUserIds = ids;
      });
    });
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
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

  Future<bool> _areFiltersEmpty() async {
    final selectedCategory = await storage.read(key: 'selectedCategory');
    final searchUserId = await storage.read(key: 'searchUserId');
    final isExactMatch = (await storage.read(key: 'isExactMatch')) == 'true';
    final isFollowing = (await storage.read(key: 'isFollowing')) == 'true';
    final star = (await storage.read(key: 'star')) == 'true';
    final startDateString = await storage.read(key: 'startDate');
    final endDateString = await storage.read(key: 'endDate');

    return selectedCategory == null &&
        searchUserId == null &&
        !isExactMatch &&
        !isFollowing &&
        !star &&
        startDateString == null &&
        endDateString == null;
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);

    if (widget.postSearchResults.isEmpty) {
      return FutureBuilder<DocumentSnapshot>(
        future: FirebaseFirestore.instance
            .collection('setting')
            .doc('lOq7swYoUFttv7LnZs2n')
            .get(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          if (snapshot.hasError) {
            return const Center(child: Text('検索結果がありません'));
          }

          if (snapshot.hasData && snapshot.data!.exists) {
            final trendEnabled = snapshot.data!['trend'] as bool? ?? false;

            if (trendEnabled) {
              return FutureBuilder<bool>(
                future: _areFiltersEmpty(),
                builder: (context, filterSnapshot) {
                  if (filterSnapshot.connectionState ==
                      ConnectionState.waiting) {
                    return const Center(child: CircularProgressIndicator());
                  }

                  if (filterSnapshot.hasError || !filterSnapshot.hasData) {
                    return const Center(child: Text('検索結果がありません'));
                  }

                  if (filterSnapshot.data == true) {
                    return const TrendingWordsPage();
                  }

                  return const Center(child: Text('検索結果がありません'));
                },
              );
            }
          }

          return const Center(child: Text('検索結果がありません'));
        },
      );
    }

    return Center(
      child: ConstrainedBox(
        constraints: BoxConstraints(maxWidth: 500),
        child: ListView.builder(
          key: PageStorageKey('SearchTextPage_${widget.userId}'),
          controller: _scrollController,
          itemCount: widget.postSearchResults.length,
          itemBuilder: (context, index) {
            final postDoc = widget.postSearchResults[index];
            final post = Post.fromDocument(postDoc);

            if (_accountCache.containsKey(post.postAccountId)) {
              final postAccount = _accountCache[post.postAccountId];
              if (postAccount == null ||
                  postAccount.lockAccount ||
                  _blockedUserIds.contains(postAccount.id)) {
                return Container();
              }

              return _buildPostItem(post, postAccount);
            }

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
                _accountCache[post.postAccountId] = postAccount;

                if (postAccount.lockAccount ||
                    _blockedUserIds.contains(postAccount.id)) {
                  return Container();
                }

                return _buildPostItem(post, postAccount);
              },
            );
          },
        ),
      ),
    );
  }

  Widget _buildPostItem(Post post, Account postAccount) {
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
        widget.favoritePost.favoritePostsNotifier.value.contains(post.id),
      ),
      onFavoriteToggle: () {
        final isFavorite =
            widget.favoritePost.favoritePostsNotifier.value.contains(post.id);
        widget.favoritePost.toggleFavorite(post.id, isFavorite);
      },
      bookmarkUsersNotifier:
          widget.bookmarkPost.bookmarkUsersNotifiers[post.id]!,
      isBookmarkedNotifier: ValueNotifier<bool>(
        widget.bookmarkPost.bookmarkPostsNotifier.value.contains(post.id),
      ),
      onBookMsrkToggle: () => widget.bookmarkPost.toggleBookmark(
        post.id,
        widget.bookmarkPost.bookmarkPostsNotifier.value.contains(post.id),
      ),
      replyFlag: ValueNotifier<bool>(false),
      userId: widget.userId,
    );
  }
}
