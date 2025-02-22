import 'package:cymva/utils/book_mark.dart';
import 'package:cymva/utils/favorite_post.dart';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cymva/model/post.dart';
import 'package:cymva/model/account.dart';
import 'package:cymva/view/post_item/post_item_widget.dart';

class BookmarkPage extends StatefulWidget {
  final String userId;

  const BookmarkPage({Key? key, required this.userId}) : super(key: key);

  @override
  _BookmarkPageState createState() => _BookmarkPageState();
}

class _BookmarkPageState extends State<BookmarkPage> {
  final FavoritePost _favoritePost = FavoritePost();
  final BookmarkPost _bookmarkPost = BookmarkPost();
  List<Post> _posts = [];
  Map<String, Account> _accounts = {};
  bool _hasMore = true;
  bool _isLoading = false;
  DocumentSnapshot? _lastDocument;
  final ScrollController _scrollController = ScrollController();

  @override
  void initState() {
    super.initState();
    _bookmarkPost.getBookmarkPosts();
    _fetchInitialBookmarks();
  }

  Future<void> _fetchInitialBookmarks() async {
    setState(() {
      _isLoading = true;
    });

    final bookmarkPostIds = await _fetchBookmarkPostIds();
    final posts = await _fetchPosts(bookmarkPostIds);
    final accountIds = posts.map((post) => post.postAccountId).toSet().toList();
    final accounts = await _fetchAccounts(accountIds);

    if (mounted) {
      setState(() {
        _posts = posts;
        _accounts = accounts;
        _isLoading = false;
      });
    }
  }

  Future<void> _fetchMoreBookmarks() async {
    if (_isLoading || !_hasMore) return;

    final bookmarkPostIds = await _fetchBookmarkPostIds();
    final posts = await _fetchPosts(bookmarkPostIds);
    if (posts.isNotEmpty) {
      final accountIds =
          posts.map((post) => post.postAccountId).toSet().toList();
      final accounts = await _fetchAccounts(accountIds);

      if (mounted) {
        setState(() {
          _posts.addAll(posts);
          _accounts.addAll(accounts);
          _lastDocument = bookmarkPostIds.last;
          _isLoading = false;
        });
      }
    } else {
      if (mounted) {
        setState(() {
          _hasMore = false;
        });
      }
    }
  }

  Future<List<DocumentSnapshot>> _fetchBookmarkPostIds() async {
    Query query = FirebaseFirestore.instance
        .collection('users')
        .doc(widget.userId)
        .collection('bookmark_posts')
        .orderBy('added_at', descending: true)
        .limit(10);

    if (_lastDocument != null) {
      query = query.startAfterDocument(_lastDocument!);
    }

    final querySnapshot = await query.get();
    if (querySnapshot.docs.isNotEmpty) {
      _lastDocument = querySnapshot.docs.last;
    }

    return querySnapshot.docs;
  }

  Future<List<Post>> _fetchPosts(List<DocumentSnapshot> bookmarkPostIds) async {
    List<Post> posts = [];
    for (var doc in bookmarkPostIds) {
      final postId = doc.id;
      final postDoc = await FirebaseFirestore.instance
          .collection('posts')
          .doc(postId)
          .get();
      if (postDoc.exists) {
        final postData = postDoc.data() as Map<String, dynamic>;
        posts.add(Post.fromMap(postData, documentSnapshot: postDoc));
      }
    }
    return posts;
  }

  Future<Map<String, Account>> _fetchAccounts(List<String> accountIds) async {
    final Map<String, Account> accounts = {};
    for (String accountId in accountIds) {
      final account = await _fetchAccount(accountId);
      if (account != null) {
        accounts[accountId] = account;
      }
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

  Future<void> _refreshBookmarks() async {
    setState(() {
      _posts = [];
      _accounts = {};
      _lastDocument = null;
      _hasMore = true;
    });
    await _fetchInitialBookmarks();
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    // if (_posts.isEmpty) {
    //   return const Center(child: Text('挟まれた栞が見当たりません'));
    // }

    return Scaffold(
      appBar: AppBar(
        title: Text('栞'),
      ),
      body: RefreshIndicator(
        onRefresh: _refreshBookmarks,
        child: ListView.builder(
          controller: _scrollController,
          itemCount: _posts.length + 1,
          itemBuilder: (context, index) {
            if (index == _posts.length) {
              return _hasMore
                  ? TextButton(
                      onPressed: _fetchMoreBookmarks,
                      child: const Text("もっと読み込む"),
                    )
                  : const Center(child: Text("結果は以上です"));
            }

            Post post = _posts[index];
            Account postAccount = _accounts[post.postAccountId]!;

            // お気に入りユーザー数の初期化と更新
            _favoritePost.favoriteUsersNotifiers[post.id] ??=
                ValueNotifier<int>(0);
            _favoritePost.updateFavoriteUsersCount(post.id);

            // ブックマークユーザー数の初期化と更新
            _bookmarkPost.bookmarkUsersNotifiers[post.id] ??=
                ValueNotifier<int>(0);
            _bookmarkPost.updateBookmarkUsersCount(post.id);

            return PostItemWidget(
              key: ValueKey(post.id), // これを追加して、各投稿のキーを設定
              post: post,
              postAccount: postAccount,
              favoriteUsersNotifier:
                  _favoritePost.favoriteUsersNotifiers[post.id]!,
              isFavoriteNotifier: ValueNotifier<bool>(
                _favoritePost.favoritePostsNotifier.value.contains(post.id),
              ),
              onFavoriteToggle: () => _favoritePost.toggleFavorite(
                post.id,
                _favoritePost.favoritePostsNotifier.value.contains(post.id),
              ),
              replyFlag: ValueNotifier<bool>(false),
              bookmarkUsersNotifier:
                  _bookmarkPost.bookmarkUsersNotifiers[post.id]!,
              isBookmarkedNotifier: ValueNotifier<bool>(
                _bookmarkPost.bookmarkPostsNotifier.value.contains(post.id),
              ),
              onBookMsrkToggle: () => _bookmarkPost.toggleBookmark(
                post.id,
                _bookmarkPost.bookmarkPostsNotifier.value.contains(post.id),
              ),
              userId: widget.userId,
            );
          },
        ),
      ),
    );
  }
}
