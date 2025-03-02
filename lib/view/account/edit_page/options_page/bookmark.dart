import 'package:cymva/utils/book_mark.dart';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cymva/model/post.dart';
import 'package:cymva/model/account.dart';
import 'package:cymva/utils/favorite_post.dart';
import 'package:cymva/view/post_item/post_item_widget.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class BookmarkPage extends ConsumerStatefulWidget {
  final String userId;

  const BookmarkPage({Key? key, required this.userId}) : super(key: key);

  @override
  _BookmarkPageState createState() => _BookmarkPageState();
}

class _BookmarkPageState extends ConsumerState<BookmarkPage> {
  final FavoritePost _favoritePost = FavoritePost();
  final BookmarkPost _bookmarkPost = BookmarkPost();
  final ScrollController _scrollController = ScrollController();
  bool _isLoadingMore = false;
  Map<String, Account> _accountCache = {};

  @override
  void initState() {
    super.initState();
    _loadPosts();
    _scrollController.addListener(_scrollListener);
    _favoritePost.getFavoritePosts(); // お気に入りの投稿を取得
    _bookmarkPost.getBookmarkPosts(); // ブックマークの投稿を取得
  }

  @override
  void dispose() {
    _scrollController.removeListener(_scrollListener);
    _scrollController.dispose();
    super.dispose();
  }

  void _scrollListener() async {
    if (_scrollController.offset >=
            _scrollController.position.maxScrollExtent - 200 &&
        !_scrollController.position.outOfRange &&
        !_isLoadingMore) {
      setState(() {
        _isLoadingMore = true;
      });
      await ref
          .read(bookmarkViewModelProvider)
          .getBookmarkPostsNext(widget.userId);
      setState(() {
        _isLoadingMore = false;
      });
    }
  }

  Future<void> _loadPosts() async {
    await ref.read(bookmarkViewModelProvider).getBookmarkPosts(widget.userId);
  }

  Future<void> _refreshPosts() async {
    await ref.read(bookmarkViewModelProvider).getBookmarkPosts(widget.userId);
  }

  Future<Account?> _fetchAccount(String accountId) async {
    if (_accountCache.containsKey(accountId)) {
      return _accountCache[accountId];
    }

    final userDoc = await FirebaseFirestore.instance
        .collection('users')
        .doc(accountId)
        .get();
    if (userDoc.exists) {
      final account = Account.fromDocument(userDoc);
      _accountCache[accountId] = account;
      return account;
    }
    return null;
  }

  @override
  Widget build(BuildContext context) {
    final model = ref.watch(bookmarkViewModelProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text("栞"),
      ),
      body: Column(
        children: [
          const Divider(height: 1, color: Colors.grey), // 境界線を追加
          Expanded(
            child: Center(
              child: ConstrainedBox(
                constraints: BoxConstraints(maxWidth: 500),
                child: RefreshIndicator(
                  onRefresh: _refreshPosts,
                  child: ListView.builder(
                    controller: _scrollController,
                    itemCount: model.postList.length + 1,
                    itemBuilder: (context, index) {
                      if (index == model.postList.length) {
                        return _isLoadingMore
                            ? const Center(child: Text(" Loading..."))
                            : const Center(child: Text("結果は以上です"));
                      }

                      final post = model.postList[index];

                      // お気に入りユーザー数の初期化と更新
                      _favoritePost.favoriteUsersNotifiers[post.id] ??=
                          ValueNotifier<int>(0);
                      _favoritePost.updateFavoriteUsersCount(post.id);

                      _bookmarkPost.bookmarkUsersNotifiers[post.id] ??=
                          ValueNotifier<int>(0);
                      _bookmarkPost.updateBookmarkUsersCount(post.id);

                      return FutureBuilder<Account?>(
                        future: _fetchAccount(post.postAccountId),
                        builder: (context, snapshot) {
                          if (!snapshot.hasData) {
                            return const Center(
                                child: Text("アカウント情報が取得できませんでした"));
                          }

                          final postAccount = snapshot.data!;

                          return PostItemWidget(
                            key: ValueKey(post.id),
                            post: post,
                            postAccount: postAccount,
                            favoriteUsersNotifier:
                                _favoritePost.favoriteUsersNotifiers[post.id]!,
                            isFavoriteNotifier: ValueNotifier<bool>(
                              _favoritePost.favoritePostsNotifier.value
                                  .contains(post.id),
                            ),
                            onFavoriteToggle: () =>
                                _favoritePost.toggleFavorite(
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
                            onBookMsrkToggle: () =>
                                _bookmarkPost.toggleBookmark(
                              post.id,
                              _bookmarkPost.bookmarkPostsNotifier.value
                                  .contains(post.id),
                            ),
                            userId: widget.userId,
                          );
                        },
                      );
                    },
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

final bookmarkViewModelProvider =
    ChangeNotifierProvider<BookmarkViewModel>((ref) => BookmarkViewModel(ref));

class BookmarkViewModel extends ChangeNotifier {
  BookmarkViewModel(this.ref);

  final Ref ref;
  List<Post> postList = [];
  List<Post> currentPostList = [];

  Future<void> getBookmarkPosts(String userId) async {
    postList = [];
    final dbManager = ref.read(dbManagerProvider);

    currentPostList = await dbManager.getBookmarkPosts(userId);
    postList.addAll(currentPostList);
    notifyListeners();
  }

  Future<void> getBookmarkPostsNext(String userId) async {
    currentPostList =
        await ref.read(dbManagerProvider).getBookmarkPostsNext(userId);
    if (currentPostList.isNotEmpty) {
      postList.addAll(currentPostList);
    }
    notifyListeners();
  }
}

class DbManager {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  DocumentSnapshot? _lastDocument;

  Future<List<Post>> getBookmarkPosts(String userId) async {
    Query query = _firestore
        .collection('users')
        .doc(userId)
        .collection('bookmark_posts')
        .orderBy('added_at', descending: true)
        .limit(10);

    final querySnapshot = await query.get();
    List<Post> posts = [];
    if (querySnapshot.docs.isNotEmpty) {
      _lastDocument = querySnapshot.docs.last;
      List<Future<Post?>> futures = querySnapshot.docs.map((doc) async {
        final postId = doc.id;
        final postDoc = await _firestore.collection('posts').doc(postId).get();
        if (postDoc.exists) {
          return Post.fromDocument(postDoc);
        }
        return null;
      }).toList();

      posts = (await Future.wait(futures))
          .where((post) => post != null)
          .cast<Post>()
          .toList();
    } else {
      print("No posts found.");
    }
    return posts;
  }

  Future<List<Post>> getBookmarkPostsNext(String userId) async {
    if (_lastDocument == null) return [];

    Query query = _firestore
        .collection('users')
        .doc(userId)
        .collection('bookmark_posts')
        .orderBy('added_at', descending: true)
        .startAfterDocument(_lastDocument!)
        .limit(10);

    final querySnapshot = await query.get();
    List<Post> posts = [];
    if (querySnapshot.docs.isNotEmpty) {
      _lastDocument = querySnapshot.docs.last;
      List<Future<Post?>> futures = querySnapshot.docs.map((doc) async {
        final postId = doc.id;
        final postDoc = await _firestore.collection('posts').doc(postId).get();
        if (postDoc.exists) {
          return Post.fromDocument(postDoc);
        }
        return null;
      }).toList();

      posts = (await Future.wait(futures))
          .where((post) => post != null)
          .cast<Post>()
          .toList();
    } else {
      print("No more posts found.");
    }
    return posts;
  }
}

final dbManagerProvider = Provider((ref) => DbManager());
