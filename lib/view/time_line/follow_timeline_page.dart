import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cymva/utils/book_mark.dart';
import 'package:flutter/material.dart';
import 'package:cymva/view/post_item/post_item_widget.dart';
import 'package:cymva/model/account.dart';
import 'package:cymva/model/post.dart';
import 'package:cymva/utils/favorite_post.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:cymva/ad_widget.dart';

class FollowTimelinePage extends StatefulWidget {
  final String userId;
  FollowTimelinePage({
    super.key,
    required this.userId,
  });

  @override
  State<FollowTimelinePage> createState() => _FollowTimelinePageState();
}

class _FollowTimelinePageState extends State<FollowTimelinePage> {
  final FavoritePost _favoritePost = FavoritePost();
  final BookmarkPost _bookmarkPost = BookmarkPost();
  String? loginUserId;
  final FlutterSecureStorage storage = FlutterSecureStorage();
  List<QueryDocumentSnapshot> _followedPosts = [];
  Map<String, Account?> _accounts = {};
  bool _hasMore = true;
  bool _isLoading = false;
  DocumentSnapshot? _lastDocument;
  final ScrollController _scrollController = ScrollController();
  final ValueNotifier<bool> _showScrollToTopButton = ValueNotifier(false);

  @override
  void initState() {
    super.initState();
    _loadLoginUserId();
    _scrollController.addListener(_scrollListener);
    _favoritePost.getFavoritePosts();
    _bookmarkPost.getBookmarkPosts();
    _fetchBlockedAccounts(widget.userId);
  }

  @override
  void dispose() {
    _scrollController.removeListener(_scrollListener);
    _scrollController.dispose();
    super.dispose();
  }

  void _scrollListener() {
    if (_scrollController.offset >= 600) {
      _showScrollToTopButton.value = true;
    } else {
      _showScrollToTopButton.value = false;
    }
  }

  Future<void> _loadLoginUserId() async {
    loginUserId = await storage.read(key: 'account_id');
    if (loginUserId != null) {
      _fetchInitialPosts();
    }
  }

  Future<void> _fetchInitialPosts() async {
    setState(() {
      _isLoading = true;
    });

    final posts = await _fetchFollowedPosts();
    final accountIds = posts
        .map((doc) => Post.fromDocument(doc).postAccountId)
        .toSet()
        .toList();
    final accounts = await _fetchAccounts(accountIds);

    setState(() {
      _followedPosts = posts;
      _accounts = accounts;
      _isLoading = false;
    });
  }

  Future<void> _fetchMorePosts() async {
    if (_isLoading || !_hasMore) return;

    setState(() {
      _isLoading = true;
    });

    final posts = await _fetchFollowedPosts();
    if (posts.isNotEmpty) {
      final accountIds = posts
          .map((doc) => Post.fromDocument(doc).postAccountId)
          .toSet()
          .toList();
      final accounts = await _fetchAccounts(accountIds);

      setState(() {
        _followedPosts.addAll(posts);
        _accounts.addAll(accounts);
        _lastDocument = posts.last;
        _isLoading = false;
      });
    } else {
      setState(() {
        _hasMore = false;
        _isLoading = false;
      });
    }
  }

  Future<List<String>> _fetchBlockedAccounts(String userId) async {
    final snapshot = await FirebaseFirestore.instance
        .collection('users')
        .doc(userId)
        .collection('blockUsers')
        .get();

    return snapshot.docs
        .map((doc) => doc['blocked_user_id'] as String)
        .toList();
  }

  Future<List<QueryDocumentSnapshot>> _fetchFollowedPosts() async {
    final followSnapshot = await FirebaseFirestore.instance
        .collection('users')
        .doc(widget.userId)
        .collection('follow')
        .get();

    // フォローしているユーザーのIDを格納
    List<String> followedUserIds =
        followSnapshot.docs.map((doc) => doc.id).toList();

    if (followedUserIds.isEmpty) return [];

    final blockSnapshot = await FirebaseFirestore.instance
        .collection('users')
        .doc(widget.userId)
        .collection('blockUsers')
        .get();

    // ブロックしている、されているユーザーのIDを格納
    List<String> blockedUserIds = blockSnapshot.docs
        .map((doc) => doc['blocked_user_id'] as String)
        .toList();

    followedUserIds.removeWhere((userId) => blockedUserIds.contains(userId));

    if (followedUserIds.isEmpty) return [];

    Query query = FirebaseFirestore.instance
        .collection('posts')
        .where('post_account_id', whereIn: followedUserIds)
        .where('hide', isEqualTo: false)
        .orderBy('created_time', descending: true)
        .limit(30);

    if (_lastDocument != null) {
      query = query.startAfterDocument(_lastDocument!);
    }

    final postSnapshot = await query.get();
    return postSnapshot.docs;
  }

  Future<Map<String, Account?>> _fetchAccounts(List<String> accountIds) async {
    final Map<String, Account?> accounts = {};
    for (String accountId in accountIds) {
      final account = await _fetchAccount(accountId);
      accounts[accountId] = account;
    }
    return accounts;
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

  Future<void> _refreshPosts() async {
    setState(() {
      _followedPosts = [];
      _accounts = {};
      _lastDocument = null;
      _hasMore = true;
    });
    await _fetchInitialPosts();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: ConstrainedBox(
          constraints: BoxConstraints(maxWidth: 500),
          child: RefreshIndicator(
            onRefresh: _refreshPosts,
            child: _followedPosts.isEmpty
                ? const Center(child: Text("まだ投稿がありません"))
                : ListView.builder(
                    controller: _scrollController,
                    itemCount: _followedPosts.length +
                        (_followedPosts.length ~/ 10) +
                        1,
                    itemBuilder: (context, int index) {
                      if (index ==
                          _followedPosts.length +
                              (_followedPosts.length ~/ 10)) {
                        return _hasMore
                            ? TextButton(
                                onPressed: _fetchMorePosts,
                                child: const Text("もっと読み込む"),
                              )
                            : const Center(child: Text("結果は以上です"));
                      }

                      if (index % 11 == 10) {
                        return BannerAdWidget(); // 広告ウィジェットを表示
                      }

                      final postIndex = index - (index ~/ 11);
                      if (postIndex >= _followedPosts.length) {
                        return Container(); // インデックスが範囲外の場合は空のコンテナを返す
                      }

                      final postDoc = _followedPosts[postIndex];
                      final post = Post.fromDocument(postDoc);
                      final postAccount = _accounts[post.postAccountId];

                      _favoritePost.favoriteUsersNotifiers[post.id] ??=
                          ValueNotifier<int>(0);
                      _favoritePost.updateFavoriteUsersCount(post.id);

                      _bookmarkPost.bookmarkUsersNotifiers[post.id] ??=
                          ValueNotifier<int>(0);
                      _bookmarkPost.updateBookmarkUsersCount(post.id);

                      return PostItemWidget(
                        key: PageStorageKey(post.id),
                        post: post,
                        postAccount: postAccount!,
                        favoriteUsersNotifier:
                            _favoritePost.favoriteUsersNotifiers[post.id]!,
                        isFavoriteNotifier: ValueNotifier<bool>(
                          _favoritePost.favoritePostsNotifier.value
                              .contains(post.id),
                        ),
                        onFavoriteToggle: () => _favoritePost.toggleFavorite(
                          post.id,
                          _favoritePost.favoritePostsNotifier.value
                              .contains(post.id),
                        ),
                        replyFlag: ValueNotifier<bool>(false),
                        bookmarkUsersNotifier:
                            _bookmarkPost.bookmarkUsersNotifiers[post.id]!,
                        isBookmarkedNotifier: ValueNotifier<bool>(
                          _bookmarkPost.bookmarkPostsNotifier.value
                              .contains(post.id),
                        ),
                        onBookMsrkToggle: () => _bookmarkPost.toggleBookmark(
                          post.id,
                          _bookmarkPost.bookmarkPostsNotifier.value
                              .contains(post.id),
                        ),
                        userId: widget.userId,
                      );
                    },
                  ),
          ),
        ),
      ),
      floatingActionButton: ValueListenableBuilder<bool>(
        valueListenable: _showScrollToTopButton,
        builder: (context, value, child) {
          return value
              ? GestureDetector(
                  onDoubleTap: () {
                    _scrollController.animateTo(
                      0,
                      duration: Duration(milliseconds: 500),
                      curve: Curves.easeInOut,
                    );
                  },
                  child: Container(
                    width: 56.0,
                    height: 56.0,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      border: Border.all(color: Colors.lightBlue, width: 2.0),
                      color: Colors.transparent, // 内側を透明にする場合
                    ),
                    child: Icon(
                      Icons.keyboard_double_arrow_up,
                      color: Colors.lightBlue,
                      size: 40.0,
                    ),
                  ),
                )
              : Container();
        },
      ),
    );
  }
}
